"""#475 overlapping saves and AI 전송 동의 changes on real PostgreSQL with separate sessions
(#474 동시 요청 표, the save and decision rows; 순서가 결과를 바꾸는 입력, the rows that change
the decision during a save). AI calls are counted at the OpenAI SDK transport (`provider`).

Every request records its own backend PID. A wait is proven by `pg_blocking_pids` naming the
expected holder, and every started request is released, cancelled if stuck and collected
before the account is cleaned up, also when the test fails midway (`producers`).
"""

import asyncio
import logging
from datetime import date
from uuid import uuid4

import pytest
import pytest_asyncio
from sqlalchemy import delete, event, func, select, text

from app.api.v1.endpoints import users as users_endpoint
from app.core.config import settings
from app.models.account_deletion_reason import AccountDeletionReason
from app.models.category import Category
from app.models.content import Content
from app.models.content_asset import ContentAsset
from app.models.content_event import ContentEvent
from app.models.summary_job import SummaryJob
from app.models.usage_record import UsageRecord
from app.models.user import User
from app.repositories.event_repository import EventRepository
from app.repositories.user_repository import UserRepository
from app.services import account_deletion_service, ai_consent, usage_limits
from app.services.ai_consent import SaveAIConsent
from app.services.content_service import ContentService
from app.services.image_deletion_service import retry_image_deletions
from app.services.usage_limits import DailyRecommendationLimit, MonthlySummaryLimit
from tests.integration.helpers import request
from tests.integration.test_recommendation_usage_limits import (
    NOW,
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
UNRELATED_LOCK = 4750001


@pytest.fixture(autouse=True)
def summaries_on(monkeypatch):
    monkeypatch.setattr(settings, "youtube_summary_enabled", True)
    monkeypatch.setattr(settings, "instagram_summary_enabled", True)


class Producers:
    """Requests and pauses a test started. `close` releases every pause, waits for the
    requests, cancels any still stuck and collects them all; it may run more than once."""

    def __init__(self):
        self.tasks, self.releases = [], []

    def start(self, coroutine):
        task = asyncio.create_task(coroutine)
        self.tasks.append(task)
        return task

    async def close(self):
        for release in self.releases:
            release.set()
        if self.tasks:
            _, pending = await asyncio.wait(self.tasks, timeout=WAIT)
            for task in pending:
                task.cancel()
            await asyncio.gather(*self.tasks, return_exceptions=True)


@pytest_asyncio.fixture
async def producers(independent_api):
    # Depends on independent_api, so it closes before the account cleanup runs.
    state = Producers()
    try:
        yield state
    finally:
        await state.close()


@pytest.fixture
def pids(monkeypatch, independent_api):
    """The backend PID of each decision, save, deletion and upgrade, read on the request's
    own session right before its locking statement."""
    seen = {"decide": [], "save": [], "delete": [], "upgrade": []}

    async def pid(session):
        return await session.scalar(text("SELECT pg_backend_pid()"))

    decide = ai_consent.decide
    allows = SaveAIConsent.allows
    locked = account_deletion_service._locked_created_at
    for_update = UserRepository.get_for_update

    async def tracked_decide(session, user_id, **kwargs):
        seen["decide"].append(await pid(session))
        return await decide(session, user_id, **kwargs)

    saves = set()

    async def tracked_allows(self, user_id):
        if id(self) not in saves:  # The save request's first check.
            saves.add(id(self))
            seen["save"].append(await pid(self.session))
        return await allows(self, user_id)

    async def tracked_locked(session, user_id):
        seen["delete"].append(await pid(session))
        return await locked(session, user_id)

    async def tracked_for_update(self, user_id):
        seen["upgrade"].append(await pid(self.session))
        return await for_update(self, user_id)

    monkeypatch.setattr(ai_consent, "decide", tracked_decide)
    monkeypatch.setattr(SaveAIConsent, "allows", tracked_allows)
    monkeypatch.setattr(account_deletion_service, "_locked_created_at", tracked_locked)
    monkeypatch.setattr(UserRepository, "get_for_update", tracked_for_update)
    return seen


def pause(monkeypatch, producers, target, name, *, after=False):
    """Hold the first call of target.name before (or after) it runs until released."""
    original = getattr(target, name)
    entered, release = asyncio.Event(), asyncio.Event()
    producers.releases.append(release)
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


def gate_transport(monkeypatch, producers, provider):
    """Hold the first OpenAI request after it reached the SDK transport, before its answer."""
    transport = provider.ai_client._client._client._transport
    original = transport.handle_async_request
    arrived, respond = asyncio.Event(), asyncio.Event()
    producers.releases.append(respond)
    state = {"arrived": 0}

    async def gated(http_request):
        state["arrived"] += 1
        if state["arrived"] == 1:
            arrived.set()
            await asyncio.wait_for(respond.wait(), WAIT)
        return await original(http_request)

    monkeypatch.setattr(transport, "handle_async_request", gated)
    return arrived, respond, state


def decide_with_held_commit(producers, sessions, user_id, status, opened=None):
    """Run the decision service in a task that owns its session, holding the commit: the
    decision is written and its locks are held. The task closes its session itself, also
    when the test fails and `producers` releases it."""
    written, release = asyncio.Event(), asyncio.Event()
    producers.releases.append(release)

    async def run():
        async with sessions() as session:
            if opened is not None:
                opened.append(await backend_pid(session))
            commit = session.commit

            async def held():
                written.set()
                await asyncio.wait_for(release.wait(), WAIT)
                await commit()

            session.commit = held
            return await ai_consent.decide(session, user_id, status=status)

    return producers.start(run()), written, release


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


async def backend_pid(session):
    return await session.scalar(text("SELECT pg_backend_pid()"))


async def recorded(seen, kind, index=0):
    """The PID of the index-th tracked request of this kind, once it ran its first query."""
    for _ in range(250):
        if len(seen[kind]) > index:
            return seen[kind][index]
        await asyncio.sleep(0.02)
    raise AssertionError(f"no {kind} request reached the database")


async def until_blocked(sessions, waiter, holder):
    """Wait until PostgreSQL reports this waiter PID blocked by this holder PID."""
    for _ in range(250):
        async with sessions() as session:
            if await session.scalar(text("SELECT :h = ANY(pg_blocking_pids(:w))"),
                                    {"h": holder, "w": waiter}):
                return
        await asyncio.sleep(0.02)
    async with sessions() as session:
        activity = (await session.execute(text(
            "SELECT pid, wait_event_type, wait_event, state, pg_blocking_pids(pid), "
            "left(query, 60) FROM pg_stat_activity WHERE datname = current_database()"))).all()
    raise AssertionError(f"PID {waiter} was never blocked by PID {holder}: {activity}")


async def hold_decisions(holder):
    """Stop every decision right after its user KEY SHARE lock, at its record write, while
    the holder itself locks no user row. Returns the holder PID."""
    pid = await backend_pid(holder)
    await holder.execute(text("LOCK TABLE ai_transfer_consents IN SHARE ROW EXCLUSIVE MODE"))
    return pid


async def blocked_pids(sessions, candidates):
    async with sessions() as session:
        return (await session.scalars(text(
            "SELECT pid FROM pg_stat_activity WHERE pid = ANY(:p) "
            "AND cardinality(pg_blocking_pids(pid)) > 0"), {"p": list(candidates)})).all()


async def lock_waiters(sessions):
    async with sessions() as session:
        return await session.scalar(text(
            "SELECT count(*) FROM pg_stat_activity "
            "WHERE datname = current_database() AND wait_event_type = 'Lock'"))


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
    independent_api, recommendation_provider, monkeypatch, producers, pids,
):
    api, headers, user_id, sessions, _, _ = independent_api
    entered, release = pause(monkeypatch, producers, DailyRecommendationLimit, "admit",
                             after=True)
    saving = producers.start(save(api, headers, "web"))
    await asyncio.wait_for(entered.wait(), WAIT)
    assert await usage(sessions, user_id, "category_recommendation") == 1
    await asyncio.wait_for(decide(api, headers, "denied"), WAIT)
    # The decision committed on its own connection while the save waits in its request.
    assert pids["decide"][0] != pids["save"][0] and not saving.done()
    release.set()
    saved = await asyncio.wait_for(saving, WAIT)
    assert recommendation_provider.calls == []
    assert category_names(saved) == ["미분류"]
    assert await usage(sessions, user_id, "category_recommendation") == 0


