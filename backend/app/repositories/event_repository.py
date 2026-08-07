from sqlalchemy.ext.asyncio import AsyncSession

from app.models.content_event import ContentEvent, ContentEventType


class EventRepository:
    """Data access for product metric events."""

    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def create(
        self,
        *,
        user_id: int,
        event_type: ContentEventType,
        content_id: int | None = None,
        category_id: int | None = None,
        metadata_json: str | None = None,
    ) -> ContentEvent:
        event = ContentEvent(
            user_id=user_id,
            content_id=content_id,
            category_id=category_id,
            event_type=event_type,
            metadata_json=metadata_json,
        )
        self.session.add(event)
        await self.session.flush()
        await self.session.refresh(event)
        return event
