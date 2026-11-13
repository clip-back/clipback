"""Backup maintenance disposes deletion ledger records and cleanup rows (#346, ADR 0013).

The backup Bucket is moto, the ledger is the local test ledger and the DB is the test PostgreSQL.
Decision tables use the disposal step with a fixed `now`; the status table runs the real
`image_backup_jobs maintain` command with its real runtime (DB locks, maintenance gate).
"""

import asyncio
import hashlib
import json
import os
import random
import sys
from datetime import UTC, datetime, timedelta
from uuid import uuid4

import boto3
import pytest
import pytest_asyncio
from moto import mock_aws
from sqlalchemy import delete, insert, select, text, update
from sqlalchemy.ext.asyncio import AsyncConnection, AsyncSession, create_async_engine

from app.core.config import settings
from app.integrations.deletion_ledger import (
    DeletionLedger,
    LocalLedgerStore,
    account_content_operation_id,
    get_deletion_ledger,
)
from app.models.image_deletion import ImageDeletion
from app.models.user import User

pytestmark = pytest.mark.asyncio

BUCKET = "private-backup"
LEDGER_LOCK, JOB_LOCK = 74264002, 74264003
SAVED_AT = "2026-09-01T00:00:00+00:00"
ASSET = {"storage_backend": "s3", "storage_key": "gone.png", "sha256": None, "size_bytes": None}


class World:
    def __init__(self, engine, store):
        self.engine, self.store = engine, store
        self.ledger = get_deletion_ledger()
        self.now = datetime.now(UTC)
        self.users = set()

    def uid(self):
        value = random.randint(10**9, 2 * 10**9)
        self.users.add(value)
        return value

    def ago(self, **delta):
        return self.now - timedelta(**delta)

    async def row(self, operation_id, user_id, deleted_at, *, completed=True, content_id=0,
                  intent=None):
        async with self.engine.begin() as connection:
            await connection.execute(insert(ImageDeletion).values(
                operation_id=operation_id, user_id=user_id, content_id=content_id,
                intent=intent or {"assets": [ASSET]}, deleted_at=deleted_at,
                completed=completed, attempts=0,
            ))
        return operation_id

    async def image(self, deleted_at, *, completed=True, row=True):
        """An image deletion record and, unless `row` is False, its cleanup row."""
        event = {"operation_id": str(uuid4()), "user_id": self.uid(), "content_id": 7,
                 "saved_at": SAVED_AT, "deleted_at": deleted_at.isoformat(), "assets": [ASSET]}
        self.ledger.append(event)
        if row:
            await self.row(event["operation_id"], event["user_id"], deleted_at,
                           completed=completed, content_id=7, intent=event)
        return event["operation_id"]

    async def account(self, deleted_at, *, rows=(), user=None):
        """An account record; `rows` are completion flags of the cleanup rows it made."""
        user_id = self.uid()
        created_at = datetime(2026, 8, 1, tzinfo=UTC)
        if user is not None:
            async with self.engine.begin() as connection:
                await connection.execute(insert(User).values(
                    id=user_id, created_at=created_at + user, display_name="disposal",
                ))
        event = {"kind": "account_deletion", "operation_id": str(uuid4()), "user_id": user_id,
                 "user_created_at": created_at.isoformat(), "deleted_at": deleted_at.isoformat(),
                 "contents": []}
        self.ledger.append(event)
        made = []
        for content_id, completed in enumerate(rows, 1):
            operation = account_content_operation_id(event["operation_id"], content_id, SAVED_AT)
            made.append(await self.row(operation, user_id, deleted_at, completed=completed,
                                       content_id=content_id, intent={
                                           "operation_id": operation, "user_id": user_id,
                                           "content_id": content_id, "saved_at": SAVED_AT,
                                           "deleted_at": event["deleted_at"], "assets": [ASSET],
                                       }))
        return user_id, made

    def point(self, identifier, captured_at, checkpoint):
        manifest = {
            "format_version": 2, "backup_id": identifier, "origin": "synthetic",
            "captured_at": captured_at.isoformat(), "app_commit": "a" * 40,
            "postgres_major": 17, "migration_revisions": ["202611060022"], "tables": {"users": 1},
            "category_links_sha256": "c" * 64, "assets": [], "sample": None,
            "database": {"file": "database.dump",
                         "backup_key": f"points/{identifier}/database.dump", "size_bytes": 4,
                         "sha256": hashlib.sha256(b"dump").hexdigest()},
            "deletion_checkpoint": checkpoint,
        }
        self.store.put_verified(f"points/{identifier}/database.dump", b"dump")
        self.store.put_verified(f"points/{identifier}/manifest.json", json.dumps(manifest).encode())

    def checkpoint(self, sequence):
        head = self.ledger.read_verified_checkpoint()
        digest = hashlib.sha256((settings.deletion_ledger_root / f"event-{sequence:020d}.json")
                                .read_bytes()).hexdigest()
        return {"namespace": head["namespace"], "sequence": sequence, "digest": digest}

    def start(self):
        path = settings.deletion_ledger_root / "start.json"
        return json.loads(path.read_text())["sequence"] if path.exists() else 0

    def files(self):
        return sorted(path.name for path in settings.deletion_ledger_root.iterdir()
                      if path.name.startswith("event-"))

    async def rows(self):
        async with self.engine.connect() as connection:
            return set(await connection.scalars(
                select(ImageDeletion.operation_id).where(ImageDeletion.user_id.in_(self.users))
            ))

    async def dispose(self, now=None):
        from scripts.image_backup_jobs import dispose_deletion_records

        return await dispose_deletion_records(self.store, self.ledger, self.engine,
                                              now=now or self.now)


