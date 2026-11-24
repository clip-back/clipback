"""#475 overlapping saves and AI 전송 동의 changes on real PostgreSQL with separate sessions
(#474 동시 요청 표, the save and decision rows; 순서가 결과를 바꾸는 입력, the rows that change
the decision during a save). AI calls are counted at the OpenAI SDK transport (`provider`).
"""

import asyncio
from uuid import uuid4

import pytest
import pytest_asyncio
from sqlalchemy import func, select, text

from app.core.config import settings
from app.models.content import Content
from app.models.content_asset import ContentAsset
from app.models.summary_job import SummaryJob
from app.models.usage_record import UsageRecord
from app.repositories.event_repository import EventRepository
from app.repositories.user_repository import UserRepository
from app.services import account_deletion_service
from app.services.image_deletion_service import retry_image_deletions
from app.services.usage_limits import DailyRecommendationLimit, MonthlySummaryLimit
from tests.integration.helpers import request
from tests.integration.test_recommendation_usage_limits import (
    recommendation_provider as recommendation_provider,
)
from tests.integration.test_save_ai_tags import provider as provider
from tests.integration.test_screenshot_usage_limits import upgrade
from tests.integration.test_share_write_concurrency import independent_api as independent_api

pytestmark = pytest.mark.asyncio
WEB = "https://example.com/article"
YOUTUBE = "https://youtu.be/dQw4w9WgXcQ"
INSTAGRAM = "https://www.instagram.com/p/Example/"
REASON = "ai_consent_required"
WAIT = 10


@pytest.fixture(autouse=True)
def summaries_on(monkeypatch):
    monkeypatch.setattr(settings, "youtube_summary_enabled", True)
    monkeypatch.setattr(settings, "instagram_summary_enabled", True)


def pause(monkeypatch, target, name, *, after=False):
    """Hold the first call of target.name before (or after) it runs until released."""
    original = getattr(target, name)
    entered, release = asyncio.Event(), asyncio.Event()
    calls = 0

    async def paused(*args, **kwargs):
        nonlocal calls
        calls += 1
        first = calls == 1
        if first and not after:
            entered.set()
            await asyncio.wait_for(release.wait(), WAIT)
        result = await original(*args, **kwargs)
        if first and after:
            entered.set()
            await asyncio.wait_for(release.wait(), WAIT)
        return result

    monkeypatch.setattr(target, name, paused)
    return entered, release


async def decide(api, headers, status_value, *, expect=200):
    return await request(api, "PUT", "users/me/ai-consent", headers=headers, status=expect,
                         json={"status": status_value, "notice_version": 1})


async def save(api, headers, kind, png=None, *, key=None):
    headers = {**headers, **({"Idempotency-Key": key} if key else {})}
    if kind == "photo":
        return await request(api, "POST", "uploads/screenshots", headers=headers, status=201,
                             files={"file": ("image.png", png, "image/png")})
    url = {"web": WEB, "youtube": YOUTUBE, "instagram": INSTAGRAM}[kind]
    return await request(api, "POST", "contents", headers=headers, status=201,
                         json={"original_url": url})


async def count(sessions, model, *conditions):
    async with sessions() as session:
        return await session.scalar(select(func.count()).select_from(model).where(*conditions))


async def usage(sessions, user_id, kind):
    return await count(sessions, UsageRecord, UsageRecord.user_id == user_id,
                       UsageRecord.kind == kind)


async def consent_rows(sessions, user_id):
    async with sessions() as session:
        return (await session.execute(text(
            "SELECT status, granted_after_denial FROM ai_transfer_consents WHERE user_id = :u"),
            {"u": user_id})).all()


async def lock_waiters(sessions):
    async with sessions() as session:
        return await session.scalar(text(
            "SELECT count(*) FROM pg_stat_activity "
            "WHERE datname = current_database() AND wait_event_type = 'Lock'"))


