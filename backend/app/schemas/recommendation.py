from dataclasses import dataclass
from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel

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
