"""Request body size limits, observed only through HTTP responses and bytes the app read."""

import json

import httpx
import pytest

from app.main import create_app
from tests.support.maintenance import OpenUnitGate

MIB = 1024 * 1024
UPLOAD_PATH = "/api/v1/uploads/screenshots"
UPLOAD_LIMIT = 11 * MIB
JSON_PATH = "/api/v1/contents"
JSON_LIMIT = MIB
CHUNK = 64 * 1024
IMAGE_TOO_LARGE = {"code": "image_file_too_large", "limit_bytes": 10 * MIB}
BODY_TOO_LARGE = {"code": "request_body_too_large", "limit_bytes": MIB}


async def send_raw(path, body, *, content_length=True, method="POST", headers=()):
    """Drive the real app as uvicorn would and count the body bytes handed to it."""
    app = create_app(maintenance=OpenUnitGate())
    chunks = [body[i:i + CHUNK] for i in range(0, len(body), CHUNK)] or [b""]
    request_headers = [(b"host", b"testserver"), *headers]
    if content_length:
        request_headers.append((b"content-length", str(len(body)).encode()))
    scope = {
        "type": "http", "asgi": {"version": "3.0"}, "http_version": "1.1",
        "method": method, "scheme": "http", "path": path, "raw_path": path.encode(),
        "query_string": b"", "root_path": "", "headers": request_headers,
        "client": ("127.0.0.1", 1), "server": ("testserver", 80),
    }
    read = 0
    pending = list(enumerate(chunks))

    async def receive():
        nonlocal read
        if not pending:
            return {"type": "http.disconnect"}
        index, chunk = pending.pop(0)
        read += len(chunk)
        return {"type": "http.request", "body": chunk, "more_body": index < len(chunks) - 1}

    sent = []

    async def send(message):
        sent.append(message)

    await app(scope, receive, send)
    status = sent[0]["status"]
    payload = b"".join(m.get("body", b"") for m in sent[1:])
    return status, json.loads(payload) if payload else None, read


def multipart(file_size, *, category_count=0, tag_names=(), total=None):
    """Build the app's multipart upload; with total, pad the file to that exact body size."""
    def build(size):
        data = {"category_ids": [str(i) for i in range(1, category_count + 1)],
                "tag_names": list(tag_names)}
        request = httpx.Request(
            "POST", "http://testserver" + UPLOAD_PATH, data=data,
            files={"file": ("photo.png", b"\x89PNG" + bytes(size - 4), "image/png")},
        )
        return request.read(), request.headers["content-type"].encode()

    body, content_type = build(file_size)
    if total is not None:
        body, content_type = build(file_size + total - len(body))
        assert len(body) == total
    return body, [(b"content-type", content_type)]


def json_body(size):
    """Valid JSON of exactly size bytes."""
    url = "https://example.com"
    base = len(json.dumps({"original_url": url, "title": ""}))
    return json.dumps({"original_url": url, "title": "x" * (size - base)}).encode()


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("path", "limit", "detail", "headers"),
    [
        (UPLOAD_PATH, UPLOAD_LIMIT, IMAGE_TOO_LARGE,
         [(b"content-type", b"multipart/form-data; boundary=x")]),
        (JSON_PATH, JSON_LIMIT, BODY_TOO_LARGE, [(b"content-type", b"application/json")]),
    ],
)
async def test_declared_length_over_limit_is_rejected_before_reading(path, limit, detail, headers):
    status, payload, read = await send_raw(path, bytes(limit + 1), headers=headers)

    assert (status, payload, read) == (413, {"detail": detail}, 0)


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("path", "limit", "detail", "request_body"),
    [
        (UPLOAD_PATH, UPLOAD_LIMIT, IMAGE_TOO_LARGE, lambda: multipart(UPLOAD_LIMIT + 5 * CHUNK)),
        (JSON_PATH, JSON_LIMIT, BODY_TOO_LARGE,
         lambda: (json_body(JSON_LIMIT + 5 * CHUNK), [(b"content-type", b"application/json")])),
    ],
)
async def test_undeclared_length_stops_once_received_bytes_pass_limit(
    path, limit, detail, request_body,
):
    body, headers = request_body()

    status, payload, read = await send_raw(path, body, content_length=False, headers=headers)

    assert (status, payload) == (413, {"detail": detail})
    assert limit < read <= limit + CHUNK


