"""Separate backup creation, retention and deletion-aware restore commands."""

import asyncio
import json
import os
from contextlib import asynccontextmanager
from datetime import UTC, datetime, timedelta
from pathlib import Path

from pydantic import ValidationError
from sqlalchemy import cast, delete, select, text
from sqlalchemy.dialects.postgresql import JSONB

from scripts.check_backup_restore import CheckError, RestoreDrill, check, require
from scripts.image_backup import BackupBucket, create_backup
from scripts.recovery_point import (
    ORIGINALS_PREFIX,
    POINTS_PREFIX,
    canonical_json,
    check_point_manifest,
    completed_points,
    load_backup,
    point_id,
    point_manifest_key,
    point_prefix,
    read_point_json,
    read_retiring_points,
    receipt_key,
    require_app_commit,
    require_backup_id,
)

BACKUP_JOB_LOCK = 74264003
# Hourly maintenance removes a point before it reaches the seven-day limit.
POINT_RETENTION = timedelta(days=7) - timedelta(hours=1)
# Reporting a missed deletion keeps the contractual seven-day limit.
DELETION_DEADLINE = timedelta(days=7)
# Hourly maintenance gets a full day to retry before the contractual seven-day limit.
DELETED_COPY_RETENTION = timedelta(days=6)
# Ledger records leave 29 days after deletion; one still kept past 30 days fails the run (ADR 0013).
DISPOSAL_AGE = timedelta(days=29)
DISPOSAL_DEADLINE = timedelta(days=30)


def latest_deletions(ledger, checkpoint):
    """Caller holds the source ledger shared lock; an offline export is never freshness."""
    require(isinstance(checkpoint, dict), "deletion_checkpoint_required")
    current = ledger.read_verified_checkpoint()
    require(current["namespace"] == checkpoint.get("namespace"), "deletion_namespace_mismatch")
    require(current["sequence"] >= checkpoint.get("sequence", -1), "deletion_ledger_regressed")
    ledger.read_verified_events(checkpoint)
    return current, ledger.read_verified_events(current)


def aware(value):
    result = datetime.fromisoformat(value)
    require(result.utcoffset() is not None, "invalid_manifest")
    return result.astimezone(UTC)


def asset_matches(asset, deleted):
    return (
        asset["storage_key"] == deleted["storage_key"]
        and (deleted["sha256"] is None or asset["sha256"] == deleted["sha256"])
    )


def maintain_backups(store, ledger, *, now=None):
    """Caller serializes backup/GC operators. Ledger disposal follows in run_job (ADR 0013)."""
    from app.integrations.deletion_ledger import deleted_contents

    now = now or datetime.now(UTC)
    events = ledger.read_verified_events()
    points = []
    overdue = set()
    inventory = {
        identifier: read_point_json(store, identifier) for identifier in completed_points(store)
    }
    retiring = {}
    for identifier, key, manifest in read_retiring_points(store):
        require(identifier not in inventory
                or canonical_json(inventory[identifier]) == canonical_json(manifest),
                "gc_receipt_conflict")
        inventory[identifier] = manifest
        retiring[identifier] = key
    # Validate the entire inventory before making a destructive change.
    for identifier, manifest in inventory.items():
        require(isinstance(manifest, dict), "invalid_manifest")
        # The format version is reported before the contract: it names the cause directly.
        require(manifest.get("format_version") == 2, "retention_requires_v2")
        check_point_manifest(manifest, identifier)
        captured = aware(manifest["captured_at"])
        require(captured <= now, "invalid_manifest")
        expire = identifier in retiring or now - captured >= POINT_RETENTION
        for event in events:
            if now - aware(event["deleted_at"]) >= DELETED_COPY_RETENTION and any(
                asset_matches(asset, deleted)
                for asset in manifest["assets"]
                for content in deleted_contents(event)
                for deleted in content["assets"]
            ):
                expire = True
                if now - aware(event["deleted_at"]) >= DELETION_DEADLINE:
                    overdue.add(event["operation_id"])
        points.append((identifier, manifest, captured, expire))
    retained = [p for p in points if not p[3]]
    # A surviving completion marker alone is not a healthy point. Check existence/size
    # without repeatedly downloading all seven DB dumps; publish/materialize verify SHA.
    checked = set()
    for identifier, manifest, _, _ in retained:
        database = manifest["database"]
        store.verify_present(database["backup_key"], database["size_bytes"])
        for asset in manifest["assets"]:
            if asset["backup_key"] not in checked:
                store.verify_present(asset["backup_key"], asset["size_bytes"])
                checked.add(asset["backup_key"])
    for identifier, manifest, _, expire in points:
        if expire:
            # Keep immutable identity across a crash after unpublishing the point. Legacy
            # deletion intents may lack SHA, so a digest alone cannot recover this link.
            if identifier not in retiring:
                store.put_verified(receipt_key(identifier), canonical_json(manifest))
            # Unpublish the point before deleting anything it references.
            store.delete_verified(point_manifest_key(identifier))
            for item in store.list_objects(point_prefix(identifier)):
                store.delete_verified(item["key"])
    referenced = {asset["backup_key"] for _, m, _, _ in retained for asset in m["assets"]}
    removed = 0
    for item in store.list_objects(ORIGINALS_PREFIX):
        if item["key"] not in referenced:
            store.delete_verified(item["key"])
            removed += 1
    completed = {p[0] for p in retained}
    partial = [item for item in store.list_objects(POINTS_PREFIX, include_dates=True)
               if point_id(item["key"]) not in completed]
    for item in partial:
        if now - aware(item["last_modified"]) >= timedelta(days=1):
            store.delete_verified(item["key"])
    for identifier, _, _, expire in points:
        if expire:
            store.delete_verified(receipt_key(identifier))
    fresh = any(now - captured <= timedelta(days=1) for _, _, captured, _ in retained)
    return {
        "passed": fresh and not overdue, "freshness_met": fresh,
        "retention_overdue": len(overdue),
        "expired_points": sum(p[3] for p in points), "removed_originals": removed,
        "retained_points": len(retained),
    }


