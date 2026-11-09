"""콘텐츠 저장 흐름: 일반 링크·공유 링크·스크린샷의 새 콘텐츠 저장 트랜잭션을 맡는다.

같은 제출 키의 잠금과 기존 결과 확인, 저장 확정(commit/rollback),
실패한 스크린샷 원본의 정리 판단을 이 module이 정한다(ADR 0010).
URL 해석·OCR·원본 쓰기와 저장할 내용의 준비·DB 반영은 기존 서비스가 한다.
"""

import hashlib
import json
import logging
from dataclasses import dataclass
from uuid import UUID

from fastapi import HTTPException, UploadFile

from app.core.exceptions import ServiceUnavailableError
from app.integrations.ocr_client import ScreenshotOCRResult
from app.integrations.storage_client import StorageUnavailableError
from app.repositories.content_repository import ContentRepository
from app.repositories.share_receipt_repository import PendingShareReceipt, ShareReceiptRepository
from app.schemas.content import ContentCreate, ContentRead, ContentShareCreate
from app.services.content_service import (
    ContentService,
    PendingContentAsset,
    PreparedContent,
    SharedLinkContext,
    content_to_read,
)
from app.services.image_deletion_service import cleanup_failed_upload
from app.services.share_intake_service import ShareIntakeService
from app.services.upload_service import ScreenshotOriginal, UploadService

logger = logging.getLogger(__name__)


def share_fingerprint(fields: dict, image: bytes | None = None) -> str:
    encoded = json.dumps(fields, sort_keys=True, ensure_ascii=False, separators=(",", ":"))
    digest = hashlib.sha256(encoded.encode())
    if image is not None:
        digest.update(b"\0")
        digest.update(image)
    return digest.hexdigest()


@dataclass
class _Submission:
    """제출 키가 있는 이번 저장 시도. 이 module 밖으로 내보내지 않는다."""

    receipt: PendingShareReceipt
    commit_attempted: bool = False


