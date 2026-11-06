"""Provider unlinking before `DELETE /users/me` (#254, D5–D7, D23, D30, ADR 0007).

Apple and Kakao run through the real social auth client over a fake HTTP transport.
"""

import asyncio
import logging
import threading
from types import SimpleNamespace
from urllib.parse import parse_qs
from uuid import UUID, uuid4

import httpx
import pytest
import pytest_asyncio
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec
from jose import jwt
from pydantic import SecretStr
from sqlalchemy import delete, text

from app.core.config import settings
from app.integrations import social_auth_client as social_auth_module
from app.integrations.deletion_ledger import LedgerUnavailableError, get_deletion_ledger
from app.integrations.social_auth_client import APPLE_ISSUER, SocialAuthClient
from app.models.apple_auth import AppleAuthChallenge
from app.models.category import Category
from app.models.content import Content
from app.models.content_event import ContentEvent
from app.models.image_deletion import ImageDeletion
from app.models.user import User
from app.services import account_deletion_service
from app.services.image_deletion_service import retry_image_deletions
from tests.integration.helpers import guest, request
from tests.integration.test_account_deletion import user_exists
from tests.integration.test_account_deletion_api import (
    REASONS,
    delete_me,
    ledger_events,
    overlapping as overlapping,  # noqa: F401
    pause_first_db_deletion,
    until_lock,
)
from tests.integration.test_apple_auth import (
    apple_login,
    apple_provider as apple_provider,  # noqa: F401
)
from tests.integration.test_image_deletion import committed_api as committed_api  # noqa: F401

pytestmark = pytest.mark.asyncio
APPLE_REVOKE = "https://appleid.apple.com/auth/revoke"
KAKAO_UNLINK = "https://kapi.kakao.com/v1/user/unlink"
ADMIN_KEY = "synthetic-kakao-admin-key"
APPLE_TOKEN = "provider-refresh-apple-user"
APPLE_EMAIL = "private@privaterelay.appleid.com"
KAKAO_MEMBER = "4242424242"


@pytest.fixture
def providers(apple_provider, monkeypatch):  # noqa: F811
    """Apple login as in the Apple tests; revocation goes to this fake HTTP transport."""
    pem = ec.generate_private_key(ec.SECP256R1()).private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.PKCS8,
        serialization.NoEncryption(),
    ).decode()
    monkeypatch.setattr(settings, "apple_private_key", SecretStr(pem))
    monkeypatch.setattr(settings, "kakao_admin_key", SecretStr(ADMIN_KEY))
    state = SimpleNamespace(
        requests=[], responses={}, cipher=apple_provider.cipher, gate=None,
    )

    async def handler(http_request):
        url = str(http_request.url)
        state.requests.append(http_request)
        if state.gate is not None:
            await state.gate.wait()
        response = state.responses.get(url, httpx.Response(200, json={}))
        if isinstance(response, Exception):
            raise response
        return response

    client = SocialAuthClient(settings, httpx.AsyncClient(transport=httpx.MockTransport(handler)))
    monkeypatch.setattr(social_auth_module, "_social_auth_client", client)
    return state


def form(http_request):
    return {key: values[0] for key, values in parse_qs(http_request.content.decode()).items()}


async def kakao_account(api):
    tokens = await request(api, "POST", "auth/social/kakao", json={"token": KAKAO_MEMBER})
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}
    return headers, await request(api, "GET", "users/me", headers=headers)


async def apple_account(api):
    _, headers, _ = await apple_login(api)
    return headers, await request(api, "GET", "users/me", headers=headers)


async def test_stored_apple_refresh_token_is_revoked_before_the_account_is_deleted(
    api, providers, database_connection,
):
    """Order: provider revocation → DB deletion. The stored token is still there to send."""
    headers, user = await apple_account(api)

    response = await delete_me(api, headers, json=REASONS)

    assert response.status_code == 204
    assert not await user_exists(database_connection, user["id"])
    [revoke] = providers.requests
    assert revoke.method == "POST" and str(revoke.url) == APPLE_REVOKE
    body = form(revoke)
    assert {key: body[key] for key in ("client_id", "token", "token_type_hint")} == {
        "client_id": "com.example.clipback",
        "token": APPLE_TOKEN,
        "token_type_hint": "refresh_token",
    }
    # The existing client_secret generation: an ES256 JWT for Apple.
    claims = jwt.get_unverified_claims(body["client_secret"])
    assert jwt.get_unverified_header(body["client_secret"])["alg"] == "ES256"
    assert claims["aud"] == APPLE_ISSUER and claims["sub"] == "com.example.clipback"


