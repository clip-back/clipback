"""#476: exercise the summary worker and consent PUT on distinct PostgreSQL sessions."""

import asyncio
import socket
from contextlib import AsyncExitStack, asynccontextmanager
from datetime import UTC, datetime, timedelta
from io import BytesIO
from uuid import uuid4

import asyncpg
import httpx
import pytest
from openai import AsyncOpenAI
from PIL import Image
from pydantic import SecretStr
from sqlalchemy import func, select, text, update
from sqlalchemy.exc import DBAPIError
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.core.config import settings
from app.integrations.instagram_summary_client import InstagramSummaryClient
from app.integrations.metadata_client import MetadataClient
from app.integrations.ocr_client import OCRClient
from app.integrations.youtube_summary_client import YouTubeSummaryClient
from app.models.content import Content
from app.models.summary_job import SummaryJob
from app.models.usage_record import UsageRecord
from app.repositories.category_repository import CategoryRepository
from app.repositories.event_repository import EventRepository
from app.services import ai_consent
from app.services.maintenance import MaintenanceGate
from app.services.summary_worker import SummaryWorker
from tests.integration.helpers import request
from tests.integration.test_ai_consent_concurrency import (
    backend_pid,
    decide,
    recommendation_provider as recommendation_provider,
    save as save_input,
    until_blocked,
    usage,
)
from tests.integration.test_save_ai_tags import provider as provider
from tests.integration.test_share_write_concurrency import independent_api as independent_api
from tests.integrations.test_instagram_summary_client import completion, page, public_resolver
from tests.integrations.test_youtube_summary_client import output, video

pytestmark = pytest.mark.asyncio
LINKS = {
    "youtube": "https://youtu.be/dQw4w9WgXcQ",
    "instagram": "https://www.instagram.com/reel/ABC123/",
}
SKIPPED = "ai_consent_required"
IMAGE_URL = "https://scontent.cdninstagram.com/summary.jpg"


async def save(api, headers, kind):
    return (await request(
        api, "POST", "contents", headers=headers, status=201,
        json={"original_url": LINKS[kind], "category_ids": []},
    ))["id"]


async def state(sessions, content_id):
    async with sessions() as session:
        job = await session.get(SummaryJob, content_id)
        count = await session.scalar(
            select(func.count()).select_from(UsageRecord).where(
                UsageRecord.content_id == content_id, UsageRecord.kind == "ai_summary",
            )
        )
        return job, count


async def due(sessions, content_id, **values):
    async with sessions() as session, session.begin():
        await session.execute(
            update(SummaryJob).where(SummaryJob.content_id == content_id).values(**values)
        )


def just_passed():
    return datetime.now(UTC) - timedelta(seconds=1)


@pytest.fixture(autouse=True)
def summaries_enabled(monkeypatch):
    monkeypatch.setattr(settings, "youtube_summary_enabled", True)
    monkeypatch.setattr(settings, "instagram_summary_enabled", True)
    monkeypatch.setattr(settings, "ai_consent_required", False)
    monkeypatch.setattr(settings, "gemini_model", "gemini-test")
    monkeypatch.setattr(settings, "youtube_data_api_key", SecretStr("test"))
    monkeypatch.setattr(settings, "gemini_api_key", SecretStr("test"))


class SummaryTraffic:
    """Record each public fetch and AI send at its own HTTP transport boundary."""

    def __init__(self):
        self.requests = []
        self.before_answer = None
        self.before_public_answer = None
        self.ai_status = self.public_status = 200
        self.png = BytesIO()
        Image.new("RGB", (4, 4)).save(self.png, "PNG")

    async def public(self, stage, answer):
        self.requests.append(stage)
        if self.before_public_answer is not None:
            await self.before_public_answer(stage)
        return answer if self.public_status == 200 else httpx.Response(self.public_status)

    async def ai(self, stage, answer):
        self.requests.append(stage)
        if self.before_answer is not None:
            await self.before_answer(stage)
        return answer if self.ai_status == 200 else httpx.Response(self.ai_status)

    async def youtube(self, req):
        if req.method == "GET" and req.url.host == "www.googleapis.com":
            return await self.public("youtube", httpx.Response(200, json=video()))
        assert req.method == "POST" and req.url.host == "generativelanguage.googleapis.com"
        return await self.ai("gemini", httpx.Response(200, json=output(category_id=None)))

    async def instagram(self, req):
        assert req.method == "GET"
        if req.headers["host"] == "www.instagram.com":
            return await self.public("instagram", page(image=IMAGE_URL))
        assert req.headers["host"] == "scontent.cdninstagram.com"
        return await self.public("image", httpx.Response(200, content=self.png.getvalue()))

    async def openai(self, req):
        assert (req.method, req.url.host, req.url.path) == (
            "POST", "api.openai.com", "/v1/responses",
        )
        assert b"data:image/png;base64," in req.content
        return await self.ai("openai", completion(category_id=None))


