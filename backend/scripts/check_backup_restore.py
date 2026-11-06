"""Offline restore drill. Never connects to Railway or accepts a target database URL.

Only labelled, UUID-named Docker resources created by this invocation are removed.
The input backup is read-only; credentials and database output are never logged.
"""

import argparse
import json
import os
import re
import secrets
import stat
import subprocess
import tempfile
import time
from pathlib import Path
from uuid import uuid4

from jose import JWTError, jwt

from scripts import recovery_point

# Old API images run the probe, which imports CheckError from this module (ADR 0004).
from scripts.operator_errors import CheckError, require, sha256_file

PROBE = Path(__file__).with_name("recovery_probe.py").read_text()
DELETE_PROBE = Path(__file__).with_name("recovery_deletions.py").read_text()
OWNER_LABEL = "clipback.recovery.owner"
REVISION_LABEL = "org.opencontainers.image.revision"
SNAPSHOT_KEYS = ("migration_revisions", "tables", "category_links_sha256", "assets", "sample")
ACCOUNT_DELETION = "account_deletion"


def private_json(path):
    require(not path.is_symlink(), "credentials_not_private")
    info = path.stat()
    require(stat.S_ISREG(info.st_mode), "credentials_not_private")
    require(stat.S_IMODE(info.st_mode) == 0o600, "credentials_not_private")
    require(info.st_uid == os.getuid(), "credentials_not_private")
    value = json.loads(path.read_text())
    require(isinstance(value, dict), "invalid_credentials")
    require(set(value) == {"secret_key", "access_token"}, "invalid_credentials")
    require(
        all(isinstance(v, str) and v and "\n" not in v and "\r" not in v for v in value.values()),
        "invalid_credentials",
    )
    return value


def token_account(credentials):
    """The access token's account if the restored API would accept the token, else None."""
    try:
        claims = jwt.decode(
            credentials["access_token"], credentials["secret_key"], algorithms=["HS256"]
        )
        return int(claims["sub"]) if claims.get("type") == "access" else None
    except (JWTError, KeyError, TypeError, ValueError):
        return None


class Docker:
    def __call__(self, *args, stdin=None, timeout=180):
        try:
            result = subprocess.run(
                ["docker", *args],
                stdin=stdin,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=True,
                timeout=timeout,
            )
            return result.stdout
        except (subprocess.SubprocessError, OSError) as exc:
            raise CheckError("docker_command_failed") from exc