@pytest_asyncio.fixture
async def world():
    database_url = os.environ.get("TEST_DATABASE_URL")
    if not database_url:
        pytest.skip("TEST_DATABASE_URL is required for PostgreSQL tests")
    from scripts.image_backup import BackupBucket

    engine = create_async_engine(database_url)
    with mock_aws():
        client = boto3.client("s3", region_name="us-east-1")
        client.create_bucket(Bucket=BUCKET)
        state = World(engine, BackupBucket(client, BUCKET))
        try:
            yield state
        finally:
            async with engine.begin() as connection:
                await connection.execute(
                    delete(ImageDeletion).where(ImageDeletion.user_id.in_(state.users)))
                await connection.execute(delete(User).where(User.id.in_(state.users)))
            await engine.dispose()


def result(pruned, overdue, rows):
    return {"deletion_records_pruned": pruned, "deletion_records_overdue": overdue,
            "image_deletion_rows_pruned": rows}


# Disposal decision table (spec #344): record 1 and record 2 in ledger order.

async def test_both_passing_records_are_disposed(world):
    await world.image(world.ago(days=29, hours=12))
    await world.image(world.ago(days=29, hours=1))
    assert await world.dispose() == result(2, 0, 2)
    assert world.start() == 2 and world.files() == []
    assert await world.rows() == set()


async def test_younger_first_record_keeps_a_passing_later_one(world):
    """Timestamps can run backwards in ledger order; the order still decides."""
    await world.image(world.ago(days=28))
    await world.image(world.ago(days=29, hours=5))
    assert await world.dispose() == result(0, 0, 0)
    assert world.start() == 0 and len(world.files()) == 2


async def test_unfinished_first_record_keeps_both_and_both_are_overdue(world):
    first = await world.image(world.ago(days=31), completed=False)
    second = await world.image(world.ago(days=31))
    assert await world.dispose() == result(0, 2, 0)
    assert world.start() == 0
    assert await world.rows() == {first, second}


async def test_only_the_unfinished_later_record_stays(world):
    await world.image(world.ago(days=29, hours=12))
    second = await world.image(world.ago(days=30, hours=1), completed=False)
    assert await world.dispose() == result(1, 1, 1)
    assert world.start() == 1 and world.files() == [f"event-{2:020d}.json"]
    assert await world.rows() == {second}


