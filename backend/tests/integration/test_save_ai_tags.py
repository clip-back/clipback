import json
import logging
from types import SimpleNamespace
from uuid import uuid4

import httpx
import pytest
import pytest_asyncio
from openai import AsyncOpenAI
from sqlalchemy import delete, select

from app.api.v1.endpoints import contents, uploads
from app.core.config import Settings, settings
from app.integrations.ai_client import AIClient, AIClientInvalidResponseError
from app.integrations.metadata_client import MetadataClient, MetadataResult
from app.integrations.ocr_client import OCRClient, OCRClientInvalidResponseError
from app.models.category import Category
from app.models.content_event import ContentEvent
from app.services import usage_limits
from tests.integration.helpers import guest, link, request

pytestmark = pytest.mark.asyncio
WEB = "https://example.com/article"
YOUTUBE = "https://youtu.be/dQw4w9WgXcQ"
INSTAGRAM = "https://www.instagram.com/p/Example/"
STORY = "https://www.instagram.com/stories/example/12345/"
OCR_BODY = {"text": "본문", "title": "화면 제목", "headline": "핵심", "points": ["요점"]}


class ProviderAI(AIClient):
    # The other integration tests install method-level fakes on the base classes.
    suggest_category_id = AIClient.suggest_category_id


class ProviderOCR(OCRClient):
    extract = OCRClient.extract


@pytest_asyncio.fixture
async def provider():
    """Send raw responses through OpenAI's actual schema conversion and parser."""
    state = SimpleNamespace(
        calls=[], requests=[], recommendation={"tags": ["추천"]},
        ocr={**OCR_BODY, "tags": ["사진"]}, error=None,
    )

    def handle(req):
        payload = json.loads(req.content)
        state.requests.append(payload)
        is_ocr = isinstance(payload["input"][1]["content"], list)
        state.calls.append("ocr" if is_ocr else "recommend")
        if state.error == "timeout":
            raise httpx.ReadTimeout("test timeout", request=req)
        if state.error == "connection":
            raise httpx.ConnectError("test connection failure", request=req)

        if is_ocr:
            answer = state.ocr
        else:
            candidates = json.loads(payload["input"][1]["content"])["candidate_categories"]
            answer = {"category_id": candidates[0]["category_id"], **state.recommendation}
        status = "incomplete" if state.error == "truncated" else "completed"
        if state.error == "refusal":
            content = {"type": "refusal", "refusal": "test refusal"}
        else:
            text = json.dumps(answer, ensure_ascii=False)
            if state.error == "truncated":
                text = text[:-2]
            content = {"type": "output_text", "text": text, "annotations": [], "logprobs": []}
        return httpx.Response(200, json={
            "id": "resp_test", "object": "response", "created_at": 0,
            "model": "gpt-test", "status": status, "parallel_tool_calls": False,
            "tool_choice": "auto", "tools": [],
            "incomplete_details": (
                {"reason": "max_output_tokens"} if status == "incomplete" else None
            ),
            "output": [{"id": "msg_test", "type": "message", "role": "assistant",
                        "status": status, "content": [content]}],
        })

    config = Settings(app_environment="test", _env_file=None)
    async with AsyncOpenAI(
        api_key="test", max_retries=0,
        http_client=httpx.AsyncClient(transport=httpx.MockTransport(handle)),
    ) as sdk:
        state.ai_client = ProviderAI(config, client=sdk)
        state.ocr_client = ProviderOCR(config, client=sdk)
        yield state


@pytest.fixture
def save_provider(api, provider, monkeypatch):
    monkeypatch.setattr(contents, "get_ai_client", lambda: provider.ai_client)
    monkeypatch.setattr(uploads, "get_ai_client", lambda: provider.ai_client)
    monkeypatch.setattr(uploads, "get_ocr_client", lambda: provider.ocr_client)
    return provider


async def suggest(client):
    return await client.suggest_category_id(
        title="제목", description=None, source="web", url=WEB,
        shared_text=None, candidates=[(3, "공부")],
    )