class RestoreDrill:
    def __init__(self, docker=None, *, deletion_events=None, owner=None):
        self.docker = docker or Docker()
        self.owner = owner or "clipback-recovery-" + uuid4().hex
        require(bool(re.fullmatch(r"clipback-recovery-[0-9a-f]{32}", self.owner)),
                "invalid_restore_owner")
        self.created = []
        self.deletion_events = deletion_events

    def create(self, kind, name, *arguments):
        # Record only after create succeeded. Never adopt an existing resource.
        self.docker(
            kind,
            "create",
            "--label",
            f"{OWNER_LABEL}={self.owner}",
            *arguments,
            *([name] if kind != "container" else ["--name", name]),
        )
        self.created.append((kind, name))

    def cleanup(self):
        clean = True
        for kind, name in reversed(self.created):
            try:
                resource = json.loads(self.docker(kind, "inspect", name))[0]
                labels = resource.get("Config", {}) if kind == "container" else resource
                labels = labels.get("Labels") or {}
                require(labels.get(OWNER_LABEL) == self.owner, "resource_ownership_mismatch")
                self.docker(kind, "rm", *(["-f", "-v"] if kind == "container" else []), name)
            except (CheckError, ValueError, KeyError, IndexError):
                clean = False
        return clean

    def container(self, name, *args):
        self.docker(
            "container", "create", "--label", f"{OWNER_LABEL}={self.owner}", "--name", name, *args
        )
        self.created.append(("container", name))

    def wait(self, *command):
        deadline = time.monotonic() + 90
        while True:
            try:
                return self.docker(*command, timeout=5)
            except CheckError:
                require(time.monotonic() < deadline, "readiness_timeout")
                time.sleep(1)

    def run(self, manifest, paths, credentials, image):
        require(
            not os.environ.get("DOCKER_HOST", "unix://").startswith(("tcp:", "ssh:")),
            "docker_must_be_local",
        )
        context = json.loads(self.docker("context", "inspect"))[0]
        host = os.environ.get("DOCKER_HOST") or context["Endpoints"]["docker"]["Host"]
        require(host.startswith("unix://"), "docker_must_be_local")
        require(bool(re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._/@:-]*", image)), "invalid_image")
        metadata = json.loads(self.docker("image", "inspect", image))[0]
        require(
            (metadata["Config"].get("Labels") or {}).get(REVISION_LABEL) == manifest["app_commit"],
            "image_revision_mismatch",
        )
        app_image = metadata["Id"]
        pg_image = json.loads(
            self.docker("image", "inspect", f"postgres:{manifest['postgres_major']}")
        )[0]["Id"]
        network, db, api, files, pg = [
            self.owner + suffix for suffix in ("-net", "-db", "-api", "-files", "-pg")
        ]
        bucket_mode = manifest["format_version"] == 2 and any(
            asset["storage_backend"] == "s3" for asset in manifest["assets"]
        )
        s3 = self.owner + "-s3"
        if bucket_mode:
            # A local, internal test double only; no source/backup endpoint can be passed in.
            s3_image = json.loads(self.docker("image", "inspect", "motoserver/moto:5.2.4"))[0]["Id"]
        self.create("network", network, "--internal")
        self.create("volume", pg)
        self.create("volume", files)
        password = secrets.token_hex(24)
        with tempfile.TemporaryDirectory(prefix="clipback-recovery-private-") as temporary:
            env = Path(temporary) / "runtime.env"
            env.write_text(
                "\n".join(
                    [
                        "APP_ENVIRONMENT=test" if bucket_mode else "APP_ENVIRONMENT=production",
                        "YOUTUBE_SUMMARY_ENABLED=false",
                        f"SECRET_KEY={credentials['secret_key']}",
                        f"POSTGRES_PASSWORD={password}",
                        "POSTGRES_DB=clipback",
                        "STORAGE_ROOT=/data/screenshots",
                        "PORT=8123",
                        f"DATABASE_URL=postgresql://postgres:{password}@{db}:5432/clipback",
                        "OPENAI_API_KEY=offline-restore-placeholder",
                        'GOOGLE_CLIENT_IDS=["offline-restore-placeholder"]',
                        "KAKAO_REST_API_KEY=offline-restore-placeholder",
                        "BACKEND_CORS_ORIGINS=[]",
                        *(
                            [
                                "STORAGE_BACKEND=s3",
                                f"S3_ENDPOINT_URL=http://{s3}:5000",
                                "S3_BUCKET=restored-originals",
                                "S3_REGION=us-east-1",
                                "S3_ADDRESSING_STYLE=path",
                                "S3_ACCESS_KEY_ID=synthetic-recovery",
                                "S3_SECRET_ACCESS_KEY=synthetic-recovery",
                            ]
                            if bucket_mode
                            else []
                        ),
                    ]
                )
                + "\n"
            )
            env.chmod(0o600)
            pg_mount = (
                "/var/lib/postgresql"
                if manifest["postgres_major"] >= 18
                else ("/var/lib/postgresql/data")
            )
            self.container(
                db,
                "--network",
                network,
                "--env-file",
                str(env),
                "-v",
                f"{pg}:{pg_mount}",
                pg_image,
            )
            self.docker("start", db)
            # The official image's initialization server accepts only Unix
            # sockets. Wait for the final TCP server before restoring data.
            self.wait("exec", db, "pg_isready", "-h", "127.0.0.1",
                      "-U", "postgres", "-d", "clipback")
            # Reject a wrong major version before restoring any application data.
            version = (
                self.docker(
                    "exec",
                    db,
                    "psql",
                    "-U",
                    "postgres",
                    "-d",
                    "clipback",
                    "-Atc",
                    "SHOW server_version_num",
                )
                .decode()
                .strip()
            )
            require(
                int(version) // 10000 == manifest["postgres_major"], "postgres_version_mismatch"
            )
            with paths["database"].open("rb") as stream:
                self.docker(
                    "exec",
                    "-i",
                    db,
                    "pg_restore",
                    "-U",
                    "postgres",
                    "-d",
                    "clipback",
                    "--no-owner",
                    "--no-acl",
                    "--exit-on-error",
                    stdin=stream,
                )
            self.docker(
                "exec", db, "psql", "-U", "postgres", "-d", "clipback", "-v", "ON_ERROR_STOP=1",
                "-c", "DO $$ BEGIN IF to_regclass('public.maintenance_state') IS NOT NULL THEN "
                "DELETE FROM maintenance_operations; DELETE FROM maintenance_events; "
                "UPDATE maintenance_state SET phase='open',run_id=NULL,generation=0,"
                "drain_deadline=NULL,result=NULL WHERE id=1; END IF; END $$;",
            )
            unpack = self.owner + "-unpack"
            self.container(
                unpack,
                "-i",
                "--network",
                "none",
                "-v",
                f"{files}:/data",
                "--entrypoint",
                "tar",
                app_image,
                "--no-same-owner",
                "--no-same-permissions",
                "-C",
                "/data",
                "-xf",
                "-",
            )
            with paths["images"].open("rb") as stream:
                self.docker("start", "-a", "-i", unpack, stdin=stream)
            if bucket_mode:
                self.container(s3, "--network", network, s3_image)
                self.docker("start", s3)
                self.wait(
                    "exec",
                    s3,
                    "python",
                    "-c",
                    "import urllib.request; urllib.request.urlopen('http://127.0.0.1:5000')",
                )
                seed_bucket = self.owner + "-seed-bucket"
                self.container(
                    seed_bucket,
                    "--network",
                    network,
                    "--env-file",
                    str(env),
                    "-v",
                    f"{files}:/data:ro",
                    "--entrypoint",
                    "python",
                    app_image,
                    "-c",
                    "from pathlib import Path; "
                    "from app.integrations.storage_client import get_storage_client; "
                    "s=get_storage_client().for_backend('s3'); "
                    "s.client.create_bucket(Bucket=s.bucket); root=Path('/data/s3'); "
                    "[(s.client.put_object(Bucket=s.bucket,Key=str(p.relative_to(root)),"
                    "Body=p.read_bytes())) for p in root.rglob('*') if p.is_file()]",
                )
                self.docker("start", "-a", seed_bucket)
            payload = {
                "sample": ({k: manifest["sample"][k] for k in ("content_id", "asset_id")}
                           if manifest["sample"] else None),
                "access_token": credentials["access_token"],
                "format_version": manifest["format_version"],
            }
            deleted, deleted_accounts = [], []
            if self.deletion_events is not None:
                probe = self.owner + "-before-deletions"
                self.container(
                    probe, "-i", "--network", network, "--env-file", str(env),
                    "-v", f"{files}:/data", "--entrypoint", "python", app_image,
                    "-c", PROBE,
                )
                # Accounts the restored DB holds for account deletion records (ADR 0008).
                accounts = [
                    {"user_id": event["user_id"], "user_created_at": event["user_created_at"]}
                    for event in self.deletion_events if event.get("kind") == ACCOUNT_DELETION
                ]
                with tempfile.TemporaryFile() as stream:
                    stream.write(json.dumps(
                        {**payload, "verify_api": False, "account_deletions": accounts}
                    ).encode())
                    stream.seek(0)
                    before = json.loads(self.docker("start", "-a", "-i", probe, stdin=stream))
                require(all(before[k] == manifest[k] for k in SNAPSHOT_KEYS),
                        "restored_data_mismatch")
                apply = self.owner + "-apply-deletions"
                self.container(
                    apply, "-i", "--network", network, "--env-file", str(env),
                    "-v", f"{files}:/data", "--entrypoint", "python", app_image,
                    "-c", DELETE_PROBE,
                )
                with tempfile.TemporaryFile() as stream:
                    stream.write(json.dumps({"events": self.deletion_events}).encode())
                    stream.seek(0)
                    result = self.docker("start", "-a", "-i", apply, stdin=stream)
                    deleted = json.loads(result)["deleted"]
                payload["deleted"] = deleted
                deleted_accounts = before["matching_accounts"]
                if deleted_accounts:
                    # The probe expects 401 for a deleted token account and no rows for any.
                    payload["deleted_accounts"] = deleted_accounts
                    payload["token_account_deleted"] = (
                        token_account(credentials) in deleted_accounts
                    )
                # Preserve a living sample and its owner. Only a deleted sample
                # needs a replacement from the authenticated account.
                if payload.get("token_account_deleted") or (payload["sample"] and any(
                    item["content_id"] == payload["sample"]["content_id"] for item in deleted
                )):
                    payload["sample"] = None
            self.container(
                api, "--network", network, "--env-file", str(env), "-v", f"{files}:/data", app_image
            )
            self.docker("start", api)
            self.wait(
                "exec",
                api,
                "python",
                "-c",
                "import urllib.request; "
                "urllib.request.urlopen('http://127.0.0.1:8123/api/v1/health/ready', timeout=3)",
            )
            with tempfile.TemporaryFile() as stream:
                stream.write(json.dumps(payload).encode())
                stream.seek(0)
                actual = json.loads(
                    self.docker("exec", "-i", api, "python", "-c", PROBE, stdin=stream)
                )
            if self.deletion_events is None:
                require(all(actual[k] == manifest[k] for k in SNAPSHOT_KEYS),
                        "restored_data_mismatch")
            return {
                "table_count": len(actual["tables"]),
                "asset_count": len(actual["assets"]),
                "extra_file_count": actual["extra_file_count"],
                "authentication_passed": True,
                "image_bytes_passed": actual["sample"] is not None,
                "image_get_skipped": actual["sample"] is None,
                "deletions_applied": self.deletion_events is not None,
                "deleted_content_count": len(deleted),
                "deleted_account_count": len(deleted_accounts),
                "token_account_deleted": payload.get("token_account_deleted", False),
            }


def check(directory, credentials_file, image, drill=None):
    started = time.monotonic()
    drill = drill or RestoreDrill()
    report = {"passed": False, "cleanup_passed": False, "maintenance_verified": False,
              "live_deletion_ledger_verified": False}
    try:
        manifest, paths = recovery_point.load_backup(directory)
        credentials = private_json(credentials_file)
        report.update(backup_id=manifest["backup_id"], origin=manifest["origin"])
        report["manifest_sha256"] = sha256_file(directory / "manifest.json")
        report.update(drill.run(manifest, paths, credentials, image))
        report["passed"] = True
    except CheckError as exc:
        report["error"] = str(exc)
    except Exception:
        # Never surface JSON, SQL, HTTP responses, env files or container logs.
        report["error"] = "invalid_input_or_check_failed"
    finally:
        report["cleanup_passed"] = drill.cleanup()
        report["passed"] = report["passed"] and report["cleanup_passed"]
        report["elapsed_seconds"] = round(time.monotonic() - started, 3)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--backup-dir", type=Path, required=True)
    parser.add_argument("--credentials-file", type=Path, required=True)
    parser.add_argument("--image", required=True)
    args = parser.parse_args()
    report = check(args.backup_dir, args.credentials_file, args.image)
    print(json.dumps(report, sort_keys=True))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
