from datetime import datetime
from enum import StrEnum

from pydantic import BaseModel, Field, HttpUrl


class ContentType(StrEnum):
    LINK = "link"
    SCREENSHOT = "screenshot"


class ContentSource(StrEnum):
    INSTAGRAM = "instagram"
    YOUTUBE = "youtube"
    TIKTOK = "tiktok"
    SCREENSHOT = "screenshot"
    WEB = "web"
    UNKNOWN = "unknown"


class ContentCreate(BaseModel):
    content_type: ContentType = ContentType.LINK
    category_id: int
    original_url: HttpUrl | None = None
    source: ContentSource = ContentSource.UNKNOWN
    title: str | None = Field(default=None, max_length=120)
    summary: str | None = None
    is_favorite: bool = False


class ContentRead(BaseModel):
    id: int
    category_id: int
    content_type: ContentType
    source: ContentSource
    title: str
    summary: str
    original_url: str | None = None
    is_favorite: bool = False
    tags: list[str] = Field(default_factory=list)
    saved_at: datetime
    last_viewed_at: datetime | None = None


class ContentViewEvent(BaseModel):
    content_id: int
    event_type: str
