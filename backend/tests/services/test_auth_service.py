from datetime import UTC, datetime, timedelta
from types import SimpleNamespace

import pytest
from sqlalchemy.exc import IntegrityError

from app.core.exceptions import (
    AuthenticationError,
    ExternalServiceError,
    InvalidStateError,
    SystemConfigurationError,
)
from app.core.security import decode_access_token, hash_refresh_token
from app.integrations.social_auth_client import (
    SocialAuthInvalidCredentialError,
    SocialAuthNotConfiguredError,
    SocialAuthTimeoutError,
    SocialAuthUpstreamError,
    SocialProfile,
)
from app.models.social_identity import SocialProvider
from app.services.auth_service import AuthService


class FakeSession:
    def __init__(self) -> None:
        self.commit_count = 0
        self.rollback_count = 0

    async def commit(self) -> None:
        self.commit_count += 1

    async def rollback(self) -> None:
        self.rollback_count += 1


class FakeUserRepository:
    def __init__(self) -> None:
        self.users: dict[int, SimpleNamespace] = {}

    async def create_guest(self) -> SimpleNamespace:
        user = SimpleNamespace(
            id=len(self.users) + 1,
            email=None,
            display_name="Guest",
            is_guest=True,
        )
        self.users[user.id] = user
        return user

    async def get(self, user_id: int) -> SimpleNamespace | None:
        return self.users.get(user_id)

    async def get_for_update(self, user_id: int) -> SimpleNamespace | None:
        return self.users.get(user_id)

    async def create_social(self, *, email: str | None, display_name: str) -> SimpleNamespace:
        user = SimpleNamespace(
            id=len(self.users) + 1,
            email=email,
            display_name=display_name,
            is_guest=False,
        )
        self.users[user.id] = user
        return user

    async def promote_guest(
        self,
        user: SimpleNamespace,
        *,
        email: str | None,
        display_name: str,
    ) -> SimpleNamespace:
        user.email = email
        user.display_name = display_name
        user.is_guest = False
        return user


class FakeAuthSessionRepository:
    def __init__(self) -> None:
        self.session = FakeSession()
        self.auth_sessions: dict[int, SimpleNamespace] = {}

    async def create(
        self,
        *,
        user_id: int,
        refresh_token_hash: str,
        expires_at: datetime,
    ) -> SimpleNamespace:
        auth_session = SimpleNamespace(
            id=len(self.auth_sessions) + 1,
            user_id=user_id,
            refresh_token_hash=refresh_token_hash,
            expires_at=expires_at,
            revoked_at=None,
        )
        self.auth_sessions[auth_session.id] = auth_session
        return auth_session

    async def get_by_refresh_token_hash_for_update(
        self,
        refresh_token_hash: str,
    ) -> SimpleNamespace | None:
        return next(
            (
                auth_session
                for auth_session in self.auth_sessions.values()
                if auth_session.refresh_token_hash == refresh_token_hash
            ),
            None,
        )

    async def rotate(
        self,
        auth_session: SimpleNamespace,
        *,
        refresh_token_hash: str,
        expires_at: datetime,
    ) -> SimpleNamespace:
        auth_session.refresh_token_hash = refresh_token_hash
        auth_session.expires_at = expires_at
        auth_session.revoked_at = None
        return auth_session

    async def revoke(self, auth_session: SimpleNamespace) -> SimpleNamespace:
        auth_session.revoked_at = datetime.now(UTC)
        return auth_session

    async def revoke_all_for_user(self, user_id: int) -> None:
        for auth_session in self.auth_sessions.values():
            if auth_session.user_id == user_id and auth_session.revoked_at is None:
                auth_session.revoked_at = datetime.now(UTC)


class FakeSocialIdentityRepository:
    def __init__(self) -> None:
        self.identities: dict[tuple[SocialProvider, str], SimpleNamespace] = {}

    async def get_by_provider_subject(
        self,
        *,
        provider: SocialProvider,
        provider_subject: str,
    ) -> SimpleNamespace | None:
        return self.identities.get((provider, provider_subject))

    async def get_by_user_provider(
        self,
        *,
        user_id: int,
        provider: SocialProvider,
    ) -> SimpleNamespace | None:
        return next(
            (
                identity
                for identity in self.identities.values()
                if identity.user_id == user_id and identity.provider == provider
            ),
            None,
        )

    async def create(
        self,
        *,
        user_id: int,
        provider: SocialProvider,
        provider_subject: str,
    ) -> SimpleNamespace:
        identity = SimpleNamespace(
            id=len(self.identities) + 1,
            user_id=user_id,
            provider=provider,
            provider_subject=provider_subject,
        )
        self.identities[(provider, provider_subject)] = identity
        return identity


