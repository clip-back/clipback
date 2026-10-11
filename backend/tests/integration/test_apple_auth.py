import asyncio
import hashlib
import os
from datetime import UTC, datetime, timedelta
from types import SimpleNamespace
from uuid import UUID, uuid4

import pytest
from cryptography.fernet import Fernet
from pydantic import SecretStr
from sqlalchemy import delete, func, select, text, update
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.api.v1.endpoints.auth import _build_auth_service
from app.core.config import settings
from app.core.exceptions import AuthenticationError, ExternalServiceError
from app.core.security import hash_refresh_token
from app.integrations.social_auth_client import (
    AppleTokenGrant,
    SocialAuthClient,
    SocialAuthInvalidCredentialError,
    SocialAuthNotConfiguredError,
    SocialAuthTimeoutError,
    SocialAuthUpstreamError,
)
from app.models.apple_auth import AppleAuthChallenge, AppleCredential
from app.models.auth_session import AuthSession
from app.models.social_identity import SocialIdentity, SocialProvider
from app.models.user import User
from tests.integration.helpers import guest, link, request
from tests.repositories.test_tag_concurrency import wait_for_block_or_completion


@pytest.fixture
def apple_provider(monkeypatch):
    key = Fernet.generate_key()
    for name, value in {
        "apple_client_id": "com.example.clipback",
        "apple_team_id": "TEAM",
        "apple_key_id": "KEY",
        "apple_private_key": SecretStr("not-used-by-mocked-provider"),
        "apple_token_encryption_key": SecretStr(key.decode()),
    }.items():
        monkeypatch.setattr(settings, name, value)
    state = SimpleNamespace(
        cipher=Fernet(key),
        exchange_calls=[],
        refresh_calls=[],
        exchange_error=None,
        refresh_error=None,
        omit_refresh=False,
        mismatch_subject=False,
        rotated_refresh=None,
    )

    async def verify(self, token, *, nonce_hash=None, display_name=None, access_token=None):
        if access_token is not None:
            assert access_token == "provider-access"
        subject, nonce = token.split(":", 1)
        if nonce_hash and hashlib.sha256(nonce.encode()).hexdigest() != nonce_hash:
            raise SocialAuthInvalidCredentialError
        return self._build_profile(
            provider=SocialProvider.APPLE,
            subject=subject,
            email="private@privaterelay.appleid.com",
            display_name=display_name,
        )

    async def exchange(self, code):
        state.exchange_calls.append(code)
        if state.exchange_error:
            raise state.exchange_error
        subject, nonce = code.split(":", 1)
        return AppleTokenGrant(
            id_token=f"{'someone-else' if state.mismatch_subject else subject}:{nonce}",
            refresh_token=None if state.omit_refresh else f"provider-refresh-{subject}",
            access_token="provider-access",
        )

    async def refresh(self, provider_token):
        state.refresh_calls.append(provider_token)
        if state.refresh_error:
            raise state.refresh_error
        subject = provider_token.removeprefix("provider-refresh-")
        return AppleTokenGrant(
            id_token=f"{'someone-else' if state.mismatch_subject else subject}:unused",
            refresh_token=state.rotated_refresh,
            access_token="provider-access",
        )

    monkeypatch.setattr(SocialAuthClient, "verify_apple_identity", verify)
    monkeypatch.setattr(SocialAuthClient, "exchange_apple_code", exchange)
    monkeypatch.setattr(SocialAuthClient, "refresh_apple_token", refresh)
    return state


async def apple_payload(api, *, subject="apple-user", headers=None, purpose="login", name=None):
    challenge = await request(
        api,
        "POST",
        "auth/social/apple/challenge",
        headers=headers,
        json={"purpose": purpose},
        status=201,
    )
    payload = {
        "token": f"{subject}:{challenge['nonce']}",
        "authorization_code": f"{subject}:{challenge['nonce']}",
        "challenge_id": challenge["challenge_id"],
    }
    if name is not None:
        payload["display_name"] = name
    return payload


async def apple_login(api, **kwargs):
    payload = await apple_payload(api, **kwargs)
    token = await request(api, "POST", "auth/social/apple", json=payload)
    return token, {"Authorization": f"Bearer {token['access_token']}"}, payload


async def credential_row(connection):
    return (await connection.execute(select(AppleCredential.__table__))).mappings().one()


async def make_due(connection):
    await connection.execute(
        update(AppleCredential).values(last_verified_at=datetime.now(UTC) - timedelta(hours=25))
    )


