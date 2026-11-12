"""Operator output for published recovery point manifests (#161, unified in #167).

`image_backup verify|download` and `image_backup_jobs maintain` run in-process through their
real `main()`. The backup Bucket is moto. For `maintain` only the runtime assembly (DB lock,
maintenance gate, deletion ledger wiring) is replaced. #161 fixed the outputs measured on
main 06bc24d; #167 changed only the expected values listed in spec #156's tables: every
contract violation is `invalid_manifest`, checked before any object is read. #185 added the
unnormalized storage_key cases, which `verify` and `maintain` accepted before. #186 changed
`verify` and `download` to report a completed point's missing or unreadable objects with the
code `maintain` uses, and pinned the outputs around them, publishing's included.
"""

import asyncio
import hashlib
import io
import json
import sys
from contextlib import asynccontextmanager
from datetime import UTC, datetime, timedelta

import boto3
import pytest
from botocore.exceptions import ClientError, EndpointConnectionError, ReadTimeoutError
from moto import mock_aws
from pydantic import SecretStr

from app.integrations.deletion_ledger import get_deletion_ledger as build_deletion_ledger

BUCKET = "private-backup"
DUMP = b"synthetic dump"
LOCAL_BYTES = b"local original"
BUCKET_BYTES = b"bucket original"
FRESH, EXPIRED = timedelta(days=0.1), timedelta(days=8)


def digest(value):
    return hashlib.sha256(value).hexdigest()


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode()


def asset(asset_id, backend, storage_key, body):
    return {
        "id": asset_id, "content_id": asset_id, "storage_backend": backend,
        "storage_key": storage_key, "size_bytes": len(body), "sha256": digest(body),
        "backup_key": "originals/sha256/" + digest(body),
    }


HEALTHY_ASSETS = [asset(1, "local", "a.png", LOCAL_BYTES), asset(2, "s3", "u/1.png", BUCKET_BYTES)]


def manifest(backup_id, captured_at, assets=HEALTHY_ASSETS):
    return {
        "format_version": 2, "backup_id": backup_id, "origin": "synthetic",
        "captured_at": captured_at, "app_commit": "a" * 40, "postgres_major": 17,
        "migration_revisions": ["202610230015"], "tables": {"content_assets": 2, "users": 1},
        "category_links_sha256": "c" * 64, "assets": [dict(item) for item in assets],
        "sample": {
            "content_id": 1, "asset_id": assets[0]["id"], "saved_at": "2026-10-23T00:00:00+00:00",
            "category_ids": [], "content_sha256": "d" * 64,
        },
        "extra_file_count": 0,
        "database": {
            "file": "database.dump", "backup_key": f"points/{backup_id}/database.dump",
            "size_bytes": len(DUMP), "sha256": digest(DUMP),
        },
        "deletion_checkpoint": None,
    }


def parent(value, path):
    for key in path[:-1]:
        value = value[key]
    return value


def delete(*path):
    return lambda value: parent(value, path).pop(path[-1])


def assign(*path, value):
    return lambda manifest_value: parent(manifest_value, path).__setitem__(path[-1], value)


def naive_captured_at(value):
    value["captured_at"] = value["captured_at"].split("+")[0]


# Each corruption returns raw bytes, or changes the target point's manifest in place.
CORRUPTIONS = {
    "not_json": b"not json",
    "not_object": b"[]",
    "missing_database": delete("database"),
    "missing_assets": delete("assets"),
    "missing_captured_at": delete("captured_at"),
    "missing_postgres_major": delete("postgres_major"),
    "missing_migration_revisions": delete("migration_revisions"),
    "missing_asset_sha256": delete("assets", 0, "sha256"),
    "app_commit_not_sha": assign("app_commit", value="abc"),
    "origin_unknown": assign("origin", value="staging"),
    "unknown_field": assign("operator_note", value="x"),
    "images_entry": assign("images", value={"file": "images.tar", "size_bytes": 1,
                                            "sha256": "e" * 64}),
    "tables_negative": assign("tables", "users", value=-1),
    "asset_content_id_missing": delete("assets", 0, "content_id"),
    "captured_at_without_timezone": naive_captured_at,
    "asset_size_string": assign("assets", 0, "size_bytes", value=str(len(LOCAL_BYTES))),
    "database_size_string": assign("database", "size_bytes", value=str(len(DUMP))),
    "database_backup_key_elsewhere": assign("database", "backup_key",
                                            value="points/other/database.dump"),
    "format_version_1": assign("format_version", value=1),
    "backup_id_differs": assign("backup_id", value="other"),
    "asset_backend_unknown": assign("assets", 1, "storage_backend", value="gcs"),
    "asset_backup_key_elsewhere": assign("assets", 0, "backup_key", value="originals/elsewhere"),
}

# A storage_key must equal its normalized POSIX path and must not be `.` (#185).
UNNORMALIZED_KEYS = {
    "dot_step": "u/./1.png", "leading_dot": "./u/1.png", "empty_step": "u//1.png",
    "trailing_slash": "u/1.png/", "dot": ".",
}
CORRUPTIONS |= {
    f"storage_key_{name}_{backend}": assign("assets", index, "storage_key", value=key)
    for name, key in UNNORMALIZED_KEYS.items()
    for index, backend in enumerate(["local", "s3"])
}

