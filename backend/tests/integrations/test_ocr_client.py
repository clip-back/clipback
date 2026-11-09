import asyncio
import base64
from types import SimpleNamespace

import httpx
import pytest
from openai import APIConnectionError, APITimeoutError

from app.core.config import Settings
from app.integrations import ocr_client as ocr_client_module
from app.integrations.ocr_client import (
    MAX_OCR_SUMMARY_LENGTH,
    MAX_OCR_TEXT_LENGTH,
    MAX_OCR_TITLE_LENGTH,
    OCRClient,
    OCRClientError,
    OCRClientInvalidResponseError,
    OCRClientNotConfiguredError,
    OCRClientTimeoutError,
    ScreenshotOCROutput,
    ScreenshotOCRResult,
)


class FakeResponses:
    def __init__(self, response=None, error: Exception | None = None) -> None:
        self.response = response
        self.error = error
        self.kwargs: dict[str, object] | None = None

    async def parse(self, **kwargs):
        self.kwargs = kwargs
        if self.error is not None:
            raise self.error
        return self.response


class FakeOpenAI:
    def __init__(self, responses: FakeResponses) -> None:
        self.responses = responses
        self.closed = False

    async def close(self) -> None:
        self.closed = True


class SlowResponses(FakeResponses):
    async def parse(self, **kwargs):
        await asyncio.sleep(1)


def config() -> Settings:
    return Settings(
        app_environment="test",
        openai_api_key="test-key",
        ocr_timeout_seconds=5,
        ocr_max_output_tokens=4096,
        _env_file=None,
    )


def completed_response(result: ScreenshotOCROutput):
    return SimpleNamespace(status="completed", output=[], output_parsed=result)


def test_sdk_client_disables_retries_and_uses_ocr_timeout(monkeypatch) -> None:
    captured: dict[str, object] = {}

    def build_client(**kwargs):
        captured.update(kwargs)
        return FakeOpenAI(FakeResponses())

    monkeypatch.setattr(ocr_client_module, "AsyncOpenAI", build_client)

    OCRClient(config())

    assert captured["api_key"] == "test-key"
    assert captured["timeout"] == 5
    assert captured["max_retries"] == 0


@pytest.mark.asyncio
async def test_extract_uses_canonical_mime_and_fixed_operational_options() -> None:
    result = ScreenshotOCROutput(
        text="  첫째 줄  \r\n\r\n둘째\t줄  ",
        title="  채용   공고  ",
        headline="  한국어\n요약  ",
        points=["  • 첫\n요점 "],
    )
    responses = FakeResponses(response=completed_response(result))
    openai_client = FakeOpenAI(responses)
    client = OCRClient(config(), client=openai_client)

    extracted = await client.extract(image_bytes=b"image-bytes", mime_type="image/png")

    assert extracted == ScreenshotOCRResult(
        text="첫째 줄\n둘째 줄",
        title="채용 공고",
        summary="한국어 요약\n• 첫 요점",
    )
    assert responses.kwargs is not None
    assert responses.kwargs["model"] == "gpt-5.4-nano-2026-03-17"
    assert responses.kwargs["text_format"] is ScreenshotOCROutput
    assert responses.kwargs["reasoning"] == {"effort": "none"}
    assert responses.kwargs["max_output_tokens"] == 4096
    assert responses.kwargs["store"] is False
    image_input = responses.kwargs["input"][1]["content"][1]
    assert image_input["detail"] == "original"
    encoded = base64.b64encode(b"image-bytes").decode("ascii")
    assert image_input["image_url"] == f"data:image/png;base64,{encoded}"
    assert "untrusted data" in responses.kwargs["input"][0]["content"]
    assert "공백 포함 25자 안팎" in responses.kwargs["input"][0]["content"]
    assert "핵심 대상" in responses.kwargs["input"][0]["content"]

    await client.close()
    assert openai_client.closed is True


@pytest.mark.asyncio
async def test_extract_limits_normalized_fields() -> None:
    client = OCRClient(
        config(),
        client=FakeOpenAI(
            FakeResponses(
                response=completed_response(
                    ScreenshotOCROutput(
                        text="가" * (MAX_OCR_TEXT_LENGTH + 1),
                        title="나" * (MAX_OCR_TITLE_LENGTH + 1),
                        headline="다" * MAX_OCR_SUMMARY_LENGTH,
                        points=["라"],
                    )
                )
            )
        ),
    )

    result = await client.extract(image_bytes=b"image", mime_type="image/jpeg")

    assert len(result.text) == MAX_OCR_TEXT_LENGTH
    assert len(result.title) == MAX_OCR_TITLE_LENGTH
    assert len(result.summary) == MAX_OCR_SUMMARY_LENGTH


@pytest.mark.asyncio
async def test_extract_discards_title_and_summary_when_text_is_empty() -> None:
    client = OCRClient(
        config(),
        client=FakeOpenAI(
            FakeResponses(
                response=completed_response(
                    ScreenshotOCROutput(
                        text="  \n", title="추측 제목", headline="추측 요약", points=["추측 요점"]
                    )
                )
            )
        ),
    )

    result = await client.extract(image_bytes=b"image", mime_type="image/webp")

    assert result == ScreenshotOCRResult(text="", title="", summary="")


@pytest.mark.asyncio
async def test_refusal_is_invalid_response() -> None:
    response = SimpleNamespace(
        status="completed",
        output=[
            SimpleNamespace(
                type="message",
                content=[SimpleNamespace(type="refusal", refusal="no")],
            )
        ],
        output_parsed=None,
    )
    client = OCRClient(config(), client=FakeOpenAI(FakeResponses(response=response)))

    with pytest.raises(OCRClientInvalidResponseError):
        await client.extract(image_bytes=b"image", mime_type="image/png")


