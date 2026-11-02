"""Recovery point module interface: key layout, formats, published and downloaded points."""

import json

import boto3
import pytest
from moto import mock_aws

from scripts import recovery_point
from scripts.operator_errors import CheckError
from tests.deployment.test_recovery_point_bucket_outputs import (
    BUCKET,
    CORRUPTIONS,
    TAR_COLLISIONS,
    asset,
    canonical,
    manifest,
)
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
    "gc/points/..json", "gc/points/...json",
])
def test_receipt_key_with_wrong_name_has_no_backup_id(key):
    assert recovery_point.receipt_backup_id(key) is None


@pytest.mark.parametrize("value", ["daily-1", "A.b_c-1", "x" * 100, "...", ".a", "a.."])
def test_backup_id_format_accepts_identifiers(value):
    recovery_point.require_backup_id(value, "invalid_backup_id")


@pytest.mark.parametrize("value", ["", "bad id", "a/b", "x" * 101, ".", "..", None, 1, ["a"]])
def test_backup_id_format_reports_the_callers_code(value):
    for code in ("invalid_backup_id", "backup_id_required", "invalid_manifest"):
        with pytest.raises(CheckError, match=f"^{code}$"):
            recovery_point.require_backup_id(value, code)


def test_app_commit_format_requires_a_full_lowercase_sha():
    recovery_point.require_app_commit("a" * 40, "invalid_manifest")
    for value in ("", "a" * 39, "A" * 40, "main", None, 1, ["a" * 40]):
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


def test_completed_points_need_the_exact_manifest_key(store):
    """A look-alike object is not a completion manifest (#169)."""
    put(store, "points/stray/manifestXjson", b"{}")
    put(store, recovery_point.point_manifest_key("published"), b"{}")
    assert recovery_point.completed_points(store) == ["published"]


def test_completed_points_skip_path_step_ids(store):
    """`.` and `..` are not backup IDs, so their manifests do not mark completed points."""
    put(store, "points/./manifest.json", b"{}")
    put(store, "points/../manifest.json", b"{}")
    put(store, recovery_point.point_manifest_key("..."), b"{}")
    assert recovery_point.completed_points(store) == ["..."]


POINT = "2026-11-01T00:00:00+00:00"


def test_point_manifest_is_read_by_checked_id(store):
    value = manifest("point", POINT)
    put(store, recovery_point.point_manifest_key("point"), canonical(value))
    assert recovery_point.read_point_manifest(store, "point") == value
    for identifier in ("bad id", "..", "."):
        with pytest.raises(CheckError, match="^invalid_backup_id$"):
            recovery_point.read_point_manifest(store, identifier)
    with pytest.raises(FileNotFoundError):
        recovery_point.read_point_manifest(store, "missing")


def corrupted(case, backup_id="target"):
    change = CORRUPTIONS[case]
    if isinstance(change, bytes):
        return change
    value = manifest(backup_id, POINT)
    change(value)
    return canonical(value)


@pytest.mark.parametrize("case", CORRUPTIONS)
def test_point_manifest_that_breaks_the_contract_is_invalid(case, store):
    put(store, recovery_point.point_manifest_key("target"), corrupted(case))
    with pytest.raises(CheckError, match="^invalid_manifest$"):
        recovery_point.read_point_manifest(store, "target")


@pytest.mark.parametrize("value", [None, 1, True, [], {}, "C" * 64, "c" * 63])
@pytest.mark.parametrize("field", [("assets", 0, "sha256"), ("database", "sha256"),
                                   ("category_links_sha256",), ("sample", "content_sha256")])
def test_digest_that_is_not_a_lowercase_sha256_is_invalid(field, value):
    point = manifest("target", POINT)
    parent = point
    for key in field[:-1]:
        parent = parent[key]
    parent[field[-1]] = value
    with pytest.raises(CheckError, match="^invalid_manifest$"):
        recovery_point.check_point_manifest(point, "target")


@pytest.mark.parametrize("value", [None, 1, [], {}, "2026-11-01"])
def test_captured_at_that_is_not_an_aware_time_is_invalid(value):
    with pytest.raises(CheckError, match="^invalid_manifest$"):
        recovery_point.check_point_manifest({**manifest("target", POINT), "captured_at": value},
                                            "target")


@pytest.mark.parametrize("change", [
    lambda value: value.update(assets=[1]),
    lambda value: value.update(database=[]),
    lambda value: value.update(sample=[]),
    lambda value: value.update(origin=["synthetic"]),
    lambda value: value.update(format_version=[2]),
    lambda value: value["assets"][0].update(storage_backend=["s3"]),
], ids=["asset_not_object", "database_not_object", "sample_not_object", "origin_array",
        "format_version_array", "storage_backend_array"])
def test_values_of_the_wrong_json_type_are_invalid(change):
    point = manifest("target", POINT)
    change(point)
    with pytest.raises(CheckError, match="^invalid_manifest$"):
        recovery_point.check_point_manifest(point, "target")


def test_point_manifest_names_the_requested_backup_id():
    recovery_point.check_point_manifest(manifest("target", POINT), "target")
    with pytest.raises(CheckError, match="^invalid_manifest$"):
        recovery_point.check_point_manifest(manifest("target", POINT), "other")


def test_published_point_without_assets_may_have_no_sample():
    recovery_point.check_point_manifest({**manifest("target", POINT), "assets": [],
                                         "sample": None}, "target")