async def test_records_after_the_oldest_surviving_checkpoint_stay(world):
    await world.image(world.ago(days=30))
    second = await world.image(world.ago(days=31))
    world.point("older", world.ago(days=2), world.checkpoint(1))
    world.point("newer", world.ago(hours=1), world.checkpoint(2))
    # (c) boundary: sequence 1 equals the smallest checkpoint, sequence 2 is past it.
    assert await world.dispose() == result(1, 1, 1)
    assert world.start() == 1
    assert await world.rows() == {second}


async def test_account_record_waits_for_every_cleanup_row_it_made(world):
    _, made = await world.account(world.ago(days=31), rows=(True, False))
    await world.image(world.ago(days=30))
    assert await world.dispose() == result(0, 1, 0)
    assert world.start() == 0
    assert set(made) <= await world.rows()


async def test_reused_account_number_is_not_the_deleted_account(world):
    """Another account with the same number but another creation time; no cleanup rows."""
    await world.account(world.ago(days=30), user=timedelta(days=1))
    await world.image(world.ago(days=30))
    assert await world.dispose() == result(2, 0, 1)
    assert world.start() == 2


async def test_points_without_a_checkpoint_do_not_limit_disposal(world):
    await world.image(world.ago(days=30))
    await world.image(world.ago(days=30))
    world.point("uncaptured", world.ago(hours=1), None)
    assert await world.dispose() == result(2, 0, 2)


async def test_image_record_without_a_cleanup_row_is_not_finished(world):
    await world.image(world.ago(days=30), row=False)
    await world.image(world.ago(days=30))
    assert await world.dispose() == result(0, 0, 0)
    assert world.start() == 0


async def test_account_still_in_the_db_keeps_its_record(world):
    await world.account(world.ago(days=30), user=timedelta(0))
    assert await world.dispose() == result(0, 0, 0)
    assert world.start() == 0


async def test_finished_account_record_is_disposed_with_its_rows(world):
    _, made = await world.account(world.ago(days=30), rows=(True, True))
    assert await world.dispose() == result(1, 0, 2)
    assert set(made).isdisjoint(await world.rows())


# Cleanup row deletion (Q-B3, R3, A2).

async def test_rows_bound_to_remaining_records_stay(world):
    await world.image(world.ago(days=31), completed=False)
    bound = await world.image(world.ago(days=31))
    user_id, made = await world.account(world.ago(days=31), rows=(True,), user=timedelta(0))
    loose = await world.row(str(uuid4()), user_id, world.ago(days=31))
    assert await world.dispose() == result(0, 3, 1)
    rows = await world.rows()
    assert bound in rows and set(made) <= rows and loose not in rows


async def test_upload_failure_rows_follow_the_deletion_time(world):
    user_id = world.uid()
    old = await world.row(str(uuid4()), user_id, world.ago(days=29, minutes=1))
    young = await world.row(str(uuid4()), user_id, world.ago(days=28, hours=23))
    pending = await world.row(str(uuid4()), user_id, world.ago(days=31), completed=False)
    assert await world.dispose() == result(0, 0, 1)
    assert await world.rows() == {young, pending}
    assert old not in await world.rows()


async def test_migration_rows_are_kept(world):
    """A user deletion later needs this row to remove the retained Volume alias (A2)."""
    user_id = world.uid()
    migration = await world.row(str(uuid4()), user_id, world.ago(days=40), intent={
        "source_identity": {"user_id": user_id, "content_id": 3, "saved_at": SAVED_AT,
                            "assets": [ASSET]},
        "assets": [ASSET],
    })
    failed_upload = await world.row(str(uuid4()), user_id, world.ago(days=40))
    assert await world.dispose() == result(0, 0, 1)
    assert await world.rows() == {migration}
    assert failed_upload not in await world.rows()


