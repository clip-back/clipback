from datetime import datetime

from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.usage_record import UsageRecord

AI_SUMMARY = "ai_summary"


class UsageRecordRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def count(
        self, user_id: int, *, kind: str, start: datetime, end: datetime,
    ) -> int:
        return await self.session.scalar(
            select(func.count()).select_from(UsageRecord).where(
                UsageRecord.user_id == user_id,
                UsageRecord.kind == kind,
                UsageRecord.recorded_at >= start,
                UsageRecord.recorded_at < end,
            )
        )

    async def add(
        self, *, user_id: int, kind: str, recorded_at: datetime, content_id: int | None,
        retain_from: datetime,
    ) -> None:
        await self.session.execute(delete(UsageRecord).where(
            UsageRecord.user_id == user_id,
            UsageRecord.recorded_at < retain_from,
        ))
        self.session.add(UsageRecord(
            user_id=user_id, kind=kind, recorded_at=recorded_at, content_id=content_id,
        ))

    async def release_summary(self, content_id: int) -> None:
        await self.session.execute(delete(UsageRecord).where(
            UsageRecord.content_id == content_id, UsageRecord.kind == AI_SUMMARY,
        ))
