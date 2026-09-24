import asyncio
from datetime import timedelta
from types import SimpleNamespace
from uuid import uuid4

import pytest
import pytest_asyncio
from sqlalchemy import select, text

from app.core.exceptions import InvalidStateError, NotFoundError
from app.models.category import Category
from app.models.content import Content, ContentSource, ContentType
from app.models.content_event import ContentEvent
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
from app.schemas.content import ContentViewCreate
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
async def exposure_data(today_data):
    sessions, user_ids, category_ids, content_ids = today_data
    items, later_items, category_items = [], [], []
    async with sessions() as session:
        for uid, categories, contents in zip(user_ids, category_ids, content_ids, strict=True):
            user_items = []
            for days_ago in [2, 1]:
                batch = RecommendationBatch(
                    user_id=uid,
                    type=RecommendationType.TODAY,
                    recommendation_date=NOW.date() - timedelta(days=days_ago),
                )
                session.add(batch)
                await session.flush()
                batch_items = [
                    RecommendationBatchItem(
                        batch_id=batch.id,
                        rank=rank,
                        target_kind=RecommendationTargetKind.CONTENT,
                        target_id_snapshot=cid,
                        content_id=cid,
                    )
                    for rank, cid in enumerate(contents[:2], 1)
                ]
                session.add_all(batch_items)
                await session.flush()
                user_items.append([item.id for item in batch_items])
            items.append(user_items[0])
            later_items.append(user_items[1])
            weekly = RecommendationBatch(user_id=uid, type=RecommendationType.WEEKLY_PICK)
            session.add(weekly)
            await session.flush()
            category_item = RecommendationBatchItem(
                batch_id=weekly.id,
                rank=1,
                target_kind=RecommendationTargetKind.CATEGORY,
                target_id_snapshot=categories[0],
                category_id=categories[0],
                card_type=RecommendationCardType.REDISCOVERY,
            )
            session.add(category_item)
            await session.flush()
            category_items.append(category_item.id)
        await session.commit()
    # today_data owns cleanup of all rows, including these recommendation FK dependencies.
    return SimpleNamespace(
        sessions=sessions,
        users=user_ids,
        categories=category_ids,
        contents=content_ids,
        items=items,
        later_items=later_items,
        category_items=category_items,
    )


def payload(item_id, event_id=None):
    return RecommendationExposureCreate(
        client_event_id=event_id or uuid4(), recommendation_item_id=item_id
    )


async def assert_recorded(data, user_index, expected_count, expected_counter, expected_time=None):
    async with data.sessions() as session:
        events = list(
            await session.scalars(
                select(RecommendationExposure)
                .where(RecommendationExposure.user_id == data.users[user_index])
                .order_by(RecommendationExposure.id)
            )
        )
        assert len(events) == expected_count
        content = await session.get(Content, data.contents[user_index][0])
        assert content.recommendation_count == expected_counter
        assert content.last_recommended_at == expected_time
        assert content.last_recommended_surface == (
            RecommendationType.TODAY if expected_counter else None
        )
        return events


