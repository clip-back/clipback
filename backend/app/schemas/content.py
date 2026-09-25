from datetime import datetime
from enum import StrEnum
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, HttpUrl

from app.schemas.category import CategoryRead
from app.schemas.tag import TagNamesPayload, TagRead

MAX_CONTENT_URL_LENGTH = 2048


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


class ContentAssetType(StrEnum):
    SCREENSHOT = "screenshot"
    THUMBNAIL = "thumbnail"
    OCR_TEXT = "ocr_text"


class ContentCreate(TagNamesPayload):
    content_type: ContentType = ContentType.LINK
    category_ids: list[int] = Field(default_factory=list)
    original_url: HttpUrl | None = Field(default=None, max_length=MAX_CONTENT_URL_LENGTH)
    source: ContentSource = ContentSource.UNKNOWN
    title: str | None = Field(default=None, max_length=120)
    summary: str | None = None
    is_favorite: bool = False


class ContentCategoryUpdate(BaseModel):
    category_ids: list[int] = Field(default_factory=list)


class ContentTagUpdate(TagNamesPayload):
    pass


class ContentFavoriteUpdate(BaseModel):
    is_favorite: bool


class ShareAttachment(BaseModel):
    filename: str | None = Field(default=None, max_length=255)
    mime_type: str | None = Field(default=None, max_length=120)
    uri: str | None = Field(default=None, max_length=2048)
    size_bytes: int | None = Field(default=None, ge=0)


class ContentShareCreate(TagNamesPayload):
    url: str | None = Field(default=None, max_length=MAX_CONTENT_URL_LENGTH)
    raw_text: str | None = Field(default=None, max_length=5000)
    mime_type: str | None = Field(default=None, max_length=120)
    source_app: str | None = Field(default=None, max_length=120)
    platform: str | None = Field(default=None, max_length=40)
    attachments: list[ShareAttachment] = Field(default_factory=list)
    category_ids: list[int] = Field(default_factory=list)
    is_favorite: bool = False


class ContentAssetRead(BaseModel):
    id: int
    asset_type: ContentAssetType
    mime_type: str | None = None
    download_url: str


class ContentRead(BaseModel):
    summary_status: Literal[
        "not_requested", "queued", "processing", "completed", "failed", "skipped"
    ] = "not_requested"
    summary_error_code: (
        Literal[
            "timeout",
            "provider_error",
            "invalid_response",
            "configuration_error",
            "video_unavailable",
            "duration_exceeded",
            "live_not_supported",
            "disabled",
        ]
        | None
    ) = None
    id: int
    categories: list[CategoryRead] = Field(default_factory=list)
    tags: list[TagRead] = Field(default_factory=list)
    assets: list[ContentAssetRead] = Field(default_factory=list)
    content_type: ContentType
    source: ContentSource
    title: str
    summary: str
    original_url: str | None = None
    is_favorite: bool = False
    saved_at: datetime
    last_viewed_at: datetime | None = None


class ContentViewCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    client_event_id: UUID
    recommendation_item_id: int | None = Field(
        default=None, gt=0, le=2_147_483_647, strict=True
    )


class ContentViewEvent(BaseModel):
    content_id: int
    event_type: str
