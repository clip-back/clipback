import asyncio
import json
import os

import pytest
import pytest_asyncio
from sqlalchemy import delete, select, text
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.core.exceptions import InvalidStateError
from app.models.category import Category
from app.models.content import Content, ContentSource, ContentType
from app.models.content_category import content_categories
from app.models.content_event import ContentEvent
from app.models.user import User
from app.repositories.category_repository import CategoryRepository
from app.repositories.content_repository import ContentRepository
from app.repositories.event_repository import EventRepository
from app.repositories.user_repository import UserRepository
from app.schemas.category import CategoryCreate, CategoryUpdate
from app.schemas.content import ContentCategoryUpdate
from app.services.category_service import CategoryService
from app.services.content_service import ContentService


@pytest_asyncio.fixture
async def concurrent_data():
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
            content = Content(
                user_id=uid,
                title="Concurrent",
                summary="",
                content_type=ContentType.LINK,
                source=ContentSource.WEB,
                categories=categories[:2],
            )
            session.add(content)
            await session.commit()
            ids, content_id = [c.id for c in categories], content.id
        yield sessions, uid, ids, content_id
    finally:
        if uid is not None:
            async with sessions() as session:
                # Only this fixture's committed rows; never reset shared tables.
                await session.execute(delete(ContentEvent).where(ContentEvent.user_id == uid))
                await session.execute(delete(Content).where(Content.user_id == uid))
                await session.execute(delete(Category).where(Category.user_id == uid))
                await session.execute(delete(User).where(User.id == uid))
                await session.commit()
        await engine.dispose()


async def wait_until_blocked(sessions, pid):
    async with asyncio.timeout(10):
        async with sessions() as observer:
            while not await observer.scalar(
                text("SELECT cardinality(pg_blocking_pids(:pid)) > 0"),
                {"pid": pid},
            ):
                await asyncio.sleep(0.01)


@pytest.mark.asyncio
@pytest.mark.parametrize("delete_first", [True, False])
async def test_concurrent_reclassification_and_deletion(concurrent_data, monkeypatch, delete_first):
    sessions, uid, ids, content_id = concurrent_data
    locked, release = asyncio.Event(), asyncio.Event()
    original_delete_lock = ContentRepository.lock_category_contents
    original_get = ContentRepository.get_owned

    async def delete_lock(self, user_id, category_id):
        result = await original_delete_lock(self, user_id, category_id)
        if delete_first:
            locked.set()
            await asyncio.wait_for(release.wait(), 10)
        return result

    async def get_owned(self, *, user_id, content_id, for_update=False):
        result = await original_get(
            self, user_id=user_id, content_id=content_id, for_update=for_update
        )
        if for_update and not delete_first:
            locked.set()
            await asyncio.wait_for(release.wait(), 10)
        return result

    monkeypatch.setattr(ContentRepository, "lock_category_contents", delete_lock)
    monkeypatch.setattr(ContentRepository, "get_owned", get_owned)
    async with sessions() as deleting, sessions() as editing:
        waiting_session = editing if delete_first else deleting
        waiting_pid = await waiting_session.scalar(text("SELECT pg_backend_pid()"))

        async def remove():
            await CategoryService(CategoryRepository(deleting)).delete_category(uid, ids[0])

        async def reclassify():
            await ContentService(
                content_repository=ContentRepository(editing),
                category_repository=CategoryRepository(editing),
                event_repository=EventRepository(editing),
            ).update_categories(
                user_id=uid,
                content_id=content_id,
                payload=ContentCategoryUpdate(category_ids=[ids[2]]),
            )

        first = asyncio.create_task(remove() if delete_first else reclassify())
        second = None
        try:
            await asyncio.wait_for(locked.wait(), 10)
            second = asyncio.create_task(reclassify() if delete_first else remove())
            await wait_until_blocked(sessions, waiting_pid)
            release.set()
            await asyncio.wait_for(asyncio.gather(first, second), 10)
        finally:
            release.set()
            await asyncio.gather(first, *([second] if second else []), return_exceptions=True)
    async with sessions() as session:
        links = list(
            await session.scalars(
                select(content_categories.c.category_id).where(
                    content_categories.c.content_id == content_id,
                )
            )
        )
        assert links == [ids[2]]
        assert await session.get(Category, ids[0]) is None
        events = list(
            await session.scalars(
                select(ContentEvent).where(ContentEvent.user_id == uid).order_by(ContentEvent.id)
            )
        )
        expected = (
            [([ids[0], ids[1]], [ids[1]]), ([ids[1]], [ids[2]])]
            if delete_first
            else [([ids[0], ids[1]], [ids[2]])]
        )
        assert [json.loads(item.metadata_json) for item in events] == [
            {"before_category_ids": before, "after_category_ids": after}
            for before, after in expected
        ]


