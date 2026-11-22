import asyncio
import json
from datetime import UTC, datetime, timedelta
from uuid import uuid4

import pytest
from sqlalchemy import delete, func, insert, select

from app.api.v1.endpoints import contents, uploads
from app.core.config import Settings, settings
from app.core.security import create_access_token, decode_access_token
from app.integrations.ai_client import AIClient
from app.integrations.metadata_client import MetadataClient, MetadataResult
from app.models.category import Category
from app.models.content import Content
from app.models.content_event import ContentEvent
from app.models.usage_record import UsageRecord
from app.repositories.event_repository import EventRepository
from app.repositories.usage_record_repository import UsageRecordRepository
from app.services import usage_limits
from app.services.category_recommendation_service import CategoryRecommendationService
from tests.integration.helpers import link, request
from tests.integration.test_save_ai_tags import provider as provider
from tests.integration.test_screenshot_usage_limits import upgrade
from tests.integration.test_share_write_concurrency import independent_api as independent_api
from tests.integration.test_usage_limits import assert_summary

pytestmark = pytest.mark.asyncio

NOW = datetime(2026, 11, 22, 12, tzinfo=UTC)
RECOMMENDATION = "category_recommendation"
INSTAGRAM = "https://www.instagram.com/p/Example/"
WEB = "https://example.com/article"
YOUTUBE = "https://youtu.be/dQw4w9WgXcQ"
AI_CONFIGURATION = AIClient.is_configured


@pytest.fixture
def recommendation_provider(independent_api, provider, monkeypatch):
    monkeypatch.setattr(AIClient, "is_configured", AI_CONFIGURATION)
    monkeypatch.setattr(contents, "get_ai_client", lambda: provider.ai_client)
    monkeypatch.setattr(uploads, "get_ai_client", lambda: provider.ai_client)
    monkeypatch.setattr(uploads, "get_ocr_client", lambda: provider.ocr_client)
    monkeypatch.setattr(usage_limits, "now", lambda: NOW)
    return provider


async def seed(sessions, user_id, count, kind):
    async with sessions.begin() as session:
        await session.execute(insert(UsageRecord), [
            {"user_id": user_id, "kind": kind, "recorded_at": NOW} for _ in range(count)
        ])


async def recorded(sessions, user_id, kind):
    async with sessions() as session:
        return (await session.scalars(
            select(UsageRecord).where(UsageRecord.user_id == user_id, UsageRecord.kind == kind)
            .order_by(UsageRecord.id),
        )).all()


async def event_metadata(sessions, content_id):
    async with sessions() as session:
        return json.loads(await session.scalar(
            select(ContentEvent.metadata_json).where(ContentEvent.content_id == content_id),
        ))


@pytest.mark.parametrize("start,calls,name,tags,reason", [
    pytest.param(49, ["recommend"], "취업", ["추천"], None, id="E10-C1"),
    pytest.param(50, [], "미분류", [], "daily_limit_exceeded", id="E11-C2"),
])
async def test_web_recommendation_limit_is_independent_of_monthly_summary(
    independent_api, recommendation_provider, start, calls, name, tags, reason,
):
    api, headers, user_id, sessions, _, _ = independent_api
    await seed(sessions, user_id, 30, "ai_summary")
    await seed(sessions, user_id, start, RECOMMENDATION)
    saved = await link(api, headers)
    assert_summary(saved, "not_requested")
    assert [category["name"] for category in saved["categories"]] == [name]
    assert [tag["name"] for tag in saved["tags"]] == tags
    assert recommendation_provider.calls == calls
    assert (await event_metadata(sessions, saved["id"]))[
        "category_recommendation_failure_reason"
    ] == reason
    assert len(await recorded(sessions, user_id, "ai_summary")) == 30
    assert len(await recorded(sessions, user_id, RECOMMENDATION)) == 50


