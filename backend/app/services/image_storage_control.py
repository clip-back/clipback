from datetime import UTC, datetime

from fastapi import HTTPException
from sqlalchemy import func, select, text
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.image_storage_control import ImageStorageControl, ImageTransferCounter

UPLOAD_CONTROL_LOCK = 74264004
TRANSFER_KINDS = (
    "original_upload_local",
    "original_upload_s3",
    "proxy_download",
    "direct_access_grant",
    "proxy_access_grant",
)


class ImageUploadControl:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def authorize(self) -> None:
        # Shared until the content commit/rollback: pause waits for already admitted saves.
        await self.session.execute(
            text("SELECT pg_advisory_xact_lock_shared(:key)"),
            {"key": UPLOAD_CONTROL_LOCK},
        )
        if await self.session.scalar(
            select(ImageStorageControl.uploads_paused).where(
                ImageStorageControl.id == 1,
            )
        ):
            raise HTTPException(
                status_code=409,
                detail={
                    "code": "image_uploads_paused",
                    "message": "이미지 저장이 일시 중단되었어요. 잠시 후 다시 시도해 주세요.",
                },
            )

    async def observe(self, kind: str, size_bytes: int = 0, *, commit: bool = False) -> None:
        """Count acknowledged application payloads, never provider/network billing bytes."""
        if kind not in TRANSFER_KINDS or size_bytes < 0:
            raise ValueError("Invalid image transfer observation")
        statement = insert(ImageTransferCounter).values(
            day=datetime.now(UTC).date(),
            kind=kind,
            operations=1,
            size_bytes=size_bytes,
        )
        await self.session.execute(
            statement.on_conflict_do_update(
                index_elements=[ImageTransferCounter.day, ImageTransferCounter.kind],
                set_={
                    "operations": ImageTransferCounter.operations + 1,
                    "size_bytes": ImageTransferCounter.size_bytes + size_bytes,
                },
            )
        )
        if commit:
            await self.session.commit()


async def set_uploads_paused(session: AsyncSession, paused: bool) -> None:
    """Wait for admitted uploads to commit, then atomically change admission policy."""
    await session.execute(text("SELECT pg_advisory_xact_lock(:key)"), {"key": UPLOAD_CONTROL_LOCK})
    await session.execute(
        insert(ImageStorageControl)
        .values(id=1, uploads_paused=paused)
        .on_conflict_do_update(
            index_elements=[ImageStorageControl.id],
            set_={"uploads_paused": paused, "updated_at": func.now()},
        )
    )
    await session.commit()
