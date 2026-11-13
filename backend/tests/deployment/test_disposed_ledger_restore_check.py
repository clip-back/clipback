"""`restore-check` and the ledger `checkpoint` command on a disposed ledger (#345, ADR 0013).

The restore check verifies the point's checkpoint and reads the latest deletions before its
first Docker call; a fake failing Docker marks that every ledger check passed.
"""

import asyncio
import json
from argparse import Namespace
from uuid import uuid4

import pytest

from app.integrations.deletion_ledger import (
    DeletionLedger,
    LedgerUnavailableError,
    LocalLedgerStore,
)
from tests.deployment.test_recovery_point_folder_outputs import (
    LOADED,
    credentials as credentials,
    failing_docker as failing_docker,
    ledger as ledger,
    restore_check,
    write_folder,
)


def image_event(content_id):
    return {
        "operation_id": str(uuid4()), "user_id": 1, "content_id": content_id,
        "saved_at": "2026-10-01T00:00:00+00:00", "deleted_at": "2026-11-01T00:00:00+00:00",
        "assets": [{"storage_backend": "s3", "storage_key": f"k{content_id}",
                    "sha256": None, "size_bytes": None}],
    }


def test_point_at_or_after_the_start_passes_the_ledger_checks(
    failing_docker, credentials, ledger, monkeypatch, capsys, tmp_path,
):
    ledger.append(image_event(1))
    point = ledger.read_checkpoint_tip()
    ledger.append(image_event(2))
    ledger.dispose_through(1)
    directory = write_folder(tmp_path / "backup", checkpoint=point)
    assert restore_check(directory, credentials, monkeypatch, capsys) == (
        1, {**LOADED, "error": "docker_command_failed", "synthetic_only": True},
    )


def test_point_before_the_start_fails_before_any_docker_call(
    failing_docker, credentials, ledger, monkeypatch, capsys, tmp_path,
):
    ledger.append(image_event(1))
    point = ledger.read_checkpoint_tip()
    ledger.append(image_event(2))
    ledger.dispose_through(2)
    directory = write_folder(tmp_path / "backup", checkpoint=point)
    assert restore_check(directory, credentials, monkeypatch, capsys) == (
        1, {"cause": "ValueError", "error": "backup_job_failed",
            "exception": "LedgerUnavailableError", "passed": False},
    )


def test_checkpoint_command_verifies_from_the_start(monkeypatch, tmp_path):
    from scripts.image_deletions import run

    root = tmp_path / "ledger"
    live = DeletionLedger(LocalLedgerStore(root))
    live.initialize()
    live.append(image_event(1))
    live.append(image_event(2))
    live.dispose_through(2)
    monkeypatch.setenv("DELETION_LEDGER_BACKEND", "local")
    monkeypatch.setenv("DELETION_LEDGER_ROOT", str(root))
    head = json.loads((root / "head.json").read_text())
    assert asyncio.run(run(Namespace(command="checkpoint"))) == head
    (root / "start.json").unlink()
    with pytest.raises(LedgerUnavailableError):
        asyncio.run(run(Namespace(command="checkpoint")))
