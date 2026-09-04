from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient

from app.api.v1.endpoints import feed as feed_endpoints
from app.core.security import create_access_token
from app.repositories.auth_session_repository import AuthSessionRepository
from app.repositories.user_repository import UserRepository
from app.schemas.feed import FeedResponse


class FakeFeedService:
    def __init__(self) -> None:
        self.calls: list[dict[str, object]] = []

    async def read_feed(
        self,
        *,
        user_id: int,
        query: str | None,
        category_id: int | None,
        is_favorite: bool | None,
        limit: int,
        cursor: str | None,
    ) -> FeedResponse:
        self.calls.append(
            {
                "user_id": user_id,
                "query": query,
                "category_id": category_id,
                "is_favorite": is_favorite,
                "limit": limit,
                "cursor": cursor,
            }
        )
        return FeedResponse(items=[], next_cursor=None)


def authorize(monkeypatch) -> dict[str, str]:
    async def get_active(self, *, session_id: int, user_id: int):
        return SimpleNamespace(id=session_id, user_id=user_id)

    async def get_user(self, user_id: int):
        return SimpleNamespace(id=user_id)

    monkeypatch.setattr(AuthSessionRepository, "get_active", get_active)
    monkeypatch.setattr(UserRepository, "get", get_user)
    token = create_access_token(user_id=7, session_id=3)
    return {"Authorization": f"Bearer {token}"}


@pytest.mark.parametrize(
    ("query_value", "expected"),
    [("true", True), ("false", False)],
)
def test_read_feed_passes_favorite_filter_with_existing_parameters(
    client: TestClient,
    monkeypatch,
    query_value: str,
    expected: bool,
) -> None:
    service = FakeFeedService()
    monkeypatch.setattr(
        feed_endpoints,
        "FeedService",
        lambda *, content_repository: service,
    )

    response = client.get(
        (
            "/api/v1/feed?q=백엔드"
            f"&is_favorite={query_value}&category_id=3&limit=10&cursor=42"
        ),
        headers=authorize(monkeypatch),
    )

    assert response.status_code == 200
    assert response.json() == {"items": [], "next_cursor": None}
    assert service.calls == [
        {
            "user_id": 7,
            "query": "백엔드",
            "category_id": 3,
            "is_favorite": expected,
            "limit": 10,
            "cursor": "42",
        }
    ]


def test_read_feed_keeps_favorite_filter_optional(
    client: TestClient,
    monkeypatch,
) -> None:
    service = FakeFeedService()
    monkeypatch.setattr(
        feed_endpoints,
        "FeedService",
        lambda *, content_repository: service,
    )

    response = client.get(
        "/api/v1/feed",
        headers=authorize(monkeypatch),
    )

    assert response.status_code == 200
    assert service.calls[0]["is_favorite"] is None
    assert service.calls[0]["query"] is None


def test_read_feed_rejects_invalid_favorite_filter(
    client: TestClient,
    monkeypatch,
) -> None:
    service = FakeFeedService()
    monkeypatch.setattr(
        feed_endpoints,
        "FeedService",
        lambda *, content_repository: service,
    )

    response = client.get(
        "/api/v1/feed?is_favorite=invalid",
        headers=authorize(monkeypatch),
    )

    assert response.status_code == 422
    assert service.calls == []


def test_read_feed_validates_search_query_length(
    client: TestClient,
    monkeypatch,
) -> None:
    service = FakeFeedService()
    monkeypatch.setattr(
        feed_endpoints,
        "FeedService",
        lambda *, content_repository: service,
    )
    headers = authorize(monkeypatch)

    accepted = client.get(
        "/api/v1/feed",
        params={"q": "가" * 100},
        headers=headers,
    )
    rejected = client.get(
        "/api/v1/feed",
        params={"q": "가" * 101},
        headers=headers,
    )

    assert accepted.status_code == 200
    assert service.calls[0]["query"] == "가" * 100
    assert rejected.status_code == 422
    assert len(service.calls) == 1
