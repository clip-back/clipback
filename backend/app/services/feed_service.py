import base64
import json
import re
import unicodedata
from datetime import UTC, datetime

from fastapi import HTTPException

from app.repositories.content_repository import ContentRepository
from app.schemas.feed import MAX_FEED_CURSOR_LENGTH, FeedCursor, FeedResponse, FeedSort
from app.services.content_service import content_to_read

MAX_CONTENT_ID = 2_147_483_647


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
        sort: FeedSort = "latest",
    ) -> FeedResponse:
        feed_cursor = await self._parse_cursor(cursor, user_id=user_id, sort=sort)
        search_query = self._normalize_search_query(query)
        contents = await self.content_repository.list_feed(
            user_id=user_id,
            category_id=category_id,
            is_favorite=is_favorite,
            search_query=search_query,
            cursor=feed_cursor,
            limit=limit + 1,
            sort=sort,
        )
        has_next_page = len(contents) > limit
        visible_contents = contents[:limit]

        next_cursor = None
        if has_next_page and visible_contents:
            last = visible_contents[-1]
            next_cursor = self._encode_cursor(
                FeedCursor(
                    saved_at=last.saved_at,
                    id=last.id,
                    is_favorite=last.is_favorite if sort == "favorites_first" else None,
                )
            )

        total_count = await self.content_repository.count_feed(
            user_id=user_id,
            category_id=category_id,
            is_favorite=is_favorite,
            search_query=search_query,
        )
        return FeedResponse(
            total_count=total_count,
            items=[content_to_read(content) for content in visible_contents],
            next_cursor=next_cursor,
        )

    async def _parse_cursor(
        self, cursor: str | None, *, user_id: int, sort: FeedSort = "latest"
    ) -> FeedCursor | None:
        if cursor is None:
            return None
        invalid_cursor = HTTPException(status_code=422, detail="Invalid feed cursor")
        if len(cursor) > MAX_FEED_CURSOR_LENGTH:
            raise invalid_cursor

        if re.fullmatch(r"[0-9]+", cursor):
            if sort != "latest":
                raise invalid_cursor
            content_id = int(cursor)
            if not 1 <= content_id <= MAX_CONTENT_ID:
                raise invalid_cursor
            resolved = await self.content_repository.get_feed_cursor(
                user_id=user_id, content_id=content_id
            )
            if resolved is None:
                raise invalid_cursor
            return resolved

        try:
            prefix = "v1." if sort == "latest" else "f1."
            if not cursor.startswith(prefix):
                raise ValueError
            encoded = cursor[3:]
            if not re.fullmatch(r"[A-Za-z0-9_-]+", encoded):
                raise ValueError
            decoded = base64.b64decode(
                encoded + "=" * (-len(encoded) % 4), altchars=b"-_", validate=True
            )
            payload = json.loads(decoded.decode("utf-8"))
            keys = {"saved_at", "id"} if sort == "latest" else {"saved_at", "id", "is_favorite"}
            if not isinstance(payload, dict) or set(payload) != keys:
                raise ValueError
            if type(payload["id"]) is not int or not 1 <= payload["id"] <= MAX_CONTENT_ID:
                raise ValueError
            if not isinstance(payload["saved_at"], str):
                raise ValueError
            saved_at = datetime.fromisoformat(payload["saved_at"])
            if saved_at.utcoffset() is None:
                raise ValueError
            favorite = payload.get("is_favorite")
            if sort == "favorites_first" and type(favorite) is not bool:
                raise ValueError
            return FeedCursor(
                saved_at=saved_at.astimezone(UTC), id=payload["id"], is_favorite=favorite
            )
        except (ValueError, OverflowError) as exc:
            raise invalid_cursor from exc

    @staticmethod
    def _encode_cursor(cursor: FeedCursor) -> str:
        payload = json.dumps(
            {
                "saved_at": cursor.saved_at.astimezone(UTC).isoformat(timespec="microseconds"),
                "id": cursor.id,
                **({"is_favorite": cursor.is_favorite} if cursor.is_favorite is not None else {}),
            },
            separators=(",", ":"),
        ).encode("utf-8")
        prefix = "v1." if cursor.is_favorite is None else "f1."
        return prefix + base64.urlsafe_b64encode(payload).decode("ascii").rstrip("=")

    @staticmethod
    def _normalize_search_query(query: str | None) -> str | None:
        if query is None:
            return None
        normalized = unicodedata.normalize("NFKC", query).strip()
        return normalized or None
