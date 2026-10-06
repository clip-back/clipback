from datetime import UTC, datetime

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.auth_session import AuthSession


class AuthSessionRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def create(
        self,
        *,
        user_id: int,
        refresh_token_hash: str,
        expires_at: datetime,
    ) -> AuthSession:
        auth_session = AuthSession(
            user_id=user_id,
            refresh_token_hash=refresh_token_hash,
            expires_at=expires_at,
        )
        self.session.add(auth_session)
        await self.session.flush()
        await self.session.refresh(auth_session)
        return auth_session

    async def get_active(self, *, session_id: int, user_id: int) -> AuthSession | None:
        result = await self.session.scalars(
            select(AuthSession).where(
                AuthSession.id == session_id,
                AuthSession.user_id == user_id,
                AuthSession.revoked_at.is_(None),
                AuthSession.expires_at > datetime.now(UTC),
            )
        )
        return result.first()

    async def get_by_refresh_token_hash_for_update(
        self,
        refresh_token_hash: str,
    ) -> AuthSession | None:
        result = await self.session.scalars(
            select(AuthSession)
            .where(AuthSession.refresh_token_hash == refresh_token_hash)
            .with_for_update()
        )
        return result.first()

    async def rotate(
        self,
        auth_session: AuthSession,
        *,
        refresh_token_hash: str,
        expires_at: datetime,
    ) -> AuthSession:
        auth_session.refresh_token_hash = refresh_token_hash
        auth_session.expires_at = expires_at
        auth_session.revoked_at = None
        await self.session.flush()
        return auth_session

    async def revoke(self, auth_session: AuthSession) -> AuthSession:
        if auth_session.revoked_at is None:
            auth_session.revoked_at = datetime.now(UTC)
            await self.session.flush()
        return auth_session

    async def revoke_all_for_user(self, user_id: int) -> None:
        await self.session.execute(
            update(AuthSession)
            .where(
                AuthSession.user_id == user_id,
                AuthSession.revoked_at.is_(None),
            )
            .values(revoked_at=datetime.now(UTC))
        )
        await self.session.flush()
