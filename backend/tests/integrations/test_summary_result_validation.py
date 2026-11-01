"""Locks how each summary client judges a model answer (spec #147 "카테고리 값 처리 표").

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


async def summarize_youtube(title="제목", summary="요약", category_id=None):
    answer = {"title": title, "summary": summary, "category_id": category_id}

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


SUMMARIZERS = {"youtube": summarize_youtube, "instagram": summarize_instagram}


async def rejected(summarize, **answer):
    with pytest.raises(Exception) as caught:
        await summarize(**answer)
    assert type(caught.value).__name__ == "SummaryError"
    return caught.value


@pytest.mark.parametrize("kind", ["youtube", "instagram"])
async def test_title_and_summary_at_the_length_limit_are_kept_trimmed(kind):
    result = await SUMMARIZERS[kind](title=f"  {TITLE_120} ", summary=f"\n{SUMMARY_500}  ")

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
@pytest.mark.parametrize("kind", ["youtube", "instagram"])
async def test_title_or_summary_outside_the_limits_is_an_invalid_response(kind, answer):
    error = await rejected(SUMMARIZERS[kind], **answer)

    assert error.code == "invalid_response"
    assert error.provider == ("openai" if kind == "instagram" else None)


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
