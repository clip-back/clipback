from datetime import UTC, datetime, timedelta
from types import SimpleNamespace

import httpx
import pytest
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import async_sessionmaker

from app.core.config import settings
from app.integrations.instagram_summary_client import InstagramSummaryClient
from app.integrations.metadata_client import ImageFetch, MetadataClient, MetadataResult, PageMeta
from app.integrations.youtube_summary_client import SummaryError, VideoSummary
from app.models.content import Content
from app.models.content_asset import ContentAsset
from app.models.content_event import ContentEvent
from app.models.summary_job import SummaryJob
from app.services.summary_worker import SummaryWorker
from tests.integration.helpers import guest, request
from tests.integrations.test_instagram_summary_client import page, public_resolver

pytestmark = pytest.mark.asyncio

REEL = "https://www.instagram.com/reel/ABC123/"
SECRET_TEXT = "공유 텍스트 비밀 문장"


def make_worker(database_connection, instagram_client, youtube_client=None):
    from app.services.maintenance import MaintenanceGate

    factory = async_sessionmaker(
        bind=database_connection, expire_on_commit=False, join_transaction_mode="create_savepoint"
    )
    gate = MaintenanceGate(async_sessionmaker(database_connection.engine, expire_on_commit=False))
    return SummaryWorker(
        factory,
        youtube_client or SimpleNamespace(summarize=None),
        settings,
        instagram_client=instagram_client,
        maintenance=gate,
    )


@pytest.fixture
def worker(database_connection, monkeypatch, api):
    monkeypatch.setattr(settings, "instagram_summary_enabled", True)
    state = SimpleNamespace(calls=[], error=None, action=None)

    async def summarize(target_id, model, candidates):
        state.calls.append((target_id, model, candidates))
        if state.action:
            await state.action()
        if state.error:
            raise state.error
        # The last candidate differs from the category recommended at save time.
        return VideoSummary("릴스 제목", "캡션 핵심 안내.", candidates[-1]["id"], {"tokens": 42})

    return make_worker(database_connection, SimpleNamespace(summarize=summarize)), state


async def save(api, headers, *, shared=False, url=REEL, **extra):
    body = {"url" if shared else "original_url": url, **extra}
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


async def category_events(database_connection, user):
    events = (
        await database_connection.execute(
            select(ContentEvent.event_type).where(ContentEvent.user_id == user["id"])
            .order_by(ContentEvent.id)
        )
    ).scalars().all()
    return [event.value for event in events]


async def test_disabled_by_default_and_not_reprocessed_when_enabled_later(
    api, database_connection, monkeypatch
):
    headers, _, _ = await guest(api)
    content = await save(api, headers)
    assert (content["summary_status"], content["summary_error_code"]) == ("skipped", "disabled")

    monkeypatch.setattr(settings, "instagram_summary_enabled", True)
    state = SimpleNamespace(calls=0)

    async def summarize(*args):
        state.calls += 1

    run = make_worker(database_connection, SimpleNamespace(summarize=summarize))
    assert not await run.run_once() and state.calls == 0
    assert (await detail(api, headers, content))["summary_status"] == "skipped"


@pytest.mark.parametrize("shared", [False, True])
async def test_complete_flow_replaces_metadata_and_recommended_category(
    api, worker, shared, database_connection, external_responses
):
    run, state = worker
    headers, _, user = await guest(api)
    content = await save(api, headers, shared=shared, tag_names=["릴스"], is_favorite=True)
    assert content["source"] == "instagram" and content["summary_status"] == "queued"
    assert content["title"] == "통합 제목" and content["summary"] == "통합 설명"
    assert external_responses.ai_calls == 1  # save-time recommendation is unchanged

    assert await run.run_once()

    completed = await detail(api, headers, content)
    assert completed["summary_status"] == "completed" and completed["summary_error_code"] is None
    assert (completed["title"], completed["summary"]) == ("릴스 제목", "캡션 핵심 안내.")
    assert completed["categories"] != content["categories"]
    assert completed["saved_at"] == content["saved_at"] and completed["is_favorite"]
    assert completed["tags"] == content["tags"]
    assert await category_events(database_connection, user) == [
        "content_created", "category_changed",
    ]
    assert not await run.run_once() and len(state.calls) == 1
    assert state.calls[0][:2] == (REEL, settings.instagram_summary_model)


