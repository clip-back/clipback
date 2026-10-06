from dataclasses import dataclass
from datetime import date, datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.models.recommendation import RecommendationCardType
from app.schemas.category import CategorySummaryRead
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


@dataclass(frozen=True)
class WeeklyCandidate:
    category: CategorySummaryRead
    saved_count: int = 0
    last_saved_event_at: datetime | None = None
    viewed_count: int = 0
    last_viewed_event_at: datetime | None = None
    last_exposed_at: datetime | None = None


@dataclass(frozen=True)
class WeeklySelection:
    category_id: int
    card_type: RecommendationCardType


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


class WeeklyRecommendationItem(BaseModel):
    recommendation_item_id: int
    rank: int
    card_type: RecommendationCardType
    category: CategorySummaryRead


class WeeklyRecommendationResponse(BaseModel):
    period_start: datetime
    period_end: datetime
    batch_id: int | None
    generated_at: datetime | None
    items: list[WeeklyRecommendationItem]


class RecommendationExposureCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    client_event_id: UUID
    recommendation_item_id: int = Field(gt=0, le=2147483647, strict=True)


class RecommendationExposureRead(BaseModel):
    exposure_id: int
    client_event_id: UUID
    recommendation_item_id: int
    recommended_at: datetime