async def test_withdrawal_while_the_request_awaits_its_answer_keeps_the_recommendation(
    independent_api, recommendation_provider, monkeypatch, producers, pids,
):
    api, headers, user_id, sessions, _, _ = independent_api
    arrived, respond, transport = gate_transport(monkeypatch, producers,
                                                 recommendation_provider)
    saving = producers.start(save(api, headers, "web"))
    await asyncio.wait_for(arrived.wait(), WAIT)
    assert transport["arrived"] == 1 and recommendation_provider.calls == []
    await asyncio.wait_for(decide(api, headers, "denied"), WAIT)
    assert pids["decide"][0] != pids["save"][0] and not saving.done()
    respond.set()
    saved = await asyncio.wait_for(saving, WAIT)
    assert transport["arrived"] == 1
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


# 추천 시도 기록: G1b removes exactly the row its own attempt added.

async def test_two_blocked_attempts_at_the_same_time_each_remove_their_own_row(
    independent_api, recommendation_provider, monkeypatch, producers,
):
    api, headers, user_id, sessions, _, _ = independent_api
    monkeypatch.setattr(usage_limits, "now", lambda: NOW)  # Both attempts share one time.
    admit = DailyRecommendationLimit.admit
    barrier, release = asyncio.Barrier(3), asyncio.Event()
    producers.releases.append(release)
    attempts = []

    async def held(limit, candidate):
        attempt = await admit(limit, candidate)
        attempts.append(attempt)
        await barrier.wait()
        await asyncio.wait_for(release.wait(), WAIT)
        return attempt

    monkeypatch.setattr(DailyRecommendationLimit, "admit", held)
    saving = [producers.start(request(api, "POST", "contents", headers=headers, status=201,
                                      json={"original_url": f"{WEB}/{index}"}))
              for index in range(2)]
    await asyncio.wait_for(barrier.wait(), WAIT)
    async with sessions() as session:
        times = (await session.scalars(select(UsageRecord.recorded_at).where(
            UsageRecord.user_id == user_id))).all()
    assert len(set(attempts)) == 2 and times == [NOW, NOW]
    await decide(api, headers, "denied")
    release.set()
    saved = await asyncio.wait_for(asyncio.gather(*saving), WAIT)
    assert [category_names(item) for item in saved] == [["미분류"], ["미분류"]]
    assert recommendation_provider.calls == []
    assert await usage(sessions, user_id, "category_recommendation") == 0


