import asyncio
from datetime import UTC, datetime, timedelta
from types import SimpleNamespace
from uuid import uuid4

import pytest
import pytest_asyncio
from sqlalchemy import delete, select, text

from app.models.category import Category
from app.models.content import Content, ContentSource, ContentType
from app.models.content_event import ContentEvent, ContentEventType
from app.models.recommendation import (
    RecommendationBatch,
    RecommendationBatchItem,
    RecommendationCardType,
    RecommendationExposure,
    RecommendationTargetKind,
    RecommendationType,
)
from app.repositories.category_repository import CategoryRepository
from app.repositories.content_repository import ContentRepository
from app.repositories.recommendation_repository import RecommendationRepository
from app.schemas.content import ContentCategoryUpdate, ContentViewCreate
from app.schemas.recommendation import RecommendationExposureCreate
from app.services.category_service import CategoryService
from tests.repositories.test_tag_concurrency import wait_for_block_or_completion
from tests.repositories.test_today_concurrency import (
    NOW,
    content_service,
    today_data as today_data,
    today_service,
)
from tests.repositories.test_view_concurrency import stop_tasks

pytestmark = pytest.mark.asyncio


@pytest_asyncio.fixture
async def weekly_data(today_data):
    sessions, users, categories, contents = today_data
    category_items = []
    async with sessions() as session:
        for uid, category_ids, content_ids in zip(users, categories, contents, strict=True):
            session.add_all([
                ContentEvent(
                    user_id=uid,
                    content_id=cid,
                    event_type=ContentEventType.CONTENT_CREATED,
                    category_ids_at_event=category_ids[:2],
                    created_at=NOW - timedelta(days=3, minutes=index),
                )
                for index, cid in enumerate(content_ids)
            ])
            batch = RecommendationBatch(
                user_id=uid,
                type=RecommendationType.WEEKLY_PICK,
                generated_at=NOW - timedelta(days=8),
            )
            session.add(batch)
            await session.flush()
            item = RecommendationBatchItem(
                batch_id=batch.id,
                rank=1,
                target_kind=RecommendationTargetKind.CATEGORY,
                target_id_snapshot=category_ids[0],
                category_id=category_ids[0],
                card_type=RecommendationCardType.REDISCOVERY,
            )
            session.add(item)
            await session.flush()
            category_items.append(item.id)
        await session.commit()
    # today_data removes only these users' rows in FK dependency order.
    return SimpleNamespace(
        sessions=sessions,
        users=users,
        categories=categories,
        contents=contents,
        category_items=category_items,
    )


async def assert_batch(data, response, user_id, expected_categories):
    async with data.sessions() as session:
        batch = await session.get(RecommendationBatch, response.batch_id)
        assert batch.user_id == user_id and batch.type == RecommendationType.WEEKLY_PICK
        assert batch.recommendation_date is None
        assert batch.generated_at == response.generated_at == response.period_end
        items = list(await session.scalars(
            select(RecommendationBatchItem)
            .where(RecommendationBatchItem.batch_id == batch.id)
            .order_by(RecommendationBatchItem.rank)
        ))
        assert [item.rank for item in items] == list(range(1, len(expected_categories) + 1))
        assert {item.target_id_snapshot for item in items} == set(expected_categories)
        assert all(item.content_id is None and item.score is None for item in items)
        assert [item.id for item in items] == [
            item.recommendation_item_id for item in response.items
        ]
        return items


