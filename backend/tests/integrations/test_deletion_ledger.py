"""Account deletion records in the deletion ledger (ADR 0008), observed through its readers."""

import json
from uuid import uuid4

import pytest

from app.integrations.deletion_ledger import (
    DeletionLedger,
    LedgerUnavailableError,
    LocalLedgerStore,
    deleted_contents,
)

ASSET = {"storage_backend": "s3", "storage_key": "a.png", "sha256": "a" * 64, "size_bytes": 3}


@pytest.fixture
def ledger(tmp_path):
    value = DeletionLedger(LocalLedgerStore(tmp_path / "ledger"))
    value.initialize()
    return value


def image_record(**overrides):
    return {
        "operation_id": str(uuid4()), "user_id": 1, "content_id": 10,
        "saved_at": "2026-10-01T00:00:00+00:00", "deleted_at": "2026-11-01T00:00:00+00:00",
        "assets": [ASSET], **overrides,
    }


def account_record(**overrides):
    return {
        "kind": "account_deletion", "operation_id": str(uuid4()), "user_id": 1,
        "user_created_at": "2026-09-01T00:00:00+00:00",
        "deleted_at": "2026-11-02T00:00:00+00:00",
        "contents": [
            {"content_id": 11, "saved_at": "2026-10-02T00:00:00+00:00", "assets": [ASSET]},
        ],
        **overrides,
    }


def test_ledger_with_only_image_records_reads_unchanged(ledger, tmp_path):
    record = image_record()
    ledger.append(record)
    stored = json.loads((tmp_path / "ledger" / f"event-{1:020d}.json").read_text())
    assert stored["event"] == record
    assert ledger.read_verified_events() == [record]


def test_account_record_is_written_and_verified_by_every_reader(ledger):
    from scripts.image_backup_jobs import latest_deletions

    before = ledger.read_verified_checkpoint()
    image, account = image_record(), account_record()
    ledger.append(image)
    checkpoint = ledger.append(account)
    # Backup creation: bounded tip capture, then full prefix verification.
    assert ledger.read_checkpoint_tip() == checkpoint
    assert ledger.read_verified_events(checkpoint) == [image, account]
    assert ledger.read_operation(account["operation_id"]) == account
    # Restore: the live ledger is newer than the backup checkpoint.
    assert latest_deletions(ledger, before) == (checkpoint, [image, account])
    # A record appended after an account record still verifies the chain.
    later = image_record(content_id=12)
    ledger.append(later)
    assert ledger.read_verified_events() == [image, account, later]


def test_account_record_without_image_contents_is_accepted(ledger):
    record = account_record(contents=[])
    ledger.append(record)
    assert ledger.read_verified_events() == [record]


@pytest.mark.parametrize("change", [
    {"user_created_at": "2026-09-01T00:00:00"},
    {"user_created_at": None},
    {"user_created_at": 1},
    {"deleted_at": "2026-11-02"},
    {"user_id": 0},
    {"user_id": 1.5},
    {"user_id": [1]},
    {"user_id": None},
    {"kind": "account"},
    {"contents": None},
    {"contents": [{"content_id": 11, "saved_at": "2026-10-02T00:00:00+00:00", "assets": []}]},
    {"contents": [{"content_id": 0, "saved_at": "2026-10-02T00:00:00+00:00",
                   "assets": [ASSET]}]},
    {"contents": [{"content_id": 11, "saved_at": "2026-10-02T00:00:00", "assets": [ASSET]}]},
    {"contents": [[]]},
    {"email": "user@example.com"},
    {"display_name": "사용자"},
])
def test_invalid_account_record_is_never_written(ledger, change):
    with pytest.raises(ValueError):
        ledger.append(account_record(**change))
    assert ledger.read_verified_checkpoint()["sequence"] == 0


@pytest.mark.parametrize("missing", ["user_created_at", "contents", "deleted_at", "kind"])
def test_account_record_missing_a_field_is_never_written(ledger, missing):
    record = account_record()
    del record[missing]
    with pytest.raises(ValueError):
        ledger.append(record)
    assert ledger.read_verified_checkpoint()["sequence"] == 0


def test_tampered_account_record_stops_verification(ledger, tmp_path):
    ledger.append(account_record())
    path = tmp_path / "ledger" / f"event-{1:020d}.json"
    record = json.loads(path.read_text())
    record["event"]["email"] = "user@example.com"
    path.write_text(json.dumps(record))
    with pytest.raises(LedgerUnavailableError):
        ledger.read_verified_events()


def test_retried_account_deletion_reuses_its_confirmed_record(ledger):
    first = account_record()
    checkpoint = ledger.append(first)
    retried = {**first, "deleted_at": "2026-11-03T00:00:00+00:00", "contents": []}
    assert ledger.append(retried) == checkpoint
    assert ledger.read_operation(first["operation_id"]) == first
    other_account = {**first, "user_created_at": "2026-09-05T00:00:00+00:00"}
    with pytest.raises(LedgerUnavailableError, match="identity conflicts"):
        ledger.append(other_account)


def test_deleted_contents_flattens_account_records_into_image_identities():
    image, account = image_record(), account_record()
    assert deleted_contents(image) == [image]
    assert deleted_contents(account) == [{
        "user_id": 1, "deleted_at": account["deleted_at"], "content_id": 11,
        "saved_at": "2026-10-02T00:00:00+00:00", "assets": [ASSET],
    }]
    assert deleted_contents(account_record(contents=[])) == []
