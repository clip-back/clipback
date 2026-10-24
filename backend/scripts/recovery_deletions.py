"""Run only inside an isolated restored environment, before starting its API."""

import asyncio
import json
import sys

from app.db.session import AsyncSessionLocal
from app.integrations.deletion_ledger import DeletionIntent
from app.integrations.storage_client import get_storage_client
from app.repositories.content_repository import ContentRepository
from app.services.image_deletion_service import (
    apply_deletion_intent,
    cleanup_image_deletion,
)


async def apply(events):
    deleted, operations = [], []
    async with AsyncSessionLocal() as session:
        repository = ContentRepository(session)
        for value in events:
            event = DeletionIntent.model_validate(value).model_dump(mode="json")
            content = await repository.get_owned(
                user_id=event["user_id"], content_id=event["content_id"], for_update=True,
            )
            if not await apply_deletion_intent(repository, content, event):
                continue
            if content is not None:
                deleted.append({"content_id": content.id,
                                "asset_ids": [a.id for a in content.assets]})
            operations.append(event["operation_id"])
        await session.commit()
        for operation in operations:
            await cleanup_image_deletion(session, operation, get_storage_client())
    return {"deleted": deleted}


if __name__ == "__main__":
    try:
        print(json.dumps(asyncio.run(apply(json.load(sys.stdin)["events"]))))
    except Exception:
        print('{"error":"deletion_restore_failed"}')
        raise SystemExit(1) from None