@pytest.mark.asyncio
async def test_apple_login_stores_only_encrypted_provider_token_and_reuses_identity(
    api,
    apple_provider,
    database_connection,
):
    token, headers, payload = await apple_login(api, name="First Apple Name")
    assert token["is_new_user"]
    user = await request(api, "GET", "users/me", headers=headers)
    assert user["linked_providers"] == ["apple"] and user["display_name"] == "First Apple Name"
    row = await credential_row(database_connection)
    encrypted = row["refresh_token_encrypted"]
    assert encrypted != "provider-refresh-apple-user"
    assert apple_provider.cipher.decrypt(encrypted.encode()) == b"provider-refresh-apple-user"
    assert "provider-refresh" not in str(token)
    stored_nonce = (
        (await database_connection.execute(select(AppleAuthChallenge.__table__))).mappings().one()
    )
    assert stored_nonce["nonce_hash"] != payload["token"].split(":", 1)[1]
    assert stored_nonce["consumed_at"] is not None
    second, second_headers, _ = await apple_login(api)
    assert not second["is_new_user"]
    assert await request(api, "GET", "users/me", headers=second_headers) == user
    assert (await database_connection.scalar(select(func.count()).select_from(User))) == 1


@pytest.mark.asyncio
async def test_apple_upgrade_keeps_guest_data_revokes_old_sessions_and_preserves_conflicting_guest(
    api,
    apple_provider,
    database_connection,
):
    headers, guest_tokens, before = await guest(api)
    content = await link(api, headers)
    payload = await apple_payload(api, headers=headers, purpose="upgrade")
    upgraded = await request(
        api, "POST", "auth/social/apple/upgrade", headers=headers, json=payload
    )
    upgraded_headers = {"Authorization": f"Bearer {upgraded['access_token']}"}
    after = await request(api, "GET", "users/me", headers=upgraded_headers)
    assert after["id"] == before["id"] and not after["is_guest"]
    assert (await request(api, "GET", f"contents/{content['id']}", headers=upgraded_headers))["id"]
    await request(api, "GET", "users/me", headers=headers, status=401)
    await request(
        api,
        "POST",
        "auth/refresh",
        json={"refresh_token": guest_tokens["refresh_token"]},
        status=401,
    )

    other_headers, _, other_guest = await guest(api)
    other_content = await link(api, other_headers)
    conflict_payload = await apple_payload(api, headers=other_headers, purpose="upgrade")
    await request(
        api,
        "POST",
        "auth/social/apple/upgrade",
        headers=other_headers,
        json=conflict_payload,
        status=409,
    )
    unchanged = await request(api, "GET", "users/me", headers=other_headers)
    assert unchanged["id"] == other_guest["id"] and unchanged["is_guest"]
    await request(api, "GET", f"contents/{other_content['id']}", headers=other_headers)
    assert (await database_connection.scalar(select(func.count()).select_from(SocialIdentity))) == 1


@pytest.mark.asyncio
async def test_apple_challenge_binds_purpose_and_guest_and_remains_usable_after_wrong_binding(
    api,
    apple_provider,
):
    first_headers, _, _ = await guest(api)
    other_headers, _, _ = await guest(api)
    payload = await apple_payload(api, headers=first_headers, purpose="upgrade")
    await request(api, "POST", "auth/social/apple", json=payload, status=401)
    await request(
        api, "POST", "auth/social/apple/upgrade", headers=other_headers, json=payload, status=401
    )
    assert not apple_provider.exchange_calls
    await request(api, "POST", "auth/social/apple/upgrade", headers=first_headers, json=payload)


@pytest.mark.asyncio
@pytest.mark.parametrize("failure", ["nonce", "subject", "missing_refresh", "upstream", "config"])
async def test_failed_apple_exchange_consumes_challenge_without_creating_account(
    api,
    apple_provider,
    database_connection,
    failure,
):
    payload = await apple_payload(api)
    expected_status = 401
    if failure == "nonce":
        payload["token"] = "apple-user:wrong-nonce"
    elif failure == "subject":
        apple_provider.mismatch_subject = True
    elif failure == "missing_refresh":
        apple_provider.omit_refresh = True
        expected_status = 502
    elif failure == "upstream":
        apple_provider.exchange_error = SocialAuthUpstreamError()
        expected_status = 502
    else:
        apple_provider.exchange_error = SocialAuthNotConfiguredError()
        expected_status = 503
    await request(api, "POST", "auth/social/apple", json=payload, status=expected_status)
    await request(api, "POST", "auth/social/apple", json=payload, status=401)
    assert (await database_connection.scalar(select(func.count()).select_from(User))) == 0
    assert (
        await database_connection.scalar(select(func.count()).select_from(AppleCredential))
    ) == 0


