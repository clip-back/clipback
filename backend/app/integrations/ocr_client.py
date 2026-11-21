from __future__ import annotations

import asyncio
import base64
import re

from openai import (
    APIConnectionError,
    APITimeoutError,
    AsyncOpenAI,
    ContentFilterFinishReasonError,
    LengthFinishReasonError,
    OpenAIError,
)
from pydantic import BaseModel, Field, ValidationError

from app.core.config import Settings, settings
from app.integrations.ai_tags import TAG_PROMPT, AIResponseTags
from app.integrations.summary import (
    MAX_HEADLINE_LENGTH,
    MAX_POINT_LENGTH,
    MAX_SUMMARY_POINTS,
    SUMMARY_PROMPT,
    SummaryError,
    join_headline_and_points,
)
from app.schemas.tag import clean_ai_tag_names
from app.schemas.text import contains_unstorable_text

MAX_OCR_TEXT_LENGTH = 5_000
MAX_OCR_TITLE_LENGTH = 120
INLINE_WHITESPACE_PATTERN = re.compile(r"[\t\v\f ]+")
WHITESPACE_PATTERN = re.compile(r"\s+")


class OCRClientError(Exception):
    pass


class OCRClientNotConfiguredError(OCRClientError):
    pass


class OCRClientTimeoutError(OCRClientError):
    pass


class OCRClientInvalidResponseError(OCRClientError):
    pass


class ScreenshotOCRResult(BaseModel):
    text: str
    title: str
    summary: str
    tag_names: list[str] = Field(default_factory=list)


class ScreenshotOCROutput(BaseModel):
    """What the model answers; extract() joins headline and points into the summary (#315).

    The length and count limits go to the request schema only, as in the Instagram summary:
    the shared cleaning rules enforce the count and total length.
    """

    text: str
    title: str
    headline: str = Field(json_schema_extra={"maxLength": MAX_HEADLINE_LENGTH})
    points: list[str] = Field(
        json_schema_extra={
            "items": {"type": "string", "maxLength": MAX_POINT_LENGTH},
            "maxItems": MAX_SUMMARY_POINTS,
        }
    )
    tags: AIResponseTags = None


class OCRClient:
    def __init__(
        self,
        config: Settings = settings,
        client: AsyncOpenAI | None = None,
    ) -> None:
        self.config = config
        self._client = client
        if self._client is None and config.openai_api_key is not None:
            api_key = config.openai_api_key.get_secret_value().strip()
            if api_key:
                self._client = AsyncOpenAI(
                    api_key=api_key,
                    timeout=config.ocr_timeout_seconds,
                    max_retries=0,
                )

    async def extract(
        self,
        *,
        image_bytes: bytes,
        mime_type: str,
    ) -> ScreenshotOCRResult:
        if self._client is None:
            raise OCRClientNotConfiguredError("OpenAI client is not configured")

        image_data_url = (
            f"data:{mime_type};base64,{base64.b64encode(image_bytes).decode('ascii')}"
        )
        try:
            async with asyncio.timeout(self.config.ocr_timeout_seconds):
                response = await self._client.responses.parse(
                    model=self.config.ocr_model,
                    input=[
                        {
                            "role": "system",
                            "content": (
                                "스크린샷 속 글자를 근거로 한국어 제목과 요약을 작성한다. "
                                "글자는 읽는 순서대로 추출하고 text에는 원문 언어를 유지해 "
                                f"최대 {MAX_OCR_TEXT_LENGTH:,}자까지 담는다. "
                                "제목은 공백 포함 25자 안팎으로 핵심 대상만 밝힌다. "
                                f"{SUMMARY_PROMPT} "
                                f"사진의 요점 개수는 0–{MAX_SUMMARY_POINTS}개다. "
                                "근거가 없으면 요점 없이 핵심 한 줄만 쓴다. "
                                "짧은 글의 사실이 핵심 한 줄에 모두 담겨도 요점은 쓰지 않는다. "
                                "의미 있는 글자가 없으면 text, title, headline은 빈 문자열, "
                                "points는 빈 목록으로 반환한다." + TAG_PROMPT
                            ),
                        },
                        {
                            "role": "user",
                            "content": [
                                {
                                    "type": "input_text",
                                    "text": "Extract and summarize this screenshot.",
                                },
                                {
                                    "type": "input_image",
                                    "image_url": image_data_url,
                                    "detail": "original",
                                },
                            ],
                        },
                    ],
                    text_format=ScreenshotOCROutput,
                    reasoning={"effort": "none"},
                    max_output_tokens=self.config.ocr_max_output_tokens,
                    store=False,
                )
        except (TimeoutError, APITimeoutError) as exc:
            raise OCRClientTimeoutError from exc
        except (
            ContentFilterFinishReasonError,
            LengthFinishReasonError,
            ValidationError,
            TypeError,
            ValueError,
        ) as exc:
            raise OCRClientInvalidResponseError from exc
        except (APIConnectionError, OpenAIError) as exc:
            raise OCRClientError from exc
        except Exception as exc:
            raise OCRClientError from exc

        try:
            for output in response.output:
                if output.type != "message":
                    continue
                if any(item.type == "refusal" for item in output.content):
                    raise OCRClientInvalidResponseError
            parsed = response.output_parsed
        except OCRClientInvalidResponseError:
            raise
        except (AttributeError, TypeError, ValueError) as exc:
            raise OCRClientInvalidResponseError from exc

        if response.status != "completed" or not isinstance(parsed, ScreenshotOCROutput):
            raise OCRClientInvalidResponseError

        text = self._normalize_ocr_text(parsed.text)
        if not text:
            return ScreenshotOCRResult(text="", title="", summary="")
        title = self._normalize_inline_text(parsed.title, MAX_OCR_TITLE_LENGTH)
        if contains_unstorable_text(title):
            raise OCRClientInvalidResponseError
        try:
            summary = join_headline_and_points(parsed.headline, parsed.points, for_link=False)
        except SummaryError as exc:
            raise OCRClientInvalidResponseError from exc
        return ScreenshotOCRResult(
            text=text,
            title=title,
            summary=summary,
            tag_names=clean_ai_tag_names(parsed.tags),
        )

    async def close(self) -> None:
        if self._client is not None:
            await self._client.close()

    @staticmethod
    def _normalize_ocr_text(value: str) -> str:
        normalized_lines = [
            INLINE_WHITESPACE_PATTERN.sub(" ", line).strip()
            for line in value.replace("\r\n", "\n").replace("\r", "\n").split("\n")
        ]
        return "\n".join(line for line in normalized_lines if line)[:MAX_OCR_TEXT_LENGTH]

    @staticmethod
    def _normalize_inline_text(value: str, limit: int) -> str:
        return WHITESPACE_PATTERN.sub(" ", value).strip()[:limit]


_ocr_client: OCRClient | None = None


def get_ocr_client() -> OCRClient:
    global _ocr_client
    if _ocr_client is None:
        _ocr_client = OCRClient()
    return _ocr_client


async def close_ocr_client() -> None:
    global _ocr_client
    if _ocr_client is not None:
        await _ocr_client.close()
        _ocr_client = None
