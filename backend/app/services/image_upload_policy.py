from fastapi import HTTPException
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import AuthenticationError, ServiceUnavailableError
from app.integrations.storage_client import StorageRouter
from app.models.content import Content
from app.models.content_asset import AssetType, ContentAsset
from app.models.user import User

GUEST_IMAGE_LIMIT_BYTES = 30 * 1024 * 1024
ACCOUNT_IMAGE_LIMIT_BYTES = 300 * 1024 * 1024


class ImageUploadPolicy:
    """Authorize a new original while holding its user's transaction lock.

    The caller must keep this session through the content commit/rollback. Every
    screenshot writer uses this boundary after completed-share replay and before
    OCR/storage. No reservation survives rollback, and deleted rows free space.
    """

    def __init__(self, session: AsyncSession, storage: StorageRouter) -> None:
        self.session = session
        self.storage = storage

    async def authorize(self, *, user_id: int, size_bytes: int) -> None:
        user = await self.session.scalar(
            select(User).where(User.id == user_id).with_for_update()
            .execution_options(populate_existing=True)
        )
        if user is None:
            raise AuthenticationError()

        originals = select(ContentAsset).join(Content).where(
            Content.user_id == user_id, ContentAsset.asset_type == AssetType.SCREENSHOT,
        )
        unknown = await self.session.scalars(originals.where(ContentAsset.size_bytes.is_(None)))
        try:
            for asset in unknown:
                asset.size_bytes = await self.storage.for_backend(asset.storage_backend).file_size(
                    asset.storage_key,
                )
        except OSError as exc:
            # Unknown originals cannot be counted as zero, even when missing.
            raise ServiceUnavailableError("Original image usage could not be verified") from exc
        await self.session.flush()
        used = await self.session.scalar(
            select(func.coalesce(func.sum(ContentAsset.size_bytes), 0)).join(Content).where(
                Content.user_id == user_id, ContentAsset.asset_type == AssetType.SCREENSHOT,
            )
        )
        limit = GUEST_IMAGE_LIMIT_BYTES if user.is_guest else ACCOUNT_IMAGE_LIMIT_BYTES
        if used + size_bytes > limit:
            raise HTTPException(status_code=409, detail={
                "code": "image_quota_exceeded", "limit_bytes": limit,
                "message": "이미지 보관 한도에 도달했어요. "
                "기존 이미지를 삭제한 뒤 다시 저장해 주세요.",
            })
