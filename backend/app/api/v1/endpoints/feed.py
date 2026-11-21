from typing import Annotated

from fastapi import APIRouter, Query
from pydantic import AfterValidator

from app.api.deps import CurrentUserId, DatabaseSession
from app.repositories.content_repository import ContentRepository
from app.schemas.feed import MAX_FEED_CURSOR_LENGTH, FeedResponse, FeedSort
from app.schemas.text import reject_unstorable_text
from app.services.feed_service import FeedService

router = APIRouter()


@router.get("", response_model=FeedResponse)
async def read_feed(
    db: DatabaseSession,
    current_user_id: CurrentUserId,
    q: Annotated[
        str | None, Query(max_length=100), AfterValidator(reject_unstorable_text)
    ] = None,
    category_id: int | None = Query(default=None),
    is_favorite: bool | None = Query(default=None),
    sort: FeedSort = Query(default="latest"),
    limit: int = Query(default=20, ge=1, le=100),
    cursor: str | None = Query(default=None, max_length=MAX_FEED_CURSOR_LENGTH),
) -> FeedResponse:
    return await FeedService(content_repository=ContentRepository(db)).read_feed(
        user_id=current_user_id,
        query=q,
        category_id=category_id,
        is_favorite=is_favorite,
        limit=limit,
        cursor=cursor,
        sort=sort,
    )
