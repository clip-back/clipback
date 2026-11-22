import asyncio
import json
from datetime import UTC, datetime
from pathlib import Path
from types import SimpleNamespace
from uuid import uuid4

import httpx
import pytest
from alembic.migration import MigrationContext
from alembic.operations import Operations
from alembic.script import ScriptDirectory
from sqlalchemy import insert, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.integrations.metadata_client import MetadataClient
from app.integrations.ocr_client import (
    OCRClient,
    OCRClientError,
    OCRClientInvalidResponseError,
    OCRClientNotConfiguredError,
    OCRClientTimeoutError,
    ScreenshotOCRResult,
)
from app.integrations.summary import SummaryResult
from app.models.content import Content
from app.models.content_event import ContentEvent
from app.models.usage_record import UsageRecord
from app.repositories.usage_record_repository import UsageRecordRepository
from app.services import usage_limits
from app.services.maintenance import MaintenanceGate
from app.services.summary_worker import SummaryWorker
from tests.integration.helpers import guest, request
from tests.integration.test_content_save_flow_contract import (
    CLIENT_TIMEOUT,
    REAL_COMMIT,
    SAVE_PATHS,
    TIME_LIMIT,
    LoopbackTransport,
    flow as flow,
    running_server,
    stored_objects,
)
from tests.integration.test_share_write_concurrency import independent_api as independent_api
from tests.integration.test_summary_usage_records import usage_rows
from tests.integration.test_usage_limits import assert_summary, save

pytestmark = pytest.mark.asyncio

NOW = datetime(2026, 11, 22, 12, tzinfo=UTC)
DEFAULT_TITLE = "저장한 콘텐츠"
DEFAULT_SUMMARY = "요약 정보가 아직 없습니다."
REASON = "monthly_limit_exceeded"


@pytest.fixture(autouse=True)
def decision_clock(monkeypatch):
    monkeypatch.setattr(usage_limits, "now", lambda: NOW)


async def seed_usage(db, user_id, count):
    await db.execute(insert(UsageRecord), [
        {"user_id": user_id, "kind": "ai_summary", "recorded_at": NOW} for _ in range(count)
    ])


async def upgrade(api, headers):
    tokens = await request(
        api, "POST", "auth/social/kakao/upgrade", headers=headers, json={"token": str(uuid4())},
    )
    return {"Authorization": f"Bearer {tokens['access_token']}"}


def with_key(headers):
    return {**headers, "Idempotency-Key": str(uuid4())}


@pytest.fixture
def ocr_probe(monkeypatch, external_responses):
    original = OCRClient.extract
    state = SimpleNamespace(calls=[], result=None, error=None)

    async def ocr(self, **kwargs):
        state.calls.append(kwargs)
        if state.error is not None:
            raise state.error
        if state.result is not None:
            return state.result
        return await original(self, **kwargs)

    monkeypatch.setattr(OCRClient, "extract", ocr)
    return state


async def screenshot(api, headers, png_bytes, **data):
    return await request(
        api, "POST", "uploads/screenshots", headers=headers, status=201,
        files={"file": ("image.png", png_bytes, "image/png")}, data=data,
    )


async def ocr_metadata(db, content_id):
    return json.loads(await db.scalar(
        select(ContentEvent.metadata_json).where(ContentEvent.content_id == content_id)
    ))


@pytest.mark.parametrize("limit", [20, 30], ids=["guest", "member"])
async def test_e2_p4_monthly_limit_still_saves_original(
    api, database_connection, external_responses, ocr_probe, png_bytes, limit,
):
    headers, _, user = await guest(api)
    if limit == 30:
        headers = await upgrade(api, headers)
    await seed_usage(database_connection, user["id"], limit)
    saved = await screenshot(api, headers, png_bytes)
    assert_summary(saved, "skipped", REASON)
    assert saved["title"] == DEFAULT_TITLE and saved["summary"] == DEFAULT_SUMMARY
    assert [category["name"] for category in saved["categories"]] == ["미분류"]
    assert saved["tags"] == []
    assert ocr_probe.calls == [] and external_responses.ai_calls == 0
    assert len(await usage_rows(database_connection, user["id"])) == limit
    meta = await ocr_metadata(database_connection, saved["id"])
    assert (meta["ocr_status"], meta["ocr_failure_reason"]) == ("skipped", REASON)
    original_file = await api.get(saved["assets"][0]["download_url"], headers=headers)
    assert original_file.status_code == 200 and original_file.content == png_bytes