def surviving_checkpoint(store):
    """Smallest ledger checkpoint among the points left after retention (Q-B1), or None."""
    manifests = [read_point_json(store, identifier) for identifier in completed_points(store)]
    return min((manifest["deletion_checkpoint"]["sequence"] for manifest in manifests
                if manifest.get("deletion_checkpoint") is not None), default=None)


def made_by(event, rows):
    """Cleanup rows an account deletion record made: the same account and the record's IDs."""
    from app.integrations.deletion_ledger import account_content_operation_id

    return [row for row in rows if row.user_id == event["user_id"] and row.operation_id
            == account_content_operation_id(event["operation_id"], row.content_id,
                                            row.intent["saved_at"])]


async def account_rows(connection, events):
    """Cleanup rows of the accounts in these account deletion records."""
    from app.models.image_deletion import ImageDeletion

    return (await connection.execute(
        select(ImageDeletion.operation_id, ImageDeletion.user_id, ImageDeletion.content_id,
               ImageDeletion.intent, ImageDeletion.completed)
        .where(ImageDeletion.user_id.in_({event["user_id"] for event in events}),
               ImageDeletion.content_id > 0)
    )).all()


async def reflected_prefix(connection, events):
    """How many leading records the DB has fully applied, rule (b)."""
    from app.integrations.deletion_ledger import ACCOUNT_DELETION
    from app.models.image_deletion import ImageDeletion
    from app.models.user import User

    accounts = [event for event in events if event.get("kind") == ACCOUNT_DELETION]
    completed = dict((await connection.execute(
        select(ImageDeletion.operation_id, ImageDeletion.completed)
        .where(ImageDeletion.operation_id.in_([event["operation_id"] for event in events]))
    )).all())
    users = dict((await connection.execute(
        select(User.id, User.created_at).where(User.id.in_({e["user_id"] for e in accounts}))
    )).all())
    rows = await account_rows(connection, accounts)
    count = 0
    for event in events:
        if event.get("kind") == ACCOUNT_DELETION:
            # Only the same number and creation time are the deleted account (ADR 0008).
            applied = users.get(event["user_id"]) != aware(event["user_created_at"]) and all(
                row.completed for row in made_by(event, rows))
        else:
            # No row yet means the retry has not applied the record.
            applied = completed.get(event["operation_id"]) is True
        if not applied:
            break
        count += 1
    return count


