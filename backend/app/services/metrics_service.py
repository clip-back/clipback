from datetime import UTC, datetime

from app.schemas.metrics import MetricEventCreate, MetricEventRead


class MetricsService:
    def record_placeholder(self, payload: MetricEventCreate) -> MetricEventRead:
        return MetricEventRead(id=1, event_type=payload.event_type, created_at=datetime.now(UTC))

