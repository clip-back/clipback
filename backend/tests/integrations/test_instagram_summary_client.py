import asyncio
import json
from html import escape
from io import BytesIO

import httpx
import pytest
from openai import AsyncOpenAI
from PIL import Image

from app.core.config import Settings
from app.integrations.instagram_summary_client import InstagramSummaryClient
from app.integrations.metadata_client import MetadataClient
from app.integrations.youtube_summary_client import SummaryError

TARGET = "https://www.instagram.com/reel/ABC123/"
CATEGORIES = [{"id": 7, "name": "맛집"}, {"id": 9, "name": "여행"}]
PAGE_HOST = "www.instagram.com"
POST_URL = "https://www.instagram.com/cafe/reel/ABC123/"


def page(
    description='38K likes, 369 comments - cafe on June 16, 2026: "성수동 카페 신메뉴 출시."',
    title='카페 on Instagram: "제목 속 캡션"',
    url=POST_URL,
    image=None,
):
    tags = []
    if url is not None:
        tags.append(f'<meta property="og:url" content="{escape(url)}">')
    if image is not None:
        tags.append(f'<meta property="og:image" content="{escape(image)}">')
    if description is not None:
        tags.append(f'<meta property="og:description" content="{escape(description)}">')
    if title is not None:
        tags.append(f'<meta property="og:title" content="{escape(title)}">')
    html = f"<html><head>{''.join(tags)}</head></html>"
    return httpx.Response(200, headers={"content-type": "text/html"}, text=html)


def completion(**overrides):
    output = {"title": "성수동 카페 소개", "summary": "신메뉴 출시 안내.", "category_id": 7}
    output.update(overrides)
    return httpx.Response(
        200,
        json={
            "id": "resp_1",
            "object": "response",
            "created_at": 0,
            "status": "completed",
            "model": "gpt-test",
            "output": [
                {
                    "type": "message",
                    "id": "msg_1",
                    "role": "assistant",
                    "status": "completed",
                    "content": [
                        {"type": "output_text", "text": json.dumps(output), "annotations": []}
                    ],
                }
            ],
            "usage": {
                "input_tokens": 120,
                "output_tokens": 30,
                "total_tokens": 150,
                "input_tokens_details": {"cached_tokens": 0},
                "output_tokens_details": {"reasoning_tokens": 0},
            },
            "parallel_tool_calls": False,
            "tool_choice": "auto",
            "tools": [],
        },
    )


async def public_resolver(hostname, port):
    return {"93.184.216.34"}


def build(page_handler, openai_handler, *, page_timeout=5.0):
    """Fake Instagram page and OpenAI endpoint; counts every request they receive."""
    seen = {"page": [], "openai": []}

    def page_side(request):
        seen["page"].append(request)
        return page_handler(request)

    def openai_side(request):
        seen["openai"].append(request)
        return openai_handler(request)

    metadata = MetadataClient(
        total_timeout_seconds=page_timeout,
        http_transport=httpx.MockTransport(page_side),
        resolver=public_resolver,
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


@pytest.mark.asyncio
async def test_summarizes_the_caption_with_a_stateless_structured_request():
    client, seen = build(lambda r: page(), lambda r: completion())

    result = await summarize(client)

    assert (result.title, result.summary, result.category_id) == (
        "성수동 카페 소개", "신메뉴 출시 안내.", 7,
    )
    assert result.usage == {"input_tokens": 120, "output_tokens": 30, "total_tokens": 150}
    assert [(r.headers["host"], r.url.path) for r in seen["page"]] == [(PAGE_HOST, "/reel/ABC123/")]
    (call,) = seen["openai"]
    body = json.loads(call.content)
    assert body["store"] is False and body["model"] == "gpt-test"
    assert body["text"]["format"]["type"] == "json_schema"
    sent = json.dumps(body["input"], ensure_ascii=False)
    assert "성수동 카페 신메뉴 출시." in sent
    assert "likes" not in sent and "맛집" in sent and "여행" in sent


@pytest.mark.asyncio
async def test_falls_back_to_the_title_caption_and_ignores_engagement_only_text():
    client, seen = build(
        lambda r: page(description="38K likes, 369 comments - cafe on June 16, 2026"),
        lambda r: completion(),
    )
    await summarize(client)
    sent = json.loads(seen["openai"][0].content)["input"]
    assert "제목 속 캡션" in json.dumps(sent, ensure_ascii=False)


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "response",
    [
        page(description=None, title=None),
        page(description="38K likes, 369 comments - cafe on June 16, 2026", title=None),
        page(description='1 likes - a on b: "   "', title=None),
    ],
)
async def test_no_caption_skips_without_calling_gpt(response):
    client, seen = build(lambda r: response, lambda r: completion())

    with pytest.raises(SummaryError) as exc:
        await summarize(client)

    assert (exc.value.code, exc.value.skipped, exc.value.retryable) == (
        "insufficient_content", True, False,
    )
    assert seen["openai"] == []


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "overrides",
    [
        {"title": "가" * 121},
        {"summary": "가" * 501},
        {"title": "  "},
        {"summary": ""},
    ],
)
async def test_rejects_out_of_range_output(overrides):
    client, _ = build(lambda r: page(), lambda r: completion(**overrides))

    with pytest.raises(SummaryError) as exc:
        await summarize(client)

    assert exc.value.code == "invalid_response" and not exc.value.retryable
    assert exc.value.usage == {"input_tokens": 120, "output_tokens": 30, "total_tokens": 150}


