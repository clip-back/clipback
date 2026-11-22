import asyncio
import json
from datetime import UTC, datetime, timedelta
from types import SimpleNamespace
from uuid import uuid4

import httpx
import pytest
from sqlalchemy import select, text, update
from sqlalchemy.ext.asyncio import async_sessionmaker

from app.core.config import settings
from app.core.security import create_access_token, decode_access_token
from app.db.session import get_db
from app.integrations.deletion_ledger import get_deletion_ledger
from app.integrations.metadata_client import MetadataClient
from app.integrations.ocr_client import OCRClient, OCRClientNotConfiguredError
from app.integrations.summary import SummaryError, SummaryResult
from app.main import create_app
from app.models.content import Content
from app.models.content_event import ContentEvent
from app.models.summary_job import SummaryJob
from app.repositories.event_repository import EventRepository
from app.services import summary_worker, usage_limits
from app.services.account_deletion_service import record_account_deletion
from app.services.maintenance import MaintenanceGate
from app.services.summary_worker import SummaryWorker
from tests.integration.helpers import guest, request
from tests.integration.test_account_deletion import session_for
from tests.integration.test_image_deletion import committed_api as committed_api
from tests.integration.test_usage_limits import VIDEO, assert_summary, save, worker as worker

pytestmark = pytest.mark.asyncio


async def usage_rows(db, user_id):
    return (await db.execute(text("""
        SELECT kind, recorded_at, content_id FROM usage_records
        WHERE user_id = :id ORDER BY recorded_at, id
    """), {"id": user_id})).all()


async def test_youtube_at_the_monthly_limit_stays_uncategorized(
    api, database_connection, external_responses, monkeypatch, worker,
):
    _, provider = worker
    tokens = await request(api, "POST", "auth/social/kakao", json={"token": str(uuid4())})
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}
    user = await request(api, "GET", "users/me", headers=headers)
    first_day = datetime(2026, 11, 1, tzinfo=UTC)
    monkeypatch.setattr(usage_limits, "now", lambda: first_day)
    for _ in range(30):
        assert_summary(await save(api, headers))

    monkeypatch.setattr(usage_limits, "now", lambda: first_day + timedelta(days=29))
    result = await save(api, headers)
    assert_summary(result, "skipped", "monthly_limit_exceeded")
    assert [category["name"] for category in result["categories"]] == ["미분류"]
    assert result["tags"] == []
    assert external_responses.ai_calls == provider.calls == 0
    assert len(await usage_rows(database_connection, user["id"])) == 30


async def test_screenshot_without_ocr_configuration_does_not_create_summary_usage(
    api, database_connection, monkeypatch, png_bytes,
):
    async def not_configured(*args, **kwargs):
        raise OCRClientNotConfiguredError()

    monkeypatch.setattr(OCRClient, "extract", not_configured)
    headers, _, user = await guest(api)
    saved = await request(
        api, "POST", "uploads/screenshots", status=201, headers=headers,
        files={"file": ("image.png", png_bytes, "image/png")},
    )
    metadata = await database_connection.scalar(
        select(ContentEvent.metadata_json).where(ContentEvent.content_id == saved["id"])
    )
    assert_summary(saved, "not_requested")
    assert json.loads(metadata)["ocr_status"] == "failed"
    assert await usage_rows(database_connection, user["id"]) == []


async def test_link_rollback_reverts_summary_usage_and_can_retry(
    api, database_connection, monkeypatch,
):
    monkeypatch.setattr(settings, "youtube_summary_enabled", True)
    headers, _, user = await guest(api)
    key = str(uuid4())
    original = EventRepository.create
    flushed_content_ids = []

    async def fail_after_flush(self, **kwargs):
        event = await original(self, **kwargs)
        flushed_content_ids.extend(
            row.content_id for row in await usage_rows(self.session, user["id"])
            if row.content_id == event.content_id
        )
        raise RuntimeError("Injected save failure after flushing the event")

    with monkeypatch.context() as fault:
        fault.setattr(EventRepository, "create", fail_after_flush)
        response = await api.post(
            "/api/v1/contents", headers={**headers, "Idempotency-Key": key},
            json={"original_url": VIDEO},
        )
        assert (response.status_code, response.text) == (500, "Internal Server Error")
    assert len(flushed_content_ids) == 1
    assert await usage_rows(database_connection, user["id"]) == []
    assert await database_connection.scalar(
        select(Content.id).where(Content.user_id == user["id"])
    ) is None
    result = await save(api, headers, key=key)
    assert_summary(result)
    assert [row.content_id for row in await usage_rows(database_connection, user["id"])] == [
        result["id"],
    ]