async def test_rows_brought_back_by_a_restore_are_deleted_again(world):
    operation = await world.image(world.ago(days=30))
    assert await world.dispose() == result(1, 0, 1)
    await world.row(operation, world.uid(), world.ago(days=30))
    assert await world.dispose() == result(0, 0, 1)
    assert operation not in await world.rows()


async def test_late_completion_counts_from_the_deletion_time(world):
    late = await world.image(world.ago(days=31), completed=False)
    pending = await world.image(world.ago(days=31), completed=False)
    assert await world.dispose() == result(0, 2, 0)
    async with world.engine.begin() as connection:
        await connection.execute(update(ImageDeletion).where(
            ImageDeletion.operation_id == late).values(completed=True))
    assert await world.dispose() == result(1, 1, 1)
    assert await world.rows() == {pending}


async def test_row_changed_after_the_decision_stays(world, monkeypatch):
    user_id = world.uid()
    rebound, reopened, loose = [
        await world.row(str(uuid4()), user_id, world.ago(days=31)) for _ in range(3)
    ]
    original = DeletionLedger.delete_disposed

    def change_then_delete(self):
        # Between the decision under the ledger lock and the row deletion.
        self.append({"operation_id": rebound, "user_id": user_id, "content_id": 7,
                     "saved_at": SAVED_AT, "deleted_at": world.now.isoformat(),
                     "assets": [ASSET]})
        asyncio.run(reopen())
        return original(self)

    async def reopen():
        engine = create_async_engine(os.environ["TEST_DATABASE_URL"])
        async with engine.begin() as connection:
            await connection.execute(update(ImageDeletion).where(
                ImageDeletion.operation_id == reopened).values(completed=False))
        await engine.dispose()

    monkeypatch.setattr(DeletionLedger, "delete_disposed", change_then_delete)
    assert await world.dispose() == result(0, 0, 1)
    assert await world.rows() == {rebound, reopened}
    assert loose not in await world.rows()


# Locks (Q-B4) and the read-only decision transaction (R4).

async def advisory_locks(engine):
    """Advisory lock keys other sessions hold in this database."""
    async with engine.connect() as connection:
        return set(await connection.scalars(text(
            "SELECT objid FROM pg_locks WHERE locktype = 'advisory' AND granted "
            "AND pid <> pg_backend_pid() "
            "AND database = (SELECT oid FROM pg_database WHERE datname = current_database())"
        )))


async def test_disposal_waits_for_the_ledger_lock(world):
    await world.image(world.ago(days=30))
    async with world.engine.connect() as holder:
        await holder.execute(text("SELECT pg_advisory_lock(:key)"), {"key": LEDGER_LOCK})
        task = asyncio.create_task(world.dispose())
        await asyncio.sleep(0.5)
        assert not task.done() and world.start() == 0
        await holder.execute(text("SELECT pg_advisory_unlock(:key)"), {"key": LEDGER_LOCK})
        await holder.rollback()
    assert await task == result(1, 0, 1)


async def test_ledger_lock_covers_only_the_decision(world, maintain_env, monkeypatch):
    import scripts.image_backup_jobs as jobs

    await world.image(world.ago(days=30))
    world.point("fresh", world.ago(hours=1), None)
    seen = {}
    loop = asyncio.get_running_loop()
    decide, delete_files, commit = (jobs.reflected_prefix, DeletionLedger.delete_disposed,
                                    AsyncConnection.commit)

    async def deciding(connection, events):
        seen["decision"] = await advisory_locks(world.engine)
        seen["read_only"] = await connection.scalar(text("SHOW transaction_read_only"))
        return await decide(connection, events)

    def deleting_files(self):
        seen["files"] = asyncio.run_coroutine_threadsafe(
            advisory_locks(world.engine), loop).result()
        return delete_files(self)

    async def committing(self):
        seen["rows"] = await advisory_locks(world.engine)
        return await commit(self)

    monkeypatch.setattr(jobs, "reflected_prefix", deciding)
    monkeypatch.setattr(DeletionLedger, "delete_disposed", deleting_files)
    monkeypatch.setattr(AsyncConnection, "commit", committing)
    report = await jobs.run_job(world.store, command="maintain")
    assert report["deletion_records_pruned"] == 1
    assert seen == {"decision": {LEDGER_LOCK, JOB_LOCK}, "read_only": "on",
                    "files": {JOB_LOCK}, "rows": {JOB_LOCK}}
    assert await advisory_locks(world.engine) == set()