async def until_waiting(sessions, waiters):
    for _ in range(250):
        if await lock_waiters(sessions) == waiters:
            return
        await asyncio.sleep(0.02)
    raise AssertionError(f"never reached {waiters} lock waiter(s)")


def category_names(content):
    return [category["name"] for category in content["categories"]]


async def test_counter_sees_n_sends_when_allowed_and_none_when_denied(
    independent_api, recommendation_provider,
):
    api, headers, user_id, sessions, _, _ = independent_api
    for index in range(3):
        await request(api, "POST", "contents", headers=headers, status=201,
                      json={"original_url": f"{WEB}/{index}"})
    assert recommendation_provider.calls == ["recommend"] * 3
    await decide(api, headers, "denied")
    for index in range(3):
        await request(api, "POST", "contents", headers=headers, status=201,
                      json={"original_url": f"{WEB}/denied/{index}"})
    assert recommendation_provider.calls == ["recommend"] * 3
    assert await usage(sessions, user_id, "category_recommendation") == 3


# 링크 추천

async def test_withdrawal_after_the_attempt_is_counted_skips_the_call_and_the_count(
    independent_api, recommendation_provider, monkeypatch,
):
    api, headers, user_id, sessions, _, _ = independent_api
    entered, release = pause(monkeypatch, DailyRecommendationLimit, "admit", after=True)
    saving = asyncio.create_task(save(api, headers, "web"))
    try:
        await asyncio.wait_for(entered.wait(), WAIT)
        assert await usage(sessions, user_id, "category_recommendation") == 1
        await asyncio.wait_for(decide(api, headers, "denied"), WAIT)
        assert not saving.done()  # The decision committed on its own connection meanwhile.
    finally:
        release.set()
    saved = await asyncio.wait_for(saving, WAIT)
    assert recommendation_provider.calls == []
    assert category_names(saved) == ["미분류"]
    assert await usage(sessions, user_id, "category_recommendation") == 0


async def test_withdrawal_after_the_send_keeps_the_recommendation(
    independent_api, recommendation_provider, monkeypatch,
):
    api, headers, user_id, sessions, _, _ = independent_api
    entered, release = pause(monkeypatch, recommendation_provider.ai_client,
                             "suggest_category_id", after=True)
    saving = asyncio.create_task(save(api, headers, "web"))
    try:
        await asyncio.wait_for(entered.wait(), WAIT)
        await asyncio.wait_for(decide(api, headers, "denied"), WAIT)
        assert not saving.done()
    finally:
        release.set()
    saved = await asyncio.wait_for(saving, WAIT)
    assert recommendation_provider.calls == ["recommend"]
    assert category_names(saved) == ["취업"]
    assert [tag["name"] for tag in saved["tags"]] == ["추천"]
    assert await usage(sessions, user_id, "category_recommendation") == 1


async def test_withdrawal_committed_before_the_save_skips_the_call(
    independent_api, recommendation_provider,
):
    api, headers, user_id, sessions, _, _ = independent_api
    await decide(api, headers, "denied")
    saved = await save(api, headers, "web")
    assert recommendation_provider.calls == []
    assert category_names(saved) == ["미분류"]
    assert await usage(sessions, user_id, "category_recommendation") == 0


# 사진 글자 읽기. The photo save holds the user row FOR NO KEY UPDATE; a decision does not
# wait for it (V17).

async def test_withdrawal_after_the_monthly_check_keeps_only_the_original(
    independent_api, recommendation_provider, monkeypatch, png_bytes,
):
    api, headers, user_id, sessions, _, path = independent_api
    entered, release = pause(monkeypatch, MonthlySummaryLimit, "admit", after=True)
    saving = asyncio.create_task(save(api, headers, "photo", png_bytes))
    try:
        await asyncio.wait_for(entered.wait(), WAIT)
        await asyncio.wait_for(decide(api, headers, "denied"), WAIT)
        assert not saving.done()
    finally:
        release.set()
    saved = await asyncio.wait_for(saving, WAIT)
    assert recommendation_provider.calls == []
    assert (saved["summary_status"], saved["summary_error_code"]) == ("skipped", REASON)
    assert await count(sessions, ContentAsset, ContentAsset.content_id == saved["id"]) == 1
    assert len(list(path.rglob("*.png"))) == 1
    assert await usage(sessions, user_id, "ai_summary") == 0