async def test_link_replay_returns_current_state_without_using_quota(
    api, database_connection, worker,
):
    run, provider = worker
    headers, tokens, user = await guest(api)
    key = str(uuid4())
    saved = await save(api, headers, key=key)
    assert_summary(saved)
    assert await run.run_once()

    replay_headers = {**headers, "Idempotency-Key": key}
    changed = {"original_url": VIDEO, "title": "다른 본문"}
    expired = create_access_token(
        user_id=user["id"], session_id=decode_access_token(tokens["access_token"]).session_id,
        expires_delta=timedelta(seconds=-1),
    )
    same = await save(api, headers, key=key)
    assert same["id"] == saved["id"]
    assert_summary(same, "completed")
    await request(api, "POST", "contents", status=409, headers=replay_headers, json=changed)
    await request(
        api, "POST", "contents", status=401,
        headers={**replay_headers, "Authorization": f"Bearer {expired}"},
        json={"original_url": VIDEO},
    )
    await request(api, "DELETE", f"contents/{saved['id']}", headers=headers, status=204)
    await request(
        api, "POST", "contents", status=410, headers=replay_headers, json={"original_url": VIDEO},
    )
    rows = await usage_rows(database_connection, user["id"])
    assert len(rows) == provider.calls == 1
    assert rows[0].kind == "ai_summary" and rows[0].content_id is None


async def test_guest_monthly_count_survives_a_new_app(api, database_connection, monkeypatch):
    monkeypatch.setattr(settings, "youtube_summary_enabled", True)
    headers, _, user = await guest(api)
    for _ in range(20):
        assert_summary(await save(api, headers))

    gate = MaintenanceGate(async_sessionmaker(database_connection.engine, expire_on_commit=False))
    fresh_app = create_app(maintenance=gate)

    async def db():
        async with session_for(database_connection) as session:
            yield session

    fresh_app.dependency_overrides[get_db] = db
    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=fresh_app), base_url="http://test",
    ) as fresh_api:
        assert_summary(await save(fresh_api, headers), "skipped", "monthly_limit_exceeded")
    assert len(await usage_rows(database_connection, user["id"])) == 20


@pytest.mark.parametrize(
    "code,retryable,skipped,attempts",
    [("provider_error", False, False, 0), ("video_unavailable", False, True, 0),
     ("timeout", True, False, 1), ("timeout", True, False, 2)],
)
async def test_terminal_summary_releases_usage(
    api, database_connection, worker, code, retryable, skipped, attempts,
):
    run, provider = worker
    headers, _, user = await guest(api)
    saved = await save(api, headers)
    assert len(await usage_rows(database_connection, user["id"])) == 1
    await database_connection.execute(
        update(SummaryJob).where(SummaryJob.content_id == saved["id"]).values(attempts=attempts)
    )
    provider.error = SummaryError(code, retryable=retryable, skipped=skipped)
    assert await run.run_once() == (attempts < 2)
    assert provider.calls == int(attempts < 2)
    result = await request(api, "GET", f"contents/{saved['id']}", headers=headers)
    assert_summary(result, "skipped" if skipped else "failed", code)
    assert await usage_rows(database_connection, user["id"]) == []


async def test_stale_failure_cannot_release_a_completed_summary(api, database_connection, worker):
    run, provider = worker
    headers, _, user = await guest(api)
    saved = await save(api, headers)

    async def recover_during_call():
        provider.action = None
        await database_connection.execute(
            update(SummaryJob).where(SummaryJob.content_id == saved["id"]).values(
                lease_expires_at=datetime.now(UTC) - timedelta(seconds=1),
            )
        )
        assert await run.run_once()
        provider.error = SummaryError("provider_error")

    provider.action = recover_during_call
    assert await run.run_once()
    assert provider.calls == 2
    result = await request(api, "GET", f"contents/{saved['id']}", headers=headers)
    assert_summary(result, "completed")
    assert [row.content_id for row in await usage_rows(database_connection, user["id"])] == [
        saved["id"],
    ]