@pytest.mark.asyncio
async def test_unparsed_response_is_invalid() -> None:
    response = SimpleNamespace(
        status="completed",
        output=[],
        output_parsed={"text": "x", "title": "x", "headline": "x", "points": ["x"]},
    )
    client = OCRClient(config(), client=FakeOpenAI(FakeResponses(response=response)))

    with pytest.raises(OCRClientInvalidResponseError):
        await client.extract(image_bytes=b"image", mime_type="image/png")


@pytest.mark.asyncio
async def test_timeout_and_connection_errors_are_classified() -> None:
    request = httpx.Request("POST", "https://api.openai.com/v1/responses")
    timeout_client = OCRClient(
        config(),
        client=FakeOpenAI(FakeResponses(error=APITimeoutError(request))),
    )
    connection_client = OCRClient(
        config(),
        client=FakeOpenAI(
            FakeResponses(error=APIConnectionError(request=request))
        ),
    )

    with pytest.raises(OCRClientTimeoutError):
        await timeout_client.extract(image_bytes=b"image", mime_type="image/png")
    with pytest.raises(OCRClientError):
        await connection_client.extract(image_bytes=b"image", mime_type="image/png")


@pytest.mark.asyncio
async def test_application_timeout_bounds_the_full_ocr_call() -> None:
    timeout_config = Settings(
        app_environment="test",
        openai_api_key="test-key",
        ocr_timeout_seconds=0.01,
        _env_file=None,
    )
    client = OCRClient(timeout_config, client=FakeOpenAI(SlowResponses()))

    with pytest.raises(OCRClientTimeoutError):
        await client.extract(image_bytes=b"image", mime_type="image/png")


@pytest.mark.asyncio
async def test_missing_key_uses_not_configured_error_without_network_call() -> None:
    client = OCRClient(Settings(app_environment="test", openai_api_key=None, _env_file=None))

    with pytest.raises(OCRClientNotConfiguredError):
        await client.extract(image_bytes=b"image", mime_type="image/png")


async def extract_answer(text="본문", title="제목", headline="핵심", points=("요점",)):
    client = OCRClient(
        config(),
        client=FakeOpenAI(
            FakeResponses(
                response=completed_response(
                    ScreenshotOCROutput(
                        text=text, title=title, headline=headline, points=list(points)
                    )
                )
            )
        ),
    )
    return await client.extract(image_bytes=b"image", mime_type="image/png")


@pytest.mark.asyncio
async def test_photo_summary_is_headline_and_bullet_points() -> None:
    result = await extract_answer(
        headline="성수동 카페 소개", points=["대표 메뉴와 가격", "영업시간"]
    )

    assert result == ScreenshotOCRResult(
        text="본문",
        title="제목",
        summary="성수동 카페 소개\n• 대표 메뉴와 가격\n• 영업시간",
    )


@pytest.mark.asyncio
async def test_photo_summary_without_points_is_the_headline_alone() -> None:
    result = await extract_answer(headline="  짧은\n안내  ", points=["  ", "•"])

    assert result.summary == "짧은 안내"


@pytest.mark.asyncio
async def test_empty_headline_empties_only_the_summary() -> None:
    result = await extract_answer(headline=" \n ", points=["요점"])

    assert result == ScreenshotOCRResult(text="본문", title="제목", summary="")


@pytest.mark.asyncio
@pytest.mark.parametrize("kind", ["youtube", "instagram"])
@pytest.mark.parametrize(
    ("headline", "points"),
    [
        ("  핵심\r\n한 줄  ", ["• 하나", "- 둘", "1. 셋", "2)내용", "-12% 하락"]),
        ("핵심", ["  줄\n바꿈  요점 ", "", "   ", "· 점"]),
        ("핵심", ["일", "이", "삼", "사", "오", "육", "칠"]),
    ],
)
async def test_photo_summary_is_cleaned_like_link_summaries(kind, headline, points) -> None:
    from tests.integrations.test_summary_result_validation import summarize

    link = await summarize(kind, headline=headline, points=points)
    photo = await extract_answer(headline=headline, points=points)

    assert photo.summary == link.summary


def test_ocr_request_asks_for_headline_and_points() -> None:
    schema = ScreenshotOCROutput.model_json_schema()
    properties = schema["properties"]

    assert set(properties) == {"text", "title", "headline", "points"}
    assert properties["headline"]["maxLength"] == 40
    assert properties["points"]["items"] == {"type": "string", "maxLength": 60}
    assert properties["points"]["maxItems"] == 5
    assert "minItems" not in properties["points"]


@pytest.mark.asyncio
async def test_ocr_prompt_asks_for_the_link_summary_format() -> None:
    responses = FakeResponses(
        response=completed_response(
            ScreenshotOCROutput(text="", title="", headline="", points=[])
        )
    )
    client = OCRClient(config(), client=FakeOpenAI(responses))
    await client.extract(image_bytes=b"image", mime_type="image/png")
    prompt = responses.kwargs["input"][0]["content"]

    for phrase in [
        "headline (핵심 한 줄)",
        "points (요점)",
        "at most 40 characters",
        "at most 60 characters each",
        "0–5 points",
        "never invent points or repeat the headline",
        "정보형·명사형 메모체",
        "no trailing period",
        "no bullets, numbering, or markdown",
        '"성수동 카페 소개"',
        "untrusted data",
        "Preserve the source language",
        "5000 characters",
        "공백 포함 25자 안팎",
        "핵심 대상",
    ]:
        assert phrase in prompt
    assert "성수동 카페 소개. 대표 메뉴와 영업시간 안내." not in prompt