@pytest.mark.parametrize("failure", ["database_error", "row_missing"])
async def test_attempt_removal_failure_is_logged_and_the_save_succeeds(
    independent_api, recommendation_provider, monkeypatch, producers, caplog, failure,
):
    api, headers, user_id, sessions, _, _ = independent_api
    entered, release = pause(monkeypatch, producers, DailyRecommendationLimit, "admit",
                             after=True)
    saving = producers.start(save(api, headers, "web"))
    await asyncio.wait_for(entered.wait(), WAIT)
    await decide(api, headers, "denied")
    if failure == "row_missing":
        async with sessions.begin() as session:
            await session.execute(text(
                "DELETE FROM usage_records WHERE user_id = :u"), {"u": user_id})
    else:
        def unavailable():
            raise ConnectionError("injected recommendation session failure")

        monkeypatch.setattr(usage_limits, "RecommendationSessionLocal", unavailable)
    with caplog.at_level(logging.WARNING, logger="app.services.usage_limits"):
        release.set()
        saved = await asyncio.wait_for(saving, WAIT)
    assert category_names(saved) == ["미분류"]
    assert recommendation_provider.calls == []
    message = {"database_error": "Unable to remove category recommendation attempt",
               "row_missing": "attempt to remove was not found"}[failure]
    assert any(message in record.getMessage() for record in caplog.records)
    assert await usage(sessions, user_id, "category_recommendation") == int(
        failure == "database_error")


# 사진 글자 읽기. The photo save holds the user row FOR NO KEY UPDATE; a decision does not
# wait for it (V17).

async def test_withdrawal_after_the_monthly_check_keeps_only_the_original(
    independent_api, recommendation_provider, monkeypatch, png_bytes, producers, pids,
):
    api, headers, user_id, sessions, _, path = independent_api
    entered, release = pause(monkeypatch, producers, MonthlySummaryLimit, "admit", after=True)
    saving = producers.start(save(api, headers, "photo", png_bytes))
    await asyncio.wait_for(entered.wait(), WAIT)
    await asyncio.wait_for(decide(api, headers, "denied"), WAIT)
    assert pids["decide"][0] != pids["save"][0] and not saving.done()
    release.set()
    saved = await asyncio.wait_for(saving, WAIT)
    assert recommendation_provider.calls == []
    assert (saved["summary_status"], saved["summary_error_code"]) == ("skipped", REASON)
    assert await count(sessions, ContentAsset, ContentAsset.content_id == saved["id"]) == 1
    assert len(list(path.rglob("*.png"))) == 1
    assert await usage(sessions, user_id, "ai_summary") == 0