async def test_e1_p1_ocr_success_records_usage_and_recommends(
    api, database_connection, external_responses, ocr_probe, png_bytes,
):
    headers, _, user = await guest(api)
    headers = await upgrade(api, headers)
    await seed_usage(database_connection, user["id"], 29)
    ocr_probe.result = ScreenshotOCRResult(
        text="사진 속 글자", title="사진 제목", summary="사진 요약", tag_names=["사진 주제"],
    )

    saved = await screenshot(api, headers, png_bytes)
    assert_summary(saved, "not_requested")
    assert saved["title"] == "사진 제목" and saved["summary"] == "사진 요약"
    assert [category["name"] for category in saved["categories"]] == ["취업"]
    assert [tag["name"] for tag in saved["tags"]] == ["사진 주제"]
    assert len(ocr_probe.calls) == external_responses.ai_calls == 1
    meta = await ocr_metadata(database_connection, saved["id"])
    assert (meta["ocr_status"], meta["ocr_failure_reason"]) == ("success", None)
    rows = await usage_rows(database_connection, user["id"])
    assert len(rows) == 30 and rows[-1] == ("ai_summary", NOW, saved["id"])


async def test_e3_and_r1_limited_screenshot_keeps_manual_choices_and_replays_current_content(
    api, database_connection, external_responses, ocr_probe, monkeypatch, png_bytes,
):
    headers, _, user = await guest(api)
    headers = await upgrade(api, headers)
    await seed_usage(database_connection, user["id"], 30)
    chosen = await request(
        api, "POST", "categories", status=201, headers=headers, json={"name": "카테고리 A"},
    )
    changed = await request(
        api, "POST", "categories", status=201, headers=headers, json={"name": "카테고리 B"},
    )
    writes = with_key(headers)
    form = {"category_ids": str(chosen["id"]), "tag_names": "여행"}

    saved = await screenshot(api, writes, png_bytes, **form)
    assert_summary(saved, "skipped", REASON)
    assert saved["title"] == DEFAULT_TITLE and saved["summary"] == DEFAULT_SUMMARY
    assert [category["id"] for category in saved["categories"]] == [chosen["id"]]
    assert [tag["name"] for tag in saved["tags"]] == ["여행"]
    meta = await ocr_metadata(database_connection, saved["id"])
    assert (meta["ocr_status"], meta["ocr_failure_reason"]) == ("skipped", REASON)
    rows_before = await usage_rows(database_connection, user["id"])
    assert len(rows_before) == 30
    assert ocr_probe.calls == [] and external_responses.ai_calls == 0

    path = f"contents/{saved['id']}"
    recategorized = await request(
        api, "PUT", f"{path}/categories", headers=headers, json={"category_ids": [changed["id"]]},
    )
    assert [category["id"] for category in recategorized["categories"]] == [changed["id"]]
    assert_summary(recategorized, "skipped", REASON)
    retagged = await request(
        api, "PUT", f"{path}/tags", headers=headers, json={"tag_names": ["현재 태그"]},
    )
    assert [tag["name"] for tag in retagged["tags"]] == ["현재 태그"]
    assert_summary(retagged, "skipped", REASON)
    favorited = await request(
        api, "PUT", f"{path}/favorite", headers=headers, json={"is_favorite": True},
    )
    assert favorited["is_favorite"] is True
    assert_summary(favorited, "skipped", REASON)
    detail = await request(api, "GET", path, headers=headers)
    assert_summary(detail, "skipped", REASON)
    for params in ({}, {"q": DEFAULT_TITLE}):
        feed = await request(api, "GET", "feed", headers=headers, params=params)
        assert len(feed["items"]) == 1 and feed["items"][0] == detail

    monkeypatch.setattr(usage_limits, "now", lambda: datetime(2026, 12, 1, tzinfo=UTC))
    assert await screenshot(api, writes, png_bytes, **form) == detail
    assert ocr_probe.calls == [] and external_responses.ai_calls == 0
    assert await usage_rows(database_connection, user["id"]) == rows_before


