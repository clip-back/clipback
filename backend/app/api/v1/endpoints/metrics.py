from fastapi import APIRouter, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUserId, DatabaseSession
from app.repositories.category_repository import CategoryRepository
from app.repositories.content_repository import ContentRepository
from app.repositories.event_repository import EventRepository
from app.schemas.metrics import MetricEventCreate, MetricEventRead
from app.services.metrics_service import MetricsService

router = APIRouter()


@router.post("/events", response_model=MetricEventRead, status_code=status.HTTP_201_CREATED)
async def create_metric_event(
    payload: MetricEventCreate,
    db: DatabaseSession,
    current_user_id: CurrentUserId,
) -> MetricEventRead:
    return await _build_metrics_service(db).record_event(
        user_id=current_user_id,
        payload=payload,
    )


def _build_metrics_service(db: AsyncSession) -> MetricsService:
    return MetricsService(
        event_repository=EventRepository(db),
        content_repository=ContentRepository(db),
        category_repository=CategoryRepository(db),
    )