async def test_withdrawal_while_text_reading_awaits_its_answer_keeps_it_without_recommending(
    independent_api, recommendation_provider, monkeypatch, png_bytes, producers, pids,
):
    api, headers, user_id, sessions, _, _ = independent_api
    arrived, respond, transport = gate_transport(monkeypatch, producers,
                                                 recommendation_provider)
    saving = producers.start(save(api, headers, "photo", png_bytes))
    await asyncio.wait_for(arrived.wait(), WAIT)
    assert transport["arrived"] == 1 and recommendation_provider.calls == []
    await asyncio.wait_for(decide(api, headers, "denied"), WAIT)
    assert pids["decide"][0] != pids["save"][0] and not saving.done()
    respond.set()
    saved = await asyncio.wait_for(saving, WAIT)
    assert transport["arrived"] == 1
    assert recommendation_provider.calls == ["ocr"]
    assert saved["title"] == "화면 제목"
    assert [tag["name"] for tag in saved["tags"]] == ["사진"]
    assert category_names(saved) == ["미분류"]
    assert (saved["summary_status"], saved["summary_error_code"]) == ("not_requested", None)
    assert await usage(sessions, user_id, "ai_summary") == 1
    assert await usage(sessions, user_id, "category_recommendation") == 0


# 철회→재동의 중 진행 저장: a save that started before the re-grant committed stays without AI.

@pytest.mark.parametrize(("kind", "target", "after_regrant"), [
    ("web", DailyRecommendationLimit, ("not_requested", None)),
    ("instagram", DailyRecommendationLimit, ("skipped", REASON)),
    ("photo", MonthlySummaryLimit, ("skipped", REASON)),
])
async def test_save_in_progress_across_withdraw_and_regrant_sends_nothing(
    independent_api, recommendation_provider, monkeypatch, png_bytes, producers, kind, target,
    after_regrant,
):
    api, headers, user_id, sessions, _, _ = independent_api
    await decide(api, headers, "granted")
    entered, release = pause(monkeypatch, producers, target, "admit", after=True)
    saving = producers.start(save(api, headers, kind, png_bytes))
    await asyncio.wait_for(entered.wait(), WAIT)
    await decide(api, headers, "denied")
    await decide(api, headers, "granted")
    assert not saving.done()
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


async def test_save_started_between_a_regrant_write_and_its_commit_stays_without_ai(
    independent_api, recommendation_provider, monkeypatch, producers, pids,
):
    """Review Spec 1: the re-grant is written (and dated) but not committed when the save's
    first check reads the denial; after the commit the save must not count as covered."""
    api, headers, user_id, sessions, _, _ = independent_api
    await decide(api, headers, "granted")
    await decide(api, headers, "denied")
    regranting, written, commit = decide_with_held_commit(producers, sessions, user_id,
                                                          "granted")
    await asyncio.wait_for(written.wait(), WAIT)
    entered, release = pause(monkeypatch, producers, ContentService, "write")
    saving = producers.start(save(api, headers, "instagram"))
    await asyncio.wait_for(entered.wait(), WAIT)  # G1a read the denial already.
    assert await recorded(pids, "save") != await recorded(pids, "decide", 2)
    commit.set()
    assert (await asyncio.wait_for(regranting, WAIT)).granted_after_denial is True
    release.set()
    saved = await asyncio.wait_for(saving, WAIT)
    assert (saved["summary_status"], saved["summary_error_code"]) == ("skipped", REASON)
    assert recommendation_provider.calls == []
    assert await usage(sessions, user_id, "ai_summary") == 0
    assert await usage(sessions, user_id, "category_recommendation") == 0
    fresh = await save(api, headers, "instagram")
    assert (fresh["summary_status"], recommendation_provider.calls) == ("queued", ["recommend"])