@pytest.mark.asyncio
@pytest.mark.parametrize("content_length", [True, False])
async def test_upload_exactly_at_limit_reaches_authentication(content_length):
    body, headers = multipart(10 * MIB, total=UPLOAD_LIMIT)

    status, _, read = await send_raw(
        UPLOAD_PATH, body, content_length=content_length, headers=headers,
    )

    assert (status, read) == (401, UPLOAD_LIMIT)


@pytest.mark.asyncio
@pytest.mark.parametrize("content_length", [True, False])
async def test_upload_one_byte_over_limit_is_rejected(content_length):
    body, headers = multipart(10 * MIB, total=UPLOAD_LIMIT + 1)

    status, payload, read = await send_raw(
        UPLOAD_PATH, body, content_length=content_length, headers=headers,
    )

    assert (status, payload) == (413, {"detail": IMAGE_TOO_LARGE})
    assert read == (0 if content_length else UPLOAD_LIMIT + 1)


@pytest.mark.asyncio
@pytest.mark.parametrize("content_length", [True, False])
async def test_json_exactly_at_limit_reaches_authentication(content_length):
    body = json_body(JSON_LIMIT)
    assert len(body) == JSON_LIMIT

    status, _, read = await send_raw(
        JSON_PATH, body, content_length=content_length,
        headers=[(b"content-type", b"application/json")],
    )

    assert (status, read) == (401, JSON_LIMIT)


@pytest.mark.asyncio
@pytest.mark.parametrize("content_length", [True, False])
async def test_json_one_byte_over_limit_is_rejected(content_length):
    status, payload, read = await send_raw(
        JSON_PATH, json_body(JSON_LIMIT + 1), content_length=content_length,
        headers=[(b"content-type", b"application/json")],
    )

    assert (status, payload) == (413, {"detail": BODY_TOO_LARGE})
    assert read == (0 if content_length else JSON_LIMIT + 1)


@pytest.mark.asyncio
async def test_largest_app_upload_passes_limit():
    # 10MiB file with 20 categories and 10 tags of 40 Korean characters each.
    body, headers = multipart(
        10 * MIB, category_count=20, tag_names=[f"{i}" + "가" * 39 for i in range(10)],
    )

    status, _, read = await send_raw(UPLOAD_PATH, body, headers=headers)

    assert (status, read) == (401, len(body))


@pytest.mark.asyncio
async def test_longest_app_json_passes_limit():
    body = json.dumps({
        "provider": "apple", "authorization_code": "a" * 8192, "identity_token": "t" * 8192,
        "raw_text": "가" * 5000, "url": "https://example.com/" + "p" * 2028,
    }).encode()

    status, _, read = await send_raw(
        JSON_PATH, body, headers=[(b"content-type", b"application/json")],
    )

    assert (status, read) == (401, len(body))


@pytest.mark.asyncio
async def test_limit_applies_to_exact_upload_path_regardless_of_method():
    status, payload, _ = await send_raw(
        UPLOAD_PATH + "/", bytes(JSON_LIMIT + 1),
        headers=[(b"content-type", b"application/json")],
    )
    assert (status, payload) == (413, {"detail": BODY_TOO_LARGE})

    status, payload, read = await send_raw(UPLOAD_PATH, bytes(JSON_LIMIT + 1), method="PUT")
    assert (status, read) == (405, 0)


@pytest.mark.asyncio
async def test_health_without_body_is_unchanged():
    status, payload, read = await send_raw("/api/v1/health", b"", method="GET")

    assert (status, payload, read) == (200, {"status": "ok"}, 0)