async def test_kakao_account_is_unlinked_with_the_admin_key_and_member_number(
    api, providers, database_connection,
):
    headers, user = await kakao_account(api)

    response = await delete_me(api, headers, json=REASONS)

    assert response.status_code == 204
    assert not await user_exists(database_connection, user["id"])
    [unlink] = providers.requests
    assert unlink.method == "POST" and str(unlink.url) == KAKAO_UNLINK
    assert unlink.headers["Authorization"] == f"KakaoAK {ADMIN_KEY}"
    assert form(unlink) == {"target_id_type": "user_id", "target_id": KAKAO_MEMBER}


async def break_stored_apple_token(connection, user_id):
    await connection.execute(text(
        "UPDATE apple_credentials SET refresh_token_encrypted = 'not-a-fernet-token' "
        "WHERE social_identity_id IN "
        "(SELECT id FROM social_identities WHERE user_id = :user_id)"
    ), {"user_id": user_id})


# Every failure in the server state table's revocation row still deletes (D7, ADR 0007).
@pytest.mark.parametrize(("provider", "failure", "reason"), [
    ("apple", httpx.ReadTimeout("slow"), "timeout"),
    ("apple", httpx.Response(400, json={"error": "invalid_request"}), "provider_error"),
    ("apple", httpx.Response(503), "provider_error"),
    ("apple", httpx.ConnectError("down"), "provider_error"),
    ("apple", "missing-apple-key", "not_configured"),
    ("apple", "missing-encryption-key", "not_configured"),
    ("apple", "unreadable-token", "token_unreadable"),
    ("kakao", httpx.ReadTimeout("slow"), "timeout"),
    ("kakao", httpx.Response(401, json={"code": -401}), "provider_error"),
    ("kakao", httpx.Response(400, json={"code": -101}), "provider_error"),
    ("kakao", httpx.ConnectError("down"), "provider_error"),
])
async def test_revocation_failure_is_logged_without_secrets_and_still_deletes(
    api, providers, database_connection, monkeypatch, caplog, provider, failure, reason,
):
    if provider == "apple":
        headers, user = await apple_account(api)
    else:
        headers, user = await kakao_account(api)
    if failure == "missing-apple-key":
        monkeypatch.setattr(settings, "apple_private_key", None)
    elif failure == "missing-encryption-key":
        monkeypatch.setattr(settings, "apple_token_encryption_key", None)
    elif failure == "unreadable-token":
        await break_stored_apple_token(database_connection, user["id"])
    else:
        url = APPLE_REVOKE if provider == "apple" else KAKAO_UNLINK
        providers.responses[url] = failure
    caplog.set_level(logging.DEBUG)

    response = await delete_me(api, headers, json=REASONS)

    assert response.status_code == 204
    assert not await user_exists(database_connection, user["id"])
    [event] = ledger_events()
    failures = [
        record.getMessage() for record in caplog.records
        if record.name == account_deletion_service.__name__
    ]
    # Provider name, failure class and the ledger operation ID only.
    assert failures == [
        f"Provider revocation failed: provider={provider} reason={reason} "
        f"operation_id={event['operation_id']}"
    ]
    for secret in (APPLE_TOKEN, ADMIN_KEY, APPLE_EMAIL, "not-a-fernet-token"):
        assert secret not in caplog.text
    assert f"user_id={user['id']}" not in caplog.text


async def test_empty_apple_token_is_not_revoked(api, providers, database_connection, caplog):
    """An account whose Apple revocation was already confirmed has no token left (D7)."""
    headers, user = await apple_account(api)
    await database_connection.execute(text(
        "UPDATE apple_credentials SET refresh_token_encrypted = NULL, revoked_at = now() "
        "WHERE social_identity_id IN "
        "(SELECT id FROM social_identities WHERE user_id = :user_id)"
    ), {"user_id": user["id"]})
    caplog.set_level(logging.DEBUG)

    response = await delete_me(api, headers, json=REASONS)

    assert response.status_code == 204
    assert not await user_exists(database_connection, user["id"])
    assert providers.requests == []
    assert not [r for r in caplog.records if r.name == account_deletion_service.__name__]


