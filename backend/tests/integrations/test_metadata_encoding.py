import gzip
import tracemalloc

import httpx
import pytest

from tests.integrations.test_metadata_client import build_client


class ResponseStream(httpx.AsyncByteStream):
    def __init__(self, *chunks: bytes) -> None:
        self.chunks = chunks
        self.reads = 0
        self.closed = False

    async def __aiter__(self):
        for chunk in self.chunks:
            self.reads += 1
            yield chunk

    async def aclose(self) -> None:
        self.closed = True


def encoded_response(stream, encoding="gzip", content_type="text/html"):
    headers = [("content-type", content_type)]
    if encoding is not None:
        headers.extend(("content-encoding", value) for value in encoding.split("|"))
    return httpx.Response(200, headers=headers, stream=stream)


@pytest.mark.asyncio
async def test_gzip_response_stays_within_memory_budget():
    limit = 256 * 1024
    stream = ResponseStream(gzip.compress(b"x" * (16 * 1024 * 1024)))
    client = build_client(lambda request: encoded_response(stream), max_response_bytes=limit)

    tracemalloc.start()
    try:
        result = await client.extract_from_url("https://example.com/post")
        _, peak = tracemalloc.get_traced_memory()
    finally:
        tracemalloc.stop()

    assert result.failure_reason == "response_too_large"
    assert peak < limit * 8
    assert stream.closed


@pytest.mark.asyncio
async def test_requests_only_supported_encoding():
    def handler(request):
        assert request.headers["accept-encoding"] == "gzip"
        return encoded_response(ResponseStream(b"<title>Example</title>"), encoding="")

    result = await build_client(handler).extract_from_url("https://example.com/post")
    assert result.title == "Example"


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "encoding,compressed,supported",
    [
        (None, False, True),
        ("", False, True),
        ("identity", False, True),
        (" IDENTITY , , ", False, True),
        ("gzip", True, True),
        ("GZIP", True, True),
        (" gzip ", True, True),
        ("gzip, identity", True, True),
        ("identity|gzip|", True, True),
        ("gzip, gzip", True, False),
        ("gzip|gzip", True, False),
        ("gzip, identity|deflate", True, False),
        ("deflate", False, False),
        ("br", False, False),
        ("zstd", False, False),
        ("x-gzip", False, False),
        ("unknown", False, False),
    ],
)
async def test_content_encoding_is_classified_before_reading(encoding, compressed, supported):
    body = b"<title>Example</title>"
    stream = ResponseStream(gzip.compress(body) if compressed else body)
    client = build_client(lambda request: encoded_response(stream, encoding))

    result = await client.extract_from_url("https://example.com/post")

    if supported:
        assert result.status == "success" and result.title == "Example"
        assert stream.reads == 1
    else:
        assert result.failure_reason == "unsupported_encoding"
        assert stream.reads == 0
    assert stream.closed


async def fetch(client, method, limit):
    if method == "fetch_image":
        return await client.fetch_image(
            "https://example.com/image", total_timeout_seconds=1, max_bytes=limit
        )
    return await getattr(client, method)("https://example.com/post")


@pytest.mark.asyncio
@pytest.mark.parametrize("method", ["extract_from_url", "fetch_page", "fetch_image"])
@pytest.mark.parametrize("compressed", [False, True])
@pytest.mark.parametrize("over_limit", [False, True])
async def test_public_fetch_methods_enforce_decoded_body_boundary(method, compressed, over_limit):
    body = b'<meta property="og:title" content="Example">'
    limit = len(body) - int(over_limit)
    stream = ResponseStream(gzip.compress(body) if compressed else body)

    def handler(request):
        assert request.headers["accept-encoding"] == "gzip"
        return encoded_response(stream, "gzip" if compressed else None)

    client = build_client(
        handler, max_response_bytes=limit + 1024 if method == "fetch_image" else limit
    )
    result = await fetch(client, method, limit)

    if over_limit:
        assert result.failure_reason == "response_too_large"
    else:
        assert result.failure_reason is None
        if method == "extract_from_url":
            assert result.title == "Example"
        elif method == "fetch_page":
            assert result.properties == {"og:title": "Example"}
        else:
            assert result.content == body
    assert stream.closed


