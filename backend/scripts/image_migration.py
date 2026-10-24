"""Inspect originals or resume a verified local-to-Bucket migration. Never removes local copies."""

import argparse
import asyncio
import hashlib
import json
import sys
from datetime import UTC, datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import select, text  # noqa: E402
from sqlalchemy.ext.asyncio import async_sessionmaker  # noqa: E402

from app.integrations.deletion_ledger import (  # noqa: E402
    IMAGE_CLEANUP_LOCK,
    LEDGER_WRITE_LOCK,
    get_deletion_ledger,
)
from app.models.content import Content  # noqa: E402
from app.models.content_asset import ContentAsset  # noqa: E402
from app.models.image_deletion import ImageDeletion  # noqa: E402
from app.repositories.content_repository import ContentRepository  # noqa: E402
from app.services.image_deletion_service import (  # noqa: E402
    deletion_identity,
    migration_operation_id,
)
from scripts.check_backup_restore import load_backup, require, sha256_file  # noqa: E402

MIGRATION_LOCK = 74264005


def verified_recovery_point(directory, report_file):
    manifest, _ = load_backup(directory)
    report = json.loads(report_file.read_text())
    require(manifest["format_version"] == 2, "migration_requires_v2_backup")
    require(
        all(
            report.get(field) is True
            for field in (
                "passed",
                "cleanup_passed",
                "authentication_passed",
                "image_bytes_passed",
                "live_deletion_ledger_verified",
                "deletions_applied",
            )
        )
        and report.get("backup_id") == manifest["backup_id"]
        and report.get("origin") == manifest["origin"]
        and report.get("manifest_sha256") == sha256_file(directory / "manifest.json"),
        "verified_restore_report_required",
    )
    return manifest


def same_bytes(asset, original):
    return (asset.size_bytes is None or asset.size_bytes == len(original)) and (
        asset.sha256 is None or asset.sha256 == hashlib.sha256(original).hexdigest()
    )


async def inspect_originals(session, storage):
    assets = list(await session.scalars(select(ContentAsset).order_by(ContentAsset.id)))
    results = []
    for asset in assets:
        status = "ready" if asset.storage_backend == "local" else "already_migrated"
        try:
            original = await storage.read_file(asset.storage_key, backend=asset.storage_backend)
            if not same_bytes(asset, original):
                status = "original_metadata_mismatch"
        except FileNotFoundError:
            status = "original_missing"
        except (OSError, ValueError):
            status = "original_unavailable"
        results.append({"asset_id": asset.id, "backend": asset.storage_backend, "status": status})
    return {
        "passed": all(item["status"] in {"ready", "already_migrated"} for item in results),
        "checked": len(results),
        "results": results,
    }


async def migrate_originals(
    engine,
    storage,
    *,
    backup_directory,
    restore_report_file,
    limit=None,
):
    """Commit each verified location flip; pending target jobs survive interruption."""
    manifest = await asyncio.to_thread(
        verified_recovery_point, backup_directory, restore_report_file
    )
    require(limit is None or limit > 0, "invalid_migration_limit")
    ledger = get_deletion_ledger(storage.config)
    await asyncio.to_thread(ledger.read_verified_checkpoint)
    sessions = async_sessionmaker(engine, expire_on_commit=False)
    async with engine.connect() as locks:
        acquired = await locks.scalar(
            text("SELECT pg_try_advisory_lock(:key)"),
            {"key": MIGRATION_LOCK},
        )
        await locks.commit()
        require(acquired, "migration_already_running")
        try:
            async with sessions() as session:
                report = await inspect_originals(session, storage)
            migrated = 0
            attempted = 0
            for item in report["results"]:
                if item["status"] != "ready" or (limit is not None and attempted >= limit):
                    continue
                attempted += 1
                try:
                    status = await migrate_original(
                        sessions,
                        locks,
                        storage,
                        ledger,
                        item["asset_id"],
                        manifest,
                    )
                except Exception:
                    # Never blindly remove an object after a lost DB acknowledgement. The
                    # pending durable target job checks live references before physical cleanup.
                    status = "migration_unavailable"
                item["status"] = status
                migrated += status == "migrated"
            report["migrated"] = migrated
            report["passed"] = all(
                item["status"]
                in {
                    "ready",
                    "already_migrated",
                    "migrated",
                    "content_deleted",
                }
                for item in report["results"]
            )
            return report
        finally:
            await locks.rollback()
            await locks.execute(text("SELECT pg_advisory_unlock(:key)"), {"key": MIGRATION_LOCK})
            await locks.commit()


