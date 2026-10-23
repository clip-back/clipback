import hashlib
import json
import logging
import warnings
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from enum import StrEnum
from io import BytesIO
from uuid import UUID, uuid4

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
from app.repositories.share_receipt_repository import ShareReceiptRepository
from app.schemas.content import (
    ContentAssetAccess,
    ContentCreate,
    ContentRead,
    ContentSource,
    ContentType,
)
from app.services.content_service import ContentService, PendingContentAsset
from app.services.image_deletion_service import cleanup_failed_upload
from app.services.share_receipt_service import prepare_share_write, share_fingerprint

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
        storage_client: StorageRouter,
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
        idempotency_key: UUID | None = None,
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

        pending = None
        receipt_args = {}
        if idempotency_key is not None:
            pending, replay = await prepare_share_write(
                self.content_service.content_repository.session, user_id=user_id,
                key=idempotency_key, kind="screenshot",
                fingerprint=share_fingerprint(
                    {"category_ids": category_ids, "tag_names": tag_names or []}, content,
                ),
            )
            if replay is not None:
                return replay
            receipt_args["share_receipt"] = pending

        mime_type, extension = self._validate_image(content)
        ocr_result, ocr_metadata = await self._extract_ocr(
            content=content,
            mime_type=mime_type,
        )
        storage_key = f"screenshots/{user_id}/{uuid4().hex}.{extension}"
        try:
            await self.storage_client.save_file(storage_key, content)
        except StorageUnavailableError as exc:
            await self._cleanup_failed_original(user_id, storage_key, content)
            raise ServiceUnavailableError("Image storage is temporarily unavailable") from exc

        try:
            return await self.content_service.create_content(
                **receipt_args,
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
                    storage_backend=self.storage_client.backend,
                    size_bytes=len(content),
                    sha256=hashlib.sha256(content).hexdigest(),
                ),
            )
        except Exception:
            if pending is not None and pending.commit_attempted:
                try:
                    committed = await ShareReceiptRepository(
                        self.content_service.content_repository.session,
                    ).committed_after_failure(pending)
                except Exception:
                    # Retain an uncertain file rather than delete a committed asset.
                    logger.exception("Unable to verify screenshot commit; retaining file")
                    raise
                if committed:
                    raise
            await self._cleanup_failed_original(user_id, storage_key, content)
            raise

    async def _cleanup_failed_original(
        self, user_id: int, storage_key: str, content: bytes,
    ) -> None:
        try:
            await cleanup_failed_upload(
                self.content_asset_repository.session, self.storage_client,
                user_id=user_id, storage_key=storage_key, size_bytes=len(content),
                sha256=hashlib.sha256(content).hexdigest(),
            )
        except Exception:
            # Combined DB+object-store failure cannot queue here. The upload still fails.
            logger.warning("Failed upload original cleanup could not be confirmed")

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
        url = f"/api/v1/uploads/assets/{asset.id}"
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
