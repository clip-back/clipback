"""Locks how each summary client judges a model answer (spec #147 "카테고리 값 처리 표",
spec #203 "공통 정리 규칙과 결과 판정").

YouTube judges the decoded JSON value; Instagram judges the value after the OpenAI SDK's
Pydantic parsing, so the same answer can end differently for the two kinds.
"""

import json

import httpx
import pytest
from openai import AsyncOpenAI

from app.core.config import Settings
from app.integrations.instagram_summary_client import InstagramSummaryClient
from app.integrations.metadata_client import MetadataClient
from app.integrations.youtube_summary_client import YouTubeSummaryClient
from tests.integrations.test_instagram_summary_client import completion, page, public_resolver
from tests.integrations.test_youtube_summary_client import config, video

pytestmark = pytest.mark.asyncio

CANDIDATES = [{"id": 1, "name": "맛집"}, {"id": 7, "name": "여행"}]
TITLE_120 = "가" * 120
SUMMARY_500 = "나" * 500


def gemini_answer(answer):
    return {
        "candidates": [
            {
                "finishReason": "STOP",
                "content": {"parts": [{"text": json.dumps(answer, ensure_ascii=False)}]},
            }
        ],
        "usageMetadata": {"promptTokenCount": 100},
    }


async def summarize_youtube(title="제목", headline="핵심", points=("요점",), category_id=None):
    return await summarize_youtube_answer(
        {"title": title, "headline": headline, "points": points, "category_id": category_id}
    )


async def summarize_youtube_answer(answer):
    def handler(request):
        if request.method == "GET":
            return httpx.Response(200, json=video("PT5M"))
        return httpx.Response(200, json=gemini_answer(answer))

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as http:
        return await YouTubeSummaryClient(config(), http).summarize(
            "dQw4w9WgXcQ", "model", CANDIDATES
        )


async def summarize_instagram(title="제목", summary="요약", category_id=None):
    metadata = MetadataClient(
        http_transport=httpx.MockTransport(lambda r: page()), resolver=public_resolver
    )
    openai = AsyncOpenAI(
        api_key="test",
        max_retries=0,
        http_client=httpx.AsyncClient(
            transport=httpx.MockTransport(
                lambda r: completion(title=title, summary=summary, category_id=category_id)
            )
        ),
    )
    settings = Settings(_env_file=None, youtube_summary_enabled=False)
    client = InstagramSummaryClient(settings, metadata, openai)
    return await client.summarize("https://www.instagram.com/reel/ABC123/", "model", CANDIDATES)


async def rejected(summarize, **answer):
    with pytest.raises(Exception) as caught:
        await summarize(**answer)
    assert type(caught.value).__name__ == "SummaryError"
    return caught.value


async def test_title_and_summary_at_the_length_limit_are_kept_trimmed():
    result = await summarize_instagram(title=f"  {TITLE_120} ", summary=f"\n{SUMMARY_500}  ")

    assert (result.title, result.summary) == (TITLE_120, SUMMARY_500)


@pytest.mark.parametrize(
    "answer",
    [
        {"title": TITLE_120 + "가"},
        {"summary": SUMMARY_500 + "나"},
        {"title": "   "},
        {"summary": " \n "},
        {"title": ""},
        {"summary": ""},
    ],
    ids=[
        "title-121", "summary-501", "blank-title", "blank-summary", "empty-title", "empty-summary",
    ],
)
async def test_title_or_summary_outside_the_limits_is_an_invalid_response(answer):
    error = await rejected(summarize_instagram, **answer)

    assert (error.code, error.provider) == ("invalid_response", "openai")


@pytest.mark.parametrize(
    "category_id,youtube,instagram",
    [
        (7, 7, 7),
        (99, None, None),
        (None, None, None),
        ("7", None, 7),
        (True, None, 1),
        (7.0, None, 7),
    ],
    ids=["candidate", "not-a-candidate", "null", "numeric-string", "true", "float"],
)
async def test_category_value_is_judged_after_each_kinds_own_parsing(
    category_id, youtube, instagram
):
    assert (await summarize_youtube(category_id=category_id)).category_id == youtube
    assert (await summarize_instagram(category_id=category_id)).category_id == instagram


