"""Operator-only original image recovery points. Never imported by the API."""

import asyncio
import hashlib
import io
import json
import os
import re
import stat
import subprocess
import tarfile
import tempfile
from collections import Counter
from datetime import UTC, datetime
from pathlib import Path
from urllib.parse import urlsplit

import boto3
from botocore.config import Config
from botocore.exceptions import ClientError
from sqlalchemy import text
from sqlalchemy.engine import make_url

from scripts.check_backup_restore import CheckError, load_backup, require, sha256_file


def canonical_json(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode()


def materialize_backup(store, backup_id, directory):
    """Download a complete point into a new private directory; no source is changed."""
    manifest = store.read_manifest(backup_id)
    require(
        manifest.get("format_version") == 2 and manifest.get("backup_id") == backup_id,
        "invalid_manifest",
    )
    directory.mkdir(mode=0o700)
    database = directory / "database.dump"
    store.download_verified(
        f"points/{backup_id}/database.dump",
        database,
        manifest["database"]["size_bytes"],
        manifest["database"]["sha256"],
    )
    archive_path = directory / "images.tar"
    with tarfile.open(archive_path, "w") as archive:
        for asset in manifest["assets"]:
            require(
                asset.get("backup_key") == f"originals/sha256/{asset['sha256']}", "invalid_manifest"
            )
            content = store.read(asset["backup_key"])
            require(
                len(content) == asset["size_bytes"]
                and hashlib.sha256(content).hexdigest() == asset["sha256"],
                "backup_hash_mismatch",
            )
            prefix = "screenshots/" if asset["storage_backend"] == "local" else "s3/"
            member = tarfile.TarInfo(prefix + asset["storage_key"])
            member.size = len(content)
            member.mode = 0o600
            archive.addfile(member, io.BytesIO(content))
    archive_path.chmod(0o600)
    manifest["images"] = {
        "file": "images.tar",
        "size_bytes": archive_path.stat().st_size,
        "sha256": sha256_file(archive_path),
    }
    path = directory / "manifest.json"
    path.write_bytes(canonical_json(manifest))
    path.chmod(0o600)
    load_backup(directory)
    return manifest


class BackupBucket:
    def __init__(self, client, bucket):
        self.client, self.bucket = client, bucket

    @classmethod
    def from_config_file(cls, path):
        require(not path.is_symlink(), "credentials_not_private")
        info = path.stat()
        require(
            stat.S_ISREG(info.st_mode)
            and stat.S_IMODE(info.st_mode) == 0o600
            and info.st_uid == os.getuid(),
            "credentials_not_private",
        )
        return cls.from_config(json.loads(path.read_text()))

    @classmethod
    def from_environment(cls):
        """Consume secret JSON directly; no shell expansion or credential file needed."""
        raw = os.environ.pop("BACKUP_BUCKET_CONFIG_JSON", None)
        require(bool(raw), "backup_configuration_missing")
        try:
            config = json.loads(raw)
        except (ValueError, TypeError) as exc:
            raise CheckError("invalid_credentials") from exc
        return cls.from_config(config)

    @classmethod
    def from_config(cls, config):
        require(
            isinstance(config, dict)
            and set(config).issubset(
                {
                    "endpoint_url",
                    "bucket",
                    "region",
                    "addressing_style",
                    "access_key_id",
                    "secret_access_key",
                }
            ),
            "invalid_credentials",
        )
        require(
            all(
                isinstance(config.get(k), str)
                and config[k].strip()
                and "\n" not in config[k]
                and "\r" not in config[k]
                for k in ("endpoint_url", "bucket", "access_key_id", "secret_access_key")
            ),
            "invalid_credentials",
        )
        endpoint = urlsplit(config["endpoint_url"])
        require(
            endpoint.scheme == "https"
            or (
                endpoint.scheme == "http" and endpoint.hostname in {"localhost", "127.0.0.1", "::1"}
            ),
            "invalid_credentials",
        )
        require(
            not endpoint.username
            and not endpoint.password
            and not endpoint.query
            and not endpoint.fragment,
            "invalid_credentials",
        )
        require(
            config.get("addressing_style", "virtual") in {"virtual", "path"}, "invalid_credentials"
        )
        client = boto3.client(
            "s3",
            endpoint_url=config["endpoint_url"],
            region_name=config.get("region", "auto"),
            aws_access_key_id=config["access_key_id"],
            aws_secret_access_key=config["secret_access_key"],
            config=Config(
                signature_version="s3v4",
                connect_timeout=3,
                read_timeout=30,
                retries={"total_max_attempts": 2},
                s3={"addressing_style": config.get("addressing_style", "virtual")},
            ),
        )
        return cls(client, config["bucket"])

    def read(self, key):
        try:
            response = self.client.get_object(Bucket=self.bucket, Key=key)
            with response["Body"] as stream:
                return stream.read()
        except ClientError as exc:
            if exc.response["Error"]["Code"] in {"NoSuchKey", "404", "NotFound"}:
                raise FileNotFoundError("Backup object missing") from exc
            raise CheckError("backup_store_unavailable") from exc

    def put_verified(self, key, value):
        self.client.put_object(Bucket=self.bucket, Key=key, Body=value)
        require(self.read(key) == value, "backup_hash_mismatch")

    def delete_verified(self, key):
        self.client.delete_object(Bucket=self.bucket, Key=key)
        try:
            self.client.head_object(Bucket=self.bucket, Key=key)
        except ClientError as exc:
            if exc.response["Error"]["Code"] in {"NoSuchKey", "404", "NotFound"}:
                return
            raise CheckError("backup_cleanup_unverified") from exc
        raise CheckError("backup_cleanup_unverified")

    def verify_present(self, key, size_bytes):
        try:
            response = self.client.head_object(Bucket=self.bucket, Key=key)
        except ClientError as exc:
            raise CheckError("backup_object_missing_or_unavailable") from exc
        require(response["ContentLength"] == size_bytes, "backup_hash_mismatch")

    def verify_object(self, key, size_bytes, digest):
        response = self.client.get_object(Bucket=self.bucket, Key=key)
        actual, size = hashlib.sha256(), 0
        with response["Body"] as source:
            for block in iter(lambda: source.read(1024 * 1024), b""):
                actual.update(block)
                size += len(block)
        require(size == size_bytes and actual.hexdigest() == digest, "backup_hash_mismatch")

    def download_verified(self, key, destination, size_bytes, digest):
        response = self.client.get_object(Bucket=self.bucket, Key=key)
        actual, size = hashlib.sha256(), 0
        with response["Body"] as source:
            with destination.open("xb") as target:
                destination.chmod(0o600)
                for block in iter(lambda: source.read(1024 * 1024), b""):
                    target.write(block)
                    actual.update(block)
                    size += len(block)
        require(size == size_bytes and actual.hexdigest() == digest, "backup_hash_mismatch")

    def put_file_verified(self, key, path):
        size, digest = path.stat().st_size, sha256_file(path)
        with path.open("rb") as source:
            self.client.put_object(Bucket=self.bucket, Key=key, Body=source, ContentLength=size)
        with tempfile.TemporaryDirectory(prefix="clipback-backup-verify-") as temporary:
            self.download_verified(key, Path(temporary) / "readback", size, digest)

    def list_objects(self, prefix="", *, include_dates=False):
        return [
            {"key": item["Key"], "size_bytes": item["Size"],
             **({"last_modified": item["LastModified"].isoformat()} if include_dates else {})}
            for page in self.client.get_paginator("list_objects_v2").paginate(
                Bucket=self.bucket, Prefix=prefix
            )
            for item in page.get("Contents", [])
        ]

    def completed_points(self):
        return sorted(
            entry["key"].split("/")[1]
            for entry in self.list_objects("points/")
            if re.fullmatch(r"points/[A-Za-z0-9._-]{1,100}/manifest.json", entry["key"])
        )

    def read_manifest(self, backup_id):
        require(bool(re.fullmatch(r"[A-Za-z0-9._-]{1,100}", backup_id)), "invalid_backup_id")
        return json.loads(self.read(f"points/{backup_id}/manifest.json"))


def verify_backup(store, backup_id):
    """Read every referenced object without writing a local DB/image copy."""
    manifest = store.read_manifest(backup_id)
    require(manifest.get("format_version") == 2 and manifest.get("backup_id") == backup_id,
            "invalid_manifest")
    database, assets = manifest["database"], manifest["assets"]
    require(database["backup_key"] == f"points/{backup_id}/database.dump", "invalid_manifest")
    require(isinstance(assets, list), "invalid_manifest")
    for asset in assets:
        require(asset.get("storage_backend") in {"local", "s3"}
                and asset.get("backup_key") == "originals/sha256/" + asset["sha256"],
                "invalid_manifest")
    objects = [database, *assets]
    for item in objects:
        require(type(item["size_bytes"]) is int and item["size_bytes"] >= 0
                and bool(re.fullmatch(r"[0-9a-f]{64}", item["sha256"])), "invalid_manifest")
        store.verify_object(item["backup_key"], item["size_bytes"], item["sha256"])
    # Detect retirement/replacement during verification without taking a write lock.
    require(store.read_manifest(backup_id) == manifest, "backup_point_changed")
    return {
        "passed": True, "backup_id": backup_id, "captured_at": manifest["captured_at"],
        "asset_counts": dict(Counter(a["storage_backend"] for a in assets)),
        "verified_objects": len(objects), "total_bytes": sum(i["size_bytes"] for i in objects),
        "all_sizes_and_sha256_match": True, "app_commit": manifest["app_commit"],
        "migration_revisions": manifest["migration_revisions"],
        "has_deletion_checkpoint": isinstance(manifest.get("deletion_checkpoint"), dict),
        "restore_verified": False, "live_deletion_ledger_verified": False,
    }


async def publish_backup(
    store,
    *,
    backup_id,
    snapshot,
    database,
    storage,
    captured_at,
    app_commit,
    postgres_major,
    origin,
    deletion_checkpoint=None,
):
    """Publish manifest last. Caller holds the paired DB snapshot / write freeze."""
    require(bool(re.fullmatch(r"[A-Za-z0-9._-]{1,100}", backup_id)), "invalid_backup_id")
    require(backup_id not in store.completed_points(), "backup_id_exists")
    try:
        await asyncio.to_thread(store.read, f"gc/points/{backup_id}.json")
    except FileNotFoundError:
        pass
    else:
        raise CheckError("backup_id_retiring")
    if any(asset["storage_backend"] == "s3" for asset in snapshot["assets"]):
        source = storage.for_backend("s3")
        require(
            source.bucket != store.bucket
            or source.client.meta.endpoint_url.rstrip("/")
            != store.client.meta.endpoint_url.rstrip("/"),
            "backup_bucket_must_be_separate",
        )
    assets = []
    for asset in snapshot["assets"]:
        content = await storage.read_file(asset["storage_key"], backend=asset["storage_backend"])
        digest = hashlib.sha256(content).hexdigest()
        require(
            len(content) == asset["size_bytes"] and digest == asset["sha256"],
            "original_hash_mismatch",
        )
        key = f"originals/sha256/{digest}"
        try:
            existing = await asyncio.to_thread(store.read, key)
        except FileNotFoundError:
            await asyncio.to_thread(store.put_verified, key, content)
        else:
            require(existing == content, "backup_hash_mismatch")
        assets.append({**asset, "backup_key": key})
    size, digest = database.stat().st_size, sha256_file(database)
    require(size > 0, "invalid_backup_file")
    key = f"points/{backup_id}/database.dump"
    await asyncio.to_thread(store.put_file_verified, key, database)
    manifest = {
        **snapshot,
        "assets": assets,
        "format_version": 2,
        "backup_id": backup_id,
        "origin": origin,
        "captured_at": captured_at,
        "app_commit": app_commit,
        "postgres_major": postgres_major,
        "database": {
            "file": "database.dump",
            "backup_key": key,
            "size_bytes": size,
            "sha256": digest,
        },
        "deletion_checkpoint": deletion_checkpoint,
    }
    await asyncio.to_thread(
        store.put_verified, f"points/{backup_id}/manifest.json", canonical_json(manifest)
    )
    return manifest


def dump_database(database_url, snapshot_id, destination, pg_dump="pg_dump", postgres_major=None):
    """Credentials go in the child environment, never argv or error output."""
    url = make_url(database_url)
    environment = os.environ.copy()
    environment.update(
        PGHOST=url.host or "localhost",
        PGPORT=str(url.port or 5432),
        PGDATABASE=url.database or "",
        PGUSER=url.username or "",
        PGPASSWORD=url.password or "",
    )
    sslmode = url.query.get("sslmode", url.query.get("ssl"))
    if sslmode is not None:
        require(sslmode in {"disable", "allow", "prefer", "require", "verify-ca", "verify-full"},
                "unsupported_database_ssl")
        environment["PGSSLMODE"] = sslmode
    try:
        version = subprocess.run(
            [pg_dump, "--version"],
            env=environment,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=10,
        )
        match = re.search(rb"pg_dump \(PostgreSQL\) (\d+)", version.stdout)
        require(match is not None and int(match[1]) == postgres_major, "pg_dump_version_mismatch")
        subprocess.run(
            [
                pg_dump,
                "-Fc",
                "--no-owner",
                "--no-acl",
                "--snapshot",
                snapshot_id,
                "--file",
                str(destination),
            ],
            env=environment,
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            timeout=3600,
        )
    except (OSError, subprocess.SubprocessError) as exc:
        raise CheckError("database_dump_failed") from exc


async def create_backup(
    store,
    *,
    backup_id,
    sample,
    app_commit,
    origin,
    writers_frozen,
    pg_dump="pg_dump",
    deletion_checkpoint=None,
    ledger=None,
    _job_locked=False,
    runtime=None,
):
    """Capture a frozen source or an online snapshot coordinated with its live ledger."""
    from app.integrations.deletion_ledger import IMAGE_CLEANUP_LOCK, LEDGER_WRITE_LOCK
    from scripts.recovery_probe import snapshot

    if runtime is not None:
        await runtime.preflight_source()
    if runtime is None:
        from app.core.config import settings
        from app.db.session import engine
        from app.integrations.storage_client import get_storage_client

        database_url, storage = settings.database_url, get_storage_client()
    else:
        engine, database_url, storage = (
            runtime.engine, runtime.config.database_url, runtime.storage
        )

    require(writers_frozen is True or ledger is not None, "source_write_freeze_required")
    require(bool(re.fullmatch(r"[0-9a-f]{40}", app_commit)), "invalid_manifest")
    require(origin in {"production", "synthetic"}, "invalid_manifest")
    if not _job_locked:
        from scripts.image_backup_jobs import BACKUP_JOB_LOCK, source_lock

        async with source_lock(BACKUP_JOB_LOCK, try_only=True, engine=engine):
            return await create_backup(
                store, backup_id=backup_id, sample=sample, app_commit=app_commit, origin=origin,
                writers_frozen=writers_frozen, pg_dump=pg_dump,
                deletion_checkpoint=deletion_checkpoint, ledger=ledger, _job_locked=True,
                runtime=runtime,
            )
    async with engine.connect() as connection:
        await connection.execute(text("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY"))
        ledger_locked = physical_locked = False
        try:
            if ledger is not None:
                await connection.execute(
                    text("SELECT pg_advisory_lock_shared(:key)"), {"key": LEDGER_WRITE_LOCK}
                )
                ledger_locked = True
            await connection.execute(
                text("SELECT pg_advisory_lock_shared(:key)"), {"key": IMAGE_CLEANUP_LOCK}
            )
            physical_locked = True
            snapshot_id = await connection.scalar(text("SELECT pg_export_snapshot()"))
            if ledger is not None:
                deletion_checkpoint = await asyncio.to_thread(ledger.read_checkpoint_tip)
                # Exported DB snapshot + immutable originals remain protected by the physical lock.
                # New deletion acknowledgements need not wait for the dump and object copies.
                await connection.execute(
                    text("SELECT pg_advisory_unlock_shared(:key)"), {"key": LEDGER_WRITE_LOCK}
                )
                ledger_locked = False
                await asyncio.to_thread(ledger.read_verified_events, deletion_checkpoint)
            major = int(await connection.scalar(text("SHOW server_version_num"))) // 10000
            captured_at = datetime.now(UTC).isoformat()
            data = await snapshot(
                {
                    "format_version": 2,
                    "snapshot_id": snapshot_id,
                    "sample": sample,
                    "verify_api": False,
                },
                runtime=runtime,
            )
            with tempfile.TemporaryDirectory(prefix="clipback-backup-private-") as temporary:
                path = Path(temporary) / "database.dump"
                await asyncio.to_thread(
                    dump_database, database_url, snapshot_id, path, pg_dump, major
                )
                path.chmod(0o600)
                return await publish_backup(
                    store,
                    backup_id=backup_id,
                    snapshot=data,
                    database=path,
                    storage=storage,
                    captured_at=captured_at,
                    app_commit=app_commit,
                    postgres_major=major,
                    origin=origin,
                    deletion_checkpoint=deletion_checkpoint,
                )
        finally:
            # Keep this exact physical connection checked out through rollback/unlock.
            # A failed SQL transaction must not return a session lock to the pool.
            try:
                await connection.rollback()
                if ledger_locked:
                    await connection.execute(
                        text("SELECT pg_advisory_unlock_shared(:key)"), {"key": LEDGER_WRITE_LOCK}
                    )
                if physical_locked:
                    await connection.execute(
                        text("SELECT pg_advisory_unlock_shared(:key)"), {"key": IMAGE_CLEANUP_LOCK}
                    )
            except BaseException:
                await connection.invalidate()
                raise


def main():
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--backup-config-file", type=Path,
                        help="Private JSON file; otherwise BACKUP_BUCKET_CONFIG_JSON is consumed")
    sub = parser.add_subparsers(dest="command", required=True)
    create = sub.add_parser("create")
    create.add_argument("--backup-id", required=True)
    create.add_argument("--sample-file", type=Path, required=True)
    create.add_argument("--app-commit", required=True)
    create.add_argument("--origin", choices=["production", "synthetic"], required=True)
    create.add_argument("--writers-frozen", action="store_true")
    create.add_argument("--pg-dump", default="pg_dump")
    create.add_argument("--capture-deletion-checkpoint", action="store_true")
    download = sub.add_parser("download")
    download.add_argument("--backup-id", required=True)
    download.add_argument("--directory", type=Path, required=True)
    verify = sub.add_parser("verify")
    verify.add_argument("--backup-id", required=True)
    args = parser.parse_args()
    try:
        store = (BackupBucket.from_config_file(args.backup_config_file)
                 if args.backup_config_file else BackupBucket.from_environment())
        if args.command == "verify":
            print(json.dumps(verify_backup(store, args.backup_id), sort_keys=True))
            return 0
        if args.command == "create":
            from app.integrations.deletion_ledger import get_deletion_ledger
            from scripts.operator_runtime import OperatorRuntime

            async def capture():
                runtime = OperatorRuntime()
                try:
                    from app.services.maintenance import MaintenanceGate
                    async with MaintenanceGate(runtime.sessions).operation("backup_create"):
                        return await create_backup(
                            store,
                            backup_id=args.backup_id,
                            sample=json.loads(args.sample_file.read_text()),
                            app_commit=args.app_commit,
                            origin=args.origin,
                            writers_frozen=args.writers_frozen,
                            pg_dump=args.pg_dump,
                            ledger=get_deletion_ledger(runtime.config)
                            if args.capture_deletion_checkpoint else None,
                            runtime=runtime,
                        )
                finally:
                    await runtime.close()

            manifest = asyncio.run(capture())
        else:
            manifest = materialize_backup(store, args.backup_id, args.directory)
        print(
            json.dumps(
                {
                    "passed": True,
                    "backup_id": manifest["backup_id"],
                    "asset_count": len(manifest["assets"]),
                    "deletions_applied": False,
                },
                sort_keys=True,
            )
        )
        return 0
    except Exception as exc:
        code = str(exc) if isinstance(exc, CheckError) else "backup_operation_failed"
        print(json.dumps({"passed": False, "error": code}, sort_keys=True))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