@pytest.fixture
def traffic():
    return SummaryTraffic()


@pytest.fixture
def worker_context(independent_api, traffic):
    @asynccontextmanager
    async def open_worker():
        _, _, _, api_sessions, _, _ = independent_api
        engine = create_async_engine(api_sessions.kw["bind"].url)
        sessions = async_sessionmaker(engine, expire_on_commit=False)
        async with AsyncExitStack() as stack:
            stack.push_async_callback(engine.dispose)
            youtube_http = await stack.enter_async_context(
                httpx.AsyncClient(transport=httpx.MockTransport(traffic.youtube))
            )
            openai = await stack.enter_async_context(AsyncOpenAI(
                api_key="test", max_retries=0,
                http_client=httpx.AsyncClient(transport=httpx.MockTransport(traffic.openai)),
            ))
            instagram_metadata = MetadataClient(
                http_transport=httpx.MockTransport(traffic.instagram), resolver=public_resolver,
            )
            youtube = YouTubeSummaryClient(settings, youtube_http)
            instagram = InstagramSummaryClient(settings, instagram_metadata, openai)
            yield SummaryWorker(
                sessions, youtube, settings, instagram_client=instagram,
                maintenance=MaintenanceGate(sessions),
            )

    return open_worker


@pytest.mark.parametrize("kind", list(LINKS))
@pytest.mark.parametrize("regrant", [False, True])
async def test_withdrawal_and_regrant_in_public_preflight_prevent_ai_send(
    independent_api, worker_context, traffic, kind, regrant,
):
    api, headers, user_id, sessions, pids, _ = independent_api
    await decide(api, headers, "granted")
    content_id = await save(api, headers, kind)
    public = ["youtube"] if kind == "youtube" else ["instagram", "image"]

    async def after_public(stage):
        if stage != public[-1]:
            return
        job, count = await state(sessions, content_id)
        assert (job.status, job.attempts, count) == ("processing", 1, 1)
        await decide(api, headers, "denied")
        if regrant:
            await decide(api, headers, "granted")

    traffic.before_public_answer = after_public
    async with worker_context() as worker:
        async with worker.sessions() as session:
            worker_pid = await backend_pid(session)
            saved_at = await session.scalar(
                select(Content.saved_at).where(Content.id == content_id),
            )
        assert await worker.run_once()
    assert pids and worker_pid not in pids
    async with sessions() as session:
        _, grant = await ai_consent.read_consent(session, user_id)
    assert grant.granted_after_denial is regrant and saved_at < grant.decided_at
    assert traffic.requests == public
    job, count = await state(sessions, content_id)
    assert (job.status, job.error_code, job.lease_token, count) == ("skipped", SKIPPED, None, 0)


async def test_withdrawal_cancels_queued_work_and_releases_its_limit(
    independent_api, worker_context, traffic,
):
    api, headers, _, sessions, _, _ = independent_api
    await decide(api, headers, "granted")
    content_id = await save(api, headers, "youtube")
    job, count = await state(sessions, content_id)
    assert (job.status, count) == ("queued", 1)
    await decide(api, headers, "denied")
    job, count = await state(sessions, content_id)
    assert (job.status, job.error_code, job.attempts, count) == ("skipped", SKIPPED, 0, 0)
    await decide(api, headers, "granted")
    async with worker_context() as worker:
        assert not await worker.run_once()
    assert traffic.requests == []


