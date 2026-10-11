from datetime import UTC, datetime
from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient

from app.api.v1.endpoints import auth as auth_endpoints
from app.core.exceptions import AuthenticationError
from app.core.security import create_access_token
from app.models.social_identity import SocialProvider
from app.repositories.auth_session_repository import AuthSessionRepository
from app.repositories.social_identity_repository import SocialIdentityRepository
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

    async def social_login(self, *, provider: SocialProvider, token: str) -> TokenResponse:
        assert provider == SocialProvider.GOOGLE
        assert token == "provider-token"
        return self._social_response(is_new_user=True)

    async def upgrade_guest_with_social(
        self,
        *,
        user_id: int,
        provider: SocialProvider,
        token: str,
    ) -> TokenResponse:
        assert user_id == 3
        assert provider == SocialProvider.KAKAO
        assert token == "provider-token"
        return self._social_response(is_new_user=False)

    @staticmethod
    def _social_response(*, is_new_user: bool):
        from app.schemas.auth import SocialTokenResponse

        return SocialTokenResponse(
            access_token="social-access-token",
            refresh_token="social-refresh-token",
            token_type="bearer",
            expires_in=604800,
            refresh_expires_in=7776000,
            is_new_user=is_new_user,
        )


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


@pytest.mark.parametrize(("path", "status"), [("naver", 422), ("naver/upgrade", 401)])
def test_naver_new_auth_is_disabled(client, path, status):
    # Unknown provider is rejected; upgrade can fail authentication first when unauthenticated.
    response = client.post(f"/api/v1/auth/social/{path}", json={"token": "legacy-token"})
    assert response.status_code == status


@pytest.mark.parametrize("code", ["", " ", "\n"])
def test_apple_rejects_blank_code_before_challenge_is_consumed(client, code):
    response = client.post("/api/v1/auth/social/apple", json={
        "token": "identity", "authorization_code": code,
        "challenge_id": "7ce2d92f-1403-4ae3-8a58-ae4d0dff99fa",
    })
    assert response.status_code == 422


def test_apple_challenge_requires_authentication_for_upgrade(client):
    response = client.post("/api/v1/auth/social/apple/challenge", json={"purpose": "upgrade"})
    assert response.status_code == 401


def test_unconfigured_apple_challenge_returns_503_without_database_access(client, monkeypatch):
    from app.core.config import settings

    monkeypatch.setattr(settings, "apple_client_id", None)
    response = client.post("/api/v1/auth/social/apple/challenge", json={"purpose": "login"})
    assert response.status_code == 503
    assert response.json() == {"detail": "Apple authentication is not configured"}


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
            created_at=datetime(2026, 9, 7, 3, tzinfo=UTC),
        )

    async def list_providers(self, user_id: int):
        return []

    monkeypatch.setattr(AuthSessionRepository, "get_active", get_active)
    monkeypatch.setattr(UserRepository, "get", get_user)
    monkeypatch.setattr(SocialIdentityRepository, "list_providers", list_providers)
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
        "created_at": "2026-09-07T03:00:00Z",
        "linked_providers": [],
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


def test_social_login_contract(client: TestClient, fake_auth_service: FakeAuthService) -> None:
    response = client.post(
        "/api/v1/auth/social/google",
        json={"token": "provider-token"},
    )

    assert response.status_code == 200
    assert response.json() == {
        "access_token": "social-access-token",
        "refresh_token": "social-refresh-token",
        "token_type": "bearer",
        "expires_in": 604800,
        "refresh_expires_in": 7776000,
        "is_new_user": True,
    }
    assert "provider-token" not in response.text


def test_social_login_rejects_unknown_provider_and_extra_fields(
    client: TestClient,
    fake_auth_service: FakeAuthService,
) -> None:
    unknown = client.post(
        "/api/v1/auth/social/unknown",
        json={"token": "provider-token"},
    )
    extra = client.post(
        "/api/v1/auth/social/google",
        json={"token": "provider-token", "email": "spoofed@example.com"},
    )

    assert unknown.status_code == 422
    assert extra.status_code == 422


@pytest.mark.parametrize("token", ["", "   ", "secret-token-" + "x" * 8192])
def test_social_login_rejects_invalid_token_without_echoing_it(
    client: TestClient,
    fake_auth_service: FakeAuthService,
    token: str,
) -> None:
    response = client.post(
        "/api/v1/auth/social/google",
        json={"token": token},
    )

    assert response.status_code == 422
    assert token not in response.text or not token


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("authorization_code", "secret-code-" + "x" * 8192),
        ("authorization_code", {"nested": "secret-code-value"}),
        ("authorization_code", None),
        ("challenge_id", "secret-code-invalid-uuid"),
        ("challenge_id", None),
        ("token", {"nested": "secret-identity-value"}),
        ("token", None),
        ("display_name", "secret-name-" + "x" * 80),
        ("unexpected", {"nested": "secret-extra-value"}),
    ],
)
def test_apple_request_validation_never_echoes_sensitive_inputs(client, field, value):
    payload = {
        "token": "secret-identity-value",
        "authorization_code": "secret-code-value",
        "challenge_id": "00000000-0000-0000-0000-000000000001",
    }
    if value is None:
        payload.pop(field)
    else:
        payload[field] = value
    response = client.post("/api/v1/auth/social/apple", json=payload)
    assert response.status_code == 422
    assert response.json() == {"detail": "Invalid authentication request"}
    assert response.headers["cache-control"] == "no-store"
    assert "secret-" not in response.text


def test_malformed_auth_json_does_not_echo_tokens(client):
    response = client.post(
        "/api/v1/auth/social/apple",
        content='{"token":"secret-identity-value","authorization_code":"secret-code-value",',
        headers={"Content-Type": "application/json"},
    )
    assert response.status_code == 422
    assert response.json() == {"detail": "Invalid authentication request"}
    assert "secret-" not in response.text


def test_social_upgrade_requires_authentication(client: TestClient) -> None:
    response = client.post(
        "/api/v1/auth/social/kakao/upgrade",
        json={"token": "provider-token"},
    )

    assert response.status_code == 401


def test_social_upgrade_contract(
    client: TestClient,
    fake_auth_service: FakeAuthService,
    monkeypatch,
) -> None:
    async def get_active(self, *, session_id: int, user_id: int):
        return SimpleNamespace(id=session_id, user_id=user_id)

    async def get_user(self, user_id: int):
        return SimpleNamespace(id=user_id)

    monkeypatch.setattr(AuthSessionRepository, "get_active", get_active)
    monkeypatch.setattr(UserRepository, "get", get_user)
    access_token = create_access_token(user_id=3, session_id=5)

    response = client.post(
        "/api/v1/auth/social/kakao/upgrade",
        json={"token": "provider-token"},
        headers={"Authorization": f"Bearer {access_token}"},
    )

    assert response.status_code == 200
    assert response.json()["is_new_user"] is False
