import hashlib
from dataclasses import dataclass
from uuid import UUID

from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncConnection, AsyncSession

from app.models.share_receipt import ShareReceipt


@dataclass
class PendingShareReceipt:
    user_id: int
    key: UUID
    kind: str
    fingerprint: str
    commit_attempted: bool = False
    content_id: int | None = None

    def for_content(self, content_id: int) -> ShareReceipt:
        self.content_id = content_id
        return ShareReceipt(
            user_id=self.user_id, key=self.key, kind=self.kind,
            fingerprint=self.fingerprint, content_id=content_id,
        )


class ShareReceiptRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def lock(self, user_id: int, key: UUID) -> None:
        # Transaction-scoped cross-process serialization also covers the absent-row case.
        # Hash collisions merely serialize unrelated operations; they cannot replay them.
        digest = hashlib.sha256(f"share:{user_id}:{key}".encode()).digest()
        lock_id = int.from_bytes(digest[:8], "big", signed=True)
        await self.session.execute(text("SELECT pg_advisory_xact_lock(:key)"), {"key": lock_id})

    async def find(self, user_id: int, key: UUID) -> ShareReceipt | None:
        return await self.session.scalar(select(ShareReceipt).where(
            ShareReceipt.user_id == user_id, ShareReceipt.key == key,
        ))

    async def begin(self, pending: PendingShareReceipt) -> ShareReceipt | None:
        await self.lock(pending.user_id, pending.key)
        return await self.find(pending.user_id, pending.key)

    async def committed_after_failure(self, pending: PendingShareReceipt) -> bool:
        # A commit acknowledgement can be lost. Reacquiring the transaction lock in a
        # fresh connection waits for that commit/rollback before deciding file cleanup.
        bind = self.session.bind
        engine = bind.engine if isinstance(bind, AsyncConnection) else bind
        async with AsyncSession(engine) as verification:
            repository = ShareReceiptRepository(verification)
            await repository.lock(pending.user_id, pending.key)
            receipt = await repository.find(pending.user_id, pending.key)
            # A successful concurrent retry may have committed after this attempt
            # rolled back. Its receipt must not retain this attempt's orphan file.
            return receipt is not None and receipt.content_id == pending.content_id
