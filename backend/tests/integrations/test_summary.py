"""The kind-neutral summary result and error that every summary client shares."""

import httpx
import pytest

from app.integrations import summary, youtube_summary_client as youtube
from tests.integrations.test_instagram_summary_client import (
    build,
    completion,
    page,
    summarize as summarize_instagram,
)
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


# Removed together with the re-export in #152.
def test_youtube_client_module_still_exports_the_old_names():
    assert youtube.VideoSummary is summary.SummaryResult
    assert youtube.SummaryError is summary.SummaryError
