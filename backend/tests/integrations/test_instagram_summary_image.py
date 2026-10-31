import asyncio
import base64
import json
from html import escape
from io import BytesIO

import httpx
import pytest
from openai import AsyncOpenAI
from PIL import Image

from app.core.config import Settings
from app.integrations import instagram_summary_client as module
from app.integrations.instagram_summary_client import InstagramSummaryClient
from app.integrations.metadata_client import MetadataClient
from app.integrations.youtube_summary_client import SummaryError
from tests.integrations.test_instagram_summary_client import (
    CATEGORIES,
    PAGE_HOST,
    POST_URL,
    TARGET,
    completion,
    public_resolver,
)
from tests.services.test_summary_logging import instagram_worker, logged_record

IMAGE_HOST = "scontent.cdninstagram.com"
IMAGE_URL = f"https://{IMAGE_HOST}/v/t51/secret-token.jpg?sig=signed-token"
CAPTION = '38K likes, 369 comments - cafe on June 16, 2026: "성수동 카페 신메뉴 출시."'


def picture(image_format="JPEG"):
    buffer = BytesIO()
    Image.new("RGB", (8, 6), "red").save(buffer, image_format)
    return buffer.getvalue()


def page(*, caption=CAPTION, image=IMAGE_URL):
    tags = [f'<meta property="og:url" content="{POST_URL}">']
    if caption is not None:
        tags.append(f'<meta property="og:description" content="{escape(caption)}">')
    if image is not None:
        tags.append(f'<meta property="og:image" content="{escape(image)}">')
    html = f"<html><head>{''.join(tags)}</head></html>"
    return httpx.Response(200, headers={"content-type": "text/html"}, text=html)


def image_response(content=None, content_type="image/jpeg"):
    body = picture() if content is None else content
    return httpx.Response(200, headers={"content-type": content_type}, content=body)


def build(page_response, image_handler, openai_handler=lambda r: completion(), resolver=None):
    """Page, image CDN and OpenAI fakes; the transport routes by Host header."""
    seen = {"page": [], "image": [], "openai": []}

    def route(request):
        if request.headers["host"] == PAGE_HOST:
            seen["page"].append(request)
            return page_response
        seen["image"].append(request)
        return image_handler(request)

    def openai_side(request):
        seen["openai"].append(request)
        return openai_handler(request)

    metadata = MetadataClient(
        http_transport=httpx.MockTransport(route), resolver=resolver or public_resolver
    )
    openai = AsyncOpenAI(
        api_key="test",
        max_retries=0,
        http_client=httpx.AsyncClient(transport=httpx.MockTransport(openai_side)),
    )
    config = Settings(_env_file=None, youtube_summary_enabled=False, openai_api_key="test")
    return InstagramSummaryClient(config, metadata, openai), seen


async def summarize(client):
    return await client.summarize(TARGET, "gpt-test", CATEGORIES)


def sent_content(seen):
    (call,) = seen["openai"]
    return json.loads(call.content)["input"][1]["content"]


def sent_images(seen):
    return [part for part in sent_content(seen) if part["type"] == "input_image"]


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "image_format,mime", [("JPEG", "image/jpeg"), ("PNG", "image/png"), ("WEBP", "image/webp")]
)
async def test_request_carries_the_caption_and_the_representative_image(image_format, mime):
    content = picture(image_format)
    client, seen = build(page(), lambda r: image_response(content, "application/octet-stream"))

    result = await summarize(client)

    assert result.title == "성수동 카페 소개"
    assert [(r.headers["host"], r.url.path) for r in seen["image"]] == [
        (IMAGE_HOST, "/v/t51/secret-token.jpg")
    ]
    (image,) = sent_images(seen)
    assert image["image_url"] == f"data:{mime};base64,{base64.b64encode(content).decode()}"
    assert "성수동 카페 신메뉴 출시." in json.dumps(sent_content(seen), ensure_ascii=False)


@pytest.mark.asyncio
async def test_summarizes_from_the_image_alone_when_there_is_no_caption():
    client, seen = build(page(caption=None), lambda r: image_response())

    assert (await summarize(client)).title == "성수동 카페 소개"
    assert len(sent_images(seen)) == 1


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "response",
    [
        image_response(picture("GIF"), "image/gif"),
        image_response(picture("BMP"), "image/bmp"),
        image_response(b"x" * (10 * 1024 * 1024 + 1)),
        image_response(b"<html>login</html>", "text/html"),
        image_response(b"not an image at all"),
        httpx.Response(403),
        httpx.Response(404),
        httpx.Response(429),
        httpx.Response(503),
        httpx.Response(302, headers={"location": "https://127.0.0.1/a.jpg"}),
    ],
    ids=["gif", "bmp", "over-10mb", "html", "garbage", "403", "404", "429", "503", "redirect"],
)
async def test_unusable_image_falls_back_to_the_caption_without_retrying(response):
    client, seen = build(page(), lambda r: response)

    result = await summarize(client)

    assert result.title == "성수동 카페 소개"
    assert len(seen["image"]) == 1
    assert sent_images(seen) == []
    assert "성수동 카페 신메뉴 출시." in json.dumps(sent_content(seen), ensure_ascii=False)


