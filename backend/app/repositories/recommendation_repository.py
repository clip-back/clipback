from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.category import Category
from app.models.content import Content
from app.models.recommendation import (
    RecommendationBatch,
    RecommendationBatchItem,
    RecommendationTargetKind,
    RecommendationType,
)


class RecommendationRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

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