# Asset tar paths: screenshots/ or s3/ + storage_key.
TAR_COLLISIONS = {
    "same_storage_key": ("u/1.png", "u/1.png"),
    # Still invalid_manifest, now from the storage_key rule on `u/./1.png` before any collision.
    "same_after_normalizing": ("u/./1.png", "u/1.png"),
    "parent_and_child": ("u/1.png", "u/1.png/x"),
}


class Bucket:
    def __init__(self, client):
        self.client = client

    def put(self, key, body):
        self.client.put_object(Bucket=BUCKET, Key=key, Body=body)

    def delete(self, key):
        self.client.delete_object(Bucket=BUCKET, Key=key)

    def keys(self):
        pages = self.client.get_paginator("list_objects_v2").paginate(Bucket=BUCKET)
        return sorted(item["Key"] for page in pages for item in page.get("Contents", []))

    def point(self, identifier, value, *, body=None, receipt=False,
              originals=(LOCAL_BYTES, BUCKET_BYTES)):
        for original in originals:
            self.put("originals/sha256/" + digest(original), original)
        self.put(f"points/{identifier}/database.dump", DUMP)
        key = f"gc/points/{identifier}.json" if receipt else f"points/{identifier}/manifest.json"
        self.put(key, canonical(value) if body is None else body)


@pytest.fixture
def bucket(monkeypatch):
    from scripts.image_backup import BackupBucket

    with mock_aws():
        client = boto3.client("s3", region_name="us-east-1")
        client.create_bucket(Bucket=BUCKET)
        store = BackupBucket(client, BUCKET)
        monkeypatch.setattr(BackupBucket, "from_environment", classmethod(lambda cls: store))
        yield Bucket(client)


@pytest.fixture
def maintenance_runtime(monkeypatch, tmp_path):
    """Replace only DB lock, maintenance gate and ledger wiring; retention runs for real."""
    import app.integrations.deletion_ledger as deletion_ledger
    import app.services.maintenance as maintenance
    import scripts.image_backup_jobs as jobs
    import scripts.operator_runtime as operator_runtime
    from tests.support.maintenance import OpenUnitGate

    ledger = deletion_ledger.DeletionLedger(deletion_ledger.LocalLedgerStore(tmp_path / "ledger"))
    ledger.initialize()

    class Runtime:
        config = sessions = engine = None

        async def close(self):
            pass

    @asynccontextmanager
    async def unlocked(*args, **kwargs):
        yield

    monkeypatch.setattr(operator_runtime, "MaintenanceRuntime", Runtime)
    monkeypatch.setattr(deletion_ledger, "get_deletion_ledger",
                        lambda config=None, **kwargs: ledger)
    monkeypatch.setattr(maintenance, "MaintenanceGate", lambda sessions: OpenUnitGate())
    monkeypatch.setattr(jobs, "source_lock", unlocked)


def run(main, argv, monkeypatch, capsys):
    monkeypatch.setattr(sys, "argv", argv)
    code = main()
    return code, json.loads(capsys.readouterr().out)


def verify(monkeypatch, capsys):
    from scripts.image_backup import main

    return run(main, ["image_backup", "verify", "--backup-id", "target"], monkeypatch, capsys)


def download(directory, monkeypatch, capsys):
    from scripts.image_backup import main

    code, output = run(main, ["image_backup", "download", "--backup-id", "target",
                              "--directory", str(directory)], monkeypatch, capsys)
    left = sorted(path.name for path in directory.iterdir()) if directory.exists() else None
    return code, output, left


def maintain(monkeypatch, capsys):
    from scripts.image_backup_jobs import main

    return run(main, ["image_backup_jobs", "maintain"], monkeypatch, capsys)


def corrupted_target(bucket, case, age, *, receipt=False):
    """A healthy fresh anchor point plus the corrupted target at the given age."""
    now = datetime.now(UTC)
    bucket.point("anchor", manifest("anchor", (now - timedelta(hours=1)).isoformat()))
    value = manifest("target", (now - age).isoformat())
    change = CORRUPTIONS[case]
    if isinstance(change, bytes):
        bucket.point("target", value, body=change, receipt=receipt)
    else:
        change(value)
        bucket.point("target", value, receipt=receipt)
    return value


def failure(code):
    return 1, {"passed": False, "error": code}


def job_failure(exception, cause):
    return 1, {"passed": False, "error": JOB, "exception": exception, "cause": cause}


ALL_FILES = ["database.dump", "images.tar", "manifest.json"]
VERIFIED = {
    "all_sizes_and_sha256_match": True, "app_commit": "a" * 40,
    "asset_counts": {"local": 1, "s3": 1}, "backup_id": "target", "captured_at": "<captured_at>",
    "has_deletion_checkpoint": False, "live_deletion_ledger_verified": False,
    "migration_revisions": ["202610230015"], "passed": True, "restore_verified": False,
    "total_bytes": 43, "verified_objects": 3,
}
DOWNLOADED = {"asset_count": 2, "backup_id": "target", "deletions_applied": False, "passed": True}


def retention(expired, removed, retained):
    return {
        "deletion_records_pruned": 0, "expired_points": expired, "freshness_met": True,
        "passed": True, "removed_originals": removed, "retained_points": retained,
        "retention_overdue": 0,
    }


