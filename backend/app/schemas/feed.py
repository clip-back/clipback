from dataclasses import dataclass
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

from app.schemas.content import ContentRead

MAX_FEED_CURSOR_LENGTH = 512
FeedSort = Literal["latest", "favorites_first"]


@dataclass(frozen=True)
class FeedCursor:
    saved_at: datetime
    id: int
    is_favorite: bool | None = None


class FeedResponse(BaseModel):
    total_count: int = Field(ge=0)
    items: list[ContentRead]
    next_cursor: str | None = None