@pytest.mark.parametrize("used,calls,name,reason", [
    pytest.param(49, ["ocr", "recommend"], "취업", None, id="C1"),
    pytest.param(50, ["ocr"], "미분류", "daily_limit_exceeded", id="E4-C2"),
])
async def test_screenshot_keeps_ocr_and_its_tags_at_recommendation_boundary(
    independent_api, recommendation_provider, png_bytes, used, calls, name, reason,
):
    api, headers, user_id, sessions, _, _ = independent_api
    await seed(sessions, user_id, 10, "ai_summary")
    await seed(sessions, user_id, used, RECOMMENDATION)

    async with asyncio.timeout(10):
        saved = await request(
            api, "POST", "uploads/screenshots", status=201, headers=headers,
            files={"file": ("image.png", png_bytes, "image/png")},
        )

    assert_summary(saved, "not_requested")
    assert (saved["title"], saved["summary"]) == ("화면 제목", "핵심\n• 요점")
    assert [category["name"] for category in saved["categories"]] == [name]
    assert [tag["name"] for tag in saved["tags"]] == ["사진"]
    assert recommendation_provider.calls == calls
    metadata = await event_metadata(sessions, saved["id"])
    assert metadata["category_recommendation_failure_reason"] == reason
    assert metadata["ocr_status"] == "success"
    summaries = await recorded(sessions, user_id, "ai_summary")
    assert len(summaries) == 11 and summaries[-1].content_id == saved["id"]
    assert len(await recorded(sessions, user_id, RECOMMENDATION)) == 50


@pytest.mark.parametrize("case,reason", [
    pytest.param("no-candidates", "no_match", id="E12"),
    ("empty-input", "insufficient_input"),
    ("not-configured", "error"),
    ("chosen-category", None),
    ("youtube", None),
    ("no-text-photo", None),
])
async def test_c3_without_provider_attempt_does_not_count(
    independent_api, recommendation_provider, external_responses, monkeypatch, png_bytes,
    case, reason,
):
    api, headers, user_id, sessions, _, _ = independent_api
    used = 49 if case == "no-candidates" else 0
    expected_name = "미분류"
    payload = {}
    if case == "no-candidates":
        await seed(sessions, user_id, used, RECOMMENDATION)
        async with sessions.begin() as session:
            await session.execute(delete(Category).where(Category.user_id == user_id))
    elif case == "empty-input":
        async def empty(self, url):
            return MetadataResult(
                resolved_url=url, title=None, description=None,
                status="failed", failure_reason="metadata_missing",
            )

        monkeypatch.setattr(MetadataClient, "extract_from_url", empty)
    elif case == "not-configured":
        client = AIClient(Settings(app_environment="test", _env_file=None, openai_api_key=None))
        monkeypatch.setattr(contents, "get_ai_client", lambda: client)
    elif case == "chosen-category":
        categories = await request(api, "GET", "categories", headers=headers)
        payload["category_ids"] = [next(cat["id"] for cat in categories if cat["name"] == "취업")]
        expected_name = "취업"
    elif case == "youtube":
        payload["original_url"] = YOUTUBE

    if case == "no-text-photo":
        recommendation_provider.ocr["text"] = ""
        saved = await request(
            api, "POST", "uploads/screenshots", status=201, headers=headers,
            files={"file": ("image.png", png_bytes, "image/png")},
        )
        assert recommendation_provider.calls == ["ocr"]
    else:
        saved = await link(api, headers, **payload)
        assert recommendation_provider.calls == []
    assert external_responses.ai_calls == 0
    assert [category["name"] for category in saved["categories"]] == [expected_name]
    assert saved["tags"] == []
    assert (await event_metadata(sessions, saved["id"]))[
        "category_recommendation_failure_reason"
    ] == reason
    assert len(await recorded(sessions, user_id, RECOMMENDATION)) == used


@pytest.mark.parametrize("failure,reason", [
    pytest.param("timeout", "timeout", id="E13"),
    ("connection", "error"),
    ("invalid", "invalid_response"),
])
async def test_c4_provider_failure_still_counts(
    independent_api, recommendation_provider, failure, reason,
):
    api, headers, user_id, sessions, _, _ = independent_api
    if failure == "invalid":
        recommendation_provider.recommendation["category_id"] = {}
    else:
        recommendation_provider.error = failure

    saved = await link(api, headers)

    assert_summary(saved, "not_requested")
    assert [category["name"] for category in saved["categories"]] == ["미분류"]
    assert saved["tags"] == []
    assert recommendation_provider.calls == ["recommend"]
    assert (await event_metadata(sessions, saved["id"]))[
        "category_recommendation_failure_reason"
    ] == reason
    rows = await recorded(sessions, user_id, RECOMMENDATION)
    assert [(row.recorded_at, row.content_id) for row in rows] == [(NOW, None)]
    assert await recorded(sessions, user_id, "ai_summary") == []


