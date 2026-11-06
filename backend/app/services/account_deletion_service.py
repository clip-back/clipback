"""Account deletion: one ledger record first, then one DB transaction (ADR 0007, 0008).

scripts/recovery_deletions.py repeats the DB part for historical API images. Keep the
deletion order and the cleanup operation ID formula identical in both places.
"""

import asyncio
from datetime import UTC, datetime
from uuid import NAMESPACE_URL, uuid5

from sqlalchemy import delete, select, text
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.integrations.deletion_ledger import (
    ACCOUNT_DELETION,
    LEDGER_WRITE_LOCK,
    canonical_json,
    get_deletion_ledger,
)
from app.models.category import Category
from app.models.content import Content
from app.models.content_event import ContentEvent
from app.models.image_deletion import ImageDeletion
from app.models.recommendation import (
    RecommendationBatch,
    RecommendationBatchItem,
    RecommendationExposure,
)
from app.models.user import User
from app.services.image_deletion_service import deletion_identity, deletion_job


def account_content_operation_id(operation_id: str, content_id: int, saved_at: str) -> str:
    """Retries and restore replays of one account deletion converge on one cleanup row."""
    saved_at = datetime.fromisoformat(saved_at).astimezone(UTC).isoformat()
    return str(uuid5(NAMESPACE_URL, f"account-deletion:{operation_id}:{content_id}:{saved_at}"))


async def _locked_created_at(session: AsyncSession, user_id: int) -> datetime | None:
    return await session.scalar(
        select(User.created_at).where(User.id == user_id).with_for_update()
    )


async def _image_contents(session: AsyncSession, user_id: int) -> list[Content]:
    return list(
        await session.scalars(
            select(Content)
            .options(selectinload(Content.assets))
            .where(Content.user_id == user_id, Content.assets.any())
            .order_by(Content.id)
        )
    )


async def record_account_deletion(session: AsyncSession, user_id: int) -> dict | None:
    """Write (or reuse) the account's ledger record. None when the account does not exist.

    A DB failure after this leaves a confirmed deletion request (U2): the retry command and
    a restore delete the account, and a new attempt reuses the same record.
    """
    await session.execute(text("SELECT pg_advisory_xact_lock(:key)"), {"key": LEDGER_WRITE_LOCK})
    created_at = await _locked_created_at(session, user_id)
    if created_at is None:
        return None
    identity = {
        "kind": ACCOUNT_DELETION,
        "user_id": user_id,
        "user_created_at": created_at.isoformat(),
    }
    contents = [
        {key: value for key, value in deletion_identity(content).items() if key != "user_id"}
        for content in await _image_contents(session, user_id)
    ]
    intent = {
        **identity,
        "operation_id": str(uuid5(NAMESPACE_URL, canonical_json(identity).decode())),
        "deleted_at": datetime.now(UTC).isoformat(),
        "contents": contents,
    }
    ledger = get_deletion_ledger()
    await asyncio.to_thread(ledger.append, intent)
    return await asyncio.to_thread(ledger.read_operation, intent["operation_id"])


async def apply_account_deletion(session: AsyncSession, intent: dict) -> list[str] | None:
    """Delete the account in the caller's transaction; return its original cleanup operations.

    The caller holds the ledger lock. Only an account whose id and creation time both match
    the record is deleted (U1); otherwise None. Every image content still in the DB gets a
    cleanup row, whether or not the record lists it.
    """
    user_id = intent["user_id"]
    created_at = await _locked_created_at(session, user_id)
    if created_at is None or created_at != datetime.fromisoformat(intent["user_created_at"]):
        return None
    operation_ids = []
    for content in await _image_contents(session, user_id):
        identity = deletion_identity(content)
        operation_id = account_content_operation_id(
            intent["operation_id"], content.id, identity["saved_at"]
        )
        if await session.get(ImageDeletion, operation_id) is None:
            session.add(
                deletion_job(
                    {**identity, "operation_id": operation_id, "deleted_at": intent["deleted_at"]}
                )
            )
        operation_ids.append(operation_id)
    # Rows that reference the user without a cascading foreign key go first.
    batches = select(RecommendationBatch.id).where(RecommendationBatch.user_id == user_id)
    for statement in (
        delete(ContentEvent).where(ContentEvent.user_id == user_id),
        delete(RecommendationExposure).where(RecommendationExposure.user_id == user_id),
        delete(RecommendationBatchItem).where(RecommendationBatchItem.batch_id.in_(batches)),
        delete(RecommendationBatch).where(RecommendationBatch.user_id == user_id),
        delete(Content).where(Content.user_id == user_id),
        # Shared categories ("미분류", templates) have no user and stay.
        delete(Category).where(Category.user_id == user_id),
        delete(User).where(User.id == user_id),
    ):
        await session.execute(statement)
    return operation_ids
