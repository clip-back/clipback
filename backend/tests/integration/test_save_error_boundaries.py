import json
import logging
from io import StringIO
from unittest.mock import AsyncMock
from uuid import uuid4

import pytest
from sqlalchemy import func, select
from sqlalchemy.exc import DBAPIError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.content import Content
from app.models.share_receipt import ShareReceipt
from app.models.tag import Tag
from app.repositories.share_receipt_repository import ShareReceiptRepository
from app.services.content_save_flow import ContentSaveFlow
from app.services.content_service import ContentService
from tests.integration.helpers import guest, link, request

pytestmark = pytest.mark.asyncio
LINK_URL = "https://example.com/save-error-test"
SHARED_URL = "https://www.instagram.com/p/ABC123/"
LOG_MARKERS = ("synthetic-parameter", "synthetic-driver-detail", "[parameters:", "[SQL:")
SAVE_PATHS = ("link", "share", "screenshot", "category", "replacement")


def save_request(kind, content_id, png_bytes, names):
    if kind == "link":
        return "POST", "contents", {"json": {"original_url": LINK_URL, "tag_names": names}}
    if kind == "share":
        return "POST", "contents/share", {"json": {"url": SHARED_URL, "tag_names": names}}
    if kind == "screenshot":
        return "POST", "uploads/screenshots", {
            "data": {"tag_names": names},
            "files": {"file": ("image.png", png_bytes, "image/png")},
        }
    if kind == "category":
        return "POST", "categories", {"json": {"name": "테스트 카테고리", "color": "#68B5FF"}}
    return "PUT", f"contents/{content_id}/tags", {"json": {"tag_names": names}}


async def save_rows(connection, user_id):
    counts = []
    for model in (Content, Tag, ShareReceipt):
        query = select(func.count()).select_from(model).where(model.user_id == user_id)
        counts.append(await connection.scalar(query))
    return tuple(counts)


@pytest.mark.parametrize("tag", ["요\x00리", "요\ud83d리"], ids=["nul", "unpaired-surrogate"])
@pytest.mark.parametrize(
    "kind,keyed,owner,method_name",
    [
        ("link", False, ContentSaveFlow, "save_link"),
        ("link", True, ContentSaveFlow, "save_link"),
        ("share", False, ContentSaveFlow, "save_shared_link"),
        ("share", True, ContentSaveFlow, "save_shared_link"),
        ("replacement", False, ContentService, "update_tags"),
    ],
    ids=["link", "link-keyed", "share", "share-keyed", "replacement"],
)
async def test_invalid_json_tags_are_rejected_before_save(
    api, database_connection, monkeypatch, kind, keyed, owner, method_name, tag,
):
    headers, _, user = await guest(api)
    existing = await link(api, headers, tag_names=["기존"]) if kind == "replacement" else None
    before = (1, 1, 0) if existing else (0, 0, 0)
    assert await save_rows(database_connection, user["id"]) == before
    save = AsyncMock(side_effect=AssertionError("Validation must happen before saving"))
    monkeypatch.setattr(owner, method_name, save)
    method, path, kwargs = save_request(kind, existing["id"] if existing else None, None, [tag])
    headers["Content-Type"] = "application/json"
    if keyed:
        headers["Idempotency-Key"] = str(uuid4())

    response = await api.request(
        method, f"/api/v1/{path}", headers=headers, content=json.dumps(kwargs["json"]),
    )

    save.assert_not_awaited()
    assert response.status_code == 422
    error, = response.json()["detail"]
    assert error["loc"] == ["body", "tag_names"]
    assert error["msg"] == "Value error, Tag name contains unsupported characters"
    assert error["input"] == [tag]
    assert await save_rows(database_connection, user["id"]) == before
    if existing:
        detail = await request(api, "GET", f"contents/{existing['id']}", headers=headers)
        assert detail["tags"] == existing["tags"]


