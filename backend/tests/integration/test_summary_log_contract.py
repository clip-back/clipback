"""Locks the summary worker log JSON (spec #147 "로그 계약 표").

Jobs are saved through the API and claimed from PostgreSQL; clients reach fake HTTP only.
"""

import asyncio
import json
import logging
from contextlib import asynccontextmanager, contextmanager
from datetime import UTC, datetime, timedelta
from types import SimpleNamespace

import httpx
import pytest
from openai import AsyncOpenAI
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import async_sessionmaker

from app.core.config import Settings, settings
from app.integrations import instagram_summary_client
from app.integrations.instagram_summary_client import InstagramSummaryClient
from app.integrations.metadata_client import MetadataClient
from app.integrations.youtube_summary_client import YouTubeSummaryClient
from app.models.summary_job import SummaryJob
from app.services.maintenance import MaintenanceError, MaintenanceGate
from app.services.summary_worker import SummaryWorker
from tests.integration.helpers import guest, request
from tests.integrations.test_instagram_summary_client import completion, page, public_resolver
from tests.integrations.test_youtube_summary_client import config as youtube_config, output, video

pytestmark = pytest.mark.asyncio

YOUTUBE_LINK = "https://youtu.be/dQw4w9WgXcQ"
REEL = "https://www.instagram.com/reel/ABC123/"
IMAGE_URL = "https://scontent.cdninstagram.com/v/representative.jpg"
RESULT_KEYS = {
    "event", "kind", "content_id", "model", "elapsed_seconds", "error_code", "provider",
    "http_status", "provider_status", "reason", "retryable", "usage",
}
GEMINI_USAGE = {"promptTokenCount": 100, "candidatesTokenCount": 20}
OPENAI_USAGE = {"input_tokens": 120, "output_tokens": 30, "total_tokens": 150}
NO_IMAGE = {"used": False, "reason": "no_image_url", "http_status": None}


class OpenGate:
    @asynccontextmanager
    async def operation(self, kind):
        yield


class ClosedGate:
    @asynccontextmanager
    async def operation(self, kind):
        raise MaintenanceError("maintenance_required")
        yield


@contextmanager
def worker_logs():
    """Collect the `youtube_summary_*` events from wherever in the app they are logged."""
    records = []

    class Collect(logging.Handler):
        def emit(self, record):
            message = record.getMessage()
            if message.startswith('{"event": "youtube_summary_'):
                records.append(json.loads(message))

    logger = logging.getLogger("app")
    handler, previous = Collect(), logger.level
    logger.setLevel(logging.INFO)
    logger.addHandler(handler)
    try:
        yield records
    finally:
        logger.removeHandler(handler)
        logger.setLevel(previous)


@pytest.fixture
def make_worker(database_connection, monkeypatch, api):
    monkeypatch.setattr(settings, "youtube_summary_enabled", True)
    monkeypatch.setattr(settings, "instagram_summary_enabled", True)
    monkeypatch.setattr(settings, "gemini_model", "gemini-fixed")
    monkeypatch.setattr(settings, "instagram_summary_model", "gpt-fixed")

    def build(*, youtube=None, instagram=None, maintenance=None):
        factory = async_sessionmaker(
            bind=database_connection,
            expire_on_commit=False,
            join_transaction_mode="create_savepoint",
        )
        gate = maintenance or MaintenanceGate(
            async_sessionmaker(database_connection.engine, expire_on_commit=False)
        )
        return SummaryWorker(
            factory, youtube, settings, instagram_client=instagram, maintenance=gate
        )

    return build


async def save(api, url):
    headers, _, _ = await guest(api)
    content = await request(
        api, "POST", "contents", headers=headers, status=201, json={"original_url": url}
    )
    return headers, content


async def result_of(worker):
    with worker_logs() as records:
        assert await worker.run_once()
    (result,) = [r for r in records if r["event"] == "youtube_summary_result"]
    return result


def fake(summarize):
    return SimpleNamespace(summarize=summarize)


def youtube_client(*, preflight=None, gemini=None, config=None):
    """Real client; `preflight` and `gemini` answer the two provider requests."""

    def handler(request):
        if request.method == "GET":
            return preflight(request) if preflight else httpx.Response(200, json=video("PT5M"))
        return gemini(request) if gemini else httpx.Response(200, json=output(category_id=None))

    http = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    return YouTubeSummaryClient(config or youtube_config(), http)