async def test_withdrawal_after_text_reading_keeps_it_and_skips_the_recommendation(
    independent_api, recommendation_provider, monkeypatch, png_bytes,
):
    api, headers, user_id, sessions, _, _ = independent_api
    entered, release = pause(monkeypatch, recommendation_provider.ocr_client, "extract",
                             after=True)
    saving = asyncio.create_task(save(api, headers, "photo", png_bytes))
    try:
        await asyncio.wait_for(entered.wait(), WAIT)
        await asyncio.wait_for(decide(api, headers, "denied"), WAIT)
        assert not saving.done()
    finally:
        release.set()
    saved = await asyncio.wait_for(saving, WAIT)
    assert recommendation_provider.calls == ["ocr"]
    assert saved["title"] == "화면 제목"
    assert [tag["name"] for tag in saved["tags"]] == ["사진"]
    assert category_names(saved) == ["미분류"]
    assert (saved["summary_status"], saved["summary_error_code"]) == ("not_requested", None)
    assert await usage(sessions, user_id, "ai_summary") == 1
    assert await usage(sessions, user_id, "category_recommendation") == 0


# 철회→재동의 중 진행 저장: data that started before the re-grant stays without AI.

@pytest.mark.parametrize(("kind", "target", "after_regrant"), [
    ("web", DailyRecommendationLimit, ("not_requested", None)),
    ("instagram", DailyRecommendationLimit, ("skipped", REASON)),
    ("photo", MonthlySummaryLimit, ("skipped", REASON)),
])
async def test_save_in_progress_across_withdraw_and_regrant_sends_nothing(
    independent_api, recommendation_provider, monkeypatch, png_bytes, kind, target,
    after_regrant,
):
    api, headers, user_id, sessions, _, _ = independent_api
    await decide(api, headers, "granted")
    entered, release = pause(monkeypatch, target, "admit", after=True)
    saving = asyncio.create_task(save(api, headers, kind, png_bytes))
    try:
        await asyncio.wait_for(entered.wait(), WAIT)
        await decide(api, headers, "denied")
        await decide(api, headers, "granted")
        assert not saving.done()
    finally:
        release.set()
    saved = await asyncio.wait_for(saving, WAIT)
    assert recommendation_provider.calls == []
    assert (saved["summary_status"], saved["summary_error_code"]) == after_regrant
    assert category_names(saved) == ["미분류"]
    assert await usage(sessions, user_id, "category_recommendation") == 0
    assert await usage(sessions, user_id, "ai_summary") == 0
    assert await consent_rows(sessions, user_id) == [("granted", True)]
    # A save that starts after the re-grant is processed.
    fresh = await save(api, headers, kind, png_bytes)
    assert recommendation_provider.calls == (["ocr", "recommend"] if kind == "photo"
                                             else ["recommend"])
    assert category_names(fresh) == ["취업"]


# 동의 / 저장

async def test_grant_before_a_save_with_the_switch_on_allows_ai(
    independent_api, recommendation_provider, monkeypatch,
):
    api, headers, _, _, _, _ = independent_api
    monkeypatch.setattr(settings, "ai_consent_required", True)
    await decide(api, headers, "granted")
    saved = await save(api, headers, "instagram")
    assert recommendation_provider.calls == ["recommend"]
    assert (saved["summary_status"], saved["summary_error_code"]) == ("queued", None)