@pytest.mark.asyncio
async def test_expired_challenge_cannot_create_account(api, apple_provider, database_connection):
    payload = await apple_payload(api)
    await database_connection.execute(
        update(AppleAuthChallenge)
        .where(AppleAuthChallenge.id == UUID(payload["challenge_id"]))
        .values(expires_at=datetime.now(UTC) - timedelta(seconds=1))
    )
    await request(api, "POST", "auth/social/apple", json=payload, status=401)
    assert not apple_provider.exchange_calls


@pytest.mark.asyncio
async def test_lazy_refresh_runs_only_when_due_and_keeps_provider_token_when_not_rotated(
    api,
    apple_provider,
    database_connection,
):
    token, _, _ = await apple_login(api)
    refreshed = await request(
        api, "POST", "auth/refresh", json={"refresh_token": token["refresh_token"]}
    )
    assert not apple_provider.refresh_calls
    await make_due(database_connection)
    old = await credential_row(database_connection)
    again = await request(
        api, "POST", "auth/refresh", json={"refresh_token": refreshed["refresh_token"]}
    )
    assert apple_provider.refresh_calls == ["provider-refresh-apple-user"]
    new = await credential_row(database_connection)
    assert new["refresh_token_encrypted"] == old["refresh_token_encrypted"]
    assert new["last_verified_at"] > old["last_verified_at"]
    await request(api, "POST", "auth/refresh", json={"refresh_token": again["refresh_token"]})
    assert len(apple_provider.refresh_calls) == 1


@pytest.mark.asyncio
@pytest.mark.parametrize("revocation", ["invalid_grant", "different_subject"])
async def test_confirmed_apple_revocation_persists_and_revokes_every_session(
    api,
    apple_provider,
    database_connection,
    revocation,
):
    first, headers, _ = await apple_login(api)
    second, other_headers, _ = await apple_login(api)
    await make_due(database_connection)
    if revocation == "invalid_grant":
        apple_provider.refresh_error = SocialAuthInvalidCredentialError()
    else:
        apple_provider.mismatch_subject = True
    await request(
        api, "POST", "auth/refresh", json={"refresh_token": first["refresh_token"]}, status=401
    )
    await request(api, "GET", "users/me", headers=headers, status=401)
    await request(api, "GET", "users/me", headers=other_headers, status=401)
    await request(
        api, "POST", "auth/refresh", json={"refresh_token": second["refresh_token"]}, status=401
    )
    row = await credential_row(database_connection)
    assert row["revoked_at"] is not None and row["refresh_token_encrypted"] is None
    assert (
        await database_connection.scalar(
            select(func.count()).select_from(AuthSession).where(AuthSession.revoked_at.is_(None))
        )
    ) == 0


@pytest.mark.asyncio
@pytest.mark.parametrize("failure", ["timeout", "provider", "config", "encryption"])
async def test_apple_outage_preserves_sessions_and_provider_credentials(
    api,
    apple_provider,
    database_connection,
    monkeypatch,
    failure,
):
    token, headers, _ = await apple_login(api)
    await make_due(database_connection)
    before = await credential_row(database_connection)
    expected = 502
    if failure == "timeout":
        apple_provider.refresh_error = SocialAuthTimeoutError()
    elif failure == "provider":
        apple_provider.refresh_error = SocialAuthUpstreamError()
    elif failure == "config":
        apple_provider.refresh_error = SocialAuthNotConfiguredError()
        expected = 503
    else:
        monkeypatch.setattr(
            settings, "apple_token_encryption_key", SecretStr(Fernet.generate_key().decode())
        )
        expected = 503
    body = {"refresh_token": token["refresh_token"]}
    await request(api, "POST", "auth/refresh", json=body, status=expected)
    await request(api, "GET", "users/me", headers=headers)
    after = await credential_row(database_connection)
    assert after == before


@pytest.mark.asyncio
async def test_authenticated_naver_upgrade_is_rejected_without_changing_guest(api):
    headers, _, before = await guest(api)
    await request(
        api,
        "POST",
        "auth/social/naver/upgrade",
        headers=headers,
        json={"token": "legacy-token"},
        status=422,
    )
    assert await request(api, "GET", "users/me", headers=headers) == before