async def test_claim_and_withdrawal_overlap_on_the_job_lock(
    independent_api, worker_context, traffic, monkeypatch,
):
    api, headers, user_id, sessions, pids, _ = independent_api
    await decide(api, headers, "granted")
    content_id = await save(api, headers, "youtube")
    locked, release_claim, denial_committed = (asyncio.Event() for _ in range(3))
    captured_pids = {}
    list_candidates = CategoryRepository.list_recommendation_candidates
    store_decision = ai_consent.decide
    waiting_for_put = asyncio.Event()

    async def pause_claim(repo, user):
        assert user == user_id
        captured_pids["claim"] = await backend_pid(repo.session)
        locked.set()
        await release_claim.wait()
        return await list_candidates(repo, user)

    async def record_put(session, user, **kwargs):
        assert user == user_id and kwargs["status"] == "denied"
        captured_pids["put"] = await backend_pid(session)
        waiting_for_put.set()
        return await store_decision(session, user, **kwargs)

    async def wait_for_denial(stage):
        assert stage == "youtube"
        await denial_committed.wait()

    monkeypatch.setattr(CategoryRepository, "list_recommendation_candidates", pause_claim)
    monkeypatch.setattr(ai_consent, "decide", record_put)
    traffic.before_public_answer = wait_for_denial
    async with worker_context() as worker:
        async with asyncio.timeout(10), asyncio.TaskGroup() as producers:
            running = producers.create_task(worker.run_once())
            await locked.wait()
            withdrawal = producers.create_task(decide(api, headers, "denied"))
            await waiting_for_put.wait()
            assert pids[-1] == captured_pids["put"] != captured_pids["claim"]
            await until_blocked(sessions, captured_pids["put"], captured_pids["claim"])
            release_claim.set()
            await withdrawal
            denial_committed.set()
            assert await running
    assert traffic.requests == ["youtube"]
    job, count = await state(sessions, content_id)
    assert (job.status, job.error_code, job.attempts, count) == ("skipped", SKIPPED, 1, 0)


@pytest.mark.parametrize("answer", [200, 429])
async def test_withdrawal_after_send_keeps_result_but_blocks_retry(
    independent_api, worker_context, traffic, answer,
):
    api, headers, _, sessions, _, _ = independent_api
    await decide(api, headers, "granted")
    content_id = await save(api, headers, "youtube")
    traffic.ai_status = answer

    async def withdraw(stage):
        assert stage == "gemini"
        assert traffic.requests == ["youtube", "gemini"]
        assert (await state(sessions, content_id))[0].status == "processing"
        await decide(api, headers, "denied")

    traffic.before_answer = withdraw
    async with worker_context() as worker:
        assert await worker.run_once()
        job, count = await state(sessions, content_id)
        assert (job.attempts, count) == (1, 1)
        if answer == 200:
            assert (job.status, job.error_code, job.usage) == (
                "completed", None,
                [{"attempt": 1, "tokens": {"promptTokenCount": 100, "candidatesTokenCount": 20}}],
            )
            detail = await request(api, "GET", f"contents/{content_id}", headers=headers)
            assert detail["summary"] == "핵심 내용\n• 세부 사항"
        else:
            assert (job.status, job.error_code) == ("queued", "provider_error")
            await decide(api, headers, "granted")
            await due(sessions, content_id, next_run_at=just_passed())
            assert not await worker.run_once()
            job, count = await state(sessions, content_id)
            assert (job.status, job.error_code, job.attempts, count) == ("skipped", SKIPPED, 1, 0)
    assert traffic.requests == ["youtube", "gemini"]


@pytest.mark.parametrize("attempts", [1, 2])
async def test_expired_lease_after_regrant_checks_attempt_limit_first(
    independent_api, worker_context, traffic, attempts,
):
    api, headers, _, sessions, _, _ = independent_api
    await decide(api, headers, "granted")
    content_id = await save(api, headers, "youtube")
    async with worker_context() as worker:
        first = await worker.claim()
        assert first.content_id == content_id
        await due(sessions, content_id, attempts=attempts, lease_expires_at=just_passed())
        await decide(api, headers, "denied")
        await decide(api, headers, "granted")
        assert not await worker.run_once()
    job, count = await state(sessions, content_id)
    status, code = ("skipped", SKIPPED) if attempts == 1 else ("failed", "timeout")
    assert (job.status, job.error_code, job.attempts, count) == (status, code, attempts, 0)
    assert job.lease_token is job.lease_expires_at is None
    assert traffic.requests == []