@pytest.mark.parametrize("admin_key", [None, SecretStr(""), SecretStr("   ")])
async def test_kakao_is_not_unlinked_without_an_admin_key_outside_production(
    api, providers, database_connection, monkeypatch, caplog, admin_key,
):
    """D23: development and test servers start without the key and skip the unlink."""
    monkeypatch.setattr(settings, "kakao_admin_key", admin_key)
    headers, user = await kakao_account(api)
    caplog.set_level(logging.DEBUG)

    response = await delete_me(api, headers, json=REASONS)

    assert response.status_code == 204
    assert not await user_exists(database_connection, user["id"])
    assert providers.requests == []
    assert not [r for r in caplog.records if r.name == account_deletion_service.__name__]


@pytest.mark.parametrize("provider", ["naver", "google"])
async def test_naver_and_google_links_are_deleted_without_server_revocation(
    api, providers, database_connection, provider,
):
    """Naver has no revocation integration; Google is disconnected by the app (D6)."""
    headers, _, user = await guest(api)
    await database_connection.execute(text(
        "INSERT INTO social_identities (user_id, provider, provider_subject) "
        "VALUES (:user_id, :provider, 'linked-subject')"
    ), {"user_id": user["id"], "provider": provider})

    response = await delete_me(api, headers, json=REASONS)

    assert response.status_code == 204
    assert not await user_exists(database_connection, user["id"])
    assert providers.requests == []


async def test_revocation_is_not_undone_when_the_database_deletion_fails(
    api, providers, database_connection, monkeypatch,
):
    """D30: the provider link stays cut and the account stays; nothing reconnects it."""
    headers, user = await kakao_account(api)

    async def broken(session, intent):
        raise RuntimeError("injected database failure")

    monkeypatch.setattr(account_deletion_service, "apply_account_deletion", broken)
    response = await delete_me(api, headers, json=REASONS)

    assert response.status_code == 500
    assert await user_exists(database_connection, user["id"])
    # Sent once and never followed by a reconnecting request.
    assert [str(r.url) for r in providers.requests] == [KAKAO_UNLINK]


# Same-account requests queue on an account lock before any provider call (S1, user decision A:
# "계정 단위 잠금(PostgreSQL advisory lock)으로 같은 계정의 탈퇴만 줄 세운다"). These run on
# committed sessions so the lock waits are real.


@pytest_asyncio.fixture
async def committed(overlapping, providers):  # noqa: F811
    client, guest_headers, sessions, _ = overlapping
    created, challenges = [], []

    async def account(provider):
        subject = f"overlap-{uuid4().hex}"
        if provider == "apple":
            _, headers, payload = await apple_login(client, subject=subject)
            challenges.append(UUID(payload["challenge_id"]))
        else:
            tokens = await request(client, "POST", "auth/social/kakao", json={"token": subject})
            headers = {"Authorization": f"Bearer {tokens['access_token']}"}
        created.append((await request(client, "GET", "users/me", headers=headers))["id"])
        return headers

    state = SimpleNamespace(
        client=client, sessions=sessions, account=account, guest_headers=guest_headers,
        releases=[], tasks=[],
    )

    def run(coroutine):
        task = asyncio.create_task(coroutine)
        state.tasks.append(task)
        return task

    state.run = run
    try:
        yield state
    finally:
        # A paused request holds its locks and would block the cleanup below.
        for release in [providers.gate, *state.releases]:
            if release is not None:
                release.set()
        await asyncio.wait_for(
            asyncio.gather(*state.tasks, return_exceptions=True), timeout=30
        )
        async with sessions() as session:
            for model in (ImageDeletion, ContentEvent, Content, Category, User):
                column = User.id if model is User else model.user_id
                await session.execute(delete(model).where(column.in_(created)))
            # Login challenges have no user, so they outlive the account.
            await session.execute(
                delete(AppleAuthChallenge).where(AppleAuthChallenge.id.in_(challenges))
            )
            await session.commit()


async def started(task):
    """Fail at once if a request that should be waiting has already finished."""
    await asyncio.sleep(0.2)
    assert not task.done(), task.result().status_code


@pytest.mark.parametrize("provider", ["apple", "kakao"])
async def test_overlapping_request_waits_before_reading_or_revoking_provider_links(
    committed, providers, provider,
):
    """Front request revoking → the later one waits, then finds the account gone (401)."""
    headers = await committed.account(provider)
    providers.gate = asyncio.Event()
    first = committed.run(delete_me(committed.client, headers, json=REASONS))
    await until_lock(committed.sessions, holders=1, waiters=0)
    while not providers.requests:
        await asyncio.sleep(0.01)
    second = committed.run(delete_me(committed.client, headers, json={"reasons": ["rejoin"]}))
    await until_lock(committed.sessions, holders=1, waiters=1)
    await started(second)
    assert len(providers.requests) == 1  # The later request has not started its revocation.
    providers.gate.set()

    assert (await first).status_code == 204
    assert (await second).status_code == 401
    assert len(providers.requests) == 1
    assert len(ledger_events()) == 1


