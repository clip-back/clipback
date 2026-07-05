from fastapi import APIRouter, Query

from app.schemas.feed import FeedResponse
from app.services.feed_service import FeedService

router = APIRouter()


@router.get("", response_model=FeedResponse)
async def read_feed(
    category_id: int | None = Query(default=None),
    limit: int = Query(default=20, ge=1, le=100),
    cursor: str | None = Query(default=None),
) -> FeedResponse:
    return await FeedService().read_placeholder(
        category_id=category_id,
        limit=limit,
        cursor=cursor,
    )