@pytest.mark.asyncio
@pytest.mark.parametrize("category_id", [999, None])
async def test_ignores_a_category_outside_the_candidates(category_id):
    client, _ = build(lambda r: page(), lambda r: completion(category_id=category_id))

    assert (await summarize(client)).category_id is None


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "status,code,retryable",
    [
        (401, "configuration_error", False),
        (403, "configuration_error", False),
        (429, "provider_error", True),
        (500, "provider_error", True),
        (503, "provider_error", True),
        (400, "provider_error", False),
        (404, "provider_error", False),
    ],
)
async def test_classifies_openai_http_errors_without_retrying(status, code, retryable):
    client, seen = build(
        lambda r: page(),
        lambda r: httpx.Response(status, json={"error": {"message": "secret detail"}}),
    )

    with pytest.raises(SummaryError) as exc:
        await summarize(client)

    error = exc.value
    assert (error.code, error.retryable, error.skipped) == (code, retryable, False)
    assert (error.provider, error.http_status) == ("openai", status)
    assert len(seen["openai"]) == 1
    assert "secret detail" not in repr(vars(error)) + str(error)


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "failure,code",
    [
        (httpx.ReadTimeout("slow"), "timeout"),
        (httpx.ConnectError("down"), "provider_error"),
    ],
)
async def test_classifies_openai_network_failures_as_retryable(failure, code):
    def broken(request):
        raise failure

    client, seen = build(lambda r: page(), broken)

    with pytest.raises(SummaryError) as exc:
        await summarize(client)

    assert (exc.value.code, exc.value.retryable) == (code, True)
    assert (exc.value.provider, exc.value.http_status) == ("openai", None)
    assert len(seen["openai"]) == 1


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "response",
    [
        httpx.Response(200, json={"id": "x", "status": "incomplete", "output": []}),
        httpx.Response(200, text="not json"),
        httpx.Response(
            200,
            json={
                "id": "r", "object": "response", "created_at": 0, "status": "completed",
                "model": "m", "parallel_tool_calls": False, "tool_choice": "auto", "tools": [],
                "output": [
                    {
                        "type": "message", "id": "m", "role": "assistant", "status": "completed",
                        "content": [{"type": "refusal", "refusal": "no"}],
                    }
                ],
            },
        ),
        httpx.Response(
            200,
            json={
                "id": "r", "object": "response", "created_at": 0, "status": "completed",
                "model": "m", "parallel_tool_calls": False, "tool_choice": "auto", "tools": [],
                "output": [
                    {
                        "type": "message", "id": "m", "role": "assistant", "status": "completed",
                        "content": [{"type": "output_text", "text": "{bad", "annotations": []}],
                    }
                ],
            },
        ),
    ],
)
async def test_malformed_openai_output_is_invalid_response(response):
    client, _ = build(lambda r: page(), lambda r: response)

    with pytest.raises(SummaryError) as exc:
        await summarize(client)

    assert (exc.value.code, exc.value.retryable, exc.value.provider) == (
        "invalid_response", False, "openai",
    )


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "status,code",
    [(429, "provider_error"), (500, "provider_error"), (503, "provider_error")],
)
async def test_transient_page_responses_are_retryable_and_skip_gpt(status, code):
    client, seen = build(lambda r: httpx.Response(status), lambda r: completion())

    with pytest.raises(SummaryError) as exc:
        await summarize(client)

    assert (exc.value.code, exc.value.retryable, exc.value.skipped) == (code, True, False)
    assert (exc.value.provider, exc.value.http_status) == ("instagram", status)
    assert seen["openai"] == []


