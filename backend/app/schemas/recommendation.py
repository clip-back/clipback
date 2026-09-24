from dataclasses import dataclass
from datetime import date, datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.content import ContentRead


@dataclass(frozen=True)
class TodayCandidate:
    id: int
    saved_at: datetime
    last_viewed_at: datetime | None
    open_count: int
    last_recommended_at: datetime | None
    is_favorite: bool
    category_ids: tuple[int, ...]


@dataclass(frozen=True)
class TodaySelection:
    content_id: int
    score: float | None


class TodayRecommendationItem(BaseModel):
    recommendation_item_id: int
    rank: int
    content: ContentRead


class TodayRecommendationResponse(BaseModel):
    stage: Literal[0, 1, 2]
    recommendation_date: date
    batch_id: int | None
    generated_at: datetime | None
    items: list[TodayRecommendationItem]


class RecommendationExposureCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    client_event_id: UUID
    recommendation_item_id: int = Field(gt=0, le=2147483647, strict=True)


class RecommendationExposureRead(BaseModel):
    exposure_id: int
    client_event_id: UUID
    recommendation_item_id: int
    recommended_at: datetime