async def test_invalid_screenshot_tags_are_rejected_before_save(
    api, database_connection, monkeypatch, png_bytes,
):
    headers, _, user = await guest(api)
    headers["Idempotency-Key"] = str(uuid4())
    save = AsyncMock(side_effect=AssertionError("Validation must happen before saving"))
    monkeypatch.setattr(ContentSaveFlow, "save_screenshot", save)
    tag = "요\x00리"
    method, path, kwargs = save_request("screenshot", None, png_bytes, [tag])

    response = await api.request(method, f"/api/v1/{path}", headers=headers, **kwargs)

    save.assert_not_awaited()
    assert response.status_code == 422
    error, = response.json()["detail"]
    assert error["loc"] == ["tag_names"]
    assert error["msg"] == "Value error, Tag name contains unsupported characters"
    assert error["input"] == [tag]
    assert await save_rows(database_connection, user["id"]) == (0, 0, 0)


async def test_valid_emoji_tag_is_saved_and_ordinary_422_bytes_are_preserved(api):
    headers, _, _ = await guest(api)
    saved = await link(api, headers, tag_names=["😀", "요리"])
    detail = await request(api, "GET", f"contents/{saved['id']}", headers=headers)
    assert {tag["name"] for tag in detail["tags"]} == {"😀", "요리"}

    long_tag = "요" * 41
    invalid = await api.put(
        f"/api/v1/contents/{saved['id']}/tags", headers=headers, json={"tag_names": [long_tag]},
    )
    assert invalid.status_code == 422
    assert invalid.content == (
        '{"detail":[{"type":"value_error","loc":["body","tag_names"],'
        '"msg":"Value error, Tag name cannot exceed 40 characters",'
        '"input":["' + long_tag + '"],"ctx":{"error":{}}}]}'
    ).encode()


def synthetic_db_error():
    return DBAPIError("SELECT", ("synthetic-parameter",), ValueError("synthetic-driver-detail"))


def assert_plain_500(response):
    assert response.status_code == 500
    assert response.content == b"Internal Server Error"
    assert response.headers["content-type"] == "text/plain; charset=utf-8"


@pytest.mark.parametrize("kind", SAVE_PATHS)
async def test_inprocess_write_failure_preserves_plain_500_and_omits_app_log_details(
    api, monkeypatch, caplog, png_bytes, kind,
):
    """Check the HTTP response and app logger through the in-process ASGI transport."""
    headers, _, _ = await guest(api)
    existing = await link(api, headers) if kind == "replacement" else None
    content_id = existing["id"] if existing else None
    method, path, kwargs = save_request(kind, content_id, png_bytes, ["태그"])
    monkeypatch.setattr(logging.getLogger("app"), "propagate", True)
    real_commit = AsyncSession.commit
    failure = AsyncMock(side_effect=synthetic_db_error())

    async def fail_first_commit(session):
        if not failure.await_count:
            await failure()
        await real_commit(session)

    with monkeypatch.context() as patch:
        patch.setattr(AsyncSession, "commit", fail_first_commit)
        response = await api.request(method, f"/api/v1/{path}", headers=headers, **kwargs)

    failure.assert_awaited_once()
    assert_plain_500(response)
    assert all(marker not in caplog.text for marker in LOG_MARKERS)


async def test_uncertain_screenshot_commit_logs_only_verification_exception_type(
    api, monkeypatch, png_bytes, tmp_path,
):
    headers, _, _ = await guest(api)
    headers["Idempotency-Key"] = str(uuid4())
    commit = AsyncMock(side_effect=ConnectionError("injected commit failure"))
    verify = AsyncMock(side_effect=synthetic_db_error())
    monkeypatch.setattr(AsyncSession, "commit", commit)
    monkeypatch.setattr(ShareReceiptRepository, "committed_after_failure", verify)

    method, path, kwargs = save_request("screenshot", None, png_bytes, [])
    output = StringIO()
    handler = logging.StreamHandler(output)
    logger = logging.getLogger("app.services.content_save_flow")
    logger.addHandler(handler)
    try:
        response = await api.request(method, f"/api/v1/{path}", headers=headers, **kwargs)
    finally:
        logger.removeHandler(handler)

    commit.assert_awaited_once()
    verify.assert_awaited_once()
    assert_plain_500(response)
    assert all(marker not in output.getvalue() for marker in LOG_MARKERS)
    assert output.getvalue().splitlines() == [
        "Unable to verify screenshot commit; retaining file (DBAPIError)"
    ]
    originals = [path for path in tmp_path.rglob("*") if path.is_file()]
    original, = originals
    assert original.read_bytes() == png_bytes