@pytest.mark.parametrize("url", [WEB, INSTAGRAM], ids=["E14-E15", "queued-summary-rollback"])
async def test_c5_retry_after_failed_save_counts_each_attempt(
    independent_api, recommendation_provider, monkeypatch, url,
):
    api, headers, user_id, sessions, _, _ = independent_api
    headers = {**headers, "Idempotency-Key": str(uuid4())}
    payload = {"original_url": url}
    monkeypatch.setattr(settings, "instagram_summary_enabled", True)
    create_event = EventRepository.create

    async def fail_save(self, **kwargs):
        await create_event(self, **kwargs)
        raise RuntimeError("injected save failure")

    with monkeypatch.context() as failing:
        failing.setattr(EventRepository, "create", fail_save)
        response = await api.post("/api/v1/contents", json=payload, headers=headers)
        assert response.status_code == 500

    async with sessions() as session:
        assert await session.scalar(select(Content.id).where(Content.user_id == user_id)) is None
        assert await session.scalar(select(ContentEvent.id).where(
            ContentEvent.user_id == user_id,
        )) is None
    assert recommendation_provider.calls == ["recommend"]
    assert await recorded(sessions, user_id, "ai_summary") == []
    first = await recorded(sessions, user_id, RECOMMENDATION)
    assert len(first) == 1

    saved = await request(api, "POST", "contents", json=payload, headers=headers, status=201)

    assert_summary(saved, "queued" if url == INSTAGRAM else "not_requested")
    assert [category["name"] for category in saved["categories"]] == ["취업"]
    assert [tag["name"] for tag in saved["tags"]] == ([] if url == INSTAGRAM else ["추천"])
    assert recommendation_provider.calls == ["recommend", "recommend"]
    rows = await recorded(sessions, user_id, RECOMMENDATION)
    assert [row.content_id for row in rows] == [None, None]
    assert rows[0].id == first[0].id
    summaries = await recorded(sessions, user_id, "ai_summary")
    assert [row.content_id for row in summaries] == ([saved["id"]] if url == INSTAGRAM else [])


async def test_r1_r4_replay_conflict_gone_and_expiry_do_not_count(
    independent_api, recommendation_provider,
):
    api, headers, user_id, sessions, _, _ = independent_api
    headers = {**headers, "Idempotency-Key": str(uuid4())}
    saved = await link(api, headers)
    path = f"contents/{saved['id']}"
    changed = await request(
        api, "PUT", f"{path}/favorite", headers=headers, json={"is_favorite": True},
    )
    assert changed["is_favorite"] is True and saved["is_favorite"] is False
    first = await recorded(sessions, user_id, RECOMMENDATION)
    assert len(first) == 1 and recommendation_provider.calls == ["recommend"]

    async def assert_no_attempt():
        assert recommendation_provider.calls == ["recommend"]
        assert [row.id for row in await recorded(sessions, user_id, RECOMMENDATION)] == [
            first[0].id,
        ]
        assert await recorded(sessions, user_id, "ai_summary") == []

    assert await link(api, headers) == changed
    await assert_no_attempt()
    await request(api, "POST", "contents", headers=headers, status=409, json={
        "original_url": WEB, "tag_names": ["다른 태그"],
    })
    await assert_no_attempt()
    await request(api, "DELETE", path, headers=headers, status=204)
    await request(api, "POST", "contents", headers=headers, status=410, json={"original_url": WEB})
    await assert_no_attempt()
    claims = decode_access_token(headers["Authorization"].split()[1])
    expired = create_access_token(
        user_id=user_id, session_id=claims.session_id, expires_delta=timedelta(seconds=-1),
    )
    await request(
        api, "POST", "contents", status=401, json={"original_url": WEB},
        headers={**headers, "Authorization": f"Bearer {expired}"},
    )
    await assert_no_attempt()