class ContentSaveFlow:
    def __init__(
        self,
        content_service: ContentService,
        *,
        share_intake: ShareIntakeService | None = None,
        uploads: UploadService | None = None,
    ) -> None:
        self.content_service = content_service
        self.session = content_service.content_repository.session
        self.share_intake = share_intake
        self.uploads = uploads

    async def save_link(
        self, *, user_id: int, payload: ContentCreate, idempotency_key: UUID | None = None,
    ) -> ContentRead:
        submission = None
        if idempotency_key is not None:
            submission, replay = await self._begin(
                user_id=user_id, key=idempotency_key, kind="content",
                fingerprint=share_fingerprint(payload.model_dump(mode="json")),
            )
            if replay is not None:
                return replay
        return await self.save_prepared_link(
            user_id=user_id, payload=payload, submission=submission,
        )

    async def save_shared_link(
        self, *, user_id: int, payload: ContentShareCreate, idempotency_key: UUID | None = None,
    ) -> ContentRead:
        submission = None
        if idempotency_key is not None:
            submission, replay = await self._begin(
                user_id=user_id, key=idempotency_key, kind="link",
                fingerprint=share_fingerprint(payload.model_dump(mode="json")),
            )
            if replay is not None:
                return replay
        content_payload, share = await self.share_intake.prepare_link(payload)
        return await self.save_prepared_link(
            user_id=user_id, payload=content_payload, share=share, submission=submission,
        )

    async def save_prepared_link(
        self,
        *,
        user_id: int,
        payload: ContentCreate,
        share: SharedLinkContext | None = None,
        submission: _Submission | None = None,
    ) -> ContentRead:
        """준비된 링크 입력을 그대로 저장하고 확정한다. 입력을 다시 검증하지 않는다."""
        prepared = await self.content_service.prepare_link(
            user_id=user_id, payload=payload, share=share,
        )
        return await self._commit(prepared, submission)

    async def save_screenshot(
        self,
        *,
        user_id: int,
        file: UploadFile,
        category_ids: list[int],
        tag_names: list[str] | None = None,
        idempotency_key: UUID | None = None,
    ) -> ContentRead:
        content = await self.uploads.read_screenshot(file)
        submission = None
        if idempotency_key is not None:
            submission, replay = await self._begin(
                user_id=user_id, key=idempotency_key, kind="screenshot",
                fingerprint=share_fingerprint(
                    {"category_ids": category_ids, "tag_names": tag_names or []}, content,
                ),
            )
            if replay is not None:
                return replay

        original = await self.uploads.prepare_original(user_id=user_id, content=content)
        try:
            await self.uploads.save_original(original)
        except StorageUnavailableError as exc:
            await self._cleanup_failed_original(user_id, original)
            raise ServiceUnavailableError("Image storage is temporarily unavailable") from exc

        try:
            await self.uploads.observe_saved_original(original)
            return await self.save_prepared_screenshot(
                user_id=user_id,
                category_ids=category_ids,
                tag_names=tag_names or [],
                ocr=original.ocr,
                ocr_metadata=original.ocr_metadata,
                asset=self.uploads.asset_for(original),
                submission=submission,
            )
        except Exception:
            # _commit이 원 트랜잭션을 rollback한 뒤에만 별도 연결로 같은 잠금을 다시 잡는다.
            if submission is not None and submission.commit_attempted:
                try:
                    committed = await ShareReceiptRepository(
                        self.session,
                    ).committed_after_failure(submission.receipt)
                except Exception:
                    # Retain an uncertain file rather than delete a committed asset.
                    logger.exception("Unable to verify screenshot commit; retaining file")
                    raise
                if committed:
                    raise
            await self._cleanup_failed_original(user_id, original)
            raise

    async def save_prepared_screenshot(
        self,
        *,
        user_id: int,
        category_ids: list[int],
        tag_names: list[str],
        ocr: ScreenshotOCRResult,
        ocr_metadata: dict[str, str | None],
        asset: PendingContentAsset,
        submission: _Submission | None = None,
    ) -> ContentRead:
        """저장한 원본과 OCR 결과를 그대로 받아 스크린샷 콘텐츠를 저장하고 확정한다."""
        prepared = await self.content_service.prepare_screenshot(
            user_id=user_id, category_ids=category_ids, tag_names=tag_names,
            ocr=ocr, ocr_metadata=ocr_metadata, asset=asset,
        )
        return await self._commit(prepared, submission)

    async def _begin(
        self, *, user_id: int, key: UUID, kind: str, fingerprint: str,
    ) -> tuple[_Submission, ContentRead | None]:
        pending = PendingShareReceipt(user_id, key, kind, fingerprint)
        receipt = await ShareReceiptRepository(self.session).begin(pending)
        if receipt is None:
            return _Submission(pending), None
        if receipt.kind != pending.kind or receipt.fingerprint != pending.fingerprint:
            raise HTTPException(status_code=409, detail="Idempotency key belongs to another input")
        content = await ContentRepository(self.session).get_owned(
            user_id=user_id, content_id=receipt.content_id,
        )
        if content is None:
            raise HTTPException(status_code=410, detail="Previously saved content was deleted")
        return _Submission(pending), content_to_read(content)

    async def _commit(
        self, prepared: PreparedContent, submission: _Submission | None,
    ) -> ContentRead:
        try:
            response = await self.content_service.write(prepared)
            if submission is not None:
                self.session.add(submission.receipt.for_content(response.id))
                await self.session.flush()
                submission.commit_attempted = True
            await self.session.commit()
        except Exception:
            await self.session.rollback()
            raise
        return response

    async def _cleanup_failed_original(self, user_id: int, original: ScreenshotOriginal) -> None:
        try:
            await cleanup_failed_upload(
                self.session, self.uploads.storage_client,
                user_id=user_id, storage_key=original.storage_key,
                size_bytes=len(original.content),
                sha256=hashlib.sha256(original.content).hexdigest(),
            )
        except Exception:
            # Combined DB+object-store failure cannot queue here. The upload still fails.
            logger.warning("Failed upload original cleanup could not be confirmed")
