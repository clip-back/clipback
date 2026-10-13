import hashlib
import json
from uuid import UUID

from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.content_repository import ContentRepository
from app.repositories.share_receipt_repository import PendingShareReceipt, ShareReceiptRepository
from app.schemas.content import ContentRead
from app.services.content_service import content_to_read


async def prepare_share_write(
    session: AsyncSession, *, user_id: int, key: UUID, kind: str, fingerprint: str,
) -> tuple[PendingShareReceipt, ContentRead | None]:
    pending = PendingShareReceipt(user_id, key, kind, fingerprint)
    receipt = await ShareReceiptRepository(session).begin(pending)
    if receipt is None:
        return pending, None
    if receipt.kind != pending.kind or receipt.fingerprint != pending.fingerprint:
        raise HTTPException(status_code=409, detail="Idempotency key belongs to another input")
    content = await ContentRepository(session).get_owned(
        user_id=user_id, content_id=receipt.content_id,
    )
    if content is None:
        raise HTTPException(status_code=410, detail="Previously saved content was deleted")
    return pending, content_to_read(content)


def share_fingerprint(fields: dict, image: bytes | None = None) -> str:
    encoded = json.dumps(fields, sort_keys=True, ensure_ascii=False, separators=(",", ":"))
    digest = hashlib.sha256(encoded.encode())
    if image is not None:
        digest.update(b"\0")
        digest.update(image)
    return digest.hexdigest()
