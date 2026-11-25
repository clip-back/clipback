from fastapi import APIRouter, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUserId, DatabaseSession
from app.integrations.social_auth_client import get_social_auth_client
from app.integrations.storage_client import get_storage_client
from app.repositories.event_repository import EventRepository
from app.repositories.social_identity_repository import SocialIdentityRepository
from app.repositories.user_repository import UserRepository
from app.schemas.user import (
    AccountDeletionRequest,
    AIConsentRead,
    AIConsentUpdate,
    UserRead,
    UserStatsRead,
)
from app.services import ai_consent
from app.services.account_deletion_service import delete_account
from app.services.user_service import UserService

router = APIRouter()


@router.get("/me", response_model=UserRead)
async def read_me(db: DatabaseSession, current_user_id: CurrentUserId) -> UserRead:
    return await _build_user_service(db).read_me(user_id=current_user_id)


@router.put("/me/ai-consent", response_model=AIConsentRead)
async def update_ai_consent(
    payload: AIConsentUpdate, db: DatabaseSession, current_user_id: CurrentUserId
) -> AIConsentRead:
    record = await ai_consent.decide(db, current_user_id, status=payload.status)
    return AIConsentRead(
        status=record.status, notice_version=record.notice_version, decided_at=record.decided_at,
    )


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_me(
    payload: AccountDeletionRequest, db: DatabaseSession, current_user_id: CurrentUserId
) -> Response:
    await delete_account(
        db,
        get_storage_client(),
        get_social_auth_client(),
        user_id=current_user_id,
        reasons=payload.reasons,
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/me/stats", response_model=UserStatsRead)
async def read_stats(db: DatabaseSession, current_user_id: CurrentUserId) -> UserStatsRead:
    return await _build_user_service(db).read_stats(user_id=current_user_id)


def _build_user_service(db: AsyncSession) -> UserService:
    return UserService(
        user_repository=UserRepository(db),
        social_identity_repository=SocialIdentityRepository(db),
        event_repository=EventRepository(db),
    )