async def extract(client):
    return await client.extract(image_bytes=b"image", mime_type="image/png")


@pytest.mark.parametrize("fields,expected", [
    ({}, []),
    ({"tags": None}, []),
    ({"tags": "Python"}, []),
    ({"tags": ["#Python", None, 7, {}, ["안"], "python", "여행", "요리", "넷"]},
     ["Python", "여행", "요리"]),
], ids=["absent", "null", "string", "mixed-array"])
async def test_raw_provider_tags_leave_category_title_and_summary_intact(
    provider, fields, expected,
):
    provider.recommendation = fields
    provider.ocr = {**OCR_BODY, **fields}

    category = await suggest(provider.ai_client)
    ocr = await extract(provider.ocr_client)
    assert category.category_id == 3
    assert (ocr.text, ocr.title, ocr.summary) == ("본문", "화면 제목", "핵심\n• 요점")
    assert category.tag_names == ocr.tag_names == expected
    for payload in provider.requests:
        schema = payload["text"]["format"]["schema"]
        assert schema["properties"]["tags"]["type"] == "array"
        assert schema["properties"]["tags"]["items"] == {"type": "string"}
        assert "tags" in schema["required"]
    assert provider.requests[0]["max_output_tokens"] == 160


@pytest.mark.parametrize("failure", ["invalid-field", "truncated", "refusal"])
async def test_raw_provider_keeps_existing_validation_errors(provider, failure):
    if failure == "invalid-field":
        # Only the tags field is permissive.
        provider.recommendation = {"category_id": {}, "tags": ["추천"]}
        provider.ocr = {**OCR_BODY, "points": [None], "tags": ["사진"]}
    else:
        provider.error = failure

    with pytest.raises(AIClientInvalidResponseError):
        await suggest(provider.ai_client)
    with pytest.raises(OCRClientInvalidResponseError):
        await extract(provider.ocr_client)


async def test_raw_ocr_ignores_tags_when_no_text_is_visible(provider):
    provider.ocr = {**OCR_BODY, "text": " \n", "tags": ["사진"]}
    result = await extract(provider.ocr_client)
    assert (result.text, result.title, result.summary) == ("", "", "")
    assert result.tag_names == []


@pytest.mark.parametrize("route,url,chosen,calls,tags", [
    pytest.param("contents", YOUTUBE, False, [], [], id="youtube"),
    pytest.param("contents", INSTAGRAM, False, ["recommend"], [], id="instagram-post-auto"),
    pytest.param("contents", INSTAGRAM, True, [], [], id="instagram-post-chosen"),
    pytest.param("contents", WEB, False, ["recommend"], ["추천"], id="ordinary-auto"),
    pytest.param("contents", STORY, False, ["recommend"], ["추천"], id="instagram-story-auto"),
    pytest.param("contents", WEB, True, [], [], id="ordinary-chosen"),
    pytest.param("contents/share", YOUTUBE, False, [], [], id="share-youtube"),
    pytest.param("contents/share", INSTAGRAM, False, ["recommend"], [], id="share-post-auto"),
    pytest.param("contents/share", INSTAGRAM, True, [], [], id="share-post-chosen"),
    pytest.param("contents/share", STORY, False, ["recommend"], ["추천"], id="share-story"),
])
async def test_link_tag_source_by_save_route(api, save_provider, route, url, chosen, calls, tags):
    headers, _, _ = await guest(api)
    payload = {"url" if route == "contents/share" else "original_url": url}
    if chosen:
        payload["category_ids"] = [await chosen_category(api, headers)]

    saved = await request(api, "POST", route, status=201, headers=headers, json=payload)

    assert save_provider.calls == calls
    assert [tag["name"] for tag in saved["tags"]] == tags
    detail = await request(api, "GET", f"contents/{saved['id']}", headers=headers)
    assert detail["tags"] == saved["tags"]