class FakeSocialAuthClient:
    def __init__(self) -> None:
        self.profile = SocialProfile(
            provider=SocialProvider.GOOGLE,
            subject="provider-user-1",
            email="user@example.com",
            display_name="Social User",
        )
        self.error: Exception | None = None
        self.tokens: list[str] = []

    async def verify(self, *, provider: SocialProvider, token: str) -> SocialProfile:
        self.tokens.append(token)
        if self.error is not None:
            raise self.error
        assert provider == self.profile.provider
        return self.profile


def build_service() -> tuple[
    AuthService,
    FakeUserRepository,
    FakeAuthSessionRepository,
    FakeSocialIdentityRepository,
    FakeSocialAuthClient,
]:
    user_repository = FakeUserRepository()
    auth_session_repository = FakeAuthSessionRepository()
    social_identity_repository = FakeSocialIdentityRepository()
    social_auth_client = FakeSocialAuthClient()
    service = AuthService(
        user_repository=user_repository,
        auth_session_repository=auth_session_repository,
        social_identity_repository=social_identity_repository,
        social_auth_client=social_auth_client,
    )
    return (
        service,
        user_repository,
        auth_session_repository,
        social_identity_repository,
        social_auth_client,
    )


@pytest.mark.asyncio
async def test_create_guest_sessions_returns_distinct_users_and_tokens() -> None:
    service, _, auth_session_repository, _, _ = build_service()

    first = await service.create_guest_session()
    second = await service.create_guest_session()

    first_claims = decode_access_token(first.access_token)
    second_claims = decode_access_token(second.access_token)
    assert first_claims.user_id != second_claims.user_id
    assert first_claims.session_id != second_claims.session_id
    assert first.refresh_token != second.refresh_token
    assert first.expires_in == 7 * 24 * 60 * 60
    assert first.refresh_expires_in == 90 * 24 * 60 * 60
    assert auth_session_repository.session.commit_count == 2


@pytest.mark.asyncio
async def test_refresh_rotates_token_and_rejects_previous_token() -> None:
    service, _, auth_session_repository, _, _ = build_service()
    created = await service.create_guest_session()

    refreshed = await service.refresh_session(created.refresh_token)

    assert refreshed.refresh_token != created.refresh_token
    assert decode_access_token(refreshed.access_token).user_id == 1
    auth_session = auth_session_repository.auth_sessions[1]
    assert auth_session.refresh_token_hash == hash_refresh_token(refreshed.refresh_token)

    with pytest.raises(AuthenticationError):
        await service.refresh_session(created.refresh_token)


@pytest.mark.asyncio
async def test_refresh_rejects_expired_or_revoked_session() -> None:
    service, _, auth_session_repository, _, _ = build_service()
    created = await service.create_guest_session()
    auth_session = auth_session_repository.auth_sessions[1]
    auth_session.expires_at = datetime.now(UTC) - timedelta(seconds=1)

    with pytest.raises(AuthenticationError):
        await service.refresh_session(created.refresh_token)

    auth_session.expires_at = datetime.now(UTC) + timedelta(days=1)
    auth_session.revoked_at = datetime.now(UTC)
    with pytest.raises(AuthenticationError):
        await service.refresh_session(created.refresh_token)


@pytest.mark.asyncio
async def test_logout_revokes_session_and_is_idempotent_for_unknown_token() -> None:
    service, _, auth_session_repository, _, _ = build_service()
    created = await service.create_guest_session()

    await service.logout(created.refresh_token)
    await service.logout("unknown-refresh-token")

    assert auth_session_repository.auth_sessions[1].revoked_at is not None
    assert auth_session_repository.session.commit_count == 2
    assert auth_session_repository.session.rollback_count == 1


@pytest.mark.asyncio
async def test_social_login_creates_user_then_reuses_identity_without_profile_overwrite() -> None:
    service, users, sessions, identities, social_client = build_service()

    created = await service.social_login(
        provider=SocialProvider.GOOGLE,
        token="first-provider-token",
    )
    users.users[1].display_name = "Clipback Name"
    social_client.profile = SocialProfile(
        provider=SocialProvider.GOOGLE,
        subject="provider-user-1",
        email="changed@example.com",
        display_name="Changed Provider Name",
    )
    existing = await service.social_login(
        provider=SocialProvider.GOOGLE,
        token="second-provider-token",
    )

    assert created.is_new_user is True
    assert existing.is_new_user is False
    assert decode_access_token(created.access_token).user_id == 1
    assert decode_access_token(existing.access_token).user_id == 1
    assert users.users[1].email == "user@example.com"
    assert users.users[1].display_name == "Clipback Name"
    assert len(identities.identities) == 1
    assert len(sessions.auth_sessions) == 2
    assert social_client.tokens == ["first-provider-token", "second-provider-token"]


