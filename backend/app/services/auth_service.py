from datetime import UTC, datetime, timedelta

from app.core.config import settings
from app.core.exceptions import AuthenticationError
from app.core.security import create_access_token, generate_refresh_token, hash_refresh_token
from app.repositories.auth_session_repository import AuthSessionRepository
from app.repositories.user_repository import UserRepository
from app.schemas.auth import TokenResponse


class AuthService:
    def __init__(
        self,
        *,
        user_repository: UserRepository,
        auth_session_repository: AuthSessionRepository,
    ) -> None:
        self.user_repository = user_repository
        self.auth_session_repository = auth_session_repository

    async def create_guest_session(self) -> TokenResponse:
        refresh_token = generate_refresh_token()
        now = datetime.now(UTC)

        try:
            user = await self.user_repository.create_guest()
            auth_session = await self.auth_session_repository.create(
                user_id=user.id,
                refresh_token_hash=hash_refresh_token(refresh_token),
                expires_at=now + timedelta(days=settings.refresh_token_expire_days),
            )
            response = self._build_token_response(
                user_id=user.id,
                session_id=auth_session.id,
                refresh_token=refresh_token,
            )
            await self.auth_session_repository.session.commit()
        except Exception:
            await self.auth_session_repository.session.rollback()
            raise

        return response

    async def refresh_session(self, refresh_token: str) -> TokenResponse:
        now = datetime.now(UTC)
        auth_session = await self.auth_session_repository.get_by_refresh_token_hash_for_update(
            hash_refresh_token(refresh_token)
        )
        if (
            auth_session is None
            or auth_session.revoked_at is not None
            or auth_session.expires_at <= now
        ):
            await self.auth_session_repository.session.rollback()
            raise AuthenticationError("Invalid or expired refresh token")

        user = await self.user_repository.get(auth_session.user_id)
        if user is None:
            await self.auth_session_repository.session.rollback()
            raise AuthenticationError("Invalid or expired refresh token")

        new_refresh_token = generate_refresh_token()
        try:
            await self.auth_session_repository.rotate(
                auth_session,
                refresh_token_hash=hash_refresh_token(new_refresh_token),
                expires_at=now + timedelta(days=settings.refresh_token_expire_days),
            )
            response = self._build_token_response(
                user_id=user.id,
                session_id=auth_session.id,
                refresh_token=new_refresh_token,
            )
            await self.auth_session_repository.session.commit()
        except Exception:
            await self.auth_session_repository.session.rollback()
            raise

        return response

    async def logout(self, refresh_token: str) -> None:
        auth_session = await self.auth_session_repository.get_by_refresh_token_hash_for_update(
            hash_refresh_token(refresh_token)
        )
        if auth_session is None:
            await self.auth_session_repository.session.rollback()
            return

        try:
            await self.auth_session_repository.revoke(auth_session)
            await self.auth_session_repository.session.commit()
        except Exception:
            await self.auth_session_repository.session.rollback()
            raise

    @staticmethod
    def _build_token_response(
        *,
        user_id: int,
        session_id: int,
        refresh_token: str,
    ) -> TokenResponse:
        return TokenResponse(
            access_token=create_access_token(user_id=user_id, session_id=session_id),
            refresh_token=refresh_token,
            token_type="bearer",
            expires_in=settings.access_token_expire_minutes * 60,
            refresh_expires_in=settings.refresh_token_expire_days * 24 * 60 * 60,
        )
