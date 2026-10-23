"""Retention is observed through the operator boundary and the independent stores."""

import hashlib
import json
from datetime import UTC, datetime, timedelta
from uuid import uuid4

import boto3
import pytest
from moto import mock_aws

from app.integrations.deletion_ledger import DeletionLedger, LocalLedgerStore
from scripts.image_backup import BackupBucket


@pytest.fixture
def stores(tmp_path):
    with mock_aws():
        client = boto3.client("s3", region_name="us-east-1")
        client.create_bucket(Bucket="private-backup")
        ledger = DeletionLedger(LocalLedgerStore(tmp_path / "ledger"))
        ledger.initialize()
        yield BackupBucket(client, "private-backup"), ledger


def point(store, identifier, when, assets):
    manifest = {
        "format_version": 2, "backup_id": identifier, "captured_at": when.isoformat(),
        "assets": assets, "deletion_checkpoint": None,
        "database": {"backup_key": f"points/{identifier}/database.dump", "size_bytes": 4},
    }
    store.put_verified(f"points/{identifier}/database.dump", b"dump")
    store.put_verified(f"points/{identifier}/manifest.json", json.dumps(manifest).encode())
    return manifest


def original(store, name="old.png", content_id=1, body=b"old"):
    digest = hashlib.sha256(body).hexdigest()
    key = "originals/sha256/" + digest
    store.put_verified(key, body)
    return {
        "storage_backend": "s3", "storage_key": name, "sha256": digest,
        "size_bytes": len(body), "content_id": content_id, "backup_key": key,
    }


def deleted(ledger, asset, when):
    return ledger.append({
        "operation_id": str(uuid4()), "user_id": 1, "content_id": asset["content_id"],
        "saved_at": "2026-10-01T00:00:00+00:00", "deleted_at": when.isoformat(),
        "assets": [{k: asset[k] for k in (
            "storage_backend", "storage_key", "sha256", "size_bytes",
        )}],
    })


def test_deleted_copies_expire_with_margin_but_live_shared_bytes_survive(stores):
    from scripts.image_backup_jobs import maintain_backups

    store, ledger = stores
    now = datetime(2026, 10, 23, tzinfo=UTC)
    asset = original(store)
    point(store, "before-delete", now - timedelta(days=6, hours=1), [asset])
    deleted(ledger, asset, now - timedelta(days=6))
    shared = {**asset, "storage_key": "another-user.png", "content_id": 2}
    point(store, "current", now, [shared])
    report = maintain_backups(store, ledger, now=now)
    assert report["passed"] is True
    assert store.completed_points() == ["current"]
    assert store.read(asset["backup_key"]) == b"old"
    assert ledger.read_verified_checkpoint()["sequence"] == 1


def test_seven_day_boundary_removes_old_points_and_unreferenced_bytes(stores):
    from scripts.image_backup_jobs import maintain_backups

    store, ledger = stores
    now = datetime(2026, 10, 23, tzinfo=UTC)
    asset = original(store)
    point(store, "expired", now - timedelta(days=7), [asset])
    point(store, "current-empty", now, [])
    report = maintain_backups(store, ledger, now=now)
    assert report["passed"] is True
    assert store.completed_points() == ["current-empty"]
    with pytest.raises(FileNotFoundError):
        store.read(asset["backup_key"])


def test_restore_refuses_missing_regressed_or_different_live_ledger(stores):
    from scripts.check_backup_restore import CheckError
    from scripts.image_backup_jobs import latest_deletions

    _, ledger = stores
    checkpoint = ledger.read_verified_checkpoint()
    assert latest_deletions(ledger, checkpoint)[1] == []
    with pytest.raises(CheckError, match="deletion_checkpoint_required"):
        latest_deletions(ledger, None)
    with pytest.raises(CheckError, match="deletion_ledger_regressed"):
        latest_deletions(ledger, {**checkpoint, "sequence": 1})
    with pytest.raises(CheckError, match="deletion_namespace_mismatch"):
        latest_deletions(ledger, {**checkpoint, "namespace": str(uuid4())})


def test_missing_ledger_never_prunes_valid_recovery_points(stores):
    from app.integrations.deletion_ledger import LedgerUnavailableError
    from scripts.image_backup_jobs import maintain_backups

    store, ledger = stores
    now = datetime.now(UTC)
    asset = original(store)
    point(store, "old", now - timedelta(days=9), [asset])
    (ledger.store.root / "head.json").unlink()
    with pytest.raises(LedgerUnavailableError):
        maintain_backups(store, ledger, now=now)
    assert store.completed_points() == ["old"]
    assert store.read(asset["backup_key"]) == b"old"


def test_cleanup_failure_is_not_reported_as_success_and_retry_finishes(stores):
    from botocore.exceptions import ClientError

    from scripts.image_backup_jobs import maintain_backups

    store, ledger = stores
    now = datetime.now(UTC)
    asset = original(store)
    point(store, "old", now - timedelta(days=8), [asset])
    point(store, "current", now, [])
    store.client.put_bucket_policy(Bucket=store.bucket, Policy=json.dumps({
        "Version": "2012-10-17", "Statement": [{
            "Effect": "Deny", "Principal": "*", "Action": "s3:DeleteObject",
            "Resource": "arn:aws:s3:::private-backup/*",
        }],
    }))
    with pytest.raises(ClientError):
        maintain_backups(store, ledger, now=now)
    assert store.completed_points() == ["current", "old"]
    store.client.delete_bucket_policy(Bucket=store.bucket)
    assert maintain_backups(store, ledger, now=now)["passed"]
    assert store.completed_points() == ["current"]


def test_deleted_copy_stays_restorable_before_cleanup_margin(stores):
    from scripts.image_backup_jobs import maintain_backups

    store, ledger = stores
    now = datetime.now(UTC)
    asset = original(store)
    point(store, "before", now - timedelta(hours=1), [asset])
    deleted(ledger, asset, now - timedelta(days=6) + timedelta(seconds=1))
    assert maintain_backups(store, ledger, now=now)["passed"]
    assert store.completed_points() == ["before"]


def test_corrupt_point_does_not_destroy_other_points_or_blobs(stores):
    from scripts.image_backup_jobs import maintain_backups

    store, ledger = stores
    now = datetime.now(UTC)
    asset = original(store)
    point(store, "valid", now - timedelta(days=8), [asset])
    store.put_verified("points/corrupt/manifest.json", b"not json")
    with pytest.raises(ValueError):
        maintain_backups(store, ledger, now=now)
    assert "valid" in store.completed_points()
    assert store.read(asset["backup_key"]) == b"old"


def test_cleanup_after_deadline_reports_missed_goal_even_if_retry_removes_copy(stores):
    from scripts.image_backup_jobs import maintain_backups

    store, ledger = stores
    now = datetime.now(UTC)
    asset = original(store)
    point(store, "before", now - timedelta(days=8), [asset])
    point(store, "current", now, [])
    deleted(ledger, asset, now - timedelta(days=7))
    report = maintain_backups(store, ledger, now=now)
    assert report["passed"] is False
    assert report["retention_overdue"] == 1
    assert store.list_objects("originals/") == []


def test_point_with_missing_original_is_not_a_healthy_completed_backup(stores):
    from scripts.check_backup_restore import CheckError
    from scripts.image_backup_jobs import maintain_backups

    store, ledger = stores
    now = datetime.now(UTC)
    asset = original(store)
    point(store, "current", now, [asset])
    store.delete_verified(asset["backup_key"])
    with pytest.raises(CheckError, match="backup_object_missing_or_unavailable"):
        maintain_backups(store, ledger, now=now)
