"""Lock the save-step log contract at the HTTP save endpoints (#458)."""

import json
import logging
from base64 import b64encode
from io import StringIO
from types import SimpleNamespace
from uuid import uuid4

import pytest
from sqlalchemy import delete, select

from app.integrations.metadata_client import MetadataClient, MetadataResult, UnsafeUrlError
from app.models.category import Category
from app.models.content_asset import ContentAsset
from app.models.content_event import ContentEvent, ContentEventType
from app.services import (
    category_recommendation_service,
    extraction_service,
    share_intake_service,
    upload_service,
)
from tests.integration.helpers import guest, request
from tests.integration.test_save_ai_tags import (
    ProviderAI,
    ProviderOCR,
    provider as provider,
    save_provider as save_provider,
)

pytestmark = pytest.mark.asyncio

WEB = "https://example.com/original-url-marker-458"
RESOLVED_WEB = "https://example.org/resolved-url-marker-458"
INSTAGRAM = "https://www.instagram.com/p/PostMarker458/"
SHARE = "https://www.instagram.com/share/ShareMarker458/"
YOUTUBE = "https://youtu.be/dQw4w9WgXcQ"
TITLE = "link-title-marker-458"
DESCRIPTION = "description-marker-458"
SHARED_TEXT = "shared-text-marker-458"
OCR_TEXT = "ocr-text-marker-458"
OCR_TITLE = "ocr-title-marker-458"
OCR_SUMMARY = "ocr-summary-marker-458"
TAG = "tag-marker-458"
CATEGORY = "category-marker-458"
IMAGE = b"image-bytes-marker-458"
EXCEPTION = "exception-marker-458"
RAW_RESPONSE = "provider-response-marker-458"
PRIVATE_MARKERS = (
    "original-url-marker-458", "resolved-url-marker-458", "PostMarker458", "ShareMarker458",
    "dQw4w9WgXcQ", TITLE, DESCRIPTION, SHARED_TEXT,
    OCR_TEXT, OCR_TITLE, OCR_SUMMARY, TAG, CATEGORY, IMAGE.decode(), EXCEPTION,
    RAW_RESPONSE, "wrong-id-marker-458",
)

EVENT = "content_save_step"
PREFIX = '{"event": "content_save_step"'
KEYS = {"event", "step", "elapsed_seconds", "status", "failure_reason"}
LOGGER_NAMES = {
    "link_metadata": "app.services.extraction_service",
    "instagram_share_resolve": "app.services.share_intake_service",
    "category_recommendation": "app.services.category_recommendation_service",
    "screenshot_ocr": "app.services.upload_service",
}

LINK_OK = ("link_metadata", "success", None)
SHARE_OK = ("instagram_share_resolve", "success", None)
AI_OK = ("category_recommendation", "ai", None)
OCR_OK = ("screenshot_ocr", "success", None)


@pytest.fixture
def save_logs(api, caplog, capsys):
    records = []
    rendered = StringIO()
    logger = logging.getLogger("app")

    class Collect(logging.Handler):
        def emit(self, record):
            message = record.getMessage()
            if message.startswith(PREFIX):
                records.append((record.name, record.levelno, json.loads(message)))

    collector = Collect()
    stream = logging.StreamHandler(rendered)
    caplog.set_level(logging.INFO)
    handlers = [collector, stream]
    if not logger.propagate:
        handlers.append(caplog.handler)
    for handler in handlers:
        logger.addHandler(handler)

    def assert_private(*extra_markers):
        output = capsys.readouterr()
        all_logs = rendered.getvalue() + caplog.text + output.out + output.err
        for marker in (*PRIVATE_MARKERS, *extra_markers):
            assert marker not in all_logs

    try:
        yield SimpleNamespace(records=records, rendered=rendered, assert_private=assert_private)
    finally:
        for handler in handlers:
            logger.removeHandler(handler)


def assert_steps(save_logs, expected, *, private_markers=()):
    records = save_logs.records
    actual = []
    for name, level, record in records:
        assert set(record) == KEYS
        assert name == LOGGER_NAMES[record["step"]]
        assert level == logging.INFO
        elapsed = record["elapsed_seconds"]
        assert type(elapsed) is float and elapsed >= 0
        assert elapsed == 0.123
        actual.append({**record, "elapsed_seconds": "<elapsed>"})
    assert actual == [
        {
            "event": EVENT, "step": step, "elapsed_seconds": "<elapsed>",
            "status": status, "failure_reason": reason,
        }
        for step, status, reason in expected
    ]
    assert [
        json.loads(line) for line in save_logs.rendered.getvalue().splitlines()
        if line.startswith(PREFIX)
    ] == [record for _, _, record in records]
    save_logs.assert_private(*private_markers)