async def test_deletion_while_processing_keeps_usage(api, database_connection, worker):
    run, provider = worker
    headers, _, user = await guest(api)
    saved = await save(api, headers)

    async def delete_while_processing():
        current = await request(api, "GET", f"contents/{saved['id']}", headers=headers)
        assert_summary(current, "processing")
        await request(api, "DELETE", f"contents/{saved['id']}", headers=headers, status=204)

    provider.action = delete_while_processing
    provider.error = SummaryError("provider_error")
    assert await run.run_once()
    rows = await usage_rows(database_connection, user["id"])
    assert len(rows) == 1 and rows[0].content_id is None


async def test_failure_releases_the_original_month_only(
    api, database_connection, monkeypatch, worker,
):
    run, provider = worker
    headers, _, user = await guest(api)
    previous = datetime(2026, 11, 30, 14, 59, 59, tzinfo=UTC)
    current = previous + timedelta(seconds=1)
    monkeypatch.setattr(usage_limits, "now", lambda: previous)
    previous_saved = await save(api, headers)
    monkeypatch.setattr(usage_limits, "now", lambda: current)
    saved = await save(api, headers)
    await database_connection.execute(
        update(SummaryJob).where(SummaryJob.content_id == previous_saved["id"])
        .values(next_run_at=previous)
    )
    await database_connection.execute(
        update(SummaryJob).where(SummaryJob.content_id == saved["id"])
        .values(next_run_at=current)
    )

    class WorkerClock(datetime):
        @classmethod
        def now(cls, tz=None):
            return current.astimezone(tz)

    monkeypatch.setattr(summary_worker, "datetime", WorkerClock)
    assert [tuple(row) for row in await usage_rows(database_connection, user["id"])] == [
        ("ai_summary", previous, previous_saved["id"]), ("ai_summary", current, saved["id"]),
    ]
    provider.error = SummaryError("provider_error")
    assert await run.run_once()
    assert_summary(
        await request(api, "GET", f"contents/{previous_saved['id']}", headers=headers),
        "failed", "provider_error",
    )
    assert [tuple(row) for row in await usage_rows(database_connection, user["id"])] == [
        ("ai_summary", current, saved["id"]),
    ]


async def test_new_usage_prunes_only_rows_before_previous_kst_month(
    api, database_connection, monkeypatch,
):
    monkeypatch.setattr(settings, "youtube_summary_enabled", True)
    headers, _, user = await guest(api)
    _, _, other = await guest(api)
    cutoff = datetime(2026, 10, 31, 15, tzinfo=UTC)
    old = cutoff - timedelta(seconds=1)
    december_start = datetime(2026, 11, 30, 15, tzinfo=UTC)
    december = datetime(2026, 12, 15, tzinfo=UTC)
    await database_connection.execute(text("""
        INSERT INTO usage_records (user_id, kind, recorded_at)
        VALUES (:account, :kind, :recorded_at)
    """), [
        {"account": user["id"], "kind": "ai_summary", "recorded_at": old},
        {"account": user["id"], "kind": "ai_summary", "recorded_at": cutoff},
        {"account": user["id"], "kind": "ai_summary", "recorded_at": december_start},
        {"account": other["id"], "kind": "ai_summary", "recorded_at": old},
    ])
    monkeypatch.setattr(usage_limits, "now", lambda: december)
    await save(api, headers)
    assert [row.recorded_at for row in await usage_rows(database_connection, user["id"])] == [
        cutoff, december_start, december,
    ]
    assert [row.recorded_at for row in await usage_rows(database_connection, other["id"])] == [old]


@pytest.mark.parametrize("via", ["api", "replay"])
async def test_account_deletion_cascades_usage(api, database_connection, monkeypatch, via):
    monkeypatch.setattr(settings, "youtube_summary_enabled", True)
    headers, _, user = await guest(api)
    first = await save(api, headers)
    await save(api, headers)
    await request(api, "DELETE", f"contents/{first['id']}", headers=headers, status=204)
    assert len(await usage_rows(database_connection, user["id"])) == 2

    if via == "api":
        await request(
            api, "DELETE", "users/me", headers=headers, json={"reasons": ["rejoin"]}, status=204,
        )
    else:
        from scripts import recovery_deletions

        async with session_for(database_connection) as session:
            assert await record_account_deletion(session, user["id"]) is not None
            await session.rollback()
        events = get_deletion_ledger().read_verified_events()
        monkeypatch.setattr(
            recovery_deletions, "AsyncSessionLocal", lambda: session_for(database_connection),
        )
        await recovery_deletions.apply(events)
    assert await usage_rows(database_connection, user["id"]) == []
    await request(api, "GET", "users/me", headers=headers, status=401)