@pytest.mark.parametrize(
    "case,kind",
    [
        ("retry", "content"),
        ("retry", "category"),
        ("other_target", "content"),
        ("other_batch_same_target", "content"),
        ("new_visit", "content"),
        ("new_visit_other_batch", "content"),
    ],
)
async def test_exposures_serialize_uuid_and_counter_updates(exposure_data, monkeypatch, case, kind):
    data = exposure_data
    uid = data.users[0]
    item_id = data.category_items[0] if kind == "category" else data.items[0][0]
    first_payload = payload(item_id)
    second_id = (
        data.items[0][1] if case == "other_target"
        else data.later_items[0][0] if "batch" in case
        else item_id
    )
    second_payload = payload(
        second_id, uuid4() if case.startswith("new_visit") else first_payload.client_event_id
    )
    locked, release = asyncio.Event(), asyncio.Event()
    original_lock = RecommendationRepository.lock_user
    async with data.sessions() as first, data.sessions() as second:
        first_pid = await first.scalar(text("SELECT pg_backend_pid()"))
        second_pid = await second.scalar(text("SELECT pg_backend_pid()"))
        assert first_pid != second_pid
        cached = await ContentRepository(second).get_owned(
            user_id=uid, content_id=data.contents[0][0]
        )
        assert cached.recommendation_count == 0

        async def lock(self, user_id):
            await original_lock(self, user_id)
            if self.session is first:
                locked.set()
                await asyncio.wait_for(release.wait(), 10)

        monkeypatch.setattr(RecommendationRepository, "lock_user", lock)
        tasks = [asyncio.create_task(today_service(first).record_exposure(uid, first_payload))]
        try:
            await asyncio.wait_for(locked.wait(), 10)
            tasks.append(asyncio.create_task(
                today_service(second, lambda: NOW + timedelta(seconds=1)).record_exposure(
                    uid, second_payload
                )
            ))
            assert await wait_for_block_or_completion(
                data.sessions, tasks[1], second_pid, first_pid
            )
            release.set()
            results = await asyncio.wait_for(asyncio.gather(*tasks, return_exceptions=True), 10)
            assert not isinstance(results[0], Exception)
            if case in {"other_target", "other_batch_same_target"}:
                assert isinstance(results[1], InvalidStateError)
                assert results[1].status_code == 409
            elif case == "retry":
                assert results[0] == results[1]
            else:
                assert results[0].exposure_id != results[1].exposure_id
            assert not first.in_transaction() and not second.in_transaction()
        finally:
            await stop_tasks(tasks, release)
    count = 2 if case.startswith("new_visit") else 1
    events = await assert_recorded(
        data, 0, count, count if kind == "content" else 0,
        NOW + timedelta(seconds=count - 1) if kind == "content" else None,
    )
    assert events[0].client_event_id == first_payload.client_event_id
    assert events[0].recommended_at == NOW
    async with data.sessions() as session:
        other = await session.get(Content, data.contents[0][1])
        assert other.recommendation_count == 0


async def test_other_user_exposure_is_independent_with_same_uuid(exposure_data, monkeypatch):
    data = exposure_data
    event_id = uuid4()
    locked, release = asyncio.Event(), asyncio.Event()
    original_lock = RecommendationRepository.lock_user
    async with data.sessions() as first, data.sessions() as second:

        async def lock(self, user_id):
            await original_lock(self, user_id)
            if self.session is first:
                locked.set()
                await asyncio.wait_for(release.wait(), 10)

        monkeypatch.setattr(RecommendationRepository, "lock_user", lock)
        task = asyncio.create_task(today_service(first).record_exposure(
            data.users[0], payload(data.items[0][0], event_id)
        ))
        try:
            await asyncio.wait_for(locked.wait(), 10)
            other = await asyncio.wait_for(today_service(second).record_exposure(
                data.users[1], payload(data.items[1][0], event_id)
            ), 10)
            assert other.exposure_id is not None
            assert not task.done()
            release.set()
            await asyncio.wait_for(task, 10)
        finally:
            await stop_tasks([task], release)
    for index in [0, 1]:
        events = await assert_recorded(data, index, 1, 1, NOW)
        assert events[0].client_event_id == event_id


