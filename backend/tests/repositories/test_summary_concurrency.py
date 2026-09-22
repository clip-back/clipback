import asyncio
from types import SimpleNamespace

import pytest
from sqlalchemy import select

from app.core.config import Settings
from app.integrations.youtube_summary_client import VideoSummary
from app.models.summary_job import SummaryJob
from app.repositories.category_repository import CategoryRepository
from app.repositories.content_repository import ContentRepository
from app.repositories.event_repository import EventRepository
from app.schemas.content import ContentCategoryUpdate
from app.services.category_service import CategoryService
from app.services.content_service import ContentService
from app.services.summary_worker import SummaryWorker
from tests.repositories.test_category_concurrency import concurrent_data as concurrent_data

pytestmark = pytest.mark.asyncio


async def setup(sessions, content_id):
    async with sessions() as session:
        session.add(
            SummaryJob(
                content_id=content_id,
                video_id="dQw4w9WgXcQ",
                status="queued",
                model="test",
                apply_title=True,
                apply_summary=True,
                apply_category=True,
            )
        )
        await session.commit()
    return SummaryWorker(
        sessions,
        None,
        Settings(
            _env_file=None,
            youtube_summary_enabled=True,
            gemini_api_key="test",
            youtube_data_api_key="test",
        ),
    )


async def test_distinct_connections_claim_once(concurrent_data):
    sessions, uid, ids, content_id = concurrent_data
    worker = await setup(sessions, content_id)
    claims = await asyncio.gather(worker.claim(), worker.claim())
    assert sum(item is not None for item in claims) == 1
    async with sessions() as session:
        job = await session.get(SummaryJob, content_id)
        assert job.attempts == 1


@pytest.mark.parametrize("action", ["manual", "delete_category", "delete_content"])
async def test_external_wait_releases_connection_and_preserves_user_action(concurrent_data, action):
    sessions, uid, ids, content_id = concurrent_data
    worker = await setup(sessions, content_id)
    started, release = asyncio.Event(), asyncio.Event()

    async def summarize(*args):
        started.set()
        await release.wait()
        return VideoSummary("완료", "핵심 요약.", ids[2], {})

    worker.client = SimpleNamespace(summarize=summarize)
    task = asyncio.create_task(worker.run_once())
    try:
        await asyncio.wait_for(started.wait(), 5)
        async with asyncio.timeout(5), sessions() as session:
            service = ContentService(
                ContentRepository(session), CategoryRepository(session), EventRepository(session)
            )
            if action == "manual":
                await service.update_categories(
                    user_id=uid,
                    content_id=content_id,
                    payload=ContentCategoryUpdate(category_ids=ids[:2]),
                )
            elif action == "delete_category":
                await CategoryService(CategoryRepository(session)).delete_category(uid, ids[0])
            else:
                await service.delete_content(user_id=uid, content_id=content_id)
        release.set()
        await asyncio.wait_for(task, 5)
        async with sessions() as session:
            content = await ContentRepository(session).get_owned(user_id=uid, content_id=content_id)
            if action == "delete_content":
                assert content is None
                assert (
                    await session.scalar(
                        select(SummaryJob).where(SummaryJob.content_id == content_id)
                    )
                    is None
                )
            else:
                expected = ids[:2] if action == "manual" else ids[1:2]
                assert sorted(c.id for c in content.categories) == sorted(expected)
                assert content.summary_job.status == "completed"
    finally:
        release.set()
        if not task.done():
            task.cancel()
            await asyncio.gather(task, return_exceptions=True)
