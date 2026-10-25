import asyncio
import os
from uuid import uuid4

import httpx
import pytest
import pytest_asyncio
from sqlalchemy import delete, func, select, text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.db.session import get_db
from app.main import create_app
from app.models.category import Category
from app.models.category_submission import CategorySubmission
from app.models.user import User
from tests.integration.helpers import guest, request

pytestmark = pytest.mark.asyncio


@pytest_asyncio.fixture
async def independent_category_api(external_responses):
    url = os.environ.get("TEST_DATABASE_URL")
    if not url:
        pytest.skip("TEST_DATABASE_URL is required for PostgreSQL tests")
    engine = create_async_engine(url)
    sessions = async_sessionmaker(engine, expire_on_commit=False)
    app = create_app()
    user_ids, pids = [], []

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
            yield api, headers, user["id"], sessions, pids
    finally:
        async with sessions() as session:
            await session.execute(delete(Category).where(Category.user_id.in_(user_ids)))
            await session.execute(delete(User).where(User.id.in_(user_ids)))
            await session.commit()
        await engine.dispose()


async def test_same_category_creation_submission_returns_original_result(api):
    headers, _, _ = await guest(api)
    key = str(uuid4())
    writes = {**headers, "Idempotency-Key": key}
    payload = {"name": "다시 확인할 분류", "color": "#68B5FF"}
    first = await request(api, "POST", "categories", headers=writes, json=payload, status=201)
    assert first["submission"] == {"key": key, "status": "succeeded", "replayed": False}
    replay = await request(api, "POST", "categories", headers=writes, json=payload, status=201)
    assert replay == {**first, "submission": {**first["submission"], "replayed": True}}
    listed = await request(api, "GET", "categories", headers=headers)
    assert [item["id"] for item in listed if item["name"] == payload["name"]] == [first["id"]]


async def test_rejected_submission_stays_rejected_after_name_becomes_available(api):
    headers, _, _ = await guest(api)
    payload = {"name": "이미 있는 이름", "color": "#68B5FF"}
    existing = await request(api, "POST", "categories", headers=headers, json=payload, status=201)
    key = str(uuid4())
    writes = {**headers, "Idempotency-Key": key}
    denied = await request(api, "POST", "categories", headers=writes, json=payload, status=409)
    assert denied == {
        "detail": "Category already exists", "code": "category_name_exists",
        "submission": {"key": key, "status": "rejected", "replayed": False},
    }
    await request(api, "PATCH", f"categories/{existing['id']}", headers=headers,
                  json={"name": "다른 이름"})
    replay = await request(api, "POST", "categories", headers=writes, json=payload, status=409)
    assert replay == {**denied, "submission": {**denied["submission"], "replayed": True}}
    separate = await request(api, "POST", "categories", headers={
        **headers, "Idempotency-Key": str(uuid4()),
    }, json=payload, status=201)
    assert separate["id"] != existing["id"]


async def test_submission_key_is_scoped_to_account_and_original_payload(api):
    first_headers, _, _ = await guest(api)
    other_headers, _, _ = await guest(api)
    key = str(uuid4())
    payload = {"name": "같은 제출", "color": "#68B5FF"}
    first = await request(api, "POST", "categories", headers={
        **first_headers, "Idempotency-Key": key,
    }, json=payload, status=201)
    conflict = await request(api, "POST", "categories", headers={
        **first_headers, "Idempotency-Key": key,
    }, json={**payload, "name": "다른 내용"}, status=409)
    assert conflict["code"] == "category_submission_conflict"
    assert "submission" not in conflict
    other = await request(api, "POST", "categories", headers={
        **other_headers, "Idempotency-Key": key,
    }, json=payload, status=201)
    assert other["id"] != first["id"]
    assert other["submission"]["replayed"] is False


async def test_success_receipt_survives_later_edits_and_category_deletion(api):
    headers, _, _ = await guest(api)
    writes = {**headers, "Idempotency-Key": str(uuid4())}
    payload = {"name": "원래 이름", "color": "#68B5FF"}
    first = await request(api, "POST", "categories", headers=writes, json=payload, status=201)
    await request(api, "PATCH", f"categories/{first['id']}", headers=headers,
                  json={"name": "다른 기기의 이름", "color": "#FF6277"})
    replay = await request(api, "POST", "categories", headers=writes, json=payload, status=201)
    assert replay == {**first, "submission": {**first["submission"], "replayed": True}}
    current = await request(api, "GET", "categories", headers=headers)
    assert next(item for item in current if item["id"] == first["id"])["name"] == "다른 기기의 이름"
    await request(api, "DELETE", f"categories/{first['id']}", headers=headers, status=204)
    assert await request(api, "POST", "categories", headers=writes,
                         json=payload, status=201) == replay
    current = await request(api, "GET", "categories", headers=headers)
    assert not any(item["id"] == first["id"] for item in current)


async def test_simultaneous_same_submissions_use_independent_transactions(independent_category_api):
    api, headers, _, _, pids = independent_category_api
    writes = {**headers, "Idempotency-Key": str(uuid4())}
    payload = {"name": "동시에 저장", "color": "#68B5FF"}
    start = len(pids)
    results = await asyncio.wait_for(asyncio.gather(*[
        request(api, "POST", "categories", headers=writes, json=payload, status=201)
        for _ in range(2)
    ]), 10)
    assert len(set(pids[start:])) == 2
    assert results[0]["id"] == results[1]["id"]
    assert sorted(result["submission"]["replayed"] for result in results) == [False, True]
    current = await request(api, "GET", "categories", headers=headers)
    assert [item["id"] for item in current if item["name"] == payload["name"]] == [results[0]["id"]]


@pytest.mark.parametrize("committed", [False, True])
async def test_retry_follows_actual_commit_and_account_deletion_cleans_receipt(
    independent_category_api, monkeypatch, committed,
):
    api, headers, user_id, sessions, _ = independent_category_api
    writes = {**headers, "Idempotency-Key": str(uuid4())}
    payload = {"name": "커밋 응답 유실", "color": "#68B5FF"}
    original = AsyncSession.commit
    armed = True

    async def fail(self):
        nonlocal armed
        if armed:
            armed = False
            if committed:
                await original(self)
            raise ConnectionError("injected commit acknowledgement loss")
        return await original(self)

    monkeypatch.setattr(AsyncSession, "commit", fail)
    response = await api.post("/api/v1/categories", headers=writes, json=payload)
    assert response.status_code == 500
    recovered = await request(api, "POST", "categories", headers=writes, json=payload, status=201)
    assert recovered["submission"]["replayed"] is committed
    current = await request(api, "GET", "categories", headers=headers)
    assert [item["id"] for item in current if item["name"] == payload["name"]] == [recovered["id"]]
    await request(api, "DELETE", f"categories/{recovered['id']}", headers=headers, status=204)
    async with sessions() as session:
        assert await session.scalar(select(func.count()).select_from(CategorySubmission).where(
            CategorySubmission.user_id == user_id,
        )) == 1
        await session.execute(delete(Category).where(Category.user_id == user_id))
        await session.execute(delete(User).where(User.id == user_id))
        await session.commit()
        assert await session.scalar(select(func.count()).select_from(CategorySubmission).where(
            CategorySubmission.user_id == user_id,
        )) == 0
