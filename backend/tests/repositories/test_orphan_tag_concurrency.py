import asyncio

import pytest
from sqlalchemy import insert, select, text

from app.models.tag import Tag
from app.repositories.content_repository import ContentRepository
from app.repositories.tag_repository import TagRepository
from scripts.image_backup_jobs import delete_orphan_tags
from tests.repositories.test_category_concurrency import concurrent_data as concurrent_data
from tests.repositories.test_tag_concurrency import replace, wait_for_block_or_completion

pytestmark = pytest.mark.asyncio


async def seed_tag(sessions, user_id, name):
    async with sessions.begin() as session:
        return await session.scalar(
            insert(Tag)
            .values(user_id=user_id, name=name, normalized_name=name.casefold())
            .returning(Tag.id)
        )


async def test_tag_save_recreates_an_orphan_claimed_by_cleanup(concurrent_data):
    sessions, user_id, _, content_id = concurrent_data
    old_id = await seed_tag(sessions, user_id, "Reused")

    async with sessions() as cleaner, sessions() as writer:
        cleaner_pid = await cleaner.scalar(text("SELECT pg_backend_pid()"))
        writer_pid = await writer.scalar(text("SELECT pg_backend_pid()"))
        assert await delete_orphan_tags(cleaner) == 1
        save = asyncio.create_task(replace(writer, user_id, content_id, ["Reused"]))
        try:
            assert await wait_for_block_or_completion(sessions, save, writer_pid, cleaner_pid)
            await cleaner.commit()
            result = await asyncio.wait_for(save, timeout=10)
        finally:
            if not save.done():
                save.cancel()
            await asyncio.gather(save, return_exceptions=True)

    [tag] = result.tags
    assert tag.name == "Reused"
    assert tag.id != old_id
    async with sessions() as session:
        saved = await ContentRepository(session).get_owned(user_id=user_id, content_id=content_id)
        assert [item.id for item in saved.tags] == [tag.id]


async def test_cleanup_skips_an_orphan_with_an_uncommitted_link(concurrent_data):
    sessions, user_id, _, content_id = concurrent_data
    tag_id = await seed_tag(sessions, user_id, "Reused")

    async with sessions() as writer, sessions.begin() as cleaner:
        content_repository = ContentRepository(writer)
        content = await content_repository.get_owned(user_id=user_id, content_id=content_id)
        tags = await TagRepository(writer).get_or_create_many(user_id=user_id, names=["Reused"])
        await content_repository.replace_tags(content=content, tags=tags)
        await cleaner.execute(text("SET LOCAL lock_timeout = '500ms'"))
        assert await delete_orphan_tags(cleaner) == 0
        await writer.commit()

    async with sessions() as session:
        saved = await ContentRepository(session).get_owned(user_id=user_id, content_id=content_id)
        assert [tag.id for tag in saved.tags] == [tag_id]


async def test_second_cleanup_finds_no_more_orphans(concurrent_data):
    sessions, user_id, _, content_id = concurrent_data
    orphan_id = await seed_tag(sessions, user_id, "Orphan")
    async with sessions() as session:
        await replace(session, user_id, content_id, ["Attached"])

    async with sessions.begin() as session:
        assert await delete_orphan_tags(session) == 1
    async with sessions.begin() as session:
        assert await delete_orphan_tags(session) == 0
        assert await session.scalar(select(Tag.id).where(Tag.id == orphan_id)) is None
        content = await ContentRepository(session).get_owned(user_id=user_id, content_id=content_id)
        assert [tag.name for tag in content.tags] == ["Attached"]


async def test_cleanup_rechecks_after_writer_commits_between_snapshot_and_tag_lock(concurrent_data):
    sessions, user_id, _, content_id = concurrent_data
    tag_id = await seed_tag(sessions, user_id, "Reused")

    async with sessions() as writer, sessions() as cleaner:
        writer_pid = await writer.scalar(text("SELECT pg_backend_pid()"))
        cleaner_pid = await cleaner.scalar(text("SELECT pg_backend_pid()"))
        await writer.execute(text("SELECT pg_advisory_xact_lock(4350435)"))
        repository = ContentRepository(writer)
        content = await repository.get_owned(user_id=user_id, content_id=content_id)
        tags = await TagRepository(writer).get_or_create_many(user_id=user_id, names=["Reused"])
        await repository.replace_tags(content=content, tags=tags)
        # Pause only the cleaner's scan after its snapshot and before it locks a tag row.
        # The real content_tags table and its CASCADE foreign key remain in use for writes.
        await cleaner.execute(text("""
            CREATE TEMP VIEW content_tags AS
            SELECT content_id, tag_id FROM public.content_tags
            OFFSET (SELECT 0 FROM pg_advisory_xact_lock(4350435))
        """))
        cleanup = asyncio.create_task(delete_orphan_tags(cleaner))
        try:
            assert await wait_for_block_or_completion(sessions, cleanup, cleaner_pid, writer_pid)
            await writer.commit()
            removed = await asyncio.wait_for(cleanup, timeout=10)
        finally:
            if not cleanup.done():
                cleanup.cancel()
            await asyncio.gather(cleanup, return_exceptions=True)
        await cleaner.execute(text("DROP VIEW pg_temp.content_tags"))
        await cleaner.commit()

    async with sessions() as session:
        saved = await ContentRepository(session).get_owned(user_id=user_id, content_id=content_id)
        assert [tag.id for tag in saved.tags] == [tag_id]
    assert removed == 0
