from datetime import UTC, datetime
from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient

from app.api.v1.endpoints import metrics as metrics_endpoints
from app.core.security import create_access_token
from app.repositories.auth_session_repository import AuthSessionRepository
from app.repositories.user_repository import UserRepository
from app.schemas.metrics import MetricEventCreate, MetricEventRead


class FakeMetricsService:
    def __init__(self) -> None:
        self.requests: list[tuple[int, MetricEventCreate]] = []

    async def record_event(
        self,
        *,
        user_id: int,
        payload: MetricEventCreate,
    ) -> MetricEventRead:
        self.requests.append((user_id, payload))
        return MetricEventRead(
            id=len(self.requests),
            event_type=payload.event_type,
            created_at=datetime.now(UTC),
        )


@pytest.fixture
def authenticated_metrics_client(client: TestClient, monkeypatch):
    async def get_active(self, *, session_id: int, user_id: int):
        return SimpleNamespace(id=session_id, user_id=user_id)

    async def get_user(self, user_id: int):
        return SimpleNamespace(id=user_id)

    service = FakeMetricsService()
    monkeypatch.setattr(AuthSessionRepository, "get_active", get_active)
    monkeypatch.setattr(UserRepository, "get", get_user)
    monkeypatch.setattr(metrics_endpoints, "_build_metrics_service", lambda db: service)
    token = create_access_token(user_id=7, session_id=3)
    return client, service, {"Authorization": f"Bearer {token}"}


def test_create_metric_event_requires_authentication(client: TestClient) -> None:
    response = client.post(
        "/api/v1/metrics/events",
        json={"event_type": "card_clicked", "content_id": 1},
    )

    assert response.status_code == 401


@pytest.mark.parametrize(
    "payload",
    [
        {"event_type": "category_filter_used", "category_id": 2},
        {"event_type": "card_clicked", "content_id": 8, "category_id": 2},
        {"event_type": "original_link_opened", "content_id": 8},
    ],
)
def test_create_metric_event_accepts_public_event_contracts(
    authenticated_metrics_client,
    payload: dict[str, object],
) -> None:
    client, service, headers = authenticated_metrics_client

    response = client.post("/api/v1/metrics/events", json=payload, headers=headers)

    assert response.status_code == 201
    assert response.json()["event_type"] == payload["event_type"]
    assert service.requests[-1][0] == 7


@pytest.mark.parametrize(
    "payload",
    [
        {"event_type": "content_created", "content_id": 1},
        {"event_type": "content_reopened", "content_id": 1},
        {"event_type": "category_filter_used"},
        {"event_type": "category_filter_used", "category_id": 1, "content_id": 2},
        {"event_type": "card_clicked"},
        {"event_type": "original_link_opened", "content_id": 1, "category_id": 2},
        {"event_type": "card_clicked", "content_id": 1, "metadata": {"url": "secret"}},
        {"event_type": "unknown", "content_id": 1},
    ],
)
def test_create_metric_event_rejects_invalid_or_server_owned_events(
    authenticated_metrics_client,
    payload: dict[str, object],
) -> None:
    client, service, headers = authenticated_metrics_client

    response = client.post("/api/v1/metrics/events", json=payload, headers=headers)

    assert response.status_code == 422
    assert service.requests == []