async def test_grant_after_a_save_with_the_switch_on_is_not_retroactive(
    independent_api, recommendation_provider, monkeypatch,
):
    api, headers, user_id, sessions, _, _ = independent_api
    monkeypatch.setattr(settings, "ai_consent_required", True)
    saved = await save(api, headers, "youtube")
    assert (saved["summary_status"], saved["summary_error_code"]) == ("skipped", REASON)
    await decide(api, headers, "granted")
    detail = await request(api, "GET", f"contents/{saved['id']}", headers=headers)
    assert (detail["summary_status"], detail["summary_error_code"]) == ("skipped", REASON)
    async with sessions() as session:
        job = await session.get(SummaryJob, saved["id"])
        assert (job.status, job.error_code) == ("skipped", REASON)
    assert await usage(sessions, user_id, "ai_summary") == 0
    assert (await save(api, headers, "youtube"))["summary_status"] == "queued"


# 두 기기: the later commit wins.

@pytest.mark.parametrize(("first", "second"), [("denied", "granted"), ("granted", "denied")])
async def test_two_devices_end_with_the_later_commit(independent_api, first, second):
    api, headers, user_id, sessions, _, _ = independent_api
    await decide(api, headers, "granted")
    async with sessions() as holder:
        # Hold the record so both requests queue on it in order.
        await holder.execute(text(
            "SELECT 1 FROM ai_transfer_consents WHERE user_id = :u FOR UPDATE"), {"u": user_id})
        a = asyncio.create_task(decide(api, headers, first))
        await until_waiting(sessions, 1)
        b = asyncio.create_task(decide(api, headers, second))
        await until_waiting(sessions, 2)
        await holder.rollback()
    first_result, second_result = await asyncio.wait_for(asyncio.gather(a, b), WAIT)
    assert first_result["decided_at"] <= second_result["decided_at"]
    expected_flag = second == "granted"
    assert await consent_rows(sessions, user_id) == [(second, expected_flag)]
    me = await request(api, "GET", "users/me", headers=headers)
    assert me["ai_consent_status"] == second


async def test_two_devices_without_a_record_end_with_the_later_commit(independent_api):
    api, headers, user_id, sessions, _, _ = independent_api
    results = await asyncio.wait_for(asyncio.gather(
        decide(api, headers, "granted"), decide(api, headers, "denied")), WAIT)
    later = max(results, key=lambda result: result["decided_at"])
    assert [row[0] for row in await consent_rows(sessions, user_id)] == [later["status"]]


# 탈퇴 API·운영자 재시도와 동의 변경: user row FOR UPDATE against KEY SHARE, both orders.

ROWS = {  # existing record, decision sent
    "no_record": (None, "denied"),
    "changed": ("granted", "denied"),
    "unchanged": ("granted", "granted"),
}


async def delete_account(api, headers):
    return await api.request("DELETE", "/api/v1/users/me", headers=headers,
                             json={"reasons": ["other"]})


async def pending_account_deletion(api, headers, monkeypatch):
    """A recorded account deletion whose DB transaction failed, for the operator retry (U2)."""
    original = account_deletion_service.apply_account_deletion

    async def broken(session, intent):
        raise RuntimeError("injected database failure")

    monkeypatch.setattr(account_deletion_service, "apply_account_deletion", broken)
    assert (await delete_account(api, headers)).status_code == 500
    monkeypatch.setattr(account_deletion_service, "apply_account_deletion", original)


async def operator_retry(sessions):
    async with sessions() as session:
        return await retry_image_deletions(session, limit=10)


