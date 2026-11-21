"""The kind-neutral summary result and error that every summary client shares."""

import json
import re

import httpx
import pytest

from app.integrations import summary, youtube_summary_client as youtube
from tests.integrations.test_instagram_summary_client import (
    build,
    completion,
    page,
    summarize as summarize_instagram,
)
from tests.integrations.test_ocr_client import screenshot_prompt
from tests.integrations.test_youtube_summary_client import config, output, video


async def summarize_youtube(gemini):
    def handler(request):
        return httpx.Response(200, json=video("PT5M")) if request.method == "GET" else gemini

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as http:
        return await youtube.YouTubeSummaryClient(config(), http).summarize(
            "dQw4w9WgXcQ", "model", []
        )


@pytest.mark.asyncio
async def test_both_kinds_return_the_shared_summary_result():
    instagram_client, _ = build(lambda r: page(), lambda r: completion())

    for result in (
        await summarize_youtube(httpx.Response(200, json=output())),
        await summarize_instagram(instagram_client),
    ):
        assert type(result) is summary.SummaryResult


@pytest.mark.asyncio
async def test_both_kinds_raise_the_shared_summary_error():
    instagram_client, _ = build(lambda r: httpx.Response(404), lambda r: completion())

    with pytest.raises(summary.SummaryError):
        await summarize_youtube(httpx.Response(500))
    with pytest.raises(summary.SummaryError):
        await summarize_instagram(instagram_client)


@pytest.mark.asyncio
async def test_youtube_and_instagram_send_the_same_summary_instructions():
    gemini_requests = []

    def gemini(request):
        if request.method == "GET":
            return httpx.Response(200, json=video("PT5M"))
        gemini_requests.append(json.loads(request.content))
        return httpx.Response(200, json=output())

    async with httpx.AsyncClient(transport=httpx.MockTransport(gemini)) as http:
        await youtube.YouTubeSummaryClient(config(), http).summarize("dQw4w9WgXcQ", "model", [])
    instagram_client, seen = build(lambda r: page(), lambda r: completion())
    await summarize_instagram(instagram_client)

    (gemini_body,) = gemini_requests
    (openai_request,) = seen["openai"]
    youtube_prompt = gemini_body["systemInstruction"]["parts"][0]["text"]
    instagram_prompt = json.loads(openai_request.content)["input"][0]["content"]
    photo_prompt = await screenshot_prompt()
    common_section = r"요약은 headline\(핵심 한 줄\).*?확인되지 않은 내용을 추측하지 마라\."
    youtube_section = re.search(common_section, youtube_prompt, re.DOTALL)
    instagram_section = re.search(common_section, instagram_prompt, re.DOTALL)
    photo_section = re.search(common_section, photo_prompt, re.DOTALL)

    assert youtube_section is not None
    assert instagram_section is not None
    assert youtube_section[0] == instagram_section[0]
    assert photo_section is not None
    assert youtube_section[0] == photo_section[0]
    for phrase in [
        "핵심 한 줄", "요점", "1–10개", "80자", "명사형", "마침표", "기호",
        "번호", "마크다운", "되풀이", "재료", "단계", "추측",
    ]:
        assert phrase in youtube_section[0]
    for instruction in [
        "근거가 적으면 적게 쓰고 요점을 지어내지 마라",
        "핵심 사실·수치·조건을 유지하라",
    ]:
        assert instruction in youtube_section[0]
