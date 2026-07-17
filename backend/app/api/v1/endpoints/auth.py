from fastapi import APIRouter, Response, status

from app.api.deps import DatabaseSession
from app.repositories.auth_session_repository import AuthSessionRepository
from app.repositories.user_repository import UserRepository
from app.schemas.auth import LogoutRequest, RefreshTokenRequest, TokenResponse
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


def _build_auth_service(db: DatabaseSession) -> AuthService:
    return AuthService(
        user_repository=UserRepository(db),
        auth_session_repository=AuthSessionRepository(db),
    )