@pytest.mark.asyncio
@pytest.mark.parametrize("outcome", ["valid", "revoked", "outage", "same_token"])
async def test_concurrent_apple_refresh_serializes_before_session_locks(
    apple_provider,
    monkeypatch,
    outcome,
):
    database_url = os.environ.get("TEST_DATABASE_URL")
    if not database_url:
        pytest.skip("TEST_DATABASE_URL is required for PostgreSQL tests")
    engine = create_async_engine(database_url)
    sessions = async_sessionmaker(engine, expire_on_commit=False)
    subject = f"concurrent-{uuid4()}"
    refresh_tokens = [f"test-refresh-{uuid4()}" for _ in range(2)]
    now = datetime.now(UTC)
    entered, release = asyncio.Event(), asyncio.Event()
    original_refresh = SocialAuthClient.refresh_apple_token
    user_id = None
    tasks = []

    async def controlled_refresh(self, token):
        if not entered.is_set():
            entered.set()
            await asyncio.wait_for(release.wait(), 10)
        return await original_refresh(self, token)

    monkeypatch.setattr(SocialAuthClient, "refresh_apple_token", controlled_refresh)
    if outcome == "revoked":
        apple_provider.refresh_error = SocialAuthInvalidCredentialError()
    elif outcome == "outage":
        apple_provider.refresh_error = SocialAuthTimeoutError()
    try:
        async with sessions() as session:
            user = User(display_name="Concurrent Apple", is_guest=False)
            session.add(user)
            await session.flush()
            user_id = user.id
            identity = SocialIdentity(
                user_id=user_id,
                provider=SocialProvider.APPLE,
                provider_subject=subject,
            )
            session.add(identity)
            await session.flush()
            session.add(
                AppleCredential(
                    social_identity_id=identity.id,
                    client_id="com.example.clipback",
                    refresh_token_encrypted=apple_provider.cipher.encrypt(
                        f"provider-refresh-{subject}".encode()
                    ).decode(),
                    last_verified_at=now - timedelta(hours=25),
                )
            )
            session.add_all(
                [
                    AuthSession(
                        user_id=user_id,
                        refresh_token_hash=hash_refresh_token(token),
                        expires_at=now + timedelta(days=1),
                    )
                    for token in refresh_tokens
                ]
            )
            await session.commit()

        async with sessions() as first, sessions() as second:
            first_pid = await first.scalar(text("SELECT pg_backend_pid()"))
            second_pid = await second.scalar(text("SELECT pg_backend_pid()"))
            tasks = [
                asyncio.create_task(_build_auth_service(first).refresh_session(refresh_tokens[0]))
            ]
            await asyncio.wait_for(entered.wait(), 10)
            tasks.append(
                asyncio.create_task(
                    _build_auth_service(second).refresh_session(
                        refresh_tokens[0] if outcome == "same_token" else refresh_tokens[1]
                    )
                )
            )
            assert await wait_for_block_or_completion(sessions, tasks[1], second_pid, first_pid)
            release.set()
            results = await asyncio.wait_for(asyncio.gather(*tasks, return_exceptions=True), 10)
            assert not first.in_transaction() and not second.in_transaction()
            if outcome == "valid":
                assert all(not isinstance(result, Exception) for result in results)
                assert len(apple_provider.refresh_calls) == 1
            elif outcome == "same_token":
                assert not isinstance(results[0], Exception)
                assert isinstance(results[1], AuthenticationError)
                assert len(apple_provider.refresh_calls) == 1
            elif outcome == "revoked":
                assert all(isinstance(result, AuthenticationError) for result in results)
                assert len(apple_provider.refresh_calls) == 1
            else:
                assert all(isinstance(result, ExternalServiceError) for result in results)

        async with sessions() as session:
            active = await session.scalar(
                select(func.count())
                .select_from(AuthSession)
                .where(
                    AuthSession.user_id == user_id,
                    AuthSession.revoked_at.is_(None),
                )
            )
            assert active == (0 if outcome == "revoked" else 2)
    finally:
        release.set()
        for task in tasks:
            if not task.done():
                task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)
        if user_id is not None:
            async with sessions() as session:
                await session.execute(delete(User).where(User.id == user_id))
                await session.commit()
        await engine.dispose()
