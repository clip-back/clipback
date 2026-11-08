"""The title and summary length limits live in one place (#158).

Changing `MAX_TITLE_LENGTH` and `MAX_SUMMARY_LENGTH` in `app.integrations.summary` alone must
change what both prompts tell the model, the YouTube response schema and the shared result
check together. The clients read the values when they are imported, so the check runs in a
fresh interpreter that changes them before importing the clients.
"""

import json
import subprocess
import sys
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[2]

SCRIPT = r"""
import asyncio
import json

import httpx

from app.integrations import summary

summary.MAX_TITLE_LENGTH = 7
summary.MAX_SUMMARY_LENGTH = 5

from app.core.config import Settings
from app.integrations.instagram_summary_client import PROMPT
from app.integrations.summary import SummaryError, validated_result
from app.integrations.youtube_summary_client import YouTubeSummaryClient


async def youtube_body():
    bodies = []

    def handler(request):
        if request.method == "GET":
            video = {
                "status": {"privacyStatus": "public"},
                "snippet": {"liveBroadcastContent": "none"},
                "contentDetails": {"duration": "PT5M"},
            }
            return httpx.Response(200, json={"items": [video]})
        bodies.append(json.loads(request.content))
        return httpx.Response(500)

    config = Settings(
        _env_file=None, youtube_summary_enabled=True, gemini_api_key="t", youtube_data_api_key="t"
    )
    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as http:
        try:
            await YouTubeSummaryClient(config, http).summarize("dQw4w9WgXcQ", "model", [])
        except SummaryError:
            pass
    return bodies[0]


def judged(title, points):
    try:
        validated_result(title, "h", points, None, [], {})
    except SummaryError as error:
        return error.code
    return "ok"


body = asyncio.run(youtube_body())
print(json.dumps({
    "instagram_prompt": PROMPT,
    "youtube_prompt": body["systemInstruction"]["parts"][0]["text"],
    "youtube_title_schema": body["generationConfig"]["responseJsonSchema"]["properties"]["title"],
    "title_7": judged("가" * 7, ["p"]),
    "title_8": judged("가" * 8, ["p"]),
    "summary_5": judged("t", ["p"]),
    "summary_6": judged("t", ["pp"]),
}))
"""


def test_changing_the_shared_limits_changes_prompts_schema_and_check_together():
    run = subprocess.run(
        [sys.executable, "-c", SCRIPT], cwd=BACKEND, capture_output=True, text=True, check=False
    )
    assert run.returncode == 0, run.stderr
    seen = json.loads(run.stdout)

    for kind in ["instagram", "youtube"]:
        prompt = seen[f"{kind}_prompt"]
        assert "제목은 7자 이내." in prompt
        assert "120" not in prompt
    assert seen["youtube_title_schema"] == {"type": "string", "maxLength": 7}
    assert (seen["title_7"], seen["title_8"]) == ("ok", "invalid_response")
    assert (seen["summary_5"], seen["summary_6"]) == ("ok", "invalid_response")