async def test_same_user_weekly_requests_wait_but_create_separate_batches(weekly_data, monkeypatch):
    data = weekly_data
    uid = data.users[0]
    locked, release = asyncio.Event(), asyncio.Event()
    original = RecommendationRepository.lock_user
    async with data.sessions() as first, data.sessions() as second:
        first_pid = await first.scalar(text("SELECT pg_backend_pid()"))
        second_pid = await second.scalar(text("SELECT pg_backend_pid()"))
        assert first_pid != second_pid

        async def lock(self, user_id):
            await original(self, user_id)
            if self.session is first:
                locked.set()
                await asyncio.wait_for(release.wait(), 10)

        monkeypatch.setattr(RecommendationRepository, "lock_user", lock)
        tasks = [asyncio.create_task(today_service(first).read_weekly(uid))]
        try:
            await asyncio.wait_for(locked.wait(), 10)
            tasks.append(asyncio.create_task(today_service(second).read_weekly(uid)))
            assert await wait_for_block_or_completion(
                data.sessions, tasks[1], second_pid, first_pid
            )
            release.set()
            results = await asyncio.wait_for(asyncio.gather(*tasks), 10)
            assert results[0].batch_id != results[1].batch_id
            assert {item.recommendation_item_id for item in results[0].items}.isdisjoint(
                item.recommendation_item_id for item in results[1].items
            )
            assert not first.in_transaction() and not second.in_transaction()
        finally:
            await stop_tasks(tasks, release)
    for response in results:
        await assert_batch(data, response, uid, data.categories[0][:2])


async def test_other_user_weekly_is_not_blocked(weekly_data, monkeypatch):
    data = weekly_data
    locked, release = asyncio.Event(), asyncio.Event()
    original = RecommendationRepository.lock_user
    async with data.sessions() as first, data.sessions() as second:

        async def lock(self, user_id):
            await original(self, user_id)
            if self.session is first:
                locked.set()
                await asyncio.wait_for(release.wait(), 10)

        monkeypatch.setattr(RecommendationRepository, "lock_user", lock)
        task = asyncio.create_task(today_service(first).read_weekly(data.users[0]))
        try:
            await asyncio.wait_for(locked.wait(), 10)
            other = await asyncio.wait_for(today_service(second).read_weekly(data.users[1]), 10)
            assert other.batch_id is not None and not task.done()
            release.set()
            response = await asyncio.wait_for(task, 10)
        finally:
            await stop_tasks([task], release)
    await assert_batch(data, response, data.users[0], data.categories[0][:2])
    await assert_batch(data, other, data.users[1], data.categories[1][:2])


