import json

import httpx
import pytest

from app.core.config import Settings
from app.integrations.youtube_summary_client import SummaryError, YouTubeSummaryClient


def config():
    return Settings(
        _env_file=None,
        youtube_summary_enabled=True,
        gemini_api_key="test",
        youtube_data_api_key="test",
    )


def video(duration="PT20M", privacy="public", live="none"):
    return {
        "items": [
            {
                "status": {"privacyStatus": privacy},
                "snippet": {"title": "제목", "liveBroadcastContent": live},
                "contentDetails": {"duration": duration},
            }
        ]
    }


def output(title="영상 제목", summary="핵심 내용 안내.", category_id=1):
    return {
        "candidates": [
            {
                "finishReason": "STOP",
                "content": {
                    "parts": [
                        {
                            "text": json.dumps(
                                {"title": title, "summary": summary, "category_id": category_id}
                            )
                        }
                    ]
                },
            }
        ],
        "usageMetadata": {"promptTokenCount": 100, "candidatesTokenCount": 20},
    }


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "data,code",
    [
        (video("PT20M1S"), "duration_exceeded"),
        (video("P1DT0S"), "duration_exceeded"),
        (video(privacy="unlisted"), "video_unavailable"),
        (video(privacy="private"), "video_unavailable"),
        ({"items": []}, "video_unavailable"),
        (video(live="live"), "live_not_supported"),
        (video(live="upcoming"), "live_not_supported"),
        (video("PT0S"), "video_unavailable"),
        (video("bad"), "invalid_response"),
        ({"items": [{}]}, "invalid_response"),
    ],
)
async def test_preflight_blocks_gemini(data, code):
    calls = []

    def handler(request):
        calls.append(request)
        return httpx.Response(200, json=data)

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as http:
        with pytest.raises(SummaryError) as exc:
            await YouTubeSummaryClient(config(), http).summarize("dQw4w9WgXcQ", "model", [])
    assert exc.value.code == code
    assert len(calls) == 1


@pytest.mark.asyncio
@pytest.mark.parametrize("duration", ["PT1S", "PT20M"])
async def test_success_and_invalid_category(duration):
    calls = []

    def handler(request):
        calls.append(request)
        if request.method == "GET":
            return httpx.Response(200, json=video(duration))
        body = json.loads(request.content)
        assert "t=" not in body["contents"][0]["parts"][0]["fileData"]["fileUri"]
        assert "tools" not in body
        return httpx.Response(200, json=output(category_id=999))

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as http:
        result = await YouTubeSummaryClient(config(), http).summarize(
            "dQw4w9WgXcQ", "model", [{"id": 1}]
        )
    assert result.summary == "핵심 내용 안내." and result.category_id is None
    assert result.usage["promptTokenCount"] == 100
    assert len(calls) == 2


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "status,code,retry",
    [
        (429, "provider_error", True),
        (503, "provider_error", True),
        (403, "configuration_error", False),
        (400, "provider_error", False),
    ],
)
async def test_http_errors(status, code, retry):
    async with httpx.AsyncClient(
        transport=httpx.MockTransport(lambda r: httpx.Response(status, json={"error": "secret"}))
    ) as http:
        with pytest.raises(SummaryError) as exc:
            await YouTubeSummaryClient(config(), http).summarize("dQw4w9WgXcQ", "model", [])
    assert (exc.value.code, exc.value.retryable) == (code, retry)
    assert "secret" not in str(exc.value)


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "data",
    [
        output(summary=" "),
        output(title="a" * 121),
        output(summary="a" * 501),
        {"candidates": [{"finishReason": "SAFETY"}]},
        {},
    ],
)
async def test_invalid_output(data):
    async with httpx.AsyncClient(
        transport=httpx.MockTransport(
            lambda r: httpx.Response(200, json=video() if r.method == "GET" else data)
        )
    ) as http:
        with pytest.raises(SummaryError) as exc:
            await YouTubeSummaryClient(config(), http).summarize("dQw4w9WgXcQ", "model", [])
    assert exc.value.code == "invalid_response" and not exc.value.retryable


@pytest.mark.asyncio
async def test_timeout():
    def handler(request):
        raise httpx.ReadTimeout("secret", request=request)

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as http:
        with pytest.raises(SummaryError) as exc:
            await YouTubeSummaryClient(config(), http).summarize("dQw4w9WgXcQ", "model", [])
    assert exc.value.code == "timeout" and exc.value.retryable


def test_keys_required_only_when_enabled():
    assert not Settings(_env_file=None).youtube_summary_enabled
    with pytest.raises(ValueError):
        Settings(_env_file=None, youtube_summary_enabled=True)