# `maintain` status and error table through the real command.

@pytest.fixture
def maintain_env(world, monkeypatch):
    from scripts.image_backup import BackupBucket

    monkeypatch.setenv("APP_ENVIRONMENT", "test")
    monkeypatch.setenv("DATABASE_URL", os.environ["TEST_DATABASE_URL"])
    monkeypatch.setenv("DELETION_LEDGER_BACKEND", "local")
    monkeypatch.setenv("DELETION_LEDGER_ROOT", str(settings.deletion_ledger_root))
    monkeypatch.setattr(BackupBucket, "from_environment", classmethod(lambda cls: world.store))


async def maintain(monkeypatch, capsys):
    from scripts.image_backup_jobs import main

    monkeypatch.setattr(sys, "argv", ["image_backup_jobs", "maintain"])
    capsys.readouterr()
    code = await asyncio.to_thread(main)
    return code, json.loads(capsys.readouterr().out)


def report(pruned=0, overdue=0, rows=0, *, passed=True, fresh=True, expired=0, retained=1,
           retention_overdue=0):
    return {"deletion_records_overdue": overdue, "deletion_records_pruned": pruned,
            "expired_points": expired, "freshness_met": fresh,
            "image_deletion_rows_pruned": rows, "passed": passed, "removed_originals": 0,
            "retained_points": retained, "retention_overdue": retention_overdue}


def job_failure(exception, cause=None):
    return 1, {"passed": False, "error": "backup_job_failed", "exception": exception,
               "cause": cause}


async def test_quiet_run_reports_zero_disposal(world, maintain_env, monkeypatch, capsys):
    world.point("fresh", world.ago(hours=1), None)
    await world.image(world.ago(days=1))
    assert await maintain(monkeypatch, capsys) == (0, report())


async def test_disposal_run_passes_with_healthy_retention(world, maintain_env, monkeypatch,
                                                          capsys):
    world.point("fresh", world.ago(hours=1), None)
    await world.image(world.ago(days=29, hours=12))
    assert await maintain(monkeypatch, capsys) == (0, report(1, 0, 1))
    assert world.start() == 1 and world.files() == []


async def test_overdue_record_fails_after_disposing_the_front(world, maintain_env, monkeypatch,
                                                              capsys):
    world.point("fresh", world.ago(hours=1), None)
    await world.image(world.ago(days=29, hours=12))
    late = await world.image(world.ago(days=31), completed=False)
    assert await maintain(monkeypatch, capsys) == (1, report(1, 1, 1, passed=False))
    assert world.start() == 1 and await world.rows() == {late}


async def test_retention_exception_disposes_nothing(world, maintain_env, monkeypatch, capsys):
    world.point("fresh", world.ago(hours=1), None)
    world.store.put_verified("points/corrupt/manifest.json", b"not json")
    operation = await world.image(world.ago(days=29, hours=12))
    assert await maintain(monkeypatch, capsys) == (1, {"passed": False,
                                                       "error": "invalid_manifest"})
    assert world.start() == 0 and await world.rows() == {operation}


async def test_ledger_failure_disposes_nothing(world, maintain_env, monkeypatch, capsys):
    world.point("fresh", world.ago(hours=1), None)
    operation = await world.image(world.ago(days=29, hours=12))
    (settings.deletion_ledger_root / "start.json").write_text("{")
    assert await maintain(monkeypatch, capsys) == job_failure("LedgerUnavailableError",
                                                              "JSONDecodeError")
    assert len(world.files()) == 1 and await world.rows() == {operation}


