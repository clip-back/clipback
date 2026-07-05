from app.schemas.feed import FeedResponse
from app.services.content_service import ContentService


class FeedService:
    async def read_placeholder(
        self,
        category_id: int | None,
        limit: int,
        cursor: str | None,
    ) -> FeedResponse:
        content = await ContentService().read_placeholder(content_id=1)
        return FeedResponse(items=[content], next_cursor=None if limit else cursor)
