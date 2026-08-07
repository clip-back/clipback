import logging
import warnings
from dataclasses import dataclass
from io import BytesIO
from uuid import uuid4

from fastapi import HTTPException, UploadFile, status
from PIL import Image, UnidentifiedImageError

from app.core.config import settings
from app.core.exceptions import NotFoundError
from app.integrations.storage_client import StorageClient
from app.models.content_asset import AssetType
from app.repositories.content_asset_repository import ContentAssetRepository
from app.schemas.content import ContentCreate, ContentRead, ContentSource, ContentType
from app.services.content_service import ContentService, PendingContentAsset

logger = logging.getLogger(__name__)

SUPPORTED_IMAGE_FORMATS = {
    "PNG": ("image/png", "png"),
    "JPEG": ("image/jpeg", "jpg"),
    "WEBP": ("image/webp", "webp"),
}


@dataclass(frozen=True)
class StoredAssetFile:
    content: bytes
    mime_type: str


class UploadService:
    def __init__(
        self,
        *,
        content_service: ContentService,
        content_asset_repository: ContentAssetRepository,
        storage_client: StorageClient,
        max_bytes: int = settings.screenshot_max_bytes,
    ) -> None:
        self.content_service = content_service
        self.content_asset_repository = content_asset_repository
        self.storage_client = storage_client
        self.max_bytes = max_bytes

    async def upload_screenshot(
        self,
        *,
        user_id: int,
        file: UploadFile,
        category_ids: list[int],
    ) -> ContentRead:
        content = await file.read(self.max_bytes + 1)
        if not content:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="Screenshot file cannot be empty",
            )
        if len(content) > self.max_bytes:
            raise HTTPException(
                status_code=status.HTTP_413_CONTENT_TOO_LARGE,
                detail="Screenshot file exceeds the configured size limit",
            )

        mime_type, extension = self._validate_image(content)
        storage_key = f"screenshots/{user_id}/{uuid4().hex}.{extension}"
        await self.storage_client.save_file(storage_key, content)

        try:
            return await self.content_service.create_content(
                user_id=user_id,
                payload=ContentCreate(
                    content_type=ContentType.SCREENSHOT,
                    source=ContentSource.SCREENSHOT,
                    category_ids=category_ids,
                ),
                asset=PendingContentAsset(
                    asset_type=AssetType.SCREENSHOT,
                    storage_key=storage_key,
                    mime_type=mime_type,
                ),
            )
        except Exception:
            try:
                await self.storage_client.delete_file(storage_key)
            except Exception:
                logger.exception("Failed to delete screenshot after database rollback")
            raise

    async def read_asset(self, *, user_id: int, asset_id: int) -> StoredAssetFile:
        asset = await self.content_asset_repository.get_owned(
            user_id=user_id,
            asset_id=asset_id,
        )
        if asset is None:
            raise NotFoundError("Content asset not found")

        try:
            content = await self.storage_client.read_file(asset.storage_key)
        except FileNotFoundError as exc:
            logger.error("Stored content asset is missing: asset_id=%s", asset.id)
            raise NotFoundError("Content asset not found") from exc

        return StoredAssetFile(
            content=content,
            mime_type=asset.mime_type or "application/octet-stream",
        )

    @staticmethod
    def _validate_image(content: bytes) -> tuple[str, str]:
        try:
            with warnings.catch_warnings():
                warnings.simplefilter("error", Image.DecompressionBombWarning)
                with Image.open(BytesIO(content)) as image:
                    image_format = image.format
                    image.verify()
        except (
            Image.DecompressionBombError,
            Image.DecompressionBombWarning,
            OSError,
            SyntaxError,
            UnidentifiedImageError,
        ) as exc:
            raise HTTPException(
                status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
                detail="Unsupported or invalid screenshot image",
            ) from exc

        image_info = SUPPORTED_IMAGE_FORMATS.get(image_format or "")
        if image_info is None:
            raise HTTPException(
                status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
                detail="Unsupported or invalid screenshot image",
            )
        return image_info