KEPT = retention(0, 0, 2)
OPERATION, JOB, INVALID = "backup_operation_failed", "backup_job_failed", "invalid_manifest"
RETENTION_V2 = "retention_requires_v2"

# case: (verify, download, folder left by download, maintain fresh, maintain expired,
#        maintain with the manifest only as a cleanup receipt)
# Every corruption breaks the contract, and download checks it before creating the folder.
# Only maintain reports a format version other than 2 before the contract.
CORRUPTION_OUTPUTS = {
    case: (INVALID, INVALID, None, INVALID, INVALID, INVALID) for case in CORRUPTIONS
} | {"format_version_1": (INVALID, INVALID, None, RETENTION_V2, RETENTION_V2, RETENTION_V2)}


def outcome(expected):
    if isinstance(expected, str):
        return failure(expected)
    return (0 if expected["passed"] else 1), expected


def without_captured_at(result, value):
    code, output = result
    if "captured_at" in output and output["captured_at"] == value.get("captured_at"):
        output = {**output, "captured_at": "<captured_at>"}
    return code, output


def test_complete_point_outputs(bucket, maintenance_runtime, monkeypatch, capsys, tmp_path):
    now = datetime.now(UTC)
    bucket.point("anchor", manifest("anchor", (now - timedelta(hours=1)).isoformat()))
    value = manifest("target", (now - FRESH).isoformat())
    bucket.point("target", value)
    assert without_captured_at(verify(monkeypatch, capsys), value) == (0, VERIFIED)
    assert download(tmp_path / "download", monkeypatch, capsys) == (0, DOWNLOADED, ALL_FILES)
    assert maintain(monkeypatch, capsys) == (0, KEPT)


@pytest.mark.parametrize("age", ["fresh", "expired"])
@pytest.mark.parametrize("case", CORRUPTIONS)
def test_corrupted_manifest_outputs(case, age, bucket, maintenance_runtime, monkeypatch, capsys,
                                    tmp_path):
    value = corrupted_target(bucket, case, FRESH if age == "fresh" else EXPIRED)
    verified, downloaded, left, fresh, expired, _ = CORRUPTION_OUTPUTS[case]
    actual = {
        "verify": without_captured_at(verify(monkeypatch, capsys), value),
        "download": download(tmp_path / "download", monkeypatch, capsys),
        "maintain": maintain(monkeypatch, capsys),
    }
    assert actual == {
        "verify": outcome(verified),
        "download": (*outcome(downloaded), left),
        "maintain": outcome(fresh if age == "fresh" else expired),
    }


@pytest.mark.parametrize("case", CORRUPTIONS)
def test_corrupted_cleanup_receipt_outputs(case, bucket, maintenance_runtime, monkeypatch, capsys):
    corrupted_target(bucket, case, EXPIRED, receipt=True)
    assert maintain(monkeypatch, capsys) == outcome(CORRUPTION_OUTPUTS[case][5])


@pytest.mark.parametrize("age", ["fresh", "expired"])
@pytest.mark.parametrize("case", TAR_COLLISIONS)
def test_colliding_asset_tar_path_outputs(case, age, bucket, maintenance_runtime, monkeypatch,
                                          capsys, tmp_path):
    now = datetime.now(UTC)
    bucket.point("anchor", manifest("anchor", (now - timedelta(hours=1)).isoformat()))
    first, second = TAR_COLLISIONS[case]
    assets = [asset(1, "s3", first, b"one"), asset(2, "s3", second, b"two")]
    value = manifest("target", (now - (FRESH if age == "fresh" else EXPIRED)).isoformat(), assets)
    bucket.point("target", value, originals=(b"one", b"two"))
    actual = {
        "verify": without_captured_at(verify(monkeypatch, capsys), value),
        "download": download(tmp_path / "download", monkeypatch, capsys),
        "maintain": maintain(monkeypatch, capsys),
    }
    assert actual == {
        "verify": failure(INVALID),
        "download": (*failure(INVALID), None),
        "maintain": failure(INVALID),
    }


NON_STRING_SHA256 = pytest.mark.parametrize(
    "sha256", [None, 1, True, [], {}], ids=["null", "number", "boolean", "array", "object"]
)


def changed_target(bucket, age, *changes, receipt=False):
    """A healthy fresh anchor point plus a target point with the given manifest changes."""
    now = datetime.now(UTC)
    bucket.point("anchor", manifest("anchor", (now - timedelta(hours=1)).isoformat()))
    value = manifest("target", (now - age).isoformat())
    for change in changes:
        change(value)
    bucket.point("target", value, receipt=receipt)


@pytest.mark.parametrize("age", ["fresh", "expired"])
@NON_STRING_SHA256
def test_non_string_asset_sha256_outputs(sha256, age, bucket, maintenance_runtime, monkeypatch,
                                         capsys, tmp_path):
    """A digest that is not a string breaks the contract like any other format violation."""
    changed_target(bucket, FRESH if age == "fresh" else EXPIRED,
                   assign("assets", 0, "sha256", value=sha256))
    actual = {
        "verify": verify(monkeypatch, capsys),
        "download": download(tmp_path / "download", monkeypatch, capsys),
        "maintain": maintain(monkeypatch, capsys),
    }
    assert actual == {
        "verify": failure(INVALID),
        "download": (*failure(INVALID), None),
        "maintain": failure(INVALID),
    }


