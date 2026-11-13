"""Account deletion: provider unlinking, one ledger record, one DB transaction (ADR 0007, 0008).

scripts/recovery_deletions.py repeats the DB part for historical API images. Keep the
deletion order and the cleanup operation ID formula identical in both places.
"""

import asyncio
import logging
from datetime import UTC, datetime
from uuid import NAMESPACE_URL, uuid5
from zoneinfo import ZoneInfo

from cryptography.fernet import Fernet, InvalidToken
from fastapi import HTTPException
from sqlalchemy import delete, select, text
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.exceptions import AuthenticationError
from app.integrations.deletion_ledger import (
    ACCOUNT_DELETION,
    LEDGER_WRITE_LOCK,
    LedgerUnavailableError,
    account_content_operation_id,
    canonical_json,
    get_deletion_ledger,
)
from app.integrations.social_auth_client import (
    SocialAuthClient,
    SocialAuthClientError,
    SocialAuthNotConfiguredError,
    SocialAuthTimeoutError,
)
from app.integrations.storage_client import StorageRouter
from app.models.account_deletion_reason import AccountDeletionReason
from app.models.apple_auth import AppleCredential
from app.models.category import Category
from app.models.content import Content
from app.models.content_event import ContentEvent
from app.models.image_deletion import ImageDeletion
from app.models.recommendation import (
    RecommendationBatch,
    RecommendationBatchItem,
    RecommendationExposure,
)
from app.models.social_identity import SocialIdentity, SocialProvider
from app.models.user import User
from app.services.image_deletion_service import (
    cleanup_image_deletion,
    deletion_identity,
    deletion_job,
)

logger = logging.getLogger(__name__)
SEOUL = ZoneInfo("Asia/Seoul")
# With the user id: queues one account's deletion requests (two-key advisory lock).
ACCOUNT_DELETION_LOCK = 74264006


def _account_identity(user_id: int, created_at: datetime) -> dict:
    return {"kind": ACCOUNT_DELETION, "user_id": user_id, "user_created_at": created_at.isoformat()}


def _account_operation_id(identity: dict) -> str:
    return str(uuid5(NAMESPACE_URL, canonical_json(identity).decode()))


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
    identity = _account_identity(user_id, created_at)
    contents = [
        {key: value for key, value in deletion_identity(content).items() if key != "user_id"}
        for content in await _image_contents(session, user_id)
    ]
    intent = {
        **identity,
        "operation_id": _account_operation_id(identity),
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


class _UnreadableToken(Exception):
    pass


def _apple_refresh_token(client: SocialAuthClient, encrypted: str) -> str:
    key = client.config.apple_token_encryption_key
    try:
        if key is None:
            raise SocialAuthNotConfiguredError
        cipher = Fernet(key.get_secret_value().encode())
    except (ValueError, TypeError) as exc:
        raise SocialAuthNotConfiguredError from exc
    try:
        return cipher.decrypt(encrypted.encode()).decode()
    except (InvalidToken, ValueError, UnicodeError) as exc:
        raise _UnreadableToken from exc


def _kakao_unlink_configured(client: SocialAuthClient) -> bool:
    # Required in production; development and test skip the unlink without it (D23).
    key = client.config.kakao_admin_key
    return key is not None and bool(key.get_secret_value().strip())


async def revoke_provider_links(
    session: AsyncSession, client: SocialAuthClient, user_id: int
) -> bool:
    """Unlink Apple and Kakao while their tokens and member numbers still exist (D5, D7).

    Failures only go to the log, keyed by the ledger operation ID the deletion will use;
    the deletion continues and nothing is reconnected if it later fails (D30). Google is
    disconnected by the app (D6) and Naver has no revocation integration. False when the
    account does not exist.
    """
    created_at = await session.scalar(select(User.created_at).where(User.id == user_id))
    if created_at is None:
        return False
    operation_id = _account_operation_id(_account_identity(user_id, created_at))
    links = await session.execute(
        select(
            SocialIdentity.provider,
            SocialIdentity.provider_subject,
            AppleCredential.refresh_token_encrypted,
        )
        .outerjoin(AppleCredential, AppleCredential.social_identity_id == SocialIdentity.id)
        .where(SocialIdentity.user_id == user_id)
        .order_by(SocialIdentity.id)
    )
    for provider, subject, encrypted in links:
        try:
            if provider == SocialProvider.APPLE and encrypted:
                await client.revoke_apple_token(_apple_refresh_token(client, encrypted))
            elif provider == SocialProvider.KAKAO and _kakao_unlink_configured(client):
                await client.unlink_kakao(subject)
            continue
        except _UnreadableToken:
            reason = "token_unreadable"
        except SocialAuthTimeoutError:
            reason = "timeout"
        except SocialAuthNotConfiguredError:
            reason = "not_configured"
        except SocialAuthClientError:
            reason = "provider_error"
        logger.warning(
            "Provider revocation failed: provider=%s reason=%s operation_id=%s",
            provider.value, reason, operation_id,
        )
    return True


async def delete_account(
    session: AsyncSession,
    storage: StorageRouter,
    social_auth_client: SocialAuthClient,
    *,
    user_id: int,
    reasons: list[str] | None,
) -> list[str]:
    """The app's deletion: provider unlinking → ledger record → DB deletion with the reason
    record → originals. The operator command passes no reasons and writes no reason record
    (D19). Returns the original cleanup operations of this deletion.

    An account lock taken first queues overlapping requests of one account, before any
    provider call. A later request rechecks the account after the earlier one finishes:
    deleted → 401, otherwise it runs again and reuses any ledger record the earlier one left
    (U2). Only this function takes the account lock and always before the ledger → account
    row locks, so it adds no lock cycle; other accounts are not blocked during provider calls.
    """
    try:
        await session.execute(
            text("SELECT pg_advisory_xact_lock(:namespace, :user_id)"),
            {"namespace": ACCOUNT_DELETION_LOCK, "user_id": user_id},
        )
        if not await revoke_provider_links(session, social_auth_client, user_id):
            raise AuthenticationError()
        intent = await record_account_deletion(session, user_id)
        if intent is None:
            raise AuthenticationError()
        operation_ids = await apply_account_deletion(session, intent)
        if reasons is not None:
            session.add(
                AccountDeletionReason(reasons=reasons, deleted_on=datetime.now(SEOUL).date())
            )
        await session.commit()
    except LedgerUnavailableError as exc:
        await session.rollback()
        raise HTTPException(
            status_code=503, detail="Account deletion is temporarily unavailable"
        ) from exc
    except Exception:
        await session.rollback()
        raise
    # The account is gone; an original left behind stays in the cleanup list for retry.
    for operation_id in operation_ids:
        try:
            await cleanup_image_deletion(session, operation_id, storage)
        except Exception:
            await session.rollback()
            logger.warning("Image cleanup deferred: operation_id=%s", operation_id)
    return operation_ids