async def wait_for_submission_lock(sessions, holder):
    while True:
        async with sessions() as session:
            if await session.scalar(text("""
                SELECT EXISTS (
                    SELECT 1 FROM pg_locks held JOIN pg_locks waiting
                    USING (locktype, database, classid, objid, objsubid)
                    WHERE held.locktype = 'advisory' AND held.pid = :holder
                      AND held.granted AND NOT waiting.granted
                )
            """), {"holder": holder}):
                return
        await asyncio.sleep(0.02)


@pytest.mark.parametrize("same_key,expected", [(False, 31), (True, 30)])
async def test_overlapping_youtube_saves(  # noqa: F811
    committed_api, external_responses, monkeypatch, same_key, expected,
):
    api, guest_headers, sessions = committed_api
    monkeypatch.setattr(settings, "youtube_summary_enabled", True)
    tokens = await request(
        api, "POST", "auth/social/kakao/upgrade",
        headers=guest_headers, json={"token": str(uuid4())},
    )
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}
    user = await request(api, "GET", "users/me", headers=headers)
    metadata_calls = []

    async def unexpected_metadata(*args):
        metadata_calls.append(args)
        raise AssertionError("YouTube saves do not extract link metadata")

    monkeypatch.setattr(MetadataClient, "extract_from_url", unexpected_metadata)
    completed_ids = []
    for _ in range(29):
        saved = await save(api, headers)
        assert_summary(saved)
        completed_ids.append(saved["id"])
    async with sessions.begin() as session:
        assert len(await usage_rows(session, user["id"])) == 29
        await session.execute(
            update(SummaryJob).where(SummaryJob.content_id.in_(completed_ids))
            .values(status="completed")
        )

    original = EventRepository.create
    reached_first = asyncio.Event()
    reached_second = asyncio.Event()
    release = asyncio.Event()
    pids = []

    async def pause_before_commit(self, **kwargs):
        event = await original(self, **kwargs)
        pid = await self.session.scalar(text("SELECT pg_backend_pid()"))
        pids.append(pid)
        (reached_first if len(pids) == 1 else reached_second).set()
        await release.wait()
        return event

    monkeypatch.setattr(EventRepository, "create", pause_before_commit)
    first_key = str(uuid4())
    async with asyncio.timeout(10), asyncio.TaskGroup() as tasks:
        first = tasks.create_task(save(api, headers, key=first_key))
        await reached_first.wait()
        second = tasks.create_task(save(api, headers, key=first_key if same_key else str(uuid4())))
        if same_key:
            await wait_for_submission_lock(sessions, pids[0])
            assert not reached_second.is_set()
        else:
            await reached_second.wait()
            assert pids[0] != pids[1]
        async with sessions() as session:
            assert len(await usage_rows(session, user["id"])) == 29
        release.set()

    results = [first.result(), second.result()]
    assert len(pids) == expected - 29
    assert (results[0]["id"] == results[1]["id"]) is same_key
    assert metadata_calls == [] and external_responses.ai_calls == 0
    for result in results:
        assert_summary(result)
    async with sessions() as session:
        rows = await usage_rows(session, user["id"])
        contents = set(await session.scalars(
            select(Content.id).where(Content.user_id == user["id"])
        ))
    assert len(rows) == len(contents) == expected
    assert {row.content_id for row in rows} == contents

    calls = []

    async def summarize(*args):
        calls.append(args)
        return SummaryResult("영상 제목", "• 핵심 사실 안내.", None, {})

    run = SummaryWorker(
        sessions, SimpleNamespace(summarize=summarize), settings,
        maintenance=MaintenanceGate(sessions),
    )
    for _ in range(expected - 29):
        assert await run.run_once()
    assert not await run.run_once()
    assert len(calls) == expected - 29
