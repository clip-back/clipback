from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient

from app.api.v1.endpoints import auth as auth_endpoints
from app.core.exceptions import AuthenticationError
from app.core.security import create_access_token
from app.repositories.auth_session_repository import AuthSessionRepository
from app.repositories.user_repository import UserRepository
from app.schemas.auth import TokenResponse


class FakeAuthService:
    def __init__(self) -> None:
        self.logout_tokens: list[str] = []

    async def create_guest_session(self) -> TokenResponse:
        return TokenResponse(
            access_token="access-token",
            refresh_token="refresh-token",
            token_type="bearer",
            expires_in=604800,
            refresh_expires_in=7776000,
        )

    async def refresh_session(self, refresh_token: str) -> TokenResponse:
        if refresh_token != "refresh-token":
            raise AuthenticationError("Invalid or expired refresh token")
        return TokenResponse(
            access_token="rotated-access-token",
            refresh_token="rotated-refresh-token",
            token_type="bearer",
            expires_in=604800,
            refresh_expires_in=7776000,
        )

    async def logout(self, refresh_token: str) -> None:
        self.logout_tokens.append(refresh_token)


@pytest.fixture
def fake_auth_service(monkeypatch) -> FakeAuthService:
    service = FakeAuthService()
    monkeypatch.setattr(auth_endpoints, "_build_auth_service", lambda db: service)
    return service


def test_guest_refresh_and_logout_contracts(
    client: TestClient,
    fake_auth_service: FakeAuthService,
) -> None:
    guest = client.post("/api/v1/auth/guest")
    refreshed = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": "refresh-token"},
    )
    logout = client.post(
        "/api/v1/auth/logout",
        json={"refresh_token": "rotated-refresh-token"},
    )

    assert guest.status_code == 201
    assert guest.json()["expires_in"] == 604800
    assert refreshed.status_code == 200
    assert refreshed.json()["access_token"] == "rotated-access-token"
    assert logout.status_code == 204
    assert fake_auth_service.logout_tokens == ["rotated-refresh-token"]


def test_refresh_rejects_invalid_token(
    client: TestClient,
    fake_auth_service: FakeAuthService,
) -> None:
    response = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": "invalid"},
    )

    assert response.status_code == 401
    assert response.headers["www-authenticate"] == "Bearer"


def test_protected_endpoint_requires_bearer_token(client: TestClient) -> None:
    response = client.get("/api/v1/users/me")

    assert response.status_code == 401
    assert response.headers["www-authenticate"] == "Bearer"


def test_access_token_returns_current_guest_user(
    client: TestClient,
    monkeypatch,
) -> None:
    async def get_active(self, *, session_id: int, user_id: int):
        return SimpleNamespace(id=session_id, user_id=user_id)

    async def get_user(self, user_id: int):
        return SimpleNamespace(
            id=user_id,
            email=None,
            display_name="Guest",
            is_guest=True,
        )

    monkeypatch.setattr(AuthSessionRepository, "get_active", get_active)
    monkeypatch.setattr(UserRepository, "get", get_user)
    token = create_access_token(user_id=3, session_id=5)

    response = client.get(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 200
    assert response.json() == {
        "id": 3,
        "email": None,
        "display_name": "Guest",
        "is_guest": True,
    }


def test_revoked_session_rejects_valid_access_token(client: TestClient, monkeypatch) -> None:
    async def get_active(self, *, session_id: int, user_id: int):
        return None

    monkeypatch.setattr(AuthSessionRepository, "get_active", get_active)
    token = create_access_token(user_id=1, session_id=1)

    response = client.get(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 401
    assert response.headers["www-authenticate"] == "Bearer"


def test_upload_and_metrics_endpoints_require_authentication(client: TestClient) -> None:
    upload_response = client.post("/api/v1/uploads/screenshots")
    metrics_response = client.post(
        "/api/v1/metrics/events",
        json={"event_type": "card_clicked"},
    )

    assert upload_response.status_code == 401
    assert metrics_response.status_code == 401
