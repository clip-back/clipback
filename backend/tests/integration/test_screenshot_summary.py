import json
from types import SimpleNamespace

import pytest
from sqlalchemy import select

from app.api.v1.endpoints import uploads
from app.integrations.ocr_client import OCRClient
from app.models.content_event import ContentEvent
from tests.integration.helpers import guest, request
from tests.integrations.test_ocr_client import completed_response, config

DEFAULT_TITLE = "저장한 콘텐츠"
DEFAULT_SUMMARY = "요약 정보가 아직 없습니다."
EXTRACTED_TEXT = "첫째 줄\nSecond line"
POINTS = [f"요점 {number}" for number in range(1, 12)]


class ScreenshotOCRClient(OCRClient):
    # The shared API fixture stubs OCRClient.extract. Keep real OCR processing
    # here and record text before category recommendation normalizes it again.
    _extract = OCRClient.extract
    extracted_text: str | None = None

    async def extract(self, *, image_bytes: bytes, mime_type: str):
        result = await self._extract(image_bytes=image_bytes, mime_type=mime_type)
        self.extracted_text = result.text
        return result


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("answer", "ocr_status", "failure_reason", "summary", "title", "extracted_text"),
    [
        pytest.param(
            {"points": [None]}, "failed", "invalid_response", DEFAULT_SUMMARY,
            DEFAULT_TITLE, None, id="parse-error",
        ),
        pytest.param(
            {"text": " \r\n "}, "no_text", None, DEFAULT_SUMMARY,
            DEFAULT_TITLE, "", id="no-text",
        ),
        pytest.param(
            {"headline": " \n "}, "success", None, DEFAULT_SUMMARY,
            "화면 제목", EXTRACTED_TEXT, id="empty-headline",
        ),
        pytest.param(
            {"points": []}, "success", None, "핵심",
            "화면 제목", EXTRACTED_TEXT, id="no-points",
        ),
        pytest.param(
            {"points": POINTS}, "success", None,
            "핵심\n• 요점 1\n• 요점 2\n• 요점 3\n• 요점 4\n• 요점 5"
            "\n• 요점 6\n• 요점 7\n• 요점 8\n• 요점 9\n• 요점 10",
            "화면 제목", EXTRACTED_TEXT, id="eleven-points",
        ),
        pytest.param(
            {"headline": "가" * 989, "points": ["a", "b", "c"]}, "success", None,
            "가" * 989 + "\n• a\n• b", "화면 제목", EXTRACTED_TEXT,
            id="drop-trailing-point",
        ),
        pytest.param(
            {"headline": "h", "points": ["가" * 997, "x"]}, "success", None,
            "h", "화면 제목", EXTRACTED_TEXT, id="drop-all-points",
        ),
        pytest.param(
            {"headline": "가" * 1000 + "나", "points": []}, "success", None,
            "가" * 1000, "화면 제목", EXTRACTED_TEXT, id="trim-headline",
        ),
        pytest.param(
            {"title": "가" * 120 + "나"}, "success", None, "핵심\n• 요점",
            "가" * 120, EXTRACTED_TEXT, id="trim-title",
        ),
    ],
)
async def test_screenshot_summary_from_ocr_to_saved_content(
    api, database_connection, monkeypatch, png_bytes,
    answer, ocr_status, failure_reason, summary, title, extracted_text,
):
    payload = {
        "text": "  첫째 줄 \r\n\r\nSecond\tline  ",
        "title": " 화면  제목 ",
        "headline": "핵심",
        "points": ["요점"],
    } | answer

    async def parse(*, text_format, **_):
        return completed_response(text_format.model_validate(payload))

    sdk = SimpleNamespace(responses=SimpleNamespace(parse=parse))
    ocr = ScreenshotOCRClient(config(), client=sdk)
    monkeypatch.setattr(uploads, "get_ocr_client", lambda: ocr)
    headers, _, _ = await guest(api)
    content = await request(
        api, "POST", "uploads/screenshots", headers=headers, status=201,
        files={"file": ("screen.png", png_bytes, "image/png")},
    )

    assert content["summary"] == summary
    assert content["title"] == title
    metadata_json = (
        await database_connection.execute(
            select(ContentEvent.metadata_json).where(ContentEvent.content_id == content["id"])
        )
    ).scalar_one()
    metadata = json.loads(metadata_json)
    assert metadata["ocr_status"] == ocr_status
    assert metadata["ocr_failure_reason"] == failure_reason
    assert ocr.extracted_text == extracted_text