@NON_STRING_SHA256
def test_non_string_asset_sha256_outputs_with_unknown_backend(sha256, bucket, maintenance_runtime,
                                                              monkeypatch, capsys, tmp_path):
    """An unknown storage backend together with a non-string digest is one contract failure."""
    changed_target(bucket, FRESH, assign("assets", 1, "storage_backend", value="gcs"),
                   assign("assets", 1, "sha256", value=sha256))
    actual = {
        "verify": verify(monkeypatch, capsys),
        "download": download(tmp_path / "download", monkeypatch, capsys),
        "maintain": maintain(monkeypatch, capsys),
    }
    assert actual == {
        "verify": failure(INVALID),
        "download": (*failure(INVALID), None),
        "maintain": failure(INVALID),
    }


@NON_STRING_SHA256
def test_non_string_asset_sha256_cleanup_receipt_outputs(sha256, bucket, maintenance_runtime,
                                                         monkeypatch, capsys):
    changed_target(bucket, EXPIRED, assign("assets", 0, "sha256", value=sha256), receipt=True)
    assert maintain(monkeypatch, capsys) == failure(INVALID)


def contract_violation(bucket):
    """A fresh target whose app_commit is not a SHA; #161 measured verify and maintain accept it."""
    now = datetime.now(UTC)
    bucket.point("anchor", manifest("anchor", (now - timedelta(hours=1)).isoformat()))
    value = manifest("target", (now - FRESH).isoformat())
    value["app_commit"] = "abc"
    bucket.point("target", value)


def test_verify_reports_contract_violation_before_object_mismatch(bucket, monkeypatch, capsys):
    contract_violation(bucket)
    bucket.put("originals/sha256/" + digest(BUCKET_BYTES), b"broken")
    assert verify(monkeypatch, capsys) == failure(INVALID)


def test_verify_reread_that_is_not_json(bucket, monkeypatch, capsys):
    now = datetime.now(UTC)
    bucket.point("target", manifest("target", (now - FRESH).isoformat()))

    def replace_while_objects_are_read(params, **kwargs):
        if params.get("Key") != "points/target/manifest.json":
            bucket.put("points/target/manifest.json", b"not json")

    bucket.client.meta.events.register(
        "before-parameter-build.s3.GetObject", replace_while_objects_are_read
    )
    assert verify(monkeypatch, capsys) == failure("backup_point_changed")


def test_verify_reread_of_a_removed_manifest(bucket, monkeypatch, capsys):
    """A manifest removed while the objects are read is a changed point, like a replaced one."""
    now = datetime.now(UTC)
    bucket.point("target", manifest("target", (now - FRESH).isoformat()))

    def remove_while_objects_are_read(params, **kwargs):
        if params.get("Key") != "points/target/manifest.json":
            bucket.delete("points/target/manifest.json")

    bucket.client.meta.events.register(
        "before-parameter-build.s3.GetObject", remove_while_objects_are_read
    )
    assert verify(monkeypatch, capsys) == failure("backup_point_changed")


MANIFEST_KEY, DUMP_KEY = "points/target/manifest.json", "points/target/database.dump"
# The s3 asset's original; the anchor point of `corrupted_target` uses it too.
S3_ORIGINAL = "originals/sha256/" + digest(BUCKET_BYTES)
MISSING, STORE = "backup_object_missing_or_unavailable", "backup_store_unavailable"
CLEANUP = "backup_cleanup_unverified"


def denied(operation):
    return ClientError({"Error": {"Code": "AccessDenied", "Message": "denied"}}, operation)


def deny_reads(key):
    """GetObject and HeadObject of `key` answer AccessDenied."""
    def apply(bucket):
        for operation in ("GetObject", "HeadObject"):
            def refuse(params, operation=operation, **kwargs):
                if params.get("Key") == key:
                    raise denied(operation)

            bucket.client.meta.events.register(f"before-parameter-build.s3.{operation}", refuse)
    return apply


def test_verify_reread_denied(bucket, monkeypatch, capsys):
    """Any other S3 error of the reread stays the store failure."""
    bucket.point("target", manifest("target", (datetime.now(UTC) - FRESH).isoformat()))
    reads = []

    def deny_the_reread(params, **kwargs):
        if params.get("Key") == MANIFEST_KEY:
            reads.append(params)
            if len(reads) == 2:
                raise denied("GetObject")

    bucket.client.meta.events.register("before-parameter-build.s3.GetObject", deny_the_reread)
    assert verify(monkeypatch, capsys) == failure(STORE)


def test_missing_point_id_outputs(bucket, monkeypatch, capsys, tmp_path):
    """No completed point has this ID: the generic failure, and download creates no folder."""
    bucket.point("anchor", manifest("anchor", (datetime.now(UTC) - FRESH).isoformat()))
    actual = {
        "verify": verify(monkeypatch, capsys),
        "download": download(tmp_path / "download", monkeypatch, capsys),
    }
    assert actual == {"verify": failure(OPERATION), "download": (*failure(OPERATION), None)}