@pytest.mark.parametrize(("kind", "target", "after_regrant"), [
    ("web", DailyRecommendationLimit, ("not_requested", None)),
    ("photo", MonthlySummaryLimit, ("skipped", REASON)),
])
async def test_save_started_while_a_regrant_waits_on_the_withdrawal_stays_without_ai(
    independent_api, recommendation_provider, monkeypatch, png_bytes, producers, pids, kind,
    target, after_regrant,
):
    """Review Spec 1: the withdrawal holds the record uncommitted, the re-grant PUT waits on
    its row lock, and a save passes its first check under the old grant meanwhile."""
    api, headers, user_id, sessions, _, _ = independent_api
    await decide(api, headers, "granted")
    withdrawing, written, commit = decide_with_held_commit(producers, sessions, user_id,
                                                           "denied")
    await asyncio.wait_for(written.wait(), WAIT)
    regranting = producers.start(decide(api, headers, "granted"))
    await until_blocked(sessions, await recorded(pids, "decide", 2),
                        await recorded(pids, "decide", 1))
    entered, release = pause(monkeypatch, producers, target, "admit", after=True)
    saving = producers.start(save(api, headers, kind, png_bytes))
    await asyncio.wait_for(entered.wait(), WAIT)  # The first check saw the old grant.
    commit.set()
    await asyncio.wait_for(withdrawing, WAIT)
    assert (await asyncio.wait_for(regranting, WAIT))["status"] == "granted"
    assert await consent_rows(sessions, user_id) == [("granted", True)]
    release.set()
    saved = await asyncio.wait_for(saving, WAIT)
    assert (saved["summary_status"], saved["summary_error_code"]) == after_regrant
    assert recommendation_provider.calls == []
    assert category_names(saved) == ["미분류"]
    assert await usage(sessions, user_id, "category_recommendation") == 0
    assert await usage(sessions, user_id, "ai_summary") == 0
    fresh = await save(api, headers, kind, png_bytes)
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
async def test_two_devices_end_with_the_later_commit(
    independent_api, producers, pids, first, second,
):
    api, headers, user_id, sessions, _, _ = independent_api
    await decide(api, headers, "granted")
    async with sessions() as holder:
        # Hold the record so both requests queue on it in order.
        holder_pid = await backend_pid(holder)
        await holder.execute(text(
            "SELECT 1 FROM ai_transfer_consents WHERE user_id = :u FOR UPDATE"), {"u": user_id})
        a = producers.start(decide(api, headers, first))
        await until_blocked(sessions, await recorded(pids, "decide", 1), holder_pid)
        a_pid = await recorded(pids, "decide", 1)
        b = producers.start(decide(api, headers, second))
        # The second device queues behind the first one on the record's row lock.
        await until_blocked(sessions, await recorded(pids, "decide", 2), a_pid)
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


class OwnReasonRows:
    """Ids of the deletion reason rows written by deletion requests of this fixture's own
    account. Only such a request's session is observed, for exactly that request's duration;
    rows another account's deletion or any other session writes are never collected."""

    def __init__(self, producers, user_id):
        self.ids, self.producers, self.observing = [], producers, 0
        self.user_id = user_id

    def collect(self, session, instance):
        if isinstance(instance, AccountDeletionReason):
            self.ids.append(instance.id)

    def wrap(self, delete_account):
        async def owned(session, *args, **kwargs):
            if kwargs.get("user_id") != self.user_id:
                return await delete_account(session, *args, **kwargs)
            event.listen(session.sync_session, "pending_to_persistent", self.collect)
            self.observing += 1
            try:
                return await delete_account(session, *args, **kwargs)
            finally:
                event.remove(session.sync_session, "pending_to_persistent", self.collect)
                self.observing -= 1

        return owned

    async def finish(self, sessions):
        """Collect every started request first, so no reason row is written afterwards."""
        await self.producers.close()
        assert self.observing == 0
        if self.ids:
            async with sessions.begin() as session:
                await session.execute(text(
                    "DELETE FROM account_deletion_reasons WHERE id = ANY(:ids)"),
                    {"ids": self.ids})


@pytest_asyncio.fixture
async def own_reasons(independent_api, producers, monkeypatch):
    rows = OwnReasonRows(producers, independent_api[2])
    monkeypatch.setattr(users_endpoint, "delete_account",
                        rows.wrap(users_endpoint.delete_account))
    try:
        yield rows
    finally:
        await rows.finish(independent_api[3])


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


async def foreign_reason(sessions):
    """A reason row another ORM session writes while this test's deletion is in progress."""
    async with sessions.begin() as other:
        row = AccountDeletionReason(reasons=["rejoin"], deleted_on=date.today())
        other.add(row)
        await other.flush()
        return row.id


async def drop_reason(sessions, row_id):
    async with sessions.begin() as other:
        await other.execute(text("DELETE FROM account_deletion_reasons WHERE id = :id"),
                            {"id": row_id})


async def existing_reasons(sessions, ids):
    async with sessions() as session:
        return sorted((await session.scalars(text(
            "SELECT id FROM account_deletion_reasons WHERE id = ANY(:ids)"),
            {"ids": list(ids)})).all())


