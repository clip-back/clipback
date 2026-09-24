import asyncio
import os
import random
from datetime import UTC, datetime, timedelta
from uuid import uuid4

import pytest
import pytest_asyncio
from sqlalchemy import delete, func, select, text
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.models.category import Category
from app.models.content import Content, ContentSource, ContentType
from app.models.content_event import ContentEvent
from app.models.recommendation import (
    RecommendationBatch,
    RecommendationBatchItem,
    RecommendationExposure,
    RecommendationType,
)
from app.models.user import User
from app.repositories.category_repository import CategoryRepository
from app.repositories.content_repository import ContentRepository
from app.repositories.event_repository import EventRepository
from app.repositories.recommendation_repository import RecommendationRepository
from app.repositories.user_repository import UserRepository
from app.schemas.content import ContentCategoryUpdate, ContentViewCreate
from app.services.content_service import ContentService
from app.services.recommendation_service import RecommendationService
from tests.repositories.test_tag_concurrency import wait_for_block_or_completion
from tests.repositories.test_view_concurrency import stop_tasks

pytestmark = pytest.mark.asyncio
NOW = datetime(2026, 9, 25, 6, tzinfo=UTC)


@pytest_asyncio.fixture
async def today_data():
    url = os.environ.get("TEST_DATABASE_URL")
    if not url:
        pytest.skip("TEST_DATABASE_URL is required for PostgreSQL repository tests")
    engine = create_async_engine(url)
    sessions = async_sessionmaker(engine, expire_on_commit=False)
    user_ids, category_ids, content_ids = [], [], []
    try:
        async with sessions() as session:
            for _ in range(2):
                user = await UserRepository(session).create_guest()
                user_ids.append(user.id)
                categories = await CategoryRepository(session).list_recommendation_candidates(
                    user.id
                )
                contents = [
                    Content(
                        user_id=user.id,
                        title=f"Concurrent today {index}",
                        summary="",
                        content_type=ContentType.LINK,
                        source=ContentSource.WEB,
                        saved_at=NOW - timedelta(days=3, minutes=index),
                        categories=categories[:2],
                    )
                    for index in range(5)
                ]
                session.add_all(contents)
                await session.flush()
                category_ids.append([category.id for category in categories])
                content_ids.append([content.id for content in contents])
            await session.commit()
        yield sessions, user_ids, category_ids, content_ids
    finally:
        if user_ids:
            async with sessions() as session:
                # Only these fixtures' committed rows, never shared-table resets.
                await session.execute(
                    delete(ContentEvent).where(ContentEvent.user_id.in_(user_ids))
                )
                await session.execute(
                    delete(RecommendationExposure).where(
                        RecommendationExposure.user_id.in_(user_ids)
                    )
                )
                batches = select(RecommendationBatch.id).where(
                    RecommendationBatch.user_id.in_(user_ids)
                )
                await session.execute(
                    delete(RecommendationBatchItem).where(
                        RecommendationBatchItem.batch_id.in_(batches)
                    )
                )
                await session.execute(
                    delete(RecommendationBatch).where(RecommendationBatch.user_id.in_(user_ids))
                )
                await session.execute(delete(Content).where(Content.user_id.in_(user_ids)))
                await session.execute(delete(Category).where(Category.user_id.in_(user_ids)))
                await session.execute(delete(User).where(User.id.in_(user_ids)))
                await session.commit()
        await engine.dispose()


def today_service(session, clock=None):
    return RecommendationService(
        content_repository=ContentRepository(session),
        recommendation_repository=RecommendationRepository(session),
        clock=clock or (lambda: NOW),
        rng=random.Random(41),
    )


def content_service(session):
    return ContentService(
        content_repository=ContentRepository(session),
        category_repository=CategoryRepository(session),
        event_repository=EventRepository(session),
    )


async def assert_single_batch(sessions, user_id, expected_count=5):
    async with sessions() as session:
        batches = list(
            await session.scalars(
                select(RecommendationBatch).where(RecommendationBatch.user_id == user_id)
            )
        )
        assert len(batches) == 1
        items = list(
            await session.scalars(
                select(RecommendationBatchItem)
                .where(RecommendationBatchItem.batch_id == batches[0].id)
                .order_by(RecommendationBatchItem.rank)
            )
        )
        assert len(items) == expected_count
        assert [item.rank for item in items] == list(range(1, expected_count + 1))
        assert len({item.target_id_snapshot for item in items}) == expected_count
        assert await session.scalar(
            select(func.count(RecommendationExposure.id)).where(
                RecommendationExposure.user_id == user_id
            )
        ) == 0
        contents = list(await session.scalars(select(Content).where(Content.user_id == user_id)))
        assert all(content.recommendation_count == 0 for content in contents)
        assert all(content.last_recommended_at is None for content in contents)
        assert all(content.last_recommended_surface is None for content in contents)
        return batches[0], items