def test_first_manifest_read_denied_outputs(bucket, monkeypatch, capsys, tmp_path):
    bucket.point("target", manifest("target", (datetime.now(UTC) - FRESH).isoformat()))
    deny_reads(MANIFEST_KEY)(bucket)
    actual = {
        "verify": verify(monkeypatch, capsys),
        "download": download(tmp_path / "download", monkeypatch, capsys),
    }
    assert actual == {"verify": failure(STORE), "download": (*failure(STORE), None)}


OBJECT_FAILURES = {
    "dump_missing": lambda bucket: bucket.delete(DUMP_KEY),
    "original_missing": lambda bucket: bucket.delete(S3_ORIGINAL),
    "dump_denied": deny_reads(DUMP_KEY),
    "original_denied": deny_reads(S3_ORIGINAL),
}
DUMP_AND_ARCHIVE = ["database.dump", "images.tar"]
# case: (folder left by download, maintain fresh, maintain expired); verify and download report
# MISSING. maintain checks only the objects of retained points (the anchor shares the original)
# and removes an expired point's objects unchecked; a denied removal is not confirmed.
OBJECT_FAILURE_OUTPUTS = {
    "dump_missing": ([], MISSING, retention(1, 0, 1)),
    "original_missing": (DUMP_AND_ARCHIVE, MISSING, MISSING),
    "dump_denied": ([], MISSING, CLEANUP),
    "original_denied": (DUMP_AND_ARCHIVE, MISSING, MISSING),
}


@pytest.mark.parametrize("age", ["fresh", "expired"])
@pytest.mark.parametrize("case", OBJECT_FAILURES)
def test_completed_point_object_failure_outputs(case, age, bucket, maintenance_runtime,
                                                monkeypatch, capsys, tmp_path):
    now = datetime.now(UTC)
    bucket.point("anchor", manifest("anchor", (now - timedelta(hours=1)).isoformat()))
    bucket.point("target", manifest("target",
                                    (now - (FRESH if age == "fresh" else EXPIRED)).isoformat()))
    OBJECT_FAILURES[case](bucket)
    left, fresh, expired = OBJECT_FAILURE_OUTPUTS[case]
    actual = {
        "verify": verify(monkeypatch, capsys),
        "download": download(tmp_path / "download", monkeypatch, capsys),
        "maintain": maintain(monkeypatch, capsys),
    }
    assert actual == {
        "verify": failure(MISSING),
        "download": (*failure(MISSING), left),
        "maintain": outcome(fresh if age == "fresh" else expired),
    }


@pytest.mark.parametrize("case", ["missing", "denied"])
def test_maintain_removes_an_original_only_an_expired_point_uses(case, bucket, maintenance_runtime,
                                                                 monkeypatch, capsys):
    """The retained anchor uses another original, so the expired target's are not checked."""
    now = datetime.now(UTC)
    anchor = b"anchor original"
    bucket.point("anchor", manifest("anchor", (now - timedelta(hours=1)).isoformat(),
                                    [asset(1, "local", "a.png", anchor)]), originals=(anchor,))
    bucket.point("target", manifest("target", (now - EXPIRED).isoformat()))
    if case == "missing":
        bucket.delete(S3_ORIGINAL)
    else:
        deny_reads(S3_ORIGINAL)(bucket)
    expected = (0, retention(1, 1, 1)) if case == "missing" else failure(CLEANUP)
    assert maintain(monkeypatch, capsys) == expected


class InterruptedBody(io.RawIOBase):
    def readinto(self, buffer):
        raise ReadTimeoutError(endpoint_url="https://backup.invalid")


def interrupt_body(key):
    def apply(bucket):
        requested = []

        def remember(params, **kwargs):
            requested.append(params.get("Key"))

        def interrupt(parsed, **kwargs):
            if requested[-1] == key:
                parsed["Body"] = InterruptedBody()

        bucket.client.meta.events.register("before-parameter-build.s3.GetObject", remember)
        bucket.client.meta.events.register("after-call.s3.GetObject", interrupt)
    return apply


def fail_connection(key):
    def apply(bucket):
        def refuse(params, **kwargs):
            if params.get("Key") == key:
                raise EndpointConnectionError(endpoint_url="https://backup.invalid")

        bucket.client.meta.events.register("before-parameter-build.s3.GetObject", refuse)
    return apply


# case: (damage, folder left by download). Not S3 responses, so the generic failure.
NOT_S3_ERRORS = {
    "dump_connection_failed": (fail_connection(DUMP_KEY), []),
    "dump_body_interrupted": (interrupt_body(DUMP_KEY), ["database.dump"]),
    "original_connection_failed": (fail_connection(S3_ORIGINAL), DUMP_AND_ARCHIVE),
    "original_body_interrupted": (interrupt_body(S3_ORIGINAL), DUMP_AND_ARCHIVE),
}


@pytest.mark.parametrize("case", NOT_S3_ERRORS)
def test_object_read_failure_that_is_not_an_s3_error(case, bucket, monkeypatch, capsys,
                                                     tmp_path):
    bucket.point("target", manifest("target", (datetime.now(UTC) - FRESH).isoformat()))
    damage, left = NOT_S3_ERRORS[case]
    damage(bucket)
    actual = {
        "verify": verify(monkeypatch, capsys),
        "download": download(tmp_path / "download", monkeypatch, capsys),
    }
    assert actual == {"verify": failure(OPERATION), "download": (*failure(OPERATION), left)}


