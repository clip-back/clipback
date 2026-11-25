"""#475 save paths: AI 전송 동의 판정 G1a·G1b·G2a·G2b·G3 (#474 입력별 실제 출력·판정 순서).

AI calls are counted at the OpenAI SDK's HTTP transport (`provider`), the only faked part.
"""

import json
from uuid import uuid4

import pytest
import pytest_asyncio
from sqlalchemy import delete, func, insert, select, text, update

from app.core.config import settings
from app.integrations.metadata_client import MetadataClient, MetadataResult
from app.models.category import Category
from app.models.content import Content
from app.models.content_asset import ContentAsset
from app.models.content_event import ContentEvent
from app.models.image_deletion import ImageDeletion
from app.models.usage_record import UsageRecord
from app.services import maintenance as maintenance_service, usage_limits
from app.services.ai_consent import SaveAIConsent
from tests.integration.helpers import guest, request
from tests.integration.test_recommendation_usage_limits import (
    NOW,
    recommendation_provider as recommendation_provider,
)
from tests.integration.test_save_ai_tags import provider as provider, save_provider as save_provider
from tests.integration.test_screenshot_usage_limits import upgrade
from tests.integration.test_share_write_concurrency import independent_api as independent_api

pytestmark = pytest.mark.asyncio

WEB = "https://example.com/article"
YOUTUBE = "https://youtu.be/dQw4w9WgXcQ"
INSTAGRAM = "https://www.instagram.com/p/Example/"
STORY = "https://www.instagram.com/stories/example/12345/"
DEFAULT_TITLE, DEFAULT_SUMMARY = "저장한 콘텐츠", "요약 정보가 아직 없습니다."
REASON = "ai_consent_required"

# state -> (switch AI_CONSENT_REQUIRED, stored decision, AI allowed)
STATES = {
    "undecided_switch_off": (False, None, True),
    "granted_switch_on": (True, "granted", True),
    "denied_switch_off": (False, "denied", False),
    "undecided_switch_on": (True, None, False),
}
# Allowed and denied states each run once as a guest and once logged in.
ACCOUNT = {"undecided_switch_off": "guest", "granted_switch_on": "login",
           "denied_switch_off": "guest", "undecided_switch_on": "login"}


@pytest.fixture(autouse=True)
def summaries_on(monkeypatch):
    monkeypatch.setattr(settings, "youtube_summary_enabled", True)
    monkeypatch.setattr(settings, "instagram_summary_enabled", True)


async def account(api, monkeypatch, state, *, login=None):
    switch, decision, _ = STATES[state]
    headers, _, user = await guest(api)
    if (ACCOUNT[state] if login is None else ("login" if login else "guest")) == "login":
        headers = await upgrade(api, headers)
    if decision is not None:
        await request(api, "PUT", "users/me/ai-consent", headers=headers,
                      json={"status": decision, "notice_version": 1})
    monkeypatch.setattr(settings, "ai_consent_required", switch)
    return headers, user["id"]


async def share_headers(api, headers):
    data = await request(api, "POST", "auth/share-credential", headers=headers)
    return {"Authorization": f"Bearer {data['share_token']}"}


async def send(api, headers, kind, *, route="app", **extra):
    if route == "share":
        headers = {**headers, **await share_headers(api, headers)}
    if kind == "photo":
        return await api.post("/api/v1/uploads/screenshots", headers=headers, data=extra.get(
            "data", {}), files={"file": ("image.png", extra["png"], "image/png")})
    url = {"web": WEB, "youtube": YOUTUBE, "instagram": INSTAGRAM, "story": STORY}[kind]
    if route == "share":
        return await api.post("/api/v1/contents/share", headers=headers, json={"url": url, **extra})
    return await api.post("/api/v1/contents", headers=headers, json={"original_url": url, **extra})


async def save(api, headers, kind, *, route="app", status=201, **extra):
    response = await send(api, headers, kind, route=route, **extra)
    assert response.status_code == status, response.text
    return response.json()


async def usage(db, user_id, kind):
    return await db.scalar(select(func.count()).select_from(UsageRecord).where(
        UsageRecord.user_id == user_id, UsageRecord.kind == kind))


async def metadata(db, content_id):
    return json.loads(await db.scalar(
        select(ContentEvent.metadata_json).where(ContentEvent.content_id == content_id)))


