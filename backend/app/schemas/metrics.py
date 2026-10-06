from datetime import datetime
from enum import StrEnum
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field


class MetricEventType(StrEnum):
    CATEGORY_FILTER_USED = "category_filter_used"
    CARD_CLICKED = "card_clicked"
    ORIGINAL_LINK_OPENED = "original_link_opened"


class _MetricEventCreateBase(BaseModel):
    model_config = ConfigDict(extra="forbid")


class CategoryFilterUsedEventCreate(_MetricEventCreateBase):
    event_type: Literal[MetricEventType.CATEGORY_FILTER_USED]
    category_id: int = Field(gt=0)


class CardClickedEventCreate(_MetricEventCreateBase):
    event_type: Literal[MetricEventType.CARD_CLICKED]
    content_id: int = Field(gt=0)
    category_id: int | None = Field(default=None, gt=0)


class OriginalLinkOpenedEventCreate(_MetricEventCreateBase):
    event_type: Literal[MetricEventType.ORIGINAL_LINK_OPENED]
    content_id: int = Field(gt=0)


MetricEventCreate = Annotated[
    CategoryFilterUsedEventCreate | CardClickedEventCreate | OriginalLinkOpenedEventCreate,
    Field(discriminator="event_type"),
]


class MetricEventRead(BaseModel):
    id: int
    event_type: MetricEventType
    created_at: datetime