@pytest.mark.parametrize("change_at,late_status", [
    ("expired", 200), ("youtube", 200), ("gemini", 200), ("gemini", 429), ("gemini", 400),
])
async def test_replaced_lease_fences_old_preflight_and_late_answers(
    independent_api, worker_context, traffic, change_at, late_status,
):
    api, headers, _, sessions, _, _ = independent_api
    content_id = await save(api, headers, "youtube")
    traffic.ai_status = late_status
    replaced = []
    async with worker_context() as worker, worker_context() as other:
        async def replace(stage):
            assert stage == ("youtube" if change_at == "expired" else change_at)
            old, count = await state(sessions, content_id)
            assert (old.status, old.attempts, count) == ("processing", 1, 1)
            await due(sessions, content_id, lease_expires_at=just_passed())
            if change_at == "expired":
                replaced.append(old)
                return
            new = await other.claim()
            assert new.content_id == content_id and new.lease_token != old.lease_token
            replaced.append(new)

        if change_at == "gemini":
            traffic.before_answer = replace
        else:
            traffic.before_public_answer = replace
        assert await worker.run_once()
        (new,) = replaced
        job, count = await state(sessions, content_id)
        assert (job.status, job.attempts, job.error_code, job.usage, count) == (
            "processing", 1 if change_at == "expired" else 2, None, [], 1,
        )
        assert job.lease_token == new.lease_token
        expected = ["youtube", "gemini"] if change_at == "gemini" else ["youtube"]
        assert traffic.requests == expected


async def test_public_fetch_failure_keeps_its_existing_classification(
    independent_api, worker_context, traffic,
):
    api, headers, _, sessions, _, _ = independent_api
    content_id = await save(api, headers, "youtube")
    traffic.public_status = 503
    async with worker_context() as worker:
        assert await worker.run_once()
    job, count = await state(sessions, content_id)
    assert (job.status, job.error_code, job.attempts, count) == ("queued", "provider_error", 1, 1)
    assert traffic.requests == ["youtube"]


@pytest.mark.parametrize("kind,point", [
    ("youtube", "claim"), ("youtube", "send"), ("instagram", "send"),
])
async def test_consent_read_failure_preserves_consent_and_uses_worker_retry_contract(
    independent_api, worker_context, traffic, monkeypatch, kind, point,
):
    api, headers, user_id, sessions, _, _ = independent_api
    await decide(api, headers, "granted")
    content_id = await save(api, headers, kind)
    read_consent = ai_consent.read_consent

    async def broken_read(session, *args, **kwargs):
        await session.execute(text("SELECT 1/0"))

    async with worker_context() as worker:
        if point == "claim":
            with monkeypatch.context() as injection:
                injection.setattr(ai_consent, "read_consent", broken_read)
                with pytest.raises(DBAPIError, match="division by zero"):
                    await worker.run_once()
            job, count = await state(sessions, content_id)
            assert (job.status, job.attempts, job.error_code, job.lease_token, count) == (
                "queued", 0, None, None, 1,
            )
        else:
            monkeypatch.setattr(ai_consent, "summary_send_allowed", broken_read)
            start = datetime.now(UTC)
            assert await worker.run_once()
            job, count = await state(sessions, content_id)
            assert (job.status, job.attempts, job.error_code, job.lease_token, count) == (
                "queued", 1, "provider_error", None, 1,
            )
            assert start <= job.next_run_at - timedelta(seconds=30) <= datetime.now(UTC)
            await due(sessions, content_id, next_run_at=just_passed())
            assert await worker.run_once()
            job, count = await state(sessions, content_id)
            assert (job.status, job.attempts, job.error_code, job.lease_token, count) == (
                "failed", 2, "provider_error", None, 0,
            )
    public = ["youtube"] if kind == "youtube" else ["instagram", "image"]
    assert traffic.requests == ([] if point == "claim" else public * 2)
    async with sessions() as session:
        _, record = await read_consent(session, user_id)
    assert record.status == "granted"