async def test_user_input_and_selected_category_are_preserved(api, worker, database_connection):
    run, _ = worker
    headers, _, user = await guest(api)
    categories = await request(api, "GET", "categories", headers=headers)
    chosen = next(c for c in categories if c["name"] != "미분류")
    content = await save(
        api, headers, title="직접 제목", summary="직접 요약", category_ids=[chosen["id"]]
    )

    await run.run_once()

    result = await detail(api, headers, content)
    assert (result["title"], result["summary"]) == ("직접 제목", "직접 요약")
    assert [c["id"] for c in result["categories"]] == [chosen["id"]]
    assert result["summary_status"] == "completed"
    assert await category_events(database_connection, user) == ["content_created"]


async def test_content_deleted_while_summarizing_is_not_recreated(api, worker, database_connection):
    run, state = worker
    headers, _, _ = await guest(api)
    content = await save(api, headers)

    async def delete():
        await request(api, "DELETE", f"contents/{content['id']}", headers=headers, status=204)

    state.action = delete
    await run.run_once()

    await request(api, "GET", f"contents/{content['id']}", headers=headers, status=404)
    assert await database_connection.scalar(select(func.count()).select_from(SummaryJob)) == 0


async def test_category_deleted_while_summarizing_is_not_assigned(api, worker):
    run, state = worker
    headers, _, _ = await guest(api)
    content = await save(api, headers)

    async def delete_every_custom_category():
        for category in await request(api, "GET", "categories", headers=headers):
            if category["name"] != "미분류":
                await request(
                    api, "DELETE", f"categories/{category['id']}", headers=headers, status=204
                )

    state.action = delete_every_custom_category
    await run.run_once()

    result = await detail(api, headers, content)
    assert [c["name"] for c in result["categories"]] == ["미분류"]
    assert result["summary_status"] == "completed"


async def test_candidates_never_include_other_users_categories(api, worker):
    run, state = worker
    first, _, _ = await guest(api)
    second, _, _ = await guest(api)
    mine = await request(
        api, "POST", "categories", headers=first, status=201, json={"name": "첫째 전용"}
    )
    theirs = await request(
        api, "POST", "categories", headers=second, status=201, json={"name": "둘째 전용"}
    )
    await save(api, first)
    await save(api, second)
    await run.run_once()
    await run.run_once()

    sent = [{c["id"] for c in call[2]} for call in state.calls]
    assert mine["id"] in sent[0] and theirs["id"] not in sent[0]
    assert theirs["id"] in sent[1] and mine["id"] not in sent[1]


async def test_story_is_saved_but_skipped_as_unsupported(api, worker):
    run, state = worker
    headers, _, _ = await guest(api)
    content = await save(api, headers, url="https://www.instagram.com/stories/someone/123456/")

    assert (content["summary_status"], content["summary_error_code"]) == (
        "skipped", "unsupported_content",
    )
    assert not await run.run_once() and state.calls == []


@pytest.mark.parametrize("path", ["reel", "p", "tv"])
async def test_reel_post_and_tv_links_are_queued(api, worker, database_connection, path):
    headers, _, _ = await guest(api)
    url = f"https://www.instagram.com/{path}/XYZ789/?igsh=tracking"
    content = await save(api, headers, url=url)

    assert content["summary_status"] == "queued"
    job = (
        await database_connection.execute(
            select(SummaryJob.kind, SummaryJob.target_id, SummaryJob.model).where(
                SummaryJob.content_id == content["id"]
            )
        )
    ).one()
    assert tuple(job) == (
        "instagram", f"https://www.instagram.com/{path}/XYZ789/", settings.instagram_summary_model,
    )


