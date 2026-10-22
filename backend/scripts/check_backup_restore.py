"""Offline restore drill. Never connects to Railway or accepts a target database URL.

Only labelled, UUID-named Docker resources created by this invocation are removed.
The input backup is read-only; credentials and database output are never logged.
"""

import argparse
import hashlib
import json
import os
import re
import secrets
import shutil
import stat
import subprocess
import tarfile
import tempfile
import time
from datetime import datetime
from pathlib import Path, PurePosixPath
from uuid import uuid4

PROBE = Path(__file__).with_name("recovery_probe.py").read_text()
OWNER_LABEL = "clipback.recovery.owner"
REVISION_LABEL = "org.opencontainers.image.revision"
SHA256 = re.compile(r"[0-9a-f]{64}\Z")
SNAPSHOT_KEYS = ("migration_revisions", "tables", "category_links_sha256", "assets", "sample")


class CheckError(Exception):
    """A fixed public error code, without subprocess output or private data."""


def require(condition, code):
    if not condition:
        raise CheckError(code)


def sha256_file(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


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


def validate_archive(path):
    """Reject links, special files, ambiguous paths and duplicate file entries."""
    files, directories, size = set(), set(), 0
    with tarfile.open(path, "r:*") as archive:
        for member in archive:
            name = member.name
            normalized = PurePosixPath(name)
            require(
                not normalized.is_absolute() and ".." not in normalized.parts and "\\" not in name,
                "unsafe_archive",
            )
            require(member.isfile() or member.isdir(), "unsafe_archive")
            require(not member.issparse() and member.size >= 0, "unsafe_archive")
            key = str(normalized)
            if key == ".":
                require(member.isdir(), "unsafe_archive")
                continue
            parents = {str(parent) for parent in normalized.parents} - {"."}
            require(not parents.intersection(files), "unsafe_archive")
            if member.isfile():
                require(key not in files and key not in directories, "unsafe_archive")
                require(
                    not any(p.startswith(key + "/") for p in files | directories), "unsafe_archive"
                )
                files.add(key)
                size += member.size
            else:
                require(key not in files, "unsafe_archive")
                directories.add(key)
    return files, size


def load_backup(directory):
    manifest = json.loads((directory / "manifest.json").read_text())
    require(isinstance(manifest, dict) and manifest.get("format_version") == 1, "invalid_manifest")
    allowed = {
        "format_version",
        "backup_id",
        "origin",
        "captured_at",
        "app_commit",
        "postgres_major",
        "migration_revisions",
        "tables",
        "category_links_sha256",
        "assets",
        "sample",
        "database",
        "images",
        "extra_file_count",
    }
    require(set(manifest).issubset(allowed), "invalid_manifest")
    require(manifest.get("origin") in {"production", "synthetic"}, "invalid_manifest")
    require(
        bool(re.fullmatch(r"[A-Za-z0-9._-]{1,100}", manifest.get("backup_id", ""))),
        "invalid_manifest",
    )
    require(bool(re.fullmatch(r"[0-9a-f]{40}", manifest.get("app_commit", ""))), "invalid_manifest")
    captured = datetime.fromisoformat(manifest["captured_at"])
    require(captured.tzinfo is not None, "invalid_manifest")
    major = manifest["postgres_major"]
    require(type(major) is int and 13 <= major <= 30, "invalid_manifest")
    revisions, tables = manifest["migration_revisions"], manifest["tables"]
    require(
        isinstance(revisions, list)
        and revisions
        and all(isinstance(v, str) and v for v in revisions),
        "invalid_manifest",
    )
    require(
        isinstance(tables, dict)
        and tables
        and all(isinstance(k, str) and type(v) is int and v >= 0 for k, v in tables.items()),
        "invalid_manifest",
    )
    require(bool(SHA256.fullmatch(manifest["category_links_sha256"])), "invalid_manifest")
    sample = manifest["sample"]
    require(
        isinstance(sample, dict)
        and all(type(sample[k]) is int and sample[k] > 0 for k in ("content_id", "asset_id")),
        "invalid_manifest",
    )
    paths = {}
    require(
        set(sample) == {"content_id", "asset_id", "saved_at", "category_ids", "content_sha256"},
        "invalid_manifest",
    )
    require(datetime.fromisoformat(sample["saved_at"]).tzinfo is not None, "invalid_manifest")
    require(
        isinstance(sample["category_ids"], list)
        and all(type(v) is int and v > 0 for v in sample["category_ids"]),
        "invalid_manifest",
    )
    require(bool(SHA256.fullmatch(sample["content_sha256"])), "invalid_manifest")
    for role, filename in (("database", "database.dump"), ("images", "images.tar")):
        entry = manifest[role]
        require(entry["file"] == filename, "invalid_manifest")
        path = directory / filename
        require(not path.is_symlink() and path.is_file(), "invalid_backup_file")
        require(type(entry["size_bytes"]) is int and entry["size_bytes"] > 0, "invalid_manifest")
        require(bool(SHA256.fullmatch(entry["sha256"])), "invalid_manifest")
        require(
            path.stat().st_size == entry["size_bytes"] and sha256_file(path) == entry["sha256"],
            "backup_hash_mismatch",
        )
        paths[role] = path
    files, expanded_size = validate_archive(paths["images"])
    assets = manifest["assets"]
    require(isinstance(assets, list), "invalid_manifest")
    seen = set()
    for asset in assets:
        require(
            type(asset["id"]) is int and asset["id"] > 0 and asset["id"] not in seen,
            "invalid_manifest",
        )
        seen.add(asset["id"])
        key = asset["storage_key"]
        require(
            isinstance(key, str)
            and key
            and not PurePosixPath(key).is_absolute()
            and ".." not in PurePosixPath(key).parts
            and "\\" not in key,
            "invalid_manifest",
        )
        require(
            type(asset["size_bytes"]) is int
            and asset["size_bytes"] >= 0
            and bool(SHA256.fullmatch(asset["sha256"])),
            "invalid_manifest",
        )
        require("screenshots/" + key in files, "missing_asset")
    require(sample["asset_id"] in seen, "invalid_manifest")
    # Reserve space for unpacked files, a generously sized restored DB, and runtime overhead.
    required = expanded_size + paths["database"].stat().st_size * 6 + 1024**3
    require(shutil.disk_usage(tempfile.gettempdir()).free >= required, "insufficient_disk_space")
    return manifest, paths


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
    def __init__(self, docker=None):
        self.docker = docker or Docker()
        self.owner = "clipback-recovery-" + uuid4().hex
        self.created = []

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
        self.create("network", network, "--internal")
        self.create("volume", pg)
        self.create("volume", files)
        password = secrets.token_hex(24)
        with tempfile.TemporaryDirectory(prefix="clipback-recovery-private-") as temporary:
            env = Path(temporary) / "runtime.env"
            env.write_text(
                "\n".join(
                    [
                        "APP_ENVIRONMENT=production",
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
            self.wait("exec", db, "pg_isready", "-U", "postgres", "-d", "clipback")
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
            payload = {
                "sample": {k: manifest["sample"][k] for k in ("content_id", "asset_id")},
                "access_token": credentials["access_token"],
            }
            with tempfile.TemporaryFile() as stream:
                stream.write(json.dumps(payload).encode())
                stream.seek(0)
                actual = json.loads(
                    self.docker("exec", "-i", api, "python", "-c", PROBE, stdin=stream)
                )
            require(all(actual[k] == manifest[k] for k in SNAPSHOT_KEYS), "restored_data_mismatch")
            return {
                "table_count": len(actual["tables"]),
                "asset_count": len(actual["assets"]),
                "extra_file_count": actual["extra_file_count"],
                "authentication_passed": True,
                "image_bytes_passed": True,
            }


def check(directory, credentials_file, image, drill=None):
    started = time.monotonic()
    drill = drill or RestoreDrill()
    report = {"passed": False, "cleanup_passed": False}
    try:
        manifest, paths = load_backup(directory)
        credentials = private_json(credentials_file)
        report.update(backup_id=manifest["backup_id"], origin=manifest["origin"])
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