@pytest.fixture
def upstream(save_provider, monkeypatch):
    now = 1000.0

    def monotonic():
        return now

    def spend_time():
        nonlocal now
        now += 0.12345

    for module in (
        extraction_service, share_intake_service, category_recommendation_service, upload_service,
    ):
        monkeypatch.setattr(module, "time", SimpleNamespace(monotonic=monotonic), raising=False)

    state = SimpleNamespace(provider=save_provider, metadata_calls=[], metadata_reason=None)
    save_provider.recommendation = {"tags": [TAG], "extra": RAW_RESPONSE}
    save_provider.ocr = {
        "text": OCR_TEXT, "title": OCR_TITLE, "headline": OCR_SUMMARY, "points": [],
        "tags": [TAG], "extra": RAW_RESPONSE,
    }

    async def metadata(self, url):
        state.metadata_calls.append(url)
        spend_time()
        if state.metadata_reason == "unsafe_url":
            raise UnsafeUrlError(EXCEPTION)
        if state.metadata_reason:
            return MetadataResult(url, None, None, "failed", state.metadata_reason)
        resolved_url = {SHARE: INSTAGRAM, WEB: RESOLVED_WEB}.get(url, url)
        return MetadataResult(resolved_url, TITLE, DESCRIPTION, "success")

    recommend = ProviderAI.suggest_category_id
    ocr = ProviderOCR.extract

    async def timed_recommend(self, **kwargs):
        try:
            return await recommend(self, **kwargs)
        finally:
            spend_time()

    async def timed_ocr(self, **kwargs):
        try:
            return await ocr(self, **kwargs)
        finally:
            spend_time()

    monkeypatch.setattr(MetadataClient, "extract_from_url", metadata)
    monkeypatch.setattr(ProviderAI, "suggest_category_id", timed_recommend)
    monkeypatch.setattr(ProviderOCR, "extract", timed_ocr)
    return state


async def test_app_log_collector_matches_rendered_lines(save_logs):
    probe = '{"event": "content_save_step", "probe": "save-log-probe-458"}'
    logging.getLogger("app.services.extraction_service").info(probe)

    assert save_logs.records == [
        ("app.services.extraction_service", logging.INFO, json.loads(probe)),
    ]
    assert save_logs.rendered.getvalue().splitlines() == [probe]


@pytest.mark.parametrize("route,url,chosen,expected", [
    pytest.param("contents", WEB, False, [LINK_OK, AI_OK], id="web-auto"),
    pytest.param("contents", WEB, True, [LINK_OK], id="web-chosen"),
    pytest.param("contents", YOUTUBE, False, [], id="youtube"),
    pytest.param("contents/share", YOUTUBE, False, [], id="youtube-share"),
    pytest.param("contents", INSTAGRAM, False, [LINK_OK, AI_OK], id="instagram"),
    pytest.param("contents/share", SHARE, False, [SHARE_OK, LINK_OK, AI_OK], id="instagram-share"),
])
async def test_link_save_step_order(api, upstream, save_logs, route, url, chosen, expected):
    headers, _, _ = await guest(api)
    category = await request(
        api, "POST", "categories", headers=headers, status=201, json={"name": CATEGORY},
    )
    upstream.provider.recommendation["category_id"] = category["id"]
    payload = (
        {"url": url, "raw_text": SHARED_TEXT} if route.endswith("/share")
        else {"original_url": url}
    )
    if chosen:
        payload["category_ids"] = [category["id"]]
    await request(api, "POST", route, headers=headers, status=201, json=payload)

    assert_steps(save_logs, expected)
    expected_metadata = [] if url == YOUTUBE else ([SHARE, INSTAGRAM] if url == SHARE else [url])
    assert upstream.metadata_calls == expected_metadata
    assert upstream.provider.calls == (["recommend"] if AI_OK in expected else [])


@pytest.mark.parametrize("route,payload,reason,expected", [
    pytest.param(
        "contents/share", {"url": SHARE}, "timeout",
        ("instagram_share_resolve", "failed", "timeout"), id="share-resolve-failed",
    ),
    pytest.param(
        "contents", {"original_url": WEB}, "unsafe_url",
        ("link_metadata", "failed", "unsafe_url"), id="unsafe-url",
    ),
])
async def test_rejected_link_logs_the_attempted_step(
    api, upstream, save_logs, route, payload, reason, expected,
):
    headers, _, _ = await guest(api)
    upstream.metadata_reason = reason
    await request(api, "POST", route, headers=headers, status=422, json=payload)

    assert_steps(save_logs, [expected])
    assert upstream.provider.calls == []