@pytest.mark.asyncio
@pytest.mark.parametrize("status,reason", [(401, "access_denied"), (403, "access_denied"),
                                           (400, "unexpected_status")])
async def test_blocked_or_unexpected_page_statuses_fail_without_retry(status, reason):
    client, seen = build(lambda r: httpx.Response(status), lambda r: completion())

    with pytest.raises(SummaryError) as exc:
        await summarize(client)

    error = exc.value
    assert (error.code, error.retryable, error.skipped) == ("provider_error", False, False)
    assert (error.provider, error.http_status, error.reason) == ("instagram", status, reason)
    assert seen["openai"] == []


@pytest.mark.asyncio
async def test_missing_post_is_skipped_as_unavailable_without_retry():
    client, seen = build(lambda r: httpx.Response(404), lambda r: completion())

    with pytest.raises(SummaryError) as exc:
        await summarize(client)

    error = exc.value
    assert (error.code, error.retryable, error.skipped) == ("content_unavailable", False, True)
    assert (error.provider, error.http_status, error.reason) == ("instagram", 404, "not_found")
    assert len(seen["page"]) == 1 and seen["openai"] == []


def login_page(request):
    """Logged-out visitors are redirected to the login screen, which has generic metadata."""
    if request.url.path.startswith("/accounts/login"):
        html = (
            '<meta property="og:title" content="Instagram">'
            '<meta property="og:description" content="Log in to see photos and videos.">'
            '<meta property="og:url" content="https://www.instagram.com/accounts/login/">'
        )
        return httpx.Response(200, headers={"content-type": "text/html"}, text=html)
    return httpx.Response(302, headers={"location": "/accounts/login/?next=/reel/ABC123/"})


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "handler,reason",
    [
        (login_page, "login_page"),
        # Generic site metadata with a caption-shaped description is still not a post.
        (lambda r: page(url="https://example.com/news/1"), "not_post_metadata"),
        (lambda r: page(url=None), "not_post_metadata"),
        (lambda r: page(url="https://www.instagram.com/"), "not_post_metadata"),
        (lambda r: page(url="https://www.instagram.com/cafe/reel/OTHER99/"), "post_id_mismatch"),
        # Shortcodes are case-sensitive.
        (lambda r: page(url="https://www.instagram.com/p/abc123/"), "post_id_mismatch"),
        (
            lambda r: httpx.Response(
                200, headers={"content-type": "application/json"}, text="{}"
            ),
            "non_html",
        ),
    ],
)
async def test_ok_response_that_is_not_the_saved_post_is_skipped_as_unavailable(handler, reason):
    client, seen = build(handler, lambda r: completion())

    with pytest.raises(SummaryError) as exc:
        await summarize(client)

    error = exc.value
    assert (error.code, error.retryable, error.skipped) == ("content_unavailable", False, True)
    assert (error.provider, error.http_status, error.reason) == ("instagram", 200, reason)
    assert seen["openai"] == []


@pytest.mark.asyncio
async def test_other_post_with_evidence_is_unavailable_not_insufficient():
    # Accessibility is judged before evidence: a mismatched post never feeds GPT.
    other = page(url="https://www.instagram.com/p/OTHER99/", image="https://cdn.example.com/a.jpg")
    client, seen = build(lambda r: other, lambda r: completion())

    with pytest.raises(SummaryError) as exc:
        await summarize(client)

    assert exc.value.code == "content_unavailable" and seen["openai"] == []


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "url", ["https://www.instagram.com/p/ABC123/", "https://www.instagram.com/tv/ABC123/?x=1",
            "https://instagram.com/cafe/reel/ABC123"]
)
async def test_same_shortcode_matches_whatever_the_link_form(url):
    client, _ = build(lambda r: page(url=url), lambda r: completion())

    assert (await summarize(client)).title == "성수동 카페 소개"


