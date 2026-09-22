"""Durable single-consumer loop with short leases and fenced result application."""

import asyncio
import json
import logging
import time
from datetime import UTC, datetime, timedelta
from uuid import uuid4

from sqlalchemy import and_, func, or_, select

from app.core.config import Settings
from app.integrations.youtube_summary_client import SummaryError, VideoSummary
from app.models.content import Content
from app.models.content_event import ContentEventType
from app.models.summary_job import SummaryJob
from app.repositories.category_repository import CategoryRepository
from app.repositories.content_repository import ContentRepository
from app.repositories.event_repository import EventRepository

logger = logging.getLogger(__name__)


class SummaryWorker:
    def __init__(self, session_factory, client, config: Settings):
        self.sessions = session_factory
        self.client = client
        self.config = config

    async def claim(self):
        now = datetime.now(UTC)
        async with self.sessions() as session, session.begin():
            job = await session.scalar(
                select(SummaryJob)
                .where(
                    or_(
                        and_(SummaryJob.status == "queued", SummaryJob.next_run_at <= now),
                        and_(SummaryJob.status == "processing", SummaryJob.lease_expires_at <= now),
                    )
                )
                .order_by(SummaryJob.next_run_at, SummaryJob.content_id)
                .with_for_update(skip_locked=True)
                .limit(1)
            )
            if job is None:
                return None
            if job.attempts >= 2:
                job.status, job.error_code = "failed", "timeout"
                job.lease_token = job.lease_expires_at = None
                return None
            recovered = job.status == "processing"
            job.status = "processing"
            job.attempts += 1
            job.lease_token = str(uuid4())
            job.lease_expires_at = now + timedelta(minutes=5)
            job.error_code = None
            user_id = await session.scalar(
                select(Content.user_id).where(Content.id == job.content_id)
            )
            candidates = await CategoryRepository(session).list_recommendation_candidates(user_id)
            pending = await session.scalar(
                select(func.count())
                .select_from(SummaryJob)
                .where(SummaryJob.status.in_(["queued", "processing"]))
            )
            logger.info(
                json.dumps(
                    {
                        "event": "youtube_summary_claim",
                        "content_id": job.content_id,
                        "attempt": job.attempts,
                        "recovered": recovered,
                        "possible_duplicate_call": recovered,
                        "pending_count": pending,
                    }
                )
            )
            return (
                job.content_id,
                user_id,
                job.video_id,
                job.model,
                job.lease_token,
                [{"id": c.id, "name": c.name} for c in candidates],
            )

    async def run_once(self) -> bool:
        if not self.config.youtube_summary_enabled:
            return False
        claim = await self.claim()
        if claim is None:
            return False
        content_id, user_id, video_id, model, token, candidates = claim
        started = time.monotonic()
        result = error = None
        try:
            result = await self.client.summarize(video_id, model, candidates)
        except SummaryError as exc:
            error = exc
        logger.log(
            logging.WARNING if error else logging.INFO,
            json.dumps(
                {
                    "event": "youtube_summary_result",
                    "content_id": content_id,
                    "model": model,
                    "elapsed_seconds": round(time.monotonic() - started, 3),
                    "error_code": error.code if error else None,
                    "provider": error.provider if error else "gemini",
                    "http_status": error.http_status if error else None,
                    "provider_status": error.provider_status if error else None,
                    "retryable": error.retryable if error else False,
                    "usage": result.usage if result else getattr(error, "usage", {}),
                }
            ),
        )
        await self.finish(content_id, user_id, token, result, error)
        return True

    async def finish(
        self,
        content_id: int,
        user_id: int,
        token: str,
        result: VideoSummary | None,
        error: SummaryError | None,
    ):
        async with self.sessions() as session, session.begin():
            categories = CategoryRepository(session)
            # Same lock order as category deletion: user -> content -> job.
            await categories.lock_user(user_id)
            contents = ContentRepository(session)
            content = await contents.get_owned(
                user_id=user_id, content_id=content_id, for_update=True
            )
            if content is None:
                return
            job = await session.scalar(
                select(SummaryJob)
                .where(SummaryJob.content_id == content_id)
                .with_for_update()
                .execution_options(populate_existing=True)
            )
            now = datetime.now(UTC)
            if (
                job is None
                or job.status != "processing"
                or job.lease_token != token
                or job.lease_expires_at <= now
            ):
                logger.info(
                    json.dumps({"event": "youtube_summary_stale_result", "content_id": content_id})
                )
                return
            usage = result.usage if result else getattr(error, "usage", {})
            job.usage = [*job.usage, {"attempt": job.attempts, "tokens": usage}]
            job.lease_token = job.lease_expires_at = None
            if error:
                job.error_code = error.code
                if error.retryable and job.attempts < 2:
                    job.status = "queued"
                    job.next_run_at = now + timedelta(seconds=30)
                else:
                    job.status = "skipped" if error.skipped else "failed"
                return
            if result is None:
                raise ValueError("Summary result is required")
            if job.apply_title:
                content.title = result.title
            if job.apply_summary:
                content.summary = result.summary
            if job.apply_category and result.category_id is not None:
                recommended = await categories.get_owned(user_id, result.category_id)
                if recommended is not None:
                    before = sorted(c.id for c in content.categories)
                    after = [recommended.id]
                    if before != after:
                        await contents.replace_categories(content=content, categories=[recommended])
                        await EventRepository(session).create(
                            user_id=user_id,
                            content_id=content_id,
                            event_type=ContentEventType.CATEGORY_CHANGED,
                            metadata_json=json.dumps(
                                {"before_category_ids": before, "after_category_ids": after}
                            ),
                        )
            job.status, job.error_code = "completed", None

    async def run(self):
        while True:
            try:
                await self.run_once()
            except Exception as exc:
                # Do not log exception text: provider responses may contain sensitive data.
                logger.error(
                    json.dumps(
                        {
                            "event": "youtube_summary_worker_error",
                            "exception_type": type(exc).__name__,
                        }
                    )
                )
            await asyncio.sleep(2)
