from datetime import datetime
from uuid import UUID

from sqlalchemy import RowMapping, func, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.content_event import ContentEvent, ContentEventType


class EventRepository:
    """Data access for product metric events."""

    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def read_user_stats(self, user_id: int) -> RowMapping:
        result = await self.session.execute(
            select(
                func.count(ContentEvent.id)
                .filter(ContentEvent.event_type == ContentEventType.CONTENT_CREATED)
                .label("saved_count"),
                func.count(ContentEvent.id)
                .filter(ContentEvent.event_type == ContentEventType.CONTENT_REOPENED)
                .label("reopened_count"),
            ).where(ContentEvent.user_id == user_id)
        )
        return result.mappings().one()

    async def create(
        self,
        *,
        user_id: int,
        event_type: ContentEventType,
        content_id: int | None = None,
        category_id: int | None = None,
        metadata_json: str | None = None,
        client_event_id: UUID | None = None,
        category_ids_at_event: list[int] | None = None,
        recommendation_item_id: int | None = None,
        created_at: datetime | None = None,
    ) -> ContentEvent:
        event = ContentEvent(
            user_id=user_id,
            content_id=content_id,
            category_id=category_id,
            event_type=event_type,
            metadata_json=metadata_json,
            client_event_id=client_event_id,
            category_ids_at_event=category_ids_at_event,
            recommendation_item_id=recommendation_item_id,
        )
        if created_at is not None:
            event.created_at = created_at
        self.session.add(event)
        await self.session.flush()
        await self.session.refresh(event)
        return event

    async def get_by_client_event_id(
        self, *, user_id: int, client_event_id: UUID
    ) -> ContentEvent | None:
        return await self.session.scalar(
            select(ContentEvent).where(
                ContentEvent.user_id == user_id,
                ContentEvent.client_event_id == client_event_id,
            )
        )

    async def create_reopened_once(
        self,
        *,
        user_id: int,
        content_id: int,
        client_event_id: UUID,
        category_ids_at_event: list[int],
        recommendation_item_id: int | None,
        created_at: datetime,
    ) -> ContentEvent | None:
        return await self.session.scalar(
            insert(ContentEvent)
            .values(
                user_id=user_id,
                content_id=content_id,
                event_type=ContentEventType.CONTENT_REOPENED,
                client_event_id=client_event_id,
                category_ids_at_event=category_ids_at_event,
                recommendation_item_id=recommendation_item_id,
                created_at=created_at,
            )
            .on_conflict_do_nothing(constraint="uq_content_events_user_client_event")
            .returning(ContentEvent)
        )