@pytest.mark.parametrize(
    "summary_first", [False, True], ids=["recommendation-first", "summary-first"],
)
@pytest.mark.parametrize("is_guest,month,day,status,reason,name,calls,end_month,end_day", [
    pytest.param(
        False, 30, 0, "skipped", "monthly_limit_exceeded", "취업", ["recommend"], 30, 1, id="E7",
    ),
    pytest.param(True, 19, 50, "queued", None, "미분류", [], 20, 50, id="E8"),
])
async def test_instagram_recommendation_and_summary_decisions_commute(
    independent_api, recommendation_provider, monkeypatch, summary_first,
    is_guest, month, day, status, reason, name, calls, end_month, end_day,
):
    api, headers, user_id, sessions, _, _ = independent_api
    if not is_guest:
        headers = await upgrade(api, headers)
    monkeypatch.setattr(settings, "instagram_summary_enabled", True)
    await seed(sessions, user_id, month, "ai_summary")
    if day:
        await seed(sessions, user_id, day, RECOMMENDATION)
    recommend = CategoryRecommendationService.recommend
    admit_summary = usage_limits.MonthlySummaryLimit.admit
    order = []
    summary_decision = None

    async def summary(limit):
        order.append("summary")
        return await admit_summary(limit, user_id, is_guest=is_guest, kind="instagram")

    guest_account = is_guest

    async def trace_summary(limit, candidate, *, is_guest, kind):
        assert (candidate, is_guest, kind) == (user_id, guest_account, "instagram")
        return summary_decision if summary_first else await summary(limit)

    async def trace_recommend(service, **kwargs):
        nonlocal summary_decision
        if summary_first:
            # Execute the same DB decision with the same save session before recommending.
            records = UsageRecordRepository(service.category_repository.session)
            summary_decision = await summary(usage_limits.MonthlySummaryLimit(records))
        order.append("recommendation")
        return await recommend(service, **kwargs)

    monkeypatch.setattr(CategoryRecommendationService, "recommend", trace_recommend)
    monkeypatch.setattr(usage_limits.MonthlySummaryLimit, "admit", trace_summary)

    saved = await request(
        api, "POST", "contents/share", status=201, headers=headers, json={"url": INSTAGRAM},
    )
    assert order == (["summary", "recommendation"] if summary_first
                     else ["recommendation", "summary"])
    assert_summary(saved, status, reason)
    assert [category["name"] for category in saved["categories"]] == [name]
    assert saved["tags"] == []
    assert recommendation_provider.calls == calls
    assert (await event_metadata(sessions, saved["id"]))[
        "category_recommendation_failure_reason"
    ] == ("daily_limit_exceeded" if day == 50 else None)
    assert len(await recorded(sessions, user_id, "ai_summary")) == end_month
    assert len(await recorded(sessions, user_id, RECOMMENDATION)) == end_day


@pytest.mark.parametrize("limit", [50, 200], ids=["guest-49-50-51", "member-199-200-201"])
async def test_daily_recommendation_boundary(
    independent_api, recommendation_provider, monkeypatch, limit,
):
    api, headers, user_id, sessions, request_pids, _ = independent_api
    if limit == 200:
        headers = await upgrade(api, headers)
    await seed(sessions, user_id, limit - 2, RECOMMENDATION)
    suggest = recommendation_provider.ai_client.suggest_category_id
    visible_at_call = []

    async with sessions() as observer:
        # Keep this connection checked out before either of the request's connections.
        observer_pid = await observer.scalar(select(func.pg_backend_pid()))

        async def observe_committed_record(**kwargs):
            visible_at_call.append(await observer.scalar(select(func.count()).where(
                UsageRecord.user_id == user_id, UsageRecord.kind == RECOMMENDATION,
            )))
            return await suggest(**kwargs)

        monkeypatch.setattr(
            recommendation_provider.ai_client, "suggest_category_id", observe_committed_record,
        )
        for attempt, expected_calls in zip((limit - 1, limit, limit + 1), (1, 2, 2), strict=True):
            saved = await link(api, headers)
            assert observer_pid != request_pids[-1]
            exceeded = attempt > limit
            assert_summary(saved, "not_requested")
            expected_category = "미분류" if exceeded else "취업"
            assert [cat["name"] for cat in saved["categories"]] == [expected_category]
            assert [tag["name"] for tag in saved["tags"]] == ([] if exceeded else ["추천"])
            assert (await event_metadata(sessions, saved["id"]))[
                "category_recommendation_failure_reason"
            ] == ("daily_limit_exceeded" if exceeded else None)
            assert recommendation_provider.calls == ["recommend"] * expected_calls
            assert len(await recorded(sessions, user_id, RECOMMENDATION)) == min(attempt, limit)
            assert await recorded(sessions, user_id, "ai_summary") == []
    assert visible_at_call == [limit - 1, limit]