@pytest.mark.parametrize("fail", [False, True], ids=["normal", "failure_before_reason_insert"])
async def test_reason_cleanup_keeps_rows_another_orm_session_wrote(
    independent_api, monkeypatch, producers, own_reasons, fail,
):
    api, headers, _, sessions, _, _ = independent_api
    # Hold the deletion right before it adds its reason row (after the account rows).
    entered, release = pause(monkeypatch, producers, account_deletion_service,
                             "apply_account_deletion", after=True)
    deleting = producers.start(delete_account(api, headers))
    await asyncio.wait_for(entered.wait(), WAIT)
    foreign = await foreign_reason(sessions)
    try:
        if fail:
            with pytest.raises(AssertionError, match="injected"):
                raise AssertionError("injected failure while the deletion waits")
            # The fixture's own exit: collect requests first, then remove only own rows.
            await own_reasons.finish(sessions)
            assert deleting.done() and own_reasons.observing == 0
        else:
            release.set()
            assert (await asyncio.wait_for(deleting, WAIT)).status_code == 204
            await own_reasons.finish(sessions)
        assert len(own_reasons.ids) == 1 and foreign not in own_reasons.ids
        assert await existing_reasons(sessions, [foreign, *own_reasons.ids]) == [foreign]
    finally:
        await drop_reason(sessions, foreign)


async def drop_account(sessions, user_id):
    """What independent_api's cleanup does for its own account, for a second one."""
    async with sessions.begin() as session:
        for model in (ContentEvent, Content, Category):
            await session.execute(delete(model).where(model.user_id == user_id))
        await session.execute(delete(User).where(User.id == user_id))


async def opened_session(request_pids, index):
    """The PID of the index-th request session independent_api opened."""
    for _ in range(250):
        if len(request_pids) > index:
            return request_pids[index]
        await asyncio.sleep(0.02)
    raise AssertionError("the request opened no session")


async def test_reason_cleanup_keeps_another_account_deleted_through_the_same_api(
    independent_api, monkeypatch, producers, pids, own_reasons,
):
    """Review recheck 2, Standards 1 (recheck 3, Standards 1): a second account leaves
    through DELETE /users/me while this test's deletion is in progress; its reason row must
    survive this test's cleanup. Each request is tied to its own PID, the PID it waits for
    and the reason row it inserted; the second account and its row are cleaned up from its
    creation on, after every request was collected. Its user PK is taken from the request
    session that creates it (recheck 4), before anything else can fail; the reason cleanup
    and the account cleanup are each tried, and both failures are kept."""
    api, headers, _, sessions, request_pids, _ = independent_api
    created = []  # User PKs the second account's POST /auth/guest flushed.
    create_guest = UserRepository.create_guest

    async def recorded_guest(self):
        user = await create_guest(self)
        created.append(user.id)
        return user

    monkeypatch.setattr(UserRepository, "create_guest", recorded_guest)
    theirs_rows = None
    try:
        tokens = await request(api, "POST", "auth/guest", status=201)
        assert len(created) == 1
        theirs_rows = OwnReasonRows(producers, created[0])
        monkeypatch.setattr(users_endpoint, "delete_account",
                            theirs_rows.wrap(users_endpoint.delete_account))
        other_headers = {"Authorization": f"Bearer {tokens['access_token']}"}
        other = await request(api, "GET", "users/me", headers=other_headers)
        assert other["id"] == created[0]
        entered, release = pause(monkeypatch, producers, account_deletion_service,
                                 "apply_account_deletion", after=True)
        mine = producers.start(delete_account(api, headers))
        await asyncio.wait_for(entered.wait(), WAIT)  # Holds the deletion ledger lock.
        my_pid = pids["delete"][0]
        assert set(pids["delete"]) == {my_pid}  # Both account row reads ran on its session.
        # The second deletion stops at the ledger lock before its own row read, so its PID
        # is the request session it opened (independent_api records each one).
        opened = len(request_pids)
        theirs = producers.start(api.request(
            "DELETE", "/api/v1/users/me", headers=other_headers,
            json={"reasons": ["rejoin"]}))
        their_pid = await opened_session(request_pids, opened)
        assert their_pid != my_pid
        # The other deletion really overlaps: PostgreSQL reports its PID waiting for mine.
        await until_blocked(sessions, their_pid, my_pid)
        assert not theirs.done() and own_reasons.ids == [] and theirs_rows.ids == []
        release.set()
        assert (await asyncio.wait_for(mine, WAIT)).status_code == 204
        assert (await asyncio.wait_for(theirs, WAIT)).status_code == 204
        await own_reasons.finish(sessions)  # What the fixture's exit does.
        assert len(own_reasons.ids) == 1 and len(theirs_rows.ids) == 1
        my_row, their_row = own_reasons.ids[0], theirs_rows.ids[0]
        assert my_row != their_row
        assert await existing_reasons(sessions, [my_row, their_row]) == [their_row]
    finally:
        failures = []
        if theirs_rows is not None:
            try:
                await theirs_rows.finish(sessions)  # Collects every request, then its row.
            except Exception as error:
                failures.append(error)
        for user_id in created:
            try:
                await drop_account(sessions, user_id)
            except Exception as error:
                failures.append(error)
        if failures:
            raise ExceptionGroup("second account cleanup failed", failures)


