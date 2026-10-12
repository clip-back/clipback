import asyncio
import os
from uuid import uuid4

import httpx
import pytest
import pytest_asyncio
from sqlalchemy import delete, func, select, text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.config import settings
from app.db.session import get_db
from app.integrations.metadata_client import MetadataClient
from app.integrations.ocr_client import OCRClient
from app.main import create_app
from app.models.category import Category
from app.models.content import Content
from app.models.content_asset import ContentAsset
from app.models.content_event import ContentEvent
from app.models.share_receipt import ShareReceipt
from app.models.summary_job import SummaryJob
from app.models.user import User
from app.repositories.event_repository import EventRepository
from app.repositories.share_receipt_repository import ShareReceiptRepository
from tests.integration.helpers import guest, request

pytestmark = pytest.mark.asyncio


@pytest_asyncio.fixture
async def independent_api(external_responses, monkeypatch, tmp_path):
    url = os.environ.get("TEST_DATABASE_URL")
    if not url:
        pytest.skip("TEST_DATABASE_URL is required for PostgreSQL tests")
    engine = create_async_engine(url)
    sessions = async_sessionmaker(engine, expire_on_commit=False)
    app = create_app()
    user_ids = []
    pids = []
    monkeypatch.setattr(settings, "storage_root", tmp_path)

    async def db():
        async with sessions() as session:
            pids.append(await session.scalar(text("SELECT pg_backend_pid()")))
            yield session

    app.dependency_overrides[get_db] = db
    try:
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app, raise_app_exceptions=False),
            base_url="http://test",
        ) as api:
            headers, _, user = await guest(api)
            user_ids.append(user["id"])
            yield api, headers, user["id"], sessions, pids, tmp_path
    finally:
        async with sessions() as session:
            for model in (ContentEvent, Content, Category):
                await session.execute(delete(model).where(model.user_id.in_(user_ids)))
            await session.execute(delete(User).where(User.id.in_(user_ids)))
            await session.commit()
        await engine.dispose()


@pytest.mark.parametrize("kind", ["instagram", "youtube", "screenshot"])
async def test_concurrent_shares_serialize_before_external_work(
    independent_api, png_bytes, monkeypatch, kind,
):
    api, headers, user_id, sessions, pids, path = independent_api
    entered, release, second_lock = asyncio.Event(), asyncio.Event(), asyncio.Event()
    calls = []
    lock_calls = 0
    original_lock = ShareReceiptRepository.lock

    async def lock(self, user_id, key):
        nonlocal lock_calls
        lock_calls += 1
        if lock_calls == 2:
            second_lock.set()
        await original_lock(self, user_id, key)

    monkeypatch.setattr(ShareReceiptRepository, "lock", lock)
    if kind == "screenshot":
        original = OCRClient.extract

        async def external(self, **kwargs):
            calls.append("ocr")
            entered.set()
            await asyncio.wait_for(release.wait(), 10)
            return await original(self, **kwargs)

        monkeypatch.setattr(OCRClient, "extract", external)
    elif kind == "instagram":
        original = MetadataClient.extract_from_url

        async def external(self, url):
            calls.append(url)
            entered.set()
            await asyncio.wait_for(release.wait(), 10)
            return await original(self, url)

        monkeypatch.setattr(MetadataClient, "extract_from_url", external)
    else:
        original = EventRepository.create

        async def external(self, **kwargs):
            calls.append("event")
            entered.set()
            await asyncio.wait_for(release.wait(), 10)
            return await original(self, **kwargs)

        monkeypatch.setattr(EventRepository, "create", external)
    headers = {**headers, "Idempotency-Key": str(uuid4())}
    endpoint = "uploads/screenshots" if kind == "screenshot" else "contents/share"
    payload = ({"files": {"file": ("image.png", png_bytes, "image/png")}}
               if kind == "screenshot" else {"json": {"url": (
                   "https://www.instagram.com/p/example/" if kind == "instagram"
                   else "https://youtu.be/dQw4w9WgXcQ")}})
    tasks = []
    try:
        tasks.append(asyncio.create_task(request(api, "POST", endpoint, status=201,
                                                 headers=headers, **payload)))
        await asyncio.wait_for(entered.wait(), 10)
        tasks.append(asyncio.create_task(request(api, "POST", endpoint, status=201,
                                                 headers=headers, **payload)))
        await asyncio.wait_for(second_lock.wait(), 10)
        assert pids[-1] != pids[-2]  # Real independent PostgreSQL connections.
        assert len(calls) == 1 and not tasks[1].done()
        release.set()
        first, second = await asyncio.wait_for(asyncio.gather(*tasks), 10)
        assert first == second and len(calls) == 1
        # Lost HTTP response is retried without repeating OCR/metadata, file or DB writes.
        assert await request(api, "POST", endpoint, status=201,
                             headers=headers, **payload) == first
        assert len(calls) == 1
        async with sessions() as session:
            for model in (Content, ContentEvent, ShareReceipt):
                assert await session.scalar(select(func.count()).select_from(model).where(
                    model.user_id == user_id,
                )) == 1
            assert await session.scalar(select(func.count()).select_from(SummaryJob).where(
                SummaryJob.content_id == first["id"],
            )) == (1 if kind == "youtube" else 0)
            assert await session.scalar(select(func.count()).select_from(ContentAsset).where(
                ContentAsset.content_id == first["id"],
            )) == (1 if kind == "screenshot" else 0)
        assert len(list(path.rglob("*.png"))) == (1 if kind == "screenshot" else 0)
    finally:
        release.set()
        await asyncio.gather(*tasks, return_exceptions=True)