@pytest.mark.parametrize(
    "operation", ["view", "move", "content_delete", "category_delete", "expose"]
)
@pytest.mark.parametrize("mutation_first", [True, False])
async def test_weekly_aggregation_follows_writer_lock_order(
    weekly_data, monkeypatch, operation, mutation_first
):
    data = weekly_data
    uid, cid = data.users[0], data.contents[0][0]
    categories = data.categories[0]
    locked, release = asyncio.Event(), asyncio.Event()
    original_ids = ContentRepository.list_owned_ids_for_share
    original_candidates = RecommendationRepository.list_weekly_candidates
    snapshots = []
    # Make the view timestamp strictly inside this Weekly request's [start, end).
    monkeypatch.setattr(
        "app.services.content_service.datetime",
        SimpleNamespace(now=lambda _: NOW - timedelta(seconds=1)),
    )
    async with data.sessions() as reading, data.sessions() as mutating:
        cached = await ContentRepository(reading).get_owned(user_id=uid, content_id=cid)
        assert {category.id for category in cached.categories} == set(categories[:2])
        first = mutating if mutation_first else reading
        second = reading if mutation_first else mutating
        first_pid = await first.scalar(text("SELECT pg_backend_pid()"))
        second_pid = await second.scalar(text("SELECT pg_backend_pid()"))
        assert first_pid != second_pid
        original_commit = mutating.commit

        async def ids(self, user_id):
            result = await original_ids(self, user_id)
            if self.session is reading and not mutation_first:
                locked.set()
                await asyncio.wait_for(release.wait(), 10)
            return result

        async def candidates(self, **kwargs):
            result = await original_candidates(self, **kwargs)
            if self.session is reading:
                snapshots.extend(result)
            return result

        async def commit():
            if mutation_first:
                locked.set()
                await asyncio.wait_for(release.wait(), 10)
            await original_commit()

        monkeypatch.setattr(ContentRepository, "list_owned_ids_for_share", ids)
        monkeypatch.setattr(RecommendationRepository, "list_weekly_candidates", candidates)
        monkeypatch.setattr(mutating, "commit", commit)

        async def mutate():
            writer = content_service(mutating)
            if operation == "view":
                return await writer.record_view(
                    uid, cid, ContentViewCreate(client_event_id=uuid4())
                )
            if operation == "move":
                return await writer.update_categories(
                    user_id=uid, content_id=cid,
                    payload=ContentCategoryUpdate(category_ids=[categories[2]]),
                )
            if operation == "content_delete":
                return await writer.delete_content(user_id=uid, content_id=cid)
            if operation == "category_delete":
                return await CategoryService(CategoryRepository(mutating)).delete_category(
                    uid, categories[0]
                )
            recommendations = today_service(mutating, lambda: NOW - timedelta(seconds=1))
            return await recommendations.record_exposure(
                uid, RecommendationExposureCreate(
                    client_event_id=uuid4(), recommendation_item_id=data.category_items[0]
                )
            )

        async def read():
            return await today_service(reading).read_weekly(uid)

        tasks = [asyncio.create_task(mutate() if mutation_first else read())]
        try:
            await asyncio.wait_for(locked.wait(), 10)
            tasks.append(asyncio.create_task(read() if mutation_first else mutate()))
            assert await wait_for_block_or_completion(
                data.sessions, tasks[1], second_pid, first_pid
            )
            release.set()
            results = await asyncio.wait_for(asyncio.gather(*tasks), 10)
            response = results[1 if mutation_first else 0]
        finally:
            await stop_tasks(tasks, release)
    by_category = {candidate.category.id: candidate for candidate in snapshots}
    if operation == "category_delete" and mutation_first:
        assert set(by_category) == {categories[1]}
    else:
        expected = set(categories[:2])
        if operation == "move" and mutation_first:
            expected.add(categories[2])
        assert set(by_category) == expected
    for category_id in categories[:2]:
        if category_id not in by_category:
            continue
        candidate = by_category[category_id]
        fewer_contents = mutation_first and operation in {"content_delete", "move"}
        assert candidate.category.content_count == (4 if fewer_contents else 5)
        assert candidate.saved_count == (
            4 if mutation_first and operation == "content_delete" else 5
        )
        assert candidate.viewed_count == int(mutation_first and operation == "view")
        assert candidate.last_viewed_event_at == (
            NOW - timedelta(seconds=1) if mutation_first and operation == "view" else None
        )
    if operation == "move" and mutation_first:
        assert by_category[categories[2]].category.content_count == 1
        assert by_category[categories[2]].saved_count == 0
    if operation == "expose":
        assert by_category[categories[0]].last_exposed_at == (
            NOW - timedelta(seconds=1) if mutation_first else None
        )
    expected_items = {item.category.id for item in response.items}
    stored = await assert_batch(data, response, uid, expected_items)
    if operation == "category_delete" and not mutation_first:
        deleted_item = next(item for item in stored if item.target_id_snapshot == categories[0])
        assert deleted_item.category_id is None


