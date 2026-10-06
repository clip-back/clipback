from datetime import UTC, datetime, timedelta
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.core.security import create_access_token
from app.models.social_identity import SocialProvider
from app.repositories.auth_session_repository import AuthSessionRepository
from app.repositories.event_repository import EventRepository
from app.repositories.social_identity_repository import SocialIdentityRepository
from app.repositories.user_repository import UserRepository


@pytest.fixture
def repositories(monkeypatch):
    users = AsyncMock(
        return_value=SimpleNamespace(
            id=7,
            email=None,
            display_name="사용자",
            is_guest=False,
            created_at=datetime(2026, 9, 7, 3, tzinfo=UTC),
        )
    )
    sessions = AsyncMock(return_value=SimpleNamespace(id=3, user_id=7))
    providers = AsyncMock(return_value=[SocialProvider.GOOGLE, SocialProvider.KAKAO])
    stats = AsyncMock(return_value={"saved_count": 1, "reopened_count": 3})
    monkeypatch.setattr(UserRepository, "get", users)
    monkeypatch.setattr(AuthSessionRepository, "get_active", sessions)
    monkeypatch.setattr(SocialIdentityRepository, "list_providers", providers)
    monkeypatch.setattr(EventRepository, "read_user_stats", stats)
    return SimpleNamespace(users=users, sessions=sessions, providers=providers, stats=stats)


def headers(**kwargs):
    return {"Authorization": f"Bearer {create_access_token(user_id=7, session_id=3, **kwargs)}"}


def test_account_response(client, repositories) -> None:
    response = client.get("/api/v1/users/me", headers=headers())

    assert response.status_code == 200
    assert response.json() == {
        "id": 7,
        "email": None,
        "display_name": "사용자",
        "is_guest": False,
        "created_at": "2026-09-07T03:00:00Z",
        "linked_providers": ["google", "kakao"],
    }
    repositories.providers.assert_awaited_once_with(user_id=7)


@pytest.mark.parametrize("counts", [(0, 0), (1, 3)])
def test_stats_response_and_user_scope(client, repositories, counts) -> None:
    repositories.stats.return_value = {"saved_count": counts[0], "reopened_count": counts[1]}

    response = client.get("/api/v1/users/me/stats", headers=headers())

    assert response.status_code == 200
    assert response.json() == repositories.stats.return_value
    repositories.stats.assert_awaited_once_with(user_id=7)


@pytest.mark.parametrize("path", ["/api/v1/users/me", "/api/v1/users/me/stats"])
@pytest.mark.parametrize("failure", ["missing", "expired", "revoked", "missing_user"])
def test_user_endpoints_reject_invalid_authentication(client, repositories, path, failure) -> None:
    auth = headers()
    if failure == "missing":
        auth = {}
    elif failure == "expired":
        auth = headers(expires_delta=timedelta(minutes=-1))
    elif failure == "revoked":
        repositories.sessions.return_value = None
    else:
        repositories.users.return_value = None

    response = client.get(path, headers=auth)

    assert response.status_code == 401
    assert response.headers["www-authenticate"] == "Bearer"
    repositories.providers.assert_not_awaited()
    repositories.stats.assert_not_awaited()


def test_user_openapi_contract(client) -> None:
    specification = client.get("/api/v1/openapi.json").json()
    schemas = specification["components"]["schemas"]
    assert {"created_at", "linked_providers"} <= set(schemas["UserRead"]["required"])
    assert set(schemas["UserRead"]["properties"]) == {
        "id",
        "email",
        "display_name",
        "is_guest",
        "created_at",
        "linked_providers",
    }
    assert set(schemas["UserStatsRead"]["required"]) == {"saved_count", "reopened_count"}
    response = specification["paths"]["/api/v1/users/me/stats"]["get"]["responses"]["200"]
    assert response["content"]["application/json"]["schema"] == {
        "$ref": "#/components/schemas/UserStatsRead",
    }