@pytest.mark.parametrize("category_id", ["abc", 7.5, [7], {"id": 7}])
async def test_category_value_pydantic_cannot_read_fails_only_the_instagram_summary(category_id):
    assert (await summarize_youtube(category_id=category_id)).category_id is None

    error = await rejected(summarize_instagram, category_id=category_id)
    assert (error.code, error.provider) == ("invalid_response", "openai")


FIVE = ["요점1", "요점2", "요점3", "요점4", "요점5"]
FIVE_JOINED = "핵심\n• 요점1\n• 요점2\n• 요점3\n• 요점4\n• 요점5"
# Headline 45 + five times ("\n• " 3 + point 88) = 500; one more headline character is 501.
POINTS_88 = ["나" * 88] * 5
JOINED_500 = "\n".join(["가" * 45, *[f"• {'나' * 88}"] * 5])
assert len(JOINED_500) == 500


def point(text):
    return {"points": [text]}


@pytest.mark.parametrize(
    "answer,summary",
    [
        ({"points": ["내용"]}, "핵심\n• 내용"),
        (point("• 내용"), "핵심\n• 내용"),
        (point("· 내용"), "핵심\n• 내용"),
        (point("- 내용"), "핵심\n• 내용"),
        (point("* 내용"), "핵심\n• 내용"),
        (point("2. 내용"), "핵심\n• 내용"),
        (point("3) 내용"), "핵심\n• 내용"),
        (point("10. 내용"), "핵심\n• 내용"),
        (point("  - 내용"), "핵심\n• 내용"),
        (point("•내용"), "핵심\n• 내용"),
        (point("·내용"), "핵심\n• 내용"),
        (point("-12% 하락"), "핵심\n• -12% 하락"),
        (point("1위 홀마크"), "핵심\n• 1위 홀마크"),
        (point("1.5배 증가"), "핵심\n• 1.5배 증가"),
        (point("2)내용"), "핵심\n• 2)내용"),
        (point("• · 내용"), "핵심\n• · 내용"),
        (point("내용 - 부연"), "핵심\n• 내용 - 부연"),
        ({"points": ["", "  ", "내용"]}, "핵심\n• 내용"),
        ({"points": ["- ", "내용"]}, "핵심\n• 내용"),
        ({"points": ["•", "내용"]}, "핵심\n• 내용"),
        ({"points": ["3) ", "내용"]}, "핵심\n• 내용"),
        (point("a\nb"), "핵심\n• a b"),
        (point("a\r\nb"), "핵심\n• a b"),
        (point("a\rb"), "핵심\n• a b"),
        (point("a\n\nb"), "핵심\n• a b"),
        (point("a \n b"), "핵심\n• a b"),
        (point("a  b"), "핵심\n• a b"),
        (point("a   b"), "핵심\n• a b"),
        (point("-  내용"), "핵심\n• 내용"),
        ({"headline": "핵심\n추가"}, "핵심 추가\n• 요점"),
        ({"headline": "핵심\r\n추가"}, "핵심 추가\n• 요점"),
        ({"headline": "핵심\n\n추가"}, "핵심 추가\n• 요점"),
        ({"headline": "핵심  추가"}, "핵심 추가\n• 요점"),
        ({"headline": "  핵심 \n"}, "핵심\n• 요점"),
        ({"headline": "- 핵심"}, "- 핵심\n• 요점"),
        ({"points": [*FIVE, "요점6"]}, FIVE_JOINED),
        ({"points": ["", *FIVE]}, FIVE_JOINED),
        ({"points": [*FIVE, "다" * 500]}, FIVE_JOINED),
        ({"headline": "가" * 41, "points": ["나" * 61]}, f"{'가' * 41}\n• {'나' * 61}"),
        ({"headline": "가" * 45, "points": POINTS_88}, JOINED_500),
    ],
    ids=[
        "plain", "mark-bullet", "mark-middle-dot", "mark-dash", "mark-star", "mark-number-dot",
        "mark-number-paren", "mark-two-digit", "space-then-mark", "bullet-no-space",
        "middle-dot-no-space", "kept-minus-number", "kept-rank", "kept-decimal",
        "kept-number-paren-no-space", "only-first-mark", "kept-inner-dash", "blank-points-dropped",
        "dash-only-dropped", "bullet-only-dropped", "number-paren-only-dropped", "point-lf",
        "point-crlf", "point-cr", "point-double-lf", "point-spaced-lf", "point-two-spaces",
        "point-three-spaces", "dash-two-spaces", "headline-lf", "headline-crlf",
        "headline-double-lf", "headline-two-spaces", "headline-trimmed", "headline-mark-kept",
        "six-points-first-five", "blank-then-five", "five-then-very-long", "over-hint-lengths",
        "exactly-500",
    ],
)
async def test_youtube_headline_and_points_are_cleaned_and_joined(answer, summary):
    result = await summarize_youtube(**answer)

    assert result.summary == summary


