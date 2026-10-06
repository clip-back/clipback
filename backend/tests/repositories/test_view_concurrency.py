import asyncio
import os
from datetime import date
from uuid import uuid4

import pytest
import pytest_asyncio
from sqlalchemy import delete, select, text
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.core.exceptions import InvalidStateError
from app.models.category import Category
from app.models.content import Content, ContentSource, ContentType
from app.models.content_event import ContentEvent, ContentEventType
from app.models.recommendation import (
    RecommendationBatch,
    RecommendationBatchItem,
    RecommendationExposure,
    RecommendationTargetKind,
    RecommendationType,
)
from app.models.user import User
from app.repositories.category_repository import CategoryRepository
from app.repositories.content_repository import ContentRepository
from app.repositories.event_repository import EventRepository
from app.repositories.user_repository import UserRepository
from app.schemas.content import ContentCategoryUpdate, ContentViewCreate
from app.services.category_service import CategoryService
from app.services.content_service import ContentService
from tests.repositories.test_tag_concurrency import wait_for_block_or_completion

pytestmark = pytest.mark.asyncio


@pytest_asyncio.fixture
async def view_data():
    url = os.environ.get("TEST_DATABASE_URL")
    if not url:
        pytest.skip("TEST_DATABASE_URL is required for PostgreSQL repository tests")
    engine = create_async_engine(url)
    sessions = async_sessionmaker(engine, expire_on_commit=False)
    uid = None
    try:
        async with sessions() as session:
            user = await UserRepository(session).create_guest()
            uid = user.id
            categories = await CategoryRepository(session).list_recommendation_candidates(uid)
            contents = [
                Content(
                    user_id=uid,
                    title=f"Concurrent view {index}",
                    summary="",
                    content_type=ContentType.LINK,
                    source=ContentSource.WEB,
                    categories=categories[:2],
                )
                for index in range(2)
            ]
            session.add_all(contents)
            await session.commit()
            yield_data = sessions, uid, [c.id for c in categories], [c.id for c in contents]
        yield yield_data
    finally:
        if uid is not None:
            async with sessions() as session:
                # Delete only rows created by this test, in FK dependency order.
                await session.execute(delete(ContentEvent).where(ContentEvent.user_id == uid))
                await session.execute(
                    delete(RecommendationExposure).where(RecommendationExposure.user_id == uid)
                )
                batches = select(RecommendationBatch.id).where(RecommendationBatch.user_id == uid)
                await session.execute(
                    delete(RecommendationBatchItem).where(
                        RecommendationBatchItem.batch_id.in_(batches)
                    )
                )
                await session.execute(
                    delete(RecommendationBatch).where(RecommendationBatch.user_id == uid)
                )
                await session.execute(delete(Content).where(Content.user_id == uid))
                await session.execute(delete(Category).where(Category.user_id == uid))
                await session.execute(delete(User).where(User.id == uid))
                await session.commit()
        await engine.dispose()


def service(session):
    return ContentService(
        content_repository=ContentRepository(session),
        category_repository=CategoryRepository(session),
        event_repository=EventRepository(session),
    )


async def stop_tasks(tasks, release):
    release.set()
    for task in tasks:
        if not task.done():
            task.cancel()
    await asyncio.gather(*tasks, return_exceptions=True)


async def assert_views(sessions, uid, expected_by_content, expected_ids):
    async with sessions() as session:
        events = list(
            await session.scalars(
                select(ContentEvent).where(
                    ContentEvent.user_id == uid,
                    ContentEvent.event_type == ContentEventType.CONTENT_REOPENED,
                )
            )
        )
        assert len(events) == sum(expected_by_content.values())
        assert {event.client_event_id for event in events} == set(expected_ids)
        for content_id, count in expected_by_content.items():
            content = await session.get(Content, content_id)
            assert content.open_count == count
            matching = [event for event in events if event.content_id == content_id]
            assert len(matching) == count
            assert content.last_viewed_at == max(
                (event.created_at for event in matching), default=None
            )
            assert content.recommendation_count == 0
            assert content.last_recommended_at is None
            assert content.last_recommended_surface is None
        return events


async def create_referral(sessions, uid, content_id):
    async with sessions() as session:
        batch = RecommendationBatch(
            user_id=uid, type=RecommendationType.TODAY, recommendation_date=date(2026, 9, 24)
        )
        session.add(batch)
        await session.flush()
        item = RecommendationBatchItem(
            batch_id=batch.id,
            rank=1,
            target_kind=RecommendationTargetKind.CONTENT,
            target_id_snapshot=content_id,
            content_id=content_id,
        )
        session.add(item)
        await session.commit()
        return item.id


