from fastapi import APIRouter, Query

from app.api.deps import CurrentUserId, DatabaseSession
from app.repositories.content_repository import ContentRepository
from app.schemas.feed import FeedResponse
from app.services.feed_service import FeedService

router = APIRouter()


@router.get("", response_model=FeedResponse)
async def read_feed(
    db: DatabaseSession,
    current_user_id: CurrentUserId,
    category_id: int | None = Query(default=None),
    limit: int = Query(default=20, ge=1, le=100),
    cursor: str | None = Query(default=None),
) -> FeedResponse:
    return await FeedService(content_repository=ContentRepository(db)).read_feed(
        user_id=current_user_id,
        category_id=category_id,
        limit=limit,
        cursor=cursor,
    )