async def test_missing_caption_is_skipped_without_calling_gpt(
    api, database_connection, monkeypatch
):
    monkeypatch.setattr(settings, "instagram_summary_enabled", True)
    gpt_calls = []

    async def fetch_page(url):
        return PageMeta(url, "success", None, properties={"og:url": REEL})

    async def fetch_image(url, **limits):
        return ImageFetch(failure_reason="http_status_403")

    async def parse(**kwargs):
        gpt_calls.append(kwargs)

    client = InstagramSummaryClient(
        settings,
        SimpleNamespace(fetch_page=fetch_page, fetch_image=fetch_image),
        SimpleNamespace(responses=SimpleNamespace(parse=parse)),
    )
    run = make_worker(database_connection, client)
    headers, _, _ = await guest(api)
    content = await save(api, headers)

    assert await run.run_once()

    result = await detail(api, headers, content)
    assert (result["summary_status"], result["summary_error_code"]) == (
        "skipped", "insufficient_content",
    )
    assert gpt_calls == []
    assert await database_connection.scalar(select(func.count()).select_from(ContentAsset)) == 0
    assert not await run.run_once()


def real_client(page_handler):
    """Real client and page fetching over fake HTTP; GPT is never expected to be reached."""
    requests = []

    def handler(req):
        requests.append(req)
        return page_handler(req)

    async def forbidden(**kwargs):
        raise AssertionError("GPT must not be called")

    metadata = MetadataClient(http_transport=httpx.MockTransport(handler), resolver=public_resolver)
    openai = SimpleNamespace(responses=SimpleNamespace(parse=forbidden))
    return InstagramSummaryClient(settings, metadata, openai), requests


async def make_due(database_connection):
    await database_connection.execute(
        update(SummaryJob).values(next_run_at=datetime.now(UTC) - timedelta(seconds=1))
    )


@pytest.mark.parametrize(
    "handler",
    [
        lambda r: httpx.Response(404),
        lambda r: httpx.Response(410),
        lambda r: page(url="https://example.com/"),
        lambda r: page(url="https://www.instagram.com/p/OTHER99/"),
    ],
    ids=["404", "410", "not_post_metadata", "post_id_mismatch"],
)
async def test_unavailable_post_is_skipped_without_retry(
    api, database_connection, monkeypatch, handler
):
    monkeypatch.setattr(settings, "instagram_summary_enabled", True)
    client, requests = real_client(handler)
    run = make_worker(database_connection, client)
    headers, _, _ = await guest(api)
    content = await save(api, headers)

    assert await run.run_once()

    result = await detail(api, headers, content)
    assert (result["summary_status"], result["summary_error_code"]) == (
        "skipped", "content_unavailable",
    )
    await make_due(database_connection)
    assert not await run.run_once() and len(requests) == 1


@pytest.mark.parametrize("status", [401, 403])
async def test_blocked_page_fails_without_retry(api, database_connection, monkeypatch, status):
    monkeypatch.setattr(settings, "instagram_summary_enabled", True)
    client, requests = real_client(lambda r: httpx.Response(status))
    run = make_worker(database_connection, client)
    headers, _, _ = await guest(api)
    content = await save(api, headers)

    assert await run.run_once()

    result = await detail(api, headers, content)
    assert (result["summary_status"], result["summary_error_code"]) == ("failed", "provider_error")
    await make_due(database_connection)
    assert not await run.run_once() and len(requests) == 1


async def test_unexpected_client_exception_fails_immediately(api, worker, database_connection):
    run, state = worker
    headers, _, _ = await guest(api)
    content = await save(api, headers)
    state.error = RuntimeError("unexpected")

    assert await run.run_once()

    result = await detail(api, headers, content)
    assert (result["summary_status"], result["summary_error_code"]) == ("failed", "provider_error")
    await make_due(database_connection)
    assert not await run.run_once() and len(state.calls) == 1