@pytest.mark.asyncio
async def test_image_taking_longer_than_five_seconds_is_dropped(monkeypatch):
    monkeypatch.setattr(module, "IMAGE_TIMEOUT_SECONDS", 0.05)

    async def slow(request):
        await asyncio.sleep(1)
        return image_response()

    client, seen = build(page(), slow)

    assert (await summarize(client)).title == "성수동 카페 소개"
    assert len(seen["image"]) == 1 and sent_images(seen) == []


def test_limits_match_the_specification():
    assert module.IMAGE_TIMEOUT_SECONDS == 5
    assert module.MAX_IMAGE_BYTES == 10 * 1024 * 1024
    assert module.OPENAI_TIMEOUT_SECONDS == 60
    assert module.ATTEMPT_TIMEOUT_SECONDS == 90


@pytest.mark.asyncio
async def test_internal_image_address_is_never_requested():
    async def resolver(hostname, port):
        return {"10.0.0.5"} if hostname == IMAGE_HOST else {"93.184.216.34"}

    client, seen = build(page(), lambda r: image_response(), resolver=resolver)

    assert (await summarize(client)).title == "성수동 카페 소개"
    assert seen["image"] == [] and sent_images(seen) == []


@pytest.mark.asyncio
async def test_relative_image_address_is_resolved_against_the_page():
    client, seen = build(page(image="/cover.jpg"), lambda r: image_response())

    await summarize(client)

    # Same host as the page, so the fake routes it to the page handler.
    assert [r.url.path for r in seen["page"]] == ["/reel/ABC123/", "/cover.jpg"]


@pytest.mark.asyncio
async def test_malformed_image_address_falls_back_to_the_caption():
    client, seen = build(page(image="https://[broken/image.jpg"), lambda r: image_response())

    result = await summarize(client)

    assert result.title == "성수동 카페 소개"
    assert seen["image"] == [] and sent_images(seen) == []
    assert "성수동 카페 신메뉴 출시." in json.dumps(sent_content(seen), ensure_ascii=False)

    worker, _ = instagram_worker(build(page(image="https://[broken/image.jpg"), None)[0])
    record, raw = await logged_record(worker)
    assert record["error_code"] is None
    assert record["image"] == {"used": False, "reason": "invalid_url", "http_status": None}
    assert "broken" not in raw


@pytest.mark.asyncio
@pytest.mark.parametrize("over_limit", [1, Image.MAX_IMAGE_PIXELS + 1], ids=["warning", "error"])
async def test_image_over_the_decompression_bomb_limit_falls_back_to_the_caption(over_limit):
    # Pillow's default bomb guard is the resolution limit: past it the image counts as unusable.
    width = 10_000
    height = (Image.MAX_IMAGE_PIXELS + over_limit) // width + 1
    buffer = BytesIO()
    Image.new("1", (width, height)).save(buffer, "PNG")
    content = buffer.getvalue()
    assert len(content) <= module.MAX_IMAGE_BYTES
    client, seen = build(page(), lambda r: image_response(content, "image/png"))

    result = await summarize(client)

    assert result.title == "성수동 카페 소개"
    assert len(seen["image"]) == 1 and sent_images(seen) == []
    assert "성수동 카페 신메뉴 출시." in json.dumps(sent_content(seen), ensure_ascii=False)


@pytest.mark.asyncio
async def test_page_without_representative_image_requests_none():
    client, seen = build(page(image=None), lambda r: image_response())

    await summarize(client)

    assert seen["image"] == [] and sent_images(seen) == []


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "image,response,provider,http_status",
    [
        (None, None, "instagram", 200),
        ("https://[broken/image.jpg", None, "instagram", 200),
        (IMAGE_URL, httpx.Response(403), "instagram_image", 403),
        (IMAGE_URL, image_response(b"not an image"), "instagram_image", None),
    ],
)
async def test_no_caption_and_no_usable_image_skips_without_calling_gpt(
    image, response, provider, http_status
):
    client, seen = build(page(caption=None, image=image), lambda r: response)

    with pytest.raises(SummaryError) as exc:
        await summarize(client)

    error = exc.value
    assert (error.code, error.skipped, error.retryable) == ("insufficient_content", True, False)
    assert (error.provider, error.http_status) == (provider, http_status)
    assert error.reason == "no_caption_or_image"
    assert seen["openai"] == []