@pytest.mark.parametrize("case", ["existing_category", "empty_category", "empty_contents"])
async def test_new_save_outside_locked_ids_waits_until_next_weekly(weekly_data, monkeypatch, case):
    data = weekly_data
    uid = data.users[0]
    category_id = data.categories[0][2 if case == "empty_category" else 0]
    if case == "empty_contents":
        async with data.sessions() as setup:
            await setup.execute(delete(Content).where(Content.user_id == uid))
            await setup.commit()
    captured, release = asyncio.Event(), asyncio.Event()
    original_ids = ContentRepository.list_owned_ids_for_share
    original_candidates = RecommendationRepository.list_weekly_candidates
    snapshots = []
    async with data.sessions() as reading, data.sessions() as saving:

        async def ids(self, user_id):
            result = await original_ids(self, user_id)
            if self.session is reading:
                assert len(result) == (0 if case == "empty_contents" else 5)
                captured.set()
                await asyncio.wait_for(release.wait(), 10)
            return result

        async def candidates(self, **kwargs):
            result = await original_candidates(self, **kwargs)
            snapshots.append({candidate.category.id: candidate for candidate in result})
            return result

        monkeypatch.setattr(ContentRepository, "list_owned_ids_for_share", ids)
        monkeypatch.setattr(RecommendationRepository, "list_weekly_candidates", candidates)
        task = asyncio.create_task(today_service(reading).read_weekly(uid))
        try:
            await asyncio.wait_for(captured.wait(), 10)
            category = await saving.get(Category, category_id)
            content = Content(
                user_id=uid, title="Saved after Weekly snapshot", summary="",
                content_type=ContentType.LINK, source=ContentSource.WEB,
                saved_at=NOW - timedelta(minutes=1), categories=[category],
                open_count=1, last_viewed_at=NOW - timedelta(seconds=30),
            )
            saving.add(content)
            await asyncio.wait_for(saving.flush(), 10)
            saving.add_all([
                ContentEvent(
                    user_id=uid, content_id=content.id, event_type=event_type,
                    category_ids_at_event=[category_id], created_at=timestamp,
                )
                for event_type, timestamp in [
                    (ContentEventType.CONTENT_CREATED, content.saved_at),
                    (ContentEventType.CONTENT_REOPENED, content.last_viewed_at),
                ]
            ])
            await asyncio.wait_for(saving.commit(), 10)
            assert not task.done()
            release.set()
            first = await asyncio.wait_for(task, 10)
        finally:
            await stop_tasks([task], release)
    async with data.sessions() as session:
        second = await today_service(session).read_weekly(uid)
    before = snapshots[0] if len(snapshots) == 2 else {}
    after = snapshots[-1]
    if case == "existing_category":
        assert before[category_id].category.content_count == before[category_id].saved_count == 5
        assert before[category_id].category.last_saved_at == NOW - timedelta(days=3)
        assert before[category_id].viewed_count == 0
        assert before[category_id].last_saved_event_at == NOW - timedelta(days=3)
    else:
        assert category_id not in before
        assert category_id not in {item.category.id for item in first.items}
    count = 6 if case == "existing_category" else 1
    assert after[category_id].category.content_count == after[category_id].saved_count == count
    assert after[category_id].category.last_saved_at == NOW - timedelta(minutes=1)
    assert after[category_id].viewed_count == 1
    assert after[category_id].last_saved_event_at == NOW - timedelta(minutes=1)
    assert after[category_id].last_viewed_event_at == NOW - timedelta(seconds=30)
    assert category_id in {item.category.id for item in second.items}
    if case == "empty_contents":
        assert first.batch_id is None and first.items == []
    else:
        assert first.batch_id != second.batch_id