@pytest.mark.parametrize("deleter", ["api", "operator"])
@pytest.mark.parametrize("row", list(ROWS))
async def test_decision_first_then_deletion(independent_api, monkeypatch, row, deleter):
    api, headers, user_id, sessions, _, _ = independent_api
    existing, sent = ROWS[row]
    if existing is not None:
        await decide(api, headers, existing)
    if deleter == "operator":
        await pending_account_deletion(api, headers, monkeypatch)
    async with sessions() as holder:
        # Pause the decision inside its transaction, after its user KEY SHARE lock.
        if existing is None:
            await holder.execute(text(
                "INSERT INTO ai_transfer_consents VALUES (:u, 'granted', 1, now(), false)"),
                {"u": user_id})
        else:
            await holder.execute(text(
                "SELECT 1 FROM ai_transfer_consents WHERE user_id = :u FOR UPDATE"),
                {"u": user_id})
        deciding = asyncio.create_task(decide(api, headers, sent))
        await until_waiting(sessions, 1)
        deleting = asyncio.create_task(
            delete_account(api, headers) if deleter == "api" else operator_retry(sessions))
        await until_waiting(sessions, 2)  # The deletion waits for the decision.
        await holder.rollback()
    decided = await asyncio.wait_for(deciding, WAIT)
    assert decided["status"] == sent
    deleted = await asyncio.wait_for(deleting, WAIT)
    if deleter == "api":
        assert deleted.status_code == 204
    else:
        assert deleted["deleted_accounts"] == 1
    assert await consent_rows(sessions, user_id) == []
    await request(api, "GET", "users/me", headers=headers, status=401)


@pytest.mark.parametrize("deleter", ["api", "operator"])
@pytest.mark.parametrize("row", list(ROWS))
async def test_deletion_first_then_decision(independent_api, monkeypatch, row, deleter):
    api, headers, user_id, sessions, _, _ = independent_api
    existing, sent = ROWS[row]
    if existing is not None:
        await decide(api, headers, existing)
    if deleter == "operator":
        await pending_account_deletion(api, headers, monkeypatch)
    entered, release = pause(monkeypatch, account_deletion_service, "_locked_created_at",
                             after=True)
    deleting = asyncio.create_task(
        delete_account(api, headers) if deleter == "api" else operator_retry(sessions))
    try:
        await asyncio.wait_for(entered.wait(), WAIT)  # The deletion holds the user FOR UPDATE.
        deciding = asyncio.create_task(api.put(
            "/api/v1/users/me/ai-consent", headers=headers,
            json={"status": sent, "notice_version": 1}))
        await until_waiting(sessions, 1)
        assert not deciding.done()
    finally:
        release.set()
    deleted = await asyncio.wait_for(deleting, WAIT)
    if deleter == "api":
        assert deleted.status_code == 204
    else:
        assert deleted["deleted_accounts"] == 1
    decided = await asyncio.wait_for(deciding, WAIT)
    assert decided.status_code == 401, decided.text
    assert await consent_rows(sessions, user_id) == []


@pytest_asyncio.fixture(autouse=True)
async def remove_deletion_reasons(independent_api):
    # Reason rows are not tied to the account, so remove this test's rows explicitly.
    sessions = independent_api[3]
    async with sessions() as session:
        last = await session.scalar(
            text("SELECT coalesce(max(id), 0) FROM account_deletion_reasons"))
    yield
    async with sessions() as session:
        await session.execute(
            text("DELETE FROM account_deletion_reasons WHERE id > :id"), {"id": last})
        await session.commit()


# 게스트 로그인 전환: the record belongs to the account id.

@pytest.mark.parametrize("decide_first", [True, False])
async def test_guest_upgrade_keeps_the_decision(
    independent_api, recommendation_provider, monkeypatch, decide_first,
):
    api, headers, user_id, sessions, _, _ = independent_api
    monkeypatch.setattr(settings, "ai_consent_required", True)
    if decide_first:
        await decide(api, headers, "granted")
        headers = await upgrade(api, headers)
    else:
        headers = await upgrade(api, headers)
        await decide(api, headers, "granted")
    me = await request(api, "GET", "users/me", headers=headers)
    assert (me["id"], me["is_guest"], me["ai_consent_status"]) == (user_id, False, "granted")
    assert await consent_rows(sessions, user_id) == [("granted", False)]
    await save(api, headers, "web")
    assert recommendation_provider.calls == ["recommend"]


