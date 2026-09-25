from fastapi import APIRouter, Response

from app.api.deps import CurrentUserId, DatabaseSession
from app.repositories.content_repository import ContentRepository
from app.repositories.recommendation_repository import RecommendationRepository
from app.schemas.recommendation import (
    RecommendationExposureCreate,
    RecommendationExposureRead,
    TodayRecommendationResponse,
    WeeklyRecommendationResponse,
)
from app.services.recommendation_service import RecommendationService

router = APIRouter()


@router.get("/weekly", response_model=WeeklyRecommendationResponse)
async def read_weekly(
    response: Response,
    db: DatabaseSession,
    current_user_id: CurrentUserId,
) -> WeeklyRecommendationResponse:
    response.headers["Cache-Control"] = "no-store"
    return await RecommendationService(
        content_repository=ContentRepository(db),
        recommendation_repository=RecommendationRepository(db),
    ).read_weekly(current_user_id)


@router.post("/exposures", response_model=RecommendationExposureRead, status_code=201)
async def record_exposure(
    payload: RecommendationExposureCreate,
    response: Response,
    db: DatabaseSession,
    current_user_id: CurrentUserId,
) -> RecommendationExposureRead:
    response.headers["Cache-Control"] = "no-store"
    return await RecommendationService(
        content_repository=ContentRepository(db),
        recommendation_repository=RecommendationRepository(db),
    ).record_exposure(current_user_id, payload)


@router.get("/today", response_model=TodayRecommendationResponse)
async def read_today(
    response: Response,
    db: DatabaseSession,
    current_user_id: CurrentUserId,
) -> TodayRecommendationResponse:
    response.headers["Cache-Control"] = "no-store"
    return await RecommendationService(
        content_repository=ContentRepository(db),
        recommendation_repository=RecommendationRepository(db),
    ).read_today(current_user_id)