@pytest.mark.parametrize("failure", ["ledger", "database"])
async def test_overlap_after_a_failed_first_request_revokes_again_only_after_it_ends(
    committed, providers, monkeypatch, failure,
):
    """Ledger failure → processed anew; DB failure → the same ledger record is reused (U2)."""
    headers = await committed.account("kakao")
    if failure == "ledger":
        release = threading.Event()
        real_append = type(get_deletion_ledger()).append
        calls = 0

        def append(ledger, intent):
            nonlocal calls
            calls += 1
            if calls == 1:
                release.wait(10)
                raise LedgerUnavailableError("injected ledger outage")
            return real_append(ledger, intent)

        monkeypatch.setattr(type(get_deletion_ledger()), "append", append)
    else:
        release = pause_first_db_deletion(monkeypatch, then=ConnectionError("injected DB failure"))
    committed.releases.append(release)
    first = committed.run(delete_me(committed.client, headers, json=REASONS))
    await until_lock(committed.sessions, holders=2, waiters=0)
    second = committed.run(delete_me(committed.client, headers, json={"reasons": ["rejoin"]}))
    await until_lock(committed.sessions, holders=2, waiters=1)
    await started(second)
    assert len(providers.requests) == 1
    records = ledger_events()
    release.set()

    assert (await first).status_code == (503 if failure == "ledger" else 500)
    assert (await second).status_code == 204
    # The later request starts over, so its provider call comes after the first one ended.
    assert [str(r.url) for r in providers.requests] == [KAKAO_UNLINK, KAKAO_UNLINK]
    if failure == "database":
        assert ledger_events() == records  # Reused, not rewritten.
    assert len(ledger_events()) == 1
    await request(committed.client, "GET", "users/me", headers=headers, status=401)


async def test_provider_call_of_one_account_does_not_block_another_accounts_deletion(
    committed, providers,
):
    headers = await committed.account("kakao")
    providers.gate = asyncio.Event()
    first = committed.run(delete_me(committed.client, headers, json=REASONS))
    while not providers.requests:
        await asyncio.sleep(0.01)

    other = await asyncio.wait_for(
        delete_me(committed.client, committed.guest_headers, json=REASONS), timeout=10
    )

    assert other.status_code == 204
    assert not first.done()
    providers.gate.set()
    assert (await first).status_code == 204


@pytest.mark.parametrize("paused", ["provider", "database"])
async def test_retry_and_a_deletion_of_the_same_account_do_not_deadlock(
    committed, providers, monkeypatch, paused,
):
    """The operator retry keeps its ledger → account row order and finishes either way."""
    headers = await committed.account("kakao")
    original = account_deletion_service.apply_account_deletion

    async def broken(session, intent):
        raise RuntimeError("injected database failure")

    monkeypatch.setattr(account_deletion_service, "apply_account_deletion", broken)
    assert (await delete_me(committed.client, headers, json=REASONS)).status_code == 500
    monkeypatch.setattr(account_deletion_service, "apply_account_deletion", original)
    providers.requests.clear()
    if paused == "provider":
        providers.gate = asyncio.Event()
        release = providers.gate
    else:
        release = pause_first_db_deletion(monkeypatch)
        committed.releases.append(release)
    deletion = committed.run(
        delete_me(committed.client, headers, json={"reasons": ["rejoin"]})
    )
    if paused == "provider":
        while not providers.requests:
            await asyncio.sleep(0.01)
    else:
        await until_lock(committed.sessions, holders=2, waiters=0)

    async def operator_retry():
        async with committed.sessions() as session:
            return await retry_image_deletions(session, limit=10)

    retry = committed.run(operator_retry())
    if paused == "provider":
        # The account lock is not in the retry's way: it removes the account meanwhile.
        result = await asyncio.wait_for(retry, timeout=10)
        assert result["deleted_accounts"] == 1
        release.set()
        assert (await asyncio.wait_for(deletion, timeout=10)).status_code == 401
    else:
        await until_lock(committed.sessions, holders=2, waiters=1)  # The retry waits.
        release.set()
        assert (await asyncio.wait_for(deletion, timeout=10)).status_code == 204
        assert (await asyncio.wait_for(retry, timeout=10))["deleted_accounts"] == 0
    assert len(ledger_events()) == 1
    await request(committed.client, "GET", "users/me", headers=headers, status=401)
