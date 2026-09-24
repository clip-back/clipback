from fastapi import APIRouter, Response

from app.api.deps import CurrentUserId, DatabaseSession
from app.repositories.content_repository import ContentRepository
from app.repositories.recommendation_repository import RecommendationRepository
from app.schemas.recommendation import TodayRecommendationResponse
from app.services.recommendation_service import RecommendationService

router = APIRouter()


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