@pytest.mark.parametrize("case", TAR_COLLISIONS)
def test_colliding_asset_tar_paths_are_invalid(case):
    first, second = TAR_COLLISIONS[case]
    point = manifest("target", POINT, [asset(1, "s3", first, b"one"),
                                       asset(2, "s3", second, b"two")])
    with pytest.raises(CheckError, match="^invalid_manifest$"):
        recovery_point.check_point_manifest(point, "target")


@pytest.mark.parametrize("first,second", [
    (("local", "u/1.png"), ("s3", "u/1.png")),
    (("s3", "u/1.png"), ("s3", "u/1.png2")),
    (("s3", "u/1"), ("s3", "u/10/x")),
])
def test_distinct_asset_tar_paths_are_accepted(first, second):
    """Local and Bucket originals live under different tar roots; only real overlaps clash."""
    point = manifest("target", POINT, [asset(1, *first, b"one"), asset(2, *second, b"two")])
    recovery_point.check_point_manifest(point, "target")


def test_point_json_is_read_before_the_contract(store):
    """maintain reads every manifest first and checks the format version before the contract."""
    put(store, recovery_point.point_manifest_key("old"), b'{"format_version": 1}')
    put(store, recovery_point.point_manifest_key("array"), b"[]")
    put(store, recovery_point.point_manifest_key("broken"), b"not json")
    assert recovery_point.read_point_json(store, "old") == {"format_version": 1}
    assert recovery_point.read_point_json(store, "array") == []
    with pytest.raises(CheckError, match="^invalid_manifest$"):
        recovery_point.read_point_json(store, "broken")
    with pytest.raises(CheckError, match="^invalid_backup_id$"):
        recovery_point.read_point_json(store, "..")


def test_point_unchanged_compares_the_reread_without_the_contract(store):
    value = {"format_version": 1}
    key = recovery_point.point_manifest_key("target")
    put(store, key, json.dumps(value).encode())
    assert recovery_point.point_unchanged(store, "target", value) is True
    put(store, key, b'{"format_version": 1, "x": 1}')
    assert recovery_point.point_unchanged(store, "target", value) is False
    put(store, key, b"not json")
    assert recovery_point.point_unchanged(store, "target", value) is False
    store.client.delete_object(Bucket=BUCKET, Key=key)
    assert recovery_point.point_unchanged(store, "target", value) is False


def test_retiring_points_yield_receipt_id_key_and_manifest_in_order(store):
    first = manifest("first", POINT)
    second = manifest("second", POINT)
    put(store, recovery_point.receipt_key("first"), canonical(first))
    put(store, recovery_point.receipt_key("second"), canonical(second))
    assert list(recovery_point.read_retiring_points(store)) == [
        ("first", "gc/points/first.json", first),
        ("second", "gc/points/second.json", second),
    ]


@pytest.mark.parametrize("key", ["gc/points/bad name.json", "gc/points/..json"])
def test_retiring_points_stop_at_a_receipt_with_a_wrong_name(key, store):
    put(store, key, b"{}")
    with pytest.raises(CheckError, match="^invalid_gc_receipt$"):
        list(recovery_point.read_retiring_points(store))


@pytest.mark.parametrize("body", [b"not json", b"[]"])
def test_retiring_points_stop_at_a_receipt_that_is_not_a_json_object(body, store):
    put(store, recovery_point.receipt_key("first"), body)
    with pytest.raises(CheckError, match="^invalid_manifest$"):
        list(recovery_point.read_retiring_points(store))


def test_receipt_name_is_checked_before_its_content(store):
    """Receipts are read in key order; each one's name comes before its JSON."""
    put(store, "gc/points/a b.json", b"not json")
    with pytest.raises(CheckError, match="^invalid_gc_receipt$"):
        list(recovery_point.read_retiring_points(store))


@pytest.mark.parametrize("case", CORRUPTIONS)
def test_receipt_content_keeps_the_same_contract(case, store):
    body = corrupted(case)
    put(store, recovery_point.receipt_key("target"), body)
    with pytest.raises(CheckError, match="^invalid_manifest$"):
        for identifier, _, value in recovery_point.read_retiring_points(store):
            recovery_point.check_point_manifest(value, identifier)


def test_downloaded_point_returns_manifest_and_file_paths(tmp_path):
    directory = write_folder(tmp_path / "backup")
    value, paths = recovery_point.load_backup(directory)
    assert value == json.loads((directory / "manifest.json").read_bytes())
    assert paths == {"database": directory / "database.dump", "images": directory / "images.tar"}


def test_downloaded_point_rejects_a_contract_violation(tmp_path):
    directory = write_folder(tmp_path / "backup", change=lambda value: value.update(origin="x"))
    with pytest.raises(CheckError, match="^invalid_manifest$"):
        recovery_point.load_backup(directory)


@pytest.mark.parametrize("body", [b"not json", b"\xff"])
def test_downloaded_manifest_that_is_not_json_is_invalid(body, tmp_path):
    directory = write_folder(tmp_path / "backup", change=body)
    with pytest.raises(CheckError, match="^invalid_manifest$"):
        recovery_point.load_backup(directory)


def test_downloaded_point_needs_its_images_entry(tmp_path):
    directory = write_folder(tmp_path / "backup", change=lambda value: value.pop("images"))
    with pytest.raises(CheckError, match="^invalid_manifest$"):
        recovery_point.load_backup(directory)


def test_downloaded_point_checks_the_database_key_before_the_dump_hash(tmp_path):
    directory = write_folder(tmp_path / "backup", change=lambda value: value["database"].update(
        backup_key="points/other/database.dump"))
    (directory / "database.dump").write_bytes(b"changed dump!!")
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
