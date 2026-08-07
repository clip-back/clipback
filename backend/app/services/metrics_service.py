from fastapi import HTTPException, status

from app.core.exceptions import NotFoundError
from app.models.content import ContentType
from app.models.content_event import ContentEventType
from app.repositories.category_repository import CategoryRepository
from app.repositories.content_repository import ContentRepository
from app.repositories.event_repository import EventRepository
from app.schemas.metrics import (
    CardClickedEventCreate,
    CategoryFilterUsedEventCreate,
    MetricEventCreate,
    MetricEventRead,
    MetricEventType,
    OriginalLinkOpenedEventCreate,
)


class MetricsService:
    def __init__(
        self,
        *,
        event_repository: EventRepository,
        content_repository: ContentRepository,
        category_repository: CategoryRepository,
    ) -> None:
        self.event_repository = event_repository
        self.content_repository = content_repository
        self.category_repository = category_repository

    async def record_event(
        self,
        *,
        user_id: int,
        payload: MetricEventCreate,
    ) -> MetricEventRead:
        try:
            content_id, category_id = await self._validate_target(
                user_id=user_id,
                payload=payload,
            )
            event = await self.event_repository.create(
                user_id=user_id,
                event_type=ContentEventType(payload.event_type.value),
                content_id=content_id,
                category_id=category_id,
                metadata_json=None,
            )
            response = MetricEventRead(
                id=event.id,
                event_type=MetricEventType(event.event_type.value),
                created_at=event.created_at,
            )
            await self.event_repository.session.commit()
        except Exception:
            await self.event_repository.session.rollback()
            raise

        return response

    async def _validate_target(
        self,
        *,
        user_id: int,
        payload: MetricEventCreate,
    ) -> tuple[int | None, int | None]:
        if isinstance(payload, CategoryFilterUsedEventCreate):
            await self._get_available_category(user_id=user_id, category_id=payload.category_id)
            return None, payload.category_id

        content = await self.content_repository.get_owned(
            user_id=user_id,
            content_id=payload.content_id,
        )
        if content is None:
            raise NotFoundError("Content not found")

        if isinstance(payload, CardClickedEventCreate):
            if payload.category_id is not None:
                await self._get_available_category(
                    user_id=user_id,
                    category_id=payload.category_id,
                )
                if payload.category_id not in {category.id for category in content.categories}:
                    raise HTTPException(
                        status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                        detail="Category is not assigned to content",
                    )
            return content.id, payload.category_id

        if isinstance(payload, OriginalLinkOpenedEventCreate):
            if content.content_type != ContentType.LINK or content.original_url is None:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                    detail="Original link is not available for content",
                )
            return content.id, None

        raise TypeError("Unsupported metric event payload")

    async def _get_available_category(self, *, user_id: int, category_id: int) -> None:
        categories = await self.category_repository.list_available_by_ids(
            user_id=user_id,
            category_ids=[category_id],
        )
        if not categories:
            raise NotFoundError("Category not found")
