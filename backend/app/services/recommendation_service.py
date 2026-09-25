import random
from collections.abc import Callable
from datetime import UTC, datetime, time, timedelta

from fastapi import HTTPException

from app.core.exceptions import InvalidStateError, NotFoundError
from app.core.recommendation_config import RECOMMENDATION_TIMEZONE, WEEKLY_WINDOW_DAYS
from app.models.recommendation import (
    RecommendationExposure,
    RecommendationTargetKind,
    RecommendationType,
)
from app.repositories.category_repository import CategoryRepository
from app.repositories.content_repository import ContentRepository
from app.repositories.recommendation_repository import RecommendationRepository
from app.schemas.recommendation import (
    RecommendationExposureCreate,
    RecommendationExposureRead,
    TodayRecommendationItem,
    TodayRecommendationResponse,
    WeeklyRecommendationItem,
    WeeklyRecommendationResponse,
)
from app.services.content_service import content_to_read
from app.services.recommendation_selection import get_stage, select_today, select_weekly


def utc_now() -> datetime:
    return datetime.now(UTC)


class RecommendationService:
    def __init__(
        self,
        content_repository: ContentRepository,
        recommendation_repository: RecommendationRepository,
        *,
        clock: Callable[[], datetime] | None = None,
        rng: random.Random | None = None,
    ) -> None:
        self.content_repository = content_repository
        self.recommendation_repository = recommendation_repository
        self.clock = clock or utc_now
        self.rng = rng or random.Random()

    async def record_exposure(
        self, user_id: int, payload: RecommendationExposureCreate
    ) -> RecommendationExposureRead:
        repository = self.recommendation_repository
        try:
            await repository.lock_user(user_id)
            exposure = await repository.get_exposure_by_client_event_id(
                user_id=user_id, client_event_id=payload.client_event_id
            )
            if exposure is not None:
                self._validate_exposure_retry(exposure, payload.recommendation_item_id)
            else:
                result = await repository.get_owned_item(
                    user_id=user_id, item_id=payload.recommendation_item_id
                )
                if result is None:
                    raise NotFoundError("Recommendation item not found")
                item, batch_type = result
                if item.content_id is None and item.category_id is None:
                    raise NotFoundError("Recommendation target not found")
                if (batch_type, item.target_kind) not in {
                    (RecommendationType.TODAY, RecommendationTargetKind.CONTENT),
                    (RecommendationType.WEEKLY_PICK, RecommendationTargetKind.CATEGORY),
                }:
                    raise HTTPException(
                        status_code=422, detail="Invalid recommendation target kind"
                    )

                # Lock the target before inserting its item's FK, matching deletion's order.
                content = None
                if item.target_kind == RecommendationTargetKind.CONTENT:
                    content = await self.content_repository.get_owned(
                        user_id=user_id, content_id=item.content_id, for_update=True
                    )
                    if content is None:
                        raise NotFoundError("Recommendation target not found")
                else:
                    category = await CategoryRepository(repository.session).get_owned_for_key_share(
                        user_id, item.category_id
                    )
                    if category is None:
                        raise NotFoundError("Recommendation target not found")

                recommended_at = self.clock().astimezone(UTC)
                exposure = await repository.create_exposure_once(
                    user_id=user_id,
                    client_event_id=payload.client_event_id,
                    recommendation_item_id=payload.recommendation_item_id,
                    recommended_at=recommended_at,
                )
                if exposure is None:
                    exposure = await repository.get_exposure_by_client_event_id(
                        user_id=user_id, client_event_id=payload.client_event_id
                    )
                    self._validate_exposure_retry(exposure, payload.recommendation_item_id)
                elif content is not None:
                    await self.content_repository.mark_recommended(
                        content, recommended_at=recommended_at, surface=batch_type
                    )

            response = RecommendationExposureRead(
                exposure_id=exposure.id,
                client_event_id=exposure.client_event_id,
                recommendation_item_id=exposure.recommendation_item_id,
                recommended_at=exposure.recommended_at,
            )
            await repository.session.commit()
            return response
        except Exception:
            await repository.session.rollback()
            raise

    @staticmethod
    def _validate_exposure_retry(
        exposure: RecommendationExposure | None, recommendation_item_id: int
    ) -> None:
        if exposure is None or exposure.recommendation_item_id != recommendation_item_id:
            raise InvalidStateError("Event ID is already used for a different request")

    async def read_weekly(self, user_id: int) -> WeeklyRecommendationResponse:
        repository = self.recommendation_repository
        try:
            await repository.lock_user(user_id)
            content_ids = await self.content_repository.list_owned_ids_for_share(user_id)
            now = self.clock().astimezone(UTC)
            start_date = now.astimezone(RECOMMENDATION_TIMEZONE).date() - timedelta(
                days=WEEKLY_WINDOW_DAYS - 1
            )
            start = datetime.combine(
                start_date, time.min, tzinfo=RECOMMENDATION_TIMEZONE
            ).astimezone(UTC)
            candidates = await repository.list_weekly_candidates(
                user_id=user_id, content_ids=content_ids, start=start, end=now
            )
            selections = select_weekly(candidates, rng=self.rng)
            batch = None
            items = []
            if selections:
                batch, saved_items = await repository.create_weekly_batch(
                    user_id=user_id, generated_at=now, selections=selections
                )
                category_by_id = {
                    candidate.category.id: candidate.category for candidate in candidates
                }
                items = [
                    WeeklyRecommendationItem(
                        recommendation_item_id=item.id,
                        rank=item.rank,
                        card_type=item.card_type,
                        category=category_by_id[item.category_id],
                    )
                    for item in saved_items
                ]
            response = WeeklyRecommendationResponse(
                period_start=start,
                period_end=now,
                batch_id=batch.id if batch is not None else None,
                generated_at=batch.generated_at if batch is not None else None,
                items=items,
            )
            await repository.session.commit()
            return response
        except Exception:
            await repository.session.rollback()
            raise

    async def read_today(self, user_id: int) -> TodayRecommendationResponse:
        repository = self.recommendation_repository
        try:
            await repository.lock_user(user_id)
            now = self.clock().astimezone(UTC)
            recommendation_date = now.astimezone(RECOMMENDATION_TIMEZONE).date()
            batch = await repository.get_today_batch(
                user_id=user_id, recommendation_date=recommendation_date
            )
            stage = get_stage(await self.content_repository.count_owned(user_id))
            if batch is None and stage > 0:
                candidates = await self.content_repository.list_today_candidates_for_share(user_id)
                # A writer may have held a content lock across midnight or deleted candidates.
                now = self.clock().astimezone(UTC)
                locked_date = now.astimezone(RECOMMENDATION_TIMEZONE).date()
                if locked_date != recommendation_date:
                    recommendation_date = locked_date
                    batch = await repository.get_today_batch(
                        user_id=user_id, recommendation_date=recommendation_date
                    )
                stage = get_stage(len(candidates))
                if batch is None and stage > 0:
                    exposed_yesterday = set()
                    if stage == 1:
                        midnight = datetime.combine(
                            recommendation_date, time.min, tzinfo=RECOMMENDATION_TIMEZONE
                        )
                        exposed_yesterday = await repository.exposed_content_ids(
                            user_id=user_id,
                            start=(midnight - timedelta(days=1)).astimezone(UTC),
                            end=midnight.astimezone(UTC),
                        )
                    selections = select_today(
                        candidates, now=now, exposed_yesterday=exposed_yesterday, rng=self.rng
                    )
                    if selections:
                        batch = await repository.create_today_batch(
                            user_id=user_id,
                            recommendation_date=recommendation_date,
                            generated_at=now,
                            selections=selections,
                        )

            items = []
            if batch is not None and stage > 0:
                saved_items = await repository.list_content_items(
                    user_id=user_id, batch_id=batch.id
                )
                contents = await self.content_repository.list_owned_by_ids(
                    user_id=user_id, content_ids=[item.content_id for item in saved_items]
                )
                content_by_id = {content.id: content for content in contents}
                items = [
                    TodayRecommendationItem(
                        recommendation_item_id=item.id,
                        rank=item.rank,
                        content=content_to_read(content_by_id[item.content_id]),
                    )
                    for item in saved_items
                    if item.content_id in content_by_id
                ]
            response = TodayRecommendationResponse(
                stage=stage,
                recommendation_date=recommendation_date,
                batch_id=batch.id if batch is not None else None,
                generated_at=batch.generated_at if batch is not None else None,
                items=items,
            )
            await repository.session.commit()
            return response
        except Exception:
            await repository.session.rollback()
            raise