@pytest.mark.parametrize("case", ["retry", "new_entry", "different_referral"])
async def test_concurrent_views_serialize_on_content(view_data, monkeypatch, case):
    sessions, uid, category_ids, content_ids = view_data
    content_id = content_ids[0]
    event_id = uuid4()
    next_id = uuid4() if case == "new_entry" else event_id
    item_id = (
        await create_referral(sessions, uid, content_id) if case == "different_referral" else None
    )
    first_payload = ContentViewCreate(client_event_id=event_id)
    second_payload = ContentViewCreate(client_event_id=next_id, recommendation_item_id=item_id)
    locked, release = asyncio.Event(), asyncio.Event()
    original_get = ContentRepository.get_owned
    async with sessions() as first, sessions() as second:
        first_pid = await first.scalar(text("SELECT pg_backend_pid()"))
        second_pid = await second.scalar(text("SELECT pg_backend_pid()"))
        assert first_pid != second_pid

        async def get_owned(self, **kwargs):
            result = await original_get(self, **kwargs)
            if self.session is first and kwargs.get("for_update"):
                locked.set()
                await asyncio.wait_for(release.wait(), 10)
            return result

        monkeypatch.setattr(ContentRepository, "get_owned", get_owned)
        tasks = [asyncio.create_task(service(first).record_view(uid, content_id, first_payload))]
        try:
            await asyncio.wait_for(locked.wait(), 10)
            tasks.append(
                asyncio.create_task(service(second).record_view(uid, content_id, second_payload))
            )
            assert await wait_for_block_or_completion(sessions, tasks[1], second_pid, first_pid)
            release.set()
            results = await asyncio.wait_for(asyncio.gather(*tasks, return_exceptions=True), 10)
            assert not isinstance(results[0], Exception)
            if case == "different_referral":
                assert isinstance(results[1], InvalidStateError)
                assert results[1].status_code == 409
            else:
                assert results == [results[0], results[0]]
            assert not first.in_transaction() and not second.in_transaction()
        finally:
            await stop_tasks(tasks, release)
    events = await assert_views(
        sessions, uid, {content_id: 2 if case == "new_entry" else 1}, [event_id, next_id]
    )
    assert all(event.category_ids_at_event == sorted(category_ids[:2]) for event in events)
    assert all(event.recommendation_item_id is None for event in events)


async def test_different_contents_race_on_event_id_unique_constraint(view_data, monkeypatch):
    sessions, uid, _, content_ids = view_data
    payload = ContentViewCreate(client_event_id=uuid4())
    inserted, release = asyncio.Event(), asyncio.Event()
    original_insert = EventRepository.create_reopened_once
    insert_results = []
    async with sessions() as first, sessions() as second:
        first_pid = await first.scalar(text("SELECT pg_backend_pid()"))
        second_pid = await second.scalar(text("SELECT pg_backend_pid()"))
        assert first_pid != second_pid

        async def insert_once(self, **kwargs):
            result = await original_insert(self, **kwargs)
            insert_results.append(result)
            if self.session is first:
                inserted.set()
                await asyncio.wait_for(release.wait(), 10)
            return result

        monkeypatch.setattr(EventRepository, "create_reopened_once", insert_once)
        tasks = [asyncio.create_task(service(first).record_view(uid, content_ids[0], payload))]
        try:
            await asyncio.wait_for(inserted.wait(), 10)
            tasks.append(
                asyncio.create_task(service(second).record_view(uid, content_ids[1], payload))
            )
            assert await wait_for_block_or_completion(sessions, tasks[1], second_pid, first_pid)
            release.set()
            results = await asyncio.wait_for(asyncio.gather(*tasks, return_exceptions=True), 10)
            assert not isinstance(results[0], Exception)
            assert isinstance(results[1], InvalidStateError)
            assert results[1].status_code == 409
            assert not first.in_transaction() and not second.in_transaction()
        finally:
            await stop_tasks(tasks, release)
    assert len(insert_results) == 2 and insert_results[0] is not None and insert_results[1] is None
    await assert_views(
        sessions, uid, {content_ids[0]: 1, content_ids[1]: 0}, [payload.client_event_id]
    )


