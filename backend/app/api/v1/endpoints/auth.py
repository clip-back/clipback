from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from fastapi.exceptions import RequestValidationError
from fastapi.routing import APIRoute
from fastapi.security import HTTPAuthorizationCredentials

from app.api.deps import CurrentUserId, DatabaseSession, bearer_scheme, get_current_user_id
from app.core.exceptions import AuthenticationError
from app.core.security import create_share_token, decode_access_token
from app.integrations.social_auth_client import get_social_auth_client
from app.models.social_identity import SocialProvider
from app.repositories.apple_auth_repository import AppleAuthRepository
from app.repositories.auth_session_repository import AuthSessionRepository
from app.repositories.social_identity_repository import SocialIdentityRepository
from app.repositories.user_repository import UserRepository
from app.schemas.auth import (
    AppleChallengeCreate,
    AppleChallengeRead,
    AppleTokenRequest,
    LogoutRequest,
    RefreshTokenRequest,
    ShareCredentialRead,
    SocialTokenRequest,
    SocialTokenResponse,
    TokenResponse,
    TokenSocialProvider,
)
from app.services.apple_auth_service import AppleAuthService
from app.services.auth_service import AuthService


class AuthRoute(APIRoute):
    def get_route_handler(self):
        handler = super().get_route_handler()

        async def sanitized_handler(request: Request) -> Response:
            try:
                return await handler(request)
            except RequestValidationError as exc:
                # Pydantic errors can contain the entire input body, including tokens
                # and one-time codes. Keep authentication validation errors generic.
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                    detail="Invalid authentication request",
                    headers={"Cache-Control": "no-store"},
                ) from exc

        return sanitized_handler


router = APIRouter(route_class=AuthRoute)


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


@router.post("/social/apple/challenge", response_model=AppleChallengeRead, status_code=201)
async def create_apple_challenge(
    payload: AppleChallengeCreate,
    db: DatabaseSession,
    response: Response,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> AppleChallengeRead:
    response.headers["Cache-Control"] = "no-store"
    user_id = (
        await get_current_user_id(db, credentials) if payload.purpose == "upgrade" else None
    )
    return await _build_apple_auth_service(db).create_challenge(
        purpose=payload.purpose, user_id=user_id
    )


@router.post("/social/apple", response_model=SocialTokenResponse)
async def apple_login(
    payload: AppleTokenRequest, db: DatabaseSession, response: Response
) -> SocialTokenResponse:
    _validated_social_token(payload)
    response.headers["Cache-Control"] = "no-store"
    return await _build_auth_service(db).apple_login(payload)


@router.post("/social/apple/upgrade", response_model=SocialTokenResponse)
async def upgrade_guest_with_apple(
    payload: AppleTokenRequest, db: DatabaseSession,
    current_user_id: CurrentUserId, response: Response,
) -> SocialTokenResponse:
    _validated_social_token(payload)
    response.headers["Cache-Control"] = "no-store"
    return await _build_auth_service(db).upgrade_guest_with_apple(
        user_id=current_user_id, payload=payload
    )


@router.post("/social/{provider}", response_model=SocialTokenResponse)
async def social_login(
    provider: TokenSocialProvider,
    payload: SocialTokenRequest,
    db: DatabaseSession,
) -> SocialTokenResponse:
    return await _build_auth_service(db).social_login(
        provider=SocialProvider(provider.value),
        token=_validated_social_token(payload),
    )


@router.post("/social/{provider}/upgrade", response_model=SocialTokenResponse)
async def upgrade_guest_with_social(
    provider: TokenSocialProvider,
    payload: SocialTokenRequest,
    db: DatabaseSession,
    current_user_id: CurrentUserId,
) -> SocialTokenResponse:
    return await _build_auth_service(db).upgrade_guest_with_social(
        user_id=current_user_id,
        provider=SocialProvider(provider.value),
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
        apple_auth_service=_build_apple_auth_service(db),
    )


def _build_apple_auth_service(db: DatabaseSession) -> AppleAuthService:
    return AppleAuthService(
        repository=AppleAuthRepository(db), client=get_social_auth_client(),
        user_repository=UserRepository(db), auth_session_repository=AuthSessionRepository(db),
    )


@router.post("/share-credential", response_model=ShareCredentialRead)
async def create_share_credential(
    db: DatabaseSession, current_user_id: CurrentUserId, response: Response,
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
) -> ShareCredentialRead:
    claims = decode_access_token(credentials.credentials)
    parent = await AuthSessionRepository(db).get_active(
        session_id=claims.session_id, user_id=current_user_id,
    )
    if parent is None:
        raise AuthenticationError()
    expires_at = min(claims.expires_at, parent.expires_at)
    response.headers["Cache-Control"] = "no-store"
    return ShareCredentialRead(
        share_token=create_share_token(
            user_id=current_user_id, session_id=claims.session_id, expires_at=expires_at,
        ),
        expires_at=expires_at, user_id=current_user_id, session_id=claims.session_id,
    )
