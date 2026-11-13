"""Readers keep working on a ledger whose records were disposed (#345, ADR 0013).

Content and account deletion, the operator retry, Volume migration and backup capture all run
against the real test DB and a local ledger whose records 1..start were removed.
"""

import os
from datetime import UTC, datetime
from types import SimpleNamespace
from uuid import uuid4

import boto3
import pytest
from moto import mock_aws
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine

from app.core.config import settings
from app.integrations.deletion_ledger import LedgerUnavailableError, get_deletion_ledger
from app.integrations.storage_client import StorageRouter
from app.services.account_deletion_service import record_account_deletion
from app.services.image_deletion_service import retry_image_deletions
from tests.integration.helpers import guest, request
from tests.integration.test_image_deletion import committed_api as committed_api, upload
from tests.integration.test_image_migration import prepared_backup

pytestmark = pytest.mark.asyncio


def dispose_everything():
    ledger = get_deletion_ledger()
    start = ledger.dispose_through(ledger.read_checkpoint_tip()["sequence"])
    root = settings.deletion_ledger_root
    assert sorted(path.name for path in root.iterdir()) == [
        "head.json", "namespace.json", "start.json",
    ]
    return start


async def test_deletion_retry_and_migration_continue_after_every_record_is_disposed(
    committed_api, s3_storage, png_bytes, monkeypatch, tmp_path,
):
    from scripts.image_migration import migrate_originals

    client, headers, sessions = committed_api
    monkeypatch.setattr(settings, "storage_backend", "local")
    kept, removed, later = [await upload(client, headers, png_bytes) for _ in range(3)]
    response = await client.delete(f"/api/v1/contents/{removed['id']}", headers=headers)
    assert response.status_code == 204
    start = dispose_everything()
    # R1: the API appends after the start point when no record file is left.
    response = await client.delete(f"/api/v1/contents/{later['id']}", headers=headers)
    assert response.status_code == 204
    events = get_deletion_ledger().read_verified_events()
    assert [event["content_id"] for event in events] == [later["id"]]
    assert get_deletion_ledger().read_checkpoint_tip()["sequence"] == start["sequence"] + 1
    async with sessions() as session:
        retried = await retry_image_deletions(session)
    assert retried["pending"] == 0
    dispose_everything()
    directory = tmp_path / "verified-backup"
    report = await prepared_backup(sessions, [kept], s3_storage, directory)
    result = await migrate_originals(
        sessions.kw["bind"], StorageRouter(settings),
        backup_directory=directory, restore_report_file=report,
    )
    assert result["passed"] is True and result["migrated"] == 1
    assert (
        await client.get(kept["assets"][0]["download_url"], headers=headers)
    ).content == png_bytes


async def test_account_deletion_is_recorded_and_retried_after_disposal(
    api, database_connection, png_bytes,
):
    headers, _, user = await guest(api)
    content = await upload(api, headers, png_bytes)
    await request(api, "DELETE", f"contents/{content['id']}", headers=headers, status=204)
    dispose_everything()
    session = AsyncSession(bind=database_connection, expire_on_commit=False,
                           join_transaction_mode="create_savepoint")
    async with session:
        record = await record_account_deletion(session, user["id"])
        # The DB transaction fails after the ledger write (U2).
        await session.rollback()
    assert get_deletion_ledger().read_verified_events() == [record]
    async with AsyncSession(bind=database_connection, expire_on_commit=False,
                            join_transaction_mode="create_savepoint") as session:
        result = await retry_image_deletions(session)
    assert result["deleted_accounts"] == 1


@pytest.fixture
def backup_job(monkeypatch, tmp_path):
    """Real create_backup with the test DB locks and snapshot; only the dump and probe are fake."""
    import app.integrations.deletion_ledger as deletion_ledger
    import app.services.maintenance as maintenance
    import scripts.image_backup as image_backup
    import scripts.operator_runtime as operator_runtime
    import scripts.recovery_probe as recovery_probe
    from scripts.image_backup import BackupBucket
    from tests.support.maintenance import OpenUnitGate

    database_url = os.environ.get("TEST_DATABASE_URL")
    if not database_url:
        pytest.skip("TEST_DATABASE_URL is required for PostgreSQL tests")
    ledger = get_deletion_ledger()

    class Runtime:
        def __init__(self):
            self.engine = create_async_engine(database_url)
            self.config = SimpleNamespace(database_url=database_url)
            self.sessions = None
            self.storage = StorageRouter(settings)

        async def preflight_source(self):
            pass

        async def close(self):
            await self.engine.dispose()

    async def snapshot(payload, *, runtime=None):
        return {"migration_revisions": ["x"], "tables": {}, "category_links_sha256": "c" * 64,
                "assets": [], "sample": None, "extra_file_count": 0}

    def dump_database(database_url, snapshot_id, destination, *args):
        destination.write_bytes(b"synthetic dump")

    monkeypatch.setattr(operator_runtime, "OperatorRuntime", Runtime)
    monkeypatch.setattr(deletion_ledger, "get_deletion_ledger",
                        lambda config=None, **kwargs: ledger)
    monkeypatch.setattr(maintenance, "MaintenanceGate", lambda sessions: OpenUnitGate())
    monkeypatch.setattr(recovery_probe, "snapshot", snapshot)
    monkeypatch.setattr(image_backup, "dump_database", dump_database)
    with mock_aws():
        client = boto3.client("s3", region_name="us-east-1")
        client.create_bucket(Bucket="private-backup")
        yield SimpleNamespace(ledger=ledger, store=BackupBucket(client, "private-backup"))


async def test_daily_and_manual_backups_capture_a_disposed_ledger(backup_job):
    from scripts.image_backup_jobs import run_job
    from scripts.recovery_point import read_point_json

    ledger, store = backup_job.ledger, backup_job.store
    ledger.append(image_event(1))
    ledger.append(image_event(2))
    start = ledger.dispose_through(2)
    daily = await run_job(store, command="daily", app_commit="a" * 40, origin="synthetic")
    assert daily["backup_created"] is True
    assert read_point_json(store, daily["backup_id"])["deletion_checkpoint"] == start
    ledger.append(image_event(3))
    manual = await run_job(store, command="manual", app_commit="a" * 40, origin="synthetic",
                           backup_id="manual-345")
    checkpoint = read_point_json(store, "manual-345")["deletion_checkpoint"]
    assert manual["backup_created"] is True and checkpoint["sequence"] == 3
    assert [event["content_id"] for event in ledger.read_verified_events(checkpoint)] == [3]
    (settings.deletion_ledger_root / "start.json").write_text("{")
    with pytest.raises(LedgerUnavailableError):
        await run_job(store, command="manual", app_commit="a" * 40, origin="synthetic",
                      backup_id="manual-corrupt")


def image_event(content_id):
    now = datetime.now(UTC).isoformat()
    return {"operation_id": str(uuid4()), "user_id": 1,
            "content_id": content_id, "saved_at": now, "deleted_at": now,
            "assets": [{"storage_backend": "s3", "storage_key": f"k{content_id}",
                        "sha256": None, "size_bytes": None}]}