@pytest.mark.parametrize("first", ["upgrade", "decision"])
async def test_guest_upgrade_overlapping_a_decision_keeps_it_on_the_account(
    independent_api, recommendation_provider, monkeypatch, first,
):
    """Both run at once on separate connections: the upgrade's user FOR UPDATE and the
    decision's KEY SHARE take turns, and the decision stays with the same account id."""
    api, headers, user_id, sessions, _, _ = independent_api
    monkeypatch.setattr(settings, "ai_consent_required", True)
    if first == "upgrade":
        entered, release = pause(monkeypatch, UserRepository, "get_for_update", after=True)
        upgrading = asyncio.create_task(upgrade(api, headers))
        try:
            await asyncio.wait_for(entered.wait(), WAIT)  # The upgrade holds FOR UPDATE.
            deciding = asyncio.create_task(decide(api, headers, "granted"))
            await until_waiting(sessions, 1)  # The decision waits for its KEY SHARE.
            assert not deciding.done()
        finally:
            release.set()
        new_headers = await asyncio.wait_for(upgrading, WAIT)
        decided = await asyncio.wait_for(deciding, WAIT)
    else:
        async with sessions() as holder:
            # Keep the decision inside its transaction, after its user KEY SHARE lock.
            await holder.execute(text(
                "INSERT INTO ai_transfer_consents VALUES (:u, 'denied', 1, now(), false)"),
                {"u": user_id})
            deciding = asyncio.create_task(decide(api, headers, "granted"))
            await until_waiting(sessions, 1)
            upgrading = asyncio.create_task(upgrade(api, headers))
            await until_waiting(sessions, 2)  # The upgrade's FOR UPDATE waits too.
            assert not deciding.done() and not upgrading.done()
            await holder.rollback()
        decided = await asyncio.wait_for(deciding, WAIT)
        new_headers = await asyncio.wait_for(upgrading, WAIT)
    assert decided["status"] == "granted"
    me = await request(api, "GET", "users/me", headers=new_headers)
    assert (me["id"], me["is_guest"], me["ai_consent_status"]) == (user_id, False, "granted")
    assert await consent_rows(sessions, user_id) == [("granted", False)]
    await save(api, new_headers, "web")
    assert recommendation_provider.calls == ["recommend"]


# 같은 제출 키: a committed save is replayed without AI; a failed one is judged anew.

async def test_withdrawal_then_same_key_replays_a_committed_save(
    independent_api, recommendation_provider,
):
    api, headers, _, _, _, _ = independent_api
    key = str(uuid4())
    first = await save(api, headers, "web", key=key)
    await decide(api, headers, "denied")
    assert await save(api, headers, "web", key=key) == first
    assert recommendation_provider.calls == ["recommend"]


async def test_withdrawal_then_same_key_after_a_failed_save_is_judged_anew(
    independent_api, recommendation_provider, monkeypatch,
):
    api, headers, user_id, sessions, _, _ = independent_api
    create = EventRepository.create
    failures = 0

    async def fail_once(self, **kwargs):
        nonlocal failures
        failures += 1
        if failures == 1:
            raise RuntimeError("injected failure before commit")
        return await create(self, **kwargs)

    monkeypatch.setattr(EventRepository, "create", fail_once)
    key = str(uuid4())
    failed = await api.post("/api/v1/contents", json={"original_url": INSTAGRAM},
                            headers={**headers, "Idempotency-Key": key})
    assert failed.status_code == 500
    assert recommendation_provider.calls == ["recommend"]
    await decide(api, headers, "denied")
    retried = await save(api, headers, "instagram", key=key)
    assert recommendation_provider.calls == ["recommend"]
    assert (retried["summary_status"], retried["summary_error_code"]) == ("skipped", REASON)
    assert category_names(retried) == ["미분류"]
    assert await count(sessions, Content, Content.user_id == user_id) == 1
