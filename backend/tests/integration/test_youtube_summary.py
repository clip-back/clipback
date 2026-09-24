from datetime import UTC, datetime, timedelta
from types import SimpleNamespace

import pytest
from sqlalchemy import event, func, select, update
from sqlalchemy.ext.asyncio import async_sessionmaker

from app.core.config import settings
from app.integrations.youtube_summary_client import SummaryError, VideoSummary
from app.models.content import Content
from app.models.content_event import ContentEvent
from app.models.summary_job import SummaryJob
from app.services.summary_worker import SummaryWorker
from tests.integration.helpers import guest, request

pytestmark = pytest.mark.asyncio


@pytest.fixture
def worker(database_connection, monkeypatch, api):
    # api lifespan starts disabled; run_once is the only worker invocation in these tests.
    monkeypatch.setattr(settings, "youtube_summary_enabled", True)
    state = SimpleNamespace(calls=0, error=None, action=None)

    async def summarize(video_id, model, candidates):
        state.calls += 1
        if state.action:
            await state.action()
        if state.error:
            raise state.error
        return VideoSummary("영상 제목", "핵심 사실 안내.", candidates[0]["id"], {"tokens": 42})

    factory = async_sessionmaker(
        bind=database_connection, expire_on_commit=False, join_transaction_mode="create_savepoint"
    )
    return SummaryWorker(factory, SimpleNamespace(summarize=summarize), settings), state


async def save(api, headers, *, shared=False, **extra):
    body = {"url" if shared else "original_url": "https://youtu.be/dQw4w9WgXcQ?si=x&t=1m", **extra}
    return await request(
        api,
        "POST",
        "contents/share" if shared else "contents",
        headers=headers,
        status=201,
        json=body,
    )


async def detail(api, headers, content):
    return await request(api, "GET", f"contents/{content['id']}", headers=headers)


async def test_disabled_and_legacy(api):
    headers, _, _ = await guest(api)
    content = await save(api, headers)
    assert (content["summary_status"], content["summary_error_code"]) == ("skipped", "disabled")
    assert (await detail(api, headers, content))["summary_status"] == "skipped"


@pytest.mark.parametrize("shared", [False, True])
async def test_complete_flow(api, worker, shared, database_connection, external_responses):
    run, state = worker
    headers, _, user = await guest(api)
    content = await save(api, headers, shared=shared, tag_names=["유튜브"], is_favorite=True)
    assert content["summary_status"] == "queued"
    assert content["source"] == "youtube" and content["original_url"].endswith("&t=60s")
    assert external_responses.ai_calls == 0
    assert await run.run_once()
    completed = await detail(api, headers, content)
    assert completed["summary_status"] == "completed" and completed["summary_error_code"] is None
    assert completed["summary"] == "핵심 사실 안내." and completed["title"] == "영상 제목"
    assert completed["categories"][0]["name"] != "미분류"
    assert completed["saved_at"] == content["saved_at"] and completed["is_favorite"]
    assert completed["tags"] == content["tags"]
    assert await request(api, "GET", "users/me/stats", headers=headers) == {
        "saved_count": 1,
        "reopened_count": 0,
    }
    page = await request(api, "GET", "feed", headers=headers)
    assert page["items"][0]["summary_status"] == "completed"
    events = (
        await database_connection.execute(
            select(ContentEvent.event_type, ContentEvent.category_ids_at_event)
            .where(ContentEvent.user_id == user["id"])
            .order_by(ContentEvent.id)
        )
    ).all()
    assert [(kind.value, ids) for kind, ids in events] == [
        ("content_created", [c["id"] for c in content["categories"]]),
        ("category_changed", None),
    ]
    assert not await run.run_once() and state.calls == 1