@pytest.mark.parametrize("kind", ["content", "category"])
@pytest.mark.parametrize("delete_first", [True, False])
async def test_target_deletion_orders_and_successful_replay(
    exposure_data, monkeypatch, kind, delete_first
):
    data = exposure_data
    uid, cid = data.users[0], data.contents[0][0]
    item_id = data.items[0][0] if kind == "content" else data.category_items[0]
    request = payload(item_id)
    locked, release = asyncio.Event(), asyncio.Event()
    original_content = ContentRepository.get_owned
    original_category = CategoryRepository.get_owned_for_key_share
    async with data.sessions() as exposing, data.sessions() as deleting:
        # Exercise a stale ORM item as well as the separate live-target lock.
        cached_item, _ = await RecommendationRepository(exposing).get_owned_item(
            user_id=uid, item_id=item_id
        )
        assert cached_item.content_id is not None or cached_item.category_id is not None
        first = deleting if delete_first else exposing
        second = exposing if delete_first else deleting
        first_pid = await first.scalar(text("SELECT pg_backend_pid()"))
        second_pid = await second.scalar(text("SELECT pg_backend_pid()"))
        original_commit = deleting.commit

        async def content_lock(self, **kwargs):
            result = await original_content(self, **kwargs)
            if self.session is exposing and not delete_first and kwargs.get("for_update"):
                locked.set()
                await asyncio.wait_for(release.wait(), 10)
            return result

        async def category_lock(self, *args, **kwargs):
            result = await original_category(self, *args, **kwargs)
            if self.session is exposing and not delete_first:
                locked.set()
                await asyncio.wait_for(release.wait(), 10)
            return result

        async def commit():
            if delete_first:
                locked.set()
                await asyncio.wait_for(release.wait(), 10)
            await original_commit()

        monkeypatch.setattr(ContentRepository, "get_owned", content_lock)
        monkeypatch.setattr(CategoryRepository, "get_owned_for_key_share", category_lock)
        monkeypatch.setattr(deleting, "commit", commit)

        async def remove():
            if kind == "content":
                await content_service(deleting).delete_content(user_id=uid, content_id=cid)
            else:
                await CategoryService(CategoryRepository(deleting)).delete_category(
                    uid, data.categories[0][0]
                )

        async def expose():
            return await today_service(exposing).record_exposure(uid, request)

        tasks = [asyncio.create_task(remove() if delete_first else expose())]
        try:
            await asyncio.wait_for(locked.wait(), 10)
            tasks.append(asyncio.create_task(expose() if delete_first else remove()))
            assert await wait_for_block_or_completion(
                data.sessions, tasks[1], second_pid, first_pid
            )
            release.set()
            results = await asyncio.wait_for(asyncio.gather(*tasks, return_exceptions=True), 10)
            exposure_result = results[1 if delete_first else 0]
            assert results[0 if delete_first else 1] is None
            if delete_first:
                assert isinstance(exposure_result, NotFoundError)
            else:
                assert not isinstance(exposure_result, Exception)
        finally:
            await stop_tasks(tasks, release)
    async with data.sessions() as session:
        item = await session.get(RecommendationBatchItem, item_id)
        assert item.content_id is None and item.category_id is None
        assert item.target_id_snapshot == (cid if kind == "content" else data.categories[0][0])
        events = list(await session.scalars(
            select(RecommendationExposure).where(RecommendationExposure.user_id == uid)
        ))
        assert len(events) == (0 if delete_first else 1)
        if not delete_first:
            replay = await today_service(session, lambda: NOW + timedelta(days=1)).record_exposure(
                uid, request
            )
            assert replay == exposure_result
            assert replay.recommended_at == NOW
        with pytest.raises(NotFoundError):
            await today_service(session).record_exposure(uid, payload(item_id))
        if kind == "category":
            contents = list(await session.scalars(select(Content).where(Content.user_id == uid)))
            assert all(content.recommendation_count == 0 for content in contents)


@pytest.mark.parametrize("view_first", [True, False])
async def test_view_and_exposure_preserve_separate_counters_without_deadlock(
    exposure_data, monkeypatch, view_first
):
    data = exposure_data
    uid, cid = data.users[0], data.contents[0][0]
    event_id = uuid4()
    locked, release = asyncio.Event(), asyncio.Event()
    original_get = ContentRepository.get_owned
    async with data.sessions() as viewing, data.sessions() as exposing:
        first = viewing if view_first else exposing
        second = exposing if view_first else viewing
        first_pid = await first.scalar(text("SELECT pg_backend_pid()"))
        second_pid = await second.scalar(text("SELECT pg_backend_pid()"))

        async def lock(self, **kwargs):
            result = await original_get(self, **kwargs)
            if self.session is first and kwargs.get("for_update"):
                locked.set()
                await asyncio.wait_for(release.wait(), 10)
            return result

        monkeypatch.setattr(ContentRepository, "get_owned", lock)

        async def view():
            return await content_service(viewing).record_view(
                uid, cid, ContentViewCreate(
                    client_event_id=event_id, recommendation_item_id=data.items[0][0]
                )
            )

        async def expose():
            return await today_service(exposing).record_exposure(
                uid, payload(data.items[0][0], event_id)
            )

        tasks = [asyncio.create_task(view() if view_first else expose())]
        try:
            await asyncio.wait_for(locked.wait(), 10)
            tasks.append(asyncio.create_task(expose() if view_first else view()))
            assert await wait_for_block_or_completion(
                data.sessions, tasks[1], second_pid, first_pid
            )
            release.set()
            await asyncio.wait_for(asyncio.gather(*tasks), 10)
        finally:
            await stop_tasks(tasks, release)
    events = await assert_recorded(data, 0, 1, 1, NOW)
    assert events[0].client_event_id == event_id
    async with data.sessions() as session:
        content = await session.get(Content, cid)
        views = list(await session.scalars(select(ContentEvent).where(ContentEvent.user_id == uid)))
        assert len(views) == 1 and views[0].client_event_id == event_id
        assert content.open_count == 1 and content.last_viewed_at == views[0].created_at


