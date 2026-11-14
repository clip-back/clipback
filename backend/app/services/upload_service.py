import hashlib
import logging
import warnings
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from enum import StrEnum
from io import BytesIO
from uuid import uuid4

from fastapi import HTTPException, UploadFile, status
from PIL import Image, UnidentifiedImageError

from app.core.config import settings
from app.core.exceptions import NotFoundError, ServiceUnavailableError
from app.integrations.ocr_client import (
    OCRClient,
    OCRClientError,
    OCRClientInvalidResponseError,
    OCRClientNotConfiguredError,
    OCRClientTimeoutError,
    ScreenshotOCRResult,
)
from app.integrations.storage_client import S3StorageClient, StorageRouter, StorageUnavailableError
from app.models.content_asset import AssetType
from app.repositories.content_asset_repository import ContentAssetRepository
from app.schemas.content import ContentAssetAccess
from app.services.content_service import PendingContentAsset
from app.services.image_storage_control import ImageUploadControl
from app.services.image_upload_policy import ImageUploadPolicy

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


@dataclass(frozen=True)
class ScreenshotOriginal:
    content: bytes
    storage_key: str
    mime_type: str
    ocr: ScreenshotOCRResult
    ocr_metadata: dict[str, str | None]


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
        content_asset_repository: ContentAssetRepository,
        storage_client: StorageRouter,
        ocr_client: OCRClient,
        image_upload_policy: ImageUploadPolicy,
        image_storage_control: ImageUploadControl | None = None,
        max_bytes: int = settings.screenshot_max_bytes,
    ) -> None:
        self.content_asset_repository = content_asset_repository
        self.storage_client = storage_client
        self.ocr_client = ocr_client
        self.image_upload_policy = image_upload_policy
        self.max_bytes = max_bytes
        self.image_storage_control = image_storage_control

    async def read_screenshot(self, file: UploadFile) -> bytes:
        content = await file.read(self.max_bytes + 1)
        if not content:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="Screenshot file cannot be empty",
            )
        if len(content) > self.max_bytes:
            raise HTTPException(
                status_code=status.HTTP_413_CONTENT_TOO_LARGE,
                detail={"code": "image_file_too_large", "limit_bytes": self.max_bytes},
            )
        return content

    async def prepare_original(self, *, user_id: int, content: bytes) -> ScreenshotOriginal:
        mime_type, extension = self._validate_image(content)
        if self.image_storage_control is not None:
            await self.image_storage_control.authorize()
        await self.image_upload_policy.authorize(user_id=user_id, size_bytes=len(content))
        ocr_result, ocr_metadata = await self._extract_ocr(
            content=content,
            mime_type=mime_type,
        )
        return ScreenshotOriginal(
            content=content,
            storage_key=f"screenshots/{user_id}/{uuid4().hex}.{extension}",
            mime_type=mime_type,
            ocr=ocr_result,
            ocr_metadata=ocr_metadata,
        )

    async def save_original(self, original: ScreenshotOriginal) -> None:
        await self.storage_client.save_file(original.storage_key, original.content)

    async def observe_saved_original(self, original: ScreenshotOriginal) -> None:
        if self.image_storage_control is not None:
            await self.image_storage_control.observe(
                f"original_upload_{self.storage_client.backend}", len(original.content),
            )

    def asset_for(self, original: ScreenshotOriginal) -> PendingContentAsset:
        return PendingContentAsset(
            asset_type=AssetType.SCREENSHOT,
            storage_key=original.storage_key,
            mime_type=original.mime_type,
            storage_backend=self.storage_client.backend,
            size_bytes=len(original.content),
            sha256=hashlib.sha256(original.content).hexdigest(),
        )

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

    async def asset_access(self, *, user_id: int, asset_id: int) -> ContentAssetAccess:
        asset = await self.content_asset_repository.get_owned(user_id=user_id, asset_id=asset_id)
        if asset is None:
            raise NotFoundError("Content asset not found")
        mime_type = asset.mime_type or "application/octet-stream"
        url = f"{settings.api_v1_prefix}/uploads/assets/{asset.id}"
        expires_at = None
        try:
            storage = self.storage_client.for_backend(asset.storage_backend)
            size = await storage.file_size(asset.storage_key)
            digest = asset.sha256
            if digest is None:
                original = await storage.read_file(asset.storage_key)
                size = len(original)
                digest = hashlib.sha256(original).hexdigest()
            if isinstance(storage, S3StorageClient):
                url = await storage.download_url(
                    asset.storage_key, mime_type=mime_type, expires_in=120,
                )
                expires_at = datetime.now(UTC) + timedelta(seconds=120)
        except FileNotFoundError as exc:
            raise NotFoundError("Content asset not found") from exc
        except OSError as exc:
            raise ServiceUnavailableError("Image storage is temporarily unavailable") from exc
        if self.image_storage_control is not None:
            await self.image_storage_control.observe(
                "direct_access_grant" if expires_at else "proxy_access_grant", commit=True,
            )
        return ContentAssetAccess(
            asset_id=asset.id, mode="direct" if expires_at else "proxy", url=url,
            expires_at=expires_at, mime_type=mime_type, size_bytes=size, sha256=digest,
        )

    async def read_asset(self, *, user_id: int, asset_id: int) -> StoredAssetFile:
        asset = await self.content_asset_repository.get_owned(
            user_id=user_id,
            asset_id=asset_id,
        )
        if asset is None:
            raise NotFoundError("Content asset not found")

        try:
            content = await self.storage_client.read_file(
                asset.storage_key, backend=asset.storage_backend,
            )
        except FileNotFoundError as exc:
            logger.error("Stored content asset is missing: asset_id=%s", asset.id)
            raise NotFoundError("Content asset not found") from exc
        except StorageUnavailableError as exc:
            raise ServiceUnavailableError("Image storage is temporarily unavailable") from exc

        if self.image_storage_control is not None:
            await self.image_storage_control.observe("proxy_download", len(content), commit=True)
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
                with Image.open(BytesIO(content)) as image:
                    image.load()
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
