from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.social_identity import SocialIdentity, SocialProvider


class SocialIdentityRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def list_providers(self, user_id: int) -> list[SocialProvider]:
        result = await self.session.scalars(
            select(SocialIdentity.provider)
            .where(SocialIdentity.user_id == user_id)
            .order_by(SocialIdentity.provider.asc())
        )
        return list(result)

    async def get_by_provider_subject(
        self,
        *,
        provider: SocialProvider,
        provider_subject: str,
    ) -> SocialIdentity | None:
        result = await self.session.scalars(
            select(SocialIdentity).where(
                SocialIdentity.provider == provider,
                SocialIdentity.provider_subject == provider_subject,
            )
        )
        return result.first()

    async def create(
        self,
        *,
        user_id: int,
        provider: SocialProvider,
        provider_subject: str,
    ) -> SocialIdentity:
        identity = SocialIdentity(
            user_id=user_id,
            provider=provider,
            provider_subject=provider_subject,
        )
        self.session.add(identity)
        await self.session.flush()
        return identity

    async def get_by_user_provider(
        self,
        *,
        user_id: int,
        provider: SocialProvider,
    ) -> SocialIdentity | None:
        result = await self.session.scalars(
            select(SocialIdentity).where(
                SocialIdentity.user_id == user_id,
                SocialIdentity.provider == provider,
            )
        )
        return result.first()