async def test_a_failure_while_a_decision_holds_its_commit_closes_its_own_session(
    independent_api, producers, pids,
):
    api, headers, user_id, sessions, _, _ = independent_api
    await decide(api, headers, "granted")
    opened = []
    deciding, written, _ = decide_with_held_commit(producers, sessions, user_id, "denied",
                                                   opened)
    with pytest.raises(AssertionError, match="injected"):
        await asyncio.wait_for(written.wait(), WAIT)
        raise AssertionError("injected failure while the decision holds its commit")
    await producers.close()
    assert deciding.done() and deciding.result().status == "denied"
    # The task committed and closed its own session; its connection holds nothing.
    async with sessions() as session:
        state, reused, locks = (await session.execute(text(
            "SELECT (SELECT state FROM pg_stat_activity WHERE pid = :p), "
            "pg_backend_pid() = :p, "
            "(SELECT count(*) FROM pg_locks WHERE pid = :p AND pid <> pg_backend_pid())"),
            {"p": opened[0]})).one()
    # Closed, idle in the pool, or handed back and now running this very query.
    assert (state in (None, "idle") or reused) and locks == 0
    assert await consent_rows(sessions, user_id) == [("denied", False)]


@pytest.mark.parametrize("deleter", ["api", "operator"])
@pytest.mark.parametrize("row", list(ROWS))
async def test_decision_first_then_deletion(
    independent_api, monkeypatch, producers, pids, own_reasons, row, deleter,
):
    api, headers, user_id, sessions, _, _ = independent_api
    existing, sent = ROWS[row]
    if existing is not None:
        await decide(api, headers, existing)
    if deleter == "operator":
        await pending_account_deletion(api, headers, monkeypatch)
    before = len(pids["decide"])
    async with sessions() as holder:
        holder_pid = await hold_decisions(holder)
        deciding = producers.start(decide(api, headers, sent))
        decide_pid = await recorded(pids, "decide", before)
        await until_blocked(sessions, decide_pid, holder_pid)
        deletes = len(pids["delete"])
        deleting = producers.start(
            delete_account(api, headers) if deleter == "api" else operator_retry(sessions))
        delete_pid = await recorded(pids, "delete", deletes)
        await until_blocked(sessions, delete_pid, decide_pid)  # Waits for the decision.
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
async def test_deletion_first_then_decision(
    independent_api, monkeypatch, producers, pids, own_reasons, row, deleter,
):
    api, headers, user_id, sessions, _, _ = independent_api
    existing, sent = ROWS[row]
    if existing is not None:
        await decide(api, headers, existing)
    if deleter == "operator":
        await pending_account_deletion(api, headers, monkeypatch)
    deletes, before = len(pids["delete"]), len(pids["decide"])
    entered, release = pause(monkeypatch, producers, account_deletion_service,
                             "_locked_created_at", after=True)
    deleting = producers.start(
        delete_account(api, headers) if deleter == "api" else operator_retry(sessions))
    await asyncio.wait_for(entered.wait(), WAIT)  # The deletion holds the user FOR UPDATE.
    delete_pid = pids["delete"][deletes]
    deciding = producers.start(api.put(
        "/api/v1/users/me/ai-consent", headers=headers,
        json={"status": sent, "notice_version": 1}))
    await until_blocked(sessions, await recorded(pids, "decide", before), delete_pid)
    release.set()
    deleted = await asyncio.wait_for(deleting, WAIT)
    if deleter == "api":
        assert deleted.status_code == 204
    else:
        assert deleted["deleted_accounts"] == 1
    decided = await asyncio.wait_for(deciding, WAIT)
    assert decided.status_code == 401, decided.text
    assert await consent_rows(sessions, user_id) == []


# Waits name their PIDs, so an unrelated lock wait cannot satisfy them; a failure while
# requests wait still releases and collects every request.

async def hold_unrelated_lock(sessions, started):
    async with sessions() as session:
        started.append(await backend_pid(session))
        await session.execute(text("SELECT pg_advisory_xact_lock(:k)"), {"k": UNRELATED_LOCK})
        await session.rollback()