async def test_weekly_period_is_sampled_after_lock_wait_across_kst_midnight(
    weekly_data, monkeypatch
):
    data = weekly_data
    uid = data.users[0]
    clock = [datetime(2026, 9, 25, 14, 59, 59, tzinfo=UTC)]
    snapshots = []
    original_candidates = RecommendationRepository.list_weekly_candidates

    async def candidates(self, **kwargs):
        result = await original_candidates(self, **kwargs)
        snapshots.extend(result)
        return result

    monkeypatch.setattr(RecommendationRepository, "list_weekly_candidates", candidates)
    async with data.sessions() as setup:
        setup.add(ContentEvent(
            user_id=uid, content_id=data.contents[0][0],
            event_type=ContentEventType.CONTENT_CREATED,
            category_ids_at_event=data.categories[0][:2],
            created_at=datetime(2026, 9, 19, 14, 59, 59, tzinfo=UTC),
        ))
        await setup.commit()
    async with data.sessions() as holding, data.sessions() as reading:
        holding_pid = await holding.scalar(text("SELECT pg_backend_pid()"))
        reading_pid = await reading.scalar(text("SELECT pg_backend_pid()"))
        await ContentRepository(holding).get_owned(
            user_id=uid, content_id=data.contents[0][0], for_update=True
        )
        task = asyncio.create_task(today_service(reading, lambda: clock[0]).read_weekly(uid))
        try:
            assert await wait_for_block_or_completion(data.sessions, task, reading_pid, holding_pid)
            clock[0] = datetime(2026, 9, 25, 15, 0, tzinfo=UTC)
            await holding.commit()
            response = await asyncio.wait_for(task, 10)
        finally:
            await stop_tasks([task], asyncio.Event())
    assert response.period_start == datetime(2026, 9, 19, 15, 0, tzinfo=UTC)
    assert response.period_end == response.generated_at == clock[0]
    assert all(candidate.saved_count == 5 for candidate in snapshots)
    await assert_batch(data, response, uid, data.categories[0][:2])


@pytest.mark.parametrize("failure_point", ["batch", "items", "commit"])
async def test_failed_weekly_generation_rolls_back_and_waiter_resumes(
    weekly_data, monkeypatch, failure_point
):
    data = weekly_data
    uid = data.users[0]
    staged, release = asyncio.Event(), asyncio.Event()
    original_create = RecommendationRepository.create_weekly_batch
    async with data.sessions() as first, data.sessions() as second:
        first_pid = await first.scalar(text("SELECT pg_backend_pid()"))
        second_pid = await second.scalar(text("SELECT pg_backend_pid()"))

        async def fail():
            staged.set()
            await asyncio.wait_for(release.wait(), 10)
            raise RuntimeError(f"injected Weekly {failure_point} failure")

        async def create(self, **kwargs):
            if self.session is first and failure_point == "batch":
                self.session.add(RecommendationBatch(
                    user_id=uid, type=RecommendationType.WEEKLY_PICK,
                    generated_at=kwargs["generated_at"],
                ))
                await self.session.flush()
                await fail()
            if self.session is first and failure_point == "items":
                await original_create(self, **{**kwargs, "selections": kwargs["selections"][:1]})
                await fail()
            return await original_create(self, **kwargs)

        monkeypatch.setattr(RecommendationRepository, "create_weekly_batch", create)
        if failure_point == "commit":
            monkeypatch.setattr(first, "commit", fail)
        tasks = [asyncio.create_task(today_service(first).read_weekly(uid))]
        try:
            await asyncio.wait_for(staged.wait(), 10)
            tasks.append(asyncio.create_task(today_service(second).read_weekly(uid)))
            assert await wait_for_block_or_completion(
                data.sessions, tasks[1], second_pid, first_pid
            )
            release.set()
            results = await asyncio.wait_for(asyncio.gather(*tasks, return_exceptions=True), 10)
            assert isinstance(results[0], RuntimeError)
            assert str(results[0]) == f"injected Weekly {failure_point} failure"
            assert results[1].batch_id is not None
            assert not first.in_transaction() and not second.in_transaction()
        finally:
            await stop_tasks(tasks, release)
    await assert_batch(data, results[1], uid, data.categories[0][:2])
    async with data.sessions() as session:
        generated = list(await session.scalars(select(RecommendationBatch).where(
            RecommendationBatch.user_id == uid, RecommendationBatch.generated_at == NOW
        )))
        assert [batch.id for batch in generated] == [results[1].batch_id]
        exposures = list(await session.scalars(select(RecommendationExposure).where(
            RecommendationExposure.user_id == uid
        )))
        assert exposures == []
