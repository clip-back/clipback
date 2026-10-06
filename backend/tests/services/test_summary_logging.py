import json
import logging
import os
import subprocess
import sys
from io import StringIO
from pathlib import Path
from unittest.mock import AsyncMock

import httpx
import pytest

from app.integrations.youtube_summary_client import YouTubeSummaryClient
from app.services.summary_worker import SummaryWorker
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
            worker = SummaryWorker(None, YouTubeSummaryClient(config(), http), config())
            worker.claim = AsyncMock(return_value=(12, 7, "dQw4w9WgXcQ", "model", "token", []))
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