def instagram_client(*, post=None, image=None, openai=None, openai_client=True, page_timeout=5):
    """Real client; `post` serves the page, `image` the image CDN, `openai` the GPT endpoint."""

    def page_side(request):
        if request.headers["host"] == "scontent.cdninstagram.com":
            return image(request)
        return post(request) if post else page()

    metadata = MetadataClient(
        total_timeout_seconds=page_timeout,
        http_transport=httpx.MockTransport(page_side),
        resolver=public_resolver,
    )
    gpt = None
    if openai_client:
        gpt = AsyncOpenAI(
            api_key="test",
            max_retries=0,
            http_client=httpx.AsyncClient(
                transport=httpx.MockTransport(openai or (lambda r: completion(category_id=None)))
            ),
        )
    config = Settings(_env_file=None, youtube_summary_enabled=False, openai_api_key=None)
    return InstagramSummaryClient(config, metadata, gpt)


def failing_with(error):
    def handler(request):
        raise error("injected", request=request)

    return handler


def answer(status=200, **kwargs):
    return lambda request: httpx.Response(status, **kwargs)


def restricted(**details):
    body = video("PT5M")
    body["items"][0]["contentDetails"].update(details)
    return body


def gemini_output(**candidate):
    body = output(category_id=None)
    body["candidates"][0].update(candidate)
    return answer(json=body)


def gemini_text(text):
    body = output(category_id=None)
    body["candidates"][0]["content"]["parts"] = [{"text": text}]
    return answer(json=body)


async def slow_page(request):
    await asyncio.sleep(1)
    return page()


def refusal(request):
    response = completion()
    body = json.loads(response.content)
    body["output"][0]["content"] = [{"type": "refusal", "refusal": "거절"}]
    return httpx.Response(200, json=body)


async def test_claim_log_names_the_job_attempt_and_queue(api, make_worker):
    worker = make_worker(youtube=youtube_client())
    _, content = await save(api, YOUTUBE_LINK)

    with worker_logs() as records:
        assert await worker.run_once()

    assert records[0] == {
        "event": "youtube_summary_claim",
        "kind": "youtube",
        "content_id": content["id"],
        "attempt": 1,
        "recovered": False,
        "possible_duplicate_call": False,
        "pending_count": 1,
    }


async def test_expired_lease_logs_a_stale_result_and_a_recovered_claim(
    api, make_worker, database_connection
):
    async def expire_lease(target_id, model, candidates):
        await database_connection.execute(
            update(SummaryJob).values(lease_expires_at=datetime.now(UTC) - timedelta(seconds=1))
        )
        return SimpleNamespace(title="제목", summary="요약", category_id=None, usage={}, image=None)

    worker = make_worker(instagram=fake(expire_lease))
    _, content = await save(api, REEL)

    with worker_logs() as records:
        assert await worker.run_once()
        assert await worker.run_once()

    events = [r["event"] for r in records]
    assert events == [
        "youtube_summary_claim",
        "youtube_summary_result",
        "youtube_summary_stale_result",
        "youtube_summary_claim",
        "youtube_summary_result",
        "youtube_summary_stale_result",
    ]
    assert records[2] == {"event": "youtube_summary_stale_result", "content_id": content["id"]}
    recovered = records[3]
    assert (recovered["kind"], recovered["attempt"]) == ("instagram", 2)
    assert recovered["recovered"] is True and recovered["possible_duplicate_call"] is True


@pytest.mark.parametrize("kind", ["youtube", "instagram"])
async def test_successful_result_names_the_summary_provider(api, make_worker, kind):
    if kind == "youtube":
        worker, url = make_worker(youtube=youtube_client()), YOUTUBE_LINK
        provider, usage, extra = "gemini", GEMINI_USAGE, {}
        model = "gemini-fixed"
    else:
        worker, url = make_worker(instagram=instagram_client()), REEL
        provider, usage, extra = "openai", OPENAI_USAGE, {"image": NO_IMAGE}
        model = "gpt-fixed"
    _, content = await save(api, url)

    result = await result_of(worker)

    elapsed = result.pop("elapsed_seconds")
    assert isinstance(elapsed, float) and elapsed >= 0
    assert result == {
        "event": "youtube_summary_result",
        "kind": kind,
        "content_id": content["id"],
        "model": model,
        "error_code": None,
        "provider": provider,
        "http_status": None,
        "provider_status": None,
        "reason": None,
        "retryable": False,
        "usage": usage,
        **extra,
    }