async def test_manual_fields_and_category_noop_are_preserved(api, worker):
    run, state = worker
    headers, _, _ = await guest(api)
    content = await save(api, headers, title="직접 제목", summary="직접 요약")

    async def manual():
        await request(
            api,
            "PUT",
            f"contents/{content['id']}/categories",
            headers=headers,
            json={"category_ids": [c["id"] for c in content["categories"]]},
        )

    state.action = manual
    await run.run_once()
    result = await detail(api, headers, content)
    assert result["categories"] == content["categories"]
    assert result["title"] == "직접 제목" and result["summary"] == "직접 요약"
    assert result["summary_status"] == "completed"


async def test_category_deletion_and_initial_manual_selection(api, worker, database_connection):
    run, state = worker
    headers, _, user = await guest(api)
    categories = await request(api, "GET", "categories", headers=headers)
    category = next(c for c in categories if c["name"] != "미분류")
    content = await save(api, headers, category_ids=[category["id"]])

    async def delete():
        await request(api, "DELETE", f"categories/{category['id']}", headers=headers, status=204)

    state.action = delete
    await run.run_once()
    assert (await detail(api, headers, content))["categories"][0]["name"] == "미분류"
    events = (
        await database_connection.execute(
            select(ContentEvent.event_type, ContentEvent.category_ids_at_event)
            .where(ContentEvent.user_id == user["id"])
            .order_by(ContentEvent.id)
        )
    ).all()
    assert [(kind.value, ids) for kind, ids in events] == [
        ("content_created", [category["id"]]),
        ("category_changed", None),
    ]


async def test_content_deleted_during_processing(api, worker, database_connection):
    run, state = worker
    headers, _, _ = await guest(api)
    content = await save(api, headers)

    async def delete():
        await request(api, "DELETE", f"contents/{content['id']}", headers=headers, status=204)

    state.action = delete
    await run.run_once()
    await request(api, "GET", f"contents/{content['id']}", headers=headers, status=404)
    assert await database_connection.scalar(select(func.count()).select_from(SummaryJob)) == 0
    assert await request(api, "GET", "users/me/stats", headers=headers) == {
        "saved_count": 1,
        "reopened_count": 0,
    }


async def test_retry_once_pause_and_resume(api, worker, database_connection, monkeypatch):
    run, state = worker
    headers, _, _ = await guest(api)
    content = await save(api, headers)
    state.error = SummaryError("timeout", retryable=True)
    await run.run_once()
    result = await detail(api, headers, content)
    assert result["summary_status"] == "queued" and result["summary_error_code"] == "timeout"
    assert not await run.run_once()
    await database_connection.execute(
        update(SummaryJob).values(next_run_at=datetime.now(UTC) - timedelta(seconds=1))
    )
    monkeypatch.setattr(settings, "youtube_summary_enabled", False)
    assert not await run.run_once()
    monkeypatch.setattr(settings, "youtube_summary_enabled", True)
    await run.run_once()
    assert (await detail(api, headers, content))["summary_status"] == "failed"
    assert not await run.run_once() and state.calls == 2


async def test_lease_recovery_fencing_and_exhaustion(api, worker, database_connection):
    run, _ = worker
    headers, _, user = await guest(api)
    content = await save(api, headers)
    first = await run.claim()
    assert first and not await run.claim()
    await database_connection.execute(
        update(SummaryJob).values(lease_expires_at=datetime.now(UTC) - timedelta(seconds=1))
    )
    second = await run.claim()
    assert second and second[4] != first[4]
    await run.finish(
        content["id"], user["id"], first[4], VideoSummary("old", "old", None, {}), None
    )
    assert (await detail(api, headers, content))["summary_status"] == "processing"
    await database_connection.execute(
        update(SummaryJob).values(lease_expires_at=datetime.now(UTC) - timedelta(seconds=1))
    )
    assert not await run.claim()
    assert (await detail(api, headers, content))["summary_status"] == "failed"


