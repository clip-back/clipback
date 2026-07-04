from datetime import datetime
from enum import StrEnum

from pydantic import BaseModel, Field


class MetricEventType(StrEnum):
    CONTENT_CREATED = "content_created"
    CONTENT_REOPENED = "content_reopened"
    CATEGORY_FILTER_USED = "category_filter_used"
    CARD_CLICKED = "card_clicked"
    ORIGINAL_LINK_OPENED = "original_link_opened"


class MetricEventCreate(BaseModel):
    event_type: MetricEventType
    content_id: int | None = None
    category_id: int | None = None
    metadata: dict[str, str | int | float | bool | None] = Field(default_factory=dict)


class MetricEventRead(BaseModel):
    id: int
    event_type: MetricEventType
    created_at: datetime
