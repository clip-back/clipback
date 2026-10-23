"""Operator backup boundary, with a real in-memory S3 service and synthetic bytes."""

import hashlib
import json
from datetime import UTC, datetime

import boto3
import pytest
from moto import mock_aws
from pydantic import SecretStr

from app.core.config import Settings
from app.integrations.storage_client import StorageRouter
from scripts.check_backup_restore import CheckError, load_backup
from scripts.image_backup import BackupBucket, materialize_backup, publish_backup


@pytest.fixture
def recovery_store(tmp_path):
    with mock_aws():
        client = boto3.client("s3", region_name="us-east-1")
        client.create_bucket(Bucket="private-backup")
        yield BackupBucket(client, "private-backup"), client


def source_snapshot():
    return {
        "migration_revisions": ["202610230015"],
        "tables": {"users": 1, "content_assets": 1},
        "category_links_sha256": "c" * 64,
        "assets": [
            {
                "id": 1,
                "content_id": 1,
                "storage_backend": "local",
                "storage_key": "a.png",
                "size_bytes": 5,
                "sha256": "6105d6cc76af400325e94d588ce511be5bfdbb73b437dc51eca43917d7a43e3d",
            }
        ],
        "sample": {
            "content_id": 1,
            "asset_id": 1,
            "saved_at": "2026-10-23T00:00:00+00:00",
            "category_ids": [],
            "content_sha256": "d" * 64,
        },
        "extra_file_count": 0,
    }


@pytest.mark.asyncio
async def test_complete_points_reuse_unchanged_originals(recovery_store, tmp_path):
    store, client = recovery_store
    root = tmp_path / "originals"
    root.mkdir()
    (root / "a.png").write_bytes(b"image")
    storage = StorageRouter(
        Settings(_env_file=None, youtube_summary_enabled=False, storage_root=root)
    )
    dump = tmp_path / "database.dump"
    dump.write_bytes(b"synthetic dump")
    for point in ("first", "second"):
        manifest = await publish_backup(
            store,
            backup_id=point,
            snapshot=source_snapshot(),
            database=dump,
            storage=storage,
            captured_at=datetime.now(UTC).isoformat(),
            app_commit="a" * 40,
            postgres_major=17,
            origin="synthetic",
        )
        assert manifest["format_version"] == 2
        assert store.read_manifest(point) == manifest
    keys = [x["Key"] for x in client.list_objects_v2(Bucket="private-backup")["Contents"]]
    assert len([key for key in keys if key.startswith("originals/")]) == 1
    assert store.completed_points() == ["first", "second"]
    assert (
        hashlib.sha256((root / "a.png").read_bytes()).hexdigest()
        == source_snapshot()["assets"][0]["sha256"]
    )


@pytest.mark.asyncio
async def test_missing_or_changed_original_never_publishes_point(recovery_store, tmp_path):
    store, _ = recovery_store
    storage = StorageRouter(
        Settings(_env_file=None, youtube_summary_enabled=False, storage_root=tmp_path)
    )
    dump = tmp_path / "database.dump"
    dump.write_bytes(b"dump")
    kwargs = dict(
        backup_id="incomplete",
        snapshot=source_snapshot(),
        database=dump,
        storage=storage,
        captured_at=datetime.now(UTC).isoformat(),
        app_commit="a" * 40,
        postgres_major=17,
        origin="synthetic",
    )
    with pytest.raises(FileNotFoundError):
        await publish_backup(store, **kwargs)
    (tmp_path / "a.png").write_bytes(b"wrong")
    with pytest.raises(CheckError, match="original_hash_mismatch"):
        await publish_backup(store, **kwargs)
    assert store.completed_points() == []


@pytest.mark.asyncio
async def test_materialized_point_verifies_every_object_before_restore(recovery_store, tmp_path):
    store, client = recovery_store
    (tmp_path / "a.png").write_bytes(b"image")
    dump = tmp_path / "database.dump"
    dump.write_bytes(b"dump")
    storage = StorageRouter(
        Settings(_env_file=None, youtube_summary_enabled=False, storage_root=tmp_path)
    )
    await publish_backup(
        store,
        backup_id="point",
        snapshot=source_snapshot(),
        database=dump,
        storage=storage,
        captured_at=datetime.now(UTC).isoformat(),
        app_commit="a" * 40,
        postgres_major=17,
        origin="synthetic",
    )
    directory = tmp_path / "download"
    materialize_backup(store, "point", directory)
    manifest, _ = load_backup(directory)
    assert manifest["assets"][0]["storage_backend"] == "local"
    key = manifest["assets"][0]["backup_key"]
    client.put_object(Bucket=store.bucket, Key=key, Body=b"broken")
    with pytest.raises(CheckError, match="backup_hash_mismatch"):
        materialize_backup(store, "point", tmp_path / "corrupt")


