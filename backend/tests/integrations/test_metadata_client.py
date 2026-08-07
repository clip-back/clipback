import asyncio

import httpx
import pytest

from app.integrations.metadata_client import (
    MetadataClient,
    UnsafeUrlError,
    UrlResolutionError,
)


async def public_resolver(hostname: str, port: int) -> set[str]:
    return {"93.184.216.34"}


def build_client(
    handler,
    *,
    resolver=public_resolver,
    timeout: float = 5.0,
    max_redirects: int = 3,
    max_response_bytes: int = 1_000_000,
) -> MetadataClient:
    return MetadataClient(
        total_timeout_seconds=timeout,
        max_redirects=max_redirects,
        max_response_bytes=max_response_bytes,
        http_client=httpx.AsyncClient(transport=httpx.MockTransport(handler)),
        resolver=resolver,
    )


@pytest.mark.asyncio
async def test_extract_prefers_open_graph_and_normalizes_text() -> None:
    async def handler(request: httpx.Request) -> httpx.Response:
        assert request.headers["user-agent"] == "ClipbackBot/0.1"
        html = """
        <html><head>
          <link rel="canonical" href="http://127.0.0.1/ignored">
          <meta property="og:title" content="  Open &amp; Graph\n  제목  ">
          <meta name="twitter:title" content="Twitter 제목">
          <title>HTML 제목</title>
          <meta property="og:description" content="  첫째 줄\n 둘째 &amp; 줄  ">
          <meta name="twitter:description" content="Twitter 설명">
          <meta name="description" content="HTML 설명">
        </head></html>
        """
        return httpx.Response(200, headers={"content-type": "text/html"}, text=html)

    client = build_client(handler)
    result = await client.extract_from_url("https://example.com/post#fragment")

    assert result.status == "success"
    assert result.resolved_url == "https://example.com/post"
    assert result.title == "Open & Graph 제목"
    assert result.description == "첫째 줄 둘째 & 줄"
    await client.http_client.aclose()


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("html", "expected_title", "expected_description"),
    [
        (
            '<meta name="twitter:title" content="Twitter">'
            '<meta name="twitter:description" content="설명">',
            "Twitter",
            "설명",
        ),
        (
            '<title>HTML 제목</title><meta name="description" content="HTML 설명">',
            "HTML 제목",
            "HTML 설명",
        ),
    ],
)
async def test_extract_uses_twitter_and_html_fallbacks(
    html: str,
    expected_title: str,
    expected_description: str,
) -> None:
    client = build_client(
        lambda request: httpx.Response(
            200,
            headers={"content-type": "application/xhtml+xml; charset=utf-8"},
            text=html,
        )
    )

    result = await client.extract_from_url("https://example.com")

    assert result.title == expected_title
    assert result.description == expected_description
    await client.http_client.aclose()


@pytest.mark.asyncio
async def test_extract_limits_title_and_description_lengths() -> None:
    html = (
        f'<meta property="og:title" content="{"가" * 121}">'
        f'<meta property="og:description" content="{"나" * 501}">'
    )
    client = build_client(
        lambda request: httpx.Response(
            200,
            headers={"content-type": "text/html"},
            text=html,
        )
    )

    result = await client.extract_from_url("https://example.com")

    assert result.title == "가" * 120
    assert result.description == "나" * 500
    await client.http_client.aclose()


@pytest.mark.asyncio
async def test_extract_follows_safe_redirect_and_returns_final_url() -> None:
    async def handler(request: httpx.Request) -> httpx.Response:
        if request.url.host == "short.example.com":
            return httpx.Response(302, headers={"location": "https://final.example.com/post#x"})
        return httpx.Response(
            200,
            headers={"content-type": "text/html"},
            text="<title>최종 제목</title>",
        )

    client = build_client(handler)
    result = await client.extract_from_url("https://short.example.com/a")

    assert result.status == "success"
    assert result.resolved_url == "https://final.example.com/post"
    await client.http_client.aclose()


