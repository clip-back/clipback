import hashlib
import json
from uuid import UUID

from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.category_submission import CategorySubmission


class CategorySubmissionRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def lock(self, user_id: int, key: UUID) -> None:
        digest = hashlib.sha256(f"category:{user_id}:{key}".encode()).digest()
        lock_id = int.from_bytes(digest[:8], "big", signed=True)
        await self.session.execute(text("SELECT pg_advisory_xact_lock(:key)"), {"key": lock_id})

    async def find(self, user_id: int, key: UUID) -> CategorySubmission | None:
        return await self.session.scalar(select(CategorySubmission).where(
            CategorySubmission.user_id == user_id, CategorySubmission.key == key,
        ))

    async def save(self, submission: CategorySubmission) -> None:
        self.session.add(submission)
        await self.session.flush()


def category_fingerprint(kind: str, target_id: int | None, fields: dict) -> str:
    encoded = json.dumps(
        {"kind": kind, "target_id": target_id, "fields": fields},
        sort_keys=True, ensure_ascii=False, separators=(",", ":"),
    )
    return hashlib.sha256(encoded.encode()).hexdigest()