def test_download_reports_contract_violation_before_dump_mismatch(bucket, monkeypatch, capsys,
                                                                   tmp_path):
    contract_violation(bucket)
    bucket.put("points/target/database.dump", b"broken")
    assert download(tmp_path / "download", monkeypatch, capsys) == (*failure(INVALID), None)


def test_maintain_reports_size_string_of_unshared_original(
    bucket, maintenance_runtime, monkeypatch, capsys
):
    """No earlier point has checked this original; the string size still breaks the contract."""
    value = manifest("target", (datetime.now(UTC) - FRESH).isoformat())
    value["assets"][0]["size_bytes"] = str(len(LOCAL_BYTES))
    bucket.point("target", value)
    assert maintain(monkeypatch, capsys) == failure(INVALID)


def test_maintain_reports_receipt_conflict_before_contract_violation(
    bucket, maintenance_runtime, monkeypatch, capsys
):
    now = datetime.now(UTC)
    bucket.point("anchor", manifest("anchor", (now - timedelta(hours=1)).isoformat()))
    value = manifest("target", (now - FRESH).isoformat())
    bucket.point("target", value)
    bucket.put("gc/points/target.json", canonical({**value, "app_commit": "abc"}))
    assert maintain(monkeypatch, capsys) == failure("gc_receipt_conflict")


def test_maintain_reports_contract_violation_before_missing_object(
    bucket, maintenance_runtime, monkeypatch, capsys
):
    contract_violation(bucket)
    bucket.delete("points/target/database.dump")
    assert maintain(monkeypatch, capsys) == failure(INVALID)


@pytest.mark.parametrize("identifier", [".", ".."])
def test_path_step_backup_id_outputs(identifier, bucket, maintenance_runtime, monkeypatch, capsys,
                                     tmp_path):
    """`.` and `..` are not backup IDs: rejected as arguments, never listed as completed points."""
    from scripts.image_backup import main

    now = datetime.now(UTC)
    bucket.point("anchor", manifest("anchor", (now - timedelta(hours=1)).isoformat()))
    bucket.point(identifier, manifest(identifier, (now - FRESH).isoformat()))
    directory = tmp_path / "download"
    actual = {
        "verify": run(main, ["image_backup", "verify", "--backup-id", identifier],
                      monkeypatch, capsys),
        "download": run(main, ["image_backup", "download", "--backup-id", identifier,
                               "--directory", str(directory)], monkeypatch, capsys),
        "download folder": directory.exists(),
        "maintain": maintain(monkeypatch, capsys),
    }
    assert actual == {
        "verify": failure("invalid_backup_id"),
        "download": failure("invalid_backup_id"),
        "download folder": False,
        # Its objects are an unfinished point's leftovers, removed once a day old.
        "maintain": (0, retention(0, 0, 1)),
    }
    assert f"points/{identifier}/manifest.json" in bucket.keys()


@pytest.mark.parametrize("identifier", [".", ".."])
def test_path_step_cleanup_receipt_outputs(identifier, bucket, maintenance_runtime, monkeypatch,
                                           capsys):
    now = datetime.now(UTC)
    bucket.point("anchor", manifest("anchor", (now - timedelta(hours=1)).isoformat()))
    bucket.point(identifier, manifest(identifier, (now - EXPIRED).isoformat()), receipt=True)
    assert maintain(monkeypatch, capsys) == failure("invalid_gc_receipt")


PUBLISHED_KEYS = [
    "gc/points/first.json",
    "originals/sha256/0f9b7fa2d9d194b1863dc6776b5dce7a05311d5d53789dc72ef1e05caae7d9ad",
    "originals/sha256/c5bcee202942f24ff07db77e302e1a97441b83cc959e541117f40cc557ba446f",
    "points/first/database.dump",
    "points/first/manifest.json",
    "points/second/database.dump",
    "points/second/manifest.json",
]
FIRST_MANIFEST = (
    b'{"app_commit":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",'
    b'"assets":[{"backup_key":"originals/sha256/c5bcee202942f24ff07db77e302e1a97441b83cc959e'
    b'541117f40cc557ba446f",'
    b'"content_id":1,"id":1,'
    b'"sha256":"c5bcee202942f24ff07db77e302e1a97441b83cc959e541117f40cc557ba446f",'
    b'"size_bytes":14,"storage_backend":"local","storage_key":"a.png"},'
    b'{"backup_key":"originals/sha256/0f9b7fa2d9d194b1863dc6776b5dce7a05311d5d53789dc72ef1e0'
    b'5caae7d9ad",'
    b'"content_id":2,"id":2,'
    b'"sha256":"0f9b7fa2d9d194b1863dc6776b5dce7a05311d5d53789dc72ef1e05caae7d9ad",'
    b'"size_bytes":15,"storage_backend":"s3","storage_key":"u/\\ud55c.png"}],'
    b'"backup_id":"first","captured_at":"2026-10-01T00:00:00+00:00",'
    b'"category_links_sha256":"ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc'
    b'ccc",'
    b'"database":{"backup_key":"points/first/database.dump","file":"database.dump",'
    b'"sha256":"3fb6e3505fc5a6d0733d9aeab99c978cd9aee8779f5409b3dcd8826217418ed6",'
    b'"size_bytes":14},"deletion_checkpoint":null,"extra_file_count":0,"format_version":2,'
    b'"migration_revisions":["202610230015"],"origin":"synthetic","postgres_major":17,'
    b'"sample":{"asset_id":1,"category_ids":[],"content_id":1,'
    b'"content_sha256":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",'
    b'"saved_at":"2026-10-23T00:00:00+00:00"},"tables":{"content_assets":2,"users":1}}'
)
SECOND_MANIFEST = (
    FIRST_MANIFEST.replace(b'"backup_id":"first"', b'"backup_id":"second"')
    .replace(b"points/first/database.dump", b"points/second/database.dump")
    .replace(b'"deletion_checkpoint":null', b'"deletion_checkpoint":{"namespace":"n","sequence":3}')
)