async def test_g5_asyncpg_connection_failure_is_retryable(
    independent_api, worker_context, traffic, monkeypatch,
):
    api, headers, _, sessions, _, _ = independent_api
    content_id = await save(api, headers, "youtube")
    read = ai_consent.summary_send_allowed
    failures = []
    with socket.socket() as endpoint:
        endpoint.bind(("127.0.0.1", 0))
        host, port = endpoint.getsockname()

        async def connect():
            return await asyncpg.connect(host=host, port=port, timeout=2)

        engine = create_async_engine("postgresql+asyncpg://", async_creator=connect)
        try:
            async def read_from_refused_connection(session, **kwargs):
                try:
                    async with async_sessionmaker(engine)() as broken:
                        return await read(broken, **kwargs)
                except (ConnectionRefusedError, TimeoutError) as exc:
                    failures.append(type(exc).__name__)
                    raise

            monkeypatch.setattr(ai_consent, "summary_send_allowed", read_from_refused_connection)
            async with worker_context() as worker:
                assert await worker.run_once()
        finally:
            await engine.dispose()
    assert len(failures) == 1
    assert traffic.requests == ["youtube"]
    job, count = await state(sessions, content_id)
    assert (job.status, job.error_code, job.attempts, count) == (
        "queued", "provider_error", 1, 1,
    )


async def test_cancelling_g5_propagates_without_finishing_the_job(
    independent_api, worker_context, traffic, monkeypatch,
):
    api, headers, _, sessions, _, _ = independent_api
    content_id = await save(api, headers, "instagram")
    entered, resume = asyncio.Event(), asyncio.Event()

    async def waiting_read(session, **kwargs):
        await session.execute(text("SELECT 1"))
        entered.set()
        await resume.wait()
        raise AssertionError("cancelled attempt resumed")

    monkeypatch.setattr(ai_consent, "summary_send_allowed", waiting_read)
    async with worker_context() as worker, asyncio.TaskGroup() as tasks:
        run = tasks.create_task(worker.run_once())
        try:
            await asyncio.wait_for(entered.wait(), 5)
        finally:
            run.cancel()
        with pytest.raises(asyncio.CancelledError):
            await run
    assert traffic.requests == ["instagram", "image"]
    job, count = await state(sessions, content_id)
    assert (job.status, job.error_code, job.attempts, count) == ("processing", None, 1, 1)
    assert job.lease_token


@pytest.mark.parametrize("kind", list(LINKS))
async def test_uncommitted_g3_job_missed_by_withdrawal_is_cancelled_at_claim(
    independent_api, worker_context, traffic, monkeypatch, kind,
):
    api, headers, user_id, sessions, pids, _ = independent_api
    await decide(api, headers, "granted")
    create_event = EventRepository.create
    denials = []

    async def withdraw_before_save_commit(repository, **kwargs):
        result = await create_event(repository, **kwargs)
        await repository.session.flush()
        pending = await repository.session.get(SummaryJob, kwargs["content_id"])
        assert pending.status == "queued"
        save_pid = await backend_pid(repository.session)
        async with sessions() as observer:
            assert await observer.get(SummaryJob, pending.content_id) is None
        denials.append(await decide(api, headers, "denied"))
        assert pids[-1] != save_pid
        return result

    with monkeypatch.context() as pause:
        pause.setattr(EventRepository, "create", withdraw_before_save_commit)
        content_id = await save(api, headers, kind)
    job, count = await state(sessions, content_id)
    assert (job.status, count) == ("queued", 1)
    repeated = await decide(api, headers, "denied")
    assert denials == [repeated]
    async with sessions() as session:
        _, denial = await ai_consent.read_consent(session, user_id)
    assert datetime.fromisoformat(repeated["decided_at"]) == denial.decided_at
    assert (await state(sessions, content_id))[0].status == "queued"

    await decide(api, headers, "granted")
    async with worker_context() as worker:
        assert not await worker.run_once()
    assert traffic.requests == []
    job, count = await state(sessions, content_id)
    assert (job.status, job.error_code, job.attempts, count) == ("skipped", SKIPPED, 0, 0)


