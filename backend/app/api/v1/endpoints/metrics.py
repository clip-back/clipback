from fastapi import APIRouter, status

from app.api.deps import CurrentUserId
from app.schemas.metrics import MetricEventCreate, MetricEventRead
from app.services.metrics_service import MetricsService

router = APIRouter()


@router.post("/events", response_model=MetricEventRead, status_code=status.HTTP_201_CREATED)
async def create_metric_event(
    payload: MetricEventCreate,
    _current_user_id: CurrentUserId,
) -> MetricEventRead:
    return MetricsService().record_placeholder(payload)