async def test_same_user_requests_wait_and_reuse_one_complete_batch(today_data, monkeypatch):
    sessions, user_ids, _, _ = today_data
    uid = user_ids[0]
    locked, release = asyncio.Event(), asyncio.Event()
    original = RecommendationRepository.lock_user
    async with sessions() as first, sessions() as second:
        first_pid = await first.scalar(text("SELECT pg_backend_pid()"))
        second_pid = await second.scalar(text("SELECT pg_backend_pid()"))
        assert first_pid != second_pid

        async def lock(self, user_id):
            await original(self, user_id)
            if self.session is first:
                locked.set()
                await asyncio.wait_for(release.wait(), 10)

        monkeypatch.setattr(RecommendationRepository, "lock_user", lock)
        tasks = [asyncio.create_task(today_service(first).read_today(uid))]
        try:
            await asyncio.wait_for(locked.wait(), 10)
            tasks.append(asyncio.create_task(today_service(second).read_today(uid)))
            assert await wait_for_block_or_completion(sessions, tasks[1], second_pid, first_pid)
            release.set()
            results = await asyncio.wait_for(asyncio.gather(*tasks), 10)
            assert results[0] == results[1]
            assert not first.in_transaction() and not second.in_transaction()
        finally:
            await stop_tasks(tasks, release)
    batch, _ = await assert_single_batch(sessions, uid)
    assert batch.id == results[0].batch_id


async def test_other_user_today_is_not_blocked(today_data, monkeypatch):
    sessions, user_ids, _, _ = today_data
    locked, release = asyncio.Event(), asyncio.Event()
    original = RecommendationRepository.lock_user
    async with sessions() as first, sessions() as second:

        async def lock(self, user_id):
            await original(self, user_id)
            if self.session is first:
                locked.set()
                await asyncio.wait_for(release.wait(), 10)

        monkeypatch.setattr(RecommendationRepository, "lock_user", lock)
        tasks = [asyncio.create_task(today_service(first).read_today(user_ids[0]))]
        try:
            await asyncio.wait_for(locked.wait(), 10)
            other = await asyncio.wait_for(today_service(second).read_today(user_ids[1]), 10)
            assert other.batch_id is not None
            assert not tasks[0].done()
            release.set()
            await asyncio.wait_for(tasks[0], 10)
        finally:
            await stop_tasks(tasks, release)
    for uid in user_ids:
        await assert_single_batch(sessions, uid)


async def test_existing_batch_does_not_lock_unselected_content(today_data):
    sessions, user_ids, _, _ = today_data
    uid = user_ids[0]
    async with sessions() as setup:
        original = await today_service(setup).read_today(uid)
        unselected = Content(
            user_id=uid,
            title="Saved after the daily batch",
            summary="",
            content_type=ContentType.LINK,
            source=ContentSource.WEB,
            saved_at=NOW,
        )
        setup.add(unselected)
        await setup.commit()
        unselected_id = unselected.id
    async with sessions() as writer, sessions() as reading:
        await ContentRepository(writer).get_owned(
            user_id=uid, content_id=unselected_id, for_update=True
        )
        response = await asyncio.wait_for(today_service(reading).read_today(uid), 10)
        assert response == original
        assert writer.in_transaction()
        assert not reading.in_transaction()
    await assert_single_batch(sessions, uid)