@pytest.mark.parametrize(
    "client_kwargs,error_code,provider,http_status,usage",
    [
        (
            {"config": Settings(_env_file=None, youtube_summary_enabled=False)},
            "configuration_error", None, None, {},
        ),
        ({"preflight": answer(403)}, "configuration_error", "youtube", 403, {}),
        ({"preflight": answer(500)}, "provider_error", "youtube", 500, {}),
        ({"preflight": failing_with(httpx.ConnectError)}, "provider_error", "youtube", None, {}),
        ({"preflight": failing_with(httpx.ReadTimeout)}, "timeout", "youtube", None, {}),
        ({"preflight": answer(text="not json")}, "invalid_response", "youtube", 200, {}),
        ({"preflight": answer(json=[1])}, "invalid_response", "youtube", 200, {}),
        (
            {"preflight": answer(json=video(privacy="private"))},
            "video_unavailable", None, None, {},
        ),
        ({"preflight": answer(json=restricted(regionRestriction={"blocked": ["KR"]}))},
         "video_unavailable", None, None, {}),
        ({"preflight": answer(json=restricted(contentRating={"ytRating": "ytAgeRestricted"}))},
         "video_unavailable", None, None, {}),
        ({"preflight": answer(json=video(live="live"))}, "live_not_supported", None, None, {}),
        ({"preflight": answer(json=video("PT20M1S"))}, "duration_exceeded", None, None, {}),
        ({"preflight": answer(json={"items": [{}]})}, "invalid_response", None, None, {}),
        ({"gemini": answer(403)}, "configuration_error", "gemini", 403, {}),
        ({"gemini": answer(429)}, "provider_error", "gemini", 429, {}),
        ({"gemini": failing_with(httpx.ConnectError)}, "provider_error", "gemini", None, {}),
        ({"gemini": failing_with(httpx.ReadTimeout)}, "timeout", "gemini", None, {}),
        ({"gemini": answer(text="not json")}, "invalid_response", "gemini", 200, {}),
        ({"gemini": answer(json=[1])}, "invalid_response", "gemini", 200, {}),
        (
            {"gemini": gemini_output(finishReason="MAX_TOKENS")},
            "invalid_response", None, None, GEMINI_USAGE,
        ),
        ({"gemini": gemini_text("not json")}, "invalid_response", None, None, GEMINI_USAGE),
        (
            {"gemini": gemini_text(json.dumps({"title": "제목", "summary": "요약"}))},
            "invalid_response", None, None, GEMINI_USAGE,
        ),
        (
            {"gemini": answer(json=output(title="가" * 121, category_id=None))},
            "invalid_response", None, None, GEMINI_USAGE,
        ),
    ],
    ids=[
        "missing-keys", "youtube-403", "youtube-500", "youtube-network", "youtube-timeout",
        "youtube-not-json", "youtube-not-object", "private-video", "region-restricted",
        "age-restricted", "live", "too-long",
        "malformed-item", "gemini-403", "gemini-429", "gemini-network", "gemini-timeout",
        "gemini-not-json", "gemini-not-object", "finish-reason", "output-not-json",
        "output-keys", "title-too-long",
    ],
)
async def test_youtube_failure_names_the_stage_that_failed(
    api, make_worker, client_kwargs, error_code, provider, http_status, usage
):
    worker = make_worker(youtube=youtube_client(**client_kwargs))
    await save(api, YOUTUBE_LINK)

    result = await result_of(worker)

    assert set(result) == RESULT_KEYS
    assert (result["kind"], result["error_code"], result["provider"]) == (
        "youtube", error_code, provider,
    )
    assert (result["http_status"], result["usage"]) == (http_status, usage)


@pytest.mark.parametrize(
    "client_kwargs,error_code,provider,image,usage",
    [
        ({"openai_client": False}, "configuration_error", None, None, {}),
        ({"post": answer(403)}, "provider_error", "instagram", None, {}),
        ({"post": answer(404)}, "content_unavailable", "instagram", None, {}),
        ({"post": failing_with(httpx.ConnectError)}, "provider_error", "instagram", None, {}),
        ({"post": failing_with(httpx.ReadTimeout)}, "timeout", "instagram", None, {}),
        ({"post": slow_page, "page_timeout": 0.05}, "timeout", "instagram", None, {}),
        (
            {"post": lambda r: page(description=None, title=None)},
            "insufficient_content", "instagram", NO_IMAGE, {},
        ),
        (
            {
                "post": lambda r: page(description=None, title=None, image=IMAGE_URL),
                "image": answer(403),
            },
            "insufficient_content", "instagram_image",
            {"used": False, "reason": "access_denied", "http_status": 403}, {},
        ),
        ({"openai": answer(503)}, "provider_error", "openai", NO_IMAGE, {}),
        ({"openai": answer(401)}, "configuration_error", "openai", NO_IMAGE, {}),
        ({"openai": failing_with(httpx.ReadTimeout)}, "timeout", "openai", NO_IMAGE, {}),
        (
            {"openai": lambda r: completion(category_id="abc")},
            "invalid_response", "openai", NO_IMAGE, {},
        ),
        ({"openai": refusal}, "invalid_response", "openai", NO_IMAGE, OPENAI_USAGE),
        (
            {"openai": lambda r: completion(title="가" * 121)},
            "invalid_response", "openai", NO_IMAGE, OPENAI_USAGE,
        ),
    ],
    ids=[
        "no-openai-client", "page-403", "page-404", "page-network", "page-read-timeout",
        "page-time-limit",
        "no-caption-or-image-url",
        "unusable-image", "openai-503", "openai-401", "openai-timeout",
        "openai-format", "openai-refusal", "title-too-long",
    ],
)
async def test_instagram_failure_names_the_stage_that_failed(
    api, make_worker, client_kwargs, error_code, provider, image, usage
):
    worker = make_worker(instagram=instagram_client(**client_kwargs))
    await save(api, REEL)

    result = await result_of(worker)

    # `image` is only reported once the post page has been read.
    assert set(result) == RESULT_KEYS | ({"image"} if image else set())
    assert (result["kind"], result["error_code"], result["provider"]) == (
        "instagram", error_code, provider,
    )
    assert (result.get("image"), result["usage"]) == (image, usage)