async def test_redirect_to_instagram_post_leaves_tags_to_automatic_summary(
    api, save_provider, monkeypatch,
):
    async def resolve_post(self, url):
        assert url == WEB
        return MetadataResult(
            resolved_url=INSTAGRAM, title="게시물 제목", description="게시물 설명",
            status="success",
        )

    monkeypatch.setattr(MetadataClient, "extract_from_url", resolve_post)
    monkeypatch.setattr(settings, "instagram_summary_enabled", False)
    headers, _, _ = await guest(api)

    saved = await link(api, headers)

    assert save_provider.calls == ["recommend"]
    assert saved["original_url"] == INSTAGRAM
    assert saved["tags"] == []
    assert (saved["summary_status"], saved["summary_error_code"]) == ("skipped", "disabled")


async def chosen_category(api, headers):
    categories = await request(api, "GET", "categories", headers=headers)
    return next(category["id"] for category in categories if category["name"] == "취업")


async def test_general_web_share_still_rejects_without_ai(api, save_provider):
    headers, _, _ = await guest(api)
    result = await request(
        api, "POST", "contents/share", status=422, headers=headers, json={"url": WEB},
    )
    assert result == {"detail": "Only Instagram URLs are supported"}
    assert save_provider.calls == []


@pytest.mark.parametrize("case,calls,names,title,summary", [
    ("auto", ["ocr", "recommend"], ["사진"], "화면 제목", "핵심\n• 요점"),
    ("chosen", ["ocr"], ["사진"], "화면 제목", "핵심\n• 요점"),
    ("no-text", ["ocr"], [], "저장한 콘텐츠", "요약 정보가 아직 없습니다."),
    ("failure", ["ocr"], [], "저장한 콘텐츠", "요약 정보가 아직 없습니다."),
    ("manual-tag", ["ocr", "recommend"], ["직접"], "화면 제목", "핵심\n• 요점"),
])
async def test_screenshot_tag_source(
    api, save_provider, png_bytes, case, calls, names, title, summary,
):
    headers, _, _ = await guest(api)
    data = {}
    if case == "chosen":
        data["category_ids"] = [await chosen_category(api, headers)]
    elif case == "no-text":
        save_provider.ocr["text"] = ""
    elif case == "failure":
        save_provider.error = "timeout"
    elif case == "manual-tag":
        data["tag_names"] = ["직접"]

    saved = await request(
        api, "POST", "uploads/screenshots", status=201, headers=headers, data=data,
        files={"file": ("image.png", png_bytes, "image/png")},
    )

    assert save_provider.calls == calls
    assert [tag["name"] for tag in saved["tags"]] == names
    assert (saved["title"], saved["summary"]) == (title, summary)


@pytest.mark.parametrize("case,ai_calls,tags", [
    ("no-candidates", [], []),
    ("no-evidence", [], []),
    ("null-category", ["recommend"], ["추천"]),
    ("outside-category", ["recommend"], ["추천"]),
    ("timeout", ["recommend"], []),
    ("connection", ["recommend"], []),
    ("refusal", ["recommend"], []),
    ("truncated", ["recommend"], []),
    ("invalid-field", ["recommend"], []),
])
async def test_link_recommendation_fallbacks(
    api, save_provider, database_connection, monkeypatch, case, ai_calls, tags,
):
    headers, _, user = await guest(api)
    if case == "no-candidates":
        await database_connection.execute(delete(Category).where(Category.user_id == user["id"]))
    elif case == "no-evidence":
        async def blank_metadata(self, url):
            return MetadataResult(
                resolved_url=url, title=None, description=None,
                status="failed", failure_reason="metadata_missing",
            )

        monkeypatch.setattr(MetadataClient, "extract_from_url", blank_metadata)
    elif case in ("null-category", "outside-category", "invalid-field"):
        save_provider.recommendation["category_id"] = {
            "null-category": None, "outside-category": 99999999, "invalid-field": {},
        }[case]
    else:
        save_provider.error = case

    saved = await link(api, headers)
    assert save_provider.calls == ai_calls
    assert [category["name"] for category in saved["categories"]] == ["미분류"]
    assert [tag["name"] for tag in saved["tags"]] == tags