@pytest.mark.parametrize(
    "error_type,failure_reason",
    [
        pytest.param(None, None, id="E5-P2-no-text"),
        pytest.param(OCRClientNotConfiguredError, "not_configured", id="E6-P3-not-configured"),
        pytest.param(OCRClientTimeoutError, "timeout", id="E6-P3-timeout"),
        pytest.param(
            OCRClientInvalidResponseError, "invalid_response", id="E6-P3-invalid-response",
        ),
        pytest.param(OCRClientError, "error", id="E6-P3-error"),
    ],
)
async def test_unsuccessful_ocr_does_not_record_usage(
    api, database_connection, external_responses, ocr_probe, png_bytes, error_type, failure_reason,
):
    headers, _, user = await guest(api)
    await seed_usage(database_connection, user["id"], 10)
    rows_before = await usage_rows(database_connection, user["id"])
    ocr_probe.result = ScreenshotOCRResult(text="", title="", summary="")
    ocr_probe.error = error_type() if error_type else None

    saved = await screenshot(api, headers, png_bytes)
    assert_summary(saved, "not_requested")
    assert saved["title"] == DEFAULT_TITLE and saved["summary"] == DEFAULT_SUMMARY
    assert [category["name"] for category in saved["categories"]] == ["미분류"]
    assert saved["tags"] == []
    assert len(ocr_probe.calls) == 1 and external_responses.ai_calls == 0
    meta = await ocr_metadata(database_connection, saved["id"])
    assert meta["ocr_status"] == ("failed" if error_type else "no_text")
    assert meta["ocr_failure_reason"] == failure_reason
    assert await usage_rows(database_connection, user["id"]) == rows_before


async def test_decision_time_is_kept_when_ocr_finishes_in_next_kst_month(
    api, database_connection, monkeypatch, png_bytes,
):
    headers, _, user = await guest(api)
    decided_at = datetime(2026, 11, 30, 14, 59, 59, tzinfo=UTC)
    next_month = datetime(2026, 11, 30, 15, tzinfo=UTC)
    monkeypatch.setattr(usage_limits, "now", lambda: decided_at)
    original = OCRClient.extract

    async def ocr(self, **kwargs):
        monkeypatch.setattr(usage_limits, "now", lambda: next_month)
        return await original(self, **kwargs)

    monkeypatch.setattr(OCRClient, "extract", ocr)
    saved = await screenshot(api, headers, png_bytes)
    assert_summary(saved, "not_requested")
    assert await usage_rows(database_connection, user["id"]) == [
        ("ai_summary", decided_at, saved["id"]),
    ]
    assert await UsageRecordRepository(database_connection).count(
        user["id"], kind="ai_summary", start=next_month,
        end=datetime(2026, 12, 31, 15, tzinfo=UTC),
    ) == 0


async def test_p5_rejected_commit_rolls_back_summary_usage_and_original(
    flow, ocr_probe, monkeypatch, png_bytes,
):
    # Keep the fault and upload shape of the frozen D4-key contract row.
    fail_next_commit = True
    uncommitted_usage = []

    async def commit(session):
        nonlocal fail_next_commit
        if fail_next_commit and session in flow.request_sessions:
            fail_next_commit = False
            uncommitted_usage.extend(await usage_rows(session, flow.user_id))
            raise ConnectionError("injected commit acknowledgement failure")
        await REAL_COMMIT(session)

    monkeypatch.setattr(AsyncSession, "commit", commit)
    path, payload = SAVE_PATHS["screenshot"]
    headers = with_key(flow.headers)
    first = await flow.client.post(f"/api/v1/{path}", headers=headers, **payload(png_bytes))
    assert first.status_code == 500
    assert len(ocr_probe.calls) == 1
    assert len(uncommitted_usage) == 1
    assert uncommitted_usage[0].kind == "ai_summary" and uncommitted_usage[0].recorded_at == NOW
    assert stored_objects(flow) == {}
    async with flow.sessions() as session:
        assert await usage_rows(session, flow.user_id) == []
        assert await session.scalar(select(Content.id).where(
            Content.user_id == flow.user_id,
        )) is None

    retry = await request(
        flow.client, "POST", path, status=201, headers=headers, **payload(png_bytes),
    )
    assert_summary(retry, "not_requested")
    async with flow.sessions() as session:
        assert await usage_rows(session, flow.user_id) == [("ai_summary", NOW, retry["id"])]
    assert len(ocr_probe.calls) == 2
    assert list(stored_objects(flow).values()) == [png_bytes]


