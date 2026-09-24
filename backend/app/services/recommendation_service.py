import random
from collections.abc import Callable
from datetime import UTC, datetime, time, timedelta

from app.core.recommendation_config import RECOMMENDATION_TIMEZONE
from app.repositories.content_repository import ContentRepository
from app.repositories.recommendation_repository import RecommendationRepository
from app.schemas.recommendation import TodayRecommendationItem, TodayRecommendationResponse
from app.services.content_service import content_to_read
from app.services.recommendation_selection import get_stage, select_today


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
