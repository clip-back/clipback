from datetime import date, datetime
from uuid import UUID

from sqlalchemy import Integer, and_, any_, cast, func, or_, select
from sqlalchemy.dialects.postgresql import ARRAY, insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.category import Category
from app.models.content import Content
from app.models.content_category import content_categories
from app.models.content_event import ContentEvent, ContentEventType
from app.models.recommendation import (
    RecommendationBatch,
    RecommendationBatchItem,
    RecommendationExposure,
    RecommendationTargetKind,
    RecommendationType,
)
from app.models.user import User
from app.schemas.category import CategorySummaryRead
from app.schemas.recommendation import TodaySelection, WeeklyCandidate, WeeklySelection


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

    async def get_exposure_by_client_event_id(
        self, *, user_id: int, client_event_id: UUID
    ) -> RecommendationExposure | None:
        return await self.session.scalar(
            select(RecommendationExposure).where(
                RecommendationExposure.user_id == user_id,
                RecommendationExposure.client_event_id == client_event_id,
            )
        )

    async def create_exposure_once(
        self,
        *,
        user_id: int,
        client_event_id: UUID,
        recommendation_item_id: int,
        recommended_at: datetime,
    ) -> RecommendationExposure | None:
        return await self.session.scalar(
            insert(RecommendationExposure)
            .values(
                user_id=user_id,
                client_event_id=client_event_id,
                recommendation_item_id=recommendation_item_id,
                recommended_at=recommended_at,
            )
            .on_conflict_do_nothing(constraint="uq_recommendation_exposures_user_client_event")
            .returning(RecommendationExposure)
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

    async def list_weekly_candidates(
        self, *, user_id: int, content_ids: list[int], start: datetime, end: datetime
    ) -> list[WeeklyCandidate]:
        if not content_ids:
            return []
        # A concurrent save can commit while we hold SHARE locks on existing rows.
        # Use one array bind to keep every aggregate within the captured content set.
        captured_content = Content.id == any_(cast(content_ids, ARRAY(Integer)))
        categories = (await self.session.execute(
            select(
                Category.id, Category.name, Category.color, Category.is_default,
                func.count(Content.id).label("content_count"),
                func.max(Content.saved_at).label("last_saved_at"),
            )
            .join(content_categories, content_categories.c.category_id == Category.id)
            .join(Content, Content.id == content_categories.c.content_id)
            .where(
                Category.user_id == user_id,
                Category.name != "미분류",
                Content.user_id == user_id,
                captured_content,
            )
            .group_by(Category.id)
            .order_by(Category.id)
        )).mappings().all()
        if not categories:
            return []
        candidate_category = Category.id == any_(
            cast([category["id"] for category in categories], ARRAY(Integer))
        )
        created = ContentEvent.event_type == ContentEventType.CONTENT_CREATED
        reopened = ContentEvent.event_type == ContentEventType.CONTENT_REOPENED
        activities = await self.session.execute(
            select(
                Category.id.label("category_id"),
                func.count(ContentEvent.id).filter(created).label("saved_count"),
                func.max(ContentEvent.created_at).filter(created).label("last_saved_event_at"),
                func.count(func.distinct(ContentEvent.content_id))
                .filter(reopened).label("viewed_count"),
                func.max(ContentEvent.created_at).filter(reopened).label("last_viewed_event_at"),
            )
            .select_from(ContentEvent)
            .join(Content, Content.id == ContentEvent.content_id)
            # ANY tests membership without multiplying duplicate IDs inside a snapshot.
            .join(Category, Category.id == any_(ContentEvent.category_ids_at_event))
            .where(
                ContentEvent.user_id == user_id,
                Content.user_id == user_id,
                Category.user_id == user_id,
                captured_content,
                candidate_category,
                ContentEvent.event_type.in_([
                    ContentEventType.CONTENT_CREATED, ContentEventType.CONTENT_REOPENED,
                ]),
                ContentEvent.created_at >= start,
                ContentEvent.created_at < end,
            )
            .group_by(Category.id)
        )
        activity_by_id = {row.category_id: row for row in activities}
        # Keep raw exposure rows separate from event rows to avoid a cross product.
        exposures = await self.session.execute(
            select(Category.id, func.max(RecommendationExposure.recommended_at))
            .select_from(RecommendationExposure)
            .join(RecommendationBatchItem,
                  RecommendationBatchItem.id == RecommendationExposure.recommendation_item_id)
            .join(RecommendationBatch, RecommendationBatch.id == RecommendationBatchItem.batch_id)
            .join(Category, Category.id == RecommendationBatchItem.category_id)
            .where(
                RecommendationExposure.user_id == user_id,
                RecommendationBatch.user_id == user_id,
                Category.user_id == user_id,
                candidate_category,
                RecommendationBatch.type == RecommendationType.WEEKLY_PICK,
                RecommendationBatchItem.target_kind == RecommendationTargetKind.CATEGORY,
                RecommendationExposure.recommended_at >= start,
                RecommendationExposure.recommended_at < end,
            )
            .group_by(Category.id)
        )
        last_exposed_by_id = dict(exposures.all())
        candidates = []
        for category in categories:
            activity = activity_by_id.get(category["id"])
            candidates.append(WeeklyCandidate(
                category=CategorySummaryRead.model_validate(category),
                saved_count=activity.saved_count if activity else 0,
                last_saved_event_at=activity.last_saved_event_at if activity else None,
                viewed_count=activity.viewed_count if activity else 0,
                last_viewed_event_at=activity.last_viewed_event_at if activity else None,
                last_exposed_at=last_exposed_by_id.get(category["id"]),
            ))
        return candidates

    async def create_weekly_batch(
        self, *, user_id: int, generated_at: datetime, selections: list[WeeklySelection]
    ) -> tuple[RecommendationBatch, list[RecommendationBatchItem]]:
        batch = RecommendationBatch(
            user_id=user_id, type=RecommendationType.WEEKLY_PICK,
            recommendation_date=None, generated_at=generated_at,
        )
        self.session.add(batch)
        await self.session.flush()
        items = [
            RecommendationBatchItem(
                batch_id=batch.id, rank=rank,
                target_kind=RecommendationTargetKind.CATEGORY,
                target_id_snapshot=selection.category_id,
                category_id=selection.category_id,
                card_type=selection.card_type,
            )
            for rank, selection in enumerate(selections, start=1)
        ]
        self.session.add_all(items)
        await self.session.flush()
        return batch, items

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