async def test_youtube_title_and_joined_summary_at_the_length_limit_are_kept_trimmed():
    result = await summarize_youtube(title=f"  {TITLE_120} ", headline="가" * 45, points=POINTS_88)

    assert (result.title, result.summary) == (TITLE_120, JOINED_500)


@pytest.mark.parametrize(
    "answer",
    [
        {"headline": ""},
        {"headline": "   "},
        {"headline": " \r\n\n "},
        {"points": []},
        {"points": ["- "]},
        {"points": ["•"]},
        {"points": ["", " "]},
        {"headline": "가" * 46, "points": POINTS_88},
        {"points": [*FIVE, 7]},
        {"points": [*FIVE, None]},
        {"headline": None},
        {"headline": 7},
        {"headline": True},
        {"headline": ["핵심"]},
        {"headline": {"text": "핵심"}},
        {"points": None},
        {"points": 7},
        {"points": "내용"},
        {"points": {"text": "내용"}},
        {"points": ["내용", 7]},
        {"points": ["내용", None]},
        {"points": ["내용", {"text": "내용"}]},
        {"points": ["내용", ["내용"]]},
        {"title": ""},
        {"title": "   "},
        {"title": TITLE_120 + "가"},
    ],
    ids=[
        "empty-headline", "blank-headline", "line-break-headline", "no-points", "dash-only",
        "bullet-only", "blank-points-only", "joined-501", "five-then-number", "five-then-null",
        "headline-null", "headline-number", "headline-bool", "headline-array", "headline-object",
        "points-null", "points-number", "points-string", "points-object", "point-number",
        "point-null", "point-object", "point-array", "empty-title", "blank-title", "title-121",
    ],
)
async def test_youtube_answer_the_cleaning_rules_reject_is_an_invalid_response(answer):
    error = await rejected(summarize_youtube, **answer)

    assert (error.code, error.retryable, error.provider) == ("invalid_response", False, None)


@pytest.mark.parametrize(
    "answer",
    [
        {"title": "제목", "headline": "핵심", "category_id": None},
        {"title": "제목", "points": ["요점"], "category_id": None},
        {"title": "제목", "headline": "핵심", "points": ["요점"]},
        {"title": "제목", "headline": "핵심", "points": ["요점"], "category_id": None, "x": 1},
        {
            "title": "제목", "headline": "핵심", "points": ["요점"], "summary": "요약",
            "category_id": None,
        },
        {"title": "제목", "summary": "요약", "category_id": None},
    ],
    ids=[
        "missing-points", "missing-headline", "missing-category", "extra-key",
        "extra-summary", "old-summary-only",
    ],
)
async def test_youtube_answer_without_the_exact_keys_is_an_invalid_response(answer):
    error = await rejected(summarize_youtube_answer, answer=answer)

    assert (error.code, error.retryable, error.provider) == ("invalid_response", False, None)