def expected(kind, allowed):
    """#474 입력별 실제 출력 for the fixture's link metadata and OCR answer."""
    category = ["취업"] if allowed else ["미분류"]
    if kind == "web":
        return (["recommend"] if allowed else [], "not_requested", None, "통합 제목", category,
                ["추천"] if allowed else [])
    if kind == "youtube":
        return ([], *(("queued", None) if allowed else ("skipped", REASON)), DEFAULT_TITLE,
                ["미분류"], [])
    if kind == "instagram":
        return (["recommend"] if allowed else [],
                *(("queued", None) if allowed else ("skipped", REASON)), "통합 제목", category, [])
    if kind == "story":
        return (["recommend"] if allowed else [], "skipped", "unsupported_content", "통합 제목",
                category, ["추천"] if allowed else [])
    return (["ocr", "recommend"] if allowed else [],
            *(("not_requested", None) if allowed else ("skipped", REASON)),
            "화면 제목" if allowed else DEFAULT_TITLE, category, ["사진"] if allowed else [])


ROUTES = [("app", kind) for kind in ("web", "youtube", "instagram", "story", "photo")] + [
    ("share", kind) for kind in ("youtube", "instagram", "story", "photo")]


@pytest.mark.parametrize("state", list(STATES))
@pytest.mark.parametrize(("route", "kind"), ROUTES)
async def test_entry_points_follow_the_consent_judgment(
    api, save_provider, database_connection, monkeypatch, png_bytes, route, kind, state,
):
    headers, user_id = await account(api, monkeypatch, state)
    allowed = STATES[state][2]
    extra = {"png": png_bytes} if kind == "photo" else {}
    saved = await save(api, headers, kind, route=route, **extra)
    calls, status, code, title, categories, tags = expected(kind, allowed)
    assert save_provider.calls == calls
    assert (saved["summary_status"], saved["summary_error_code"]) == (status, code)
    assert saved["title"] == title
    assert [category["name"] for category in saved["categories"]] == categories
    assert [tag["name"] for tag in saved["tags"]] == tags
    if kind in ("youtube", "photo") and not allowed:
        assert saved["summary"] == DEFAULT_SUMMARY
    summary_counted = allowed and kind in ("youtube", "instagram", "photo")
    assert await usage(database_connection, user_id, "ai_summary") == int(summary_counted)
    assert await usage(database_connection, user_id, "category_recommendation") == int(
        allowed and kind != "youtube")
    event = await metadata(database_connection, saved["id"])
    if kind == "photo":
        assert (event["ocr_status"], event["ocr_failure_reason"]) == (
            ("success", None) if allowed else ("skipped", REASON))
    elif kind != "youtube":
        assert event["category_recommendation_failure_reason"] == (None if allowed else REASON)
    detail = await request(api, "GET", f"contents/{saved['id']}", headers=headers)
    assert (detail["summary_status"], detail["summary_error_code"]) == (status, code)
    feed = await request(api, "GET", "feed", headers=headers)
    assert [item["id"] for item in feed["items"]] == [saved["id"]]


@pytest.mark.parametrize("state", ["denied_switch_off", "undecided_switch_on"])
@pytest.mark.parametrize("kind", ["web", "instagram", "photo"])
async def test_chosen_category_and_tags_are_kept_when_ai_is_denied(
    api, save_provider, database_connection, monkeypatch, png_bytes, kind, state,
):
    headers, user_id = await account(api, monkeypatch, state)
    chosen = await database_connection.scalar(select(Category.id).where(
        Category.user_id == user_id, Category.name == "취업"))
    extra = ({"png": png_bytes, "data": {"category_ids": [chosen], "tag_names": ["직접"]}}
             if kind == "photo" else {"category_ids": [chosen], "tag_names": ["직접"]})
    saved = await save(api, headers, kind, **extra)
    assert save_provider.calls == []
    assert [category["name"] for category in saved["categories"]] == ["취업"]
    assert [tag["name"] for tag in saved["tags"]] == ["직접"]
    assert (saved["summary_status"], saved["summary_error_code"]) == (
        ("not_requested", None) if kind == "web" else ("skipped", REASON))


async def test_typed_title_and_summary_are_kept_when_ai_is_denied(
    api, save_provider, monkeypatch,
):
    headers, _ = await account(api, monkeypatch, "denied_switch_off")
    saved = await save(api, headers, "youtube", title="직접 제목", summary="직접 요약")
    assert (saved["title"], saved["summary"]) == ("직접 제목", "직접 요약")
    assert (saved["summary_status"], saved["summary_error_code"]) == ("skipped", REASON)
    assert save_provider.calls == []


# #474 "순서가 결과를 바꾸는 입력": one test per row. The rows that change the decision during a
# save are in test_ai_consent_concurrency.py.

async def seed_summary_usage(db, user_id, count=20):
    await db.execute(insert(UsageRecord), [
        {"user_id": user_id, "kind": "ai_summary", "recorded_at": NOW} for _ in range(count)])


