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
from datetime import UTC, datetime
from pathlib import Path
from urllib.parse import urlsplit

import boto3
from botocore.config import Config
from botocore.exceptions import ClientError
from sqlalchemy import text
from sqlalchemy.engine import make_url

from scripts.check_backup_restore import CheckError, load_backup, require, sha256_file

PHYSICAL_CLEANUP_LOCK = 74264001


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
    dump = store.read(f"points/{backup_id}/database.dump")
    require(
        len(dump) == manifest["database"]["size_bytes"]
        and hashlib.sha256(dump).hexdigest() == manifest["database"]["sha256"],
        "backup_hash_mismatch",
    )
    database = directory / "database.dump"
    database.write_bytes(dump)
    database.chmod(0o600)
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
        config = json.loads(path.read_text())
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

    def list_objects(self, prefix=""):
        return [
            {"key": item["Key"], "size_bytes": item["Size"]}
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
    dump = database.read_bytes()
    require(bool(dump), "invalid_backup_file")
    key = f"points/{backup_id}/database.dump"
    await asyncio.to_thread(store.put_verified, key, dump)
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
            "size_bytes": len(dump),
            "sha256": hashlib.sha256(dump).hexdigest(),
        },
        "deletion_checkpoint": deletion_checkpoint,
    }
    await asyncio.to_thread(
        store.put_verified, f"points/{backup_id}/manifest.json", canonical_json(manifest)
    )
    return manifest


def dump_database(database_url, snapshot_id, destination, pg_dump="pg_dump"):
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
    if "sslmode" in url.query:
        environment["PGSSLMODE"] = url.query["sslmode"]
    try:
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
):
    """Capture one paired point. The operator must first stop all source writers."""
    from app.core.config import settings
    from app.db.session import AsyncSessionLocal
    from app.integrations.storage_client import get_storage_client
    from scripts.recovery_probe import snapshot

    require(writers_frozen is True, "source_write_freeze_required")
    require(bool(re.fullmatch(r"[0-9a-f]{40}", app_commit)), "invalid_manifest")
    require(origin in {"production", "synthetic"}, "invalid_manifest")
    async with AsyncSessionLocal() as session:
        await session.execute(text("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY"))
        await session.execute(text(f"SELECT pg_advisory_lock_shared({PHYSICAL_CLEANUP_LOCK})"))
        try:
            snapshot_id = await session.scalar(text("SELECT pg_export_snapshot()"))
            major = int(await session.scalar(text("SHOW server_version_num"))) // 10000
            captured_at = datetime.now(UTC).isoformat()
            data = await snapshot(
                {
                    "format_version": 2,
                    "snapshot_id": snapshot_id,
                    "sample": sample,
                    "verify_api": False,
                }
            )
            with tempfile.TemporaryDirectory(prefix="clipback-backup-private-") as temporary:
                path = Path(temporary) / "database.dump"
                await asyncio.to_thread(
                    dump_database, settings.database_url, snapshot_id, path, pg_dump
                )
                path.chmod(0o600)
                return await publish_backup(
                    store,
                    backup_id=backup_id,
                    snapshot=data,
                    database=path,
                    storage=get_storage_client(),
                    captured_at=captured_at,
                    app_commit=app_commit,
                    postgres_major=major,
                    origin=origin,
                    deletion_checkpoint=deletion_checkpoint,
                )
        finally:
            await session.execute(
                text(f"SELECT pg_advisory_unlock_shared({PHYSICAL_CLEANUP_LOCK})")
            )


def main():
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--backup-config-file", type=Path, required=True)
    sub = parser.add_subparsers(dest="command", required=True)
    create = sub.add_parser("create")
    create.add_argument("--backup-id", required=True)
    create.add_argument("--sample-file", type=Path, required=True)
    create.add_argument("--app-commit", required=True)
    create.add_argument("--origin", choices=["production", "synthetic"], required=True)
    create.add_argument("--writers-frozen", action="store_true")
    create.add_argument("--pg-dump", default="pg_dump")
    download = sub.add_parser("download")
    download.add_argument("--backup-id", required=True)
    download.add_argument("--directory", type=Path, required=True)
    args = parser.parse_args()
    try:
        store = BackupBucket.from_config_file(args.backup_config_file)
        if args.command == "create":
            sample = json.loads(args.sample_file.read_text())
            manifest = asyncio.run(
                create_backup(
                    store,
                    backup_id=args.backup_id,
                    sample=sample,
                    app_commit=args.app_commit,
                    origin=args.origin,
                    writers_frozen=args.writers_frozen,
                    pg_dump=args.pg_dump,
                )
            )
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
