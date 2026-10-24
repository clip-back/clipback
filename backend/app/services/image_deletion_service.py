import asyncio
import logging
from datetime import UTC, datetime
from uuid import NAMESPACE_URL, uuid5

from fastapi import HTTPException
from sqlalchemy import func, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, settings
from app.core.exceptions import NotFoundError
from app.integrations.deletion_ledger import (
    IMAGE_CLEANUP_LOCK,
    LEDGER_WRITE_LOCK,
    LedgerUnavailableError,
    canonical_json,
    get_deletion_ledger,
)
from app.integrations.storage_client import StorageRouter
from app.models.content_asset import ContentAsset
from app.models.image_deletion import ImageDeletion
from app.repositories.content_repository import ContentRepository

logger = logging.getLogger(__name__)


def deletion_identity(content) -> dict:
    return {
        "user_id": content.user_id,
        "content_id": content.id,
        "saved_at": content.saved_at.isoformat(),
        "assets": [
            {
                "storage_backend": asset.storage_backend,
                "storage_key": asset.storage_key,
                "sha256": asset.sha256,
                "size_bytes": asset.size_bytes,
            }
            for asset in sorted(content.assets, key=lambda item: item.id)
        ],
    }


def deletion_job(intent: dict) -> ImageDeletion:
    return ImageDeletion(
        operation_id=intent["operation_id"],
        user_id=intent["user_id"],
        content_id=intent["content_id"],
        intent=intent,
        deleted_at=datetime.fromisoformat(intent["deleted_at"]),
    )


def migration_operation_id(storage_key: str) -> str:
    return str(uuid5(NAMESPACE_URL, f"migration-target:s3:{storage_key}"))


async def migrated_local_alias(session: AsyncSession, job: ImageDeletion, asset: dict) -> bool:
    # Only an actual user deletion retires a deliberately retained migration source.
    # A failed target upload/flip must keep the local original available.
    if job.content_id == 0 or asset["storage_backend"] != "s3":
        return False
    migration = await session.get(ImageDeletion, migration_operation_id(asset["storage_key"]))
    source = migration.intent.get("source_identity") if migration is not None else None
    if not source or any(source[field] != job.intent[field] for field in ("user_id", "content_id")):
        return False
    if datetime.fromisoformat(source["saved_at"]) != datetime.fromisoformat(job.intent["saved_at"]):
        return False
    return any(
        item["storage_key"] == asset["storage_key"]
        and all(item.get(field) is None or asset.get(field) is None
                or item[field] == asset[field] for field in ("sha256", "size_bytes"))
        for item in source["assets"]
    )


def matches_deletion_identity(content, intent: dict) -> bool:
    """Location changes and filling legacy metadata do not make a new original."""
    current = deletion_identity(content)
    if any(current[key] != intent[key] for key in ("user_id", "content_id")):
        return False
    if datetime.fromisoformat(current["saved_at"]) != datetime.fromisoformat(intent["saved_at"]):
        return False
    current_assets = {asset["storage_key"]: asset for asset in current["assets"]}
    intended_assets = {asset["storage_key"]: asset for asset in intent["assets"]}
    if current_assets.keys() != intended_assets.keys():
        return False
    return all(
        current_assets[key][field] is None
        or intended_assets[key][field] is None
        or current_assets[key][field] == intended_assets[key][field]
        for key in current_assets
        for field in ("sha256", "size_bytes")
    )


async def apply_deletion_intent(repository: ContentRepository, content, intent: dict) -> bool:
    """Apply an already verified intent; the caller owns locking and transaction policy."""
    cleanup_intent = intent
    if content is not None:
        if not matches_deletion_identity(content, intent):
            # Restored numeric IDs may belong to a different immutable original.
            return False
        cleanup_intent = {**intent, "assets": deletion_identity(content)["assets"]}
        await repository.delete(content)
    if await repository.session.get(ImageDeletion, intent["operation_id"]) is None:
        repository.session.add(deletion_job(cleanup_intent))
    return True


async def record_image_deletion(session: AsyncSession, content) -> str:
    """The ledger commits first. A DB failure afterwards leaves a replayable deletion intent."""
    identity = deletion_identity(content)
    intent = {
        **identity,
        "operation_id": str(uuid5(NAMESPACE_URL, canonical_json(identity).decode())),
        "deleted_at": datetime.now(UTC).isoformat(),
    }
    await session.execute(text("SELECT pg_advisory_xact_lock(:key)"), {"key": LEDGER_WRITE_LOCK})
    ledger = get_deletion_ledger()
    await asyncio.to_thread(ledger.append, intent)
    # Use the original durable timestamp on a retry, rather than extending backup retention.
    intent = await asyncio.to_thread(ledger.read_operation, intent["operation_id"])
    if await session.get(ImageDeletion, intent["operation_id"]) is None:
        session.add(deletion_job(intent))
    return intent["operation_id"]