def test_publishing_fixed_input_writes_fixed_keys_and_bytes(
    bucket, maintenance_runtime, monkeypatch, capsys, tmp_path
):
    """Key layout and canonical JSON of manifests and cleanup receipts stay byte-identical."""
    from app.core.config import Settings
    from app.integrations.storage_client import StorageRouter
    from scripts.image_backup import BackupBucket, publish_backup

    bucket.client.create_bucket(Bucket="source-originals")
    bucket.client.put_object(Bucket="source-originals", Key="u/한.png", Body=BUCKET_BYTES)
    (tmp_path / "a.png").write_bytes(LOCAL_BYTES)
    dump = tmp_path / "database.dump"
    dump.write_bytes(DUMP)
    storage = StorageRouter(Settings(
        _env_file=None, app_environment="test", youtube_summary_enabled=False,
        storage_backend="local", storage_root=tmp_path,
        s3_bucket="source-originals", s3_endpoint_url="https://s3.amazonaws.com",
        s3_region="us-east-1", s3_access_key_id=SecretStr("testing"),
        s3_secret_access_key=SecretStr("testing"),
    ))
    snapshot = manifest("unused", "unused", [
        asset(1, "local", "a.png", LOCAL_BYTES), asset(2, "s3", "u/한.png", BUCKET_BYTES),
    ])
    snapshot = {key: snapshot[key] for key in (
        "migration_revisions", "tables", "category_links_sha256", "sample", "extra_file_count",
    )} | {"assets": [
        {key: value for key, value in item.items() if key != "backup_key"}
        for item in snapshot["assets"]
    ]}
    for identifier, checkpoint in (("first", None), ("second", {"namespace": "n", "sequence": 3})):
        asyncio.run(publish_backup(
            BackupBucket(bucket.client, BUCKET), backup_id=identifier, snapshot=snapshot,
            database=dump, storage=storage, captured_at="2026-10-01T00:00:00+00:00",
            app_commit="a" * 40, postgres_major=17, origin="synthetic",
            deletion_checkpoint=checkpoint,
        ))
    # Retention writes the cleanup receipt, then fails to unpublish the first point.
    bucket.client.put_bucket_policy(Bucket=BUCKET, Policy=json.dumps({
        "Version": "2012-10-17", "Statement": [{
            "Effect": "Deny", "Principal": "*", "Action": "s3:DeleteObject",
            "Resource": f"arn:aws:s3:::{BUCKET}/points/first/*",
        }],
    }))
    assert maintain(monkeypatch, capsys) == job_failure("ClientError", None)

    def body(key):
        return bucket.client.get_object(Bucket=BUCKET, Key=key)["Body"].read()

    assert bucket.keys() == PUBLISHED_KEYS
    assert body("points/first/manifest.json") == FIRST_MANIFEST
    assert body("gc/points/first.json") == FIRST_MANIFEST
    assert body("points/second/manifest.json") == SECOND_MANIFEST


LOCAL_ORIGINAL = "originals/sha256/" + digest(LOCAL_BYTES)
PUBLISHED_DUMP = "points/point/database.dump"


def remove_when_read(key):
    def apply(bucket):
        def remove(params, **kwargs):
            if params.get("Key") == key:
                bucket.delete(key)

        bucket.client.meta.events.register("before-parameter-build.s3.GetObject", remove)
    return apply


def deny_get(key):
    def apply(bucket):
        def refuse(params, **kwargs):
            if params.get("Key") == key:
                raise denied("GetObject")

        bucket.client.meta.events.register("before-parameter-build.s3.GetObject", refuse)
    return apply


PUBLISH_FAILURES = {
    "dump_readback_missing": remove_when_read(PUBLISHED_DUMP),
    "dump_readback_denied": deny_get(PUBLISHED_DUMP),
    "existing_original_denied": lambda bucket: (bucket.put(LOCAL_ORIGINAL, LOCAL_BYTES),
                                                deny_get(LOCAL_ORIGINAL)(bucket)),
}
# case: (raised, Bucket keys after the failure). create and daily print a CheckError's code and
# report any other exception as backup_operation_failed and backup_job_failed. Measured on the
# start commit 509c5cb of #186; the manifest is never published.
PUBLISH_FAILURE_OUTPUTS = {
    "dump_readback_missing": (("NoSuchKey", None), [LOCAL_ORIGINAL]),
    "dump_readback_denied": (("ClientError", None), [LOCAL_ORIGINAL, PUBLISHED_DUMP]),
    "existing_original_denied": (("CheckError", STORE), [LOCAL_ORIGINAL]),
}


