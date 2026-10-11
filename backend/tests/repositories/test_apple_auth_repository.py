import asyncio
import os
from datetime import UTC, datetime, timedelta
from uuid import uuid4

import pytest
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.models.apple_auth import AppleAuthChallenge
from app.models.user import User
from app.repositories.apple_auth_repository import AppleAuthRepository

pytestmark = pytest.mark.asyncio


def challenge(*, now, purpose="login", user_id=None, expires_at=None):
    return AppleAuthChallenge(
        id=uuid4(),
        nonce_hash="a" * 64,
        purpose=purpose,
        user_id=user_id,
        expires_at=expires_at or now + timedelta(minutes=5),
    )


@pytest.mark.parametrize("wrong_binding", ["purpose", "guest", "anonymous", "id"])
async def test_invalid_binding_does_not_consume_guest_challenge(database_session, wrong_binding):
    user, other = User(display_name="Guest"), User(display_name="Other guest")
    database_session.add_all([user, other])
    await database_session.flush()
    now = datetime.now(UTC)
    item = challenge(now=now, purpose="upgrade", user_id=user.id)
    repository = AppleAuthRepository(database_session)
    await repository.create_challenge(item, now=now)

    invalid = dict(challenge_id=item.id, purpose="upgrade", user_id=user.id, now=now)
    if wrong_binding == "purpose":
        invalid["purpose"] = "login"
    elif wrong_binding == "guest":
        invalid["user_id"] = other.id
    elif wrong_binding == "anonymous":
        invalid["user_id"] = None
    else:
        invalid["challenge_id"] = uuid4()
    assert await repository.consume_challenge(**invalid) is None
    assert await repository.consume_challenge(
        challenge_id=item.id, purpose="upgrade", user_id=user.id, now=now
    ) == item.nonce_hash
    assert await repository.consume_challenge(
        challenge_id=item.id, purpose="upgrade", user_id=user.id, now=now
    ) is None


@pytest.mark.parametrize("elapsed_seconds", [300, 301])
async def test_challenge_is_expired_at_deadline(database_session, elapsed_seconds):
    now = datetime.now(UTC)
    repository = AppleAuthRepository(database_session)
    item = challenge(now=now)
    await repository.create_challenge(item, now=now)
    assert await repository.consume_challenge(
        challenge_id=item.id,
        purpose="login",
        user_id=None,
        now=now + timedelta(seconds=elapsed_seconds),
    ) is None


async def test_new_challenge_cleans_expired_but_preserves_live_attempt(database_session):
    now = datetime.now(UTC)
    expired = challenge(now=now, expires_at=now)
    live = challenge(now=now)
    database_session.add_all([expired, live])
    await database_session.flush()
    repository = AppleAuthRepository(database_session)
    new = challenge(now=now)
    await repository.create_challenge(new, now=now)
    remaining = set(await database_session.scalars(select(AppleAuthChallenge.id)))
    assert expired.id not in remaining
    assert {live.id, new.id} <= remaining


async def test_concurrent_transactions_consume_challenge_once():
    url = os.environ.get("TEST_DATABASE_URL")
    if not url:
        pytest.skip("TEST_DATABASE_URL is required for PostgreSQL tests")
    engine = create_async_engine(url)
    sessions = async_sessionmaker(engine, expire_on_commit=False)
    now = datetime.now(UTC)
    item = challenge(now=now)
    start = asyncio.Event()

    async def consume():
        async with sessions() as session:
            await start.wait()
            result = await AppleAuthRepository(session).consume_challenge(
                challenge_id=item.id, purpose="login", user_id=None, now=now
            )
            await session.commit()
            return result

    tasks = []
    try:
        async with sessions() as session:
            await AppleAuthRepository(session).create_challenge(item, now=now)
            await session.commit()
        tasks = [asyncio.create_task(consume()) for _ in range(4)]
        start.set()
        results = await asyncio.wait_for(asyncio.gather(*tasks), timeout=10)
        assert results.count(item.nonce_hash) == 1
        assert results.count(None) == 3
        async with sessions() as session:
            saved = await session.get(AppleAuthChallenge, item.id)
            assert saved is not None and saved.consumed_at is not None
    finally:
        for task in tasks:
            task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)
        async with sessions() as session:
            await session.execute(
                delete(AppleAuthChallenge).where(AppleAuthChallenge.id == item.id)
            )
            await session.commit()
        await engine.dispose()