async def test_condition_read_failure_disposes_nothing_and_releases_the_lock(
    world, maintain_env, monkeypatch, capsys,
):
    import scripts.image_backup_jobs as jobs

    world.point("fresh", world.ago(hours=1), None)
    operation = await world.image(world.ago(days=29, hours=12))

    async def failing(connection, events):
        await connection.execute(text("SELECT 1"))
        raise ConnectionResetError

    monkeypatch.setattr(jobs, "reflected_prefix", failing)
    assert await maintain(monkeypatch, capsys) == job_failure("ConnectionResetError")
    assert world.start() == 0 and await world.rows() == {operation}
    async with world.engine.connect() as other:
        assert await other.scalar(text("SELECT pg_try_advisory_lock(:key)"),
                                  {"key": LEDGER_LOCK}) is True
        await other.execute(text("SELECT pg_advisory_unlock(:key)"), {"key": LEDGER_LOCK})


async def test_unconfirmed_start_write_deletes_no_file(world, maintain_env, monkeypatch, capsys):
    world.point("fresh", world.ago(hours=1), None)
    operation = await world.image(world.ago(days=29, hours=12))
    write = LocalLedgerStore.write

    def dropping(self, key, value):
        if key != "start.json":
            write(self, key, value)

    monkeypatch.setattr(LocalLedgerStore, "write", dropping)
    assert await maintain(monkeypatch, capsys) == job_failure("LedgerUnavailableError")
    assert world.start() == 0 and len(world.files()) == 1
    assert await world.rows() == {operation}


async def test_file_deletion_failure_is_finished_by_the_next_run(world, maintain_env,
                                                                 monkeypatch, capsys):
    world.point("fresh", world.ago(hours=1), None)
    operation = await world.image(world.ago(days=29, hours=12))
    original = LocalLedgerStore.delete

    def refusing(self, key):
        raise PermissionError

    monkeypatch.setattr(LocalLedgerStore, "delete", refusing)
    assert await maintain(monkeypatch, capsys) == job_failure("PermissionError")
    assert world.start() == 1 and len(world.files()) == 1
    assert await world.rows() == {operation}
    monkeypatch.setattr(LocalLedgerStore, "delete", original)
    assert await maintain(monkeypatch, capsys) == (0, report(0, 0, 1))
    assert world.files() == [] and await world.rows() == set()


async def test_row_delete_failure_rolls_back_and_the_next_run_deletes(world, maintain_env,
                                                                      monkeypatch, capsys):
    world.point("fresh", world.ago(hours=1), None)
    user_id = world.uid()
    rows = {await world.row(str(uuid4()), user_id, world.ago(days=29, hours=12)) for _ in range(2)}
    async with world.engine.begin() as connection:
        await connection.execute(text(
            "CREATE FUNCTION refuse_disposal_test_delete() RETURNS trigger LANGUAGE plpgsql "
            "AS $$ BEGIN IF OLD.user_id = " + str(user_id) + " AND OLD.operation_id = '"
            + max(rows) + "' THEN RAISE EXCEPTION 'refused'; END IF; RETURN OLD; END $$"))
        await connection.execute(text(
            "CREATE TRIGGER refuse_disposal_test_delete BEFORE DELETE ON image_deletions "
            "FOR EACH ROW EXECUTE FUNCTION refuse_disposal_test_delete()"))
    try:
        code, output = await maintain(monkeypatch, capsys)
    finally:
        async with world.engine.begin() as connection:
            await connection.execute(text(
                "DROP TRIGGER refuse_disposal_test_delete ON image_deletions"))
            await connection.execute(text("DROP FUNCTION refuse_disposal_test_delete()"))
    assert (code, set(output)) == (1, {"passed", "error", "exception", "cause"})
    assert output["error"] == "backup_job_failed"
    assert await world.rows() == rows
    assert await maintain(monkeypatch, capsys) == (0, report(0, 0, 2))
    assert await world.rows() == set()