async def test_link_tags_keep_manual_choice_and_reuse_first_spelling_by_id(api, save_provider):
    headers, _, _ = await guest(api)
    seeded = await link(api, headers, tag_names=["Python"])
    save_provider.recommendation["tags"] = ["새 태그", "python"]
    saved = await link(api, headers, tag_names=[])

    assert [tag["name"] for tag in seeded["tags"]] == ["Python"]
    original, new = saved["tags"]
    assert original == seeded["tags"][0]
    assert set(original) == {"id", "name"}
    assert new == {"id": new["id"], "name": "새 태그"}
    assert type(original["id"]) is int and type(new["id"]) is int
    assert original["id"] < new["id"]
    assert save_provider.calls == ["recommend", "recommend"]


async def test_saved_ai_tags_replay_without_ai_and_keep_conflict_and_gone(api, save_provider):
    headers, _, _ = await guest(api)
    headers["Idempotency-Key"] = str(uuid4())
    saved = await link(api, headers, tag_names=[])
    save_provider.recommendation["tags"] = ["나중 응답"]
    replay = await link(api, headers, tag_names=[])
    assert saved == replay
    assert [tag["name"] for tag in replay["tags"]] == ["추천"]
    await request(api, "POST", "contents", status=409, headers=headers, json={
        "original_url": WEB, "tag_names": ["다른 입력"],
    })
    await request(api, "DELETE", f"contents/{saved['id']}", status=204, headers=headers)
    await request(api, "POST", "contents", status=410, headers=headers, json={
        "original_url": WEB, "tag_names": [],
    })
    assert save_provider.calls == ["recommend"]


async def test_guest_ai_tags_survive_upgrade_without_search_or_log_leaks(
    api, save_provider, database_connection, caplog, capsys,
):
    caplog.set_level(logging.DEBUG)
    marker = f"태그표식{uuid4().hex}"
    headers, _, user = await guest(api)
    other, _, other_user = await guest(api)
    save_provider.recommendation["tags"] = [marker]
    saved = await link(api, headers)
    other_saved = await link(api, other)
    save_provider.recommendation["tags"] = marker
    malformed = await link(api, headers)

    promoted = await request(api, "POST", "auth/social/kakao/upgrade", headers=headers,
                             json={"token": "ai-tag-upgrade"})
    member = {"Authorization": f"Bearer {promoted['access_token']}"}
    assert (await request(api, "GET", "users/me", headers=member))["is_guest"] is False
    results = await request(api, "GET", "feed", headers=member, params={"q": marker})
    assert [item["id"] for item in results["items"]] == [saved["id"]]
    assert [tag["name"] for tag in other_saved["tags"]] == [marker]
    assert malformed["tags"] == []
    assert malformed["title"] == "통합 제목"
    assert malformed["summary"] == "통합 설명"
    rows = (await database_connection.execute(
        select(ContentEvent.content_id, ContentEvent.metadata_json).where(
            ContentEvent.user_id.in_([user["id"], other_user["id"]]),
        )
    )).all()
    assert {row.content_id for row in rows} == {saved["id"], other_saved["id"], malformed["id"]}
    assert all(marker not in row.metadata_json for row in rows)
    output = capsys.readouterr()
    assert marker not in caplog.text + output.out + output.err


async def test_recommendation_tags_do_not_consume_quota_or_fill_a_skipped_summary(
    api, save_provider, monkeypatch,
):
    monkeypatch.setattr(settings, "instagram_summary_enabled", True)
    monkeypatch.setattr(usage_limits, "GUEST_SUMMARY_DAILY_LIMIT", 1)
    headers, _, _ = await guest(api)

    ordinary = await link(api, headers)
    queued = await link(api, headers, original_url=INSTAGRAM)
    skipped = await link(api, headers, original_url=INSTAGRAM)

    assert [tag["name"] for tag in ordinary["tags"]] == ["추천"]
    assert queued["summary_status"] == "queued" and queued["tags"] == []
    assert skipped["summary_status"] == "skipped"
    assert skipped["summary_error_code"] == "daily_limit_exceeded"
    assert skipped["tags"] == []
    assert save_provider.calls == ["recommend", "recommend", "recommend"]
