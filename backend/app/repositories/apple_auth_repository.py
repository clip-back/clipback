from datetime import datetime
from uuid import UUID

from sqlalchemy import delete, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.apple_auth import AppleAuthChallenge, AppleCredential
from app.models.auth_session import AuthSession
from app.models.social_identity import SocialIdentity, SocialProvider


class AppleAuthRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def create_challenge(self, challenge: AppleAuthChallenge, *, now: datetime) -> None:
        # A bounded lifetime also bounds retained nonces without a scheduled cleanup job.
        await self.session.execute(
            delete(AppleAuthChallenge).where(AppleAuthChallenge.expires_at <= now)
        )
        self.session.add(challenge)
        await self.session.flush()

    async def consume_challenge(
        self, *, challenge_id: UUID, purpose: str, user_id: int | None, now: datetime
    ) -> str | None:
        return await self.session.scalar(
            update(AppleAuthChallenge)
            .where(
                AppleAuthChallenge.id == challenge_id,
                AppleAuthChallenge.purpose == purpose,
                AppleAuthChallenge.user_id == user_id,
                AppleAuthChallenge.expires_at > now,
                AppleAuthChallenge.consumed_at.is_(None),
            )
            .values(consumed_at=now)
            .returning(AppleAuthChallenge.nonce_hash)
        )

    async def apple_user_for_refresh(self, refresh_token_hash: str) -> int | None:
        return await self.session.scalar(
            select(AuthSession.user_id)
            .join(SocialIdentity, SocialIdentity.user_id == AuthSession.user_id)
            .where(
                AuthSession.refresh_token_hash == refresh_token_hash,
                SocialIdentity.provider == SocialProvider.APPLE,
            )
        )

    async def get_identity(self, user_id: int) -> SocialIdentity | None:
        return await self.session.scalar(
            select(SocialIdentity).where(
                SocialIdentity.user_id == user_id,
                SocialIdentity.provider == SocialProvider.APPLE,
            )
        )

    async def get_credential(self, identity_id: int) -> AppleCredential | None:
        return await self.session.scalar(
            select(AppleCredential)
            .where(AppleCredential.social_identity_id == identity_id)
            .with_for_update()
        )

    async def save_credential(
        self, *, identity_id: int, client_id: str, encrypted_token: str, verified_at: datetime
    ) -> None:
        credential = await self.get_credential(identity_id)
        if credential is None:
            credential = AppleCredential(social_identity_id=identity_id)
            self.session.add(credential)
        credential.client_id = client_id
        credential.refresh_token_encrypted = encrypted_token
        credential.last_verified_at = verified_at
        credential.revoked_at = None
        await self.session.flush()
