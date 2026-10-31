import json
import logging
import os
import subprocess
import sys
from io import StringIO
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import AsyncMock

import httpx
import pytest

from app.integrations.youtube_summary_client import YouTubeSummaryClient
from app.services.summary_worker import SummaryWorker
from tests.integrations.test_instagram_summary_client import page, public_resolver
from tests.integrations.test_youtube_summary_client import config, video


def test_application_info_logs_are_visible_without_http_library_logs():
    result = subprocess.run(
        [
            sys.executable,
            "-c",
            """
import logging
from logging.config import dictConfig
from uvicorn.config import LOGGING_CONFIG
from app.core.logging import configure_logging

dictConfig(LOGGING_CONFIG)
configure_logging()
configure_logging()
logging.getLogger("app.services.summary_worker").info("summary-visible")
logging.getLogger("httpx").info("secret-request-url")
""",
        ],
        cwd=Path(__file__).resolve().parents[2],
        env=os.environ.copy(),
        capture_output=True,
        text=True,
        check=True,
    )
    assert result.stderr.count("summary-visible") == 1
    assert "secret-request-url" not in result.stderr + result.stdout


@pytest.mark.asyncio
@pytest.mark.parametrize("provider,status", [("youtube", 400), ("gemini", 404), ("gemini", 429)])
async def test_worker_logs_safe_provider_diagnostics(provider, status):
    def handler(request):
        if provider == "gemini" and request.method == "GET":
            return httpx.Response(200, json=video())
        return httpx.Response(
            status,
            json={
                "error": {
                    "status": "RESOURCE_EXHAUSTED" if status == 429 else "INVALID_ARGUMENT",
                    "message": "secret-key private-video-url",
                }
            },
        )

    output = StringIO()
    logger = logging.getLogger("app.services.summary_worker")
    handler_log = logging.StreamHandler(output)
    logger.addHandler(handler_log)
    try:
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as http:
            from tests.support.maintenance import OpenUnitGate

            worker = SummaryWorker(
                None, YouTubeSummaryClient(config(), http), config(), maintenance=OpenUnitGate()
            )
            worker.claim = AsyncMock(
                return_value=(12, 7, "dQw4w9WgXcQ", "model", "token", [], "youtube")
            )
            worker.finish = AsyncMock()
            await worker.run_once()
            worker.finish.assert_awaited_once()
    finally:
        logger.removeHandler(handler_log)
    record = json.loads(output.getvalue())
    assert record["content_id"] == 12
    assert record["provider"] == provider and record["http_status"] == status
    assert record["retryable"] == (status == 429)
    assert record["provider_status"] is not None
    assert "secret-key" not in output.getvalue() and "private-video-url" not in output.getvalue()


@pytest.mark.asyncio
async def test_unknown_provider_status_is_not_retained():
    async with httpx.AsyncClient(
        transport=httpx.MockTransport(
            lambda r: httpx.Response(400, json={"error": {"status": "secret"}})
        )
    ) as http:
        from app.integrations.youtube_summary_client import SummaryError

        with pytest.raises(SummaryError) as caught:
            await YouTubeSummaryClient(config(), http).summarize("dQw4w9WgXcQ", "model", [])
    assert caught.value.provider_status is None
    assert caught.value.http_status == 400


def instagram_worker(client, config_overrides=None):
    from app.core.config import Settings
    from tests.support.maintenance import OpenUnitGate

    settings = Settings(_env_file=None, youtube_summary_enabled=False, openai_api_key="secret-key")
    settings.instagram_summary_enabled = True
    worker = SummaryWorker(
        None, None, settings, instagram_client=client, maintenance=OpenUnitGate()
    )
    worker.claim = AsyncMock(
        return_value=(
            12, 7, "https://www.instagram.com/reel/ABC123/", "model", "token", [], "instagram"
        )
    )
    worker.finish = AsyncMock()
    return worker, settings