async def migrate_original(sessions, locks, storage, ledger, asset_id, manifest):
    # Hold shared physical protection only during staging/copy. Before the DB flip,
    # release it and acquire ledger -> exclusive physical -> content in that order.
    await locks.execute(
        text("SELECT pg_advisory_lock_shared(:key)"),
        {"key": IMAGE_CLEANUP_LOCK},
    )
    await locks.commit()
    try:
        async with sessions() as session:
            asset = await session.get(ContentAsset, asset_id)
            if asset is None:
                return "content_deleted"
            content = await ContentRepository(session).get_owned(
                user_id=await session.scalar(
                    select(Content.user_id).where(
                        Content.id == asset.content_id,
                    )
                ),
                content_id=asset.content_id,
            )
            if content is None:
                return "content_deleted"
            if asset.storage_backend != "local":
                return "already_migrated"
            identity = deletion_identity(content)
            original = await storage.read_file(asset.storage_key, backend="local")
            if not same_bytes(asset, original):
                return "original_metadata_mismatch"
            size, digest = len(original), hashlib.sha256(original).hexdigest()
            covered = any(
                entry["id"] == asset.id
                and entry["content_id"] == asset.content_id
                and entry["storage_key"] == asset.storage_key
                and entry["size_bytes"] == size
                and entry["sha256"] == digest
                for entry in manifest["assets"]
            )
            if not covered:
                return "original_not_in_verified_backup"
            target = storage.for_backend("s3")
            try:
                existing = await target.read_file(asset.storage_key)
            except FileNotFoundError:
                existing = None
            if existing is not None and existing != original:
                return "target_original_conflict"
            operation_id = migration_operation_id(asset.storage_key)
            job = await session.get(ImageDeletion, operation_id)
            if job is not None and job.intent.get("source_identity") != identity:
                return "migration_identity_changed"
            if job is None:
                job = ImageDeletion(
                    operation_id=operation_id,
                    user_id=content.user_id,
                    content_id=0,
                    deleted_at=datetime.now(UTC),
                    intent={
                        "source_identity": identity,
                        "assets": [
                            {
                                "storage_backend": "s3",
                                "storage_key": asset.storage_key,
                                "sha256": digest,
                                "size_bytes": size,
                            }
                        ],
                    },
                )
                session.add(job)
            job.completed = False
            job.last_error = None
            key, content_id, user_id = asset.storage_key, content.id, content.user_id
            await session.commit()
            if existing is None:
                await target.save_file(key, original)
            if await target.read_file(key) != original:
                return "target_verification_failed"
    finally:
        await locks.rollback()
        await locks.execute(
            text("SELECT pg_advisory_unlock_shared(:key)"),
            {"key": IMAGE_CLEANUP_LOCK},
        )
        await locks.commit()
    async with sessions() as session:
        await session.execute(
            text("SELECT pg_advisory_xact_lock(:key)"),
            {"key": LEDGER_WRITE_LOCK},
        )
        acquired = await session.scalar(
            text("SELECT pg_try_advisory_xact_lock(:key)"),
            {"key": IMAGE_CLEANUP_LOCK},
        )
        if not acquired:
            return "backup_or_cleanup_busy"
        content = await ContentRepository(session).get_owned(
            user_id=user_id,
            content_id=content_id,
            for_update=True,
        )
        if content is None:
            return "content_deleted"
        if deletion_identity(content) != identity:
            return "migration_identity_changed"
        events = await asyncio.to_thread(ledger.read_verified_events)
        if any(
            all(
                event[field] == identity[field]
                for field in (
                    "user_id",
                    "content_id",
                    "saved_at",
                    "assets",
                )
            )
            for event in events
        ):
            return "content_deleted"
        # Cleanup may have run in the intentional gap between copy and the final
        # ordered lock acquisition; re-read the target before publishing its location.
        if await storage.read_file(key, backend="s3") != original:
            return "target_verification_failed"
        asset = next(item for item in content.assets if item.id == asset_id)
        asset.storage_backend, asset.size_bytes, asset.sha256 = "s3", size, digest
        job = await session.get(ImageDeletion, operation_id)
        job.completed = True
        await session.commit()
        return "migrated"


async def run(args):
    from app.db.session import AsyncSessionLocal, engine
    from app.integrations.storage_client import get_storage_client

    try:
        storage = get_storage_client()
        if args.command == "inspect":
            async with AsyncSessionLocal() as session:
                return await inspect_originals(session, storage)
        return await migrate_originals(
            engine,
            storage,
            backup_directory=args.backup_directory,
            restore_report_file=args.restore_report_file,
            limit=args.limit,
        )
    finally:
        await engine.dispose()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("inspect", help="Read-only DB/original integrity report")
    apply = commands.add_parser("apply", help="Resume independently verified asset location flips")
    apply.add_argument("--backup-directory", type=Path, required=True)
    apply.add_argument("--restore-report-file", type=Path, required=True)
    apply.add_argument("--limit", type=int)
    args = parser.parse_args()
    try:
        report = asyncio.run(run(args))
    except Exception:
        report = {"passed": False, "error": "migration_precondition_or_storage_unavailable"}
    print(json.dumps(report, sort_keys=True))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