async def test_an_unrelated_lock_wait_does_not_satisfy_the_wait(
    independent_api, producers, pids,
):
    api, headers, user_id, sessions, _, _ = independent_api
    await decide(api, headers, "granted")
    unrelated_pids = []
    async with sessions() as blocker, sessions() as holder:
        blocker_pid = await backend_pid(blocker)
        await blocker.execute(text("SELECT pg_advisory_xact_lock(:k)"), {"k": UNRELATED_LOCK})
        unrelated = producers.start(hold_unrelated_lock(sessions, unrelated_pids))
        for _ in range(250):
            if unrelated_pids:
                break
            await asyncio.sleep(0.02)
        await until_blocked(sessions, unrelated_pids[0], blocker_pid)
        # A count of lock waiters is already 1 before the decision starts.
        assert await lock_waiters(sessions) >= 1
        holder_pid = await backend_pid(holder)
        await holder.execute(text(
            "SELECT 1 FROM ai_transfer_consents WHERE user_id = :u FOR UPDATE"), {"u": user_id})
        deciding = producers.start(decide(api, headers, "denied"))
        decide_pid = await recorded(pids, "decide", 1)
        await until_blocked(sessions, decide_pid, holder_pid)
        assert not await sessions_scalar(
            sessions, "SELECT :h = ANY(pg_blocking_pids(:w))", h=holder_pid, w=unrelated_pids[0])
        assert sorted(await blocked_pids(sessions, [decide_pid, unrelated_pids[0]])) == sorted(
            [decide_pid, unrelated_pids[0]])
        await holder.rollback()
        assert (await asyncio.wait_for(deciding, WAIT))["status"] == "denied"
        await blocker.rollback()
    await asyncio.wait_for(unrelated, WAIT)


async def sessions_scalar(sessions, sql, **params):
    async with sessions() as session:
        return await session.scalar(text(sql), params)


async def test_a_failure_while_requests_wait_still_collects_them(
    independent_api, recommendation_provider, monkeypatch, producers, pids,
):
    api, headers, user_id, sessions, _, _ = independent_api
    await decide(api, headers, "granted")
    entered, _ = pause(monkeypatch, producers, DailyRecommendationLimit, "admit", after=True)
    saving = producers.start(save(api, headers, "web"))
    deciding = None
    with pytest.raises(AssertionError, match="injected"):
        async with sessions() as holder:
            holder_pid = await backend_pid(holder)
            await holder.execute(text(
                "SELECT 1 FROM ai_transfer_consents WHERE user_id = :u FOR UPDATE"),
                {"u": user_id})
            deciding = producers.start(decide(api, headers, "denied"))
            await asyncio.wait_for(entered.wait(), WAIT)
            await until_blocked(sessions, await recorded(pids, "decide", 1), holder_pid)
            raise AssertionError("injected failure while both requests wait")
    await producers.close()
    assert saving.done() and deciding.done()
    assert await blocked_pids(sessions, [*pids["decide"], *pids["save"]]) == []
    # The account's own rows can be cleaned up right away.
    async with sessions.begin() as session:
        await session.execute(text("SET LOCAL lock_timeout = '1s'"))
        await session.execute(text(
            "DELETE FROM ai_transfer_consents WHERE user_id = :u"), {"u": user_id})


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
    independent_api, recommendation_provider, monkeypatch, producers, pids, first,
):
    """Both run at once on separate connections: the upgrade's user FOR UPDATE and the
    decision's KEY SHARE take turns, and the decision stays with the same account id."""
    api, headers, user_id, sessions, _, _ = independent_api
    monkeypatch.setattr(settings, "ai_consent_required", True)
    if first == "upgrade":
        entered, release = pause(monkeypatch, producers, UserRepository, "get_for_update",
                                 after=True)
        upgrading = producers.start(upgrade(api, headers))
        await asyncio.wait_for(entered.wait(), WAIT)  # The upgrade holds FOR UPDATE.
        deciding = producers.start(decide(api, headers, "granted"))
        await until_blocked(sessions, await recorded(pids, "decide"),
                            await recorded(pids, "upgrade"))
        release.set()
        new_headers = await asyncio.wait_for(upgrading, WAIT)
        decided = await asyncio.wait_for(deciding, WAIT)
    else:
        async with sessions() as holder:
            holder_pid = await hold_decisions(holder)
            deciding = producers.start(decide(api, headers, "granted"))
            decide_pid = await recorded(pids, "decide")
            await until_blocked(sessions, decide_pid, holder_pid)
            upgrading = producers.start(upgrade(api, headers))
            await until_blocked(sessions, await recorded(pids, "upgrade"), decide_pid)
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