@pytest.mark.parametrize("same_content", [True, False])
async def test_failed_first_writer_releases_event_id_for_waiting_request(
    view_data, monkeypatch, same_content
):
    sessions, uid, _, content_ids = view_data
    winning_id = content_ids[0 if same_content else 1]
    payload = ContentViewCreate(client_event_id=uuid4())
    staged, release = asyncio.Event(), asyncio.Event()
    async with sessions() as first, sessions() as second:
        first_pid = await first.scalar(text("SELECT pg_backend_pid()"))
        second_pid = await second.scalar(text("SELECT pg_backend_pid()"))

        async def fail_commit():
            staged.set()
            await asyncio.wait_for(release.wait(), 10)
            raise RuntimeError("injected view commit failure")

        monkeypatch.setattr(first, "commit", fail_commit)
        tasks = [asyncio.create_task(service(first).record_view(uid, content_ids[0], payload))]
        try:
            await asyncio.wait_for(staged.wait(), 10)
            tasks.append(asyncio.create_task(service(second).record_view(uid, winning_id, payload)))
            assert await wait_for_block_or_completion(sessions, tasks[1], second_pid, first_pid)
            release.set()
            results = await asyncio.wait_for(asyncio.gather(*tasks, return_exceptions=True), 10)
            assert isinstance(results[0], RuntimeError)
            assert str(results[0]) == "injected view commit failure"
            assert results[1].content_id == winning_id
            assert not first.in_transaction() and not second.in_transaction()
        finally:
            await stop_tasks(tasks, release)
    await assert_views(
        sessions,
        uid,
        {content_id: int(content_id == winning_id) for content_id in content_ids},
        [payload.client_event_id],
    )


@pytest.mark.parametrize("operation", ["reclassify", "delete"])
@pytest.mark.parametrize("mutation_first", [True, False])
async def test_view_snapshot_follows_category_lock_order(
    view_data, monkeypatch, operation, mutation_first
):
    sessions, uid, category_ids, content_ids = view_data
    content_id = content_ids[0]
    initial = sorted(category_ids[:2])
    changed = [category_ids[2]] if operation == "reclassify" else [category_ids[1]]
    locked, release = asyncio.Event(), asyncio.Event()
    original_get = ContentRepository.get_owned
    original_delete_lock = ContentRepository.lock_category_contents
    async with sessions() as viewing, sessions() as mutating:
        # The service must refresh cached relationships after acquiring its lock.
        cached = await ContentRepository(viewing).get_owned(user_id=uid, content_id=content_id)
        assert sorted(category.id for category in cached.categories) == initial
        first_session = mutating if mutation_first else viewing
        second_session = viewing if mutation_first else mutating
        first_pid = await first_session.scalar(text("SELECT pg_backend_pid()"))
        second_pid = await second_session.scalar(text("SELECT pg_backend_pid()"))
        assert first_pid != second_pid

        async def get_owned(self, **kwargs):
            result = await original_get(self, **kwargs)
            if self.session is first_session and kwargs.get("for_update"):
                locked.set()
                await asyncio.wait_for(release.wait(), 10)
            return result

        async def delete_lock(self, *args):
            result = await original_delete_lock(self, *args)
            if self.session is first_session:
                locked.set()
                await asyncio.wait_for(release.wait(), 10)
            return result

        monkeypatch.setattr(ContentRepository, "get_owned", get_owned)
        monkeypatch.setattr(ContentRepository, "lock_category_contents", delete_lock)
        payload = ContentViewCreate(client_event_id=uuid4())

        async def view():
            return await service(viewing).record_view(uid, content_id, payload)

        async def mutate():
            if operation == "delete":
                return await CategoryService(CategoryRepository(mutating)).delete_category(
                    uid, category_ids[0]
                )
            return await service(mutating).update_categories(
                user_id=uid,
                content_id=content_id,
                payload=ContentCategoryUpdate(category_ids=changed),
            )

        tasks = [asyncio.create_task(mutate() if mutation_first else view())]
        try:
            await asyncio.wait_for(locked.wait(), 10)
            tasks.append(asyncio.create_task(view() if mutation_first else mutate()))
            assert await wait_for_block_or_completion(sessions, tasks[1], second_pid, first_pid)
            release.set()
            await asyncio.wait_for(asyncio.gather(*tasks), 10)
        finally:
            await stop_tasks(tasks, release)
    events = await assert_views(sessions, uid, {content_id: 1}, [payload.client_event_id])
    assert events[0].category_ids_at_event == (changed if mutation_first else initial)
    async with sessions() as session:
        content = await ContentRepository(session).get_owned(user_id=uid, content_id=content_id)
        assert sorted(category.id for category in content.categories) == changed
        if operation == "delete":
            assert await session.get(Category, category_ids[0]) is None