def test_operator_credentials_are_private_and_not_api_settings(tmp_path):
    credentials = tmp_path / "operator.json"
    credentials.write_text(
        json.dumps(
            {
                "endpoint_url": "http://127.0.0.1:5000",
                "bucket": "private-backup",
                "access_key_id": "testing",
                "secret_access_key": "testing",
                "addressing_style": "path",
            }
        )
    )
    credentials.chmod(0o644)
    with pytest.raises(CheckError, match="credentials_not_private"):
        BackupBucket.from_config_file(credentials)
    credentials.chmod(0o600)
    assert BackupBucket.from_config_file(credentials).bucket == "private-backup"
    assert not any(name.startswith("backup_") for name in Settings.model_fields)


@pytest.mark.asyncio
async def test_primary_bucket_cannot_also_be_backup_destination(recovery_store, tmp_path):
    store, _ = recovery_store
    snapshot = source_snapshot()
    snapshot["assets"][0]["storage_backend"] = "s3"
    config = Settings(
        _env_file=None,
        youtube_summary_enabled=False,
        storage_backend="s3",
        s3_bucket="private-backup",
        s3_endpoint_url="https://s3.amazonaws.com",
        s3_region="us-east-1",
        s3_access_key_id=SecretStr("testing"),
        s3_secret_access_key=SecretStr("testing"),
    )
    with pytest.raises(CheckError, match="backup_bucket_must_be_separate"):
        await publish_backup(
            store,
            backup_id="wrong-destination",
            snapshot=snapshot,
            database=tmp_path / "unused",
            storage=StorageRouter(config),
            captured_at=datetime.now(UTC).isoformat(),
            app_commit="a" * 40,
            postgres_major=17,
            origin="synthetic",
        )


@pytest.mark.asyncio
async def test_incomplete_backup_object_does_not_count_as_complete(recovery_store, tmp_path):
    store, client = recovery_store
    client.put_object(Bucket=store.bucket, Key="points/interrupted/database.dump", Body=b"partial")
    assert store.completed_points() == []
    with pytest.raises(FileNotFoundError):
        materialize_backup(store, "interrupted", tmp_path / "no-complete-point")


@pytest.mark.asyncio
async def test_backup_requires_explicit_source_write_freeze(recovery_store):
    from scripts.image_backup import create_backup

    store, _ = recovery_store
    with pytest.raises(CheckError, match="source_write_freeze_required"):
        await create_backup(
            store,
            backup_id="unsafe",
            sample={},
            app_commit="a" * 40,
            origin="synthetic",
            writers_frozen=False,
        )


@pytest.mark.asyncio
async def test_destination_access_denied_does_not_publish_completed_point(recovery_store, tmp_path):
    from botocore.exceptions import ClientError

    store, client = recovery_store
    (tmp_path / "a.png").write_bytes(b"image")
    dump = tmp_path / "database.dump"
    dump.write_bytes(b"dump")
    client.put_bucket_policy(
        Bucket=store.bucket,
        Policy=json.dumps(
            {
                "Version": "2012-10-17",
                "Statement": [
                    {
                        "Effect": "Deny",
                        "Principal": "*",
                        "Action": "s3:PutObject",
                        "Resource": "arn:aws:s3:::private-backup/points/*",
                    }
                ],
            }
        ),
    )
    config = Settings(_env_file=None, youtube_summary_enabled=False, storage_root=tmp_path)
    with pytest.raises(ClientError):
        await publish_backup(
            store,
            backup_id="denied",
            snapshot=source_snapshot(),
            database=dump,
            storage=StorageRouter(config),
            captured_at=datetime.now(UTC).isoformat(),
            app_commit="a" * 40,
            postgres_major=17,
            origin="synthetic",
        )
    assert store.completed_points() == []
