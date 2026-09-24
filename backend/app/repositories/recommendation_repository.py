from datetime import date, datetime

from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.category import Category
from app.models.content import Content
from app.models.recommendation import (
    RecommendationBatch,
    RecommendationBatchItem,
    RecommendationExposure,
    RecommendationTargetKind,
    RecommendationType,
)
from app.models.user import User
from app.schemas.recommendation import TodaySelection


class RecommendationRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def lock_user(self, user_id: int) -> None:
        # NO KEY UPDATE is compatible with existing content/event FK KEY SHARE locks.
        await self.session.execute(
            select(User.id).where(User.id == user_id).with_for_update(key_share=True)
        )

    async def get_today_batch(
        self, *, user_id: int, recommendation_date: date
    ) -> RecommendationBatch | None:
        return await self.session.scalar(
            select(RecommendationBatch).where(
                RecommendationBatch.user_id == user_id,
                RecommendationBatch.type == RecommendationType.TODAY,
                RecommendationBatch.recommendation_date == recommendation_date,
            )
        )

    async def list_content_items(
        self, *, user_id: int, batch_id: int
    ) -> list[RecommendationBatchItem]:
        result = await self.session.scalars(
            select(RecommendationBatchItem)
            .join(RecommendationBatch, RecommendationBatch.id == RecommendationBatchItem.batch_id)
            .join(Content, Content.id == RecommendationBatchItem.content_id)
            .where(
                RecommendationBatch.id == batch_id,
                RecommendationBatch.user_id == user_id,
                Content.user_id == user_id,
                RecommendationBatchItem.target_kind == RecommendationTargetKind.CONTENT,
            )
            .order_by(RecommendationBatchItem.rank)
            .execution_options(populate_existing=True)
        )
        return list(result)

    async def exposed_content_ids(
        self, *, user_id: int, start: datetime, end: datetime
    ) -> set[int]:
        result = await self.session.scalars(
            select(RecommendationBatchItem.content_id)
            .join(
                RecommendationExposure,
                RecommendationExposure.recommendation_item_id == RecommendationBatchItem.id,
            )
            .join(RecommendationBatch, RecommendationBatch.id == RecommendationBatchItem.batch_id)
            .join(Content, Content.id == RecommendationBatchItem.content_id)
            .where(
                RecommendationExposure.user_id == user_id,
                RecommendationBatch.user_id == user_id,
                Content.user_id == user_id,
                RecommendationBatchItem.target_kind == RecommendationTargetKind.CONTENT,
                RecommendationExposure.recommended_at >= start,
                RecommendationExposure.recommended_at < end,
            )
            .distinct()
        )
        return set(result)

    async def create_today_batch(
        self,
        *,
        user_id: int,
        recommendation_date: date,
        generated_at: datetime,
        selections: list[TodaySelection],
    ) -> RecommendationBatch:
        batch = RecommendationBatch(
            user_id=user_id,
            type=RecommendationType.TODAY,
            recommendation_date=recommendation_date,
            generated_at=generated_at,
        )
        self.session.add(batch)
        await self.session.flush()
        self.session.add_all([
            RecommendationBatchItem(
                batch_id=batch.id,
                rank=rank,
                target_kind=RecommendationTargetKind.CONTENT,
                target_id_snapshot=selection.content_id,
                content_id=selection.content_id,
                score=selection.score,
            )
            for rank, selection in enumerate(selections, start=1)
        ])
        await self.session.flush()
        return batch

    async def get_owned_item(
        self, *, user_id: int, item_id: int
    ) -> tuple[RecommendationBatchItem, RecommendationType] | None:
        result = await self.session.execute(
            select(RecommendationBatchItem, RecommendationBatch.type)
            .join(RecommendationBatch, RecommendationBatch.id == RecommendationBatchItem.batch_id)
            .outerjoin(Content, Content.id == RecommendationBatchItem.content_id)
            .outerjoin(Category, Category.id == RecommendationBatchItem.category_id)
            .where(
                RecommendationBatchItem.id == item_id,
                RecommendationBatch.user_id == user_id,
                or_(
                    and_(
                        RecommendationBatchItem.target_kind == RecommendationTargetKind.CONTENT,
                        or_(
                            RecommendationBatchItem.content_id.is_(None), Content.user_id == user_id
                        ),
                    ),
                    and_(
                        RecommendationBatchItem.target_kind == RecommendationTargetKind.CATEGORY,
                        or_(
                            RecommendationBatchItem.category_id.is_(None),
                            Category.user_id == user_id,
                        ),
                    ),
                ),
            )
        )
        row = result.first()
        return (row[0], row[1]) if row is not None else None
