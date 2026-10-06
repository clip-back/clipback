from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.content import Content
from app.models.content_asset import AssetType, ContentAsset


class ContentAssetRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def create(
        self,
        *,
        content_id: int,
        asset_type: AssetType,
        storage_key: str,
        mime_type: str | None,
    ) -> ContentAsset:
        asset = ContentAsset(
            content_id=content_id,
            asset_type=asset_type,
            storage_key=storage_key,
            mime_type=mime_type,
        )
        self.session.add(asset)
        await self.session.flush()
        return asset

    async def get_owned(self, *, user_id: int, asset_id: int) -> ContentAsset | None:
        result = await self.session.scalars(
            select(ContentAsset)
            .join(Content, Content.id == ContentAsset.content_id)
            .where(ContentAsset.id == asset_id, Content.user_id == user_id)
        )
        return result.first()