@pytest.mark.asyncio
async def test_one_attempt_is_capped_at_ninety_seconds(monkeypatch):
    monkeypatch.setattr(module, "ATTEMPT_TIMEOUT_SECONDS", 0.05)

    async def slow(request):
        await asyncio.sleep(1)
        return completion()

    client, seen = build(page(), lambda r: image_response(), slow)

    with pytest.raises(SummaryError) as exc:
        await summarize(client)

    assert (exc.value.code, exc.value.retryable, exc.value.skipped) == ("timeout", True, False)
    assert len(seen["openai"]) == 1


@pytest.mark.asyncio
async def test_image_failure_log_names_the_stage_without_the_image_address():
    client, _ = build(page(caption=None), lambda r: httpx.Response(403, text="secret-body"))
    worker, _ = instagram_worker(client)

    record, raw = await logged_record(worker)

    assert record["provider"] == "instagram_image" and record["http_status"] == 403
    assert record["error_code"] == "insufficient_content"
    assert record["reason"] == "no_caption_or_image"
    for secret in ("secret-token", "signed-token", IMAGE_HOST, "cdninstagram", "secret-body"):
        assert secret not in raw


def sensitive_image_response(status):
    return httpx.Response(status, text="secret-body")


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "image_response_value,expected",
    [
        (image_response(), {"used": True, "reason": None, "http_status": None}),
        (
            sensitive_image_response(403),
            {"used": False, "reason": "access_denied", "http_status": 403},
        ),
        (
            sensitive_image_response(404),
            {"used": False, "reason": "not_found", "http_status": 404},
        ),
        (
            sensitive_image_response(410),
            {"used": False, "reason": "gone", "http_status": 410},
        ),
        (
            sensitive_image_response(429),
            {"used": False, "reason": "rate_limited", "http_status": 429},
        ),
        (
            sensitive_image_response(503),
            {"used": False, "reason": "server_error", "http_status": 503},
        ),
        (
            image_response(picture("GIF"), "image/gif"),
            {"used": False, "reason": "invalid_image", "http_status": None},
        ),
        (
            image_response(b"not an image at all"),
            {"used": False, "reason": "invalid_image", "http_status": None},
        ),
        (
            image_response(b"x" * (10 * 1024 * 1024 + 1)),
            {"used": False, "reason": "response_too_large", "http_status": None},
        ),
    ],
    ids=["used", "403", "404", "410", "429", "503", "gif", "garbage", "over-10mb"],
)
async def test_successful_summary_logs_the_image_stage_result(image_response_value, expected):
    client, _ = build(page(), lambda r: image_response_value)
    worker, _ = instagram_worker(client)

    record, raw = await logged_record(worker)

    assert record["error_code"] is None and record["provider"] == "openai"
    assert record["image"] == expected
    for secret in ("secret-token", "signed-token", IMAGE_HOST, "cdninstagram", "secret-body"):
        assert secret not in raw


@pytest.mark.asyncio
async def test_image_stage_log_covers_missing_slow_and_internal_images(monkeypatch):
    async def internal(hostname, port):
        return {"10.0.0.5"} if hostname == IMAGE_HOST else {"93.184.216.34"}

    async def slow(request):
        await asyncio.sleep(1)
        return image_response()

    monkeypatch.setattr(module, "IMAGE_TIMEOUT_SECONDS", 0.05)
    cases = [
        (build(page(image=None), lambda r: image_response())[0], "no_image_url"),
        (build(page(), lambda r: image_response(), resolver=internal)[0], "unsafe_url"),
        (build(page(), slow)[0], "timeout"),
    ]

    for client, reason in cases:
        record, _ = await logged_record(instagram_worker(client)[0])
        assert record["image"] == {"used": False, "reason": reason, "http_status": None}


@pytest.mark.asyncio
async def test_failed_gpt_call_still_logs_the_image_stage_result():
    client, _ = build(page(), lambda r: image_response(), lambda r: httpx.Response(503))
    worker, _ = instagram_worker(client)

    record, _ = await logged_record(worker)

    assert (record["provider"], record["http_status"]) == ("openai", 503)
    assert record["image"] == {"used": True, "reason": None, "http_status": None}


@pytest.mark.asyncio
async def test_page_stage_failure_has_no_image_stage_result():
    client, _ = build(httpx.Response(403), lambda r: image_response())
    worker, _ = instagram_worker(client)

    record, _ = await logged_record(worker)

    assert record["provider"] == "instagram" and "image" not in record