async def prune_cleanup_rows(ledger, engine, *, now):
    """Delete completed cleanup rows 29 days past deletion that no remaining record binds (Q-B3).

    The remainder is read after the files are gone and every condition is in the DELETE, so a
    row bound or reopened after the decision stays. Migration rows are kept: a later user
    deletion needs their source identity to remove the retained Volume original.
    """
    from app.integrations.deletion_ledger import ACCOUNT_DELETION
    from app.models.image_deletion import ImageDeletion

    events = await asyncio.to_thread(ledger.read_verified_events)
    accounts = [event for event in events if event.get("kind") == ACCOUNT_DELETION]
    async with engine.connect() as connection:
        rows = await account_rows(connection, accounts)
        bound = {event["operation_id"] for event in events} | {
            row.operation_id for event in accounts for row in made_by(event, rows)}
        result = await connection.execute(delete(ImageDeletion).where(
            ImageDeletion.completed.is_(True),
            ImageDeletion.deleted_at <= now - DISPOSAL_AGE,
            ImageDeletion.operation_id.not_in(bound),
            ~cast(ImageDeletion.intent, JSONB).has_key("source_identity"),
        ))
        await connection.commit()
    return result.rowcount


async def dispose_deletion_records(store, ledger, engine, *, now):
    """Dispose records retention left unneeded, after it finished without an exception.

    The ledger write lock covers only reading the remainder and the DB conditions and writing
    the start point; record files and cleanup rows go after it, under the caller's job lock.
    """
    from app.integrations.deletion_ledger import LEDGER_WRITE_LOCK

    limit = await asyncio.to_thread(surviving_checkpoint, store)
    async with source_lock(LEDGER_WRITE_LOCK, engine=engine) as connection:
        start, events = await asyncio.to_thread(ledger.read_verified_remainder)
        # Rules (a) and (c) need no DB, so (b) is read only for the records passing both.
        candidates = []
        for sequence, event in enumerate(events, start + 1):
            if now - aware(event["deleted_at"]) < DISPOSAL_AGE or (
                limit is not None and sequence > limit
            ):
                break
            candidates.append(event)
        # A rollback keeps the session lock; one read-only transaction reads the conditions.
        await connection.rollback()
        await connection.execute(text("SET TRANSACTION READ ONLY"))
        pruned = await reflected_prefix(connection, candidates)
        await connection.rollback()
        if pruned:
            await asyncio.to_thread(ledger.advance_start, start + pruned)
    overdue = sum(now - aware(event["deleted_at"]) > DISPOSAL_DEADLINE
                  for event in events[pruned:])
    await asyncio.to_thread(ledger.delete_disposed)
    rows = await prune_cleanup_rows(ledger, engine, now=now)
    return {"deletion_records_pruned": pruned, "deletion_records_overdue": overdue,
            "image_deletion_rows_pruned": rows}


@asynccontextmanager
async def source_lock(key, *, shared=False, try_only=False, engine=None):
    """Pin the exact PostgreSQL session until its advisory lock is released."""
    if engine is None:
        from app.db.session import engine

    suffix = "_shared" if shared else ""
    function = "pg_try_advisory_lock" if try_only else "pg_advisory_lock"
    async with engine.connect() as connection:
        acquired = False
        try:
            result = await connection.scalar(text(f"SELECT {function}{suffix}(:key)"), {"key": key})
            acquired = result is True if try_only else True
            require(acquired, "backup_job_already_running")
            yield connection
        finally:
            try:
                await connection.rollback()
                if acquired:
                    await connection.execute(text(f"SELECT pg_advisory_unlock{suffix}(:key)"),
                                             {"key": key})
            except BaseException:
                await connection.invalidate()
                raise


async def run_job(store, *, command, app_commit=None, origin=None, sample=None,
                  pg_dump="pg_dump", backup_id=None):
    """Backup-only commands never perform source cleanup or retention."""
    from app.integrations.deletion_ledger import get_deletion_ledger
    from scripts.operator_runtime import MaintenanceRuntime, OperatorRuntime

    try:
        runtime = MaintenanceRuntime() if command == "maintain" else OperatorRuntime()
    except ValidationError as exc:
        raise CheckError("operator_configuration_invalid") from exc
    try:
        ledger = get_deletion_ledger(runtime.config, operator_reads=True)
        from app.services.maintenance import MaintenanceGate
        async with MaintenanceGate(runtime.sessions).operation("backup_" + command), \
                source_lock(BACKUP_JOB_LOCK, try_only=True, engine=runtime.engine):
            if command == "maintain":
                now = datetime.now(UTC)
                report = await asyncio.to_thread(maintain_backups, store, ledger, now=now)
                disposal = await dispose_deletion_records(store, ledger, runtime.engine, now=now)
                return {**report, **disposal, "passed": report["passed"]
                        and disposal["deletion_records_overdue"] == 0}
            identifier = backup_id or "daily-" + datetime.now(UTC).date().isoformat()
            if command == "daily" and identifier in completed_points(store):
                return {"passed": True, "backup_id": identifier, "backup_created": False,
                        "restore_verified": False}
            manifest = await create_backup(
                store, backup_id=identifier, sample=sample, app_commit=app_commit,
                origin=origin, writers_frozen=False, pg_dump=pg_dump, ledger=ledger,
                _job_locked=True, runtime=runtime,
            )
            return {"passed": True, "backup_id": identifier, "backup_created": True,
                    "asset_count": len(manifest["assets"]), "restore_verified": False}
    finally:
        await runtime.close()