# The monthly limit is judged on the seeded month (review Standards 3); a granted account
# with the same seed is the control that the limit is really used up.
@pytest.mark.parametrize(("state", "code"), [
    ("denied_switch_off", REASON), ("granted_switch_on", "monthly_limit_exceeded"),
])
async def test_order_denied_youtube_with_monthly_limit_used(
    api, save_provider, database_connection, monkeypatch, state, code,
):
    monkeypatch.setattr(usage_limits, "now", lambda: NOW)
    headers, user_id = await account(api, monkeypatch, state, login=False)
    await seed_summary_usage(database_connection, user_id)
    saved = await save(api, headers, "youtube")
    assert (saved["summary_status"], saved["summary_error_code"]) == ("skipped", code)
    assert await usage(database_connection, user_id, "ai_summary") == 20


@pytest.mark.parametrize(("state", "code", "calls"), [
    ("denied_switch_off", REASON, []), ("granted_switch_on", "monthly_limit_exceeded", []),
])
async def test_order_denied_photo_with_monthly_limit_used(
    api, save_provider, database_connection, monkeypatch, png_bytes, state, code, calls,
):
    monkeypatch.setattr(usage_limits, "now", lambda: NOW)
    headers, user_id = await account(api, monkeypatch, state, login=False)
    await seed_summary_usage(database_connection, user_id)
    saved = await save(api, headers, "photo", png=png_bytes)
    assert (saved["summary_status"], saved["summary_error_code"]) == ("skipped", code)
    assert await usage(database_connection, user_id, "ai_summary") == 20
    assert save_provider.calls == calls
    assert (await metadata(database_connection, saved["id"]))["ocr_failure_reason"] == code


async def test_order_denied_instagram_story(api, save_provider, monkeypatch):
    headers, _ = await account(api, monkeypatch, "denied_switch_off")
    saved = await save(api, headers, "story")
    assert (saved["summary_status"], saved["summary_error_code"]) == (
        "skipped", "unsupported_content")


@pytest.mark.parametrize("kind", ["story", "youtube"])
async def test_order_denied_with_summary_kind_off(api, save_provider, monkeypatch, kind):
    headers, _ = await account(api, monkeypatch, "denied_switch_off")
    monkeypatch.setattr(settings, "youtube_summary_enabled", False)
    monkeypatch.setattr(settings, "instagram_summary_enabled", False)
    saved = await save(api, headers, kind)
    assert (saved["summary_status"], saved["summary_error_code"]) == ("skipped", "disabled")


async def test_order_denied_without_candidates_and_input(
    api, save_provider, database_connection, monkeypatch,
):
    headers, user_id = await account(api, monkeypatch, "denied_switch_off")
    await database_connection.execute(text(
        "DELETE FROM categories WHERE user_id = :u AND name <> '미분류'"), {"u": user_id})

    async def empty(self, url):
        return MetadataResult(resolved_url=url, title=None, description=None, status="failed")

    monkeypatch.setattr(MetadataClient, "extract_from_url", empty)
    saved = await save(api, headers, "web")
    assert (await metadata(database_connection, saved["id"]))[
        "category_recommendation_failure_reason"] == "no_match"


async def test_order_denied_link_with_insufficient_input(
    api, save_provider, database_connection, monkeypatch,
):
    headers, _ = await account(api, monkeypatch, "denied_switch_off")

    async def empty(self, url):
        return MetadataResult(resolved_url=url, title=None, description=None, status="failed")

    monkeypatch.setattr(MetadataClient, "extract_from_url", empty)
    saved = await save(api, headers, "web")
    assert (await metadata(database_connection, saved["id"]))[
        "category_recommendation_failure_reason"] == "insufficient_input"


async def test_order_denied_with_daily_recommendation_limit_used(
    api, save_provider, database_connection, monkeypatch,
):
    headers, user_id = await account(api, monkeypatch, "denied_switch_off")
    await database_connection.execute(insert(UsageRecord), [
        {"user_id": user_id, "kind": "category_recommendation", "recorded_at": NOW}
        for _ in range(50)])
    monkeypatch.setattr(usage_limits, "now", lambda: NOW)
    saved = await save(api, headers, "web")
    assert (await metadata(database_connection, saved["id"]))[
        "category_recommendation_failure_reason"] == REASON
    assert await usage(database_connection, user_id, "category_recommendation") == 50
    assert save_provider.calls == []


async def test_order_denied_photo_over_image_quota_is_409(
    api, save_provider, database_connection, monkeypatch, png_bytes,
):
    headers, user_id = await account(api, monkeypatch, "denied_switch_off")
    first = await save(api, headers, "photo", png=png_bytes)
    await database_connection.execute(update(ContentAsset).where(
        ContentAsset.content_id == first["id"]).values(size_bytes=31_457_280))
    rejected = await save(api, headers, "photo", png=png_bytes, status=409)
    assert rejected["detail"]["code"] == "image_quota_exceeded"
    assert await database_connection.scalar(select(func.count()).select_from(Content).where(
        Content.user_id == user_id)) == 1


