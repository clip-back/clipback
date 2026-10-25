"""Separate backup creation, retention and deletion-aware restore commands."""

import asyncio
import json
import re
from contextlib import asynccontextmanager
from datetime import UTC, datetime, timedelta
from pathlib import Path

from pydantic import ValidationError
from sqlalchemy import text

from scripts.check_backup_restore import CheckError, RestoreDrill, check, load_backup, require
from scripts.image_backup import BackupBucket, canonical_json, create_backup

BACKUP_JOB_LOCK = 74264003
POINT_RETENTION = timedelta(days=7)
# Hourly maintenance gets a full day to retry before the contractual seven-day limit.
DELETED_COPY_RETENTION = timedelta(days=6)


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
    """Caller serializes backup/GC operators. No ledger records are ever pruned."""
    now = now or datetime.now(UTC)
    events = ledger.read_verified_events()
    points = []
    overdue = set()
    inventory = {
        identifier: store.read_manifest(identifier) for identifier in store.completed_points()
    }
    retiring = {}
    for item in store.list_objects("gc/points/"):
        match = re.fullmatch(r"gc/points/([A-Za-z0-9._-]{1,100})\.json", item["key"])
        require(match is not None, "invalid_gc_receipt")
        identifier = match[1]
        manifest = json.loads(store.read(item["key"]))
        require(identifier not in inventory
                or canonical_json(inventory[identifier]) == canonical_json(manifest),
                "gc_receipt_conflict")
        inventory[identifier] = manifest
        retiring[identifier] = item["key"]
    # Validate the entire inventory before making a destructive change.
    for identifier, manifest in inventory.items():
        require(manifest.get("format_version") == 2, "retention_requires_v2")
        captured = aware(manifest["captured_at"])
        require(captured <= now and manifest["backup_id"] == identifier, "invalid_manifest")
        require(isinstance(manifest["assets"], list), "invalid_manifest")
        for asset in manifest["assets"]:
            require(asset.get("storage_backend") in {"local", "s3"}
                    and isinstance(asset.get("storage_key"), str)
                    and bool(re.fullmatch(r"[0-9a-f]{64}", asset.get("sha256", "")))
                    and asset.get("backup_key") == "originals/sha256/" + asset["sha256"],
                    "invalid_manifest")
        expire = identifier in retiring or now - captured >= POINT_RETENTION
        for event in events:
            if now - aware(event["deleted_at"]) >= DELETED_COPY_RETENTION and any(
                asset_matches(asset, deleted)
                for asset in manifest["assets"]
                for deleted in event["assets"]
            ):
                expire = True
                if now - aware(event["deleted_at"]) >= POINT_RETENTION:
                    overdue.add(event["operation_id"])
        points.append((identifier, manifest, captured, expire))
    retained = [p for p in points if not p[3]]
    # A surviving completion marker alone is not a healthy point. Check existence/size
    # without repeatedly downloading all seven DB dumps; publish/materialize verify SHA.
    checked = set()
    for identifier, manifest, _, _ in retained:
        database = manifest["database"]
        require(database["backup_key"] == f"points/{identifier}/database.dump", "invalid_manifest")
        store.verify_present(database["backup_key"], database["size_bytes"])
        for asset in manifest["assets"]:
            if asset["backup_key"] not in checked:
                store.verify_present(asset["backup_key"], asset["size_bytes"])
                checked.add(asset["backup_key"])
    for identifier, manifest, _, expire in points:
        if expire:
            # Keep immutable identity across a crash after unpublishing the point. Legacy
            # deletion intents may lack SHA, so a digest alone cannot recover this link.
            receipt_key = f"gc/points/{identifier}.json"
            if identifier not in retiring:
                store.put_verified(receipt_key, canonical_json(manifest))
            # Unpublish the point before deleting anything it references.
            store.delete_verified(f"points/{identifier}/manifest.json")
            for item in store.list_objects(f"points/{identifier}/"):
                store.delete_verified(item["key"])
    referenced = {asset["backup_key"] for _, m, _, _ in retained for asset in m["assets"]}
    removed = 0
    for item in store.list_objects("originals/"):
        if item["key"] not in referenced:
            store.delete_verified(item["key"])
            removed += 1
    completed = {p[0] for p in retained}
    partial = [item for item in store.list_objects("points/", include_dates=True)
               if item["key"].split("/")[1] not in completed]
    for item in partial:
        if now - aware(item["last_modified"]) >= timedelta(days=1):
            store.delete_verified(item["key"])
    for identifier, _, _, expire in points:
        if expire:
            store.delete_verified(f"gc/points/{identifier}.json")
    fresh = any(now - captured <= timedelta(days=1) for _, _, captured, _ in retained)
    return {
        "passed": fresh and not overdue, "freshness_met": fresh,
        "retention_overdue": len(overdue),
        "expired_points": sum(p[3] for p in points), "removed_originals": removed,
        "retained_points": len(retained), "deletion_records_pruned": 0,
    }


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
            yield
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
    from scripts.operator_runtime import OperatorRuntime

    try:
        runtime = OperatorRuntime()
    except ValidationError as exc:
        raise CheckError("operator_configuration_invalid") from exc
    try:
        ledger = get_deletion_ledger(runtime.config)
        async with source_lock(BACKUP_JOB_LOCK, try_only=True, engine=runtime.engine):
            if command == "maintain":
                return await asyncio.to_thread(maintain_backups, store, ledger)
            identifier = backup_id or "daily-" + datetime.now(UTC).date().isoformat()
            if command == "daily" and identifier in store.completed_points():
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


async def check_latest_restore(directory, credentials_file, image, *, writers_frozen):
    """No traffic is opened. Keep the operator's writer freeze through any later cutover."""
    from app.integrations.deletion_ledger import LEDGER_WRITE_LOCK, get_deletion_ledger

    require(writers_frozen is True, "source_write_freeze_required")
    manifest, _ = load_backup(directory)
    async with source_lock(LEDGER_WRITE_LOCK, shared=True):
        _, events = await asyncio.to_thread(
            latest_deletions, get_deletion_ledger(), manifest.get("deletion_checkpoint"),
        )
        report = await asyncio.to_thread(
            check, directory, credentials_file, image, RestoreDrill(deletion_events=events),
        )
        report["live_deletion_ledger_verified"] = report["passed"]
        return report


def main():
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    for command in ("manual", "daily", "maintain"):
        task = sub.add_parser(command)
        task.add_argument("--backup-config-file", type=Path, required=True)
        if command in {"manual", "daily"}:
            task.add_argument("--app-commit", required=True)
            task.add_argument("--origin", choices=["production", "synthetic"], required=True)
            task.add_argument("--sample-file", type=Path)
            task.add_argument("--pg-dump", default="pg_dump")
        if command == "manual":
            task.add_argument("--backup-id", required=True)
    restore = sub.add_parser("restore-check")
    restore.add_argument("--backup-dir", type=Path, required=True)
    restore.add_argument("--credentials-file", type=Path, required=True)
    restore.add_argument("--image", required=True)
    restore.add_argument("--writers-frozen", action="store_true")
    args = parser.parse_args()
    try:
        if args.command == "restore-check":
            report = asyncio.run(check_latest_restore(
                args.backup_dir, args.credentials_file, args.image,
                writers_frozen=args.writers_frozen,
            ))
        else:
            store = BackupBucket.from_config_file(args.backup_config_file)
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
    except Exception as exc:
        code = str(exc) if isinstance(exc, CheckError) else "backup_job_failed"
        print(json.dumps({"passed": False, "error": code}, sort_keys=True))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