async def test_r5_lost_http_response_replays_without_new_ocr_usage_or_original(
    flow, monkeypatch, png_bytes,
):
    # Same server, transport and upload as the frozen screenshot-after_server_finished row.
    entered, release, finished = asyncio.Event(), asyncio.Event(), asyncio.Event()
    calls = []
    original = OCRClient.extract

    async def ocr(self, **kwargs):
        calls.append(kwargs)
        entered.set()
        await release.wait()
        return await original(self, **kwargs)

    async def served(scope, receive, send):
        try:
            await flow.asgi(scope, receive, send)
        finally:
            finished.set()

    monkeypatch.setattr(OCRClient, "extract", ocr)
    path, payload = SAVE_PATHS["screenshot"]
    headers = with_key(flow.headers)
    async with running_server(served) as port, httpx.AsyncClient(
        transport=LoopbackTransport(), base_url=f"http://127.0.0.1:{port}",
        timeout=httpx.Timeout(TIME_LIMIT),
    ) as client:
        try:
            with pytest.raises(httpx.ReadTimeout):
                await client.post(
                    f"/api/v1/{path}", headers=headers,
                    timeout=httpx.Timeout(TIME_LIMIT, read=CLIENT_TIMEOUT), **payload(png_bytes),
                )
            assert entered.is_set() and not finished.is_set()
        finally:
            release.set()
        await asyncio.wait_for(finished.wait(), TIME_LIMIT)
        async with flow.sessions() as session:
            rows_before = await usage_rows(session, flow.user_id)
        assert len(rows_before) == len(calls) == 1
        originals_before = stored_objects(flow)
        assert list(originals_before.values()) == [png_bytes]
        assert flow.errors == []

        retry = await request(
            client, "POST", path, status=201, headers=headers, **payload(png_bytes),
        )
        assert_summary(retry, "not_requested")
        assert rows_before == [("ai_summary", NOW, retry["id"])]
        async with flow.sessions() as session:
            assert await usage_rows(session, flow.user_id) == rows_before
        assert len(calls) == 1 and stored_objects(flow) == originals_before
        downloaded = await client.get(retry["assets"][0]["download_url"], headers=headers)
        assert downloaded.status_code == 200 and downloaded.content == png_bytes


async def wait_until_blocked(sessions, holder, waiter):
    while True:
        async with sessions() as session:
            blockers = await session.scalar(
                text("SELECT pg_blocking_pids(:waiter)"), {"waiter": waiter},
            )
            if holder in blockers:
                return
        await asyncio.sleep(0.02)


@pytest.mark.parametrize("same_key", [False, True], ids=["X1-different-key", "X2-same-key"])
async def test_overlapping_screenshots_share_one_remaining_summary(
    independent_api, external_responses, png_bytes, monkeypatch, same_key,
):
    api, headers, user_id, sessions, pids, _ = independent_api
    headers = await upgrade(api, headers)
    async with sessions.begin() as session:
        await seed_usage(session, user_id, 29)

    entered, release = asyncio.Event(), asyncio.Event()
    calls = []
    original = OCRClient.extract

    async def ocr(self, **kwargs):
        calls.append(kwargs)
        entered.set()
        await release.wait()
        return await original(self, **kwargs)

    monkeypatch.setattr(OCRClient, "extract", ocr)
    first_headers = with_key(headers)
    second_headers = first_headers if same_key else with_key(headers)
    async with asyncio.timeout(10), asyncio.TaskGroup() as tasks:
        first = tasks.create_task(screenshot(api, first_headers, png_bytes))
        await entered.wait()
        holder_index = len(pids) - 1
        second = tasks.create_task(screenshot(api, second_headers, png_bytes))
        while len(pids) == holder_index + 1:
            await asyncio.sleep(0.02)
        holder, waiter = pids[holder_index:holder_index + 2]
        assert holder != waiter
        await wait_until_blocked(sessions, holder, waiter)
        async with sessions() as session:
            assert len(await usage_rows(session, user_id)) == 29
        assert len(calls) == 1 and not second.done()
        release.set()

    first_saved, second_saved = first.result(), second.result()
    assert_summary(first_saved, "not_requested")
    if same_key:
        assert second_saved == first_saved
    else:
        assert second_saved["id"] != first_saved["id"]
        assert_summary(second_saved, "skipped", REASON)
    assert len(calls) == external_responses.ai_calls == 1
    async with sessions() as session:
        rows = await usage_rows(session, user_id)
        saved_ids = set(await session.scalars(select(Content.id).where(Content.user_id == user_id)))
    assert len(rows) == 30
    assert [row.content_id for row in rows if row.content_id is not None] == [first_saved["id"]]
    assert saved_ids == {first_saved["id"], second_saved["id"]}