@pytest.mark.parametrize("case", PUBLISH_FAILURES)
def test_publishing_object_failure_publishes_no_manifest(case, bucket, tmp_path):
    """Publishing keeps its own object errors; only verify and download changed in #186."""
    from app.core.config import Settings
    from app.integrations.storage_client import StorageRouter
    from scripts.image_backup import BackupBucket, publish_backup
    from scripts.operator_errors import CheckError

    (tmp_path / "a.png").write_bytes(LOCAL_BYTES)
    dump = tmp_path / "database.dump"
    dump.write_bytes(DUMP)
    storage = StorageRouter(Settings(
        _env_file=None, app_environment="test", youtube_summary_enabled=False,
        storage_backend="local", storage_root=tmp_path,
    ))
    snapshot = manifest("unused", "unused", [asset(1, "local", "a.png", LOCAL_BYTES)])
    snapshot = {key: snapshot[key] for key in (
        "migration_revisions", "tables", "category_links_sha256", "sample", "extra_file_count",
    )} | {"assets": [{key: value for key, value in snapshot["assets"][0].items()
                      if key != "backup_key"}]}
    PUBLISH_FAILURES[case](bucket)
    try:
        asyncio.run(publish_backup(
            BackupBucket(bucket.client, BUCKET), backup_id="point", snapshot=snapshot,
            database=dump, storage=storage, captured_at="2026-10-01T00:00:00+00:00",
            app_commit="a" * 40, postgres_major=17, origin="synthetic",
        ))
        raised = None
    except CheckError as exc:
        raised = ("CheckError", str(exc))
    except Exception as exc:
        raised = (type(exc).__name__, None)
    assert (raised, bucket.keys()) == PUBLISH_FAILURE_OUTPUTS[case]


LEDGER_KEY_ID, LEDGER_SECRET = "LEDGERKEYID342", "ledger-secret-342"


def ledger_settings(endpoint, bucket):
    from app.core.deletion_ledger_config import DeletionLedgerSettings

    return DeletionLedgerSettings(
        app_environment="test", deletion_ledger_backend="s3",
        deletion_ledger_s3_endpoint_url=endpoint, deletion_ledger_s3_bucket=bucket,
        deletion_ledger_s3_region="us-east-1",
        deletion_ledger_s3_access_key_id=SecretStr(LEDGER_KEY_ID),
        deletion_ledger_s3_secret_access_key=SecretStr(LEDGER_SECRET),
    )


def wire_s3_ledger(monkeypatch, settings, timeouts):
    """The real ledger built with run_job's arguments; its first `timeouts` GETs time out."""
    import app.integrations.deletion_ledger as deletion_ledger

    def wiring(config=None, **kwargs):
        ledger = build_deletion_ledger(settings, **kwargs)
        sent = []

        def time_out(request, **_):
            sent.append(request)
            if len(sent) <= timeouts:
                raise ReadTimeoutError(endpoint_url=settings.deletion_ledger_s3_endpoint_url)

        ledger.store.client.meta.events.register("before-send.s3.GetObject", time_out)
        return ledger

    monkeypatch.setattr(deletion_ledger, "get_deletion_ledger", wiring)


def test_maintain_survives_one_ledger_read_timeout(
    bucket, maintenance_runtime, monkeypatch, capsys
):
    """#342: backup and retention jobs retry a ledger GET that timed out once."""
    settings = ledger_settings("https://s3.amazonaws.com", "ledger-342")
    bucket.client.create_bucket(Bucket="ledger-342")
    build_deletion_ledger(settings).initialize()
    wire_s3_ledger(monkeypatch, settings, timeouts=1)
    now = datetime.now(UTC)
    bucket.point("anchor", manifest("anchor", (now - timedelta(hours=1)).isoformat()))
    bucket.point("target", manifest("target", (now - FRESH).isoformat()))
    assert maintain(monkeypatch, capsys) == (0, KEPT)


def test_maintain_reports_exception_class_names_only(
    bucket, maintenance_runtime, monkeypatch, capsys
):
    """#342: an unreachable ledger fails with class names; no message, URL, bucket or key."""
    from scripts.image_backup_jobs import main

    endpoint, ledger_bucket = "https://ledger-342.invalid", "ledger-bucket-342"
    wire_s3_ledger(monkeypatch, ledger_settings(endpoint, ledger_bucket), timeouts=float("inf"))
    monkeypatch.setattr(sys, "argv", ["image_backup_jobs", "maintain"])
    code = main()
    out = capsys.readouterr().out
    assert (code, json.loads(out)) == job_failure("LedgerUnavailableError", "ReadTimeoutError")
    for secret in (endpoint, "ledger-342.invalid", ledger_bucket, LEDGER_KEY_ID, LEDGER_SECRET,
                   "Deletion ledger cannot be verified", "Read timeout"):
        assert secret not in out
