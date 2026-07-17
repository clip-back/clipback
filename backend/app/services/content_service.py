from fastapi import HTTPException

from app.core.exceptions import NotFoundError
from app.models.content import (
    Content,
    ContentSource as ModelContentSource,
    ContentType as ModelContentType,
)
from app.models.content_event import ContentEventType
from app.repositories.category_repository import CategoryRepository
from app.repositories.content_repository import ContentRepository
from app.repositories.event_repository import EventRepository
from app.schemas.category import CategoryRead
from app.schemas.content import (
    ContentCreate,
    ContentRead,
    ContentSource,
    ContentType,
    ContentViewEvent,
)


DEFAULT_CONTENT_TITLE = "저장한 콘텐츠"
DEFAULT_CONTENT_SUMMARY = "요약 정보가 아직 없습니다."


def content_to_read(content: Content) -> ContentRead:
    return ContentRead(
        id=content.id,
        categories=[
            CategoryRead.model_validate(category)
            for category in sorted(content.categories, key=lambda item: item.id)
        ],
        content_type=ContentType(content.content_type.value),
        source=ContentSource(content.source.value),
        title=content.title,
        summary=content.summary,
        original_url=content.original_url,
        is_favorite=content.is_favorite,
        saved_at=content.saved_at,
        last_viewed_at=content.last_viewed_at,
    )


class ContentService:
    def __init__(
        self,
        content_repository: ContentRepository,
        category_repository: CategoryRepository,
        event_repository: EventRepository,
    ) -> None:
        self.content_repository = content_repository
        self.category_repository = category_repository
        self.event_repository = event_repository

    async def create_content(
        self,
        user_id: int,
        payload: ContentCreate,
        event_metadata_json: str | None = None,
    ) -> ContentRead:
        if payload.content_type == ContentType.LINK and payload.original_url is None:
            raise HTTPException(
                status_code=422,
                detail="original_url is required for link content",
            )

        category_ids = self._deduplicate_ids(payload.category_ids)
        if category_ids:
            categories = await self.category_repository.list_available_by_ids(
                user_id=user_id,
                category_ids=category_ids,
            )
            if len(categories) != len(category_ids):
                raise NotFoundError("Category not found")
            category_by_id = {category.id: category for category in categories}
            categories = [category_by_id[category_id] for category_id in category_ids]
        else:
            uncategorized = await self.category_repository.get_uncategorized()
            if uncategorized is None:
                raise NotFoundError("Uncategorized category not found")
            categories = [uncategorized]

        try:
            content = await self.content_repository.create(
                user_id=user_id,
                content_type=ModelContentType(payload.content_type.value),
                source=ModelContentSource(payload.source.value),
                title=self._normalize_text(payload.title, DEFAULT_CONTENT_TITLE),
                summary=self._normalize_text(payload.summary, DEFAULT_CONTENT_SUMMARY),
                original_url=str(payload.original_url) if payload.original_url else None,
                is_favorite=payload.is_favorite,
                categories=categories,
            )
            await self.event_repository.create(
                user_id=user_id,
                content_id=content.id,
                event_type=ContentEventType.CONTENT_CREATED,
                metadata_json=event_metadata_json,
            )
            content_id = content.id
            await self.content_repository.session.commit()
        except Exception:
            await self.content_repository.session.rollback()
            raise

        created_content = await self.content_repository.get_owned(
            user_id=user_id,
            content_id=content_id,
        )
        if created_content is None:
            raise NotFoundError("Content not found")
        return content_to_read(created_content)

    async def read_content(self, user_id: int, content_id: int) -> ContentRead:
        content = await self.content_repository.get_owned(user_id=user_id, content_id=content_id)
        if content is None:
            raise NotFoundError("Content not found")
        return content_to_read(content)

    async def record_view(self, user_id: int, content_id: int) -> ContentViewEvent:
        content = await self.content_repository.get_owned(user_id=user_id, content_id=content_id)
        if content is None:
            raise NotFoundError("Content not found")

        try:
            await self.content_repository.mark_viewed(content)
            await self.event_repository.create(
                user_id=user_id,
                content_id=content.id,
                event_type=ContentEventType.CONTENT_REOPENED,
            )
            await self.content_repository.session.commit()
        except Exception:
            await self.content_repository.session.rollback()
            raise

        return ContentViewEvent(
            content_id=content.id,
            event_type=ContentEventType.CONTENT_REOPENED.value,
        )

    @staticmethod
    def _deduplicate_ids(category_ids: list[int]) -> list[int]:
        return list(dict.fromkeys(category_ids))

    @staticmethod
    def _normalize_text(value: str | None, default: str) -> str:
        if value is None:
            return default
        normalized = value.strip()
        return normalized or default