@pytest.mark.parametrize("failure", ["batch", "items", "commit"])
async def test_failed_generation_rolls_back_and_waiter_creates_complete_batch(
    today_data, monkeypatch, failure
):
    sessions, user_ids, _, _ = today_data
    uid = user_ids[0]
    staged, release = asyncio.Event(), asyncio.Event()
    original_create = RecommendationRepository.create_today_batch
    async with sessions() as first, sessions() as second:
        first_pid = await first.scalar(text("SELECT pg_backend_pid()"))
        second_pid = await second.scalar(text("SELECT pg_backend_pid()"))

        async def fail():
            staged.set()
            await asyncio.wait_for(release.wait(), 10)
            raise RuntimeError(f"injected today {failure} failure")

        async def create(self, **kwargs):
            if self.session is first and failure == "batch":
                self.session.add(
                    RecommendationBatch(
                        user_id=kwargs["user_id"],
                        type=RecommendationType.TODAY,
                        recommendation_date=kwargs["recommendation_date"],
                        generated_at=kwargs["generated_at"],
                    )
                )
                await self.session.flush()
                await fail()
            if self.session is first and failure == "items":
                await original_create(self, **{**kwargs, "selections": kwargs["selections"][:1]})
                await fail()
            return await original_create(self, **kwargs)

        monkeypatch.setattr(RecommendationRepository, "create_today_batch", create)
        if failure == "commit":
            monkeypatch.setattr(first, "commit", fail)
        tasks = [asyncio.create_task(today_service(first).read_today(uid))]
        try:
            await asyncio.wait_for(staged.wait(), 10)
            tasks.append(asyncio.create_task(today_service(second).read_today(uid)))
            assert await wait_for_block_or_completion(sessions, tasks[1], second_pid, first_pid)
            release.set()
            results = await asyncio.wait_for(asyncio.gather(*tasks, return_exceptions=True), 10)
            assert isinstance(results[0], RuntimeError)
            assert str(results[0]) == f"injected today {failure} failure"
            assert results[1].batch_id is not None
            assert not first.in_transaction() and not second.in_transaction()
        finally:
            await stop_tasks(tasks, release)
    batch, _ = await assert_single_batch(sessions, uid)
    assert results[1].batch_id == batch.id


@pytest.mark.parametrize("operation", ["delete", "view", "reclassify"])
@pytest.mark.parametrize("mutation_first", [True, False])
async def test_candidates_follow_content_lock_order(
    today_data, monkeypatch, operation, mutation_first
):
    sessions, user_ids, category_ids, content_ids = today_data
    uid, cid = user_ids[0], content_ids[0][0]
    locked, release = asyncio.Event(), asyncio.Event()
    original_candidates = ContentRepository.list_today_candidates_for_share
    snapshots = []
    async with sessions() as reading, sessions() as mutating:
        # A cached ORM relationship must not leak into the fresh locked snapshot.
        cached = await ContentRepository(reading).get_owned(user_id=uid, content_id=cid)
        assert sorted(category.id for category in cached.categories) == category_ids[0][:2]
        first_session = mutating if mutation_first else reading
        second_session = reading if mutation_first else mutating
        first_pid = await first_session.scalar(text("SELECT pg_backend_pid()"))
        second_pid = await second_session.scalar(text("SELECT pg_backend_pid()"))
        assert first_pid != second_pid
        original_commit = mutating.commit

        async def candidates(self, user_id):
            result = await original_candidates(self, user_id)
            if self.session is reading:
                snapshots.extend(result)
                if not mutation_first:
                    locked.set()
                    await asyncio.wait_for(release.wait(), 10)
            return result

        async def commit():
            if mutation_first:
                locked.set()
                await asyncio.wait_for(release.wait(), 10)
            await original_commit()

        monkeypatch.setattr(ContentRepository, "list_today_candidates_for_share", candidates)
        monkeypatch.setattr(mutating, "commit", commit)

        async def mutate():
            writer = content_service(mutating)
            if operation == "delete":
                return await writer.delete_content(user_id=uid, content_id=cid)
            if operation == "view":
                return await writer.record_view(
                    uid, cid, ContentViewCreate(client_event_id=uuid4())
                )
            return await writer.update_categories(
                user_id=uid,
                content_id=cid,
                payload=ContentCategoryUpdate(category_ids=[category_ids[0][2]]),
            )

        async def read():
            return await today_service(reading).read_today(uid)

        tasks = [asyncio.create_task(mutate() if mutation_first else read())]
        try:
            await asyncio.wait_for(locked.wait(), 10)
            tasks.append(asyncio.create_task(read() if mutation_first else mutate()))
            assert await wait_for_block_or_completion(sessions, tasks[1], second_pid, first_pid)
            release.set()
            results = await asyncio.wait_for(asyncio.gather(*tasks), 10)
            response = results[1 if mutation_first else 0]
        finally:
            await stop_tasks(tasks, release)
    captured = {candidate.id: candidate for candidate in snapshots}
    if operation == "delete" and mutation_first:
        assert cid not in captured
        assert response.stage == 0 and response.batch_id is None
        async with sessions() as session:
            assert await session.scalar(
                select(func.count(RecommendationBatch.id)).where(RecommendationBatch.user_id == uid)
            ) == 0
        return
    assert set(captured) == set(content_ids[0])
    if operation == "view":
        assert captured[cid].open_count == int(mutation_first)
        assert (captured[cid].last_viewed_at is not None) == mutation_first
    if operation == "reclassify":
        assert set(captured[cid].category_ids) == set(
            [category_ids[0][2]] if mutation_first else category_ids[0][:2]
        )
    _, items = await assert_single_batch(sessions, uid)
    assert {item.target_id_snapshot for item in items} == set(content_ids[0])
    if operation == "delete":
        assert next(item for item in items if item.target_id_snapshot == cid).content_id is None