async def test_order_maintenance_comes_before_authentication(api, monkeypatch):
    async def closed(self, kind):
        raise maintenance_service.MaintenanceError()

    monkeypatch.setattr(maintenance_service.MaintenanceGate, "admit", closed)
    for method, path in (("PUT", "users/me/ai-consent"), ("POST", "contents")):
        response = await api.request(method, f"/api/v1/{path}",
                                     headers={"Authorization": "Bearer invalid"},
                                     json={"status": "granted", "notice_version": 1})
        assert response.status_code == 503, response.text


# #474 "동의를 읽지 못할 때": the save fails with the existing DB error, rolls back and sends
# nothing; the same submission key is judged again; a failed read never stores a denial.

FAILING = {  # (save, nth consent read that fails)
    "G1a": ("web", 1), "G1b": ("web", 2), "G3": ("youtube", 1),
    "G2a": ("photo", 1), "G2b": ("photo", 2), "G1a_photo": ("photo", 3),
    "G1b_photo": ("photo", 4), "G3_instagram": ("instagram", 3),
}


@pytest_asyncio.fixture
async def own_image_deletions(independent_api):
    """A photo save that fails after storing its original queues a cleanup row that the
    account cleanup does not remove; drop this account's rows so later tests start clean."""
    yield
    async with independent_api[3].begin() as session:
        await session.execute(
            delete(ImageDeletion).where(ImageDeletion.user_id == independent_api[2]))


# Sends the request made before the failed read, in the #474 order (사용자 결정 “실패 시점
# 뒤 추가 0회 (추천)”): a photo reads its text before the recommendation checks, an
# Instagram post is recommended before G3.
SENT_BEFORE = {"G1b": [], "G1a_photo": ["ocr"], "G1b_photo": ["ocr"],
               "G3_instagram": ["recommend"]}
# The retry with the same key is judged anew (still undecided, switch off) and sends again.
RETRY_SENDS = {"web": ["recommend"], "youtube": [], "instagram": ["recommend"],
               "photo": ["ocr", "recommend"]}


@pytest.mark.parametrize("point", list(FAILING))
async def test_read_failure_rolls_back_without_ai_and_retries_fresh(
    independent_api, recommendation_provider, monkeypatch, png_bytes, own_image_deletions, point,
):
    api, headers, user_id, sessions, _, path = independent_api
    kind, failing_read = FAILING[point]
    allows = SaveAIConsent.allows
    reads = 0
    at_failure = None

    async def fail_once(self, user):
        nonlocal reads, at_failure
        reads += 1
        if reads == failing_read:
            at_failure = list(recommendation_provider.calls)
            await self.session.execute(text("SELECT 1 / 0"))
        return await allows(self, user)

    monkeypatch.setattr(SaveAIConsent, "allows", fail_once)
    keyed = {**headers, "Idempotency-Key": str(uuid4())}
    extra = {"png": png_bytes} if kind == "photo" else {}
    failed = await send(api, keyed, kind, **extra)
    assert (failed.status_code, failed.text) == (500, "Internal Server Error")
    # Already sent before the failed read, then nothing more after it.
    assert at_failure == SENT_BEFORE.get(point, [])
    assert recommendation_provider.calls == at_failure
    async with sessions() as session:
        # The save is rolled back.
        assert await session.scalar(select(func.count()).select_from(Content).where(
            Content.user_id == user_id)) == 0
        assert await session.scalar(select(func.count()).select_from(UsageRecord).where(
            UsageRecord.user_id == user_id, UsageRecord.kind == "ai_summary")) == 0
        # #465: an attempt committed before the failed G1b read may remain.
        assert await session.scalar(select(func.count()).select_from(UsageRecord).where(
            UsageRecord.user_id == user_id, UsageRecord.kind == "category_recommendation",
        )) == int(point in ("G1b", "G1b_photo", "G3_instagram"))
        # The failed read is not stored as a denial.
        assert await session.scalar(text(
            "SELECT count(*) FROM ai_transfer_consents WHERE user_id = :u"), {"u": user_id}) == 0
    assert list(path.rglob("*.png")) == []
    me = await request(api, "GET", "users/me", headers=headers)
    assert me["ai_consent_status"] == "undecided"
    # The same submission key is judged anew and saves once.
    retried = await save(api, keyed, kind, **extra)
    assert retried["summary_status"] == ("queued" if kind in ("youtube", "instagram")
                                         else "not_requested")
    assert reads > failing_read
    assert recommendation_provider.calls == at_failure + RETRY_SENDS[kind]
    async with sessions() as session:
        assert await session.scalar(select(func.count()).select_from(Content).where(
            Content.user_id == user_id)) == 1