@pytest.mark.parametrize("failure", ["before_commit", "commit_rejected", "commit_ack_lost"])
async def test_screenshot_retry_and_cleanup_follow_actual_commit(
    independent_api, png_bytes, monkeypatch, failure,
):
    api, headers, user_id, sessions, _, path = independent_api
    headers = {**headers, "Idempotency-Key": str(uuid4())}
    payload = {"files": {"file": ("image.png", png_bytes, "image/png")}}
    armed = True
    if failure == "before_commit":
        original = EventRepository.create

        async def fail(self, **kwargs):
            nonlocal armed
            if armed:
                armed = False
                raise RuntimeError("injected event write failure")
            return await original(self, **kwargs)

        monkeypatch.setattr(EventRepository, "create", fail)
    else:
        original = AsyncSession.commit

        async def fail(self):
            nonlocal armed
            if armed:
                armed = False
                if failure == "commit_ack_lost":
                    await original(self)
                raise ConnectionError("injected commit acknowledgement failure")
            return await original(self)

        monkeypatch.setattr(AsyncSession, "commit", fail)
    failed = await api.post("/api/v1/uploads/screenshots", headers=headers, **payload)
    assert failed.status_code == 500
    files = list(path.rglob("*.png"))
    assert len(files) == (1 if failure == "commit_ack_lost" else 0)
    first = await request(api, "POST", "uploads/screenshots", status=201,
                          headers=headers, **payload)
    assert len(list(path.rglob("*.png"))) == 1
    if files:
        assert list(path.rglob("*.png")) == files
    async with sessions() as session:
        assert await session.scalar(select(func.count()).select_from(ShareReceipt).where(
            ShareReceipt.user_id == user_id,
        )) == 1
        assert await session.scalar(select(func.count()).select_from(ContentEvent).where(
            ContentEvent.user_id == user_id,
        )) == 1
    await request(api, "POST", "uploads/screenshots", status=409, headers=headers,
                  files={"file": ("changed.png", png_bytes + b"changed", "image/png")})
    await request(api, "POST", "contents/share", status=409, headers=headers,
                  json={"url": "https://youtu.be/dQw4w9WgXcQ"})
    await request(api, "DELETE", f"contents/{first['id']}", status=204, headers=headers)
    await request(api, "POST", "uploads/screenshots", status=410, headers=headers, **payload)
    assert not list(path.rglob("*.png"))