async def test_g5_sees_the_denial_while_regrant_has_written_but_not_committed(
    independent_api, worker_context, traffic, monkeypatch,
):
    api, headers, user_id, sessions, pids, _ = independent_api
    await decide(api, headers, "granted")
    content_id = await save(api, headers, "youtube")
    async with sessions() as writer, worker_context() as worker:
        regrant = []
        commit = writer.commit

        async def hold_commit():
            pass

        async def withdraw_and_write_regrant(stage):
            assert stage == "youtube"
            writer_pid = await backend_pid(writer)
            await decide(api, headers, "denied")
            assert pids[-1] != writer_pid
            async with worker.sessions() as reader:
                assert await backend_pid(reader) != writer_pid
            with monkeypatch.context() as pause:
                pause.setattr(writer, "commit", hold_commit)
                regrant.append(await ai_consent.decide(writer, user_id, status="granted"))
            assert writer.in_transaction() and await backend_pid(writer) == writer_pid

        traffic.before_public_answer = withdraw_and_write_regrant
        assert await worker.run_once()
        (pending,) = regrant
        assert pending.granted_after_denial
        async with sessions() as reader:
            _, still_denied = await ai_consent.read_consent(reader, user_id)
        assert still_denied.status == "denied"
        await commit()
        async with sessions() as reader:
            _, committed = await ai_consent.read_consent(reader, user_id)
        assert committed == pending
    job, count = await state(sessions, content_id)
    assert (job.status, job.error_code, job.attempts, count) == ("skipped", SKIPPED, 1, 0)
    assert traffic.requests == ["youtube"]


async def test_disabled_kind_stays_unclaimed_and_withdrawal_still_cancels(
    independent_api, worker_context, traffic, monkeypatch,
):
    api, headers, _, sessions, _, _ = independent_api
    content_id = await save(api, headers, "youtube")
    monkeypatch.setattr(settings, "youtube_summary_enabled", False)
    async with worker_context() as worker:
        assert not await worker.run_once()
        job, count = await state(sessions, content_id)
        assert (job.status, job.attempts, count) == ("queued", 0, 1)
        await decide(api, headers, "denied")
        await decide(api, headers, "granted")
        monkeypatch.setattr(settings, "youtube_summary_enabled", True)
        assert not await worker.run_once()
    job, count = await state(sessions, content_id)
    assert (job.status, job.error_code, job.attempts, count) == ("skipped", SKIPPED, 0, 0)
    assert traffic.requests == []


@pytest.mark.parametrize("claim_first", [False, True])
async def test_transition_queue_is_available_at_first_grant_unless_switch_already_skipped_it(
    independent_api, worker_context, traffic, monkeypatch, claim_first,
):
    api, headers, _, sessions, _, _ = independent_api
    content_id = await save(api, headers, "instagram")
    monkeypatch.setattr(settings, "ai_consent_required", True)
    async with worker_context() as worker:
        if claim_first:
            assert not await worker.run_once()
            assert traffic.requests == []
        await decide(api, headers, "granted")
        assert await worker.run_once() is not claim_first
    job, count = await state(sessions, content_id)
    if claim_first:
        assert (job.status, job.error_code, job.attempts, count) == ("skipped", SKIPPED, 0, 0)
        assert traffic.requests == []
    else:
        assert (job.status, job.error_code, job.attempts, count) == ("completed", None, 1, 1)
        assert traffic.requests == ["instagram", "image", "openai"]


@pytest.mark.parametrize("kind", ["youtube", "instagram", "photo"])
async def test_required_switch_blocks_undecided_saves_without_retroactive_ai(
    independent_api, worker_context, traffic, monkeypatch, kind, png_bytes, external_responses,
):
    api, headers, _, sessions, _, _ = independent_api
    monkeypatch.setattr(settings, "ai_consent_required", True)
    ocr_calls = []

    async def record_ocr(*args, **kwargs):
        ocr_calls.append(True)
        raise AssertionError("unexpected OCR")

    monkeypatch.setattr(OCRClient, "extract", record_ocr)
    content = await save_input(api, headers, kind, png_bytes)
    assert (content["summary_status"], content["summary_error_code"]) == ("skipped", SKIPPED)
    await decide(api, headers, "granted")
    async with worker_context() as worker:
        assert not await worker.run_once()
    detail = await request(api, "GET", f"contents/{content['id']}", headers=headers)
    assert (detail["summary_status"], detail["summary_error_code"]) == ("skipped", SKIPPED)
    _, count = await state(sessions, content["id"])
    assert count == len(ocr_calls) == len(traffic.requests) == external_responses.ai_calls == 0


