from fastapi import APIRouter, HTTPException, Response, status

from app.api.deps import CurrentUserId, DatabaseSession
from app.integrations.social_auth_client import get_social_auth_client
from app.models.social_identity import SocialProvider
from app.repositories.auth_session_repository import AuthSessionRepository
from app.repositories.social_identity_repository import SocialIdentityRepository
from app.repositories.user_repository import UserRepository
from app.schemas.auth import (
    LogoutRequest,
    RefreshTokenRequest,
    SocialTokenRequest,
    SocialTokenResponse,
    TokenResponse,
)
from app.services.auth_service import AuthService

router = APIRouter()


@router.post("/guest", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def create_guest_session(db: DatabaseSession) -> TokenResponse:
    return await _build_auth_service(db).create_guest_session()


@router.post("/refresh", response_model=TokenResponse)
async def refresh_session(payload: RefreshTokenRequest, db: DatabaseSession) -> TokenResponse:
    return await _build_auth_service(db).refresh_session(payload.refresh_token)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(payload: LogoutRequest, db: DatabaseSession) -> Response:
    await _build_auth_service(db).logout(payload.refresh_token)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/social/{provider}", response_model=SocialTokenResponse)
async def social_login(
    provider: SocialProvider,
    payload: SocialTokenRequest,
    db: DatabaseSession,
) -> SocialTokenResponse:
    return await _build_auth_service(db).social_login(
        provider=provider,
        token=_validated_social_token(payload),
    )


@router.post("/social/{provider}/upgrade", response_model=SocialTokenResponse)
async def upgrade_guest_with_social(
    provider: SocialProvider,
    payload: SocialTokenRequest,
    db: DatabaseSession,
    current_user_id: CurrentUserId,
) -> SocialTokenResponse:
    return await _build_auth_service(db).upgrade_guest_with_social(
        user_id=current_user_id,
        provider=provider,
        token=_validated_social_token(payload),
    )


def _validated_social_token(payload: SocialTokenRequest) -> str:
    if not payload.token.strip() or len(payload.token) > 8192:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="Invalid social authentication token",
        )
    return payload.token


def _build_auth_service(db: DatabaseSession) -> AuthService:
    return AuthService(
        user_repository=UserRepository(db),
        auth_session_repository=AuthSessionRepository(db),
        social_identity_repository=SocialIdentityRepository(db),
        social_auth_client=get_social_auth_client(),
    )
