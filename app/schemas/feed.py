from pydantic import BaseModel

from app.schemas.content import ContentRead


class FeedResponse(BaseModel):
    items: list[ContentRead]
    next_cursor: str | None = None