async def test_atomic_save_rollback(api, worker, database_connection):
    headers, _, _ = await guest(api)

    def fail(conn, cursor, statement, parameters, context, many):
        if statement.lstrip().startswith("INSERT INTO summary_jobs"):
            raise RuntimeError("injected")

    event.listen(database_connection.sync_connection, "before_cursor_execute", fail)
    try:
        response = await api.post(
            "/api/v1/contents",
            headers=headers,
            json={"original_url": "https://youtu.be/dQw4w9WgXcQ"},
        )
        assert response.status_code == 500
    finally:
        event.remove(database_connection.sync_connection, "before_cursor_execute", fail)
    for model in (Content, ContentEvent, SummaryJob):
        assert await database_connection.scalar(select(func.count()).select_from(model)) == 0


async def test_user_isolation_and_batch_loading(api, worker, database_connection):
    run, _ = worker
    first, _, _ = await guest(api)
    second, _, _ = await guest(api)
    one = await save(api, first)
    await save(api, second)
    await run.run_once()
    await run.run_once()
    await request(api, "GET", f"contents/{one['id']}", headers=second, status=404)
    a = await detail(api, first, one)
    second_categories = await request(api, "GET", "categories", headers=second)
    assert a["categories"][0]["id"] not in {c["id"] for c in second_categories}
    for _ in range(3):
        await save(api, first)
    statements = []

    def count(conn, cursor, statement, parameters, context, many):
        if "FROM summary_jobs" in statement:
            statements.append(statement)

    event.listen(database_connection.sync_connection, "before_cursor_execute", count)
    try:
        page = await request(api, "GET", "feed", headers=first)
    finally:
        event.remove(database_connection.sync_connection, "before_cursor_execute", count)
    assert len(page["items"]) == 4 and len(statements) == 1


@pytest.mark.parametrize(
    "code,skipped",
    [("configuration_error", False), ("invalid_response", False), ("duration_exceeded", True)],
)
async def test_permanent_error_does_not_retry(api, worker, code, skipped):
    run, state = worker
    headers, _, _ = await guest(api)
    content = await save(api, headers)
    state.error = SummaryError(code, skipped=skipped)
    await run.run_once()
    result = await detail(api, headers, content)
    assert result["summary_status"] == ("skipped" if skipped else "failed")
    assert result["summary_error_code"] == code
    assert not await run.run_once() and state.calls == 1


async def test_retry_success_and_deleted_recommendation(api, worker, database_connection):
    run, state = worker
    headers, _, _ = await guest(api)
    content = await save(api, headers)
    state.error = SummaryError("provider_error", retryable=True)
    await run.run_once()
    state.error = None
    await database_connection.execute(
        update(SummaryJob).values(next_run_at=datetime.now(UTC) - timedelta(seconds=1))
    )
    categories = await request(api, "GET", "categories", headers=headers)
    category = next(c for c in categories if c["name"] != "미분류")

    async def remove_recommendation():
        await request(api, "DELETE", f"categories/{category['id']}", headers=headers, status=204)

    state.action = remove_recommendation
    await run.run_once()
    result = await detail(api, headers, content)
    assert result["summary_status"] == "completed" and result["summary_error_code"] is None
    assert result["categories"] == content["categories"]
    assert state.calls == 2


@pytest.mark.parametrize("shared", [False, True])
async def test_invalid_video_and_auth_do_not_save(api, worker, database_connection, shared):
    headers, _, _ = await guest(api)
    route = "contents/share" if shared else "contents"
    key = "url" if shared else "original_url"
    await request(
        api,
        "POST",
        route,
        headers=headers,
        status=422,
        json={key: "https://youtube.com/playlist?list=abc"},
    )
    await request(api, "POST", route, status=401, json={key: "https://youtu.be/dQw4w9WgXcQ"})
    assert await database_connection.scalar(select(func.count()).select_from(SummaryJob)) == 0


async def test_shared_text_url_overrides_source_app(api, worker):
    headers, _, _ = await guest(api)
    content = await request(
        api,
        "POST",
        "contents/share",
        headers=headers,
        status=201,
        json={
            "raw_text": "영상 공유 https://www.youtube.com/shorts/dQw4w9WgXcQ?si=test",
            "source_app": "instagram",
        },
    )
    assert content["source"] == "youtube" and content["summary_status"] == "queued"