@pytest.mark.asyncio
@pytest.mark.parametrize("method", ["fetch_page", "fetch_image"])
async def test_public_fetch_methods_reject_layered_encoding_without_reading(method):
    stream = ResponseStream(b"unread")
    client = build_client(lambda request: encoded_response(stream, "gzip|gzip"))

    result = await fetch(client, method, 1024)

    assert result.failure_reason == "unsupported_encoding"
    assert stream.reads == 0 and stream.closed


@pytest.mark.asyncio
async def test_layered_response_stays_within_memory_budget():
    limit = 256 * 1024
    stream = ResponseStream(gzip.compress(gzip.compress(b"x" * (16 * 1024 * 1024))))
    client = build_client(
        lambda request: encoded_response(stream, "gzip, gzip"), max_response_bytes=limit
    )

    tracemalloc.start()
    try:
        result = await client.extract_from_url("https://example.com/post")
        _, peak = tracemalloc.get_traced_memory()
    finally:
        tracemalloc.stop()

    assert result.failure_reason == "unsupported_encoding"
    assert peak < limit * 8
    assert stream.reads == 0 and stream.closed


@pytest.mark.asyncio
@pytest.mark.parametrize("over_limit", [False, True])
async def test_gzip_can_span_response_chunks(over_limit):
    body = b'<meta property="og:title" content="Example">'
    encoded = gzip.compress(body)
    stream = ResponseStream(*(encoded[index : index + 1] for index in range(len(encoded))))
    limit = len(body) - int(over_limit)
    client = build_client(lambda request: encoded_response(stream), max_response_bytes=limit)

    result = await client.fetch_page("https://example.com/post")

    if over_limit:
        assert result.failure_reason == "response_too_large"
    else:
        assert result.properties == {"og:title": "Example"}
    assert stream.closed


@pytest.mark.asyncio
async def test_oversized_gzip_stops_before_reading_the_next_chunk():
    stream = ResponseStream(gzip.compress(b"x" * 4096), b"unread")
    client = build_client(lambda request: encoded_response(stream), max_response_bytes=64)

    result = await client.extract_from_url("https://example.com/post")

    assert result.failure_reason == "response_too_large"
    assert stream.reads == 1 and stream.closed


@pytest.mark.asyncio
@pytest.mark.parametrize("method", ["extract_from_url", "fetch_page", "fetch_image"])
@pytest.mark.parametrize(
    "body",
    [b"invalid", gzip.compress(b"Example")[:-4], gzip.compress(b"Example")[:-8] + b"invalid!"],
    ids=["invalid", "incomplete", "checksum"],
)
async def test_invalid_gzip_reports_request_failure(method, body):
    stream = ResponseStream(body)
    client = build_client(lambda request: encoded_response(stream))

    result = await fetch(client, method, 1024)

    assert result.failure_reason == "request_failure"
    assert stream.closed


@pytest.mark.asyncio
@pytest.mark.parametrize("method", ["extract_from_url", "fetch_page", "fetch_image"])
async def test_gzip_completion_preserves_success_without_reading_trailing_chunks(method):
    body = b'<meta property="og:title" content="Example">'
    stream = ResponseStream(gzip.compress(body), b"unread", b"also unread")
    client = build_client(lambda request: encoded_response(stream), max_response_bytes=len(body))

    result = await fetch(client, method, len(body))

    assert result.failure_reason is None
    if method == "extract_from_url":
        assert result.status == "success" and result.title == "Example"
    elif method == "fetch_page":
        assert result.status == "success" and result.properties == {"og:title": "Example"}
    else:
        assert result.content == body
    assert stream.reads == 1
    assert stream.closed