async def test_midnight_while_waiting_for_content_uses_new_day(today_data):
    sessions, user_ids, _, content_ids = today_data
    uid = user_ids[0]
    clock = [datetime(2026, 9, 25, 14, 59, 59, tzinfo=UTC)]
    async with sessions() as writer, sessions() as reading:
        writer_pid = await writer.scalar(text("SELECT pg_backend_pid()"))
        reading_pid = await reading.scalar(text("SELECT pg_backend_pid()"))
        await ContentRepository(writer).get_owned(
            user_id=uid, content_id=content_ids[0][0], for_update=True
        )
        task = asyncio.create_task(today_service(reading, lambda: clock[0]).read_today(uid))
        try:
            assert await wait_for_block_or_completion(sessions, task, reading_pid, writer_pid)
            clock[0] = datetime(2026, 9, 25, 15, 0, 0, tzinfo=UTC)
            await writer.commit()
            response = await asyncio.wait_for(task, 10)
        finally:
            if not task.done():
                task.cancel()
            await asyncio.gather(task, return_exceptions=True)
    batch, _ = await assert_single_batch(sessions, uid)
    assert batch.recommendation_date.isoformat() == "2026-09-26"
    assert batch.generated_at == clock[0]
    assert response.recommendation_date == batch.recommendation_date


async def test_new_save_after_snapshot_changes_stage_only_on_next_request(today_data, monkeypatch):
    sessions, user_ids, category_ids, _ = today_data
    uid = user_ids[0]
    async with sessions() as setup:
        categories = await CategoryRepository(setup).list_available_by_ids(uid, category_ids[0][:2])
        setup.add_all(
            [
                Content(
                    user_id=uid,
                    title=f"Before snapshot {index}",
                    summary="",
                    content_type=ContentType.LINK,
                    source=ContentSource.WEB,
                    saved_at=NOW - timedelta(days=4, minutes=index),
                    categories=categories,
                )
                for index in range(4)
            ]
        )
        await setup.commit()
    captured, release = asyncio.Event(), asyncio.Event()
    original_candidates = ContentRepository.list_today_candidates_for_share
    async with sessions() as reading, sessions() as saving:

        async def candidates(self, user_id):
            result = await original_candidates(self, user_id)
            if self.session is reading:
                assert len(result) == 9
                captured.set()
                await asyncio.wait_for(release.wait(), 10)
            return result

        monkeypatch.setattr(ContentRepository, "list_today_candidates_for_share", candidates)
        task = asyncio.create_task(today_service(reading).read_today(uid))
        try:
            await asyncio.wait_for(captured.wait(), 10)
            content = Content(
                user_id=uid,
                title="Saved after snapshot",
                summary="",
                content_type=ContentType.LINK,
                source=ContentSource.WEB,
                saved_at=NOW,
            )
            saving.add(content)
            await asyncio.wait_for(saving.commit(), 10)
            assert not task.done(), "A content insert must coexist with the user NO KEY UPDATE lock"
            release.set()
            first = await asyncio.wait_for(task, 10)
            second = await today_service(reading).read_today(uid)
        finally:
            await stop_tasks([task], release)
    batch, items = await assert_single_batch(sessions, uid)
    assert first.stage == 1 and second.stage == 2
    assert first.batch_id == second.batch_id == batch.id
    assert content.id not in {item.target_id_snapshot for item in items}
