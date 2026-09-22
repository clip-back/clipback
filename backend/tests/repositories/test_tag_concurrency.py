import asyncio

import pytest
from sqlalchemy import select, text

from app.models.content import Content, ContentSource, ContentType
from app.models.tag import Tag
from app.repositories.category_repository import CategoryRepository
from app.repositories.content_repository import ContentRepository
from app.repositories.event_repository import EventRepository
from app.repositories.tag_repository import TagRepository
from app.schemas.content import ContentTagUpdate
from app.services.content_service import ContentService
from tests.repositories.test_category_concurrency import concurrent_data as concurrent_data

pytestmark = pytest.mark.asyncio


async def replace(session, user_id, content_id, names):
    return await ContentService(
        content_repository=ContentRepository(session),
        category_repository=CategoryRepository(session),
        event_repository=EventRepository(session),
        tag_repository=TagRepository(session),
    ).update_tags(user_id=user_id, content_id=content_id, payload=ContentTagUpdate(tag_names=names))


async def wait_for_block_or_completion(sessions, task, waiting_pid, holding_pid):
    async with asyncio.timeout(10), sessions() as observer:
        while not task.done():
            if await observer.scalar(
                text("SELECT :holding = ANY(pg_blocking_pids(:waiting))"),
                {"holding": holding_pid, "waiting": waiting_pid},
            ):
                return True
            await asyncio.sleep(0.01)
    return False


@pytest.mark.parametrize(
    ("initial", "first_names", "second_names"),
    [
        ([], ["first"], ["second"]),
        (["old"], ["first", "shared"], ["second", "shared"]),
        (["old"], [], ["second"]),
        (["old"], ["first"], []),
        (["same"], ["same"], ["second"]),
        ([], [], ["second"]),
        (["same"], ["same"], ["same"]),
    ],
)
async def test_concurrent_replacements_never_merge_tag_sets(
    concurrent_data, monkeypatch, initial, first_names, second_names
):
    sessions, uid, _, content_id = concurrent_data
    async with sessions() as setup:
        await replace(setup, uid, content_id, initial)
    loaded, release, second_done = asyncio.Event(), asyncio.Event(), asyncio.Event()
    original_get = ContentRepository.get_owned

    async with sessions() as first, sessions() as second:
        first_pid = await first.scalar(text("SELECT pg_backend_pid()"))
        second_pid = await second.scalar(text("SELECT pg_backend_pid()"))
        # Keep stale relationships in this session to also check the locked reload.
        cached = await ContentRepository(second).get_owned(user_id=uid, content_id=content_id)
        assert [tag.name for tag in cached.tags] == initial

        async def get_owned(self, **kwargs):
            result = await original_get(self, **kwargs)
            if self.session is first and not loaded.is_set():
                loaded.set()
                await asyncio.wait_for(release.wait(), 10)
            return result

        monkeypatch.setattr(ContentRepository, "get_owned", get_owned)
        original_commit = first.commit

        async def commit():
            await original_commit()
            # Let the next writer finish before the first service call returns.
            await asyncio.wait_for(second_done.wait(), 10)

        async def second_update():
            try:
                return await replace(second, uid, content_id, second_names)
            finally:
                second_done.set()

        monkeypatch.setattr(first, "commit", commit)
        tasks = [asyncio.create_task(replace(first, uid, content_id, first_names))]
        try:
            await asyncio.wait_for(loaded.wait(), 10)
            tasks.append(asyncio.create_task(second_update()))
            blocked = await wait_for_block_or_completion(sessions, tasks[1], second_pid, first_pid)
            release.set()
            results = await asyncio.wait_for(asyncio.gather(*tasks), 10)
            assert not first.in_transaction() and not second.in_transaction()
        finally:
            release.set()
            for task in tasks:
                if not task.done():
                    task.cancel()
            await asyncio.gather(*tasks, return_exceptions=True)

    async with sessions() as checking:
        final = await ContentRepository(checking).get_owned(user_id=uid, content_id=content_id)
        assert sorted(tag.name for tag in final.tags) == sorted(second_names)
    assert [sorted(tag.name for tag in result.tags) for result in results] == [
        sorted(first_names),
        sorted(second_names),
    ]
    assert blocked, "The second writer must wait for the first writer's content row lock"


async def test_failed_writer_rolls_back_and_unblocks_next_writer(concurrent_data, monkeypatch):
    sessions, uid, _, content_id = concurrent_data
    async with sessions() as setup:
        await replace(setup, uid, content_id, ["old"])
    staged, release = asyncio.Event(), asyncio.Event()

    async with sessions() as first, sessions() as second:
        first_pid = await first.scalar(text("SELECT pg_backend_pid()"))
        second_pid = await second.scalar(text("SELECT pg_backend_pid()"))

        async def fail_commit():
            staged.set()
            await asyncio.wait_for(release.wait(), 10)
            raise RuntimeError("injected commit failure")

        monkeypatch.setattr(first, "commit", fail_commit)
        tasks = [asyncio.create_task(replace(first, uid, content_id, ["failed"]))]
        try:
            await asyncio.wait_for(staged.wait(), 10)
            tasks.append(asyncio.create_task(replace(second, uid, content_id, ["after"])))
            assert await wait_for_block_or_completion(sessions, tasks[1], second_pid, first_pid)
            release.set()
            results = await asyncio.wait_for(asyncio.gather(*tasks, return_exceptions=True), 10)
            assert isinstance(results[0], RuntimeError)
            assert str(results[0]) == "injected commit failure"
            assert [tag.name for tag in results[1].tags] == ["after"]
            assert not first.in_transaction() and not second.in_transaction()
        finally:
            release.set()
            for task in tasks:
                if not task.done():
                    task.cancel()
            await asyncio.gather(*tasks, return_exceptions=True)

    async with sessions() as checking:
        final = await ContentRepository(checking).get_owned(user_id=uid, content_id=content_id)
        assert [tag.name for tag in final.tags] == ["after"]
        names = set(await checking.scalars(select(Tag.name).where(Tag.user_id == uid)))
        assert names == {"old", "after"}


async def test_content_lock_does_not_block_another_contents_tags(concurrent_data, monkeypatch):
    sessions, uid, _, content_id = concurrent_data
    async with sessions() as setup:
        other = Content(
            user_id=uid,
            title="Other",
            summary="",
            content_type=ContentType.LINK,
            source=ContentSource.WEB,
        )
        setup.add(other)
        await setup.commit()
        other_id = other.id

    loaded, release = asyncio.Event(), asyncio.Event()
    original_get = ContentRepository.get_owned
    async with sessions() as first, sessions() as second:

        async def get_owned(self, **kwargs):
            result = await original_get(self, **kwargs)
            if self.session is first:
                loaded.set()
                await asyncio.wait_for(release.wait(), 10)
            return result

        monkeypatch.setattr(ContentRepository, "get_owned", get_owned)
        task = asyncio.create_task(replace(first, uid, content_id, ["first"]))
        try:
            await asyncio.wait_for(loaded.wait(), 10)
            result = await asyncio.wait_for(replace(second, uid, other_id, ["other"]), 10)
            assert [tag.name for tag in result.tags] == ["other"]
            assert not task.done()
            release.set()
            await asyncio.wait_for(task, 10)
        finally:
            release.set()
            if not task.done():
                task.cancel()
            await asyncio.gather(task, return_exceptions=True)
