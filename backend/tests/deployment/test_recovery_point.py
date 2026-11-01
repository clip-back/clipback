"""Recovery point module interface: key layout, formats, published and downloaded points."""

import json

import boto3
import pytest
from moto import mock_aws

from scripts import recovery_point
from scripts.operator_errors import CheckError
from tests.deployment.test_recovery_point_bucket_outputs import BUCKET, canonical, manifest
from tests.deployment.test_recovery_point_folder_outputs import write_folder

SHA = "c" * 64


@pytest.fixture
def store():
    from scripts.image_backup import BackupBucket

    with mock_aws():
        client = boto3.client("s3", region_name="us-east-1")
        client.create_bucket(Bucket=BUCKET)
        yield BackupBucket(client, BUCKET)


def put(store, key, body):
    store.client.put_object(Bucket=BUCKET, Key=key, Body=body)


def test_key_layout_matches_the_backup_store_format():
    assert recovery_point.original_key(SHA) == "originals/sha256/" + SHA
    assert recovery_point.point_prefix("daily-1") == "points/daily-1/"
    assert recovery_point.point_dump_key("daily-1") == "points/daily-1/database.dump"
    assert recovery_point.point_manifest_key("daily-1") == "points/daily-1/manifest.json"
    assert recovery_point.receipt_key("daily-1") == "gc/points/daily-1.json"


def test_listing_prefixes_cover_every_key_kind():
    assert recovery_point.original_key(SHA).startswith(recovery_point.ORIGINALS_PREFIX)
    assert recovery_point.point_prefix("a").startswith(recovery_point.POINTS_PREFIX)
    assert recovery_point.receipt_key("a").startswith(recovery_point.RECEIPTS_PREFIX)
    assert (recovery_point.ORIGINALS_PREFIX, recovery_point.POINTS_PREFIX,
            recovery_point.RECEIPTS_PREFIX) == ("originals/", "points/", "gc/points/")


@pytest.mark.parametrize("key_of", [recovery_point.point_dump_key,
                                    recovery_point.point_manifest_key])
def test_point_key_round_trips_to_backup_id(key_of):
    assert recovery_point.point_id(key_of("daily-1")) == "daily-1"


@pytest.mark.parametrize("backup_id", ["daily-2026-11-01", "a", "A.b_c-1", "x" * 100])
def test_receipt_key_round_trips_to_backup_id(backup_id):
    assert recovery_point.receipt_backup_id(recovery_point.receipt_key(backup_id)) == backup_id


@pytest.mark.parametrize("key", [
    "gc/points/bad id.json", "gc/points/.json", "gc/points/" + "x" * 101 + ".json",
    "gc/points/a.txt", "gc/points/nested/a.json", "points/a/manifest.json",
])
def test_receipt_key_with_wrong_name_has_no_backup_id(key):
    assert recovery_point.receipt_backup_id(key) is None


@pytest.mark.parametrize("value", ["daily-1", "A.b_c-1", "x" * 100])
def test_backup_id_format_accepts_identifiers(value):
    recovery_point.require_backup_id(value, "invalid_backup_id")


@pytest.mark.parametrize("value", ["", "bad id", "a/b", "x" * 101])
def test_backup_id_format_reports_the_callers_code(value):
    for code in ("invalid_backup_id", "backup_id_required", "invalid_manifest"):
        with pytest.raises(CheckError, match=f"^{code}$"):
            recovery_point.require_backup_id(value, code)


def test_app_commit_format_requires_a_full_lowercase_sha():
    recovery_point.require_app_commit("a" * 40, "invalid_manifest")
    for value in ("", "a" * 39, "A" * 40, "main"):
        with pytest.raises(CheckError, match="^app_commit_required$"):
            recovery_point.require_app_commit(value, "app_commit_required")


def test_canonical_json_is_sorted_compact_and_ascii():
    assert recovery_point.canonical_json({"b": "한", "a": [1, 2]}) == b'{"a":[1,2],"b":"\\ud55c"}'


def test_completed_points_are_ids_with_a_published_manifest(store):
    put(store, recovery_point.point_manifest_key("second"), b"{}")
    put(store, recovery_point.point_manifest_key("first"), b"{}")
    put(store, recovery_point.point_dump_key("interrupted"), b"dump")
    put(store, recovery_point.receipt_key("retiring"), b"{}")
    assert recovery_point.completed_points(store) == ["first", "second"]


def test_point_manifest_is_read_by_checked_id(store):
    value = manifest("point", "2026-11-01T00:00:00+00:00")
    put(store, recovery_point.point_manifest_key("point"), canonical(value))
    assert recovery_point.read_point_manifest(store, "point") == value
    with pytest.raises(CheckError, match="^invalid_backup_id$"):
        recovery_point.read_point_manifest(store, "bad id")
    with pytest.raises(FileNotFoundError):
        recovery_point.read_point_manifest(store, "missing")


def test_retiring_points_yield_receipt_id_key_and_manifest_in_order(store):
    first = manifest("first", "2026-11-01T00:00:00+00:00")
    put(store, recovery_point.receipt_key("first"), canonical(first))
    put(store, recovery_point.receipt_key("second"), b"[]")
    assert list(recovery_point.read_retiring_points(store)) == [
        ("first", "gc/points/first.json", first),
        ("second", "gc/points/second.json", []),
    ]


def test_retiring_points_stop_at_a_receipt_with_a_wrong_name(store):
    put(store, "gc/points/bad name.json", b"{}")
    with pytest.raises(CheckError, match="^invalid_gc_receipt$"):
        list(recovery_point.read_retiring_points(store))


def test_downloaded_point_returns_manifest_and_file_paths(tmp_path):
    directory = write_folder(tmp_path / "backup")
    value, paths = recovery_point.load_backup(directory)
    assert value == json.loads((directory / "manifest.json").read_bytes())
    assert paths == {"database": directory / "database.dump", "images": directory / "images.tar"}


def test_downloaded_point_rejects_a_contract_violation(tmp_path):
    directory = write_folder(tmp_path / "backup", change=lambda value: value.update(origin="x"))
    with pytest.raises(CheckError, match="^invalid_manifest$"):
        recovery_point.load_backup(directory)


def test_downloaded_manifest_is_read_without_checking_the_folder(tmp_path):
    """The restore run reads its copied manifest as is; the copy was checked at prepare."""
    directory = tmp_path / "copied"
    directory.mkdir()
    (directory / "manifest.json").write_text('{"deletion_checkpoint": null, "origin": "x"}')
    assert recovery_point.read_downloaded_manifest(directory) == {
        "deletion_checkpoint": None, "origin": "x",
    }


def test_delegating_names_from_the_migration_are_gone():
    """Callers use this module directly; only the probe's error imports stay re-exported."""
    from scripts import check_backup_restore, image_backup, operator_errors

    assert not hasattr(check_backup_restore, "load_backup")
    assert not hasattr(check_backup_restore, "validate_archive")
    assert not hasattr(image_backup.BackupBucket, "completed_points")
    assert not hasattr(image_backup.BackupBucket, "read_manifest")
    assert check_backup_restore.CheckError is operator_errors.CheckError