async def test_main_refresh_does_not_deadlock_native_share(independent_api):
    api, _, _, sessions, _, _ = independent_api
    # A second session for the same test user is not required: this is the exact
    # parent session minted by the main app and rotated during a native save.
    from app.api.v1.endpoints.auth import _build_auth_service

    async with sessions() as session:
        tokens = await _build_auth_service(session).create_guest_session()
    # Register the separate disposable guest for teardown through explicit cleanup.
    from app.core.security import decode_access_token

    native_user = decode_access_token(tokens.access_token).user_id
    try:
        native_headers = {"Authorization": f"Bearer {tokens.access_token}"}
        credential = await request(api, "POST", "auth/share-credential", headers=native_headers)
        share_headers = {"Authorization": f"Bearer {credential['share_token']}",
                         "Idempotency-Key": str(uuid4())}
        saved, rotated = await asyncio.wait_for(asyncio.gather(
            request(api, "POST", "contents/share", status=201, headers=share_headers,
                    json={"url": "https://youtu.be/dQw4w9WgXcQ"}),
            request(api, "POST", "auth/refresh", json={"refresh_token": tokens.refresh_token}),
        ), 10)
        assert saved["id"] > 0
        assert (await request(api, "GET", "users/me", headers={
            "Authorization": f"Bearer {rotated['access_token']}",
        }))["id"] == native_user
        await request(api, "POST", "auth/logout", status=204,
                      json={"refresh_token": rotated["refresh_token"]})
        await request(api, "POST", "contents/share", status=401, headers=share_headers,
                      json={"url": "https://youtu.be/dQw4w9WgXcQ"})
    finally:
        async with sessions() as session:
            for model in (ContentEvent, Content, Category):
                await session.execute(delete(model).where(model.user_id == native_user))
            await session.execute(delete(User).where(User.id == native_user))
            await session.commit()


async def test_image_file_failure_retries_same_key_without_receipt(independent_api,
                                                                  png_bytes, monkeypatch):
    from app.integrations.storage_client import LocalStorageClient

    api, headers, user_id, sessions, _, path = independent_api
    headers = {**headers, "Idempotency-Key": str(uuid4())}
    original = LocalStorageClient.save_file
    armed = True

    async def fail(self, key, data):
        nonlocal armed
        if armed:
            armed = False
            raise OSError("injected storage failure")
        await original(self, key, data)

    monkeypatch.setattr(LocalStorageClient, "save_file", fail)
    payload = {"files": {"file": ("image.png", png_bytes, "image/png")}}
    failed = await api.post("/api/v1/uploads/screenshots", headers=headers, **payload)
    assert failed.status_code == 500 and not list(path.rglob("*.png"))
    async with sessions() as session:
        assert await session.scalar(select(func.count()).select_from(ShareReceipt).where(
            ShareReceipt.user_id == user_id,
        )) == 0
    await request(api, "POST", "uploads/screenshots", status=201, headers=headers, **payload)
    assert len(list(path.rglob("*.png"))) == 1


async def test_retry_winning_before_commit_verification_cleans_only_failed_attempt(
    independent_api, png_bytes, monkeypatch,
):
    api, headers, _, _, _, path = independent_api
    headers = {**headers, "Idempotency-Key": str(uuid4())}
    payload = {"files": {"file": ("image.png", png_bytes, "image/png")}}
    verification_entered, allow_verification = asyncio.Event(), asyncio.Event()
    original_commit = AsyncSession.commit
    original_verify = ShareReceiptRepository.committed_after_failure
    armed = True

    async def reject_once(self):
        nonlocal armed
        if armed:
            armed = False
            raise ConnectionError("injected rejected commit")
        await original_commit(self)

    async def wait_before_verify(self, pending):
        verification_entered.set()
        await asyncio.wait_for(allow_verification.wait(), 10)
        return await original_verify(self, pending)

    monkeypatch.setattr(AsyncSession, "commit", reject_once)
    monkeypatch.setattr(ShareReceiptRepository, "committed_after_failure", wait_before_verify)
    failed = asyncio.create_task(
        api.post("/api/v1/uploads/screenshots", headers=headers, **payload),
    )
    try:
        await asyncio.wait_for(verification_entered.wait(), 10)
        failed_files = set(path.rglob("*.png"))
        assert len(failed_files) == 1
        succeeded = await request(api, "POST", "uploads/screenshots", status=201,
                                  headers=headers, **payload)
        assert len(list(path.rglob("*.png"))) == 2
        allow_verification.set()
        assert (await asyncio.wait_for(failed, 10)).status_code == 500
        remaining = set(path.rglob("*.png"))
        assert len(remaining) == 1 and remaining.isdisjoint(failed_files)
        assert (await request(api, "POST", "uploads/screenshots", status=201,
                              headers=headers, **payload))["id"] == succeeded["id"]
    finally:
        allow_verification.set()
        await asyncio.gather(failed, return_exceptions=True)
