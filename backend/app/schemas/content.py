from datetime import datetime
from enum import StrEnum

from pydantic import BaseModel, Field, HttpUrl

from app.schemas.category import CategoryRead


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
    category_ids: list[int] = Field(default_factory=list)
    original_url: HttpUrl | None = None
    source: ContentSource = ContentSource.UNKNOWN
    title: str | None = Field(default=None, max_length=120)
    summary: str | None = None
    is_favorite: bool = False


class ContentRead(BaseModel):
    id: int
    categories: list[CategoryRead] = Field(default_factory=list)
    content_type: ContentType
    source: ContentSource
    title: str
    summary: str
    original_url: str | None = None
    is_favorite: bool = False
    saved_at: datetime
    last_viewed_at: datetime | None = None


class ContentViewEvent(BaseModel):
    content_id: int
    event_type: str