@pytest.mark.asyncio
async def test_guest_upgrade_preserves_user_and_revokes_previous_sessions() -> None:
    service, users, sessions, identities, _ = build_service()
    guest_tokens = await service.create_guest_session()
    guest = users.users[1]
    guest.saved_content_marker = "preserved"

    upgraded = await service.upgrade_guest_with_social(
        user_id=guest.id,
        provider=SocialProvider.GOOGLE,
        token="provider-token",
    )

    assert upgraded.is_new_user is False
    assert decode_access_token(upgraded.access_token).user_id == guest.id
    assert users.users[guest.id].is_guest is False
    assert users.users[guest.id].saved_content_marker == "preserved"
    assert users.users[guest.id].email == "user@example.com"
    assert len(identities.identities) == 1
    old_session_id = decode_access_token(guest_tokens.access_token).session_id
    new_session_id = decode_access_token(upgraded.access_token).session_id
    assert sessions.auth_sessions[old_session_id].revoked_at is not None
    assert sessions.auth_sessions[new_session_id].revoked_at is None


@pytest.mark.asyncio
async def test_guest_upgrade_rejects_identity_linked_to_another_user() -> None:
    service, users, _, identities, _ = build_service()
    social_user = await users.create_social(
        email="existing@example.com",
        display_name="Existing",
    )
    await identities.create(
        user_id=social_user.id,
        provider=SocialProvider.GOOGLE,
        provider_subject="provider-user-1",
    )
    guest = await users.create_guest()

    with pytest.raises(InvalidStateError, match="already linked"):
        await service.upgrade_guest_with_social(
            user_id=guest.id,
            provider=SocialProvider.GOOGLE,
            token="provider-token",
        )

    assert guest.is_guest is True


@pytest.mark.asyncio
async def test_social_upgrade_rejects_non_guest_user() -> None:
    service, users, _, _, _ = build_service()
    user = await users.create_social(email=None, display_name="Existing")

    with pytest.raises(InvalidStateError, match="Only guest"):
        await service.upgrade_guest_with_social(
            user_id=user.id,
            provider=SocialProvider.GOOGLE,
            token="provider-token",
        )


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("client_error", "service_error"),
    [
        (SocialAuthInvalidCredentialError(), AuthenticationError),
        (SocialAuthTimeoutError(), ExternalServiceError),
        (SocialAuthUpstreamError(), ExternalServiceError),
        (SocialAuthNotConfiguredError(), SystemConfigurationError),
    ],
)
async def test_social_login_maps_provider_errors(
    client_error: Exception,
    service_error: type[Exception],
) -> None:
    service, _, sessions, _, social_client = build_service()
    social_client.error = client_error

    with pytest.raises(service_error):
        await service.social_login(
            provider=SocialProvider.GOOGLE,
            token="secret-provider-token",
        )

    assert sessions.auth_sessions == {}


@pytest.mark.asyncio
async def test_concurrent_first_social_login_uses_winning_identity() -> None:
    users = FakeUserRepository()
    sessions = FakeAuthSessionRepository()
    social_client = FakeSocialAuthClient()
    winning_user = SimpleNamespace(
        id=99,
        email="winner@example.com",
        display_name="Winner",
        is_guest=False,
    )
    users.users[winning_user.id] = winning_user

    class RacingSocialIdentityRepository(FakeSocialIdentityRepository):
        async def create(
            self,
            *,
            user_id: int,
            provider: SocialProvider,
            provider_subject: str,
        ) -> SimpleNamespace:
            self.identities[(provider, provider_subject)] = SimpleNamespace(
                id=1,
                user_id=winning_user.id,
                provider=provider,
                provider_subject=provider_subject,
            )
            raise IntegrityError("insert social identity", {}, Exception("unique"))

    identities = RacingSocialIdentityRepository()
    service = AuthService(
        user_repository=users,
        auth_session_repository=sessions,
        social_identity_repository=identities,
        social_auth_client=social_client,
    )

    response = await service.social_login(
        provider=SocialProvider.GOOGLE,
        token="provider-token",
    )

    assert response.is_new_user is False
    assert decode_access_token(response.access_token).user_id == winning_user.id
    assert sessions.session.rollback_count == 1
    assert sessions.session.commit_count == 1