@pytest.mark.asyncio
async def test_matching_post_without_caption_or_image_is_insufficient_not_unavailable():
    client, seen = build(lambda r: page(description=None, title=None), lambda r: completion())

    with pytest.raises(SummaryError) as exc:
        await summarize(client)

    error = exc.value
    assert (error.code, error.retryable, error.skipped) == ("insufficient_content", False, True)
    assert (error.provider, error.http_status, error.reason) == (
        "instagram", 200, "no_caption_or_image",
    )
    assert seen["openai"] == []


@pytest.mark.asyncio
async def test_a_representative_image_alone_counts_as_post_evidence():
    page_with_image = page(description=None, title=None, image="https://cdn.example.com/a.jpg")
    jpeg = BytesIO()
    Image.new("RGB", (4, 4)).save(jpeg, "JPEG")

    def route(request):
        if request.headers["host"] == PAGE_HOST:
            return page_with_image
        return httpx.Response(200, content=jpeg.getvalue())

    client, _ = build(route, lambda r: completion())

    assert (await summarize(client)).title == "성수동 카페 소개"


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "status,reason", [(429, "rate_limited"), (500, "server_error"), (503, "server_error")]
)
async def test_transient_page_status_reasons(status, reason):
    client, _ = build(lambda r: httpx.Response(status), lambda r: completion())

    with pytest.raises(SummaryError) as exc:
        await summarize(client)

    assert exc.value.reason == reason


@pytest.mark.asyncio
async def test_page_network_failures_are_retryable():
    async def slow(request):
        await asyncio.sleep(1)

    client, _ = build(slow, lambda r: completion(), page_timeout=0.05)
    with pytest.raises(SummaryError) as timeout:
        await summarize(client)
    assert (timeout.value.code, timeout.value.retryable, timeout.value.provider) == (
        "timeout", True, "instagram",
    )
    assert timeout.value.reason == "timeout"

    def read_timeout(request):
        raise httpx.ReadTimeout("slow")

    client, _ = build(read_timeout, lambda r: completion())
    with pytest.raises(SummaryError) as stalled:
        await summarize(client)
    assert (stalled.value.code, stalled.value.retryable) == ("provider_error", True)
    assert stalled.value.reason == "network_error"

    def down(request):
        raise httpx.ConnectError("down")

    client, _ = build(down, lambda r: completion())
    with pytest.raises(SummaryError) as network:
        await summarize(client)
    assert (network.value.code, network.value.retryable) == ("provider_error", True)


@pytest.mark.asyncio
async def test_missing_openai_key_is_a_configuration_error():
    config = Settings(_env_file=None, youtube_summary_enabled=False, openai_api_key=None)
    metadata = MetadataClient(
        http_transport=httpx.MockTransport(lambda r: page()), resolver=public_resolver
    )

    with pytest.raises(SummaryError) as exc:
        await InstagramSummaryClient(config, metadata).summarize(TARGET, "m", CATEGORIES)

    assert exc.value.code == "configuration_error"


@pytest.mark.asyncio
async def test_page_fetch_keeps_the_internal_network_block():
    async def private_resolver(hostname, port):
        return {"10.0.0.5"}

    seen = []
    metadata = MetadataClient(
        http_transport=httpx.MockTransport(lambda r: seen.append(r) or page()),
        resolver=private_resolver,
    )
    config = Settings(_env_file=None, youtube_summary_enabled=False, openai_api_key="test")

    with pytest.raises(SummaryError) as exc:
        await InstagramSummaryClient(config, metadata).summarize(TARGET, "m", CATEGORIES)

    assert (exc.value.code, exc.value.retryable, exc.value.provider) == (
        "provider_error", False, "instagram",
    )
    assert exc.value.reason == "unsafe_url"
    assert seen == []