@pytest.mark.parametrize("exposure_first", [True, False])
async def test_today_and_exposure_follow_user_lock_order(
    exposure_data, monkeypatch, exposure_first
):
    data = exposure_data
    uid, cid = data.users[0], data.contents[0][0]
    async with data.sessions() as setup:
        setup.add_all([
            Content(
                user_id=uid,
                title=f"Extra Stage 2 candidate {index}",
                summary="",
                content_type=ContentType.LINK,
                source=ContentSource.WEB,
                saved_at=NOW - timedelta(days=3),
            )
            for index in range(5)
        ])
        await setup.commit()
    locked, release = asyncio.Event(), asyncio.Event()
    original_lock = RecommendationRepository.lock_user
    original_candidates = ContentRepository.list_today_candidates_for_share
    snapshots = []
    async with data.sessions() as exposing, data.sessions() as reading:
        first = exposing if exposure_first else reading
        second = reading if exposure_first else exposing
        first_pid = await first.scalar(text("SELECT pg_backend_pid()"))
        second_pid = await second.scalar(text("SELECT pg_backend_pid()"))

        async def lock(self, user_id):
            await original_lock(self, user_id)
            if self.session is first:
                locked.set()
                await asyncio.wait_for(release.wait(), 10)

        async def candidates(self, user_id):
            result = await original_candidates(self, user_id)
            snapshots.extend(result)
            return result

        monkeypatch.setattr(RecommendationRepository, "lock_user", lock)
        monkeypatch.setattr(ContentRepository, "list_today_candidates_for_share", candidates)

        async def expose():
            return await today_service(exposing).record_exposure(uid, payload(data.items[0][0]))

        async def read():
            return await today_service(reading).read_today(uid)

        tasks = [asyncio.create_task(expose() if exposure_first else read())]
        try:
            await asyncio.wait_for(locked.wait(), 10)
            tasks.append(asyncio.create_task(read() if exposure_first else expose()))
            assert await wait_for_block_or_completion(
                data.sessions, tasks[1], second_pid, first_pid
            )
            release.set()
            results = await asyncio.wait_for(asyncio.gather(*tasks), 10)
            original = results[1 if exposure_first else 0]
        finally:
            await stop_tasks(tasks, release)
    captured = next(candidate for candidate in snapshots if candidate.id == cid)
    assert captured.last_recommended_at == (NOW if exposure_first else None)
    if exposure_first:
        assert cid not in {item.content.id for item in original.items}
    async with data.sessions() as session:
        replay = await today_service(session).read_today(uid)
        assert replay == original
    await assert_recorded(data, 0, 1, 1, NOW)