@pytest.mark.asyncio
async def test_concurrent_create_and_rename_cannot_duplicate_name(concurrent_data, monkeypatch):
    sessions, uid, ids, _ = concurrent_data
    locked, release = asyncio.Event(), asyncio.Event()
    original = CategoryRepository.lock_user
    async with sessions() as creating, sessions() as editing:
        waiting_pid = await editing.scalar(text("SELECT pg_backend_pid()"))

        async def lock(self, user_id):
            await original(self, user_id)
            if self.session is creating:
                locked.set()
                await asyncio.wait_for(release.wait(), 10)

        monkeypatch.setattr(CategoryRepository, "lock_user", lock)
        first = asyncio.create_task(
            CategoryService(CategoryRepository(creating)).create_category(
                uid,
                CategoryCreate(name="Concurrent unique"),
            )
        )
        second = None
        try:
            await asyncio.wait_for(locked.wait(), 10)
            second = asyncio.create_task(
                CategoryService(CategoryRepository(editing)).update_category(
                    uid,
                    ids[0],
                    CategoryUpdate(name="CONCURRENT UNIQUE"),
                )
            )
            await wait_until_blocked(sessions, waiting_pid)
            release.set()
            results = await asyncio.wait_for(
                asyncio.gather(first, second, return_exceptions=True), 10
            )
            assert not isinstance(results[0], Exception)
            assert isinstance(results[1], InvalidStateError)
        finally:
            release.set()
            await asyncio.gather(first, *([second] if second else []), return_exceptions=True)


@pytest.mark.asyncio
async def test_new_reference_during_delete_causes_atomic_conflict(concurrent_data, monkeypatch):
    sessions, uid, ids, content_id = concurrent_data
    locked, release = asyncio.Event(), asyncio.Event()
    original = ContentRepository.lock_category_contents

    async def lock(self, user_id, category_id):
        result = await original(self, user_id, category_id)
        locked.set()
        await asyncio.wait_for(release.wait(), 10)
        return result

    monkeypatch.setattr(ContentRepository, "lock_category_contents", lock)
    async with sessions() as deleting, sessions() as creating:
        task = asyncio.create_task(
            CategoryService(CategoryRepository(deleting)).delete_category(
                uid,
                ids[0],
            )
        )
        try:
            await asyncio.wait_for(locked.wait(), 10)
            category = await creating.get(Category, ids[0])
            new_content = Content(
                user_id=uid,
                title="New reference",
                summary="",
                content_type=ContentType.LINK,
                source=ContentSource.WEB,
                categories=[category],
            )
            creating.add(new_content)
            await asyncio.wait_for(creating.commit(), 10)
            release.set()
            with pytest.raises(InvalidStateError):
                await asyncio.wait_for(task, 10)
        finally:
            release.set()
            await asyncio.gather(task, return_exceptions=True)
    async with sessions() as session:
        assert await session.get(Category, ids[0]) is not None
        for cid in [content_id, new_content.id]:
            assert ids[0] in list(
                await session.scalars(
                    select(content_categories.c.category_id).where(
                        content_categories.c.content_id == cid
                    )
                )
            )
        assert (
            list(await session.scalars(select(ContentEvent).where(ContentEvent.user_id == uid)))
            == []
        )