@pytest.mark.parametrize("status", [429, 500, 503])
async def test_transient_page_status_retries_once_then_fails(
    api, database_connection, monkeypatch, status
):
    monkeypatch.setattr(settings, "instagram_summary_enabled", True)
    client, requests = real_client(lambda r: httpx.Response(status))
    run = make_worker(database_connection, client)
    headers, _, _ = await guest(api)
    content = await save(api, headers)

    await run.run_once()
    queued = await detail(api, headers, content)
    assert (queued["summary_status"], queued["summary_error_code"]) == ("queued", "provider_error")
    wait = await database_connection.scalar(
        select(SummaryJob.next_run_at - func.now()).where(SummaryJob.content_id == content["id"])
    )
    assert timedelta(seconds=25) < wait < timedelta(seconds=35)
    assert not await run.run_once() and len(requests) == 1

    await make_due(database_connection)
    await run.run_once()
    failed = await detail(api, headers, content)
    assert (failed["summary_status"], failed["summary_error_code"]) == ("failed", "provider_error")
    await make_due(database_connection)
    assert not await run.run_once() and len(requests) == 2


async def test_transient_gpt_failure_retries_once_after_thirty_seconds(
    api, worker, database_connection
):
    run, state = worker
    headers, _, _ = await guest(api)
    content = await save(api, headers)
    state.error = SummaryError("provider_error", retryable=True)

    await run.run_once()
    queued = await detail(api, headers, content)
    assert (queued["summary_status"], queued["summary_error_code"]) == (
        "queued", "provider_error",
    )
    wait = await database_connection.scalar(
        select(SummaryJob.next_run_at - func.now()).where(SummaryJob.content_id == content["id"])
    )
    assert timedelta(seconds=25) < wait < timedelta(seconds=35)
    assert not await run.run_once()

    await database_connection.execute(
        update(SummaryJob).values(next_run_at=datetime.now(UTC) - timedelta(seconds=1))
    )
    await run.run_once()
    assert (await detail(api, headers, content))["summary_status"] == "failed"
    await database_connection.execute(
        update(SummaryJob).values(next_run_at=datetime.now(UTC) - timedelta(seconds=1))
    )
    assert not await run.run_once() and len(state.calls) == 2


async def test_mixed_queue_processes_each_kind_with_its_own_client(
    api, database_connection, monkeypatch
):
    monkeypatch.setattr(settings, "youtube_summary_enabled", True)
    monkeypatch.setattr(settings, "instagram_summary_enabled", True)
    calls = []

    def client(kind):
        async def summarize(target_id, model, candidates):
            calls.append((kind, target_id))
            return VideoSummary(f"{kind} 제목", f"{kind} 요약", None, {})

        return SimpleNamespace(summarize=summarize)

    run = make_worker(database_connection, client("instagram"), client("youtube"))
    headers, _, _ = await guest(api)
    video = await save(api, headers, url="https://youtu.be/dQw4w9WgXcQ")
    reel = await save(api, headers)

    assert await run.run_once() and await run.run_once() and not await run.run_once()

    assert calls == [("youtube", "dQw4w9WgXcQ"), ("instagram", REEL)]
    assert (await detail(api, headers, video))["title"] == "youtube 제목"
    assert (await detail(api, headers, reel))["title"] == "instagram 제목"


async def test_instagram_only_worker_leaves_youtube_jobs_queued(
    api, database_connection, monkeypatch
):
    monkeypatch.setattr(settings, "youtube_summary_enabled", True)
    monkeypatch.setattr(settings, "instagram_summary_enabled", True)
    headers, _, _ = await guest(api)
    video = await save(api, headers, url="https://youtu.be/dQw4w9WgXcQ")
    reel = await save(api, headers)
    monkeypatch.setattr(settings, "youtube_summary_enabled", False)

    async def summarize(target_id, model, candidates):
        return VideoSummary("릴스 제목", "릴스 요약", None, {})

    async def forbidden(*args):
        raise AssertionError("youtube must not run")

    run = make_worker(
        database_connection,
        SimpleNamespace(summarize=summarize),
        SimpleNamespace(summarize=forbidden),
    )

    assert run.enabled_kinds() == ["instagram"]
    assert await run.run_once() and not await run.run_once()

    assert (await detail(api, headers, reel))["summary_status"] == "completed"
    left = await detail(api, headers, video)
    assert (left["summary_status"], left["summary_error_code"]) == ("queued", None)