@pytest.mark.parametrize("kind", ["youtube", "instagram", "photo", "web"])
@pytest.mark.parametrize("regrant_before_start", [False, True])
async def test_save_judgments_use_the_same_transaction_start_as_saved_at(
    independent_api, recommendation_provider, worker_context, traffic, monkeypatch,
    png_bytes, kind, regrant_before_start,
):
    api, headers, user_id, sessions, pids, _ = independent_api
    await decide(api, headers, "granted")
    await decide(api, headers, "denied")
    decisions, judgments = [], []
    if regrant_before_start:
        decisions.append(await decide(api, headers, "granted"))
    allows = ai_consent.SaveAIConsent.allows

    async def observe(guard, user):
        assert user == user_id and guard.session.in_transaction()
        began_at = await guard.session.scalar(text("SELECT transaction_timestamp()"))
        if not judgments and not regrant_before_start:
            save_pid = await backend_pid(guard.session)
            decisions.append(await asyncio.wait_for(decide(api, headers, "granted"), 5))
            assert pids[-1] != save_pid
        allowed = await allows(guard, user)
        judgments.append((began_at, guard.started_at, allowed))
        return allowed

    with monkeypatch.context() as inject:
        inject.setattr(ai_consent.SaveAIConsent, "allows", observe)
        key = str(uuid4())
        if kind in LINKS:
            saved = await request(
                api, "POST", "contents", headers={**headers, "Idempotency-Key": key},
                status=201, json={"original_url": LINKS[kind]},
            )
        else:
            saved = await save_input(api, headers, kind, png_bytes, key=key)
    (decision,) = decisions
    regranted_at = datetime.fromisoformat(decision["decided_at"])
    async with sessions() as session:
        saved_at = await session.scalar(
            select(Content.saved_at).where(Content.id == saved["id"]),
        )
    assert (saved_at > regranted_at) is regrant_before_start
    assert saved_at != regranted_at
    expected_status = {
        "youtube": "queued", "instagram": "queued", "photo": "not_requested",
        "web": "not_requested",
    }[kind] if regrant_before_start else ("not_requested" if kind == "web" else "skipped")
    expected_reason = SKIPPED if expected_status == "skipped" else None
    assert (saved["summary_status"], saved["summary_error_code"]) == (
        expected_status, expected_reason,
    )
    expected_checks = {
        "youtube": 1, "instagram": 3 if regrant_before_start else 2,
        "photo": 4 if regrant_before_start else 1, "web": 2 if regrant_before_start else 1,
    }[kind]
    assert judgments == [(saved_at, saved_at, regrant_before_start)] * expected_checks
    expected_calls = {
        "youtube": [], "instagram": ["recommend"], "photo": ["ocr", "recommend"],
        "web": ["recommend"],
    }[kind] if regrant_before_start else []
    assert recommendation_provider.calls == expected_calls
    if kind != "youtube":
        assert await usage(sessions, user_id, "category_recommendation") == (
            expected_calls.count("recommend")
        )
    if kind != "web":
        assert await usage(sessions, user_id, "ai_summary") == int(regrant_before_start)
    if kind in LINKS:
        async with worker_context() as worker:
            assert await worker.run_once() is regrant_before_start
        job, count = await state(sessions, saved["id"])
        assert (job.status, job.error_code, count) == (
            "completed" if regrant_before_start else "skipped", expected_reason,
            int(regrant_before_start),
        )
        sends = ["youtube", "gemini"] if kind == "youtube" else ["instagram", "image", "openai"]
        assert traffic.requests == (sends if regrant_before_start else [])