async def delete_image_content(
    repository: ContentRepository,
    storage: StorageRouter,
    *,
    user_id: int,
    content_id: int,
) -> None:
    session = repository.session
    try:
        # Match reconciliation: take the ledger lock before locking the content.
        await session.execute(
            text("SELECT pg_advisory_xact_lock(:key)"), {"key": LEDGER_WRITE_LOCK}
        )
        content = await repository.get_owned(
            user_id=user_id,
            content_id=content_id,
            for_update=True,
        )
        if content is None:
            raise NotFoundError("Content not found")
        operation_id = await record_image_deletion(session, content)
        await repository.delete(content)
        await session.commit()
    except LedgerUnavailableError as exc:
        await session.rollback()
        raise HTTPException(
            status_code=503,
            detail="Image deletion is temporarily unavailable",
        ) from exc
    except Exception:
        await session.rollback()
        raise
    try:
        await cleanup_image_deletion(session, operation_id, storage)
    except Exception:
        await session.rollback()
        logger.warning("Image cleanup deferred: operation_id=%s", operation_id)


async def cleanup_image_deletion(
    session: AsyncSession,
    operation_id: str,
    storage: StorageRouter,
) -> None:
    # Backup holds the shared session form of this lock until its snapshot bytes are copied.
    acquired = await session.scalar(
        text("SELECT pg_try_advisory_xact_lock(:key)"),
        {"key": IMAGE_CLEANUP_LOCK},
    )
    if not acquired:
        await session.commit()
        return
    job = await session.scalar(
        select(ImageDeletion).where(ImageDeletion.operation_id == operation_id).with_for_update()
    )
    if job is None or job.completed:
        await session.commit()
        return
    job.attempts += 1
    try:
        physical_assets = list(job.intent["assets"])
        for asset in job.intent["assets"]:
            if await migrated_local_alias(session, job, asset):
                physical_assets.append({**asset, "storage_backend": "local"})
        for asset in physical_assets:
            referenced = await session.scalar(
                select(ContentAsset.id)
                .where(
                    ContentAsset.storage_backend == asset["storage_backend"],
                    ContentAsset.storage_key == asset["storage_key"],
                )
                .limit(1)
            )
            if referenced is not None:
                job.last_error = "original_still_referenced"
                break
            await storage.delete_file(asset["storage_key"], backend=asset["storage_backend"])
        else:
            job.completed = True
            job.last_error = None
    except (OSError, ValueError):
        job.last_error = "original_cleanup_unavailable"
    await session.commit()


async def cleanup_failed_upload(
    session: AsyncSession,
    storage: StorageRouter,
    *,
    user_id: int,
    storage_key: str,
    size_bytes: int,
    sha256: str,
) -> None:
    """Never delete a committed asset. Journal an unreferenced failed PUT before cleanup."""
    await session.rollback()
    referenced = await session.scalar(
        select(ContentAsset.id)
        .where(
            ContentAsset.storage_backend == storage.backend,
            ContentAsset.storage_key == storage_key,
        )
        .limit(1)
    )
    if referenced is not None:
        return
    operation_id = str(uuid5(NAMESPACE_URL, f"uncommitted:{storage.backend}:{storage_key}"))
    if await session.get(ImageDeletion, operation_id) is None:
        session.add(
            ImageDeletion(
                operation_id=operation_id,
                user_id=user_id,
                content_id=0,
                deleted_at=datetime.now(UTC),
                intent={
                    "assets": [
                        {
                            "storage_backend": storage.backend,
                            "storage_key": storage_key,
                            "size_bytes": size_bytes,
                            "sha256": sha256,
                        }
                    ]
                },
            )
        )
    await session.commit()
    await cleanup_image_deletion(session, operation_id, storage)


async def retry_image_deletions(
    session: AsyncSession,
    *,
    config: Settings = settings,
    limit: int = 100,
) -> dict:
    """Operator entry point. Reconcile durable intents, then retry a bounded batch of cleanup."""
    await session.execute(text("SELECT pg_advisory_xact_lock(:key)"), {"key": LEDGER_WRITE_LOCK})
    events = await asyncio.to_thread(get_deletion_ledger(config).read_verified_events)
    repository = ContentRepository(session)
    reconciled = 0
    for intent in events:
        if await session.get(ImageDeletion, intent["operation_id"]) is not None:
            continue
        content = await repository.get_owned(
            user_id=intent["user_id"],
            content_id=intent["content_id"],
            for_update=True,
        )
        if not await apply_deletion_intent(repository, content, intent):
            continue
        reconciled += 1
        if reconciled >= limit:
            break
    await session.commit()
    operation_ids = list(
        await session.scalars(
            select(ImageDeletion.operation_id)
            .where(ImageDeletion.completed.is_(False))
            .order_by(ImageDeletion.attempts, ImageDeletion.deleted_at, ImageDeletion.operation_id)
            .limit(limit)
        )
    )
    for operation_id in operation_ids:
        await cleanup_image_deletion(session, operation_id, StorageRouter(config))
    pending = await session.scalar(
        select(func.count()).select_from(ImageDeletion).where(ImageDeletion.completed.is_(False))
    )
    await session.commit()
    return {"reconciled": reconciled, "attempted": len(operation_ids), "pending": pending}