async def test_share_url_resolution_creates_a_job_only_when_it_resolves(
    api, worker, database_connection, monkeypatch
):
    resolved = {"https://www.instagram.com/share/good/": REEL}

    async def metadata(self, url):
        if url in resolved:
            return MetadataResult(resolved[url], "제목", "설명", "success")
        if "/share/" in url:
            return MetadataResult(url, None, None, "failed", "http_status_404")
        return MetadataResult(url, "제목", "설명", "success")

    monkeypatch.setattr(MetadataClient, "extract_from_url", metadata)
    headers, _, _ = await guest(api)

    content = await save(api, headers, shared=True, url="https://www.instagram.com/share/good/")
    assert content["original_url"] == REEL and content["summary_status"] == "queued"

    for route, key in (("contents/share", "url"), ("contents", "original_url")):
        await request(
            api, "POST", route, headers=headers, status=422,
            json={key: "https://www.instagram.com/share/bad/"},
        )
    assert await database_connection.scalar(select(func.count()).select_from(Content)) == 1
    assert await database_connection.scalar(select(func.count()).select_from(SummaryJob)) == 1


async def test_shared_text_is_not_kept_on_the_job(api, worker, database_connection):
    headers, _, _ = await guest(api)
    content = await request(
        api, "POST", "contents/share", headers=headers, status=201,
        json={"url": REEL, "raw_text": f"{SECRET_TEXT} {REEL}"},
    )

    columns = [column.name for column in SummaryJob.__table__.columns]
    assert not any("text" in name for name in columns)
    row = (
        await database_connection.execute(
            select(*SummaryJob.__table__.columns).where(SummaryJob.content_id == content["id"])
        )
    ).one()
    assert SECRET_TEXT not in repr(tuple(row))


async def test_job_is_created_atomically_with_the_content(api, worker, database_connection):
    from sqlalchemy import event

    headers, _, _ = await guest(api)

    def fail(conn, cursor, statement, parameters, context, many):
        if statement.lstrip().startswith("INSERT INTO summary_jobs"):
            raise RuntimeError("injected")

    event.listen(database_connection.sync_connection, "before_cursor_execute", fail)
    try:
        response = await api.post("/api/v1/contents", headers=headers, json={"original_url": REEL})
        assert response.status_code == 500
    finally:
        event.remove(database_connection.sync_connection, "before_cursor_execute", fail)
    for model in (Content, ContentEvent, SummaryJob):
        assert await database_connection.scalar(select(func.count()).select_from(model)) == 0


async def test_job_queued_before_switching_off_resumes_when_switched_on_again(
    api, worker, monkeypatch
):
    run, state = worker
    headers, _, _ = await guest(api)
    content = await save(api, headers)
    assert content["summary_status"] == "queued"

    monkeypatch.setattr(settings, "instagram_summary_enabled", False)
    assert not await run.run_once() and state.calls == []
    waiting = await detail(api, headers, content)
    assert (waiting["summary_status"], waiting["summary_error_code"]) == ("queued", None)

    monkeypatch.setattr(settings, "instagram_summary_enabled", True)
    assert await run.run_once()

    assert (await detail(api, headers, content))["summary_status"] == "completed"
    assert len(state.calls) == 1


async def test_token_usage_of_each_attempt_is_stored_on_the_job(
    api, worker, database_connection
):
    run, state = worker
    headers, _, _ = await guest(api)
    content = await save(api, headers)
    state.error = SummaryError("provider_error", retryable=True)
    state.error.usage = {"input_tokens": 120, "output_tokens": 30, "total_tokens": 150}

    await run.run_once()
    await database_connection.execute(
        update(SummaryJob).values(next_run_at=datetime.now(UTC) - timedelta(seconds=1))
    )
    state.error = None
    await run.run_once()

    usage = await database_connection.scalar(
        select(SummaryJob.usage).where(SummaryJob.content_id == content["id"])
    )
    assert usage == [
        {"attempt": 1, "tokens": {"input_tokens": 120, "output_tokens": 30, "total_tokens": 150}},
        {"attempt": 2, "tokens": {"tokens": 42}},
    ]