async def test_x3_overlapping_screenshot_and_youtube_can_both_use_last_slot(
    independent_api, external_responses, png_bytes, monkeypatch,
):
    api, headers, user_id, sessions, pids, _ = independent_api
    headers = await upgrade(api, headers)
    monkeypatch.setattr(settings, "youtube_summary_enabled", True)
    async with sessions.begin() as session:
        await seed_usage(session, user_id, 29)

    entered, release = asyncio.Event(), asyncio.Event()
    ocr_calls, metadata_calls = [], []
    original = OCRClient.extract

    async def ocr(self, **kwargs):
        ocr_calls.append(kwargs)
        entered.set()
        await release.wait()
        return await original(self, **kwargs)

    async def metadata(self, url):
        metadata_calls.append(url)
        raise AssertionError("YouTube saves do not extract link metadata")

    monkeypatch.setattr(OCRClient, "extract", ocr)
    monkeypatch.setattr(MetadataClient, "extract_from_url", metadata)
    async with asyncio.timeout(10), asyncio.TaskGroup() as tasks:
        photo = tasks.create_task(screenshot(api, with_key(headers), png_bytes))
        await entered.wait()
        photo_pid = pids[-1]
        link = await save(api, headers, key=str(uuid4()))
        assert pids[-1] != photo_pid
        assert_summary(link)
        assert not photo.done()
        async with sessions() as session:
            assert len(await usage_rows(session, user_id)) == 30
        assert metadata_calls == [] and external_responses.ai_calls == 0
        release.set()

    assert_summary(photo.result(), "not_requested")
    assert len(ocr_calls) == external_responses.ai_calls == 1
    async with sessions() as session:
        rows = await usage_rows(session, user_id)
    assert len(rows) == 31
    assert {row.content_id for row in rows if row.content_id is not None} == {
        link["id"], photo.result()["id"],
    }

    summary_calls = []

    async def summarize(*args):
        summary_calls.append(args)
        return SummaryResult("영상 제목", "영상 요약", None, {})

    worker = SummaryWorker(
        sessions, SimpleNamespace(summarize=summarize), settings,
        maintenance=MaintenanceGate(sessions),
    )
    assert await worker.run_once()
    assert len(summary_calls) == 1
    detail = await request(api, "GET", f"contents/{link['id']}", headers=headers)
    assert_summary(detail, "completed")


async def test_downgrades_screenshot_reason_then_link_usage_on_the_same_database(
    api, database_connection, monkeypatch, png_bytes,
):
    monkeypatch.setattr(settings, "youtube_summary_enabled", True)
    headers, _, user = await guest(api)
    await seed_usage(database_connection, user["id"], 20)
    photo = await screenshot(api, headers, png_bytes)
    link = await save(api, headers)
    assert_summary(photo, "skipped", REASON)
    assert_summary(link, "skipped", REASON)
    assert await database_connection.scalar(select(Content.screenshot_summary_skip_reason).where(
        Content.id == photo["id"],
    )) == REASON

    def downgrade_screenshot_and_link(connection):
        migrations = ScriptDirectory(str(Path(__file__).resolve().parents[2] / "alembic"))
        with Operations.context(MigrationContext.configure(connection)):
            migrations.get_revision("202611220025").module.downgrade()
            assert not connection.scalar(text("""
                SELECT EXISTS (
                    SELECT 1 FROM information_schema.columns WHERE table_schema = 'public'
                    AND table_name = 'contents' AND column_name = 'screenshot_summary_skip_reason'
                )
            """))
            assert connection.scalar(text("SELECT to_regclass('usage_records')")) is not None
            migrations.get_revision("202611220024").module.downgrade()

    await database_connection.run_sync(downgrade_screenshot_and_link)
    assert await database_connection.scalar(text("SELECT to_regclass('usage_records')")) is None
    assert await database_connection.scalar(
        text("SELECT error_code FROM summary_jobs WHERE content_id = :id"), {"id": link["id"]},
    ) == "daily_limit_exceeded"
    assert await database_connection.scalar(
        text("SELECT title FROM contents WHERE id = :id"), {"id": photo["id"]},
    ) == DEFAULT_TITLE