@pytest.mark.parametrize("kind", ["content", "category"])
async def test_exposure_timestamp_is_sampled_after_target_lock(exposure_data, kind):
    data = exposure_data
    uid = data.users[0]
    item_id = data.items[0][0] if kind == "content" else data.category_items[0]
    clock = [NOW]
    async with data.sessions() as holding, data.sessions() as exposing:
        holding_pid = await holding.scalar(text("SELECT pg_backend_pid()"))
        exposing_pid = await exposing.scalar(text("SELECT pg_backend_pid()"))
        if kind == "content":
            await ContentRepository(holding).get_owned(
                user_id=uid, content_id=data.contents[0][0], for_update=True
            )
        else:
            await holding.execute(
                select(Category.id).where(Category.id == data.categories[0][0]).with_for_update()
            )
        task = asyncio.create_task(today_service(exposing, lambda: clock[0]).record_exposure(
            uid, payload(item_id)
        ))
        try:
            assert await wait_for_block_or_completion(
                data.sessions, task, exposing_pid, holding_pid
            )
            clock[0] += timedelta(hours=2)
            await holding.commit()
            response = await asyncio.wait_for(task, 10)
        finally:
            await stop_tasks([task], asyncio.Event())
    events = await assert_recorded(
        data, 0, 1, int(kind == "content"), clock[0] if kind == "content" else None
    )
    assert events[0].recommended_at == response.recommended_at == clock[0]


@pytest.mark.parametrize("failure_point", ["insert", "counter", "commit"])
async def test_failed_exposure_rolls_back_then_waiting_retry_succeeds(
    exposure_data, monkeypatch, failure_point
):
    data = exposure_data
    uid = data.users[0]
    request = payload(data.items[0][0])
    staged, release = asyncio.Event(), asyncio.Event()
    original_insert = RecommendationRepository.create_exposure_once
    original_mark = ContentRepository.mark_recommended
    async with data.sessions() as first, data.sessions() as second:
        first_pid = await first.scalar(text("SELECT pg_backend_pid()"))
        second_pid = await second.scalar(text("SELECT pg_backend_pid()"))

        async def fail():
            staged.set()
            await asyncio.wait_for(release.wait(), 10)
            raise RuntimeError(f"injected exposure {failure_point} failure")

        async def insert(self, **kwargs):
            result = await original_insert(self, **kwargs)
            if self.session is first and failure_point == "insert":
                await fail()
            return result

        async def mark(self, *args, **kwargs):
            result = await original_mark(self, *args, **kwargs)
            if self.session is first and failure_point == "counter":
                await fail()
            return result

        monkeypatch.setattr(RecommendationRepository, "create_exposure_once", insert)
        monkeypatch.setattr(ContentRepository, "mark_recommended", mark)
        if failure_point == "commit":
            monkeypatch.setattr(first, "commit", fail)
        tasks = [asyncio.create_task(today_service(first).record_exposure(uid, request))]
        try:
            await asyncio.wait_for(staged.wait(), 10)
            tasks.append(asyncio.create_task(
                today_service(second, lambda: NOW + timedelta(seconds=1)).record_exposure(
                    uid, request
                )
            ))
            assert await wait_for_block_or_completion(
                data.sessions, tasks[1], second_pid, first_pid
            )
            release.set()
            results = await asyncio.wait_for(asyncio.gather(*tasks, return_exceptions=True), 10)
            assert isinstance(results[0], RuntimeError)
            assert str(results[0]) == f"injected exposure {failure_point} failure"
            assert results[1].recommended_at == NOW + timedelta(seconds=1)
            assert not first.in_transaction() and not second.in_transaction()
        finally:
            await stop_tasks(tasks, release)
    events = await assert_recorded(data, 0, 1, 1, NOW + timedelta(seconds=1))
    assert events[0].client_event_id == request.client_event_id
    assert events[0].id == results[1].exposure_id


async def test_category_exposure_does_not_lock_member_contents(exposure_data):
    data = exposure_data
    uid = data.users[0]
    async with data.sessions() as holding, data.sessions() as exposing:
        await ContentRepository(holding).get_owned(
            user_id=uid, content_id=data.contents[0][0], for_update=True
        )
        response = await asyncio.wait_for(today_service(exposing).record_exposure(
            uid, payload(data.category_items[0])
        ), 10)
        assert response.exposure_id is not None
        assert holding.in_transaction() and not exposing.in_transaction()
    await assert_recorded(data, 0, 1, 0)