async def test_lost_commit_fails_and_the_next_run_does_not_recreate_rows(
    world, maintain_env, monkeypatch, capsys,
):
    world.point("fresh", world.ago(hours=1), None)
    operation = await world.image(world.ago(days=29, hours=12))
    commit = AsyncConnection.commit

    async def lost(self):
        await commit(self)
        raise ConnectionResetError

    with monkeypatch.context() as patch:
        patch.setattr(AsyncConnection, "commit", lost)
        assert await maintain(monkeypatch, capsys) == job_failure("ConnectionResetError")
    assert world.start() == 1 and operation not in await world.rows()
    assert await maintain(monkeypatch, capsys) == (0, report())
    assert operation not in await world.rows()


async def test_any_other_exception_stops_before_later_steps(world, maintain_env, monkeypatch,
                                                            capsys):
    world.point("fresh", world.ago(hours=1), "not a checkpoint")
    operation = await world.image(world.ago(days=29, hours=12))
    assert await maintain(monkeypatch, capsys) == job_failure("TypeError")
    assert world.start() == 0 and len(world.files()) == 1
    assert await world.rows() == {operation}


async def test_stale_points_limit_disposal_and_keep_passed_false(world, maintain_env,
                                                                 monkeypatch, capsys):
    await world.image(world.ago(days=29, hours=12))
    second = await world.image(world.ago(days=29, hours=12))
    world.point("stale", world.ago(days=2), world.checkpoint(1))
    assert await maintain(monkeypatch, capsys) == (1, report(1, 0, 1, passed=False, fresh=False))
    assert world.start() == 1 and await world.rows() == {second}


async def test_overdue_retention_limits_disposal_and_keeps_passed_false(world, maintain_env,
                                                                        monkeypatch, capsys):
    await world.image(world.ago(days=29, hours=12))
    second = await world.image(world.ago(days=29, hours=12))
    # This point still holds the deleted original past seven days: retention expires it now,
    # so its smaller checkpoint no longer limits disposal.
    namespace = world.ledger.read_verified_checkpoint()["namespace"]
    world.point("holding", world.ago(days=2),
                {"namespace": namespace, "sequence": 0, "digest": "0" * 64})
    manifest = json.loads(world.store.read("points/holding/manifest.json"))
    body = b"deleted original"
    key = "originals/sha256/" + hashlib.sha256(body).hexdigest()
    world.store.put_verified(key, body)
    manifest["assets"] = [{"id": 1, **ASSET, "content_id": 7, "backup_key": key,
                           "sha256": hashlib.sha256(body).hexdigest(), "size_bytes": len(body)}]
    manifest["sample"] = {"content_id": 7, "asset_id": 1, "saved_at": SAVED_AT,
                          "category_ids": [], "content_sha256": "d" * 64}
    world.store.put_verified("points/holding/manifest.json", json.dumps(manifest).encode())
    world.point("fresh", world.ago(hours=1), world.checkpoint(1))
    output = await maintain(monkeypatch, capsys)
    assert output == (1, {**report(1, 0, 1, passed=False, expired=1, retention_overdue=2),
                          "removed_originals": 1})
    assert world.start() == 1 and await world.rows() == {second}


# Other ledger paths after disposal.

async def test_retry_keeps_running_and_does_not_recreate_disposed_rows(world):
    from app.services.image_deletion_service import retry_image_deletions

    disposed = await world.image(world.ago(days=29, hours=12))
    remaining = await world.image(world.ago(days=1))
    assert await world.dispose() == result(1, 0, 1)
    async with AsyncSession(world.engine, expire_on_commit=False) as session:
        retried = await retry_image_deletions(session)
    assert retried["reconciled"] == 0
    assert await world.rows() == {remaining}
    assert disposed not in await world.rows()