async def test_instagram_attempt_over_the_time_cap_has_no_provider(
    api, make_worker, monkeypatch
):
    monkeypatch.setattr(instagram_summary_client, "ATTEMPT_TIMEOUT_SECONDS", 0.05)

    async def slow(request):
        await asyncio.sleep(1)
        return completion()

    worker = make_worker(instagram=instagram_client(openai=slow))
    await save(api, REEL)

    result = await result_of(worker)

    assert set(result) == RESULT_KEYS
    assert (result["error_code"], result["provider"], result["retryable"]) == (
        "timeout", None, True,
    )


@pytest.mark.parametrize("kind,url", [("youtube", YOUTUBE_LINK), ("instagram", REEL)])
async def test_unexpected_client_exception_logs_only_its_type(api, make_worker, kind, url):
    async def explode(target_id, model, candidates):
        raise RuntimeError("secret-key private-caption")

    worker = make_worker(**{kind: fake(explode)})
    await save(api, url)

    with worker_logs() as records:
        assert await worker.run_once()

    (result,) = [r for r in records if r["event"] == "youtube_summary_result"]
    assert set(result) == RESULT_KEYS | {"exception_type"}
    assert (result["kind"], result["error_code"], result["provider"]) == (
        kind, "provider_error", None,
    )
    assert (result["reason"], result["exception_type"]) == ("unexpected_error", "RuntimeError")
    assert "secret-key" not in json.dumps(records)


async def test_worker_loop_error_logs_only_the_exception_type():
    def broken_sessions():
        raise RuntimeError("secret-key")

    async def never_called(target_id, model, candidates):
        raise AssertionError("no job can be claimed")

    config = Settings(_env_file=None, youtube_summary_enabled=False)
    config.instagram_summary_enabled = True
    worker = SummaryWorker(
        broken_sessions, None, config, instagram_client=fake(never_called), maintenance=OpenGate()
    )

    with worker_logs() as records:
        loop = asyncio.create_task(worker.run())
        try:
            async with asyncio.timeout(1):
                while not records:
                    await asyncio.sleep(0.01)
        finally:
            loop.cancel()

    assert records == [
        {"event": "youtube_summary_worker_error", "exception_type": "RuntimeError"}
    ]


async def test_nothing_is_logged_without_a_job_to_run(api, make_worker):
    worker = make_worker(youtube=youtube_client())

    with worker_logs() as records:
        assert not await worker.run_once()

    assert records == []


async def test_nothing_is_logged_when_the_last_attempt_is_used_up(
    api, make_worker, database_connection
):
    worker = make_worker(youtube=youtube_client())
    _, content = await save(api, YOUTUBE_LINK)
    await database_connection.execute(update(SummaryJob).values(attempts=2))

    with worker_logs() as records:
        assert not await worker.run_once()

    assert records == []
    stored = await database_connection.execute(
        select(SummaryJob.status, SummaryJob.error_code).where(
            SummaryJob.content_id == content["id"]
        )
    )
    assert tuple(stored.one()) == ("failed", "timeout")


async def test_nothing_is_logged_while_every_kind_is_switched_off(
    api, make_worker, monkeypatch
):
    worker = make_worker(youtube=youtube_client(), instagram=instagram_client())
    await save(api, YOUTUBE_LINK)
    monkeypatch.setattr(settings, "youtube_summary_enabled", False)
    monkeypatch.setattr(settings, "instagram_summary_enabled", False)

    with worker_logs() as records:
        assert not await worker.run_once()

    assert records == []


async def test_nothing_is_logged_during_maintenance(api, make_worker):
    worker = make_worker(youtube=youtube_client(), maintenance=ClosedGate())
    headers, content = await save(api, YOUTUBE_LINK)

    with worker_logs() as records:
        assert not await worker.run_once()

    assert records == []
    detail = await request(api, "GET", f"contents/{content['id']}", headers=headers)
    assert detail["summary_status"] == "queued"
