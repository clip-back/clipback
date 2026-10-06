from dataclasses import dataclass
from datetime import datetime

from pydantic import BaseModel

from app.schemas.content import ContentRead

MAX_FEED_CURSOR_LENGTH = 512


@dataclass(frozen=True)
class FeedCursor:
    saved_at: datetime
    id: int


class FeedResponse(BaseModel):
    items: list[ContentRead]
    next_cursor: str | None = None
