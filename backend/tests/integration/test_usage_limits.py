from datetime import UTC, datetime
from uuid import uuid4

import pytest
from sqlalchemy import func, select

from app.core.config import settings
from app.models.auth_session import AuthSession
from app.models.user import User
from tests.integration import test_youtube_summary
from tests.integration.helpers import guest, request

worker = test_youtube_summary.worker

pytestmark = pytest.mark.asyncio
VIDEO = "https://youtu.be/dQw4w9WgXcQ"


async def save(api, headers, *, shared=False, key=None, url=VIDEO):
    result = await request(
        api,
        "POST",
        "contents/share" if shared else "contents",
        status=201,
        headers={**headers, **({"Idempotency-Key": key} if key else {})},
        json={"url" if shared else "original_url": url},
    )
    return result


def assert_summary(content, status="queued", code=None):
    assert (content["summary_status"], content["summary_error_code"]) == (status, code)


async def test_guest_rejection_does_not_create_rows(api, database_connection):
    for _ in range(20):
        assert (await api.post("/api/v1/auth/guest")).status_code == 201
    before = [
        await database_connection.scalar(select(func.count()).select_from(m))
        for m in (User, AuthSession)
    ]
    response = await api.post("/api/v1/auth/guest")
    assert response.status_code == 429
    assert isinstance(response.json()["detail"], str)
    assert [
        await database_connection.scalar(select(func.count()).select_from(m))
        for m in (User, AuthSession)
    ] == before


@pytest.mark.parametrize("logged_in,limit", [(False, 20), (True, 100)])
@pytest.mark.parametrize("shared", [False, True])
async def test_daily_summary_boundary(api, monkeypatch, logged_in, limit, shared):
    monkeypatch.setattr(settings, "youtube_summary_enabled", True)
    if logged_in:
        tokens = await request(api, "POST", "auth/social/kakao", json={"token": "daily-user"})
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}
    else:
        headers, _, _ = await guest(api)
    for _ in range(limit):
        assert_summary(await save(api, headers, shared=shared))
    skipped = await save(api, headers, shared=shared)
    assert_summary(skipped, "skipped", "daily_limit_exceeded")
    assert_summary(
        await request(api, "GET", f"contents/{skipped['id']}", headers=headers),
        "skipped",
        "daily_limit_exceeded",
    )
    other, _, _ = await guest(api)
    assert_summary(await save(api, other, shared=shared))


async def test_daily_summary_kst_midnight(api, monkeypatch):
    from app.services import usage_limits

    clock = [datetime(2026, 11, 16, 14, 59, 59, tzinfo=UTC)]
    monkeypatch.setattr(usage_limits, "now", lambda: clock[0])
    monkeypatch.setattr(settings, "youtube_summary_enabled", True)
    headers, _, _ = await guest(api)
    for _ in range(20):
        assert_summary(await save(api, headers))
    assert_summary(await save(api, headers), "skipped", "daily_limit_exceeded")
    clock[0] = datetime(2026, 11, 16, 15, 0, tzinfo=UTC)
    assert_summary(await save(api, headers))


async def test_only_new_queued_jobs_count(api, monkeypatch, png_bytes):
    headers, _, _ = await guest(api)
    # Disabled jobs, unsupported stories and inputs without jobs leave today's capacity intact.
    assert_summary(await save(api, headers), "skipped", "disabled")
    monkeypatch.setattr(settings, "instagram_summary_enabled", True)
    assert_summary(
        await save(api, headers, url="https://instagram.com/stories/person/123/"),
        "skipped",
        "unsupported_content",
    )
    assert_summary(await save(api, headers, url="https://example.com/article"), "not_requested")
    image = await request(
        api,
        "POST",
        "uploads/screenshots",
        status=201,
        headers=headers,
        files={"file": ("image.png", png_bytes, "image/png")},
    )
    assert_summary(image, "not_requested")
    monkeypatch.setattr(settings, "youtube_summary_enabled", True)
    key = str(uuid4())
    first = await save(api, headers, key=key)
    assert_summary(first)
    assert (await save(api, headers, key=key))["id"] == first["id"]
    await request(api, "DELETE", f"contents/{first['id']}", headers=headers, status=204)
    for _ in range(19):
        assert_summary(await save(api, headers))
    assert_summary(await save(api, headers), "skipped", "daily_limit_exceeded")


async def test_upgrade_preserves_count_with_logged_in_limit(api, monkeypatch):
    monkeypatch.setattr(settings, "youtube_summary_enabled", True)
    headers, _, before = await guest(api)
    for _ in range(20):
        assert_summary(await save(api, headers))
    assert_summary(await save(api, headers), "skipped", "daily_limit_exceeded")
    tokens = await request(
        api, "POST", "auth/social/kakao/upgrade", headers=headers, json={"token": "upgrade-daily"}
    )
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}
    assert (await request(api, "GET", "users/me", headers=headers))["id"] == before["id"]
    for _ in range(80):
        assert_summary(await save(api, headers))
    assert_summary(await save(api, headers), "skipped", "daily_limit_exceeded")


async def test_worker_retry_does_not_use_new_summary_capacity(api, worker):
    from app.integrations.summary import SummaryError

    run, state = worker
    headers, _, _ = await guest(api)
    first = await save(api, headers)
    state.error = SummaryError("timeout", retryable=True)
    assert await run.run_once()
    retried = await request(api, "GET", f"contents/{first['id']}", headers=headers)
    assert_summary(retried, "queued", "timeout")
    for _ in range(19):
        assert_summary(await save(api, headers))
    assert_summary(await save(api, headers), "skipped", "daily_limit_exceeded")


async def test_summary_kinds_and_save_entries_share_daily_count(api, monkeypatch):
    monkeypatch.setattr(settings, "youtube_summary_enabled", True)
    monkeypatch.setattr(settings, "instagram_summary_enabled", True)
    headers, _, _ = await guest(api)
    for index in range(20):
        assert_summary(
            await save(
                api,
                headers,
                shared=bool(index % 2),
                url=VIDEO if index % 2 else "https://instagram.com/p/XYZ789/",
            )
        )
    assert_summary(
        await save(api, headers, url="https://instagram.com/p/XYZ789/"),
        "skipped",
        "daily_limit_exceeded",
    )


async def test_guest_database_failure_does_not_count(api, database_connection, monkeypatch):
    from app.repositories.auth_session_repository import AuthSessionRepository

    original = AuthSessionRepository.create

    async def fail(*args, **kwargs):
        raise RuntimeError("injected session failure")

    monkeypatch.setattr(AuthSessionRepository, "create", fail)
    assert (await api.post("/api/v1/auth/guest")).status_code == 500
    for model in (User, AuthSession):
        assert await database_connection.scalar(select(func.count()).select_from(model)) == 0
    monkeypatch.setattr(AuthSessionRepository, "create", original)
    for _ in range(20):
        assert (await api.post("/api/v1/auth/guest")).status_code == 201
    assert (await api.post("/api/v1/auth/guest")).status_code == 429