@pytest.mark.asyncio
async def test_extract_rejects_unsafe_redirect() -> None:
    client = build_client(
        lambda request: httpx.Response(302, headers={"location": "http://127.0.0.1/admin"})
    )

    with pytest.raises(UnsafeUrlError):
        await client.extract_from_url("https://example.com")

    await client.http_client.aclose()


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "url",
    [
        "http://localhost/path",
        "http://service.internal/path",
        "http://internal/path",
        "http://127.0.0.1/path",
        "http://10.0.0.1/path",
        "http://169.254.1.1/path",
        "http://224.0.0.1/path",
        "http://192.0.2.1/path",
        "http://[::1]/path",
        "https://example.com:8443/path",
        "ftp://example.com/path",
    ],
)
async def test_extract_rejects_internal_or_unsupported_urls(url: str) -> None:
    client = build_client(lambda request: httpx.Response(200))

    with pytest.raises(UnsafeUrlError):
        await client.extract_from_url(url)

    await client.http_client.aclose()


@pytest.mark.asyncio
async def test_extract_rejects_hostname_when_any_dns_address_is_private() -> None:
    async def mixed_resolver(hostname: str, port: int) -> set[str]:
        return {"93.184.216.34", "10.0.0.5"}

    client = build_client(lambda request: httpx.Response(200), resolver=mixed_resolver)

    with pytest.raises(UnsafeUrlError):
        await client.extract_from_url("https://example.com")

    await client.http_client.aclose()


@pytest.mark.asyncio
async def test_extract_treats_dns_failure_as_fallback() -> None:
    async def failing_resolver(hostname: str, port: int) -> set[str]:
        raise UrlResolutionError("failed")

    client = build_client(lambda request: httpx.Response(200), resolver=failing_resolver)
    result = await client.extract_from_url("https://missing.example.com")

    assert result.status == "failed"
    assert result.failure_reason == "dns_failure"
    await client.http_client.aclose()


@pytest.mark.asyncio
async def test_extract_treats_timeout_as_fallback() -> None:
    async def slow_handler(request: httpx.Request) -> httpx.Response:
        await asyncio.sleep(0.05)
        return httpx.Response(200, headers={"content-type": "text/html"}, text="<title>x</title>")

    client = build_client(slow_handler, timeout=0.01)
    result = await client.extract_from_url("https://example.com")

    assert result.status == "failed"
    assert result.failure_reason == "timeout"
    await client.http_client.aclose()


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("response", "expected_reason"),
    [
        (httpx.Response(404), "http_status_404"),
        (httpx.Response(500), "http_status_500"),
        (
            httpx.Response(200, headers={"content-type": "application/json"}, text="{}"),
            "non_html",
        ),
        (
            httpx.Response(200, headers={"content-type": "text/html"}, text="<html></html>"),
            "metadata_missing",
        ),
    ],
)
async def test_extract_treats_response_failures_as_fallback(
    response: httpx.Response,
    expected_reason: str,
) -> None:
    client = build_client(lambda request: response)
    result = await client.extract_from_url("https://example.com")

    assert result.status == "failed"
    assert result.failure_reason == expected_reason
    await client.http_client.aclose()


@pytest.mark.asyncio
async def test_extract_limits_redirect_count() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        index = int(request.url.path.strip("/") or 0)
        return httpx.Response(302, headers={"location": f"/{index + 1}"})

    client = build_client(handler, max_redirects=3)
    result = await client.extract_from_url("https://example.com/0")

    assert result.status == "failed"
    assert result.failure_reason == "redirect_limit"
    assert result.resolved_url == "https://example.com/3"
    await client.http_client.aclose()


@pytest.mark.asyncio
async def test_extract_limits_response_body_size() -> None:
    client = build_client(
        lambda request: httpx.Response(
            200,
            headers={"content-type": "text/html"},
            content=b"x" * 11,
        ),
        max_response_bytes=10,
    )
    result = await client.extract_from_url("https://example.com")

    assert result.status == "failed"
    assert result.failure_reason == "response_too_large"
    await client.http_client.aclose()


@pytest.mark.asyncio
async def test_extract_treats_parse_error_as_fallback(monkeypatch) -> None:
    client = build_client(
        lambda request: httpx.Response(
            200,
            headers={"content-type": "text/html"},
            text="<title>제목</title>",
        )
    )

    def fail_parse(body: bytes, encoding: str | None) -> tuple[str | None, str | None]:
        raise ValueError("invalid html")

    monkeypatch.setattr(client, "_parse_metadata", fail_parse)
    result = await client.extract_from_url("https://example.com")

    assert result.status == "failed"
    assert result.failure_reason == "parse_failure"
    await client.http_client.aclose()