async def logged_record(worker):
    output = StringIO()
    logger = logging.getLogger("app.services.summary_worker")
    handler_log = logging.StreamHandler(output)
    previous_level = logger.level
    logger.setLevel(logging.INFO)
    logger.addHandler(handler_log)
    try:
        await worker.run_once()
    finally:
        logger.removeHandler(handler_log)
        logger.setLevel(previous_level)
    return json.loads(output.getvalue()), output.getvalue()


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "stage,page_status,openai_status,http_status,retryable",
    [
        ("instagram", 403, None, 403, False),
        ("instagram", 503, None, 503, True),
        ("openai", 200, 429, 429, True),
        ("openai", 200, None, None, False),
    ],
)
async def test_worker_logs_instagram_failure_stage_without_sensitive_data(
    stage, page_status, openai_status, http_status, retryable
):
    from openai import AsyncOpenAI

    from app.core.config import Settings
    from app.integrations.instagram_summary_client import InstagramSummaryClient
    from app.integrations.metadata_client import MetadataClient
    from tests.integrations.test_instagram_summary_client import completion, page, public_resolver

    def page_handler(request):
        if page_status != 200:
            return httpx.Response(page_status, text="secret-page-body")
        return page(description='1 likes - a on b: "비밀 캡션 private-caption"')

    def openai_handler(request):
        if openai_status:
            return httpx.Response(
                openai_status, json={"error": {"message": "secret-key private-caption"}}
            )
        # An out-of-range title makes the otherwise successful answer invalid.
        return completion(title="가" * 121)

    metadata = MetadataClient(
        http_transport=httpx.MockTransport(page_handler), resolver=public_resolver
    )
    openai = AsyncOpenAI(
        api_key="secret-key",
        max_retries=0,
        http_client=httpx.AsyncClient(transport=httpx.MockTransport(openai_handler)),
    )
    config = Settings(_env_file=None, youtube_summary_enabled=False, openai_api_key="secret-key")
    worker, _ = instagram_worker(InstagramSummaryClient(config, metadata, openai))

    record, raw = await logged_record(worker)

    assert record["kind"] == "instagram" and record["content_id"] == 12
    assert record["provider"] == stage and record["http_status"] == http_status
    assert record["retryable"] == retryable
    assert record["error_code"] is not None
    # A page failure never reached GPT; an invalid answer still reports the tokens it used.
    assert record["usage"] == ({"input_tokens": 120, "output_tokens": 30, "total_tokens": 150}
                               if stage == "openai" and not openai_status else {})
    for secret in ("private-caption", "secret-key", "secret-page-body", "instagram.com"):
        assert secret not in raw


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "page_response,error_code,http_status,reason,retryable",
    [
        (lambda: httpx.Response(404, text="secret-page-body"),
         "content_unavailable", 404, "not_found", False),
        (lambda: httpx.Response(401, text="secret-page-body"),
         "provider_error", 401, "access_denied", False),
        (lambda: httpx.Response(403, text="secret-page-body"),
         "provider_error", 403, "access_denied", False),
        (lambda: httpx.Response(429, text="secret-page-body"),
         "provider_error", 429, "rate_limited", True),
        (lambda: httpx.Response(502, text="secret-page-body"),
         "provider_error", 502, "server_error", True),
        (lambda: page(url="https://example.com/secret-other-site"),
         "content_unavailable", 200, "not_post_metadata", False),
        (lambda: page(url="https://www.instagram.com/p/SECRET99/"),
         "content_unavailable", 200, "post_id_mismatch", False),
        (lambda: page(description=None, title=None, url="https://www.instagram.com/p/ABC123/"),
         "insufficient_content", 200, "no_caption_or_image", False),
    ],
)
async def test_worker_logs_the_page_decision_without_sensitive_data(
    page_response, error_code, http_status, reason, retryable
):
    from app.core.config import Settings
    from app.integrations.instagram_summary_client import InstagramSummaryClient
    from app.integrations.metadata_client import MetadataClient

    metadata = MetadataClient(
        http_transport=httpx.MockTransport(lambda request: page_response()),
        resolver=public_resolver,
    )
    config = Settings(_env_file=None, youtube_summary_enabled=False, openai_api_key="secret-key")
    worker, _ = instagram_worker(InstagramSummaryClient(config, metadata, SimpleNamespace()))

    record, raw = await logged_record(worker)

    assert (record["kind"], record["provider"], record["error_code"]) == (
        "instagram", "instagram", error_code,
    )
    assert (record["http_status"], record["reason"], record["retryable"]) == (
        http_status, reason, retryable,
    )
    assert record["usage"] == {}
    # No caption, image address, request URL, response body, key or provider message.
    for secret in (
        "성수동", "private-caption", "cdn.example.com", "ABC123", "SECRET99", "instagram.com",
        "secret-page-body", "secret-key", "example.com",
    ):
        assert secret not in raw


@pytest.mark.asyncio
async def test_worker_logs_usage_and_openai_provider_for_a_successful_instagram_summary():
    from app.integrations.youtube_summary_client import VideoSummary

    async def summarize(target, model, candidates):
        return VideoSummary("제목", "요약", None, {"total_tokens": 150})

    worker, _ = instagram_worker(SimpleNamespace(summarize=summarize))

    record, _ = await logged_record(worker)

    assert record["provider"] == "openai" and record["usage"] == {"total_tokens": 150}
    assert record["error_code"] is None and record["reason"] is None
