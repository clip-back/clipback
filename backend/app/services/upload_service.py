import json
import logging
import warnings
from dataclasses import dataclass
from enum import StrEnum
from io import BytesIO
from uuid import uuid4

from fastapi import HTTPException, UploadFile, status
from PIL import Image, UnidentifiedImageError

from app.core.config import settings
from app.core.exceptions import NotFoundError
from app.integrations.ocr_client import (
    OCRClient,
    OCRClientError,
    OCRClientInvalidResponseError,
    OCRClientNotConfiguredError,
    OCRClientTimeoutError,
    ScreenshotOCRResult,
)
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


class ScreenshotOCRStatus(StrEnum):
    SUCCESS = "success"
    NO_TEXT = "no_text"
    FAILED = "failed"


class ScreenshotOCRFailureReason(StrEnum):
    NOT_CONFIGURED = "not_configured"
    TIMEOUT = "timeout"
    INVALID_RESPONSE = "invalid_response"
    ERROR = "error"


class UploadService:
    def __init__(
        self,
        *,
        content_service: ContentService,
        content_asset_repository: ContentAssetRepository,
        storage_client: StorageClient,
        ocr_client: OCRClient,
        max_bytes: int = settings.screenshot_max_bytes,
    ) -> None:
        self.content_service = content_service
        self.content_asset_repository = content_asset_repository
        self.storage_client = storage_client
        self.ocr_client = ocr_client
        self.max_bytes = max_bytes

    async def upload_screenshot(
        self,
        *,
        user_id: int,
        file: UploadFile,
        category_ids: list[int],
        tag_names: list[str] | None = None,
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
        ocr_result, ocr_metadata = await self._extract_ocr(
            content=content,
            mime_type=mime_type,
        )
        storage_key = f"screenshots/{user_id}/{uuid4().hex}.{extension}"
        await self.storage_client.save_file(storage_key, content)

        try:
            return await self.content_service.create_content(
                user_id=user_id,
                payload=ContentCreate(
                    content_type=ContentType.SCREENSHOT,
                    source=ContentSource.SCREENSHOT,
                    category_ids=category_ids,
                    tag_names=tag_names or [],
                    title=ocr_result.title or None,
                    summary=ocr_result.summary or None,
                ),
                event_metadata_json=json.dumps(
                    ocr_metadata,
                    ensure_ascii=False,
                    separators=(",", ":"),
                ),
                recommendation_shared_text=ocr_result.text or None,
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

    async def _extract_ocr(
        self,
        *,
        content: bytes,
        mime_type: str,
    ) -> tuple[ScreenshotOCRResult, dict[str, str | None]]:
        try:
            result = await self.ocr_client.extract(
                image_bytes=content,
                mime_type=mime_type,
            )
        except OCRClientNotConfiguredError:
            return self._ocr_fallback(ScreenshotOCRFailureReason.NOT_CONFIGURED)
        except OCRClientTimeoutError:
            return self._ocr_fallback(ScreenshotOCRFailureReason.TIMEOUT)
        except OCRClientInvalidResponseError:
            return self._ocr_fallback(ScreenshotOCRFailureReason.INVALID_RESPONSE)
        except OCRClientError:
            logger.warning("Screenshot OCR failed", exc_info=True)
            return self._ocr_fallback(ScreenshotOCRFailureReason.ERROR)
        except Exception:
            logger.exception("Unexpected screenshot OCR failure")
            return self._ocr_fallback(ScreenshotOCRFailureReason.ERROR)

        if not result.text:
            return result, {
                "ocr_status": ScreenshotOCRStatus.NO_TEXT.value,
                "ocr_failure_reason": None,
            }
        return result, {
            "ocr_status": ScreenshotOCRStatus.SUCCESS.value,
            "ocr_failure_reason": None,
        }

    @staticmethod
    def _ocr_fallback(
        reason: ScreenshotOCRFailureReason,
    ) -> tuple[ScreenshotOCRResult, dict[str, str | None]]:
        return ScreenshotOCRResult(text="", title="", summary=""), {
            "ocr_status": ScreenshotOCRStatus.FAILED.value,
            "ocr_failure_reason": reason.value,
        }

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