async def check_latest_restore(directory, credentials_file, image, *, writers_frozen,
                               synthetic_offline=False):
    """No traffic is opened. Keep the operator's writer freeze through any later cutover."""
    from app.integrations.deletion_ledger import LEDGER_WRITE_LOCK, get_deletion_ledger

    require(synthetic_offline is True, "authoritative_restore_required")
    require(writers_frozen is True, "source_write_freeze_required")
    manifest, _ = load_backup(directory)
    require(manifest["origin"] == "synthetic", "synthetic_backup_required")
    async with source_lock(LEDGER_WRITE_LOCK, shared=True):
        _, events = await asyncio.to_thread(
            latest_deletions, get_deletion_ledger(), manifest.get("deletion_checkpoint"),
        )
        report = await asyncio.to_thread(
            check, directory, credentials_file, image, RestoreDrill(deletion_events=events),
        )
        report["live_deletion_ledger_verified"] = report["passed"]
        report["maintenance_verified"] = False
        report["synthetic_only"] = True
        return report


def main():
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    for command in ("manual", "daily", "maintain"):
        task = sub.add_parser(command)
        task.add_argument("--backup-config-file", type=Path,
                          help="Private JSON file; otherwise BACKUP_BUCKET_CONFIG_JSON is consumed")
        if command in {"manual", "daily"}:
            task.add_argument("--app-commit", default=os.environ.get("IMAGE_BACKUP_APP_COMMIT"))
            task.add_argument("--origin", choices=["production", "synthetic"], default="production")
            task.add_argument("--sample-file", type=Path)
            task.add_argument("--pg-dump", default="pg_dump")
        if command == "manual":
            task.add_argument("--backup-id", default=os.environ.get("IMAGE_BACKUP_ID"))
    restore = sub.add_parser("restore-check")
    restore.add_argument("--workspace", type=Path)
    restore.add_argument("--backup-dir", type=Path)
    restore.add_argument("--credentials-file", type=Path)
    restore.add_argument("--image")
    restore.add_argument("--synthetic-offline", action="store_true")
    restore.add_argument("--writers-frozen", action="store_true")
    args = parser.parse_args()
    try:
        if args.command == "restore-check":
            if args.workspace:
                from scripts.restore_execution import run_restore
                report = asyncio.run(run_restore(args.workspace))
            else:
                report = asyncio.run(check_latest_restore(
                    args.backup_dir, args.credentials_file, args.image,
                    writers_frozen=args.writers_frozen, synthetic_offline=args.synthetic_offline,
                ))
        else:
            if args.command in {"manual", "daily"}:
                require_app_commit(args.app_commit or "", "app_commit_required")
            if args.command == "manual":
                require_backup_id(args.backup_id or "", "backup_id_required")
            store = (BackupBucket.from_config_file(args.backup_config_file)
                     if args.backup_config_file else BackupBucket.from_environment())
            kwargs = {}
            if args.command in {"manual", "daily"}:
                kwargs = dict(app_commit=args.app_commit, origin=args.origin, pg_dump=args.pg_dump,
                              sample=json.loads(args.sample_file.read_text())
                              if args.sample_file else None)
            if args.command == "manual":
                kwargs["backup_id"] = args.backup_id
            report = asyncio.run(run_job(store, command=args.command, **kwargs))
        print(json.dumps(report, sort_keys=True))
        return 0 if report["passed"] else 1
    except CheckError as exc:
        print(json.dumps({"passed": False, "error": str(exc)}, sort_keys=True))
        return 1
    except Exception as exc:
        # Class names only: messages may carry endpoints, bucket names or keys.
        cause = type(exc.__cause__).__name__ if exc.__cause__ is not None else None
        print(json.dumps({"passed": False, "error": "backup_job_failed",
                          "exception": type(exc).__name__, "cause": cause}, sort_keys=True))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
