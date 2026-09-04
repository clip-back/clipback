import unicodedata

from fastapi import HTTPException

from app.repositories.content_repository import ContentRepository
from app.schemas.feed import FeedResponse
from app.services.content_service import content_to_read


class FeedService:
    def __init__(self, content_repository: ContentRepository) -> None:
        self.content_repository = content_repository

    async def read_feed(
        self,
        user_id: int,
        category_id: int | None,
        limit: int,
        cursor: str | None,
        is_favorite: bool | None = None,
        query: str | None = None,
    ) -> FeedResponse:
        cursor_id = self._parse_cursor(cursor)
        search_query = self._normalize_search_query(query)
        contents = await self.content_repository.list_feed(
            user_id=user_id,
            category_id=category_id,
            is_favorite=is_favorite,
            search_query=search_query,
            cursor_id=cursor_id,
            limit=limit + 1,
        )
        has_next_page = len(contents) > limit
        visible_contents = contents[:limit]

        next_cursor = None
        if has_next_page and visible_contents:
            next_cursor = str(visible_contents[-1].id)

        return FeedResponse(
            items=[content_to_read(content) for content in visible_contents],
            next_cursor=next_cursor,
        )

    @staticmethod
    def _parse_cursor(cursor: str | None) -> int | None:
        if cursor is None:
            return None
        try:
            return int(cursor)
        except ValueError as exc:
            raise HTTPException(
                status_code=422,
                detail="cursor must be a numeric content id",
            ) from exc

    @staticmethod
    def _normalize_search_query(query: str | None) -> str | None:
        if query is None:
            return None
        normalized = unicodedata.normalize("NFKC", query).strip()
        return normalized or None