async def test_recommendation_keeps_decision_day_when_request_crosses_kst_midnight(
    independent_api, recommendation_provider, monkeypatch,
):
    api, headers, user_id, sessions, _, _ = independent_api
    previous_day = datetime(2026, 11, 22, 14, 59, 59, tzinfo=UTC)
    midnight = previous_day + timedelta(seconds=1)
    await seed(sessions, user_id, 49, RECOMMENDATION)
    monkeypatch.setattr(usage_limits, "now", lambda: previous_day)
    suggest = recommendation_provider.ai_client.suggest_category_id

    async def finish_after_midnight(**kwargs):
        monkeypatch.setattr(usage_limits, "now", lambda: midnight)
        return await suggest(**kwargs)

    monkeypatch.setattr(
        recommendation_provider.ai_client, "suggest_category_id", finish_after_midnight,
    )

    saved = await link(api, headers)
    assert [cat["name"] for cat in saved["categories"]] == ["취업"]
    assert recommendation_provider.calls == ["recommend"]
    rows = await recorded(sessions, user_id, RECOMMENDATION)
    assert len(rows) == 50 and rows[-1].recorded_at == previous_day

    following = await link(api, headers)
    assert [cat["name"] for cat in following["categories"]] == ["취업"]
    assert recommendation_provider.calls == ["recommend", "recommend"]
    rows = await recorded(sessions, user_id, RECOMMENDATION)
    assert len(rows) == 51 and rows[-1].recorded_at == midnight


async def test_same_day_upgrade_keeps_recommendation_usage_with_member_limit(
    independent_api, recommendation_provider,
):
    api, headers, user_id, sessions, _, _ = independent_api
    await seed(sessions, user_id, 50, RECOMMENDATION)
    blocked = await link(api, headers)
    assert [cat["name"] for cat in blocked["categories"]] == ["미분류"]
    assert recommendation_provider.calls == []
    before_upgrade = await recorded(sessions, user_id, RECOMMENDATION)
    assert len(before_upgrade) == 50

    member = await upgrade(api, headers)
    account = await request(api, "GET", "users/me", headers=member)
    assert account["id"] == user_id and account["is_guest"] is False
    saved = await link(api, member)
    assert [cat["name"] for cat in saved["categories"]] == ["취업"]
    assert recommendation_provider.calls == ["recommend"]
    rows = await recorded(sessions, user_id, RECOMMENDATION)
    assert len(rows) == 51
    assert [row.id for row in rows[:-1]] == [row.id for row in before_upgrade]


async def test_recommendation_record_failure_skips_provider_and_keeps_save(
    independent_api, recommendation_provider, monkeypatch,
):
    api, headers, user_id, sessions, _, _ = independent_api
    add = UsageRecordRepository.add

    async def fail_to_commit(repository, **kwargs):
        # Force PostgreSQL to reject the usage insert at commit, after the limit check.
        await add(repository, **{**kwargs, "kind": "not_a_usage_kind"})

    monkeypatch.setattr(UsageRecordRepository, "add", fail_to_commit)

    saved = await link(api, headers)
    assert_summary(saved, "not_requested")
    assert [cat["name"] for cat in saved["categories"]] == ["미분류"]
    assert saved["tags"] == []
    assert recommendation_provider.calls == []
    assert (await event_metadata(sessions, saved["id"]))[
        "category_recommendation_failure_reason"
    ] == "error"
    assert await recorded(sessions, user_id, RECOMMENDATION) == []


async def test_recommendation_prunes_usage_before_previous_kst_month(
    independent_api, recommendation_provider, monkeypatch,
):
    api, headers, user_id, sessions, _, _ = independent_api
    cutoff = datetime(2026, 10, 31, 15, tzinfo=UTC)
    old = cutoff - timedelta(seconds=1)
    december = datetime(2026, 12, 15, tzinfo=UTC)
    monkeypatch.setattr(usage_limits, "now", lambda: december)
    async with sessions.begin() as session:
        await session.execute(insert(UsageRecord), [
            {"user_id": user_id, "kind": kind, "recorded_at": at}
            for kind in ("ai_summary", RECOMMENDATION)
            for at in (old, cutoff)
        ])

    saved = await link(api, headers)
    assert [cat["name"] for cat in saved["categories"]] == ["취업"]
    assert recommendation_provider.calls == ["recommend"]
    assert [row.recorded_at for row in await recorded(sessions, user_id, RECOMMENDATION)] == [
        cutoff, december,
    ]
    assert [row.recorded_at for row in await recorded(sessions, user_id, "ai_summary")] == [cutoff]
