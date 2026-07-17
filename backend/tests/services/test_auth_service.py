from datetime import UTC, datetime, timedelta
from types import SimpleNamespace

import pytest

from app.core.exceptions import AuthenticationError
from app.core.security import decode_access_token, hash_refresh_token
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


def build_service() -> tuple[AuthService, FakeUserRepository, FakeAuthSessionRepository]:
    user_repository = FakeUserRepository()
    auth_session_repository = FakeAuthSessionRepository()
    service = AuthService(
        user_repository=user_repository,
        auth_session_repository=auth_session_repository,
    )
    return service, user_repository, auth_session_repository


@pytest.mark.asyncio
async def test_create_guest_sessions_returns_distinct_users_and_tokens() -> None:
    service, _, auth_session_repository = build_service()

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
    service, _, auth_session_repository = build_service()
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
    service, _, auth_session_repository = build_service()
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
    service, _, auth_session_repository = build_service()
    created = await service.create_guest_session()

    await service.logout(created.refresh_token)
    await service.logout("unknown-refresh-token")

    assert auth_session_repository.auth_sessions[1].revoked_at is not None
    assert auth_session_repository.session.commit_count == 2
    assert auth_session_repository.session.rollback_count == 1
