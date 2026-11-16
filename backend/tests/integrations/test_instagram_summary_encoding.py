import pytest

from tests.integrations.test_instagram_summary_image import (
    build,
    page,
    sent_content,
    sent_images,
    summarize,
)
from tests.integrations.test_metadata_encoding import ResponseStream, encoded_response
from tests.services.test_summary_logging import instagram_worker, logged_record


@pytest.mark.asyncio
async def test_unsupported_page_encoding_fails_without_retry_and_logs_reason():
    stream = ResponseStream(b"unread")
    client, seen = build(encoded_response(stream, "gzip, gzip"), None)
    worker, _ = instagram_worker(client)

    record, _ = await logged_record(worker)

    assert record["error_code"] == "provider_error"
    assert record["reason"] == "unsupported_encoding"
    assert record["retryable"] is False
    assert record["provider"] == "instagram"
    assert len(seen["page"]) == 1
    assert seen["image"] == seen["openai"] == []
    assert stream.reads == 0 and stream.closed


@pytest.mark.asyncio
async def test_unsupported_image_encoding_uses_caption_without_retry():
    stream = ResponseStream(b"unread")
    client, seen = build(page(), lambda request: encoded_response(stream, "br"))

    result = await summarize(client)

    assert result.title == "성수동 카페 소개"
    assert len(seen["image"]) == 1 and sent_images(seen) == []
    assert any("성수동 카페 신메뉴 출시." in part.get("text", "") for part in sent_content(seen))
    assert stream.reads == 0 and stream.closed


@pytest.mark.asyncio
async def test_unsupported_image_encoding_logs_caption_only_success():
    stream = ResponseStream(b"unread")
    client, seen = build(page(), lambda request: encoded_response(stream, "br"))

    record, _ = await logged_record(instagram_worker(client)[0])

    assert record["error_code"] is None and record["provider"] == "openai"
    assert record["image"] == {
        "used": False, "reason": "unsupported_encoding", "http_status": None
    }
    assert len(seen["image"]) == 1 and sent_images(seen) == []
    assert stream.reads == 0 and stream.closed