@pytest.mark.parametrize("case,expected", [
    pytest.param("text", [OCR_OK, AI_OK], id="text"),
    pytest.param("no-text", [("screenshot_ocr", "no_text", None)], id="no-text"),
    pytest.param("timeout", [("screenshot_ocr", "failed", "timeout")], id="timeout"),
    pytest.param("missing-field", [("screenshot_ocr", "failed", "invalid_response")], id="invalid"),
])
async def test_screenshot_save_steps_match_event_metadata(
    api, upstream, save_logs, png_bytes, database_connection, case, expected,
):
    headers, _, _ = await guest(api)
    if case == "no-text":
        upstream.provider.ocr["text"] = ""
    elif case == "timeout":
        upstream.provider.error = "timeout"
    elif case == "missing-field":
        del upstream.provider.ocr["text"]
    image = png_bytes + IMAGE
    saved = await request(
        api, "POST", "uploads/screenshots", headers=headers, status=201,
        files={"file": ("image.png", image, "image/png")},
    )

    assert upstream.provider.calls == (["ocr", "recommend"] if case == "text" else ["ocr"])
    metadata = await created_metadata(database_connection, saved["id"])
    assert (metadata["ocr_status"], metadata["ocr_failure_reason"]) == expected[0][1:]
    asset = (await database_connection.execute(
        select(ContentAsset.storage_key, ContentAsset.sha256).where(
            ContentAsset.content_id == saved["id"],
        )
    )).one()
    assert_steps(
        save_logs, expected,
        private_markers=(asset.storage_key, asset.sha256, b64encode(image).decode("ascii")),
    )


@pytest.mark.parametrize("fields,expected", [
    pytest.param({"category_id": "wrong-id-marker-458"}, (
        "category_recommendation", "uncategorized", "invalid_response",
    ), id="invalid-category-id"),
    pytest.param({"tags": "tag-marker-458"}, AI_OK, id="string-tags"),
    pytest.param({"tags": [TAG, 42, [RAW_RESPONSE]]}, AI_OK, id="mixed-tags"),
    pytest.param({"category_id": None}, (
        "category_recommendation", "uncategorized", "no_match",
    ), id="no-match-after-call"),
])
async def test_recommendation_log_matches_event_metadata(
    api, upstream, save_logs, database_connection, fields, expected,
):
    headers, _, _ = await guest(api)
    upstream.provider.recommendation.update(fields)
    saved = await request(
        api, "POST", "contents", headers=headers, status=201, json={"original_url": WEB},
    )

    assert_steps(save_logs, [LINK_OK, expected])
    assert upstream.provider.calls == ["recommend"]
    metadata = await created_metadata(database_connection, saved["id"])
    assert (metadata["metadata_status"], metadata["metadata_failure_reason"]) == LINK_OK[1:]
    assert (
        metadata["category_assignment_method"], metadata["category_recommendation_failure_reason"],
    ) == expected[1:]


@pytest.mark.parametrize("absent", ["candidates", "input"])
async def test_link_without_recommendation_prerequisite_has_no_ai_log(
    api, upstream, save_logs, database_connection, absent,
):
    headers, _, user = await guest(api)
    expected = LINK_OK
    if absent == "candidates":
        await database_connection.execute(delete(Category).where(Category.user_id == user["id"]))
    else:
        upstream.metadata_reason = "metadata_missing"
        expected = ("link_metadata", "failed", "metadata_missing")
    await request(api, "POST", "contents", headers=headers, status=201, json={"original_url": WEB})

    assert_steps(save_logs, [expected])
    assert upstream.provider.calls == []


async def test_idempotent_replay_has_no_external_steps(api, upstream, save_logs):
    headers, _, _ = await guest(api)
    headers["Idempotency-Key"] = str(uuid4())
    payload = {"url": SHARE, "raw_text": SHARED_TEXT}
    saved = await request(api, "POST", "contents/share", headers=headers, status=201, json=payload)
    assert_steps(save_logs, [SHARE_OK, LINK_OK, AI_OK])
    save_logs.records.clear()
    save_logs.rendered.seek(0)
    save_logs.rendered.truncate()

    replay = await request(api, "POST", "contents/share", headers=headers, status=201, json=payload)

    assert replay == saved
    assert_steps(save_logs, [])
    assert upstream.metadata_calls == [SHARE, INSTAGRAM]
    assert upstream.provider.calls == ["recommend"]


async def created_metadata(connection, content_id):
    raw = await connection.scalar(select(ContentEvent.metadata_json).where(
        ContentEvent.content_id == content_id,
        ContentEvent.event_type == ContentEventType.CONTENT_CREATED,
    ))
    return json.loads(raw)
