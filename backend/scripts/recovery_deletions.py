"""Run only inside an isolated restored environment, before starting its API.

Historical API images run this source (ADR 0004, 0008). Their ledger validation and modules
predate account deletion records, so those records are applied here with SQL. Keep the
deletion order equal to app/services/account_deletion_service.py and the cleanup ID formula
equal to app/integrations/deletion_ledger.py.
"""

import asyncio
import json
import sys
from datetime import UTC, datetime
from uuid import NAMESPACE_URL, UUID, uuid5

from sqlalchemy import text

from app.db.session import AsyncSessionLocal
from app.integrations.deletion_ledger import DeletionIntent
from app.integrations.storage_client import get_storage_client
from app.models.image_deletion import ImageDeletion
from app.repositories.content_repository import ContentRepository
from app.services.image_deletion_service import (
    apply_deletion_intent,
    cleanup_image_deletion,
    deletion_job,
)

ACCOUNT_DELETION = "account_deletion"
# Rows that reference the user without a cascading foreign key go first. Shared categories
# have no user and stay.
ACCOUNT_DELETE_STATEMENTS = (
    "DELETE FROM content_events WHERE user_id = :user_id",
    "DELETE FROM recommendation_exposures WHERE user_id = :user_id",
    "DELETE FROM recommendation_batch_items WHERE batch_id IN "
    "(SELECT id FROM recommendation_batches WHERE user_id = :user_id)",
    "DELETE FROM recommendation_batches WHERE user_id = :user_id",
    "DELETE FROM contents WHERE user_id = :user_id",
    "DELETE FROM categories WHERE user_id = :user_id",
    "DELETE FROM users WHERE id = :user_id",
)


def aware(value):
    result = datetime.fromisoformat(value)
    if result.utcoffset() is None:
        raise ValueError("Deletion timestamps require a timezone")
    return result


def account_content_operation_id(operation_id, content_id, saved_at):
    saved_at = datetime.fromisoformat(saved_at).astimezone(UTC).isoformat()
    return str(uuid5(NAMESPACE_URL, f"account-deletion:{operation_id}:{content_id}:{saved_at}"))


async def apply_account(session, event):
    """Delete the account only if its id and creation time both match (ADR 0008)."""
    user_id = event["user_id"]
    if type(user_id) is not int or user_id < 1:
        raise ValueError("Invalid account deletion record")
    operation_id = str(UUID(event["operation_id"]))
    aware(event["deleted_at"])
    created_at = await session.scalar(
        text("SELECT created_at FROM users WHERE id = :user_id FOR UPDATE"), {"user_id": user_id}
    )
    if created_at is None or created_at != aware(event["user_created_at"]):
        return [], []
    rows = (await session.execute(
        text(
            "SELECT c.id AS content_id, c.saved_at, a.id AS asset_id, a.storage_backend, "
            "a.storage_key, a.sha256, a.size_bytes FROM contents c "
            "LEFT JOIN content_assets a ON a.content_id = c.id "
            "WHERE c.user_id = :user_id ORDER BY c.id, a.id"
        ),
        {"user_id": user_id},
    )).all()
    contents = {}
    for row in rows:
        content = contents.setdefault(
            row.content_id, {"saved_at": row.saved_at.isoformat(), "assets": []}
        )
        if row.asset_id is not None:
            content["assets"].append((row.asset_id, {
                "storage_backend": row.storage_backend, "storage_key": row.storage_key,
                "sha256": row.sha256, "size_bytes": row.size_bytes,
            }))
    deleted, operations = [], []
    for content_id, content in contents.items():
        deleted.append({"content_id": content_id,
                        "asset_ids": [asset_id for asset_id, _ in content["assets"]]})
        if not content["assets"]:
            continue
        operation = account_content_operation_id(operation_id, content_id, content["saved_at"])
        if await session.get(ImageDeletion, operation) is None:
            session.add(deletion_job({
                "operation_id": operation, "user_id": user_id, "content_id": content_id,
                "saved_at": content["saved_at"], "deleted_at": event["deleted_at"],
                "assets": [asset for _, asset in content["assets"]],
            }))
        operations.append(operation)
    for statement in ACCOUNT_DELETE_STATEMENTS:
        await session.execute(text(statement), {"user_id": user_id})
    return deleted, operations


async def apply(events):
    deleted, operations = [], []
    async with AsyncSessionLocal() as session:
        repository = ContentRepository(session)
        # Ledger order: an earlier image deletion is applied before a later account deletion.
        for value in events:
            if value.get("kind") == ACCOUNT_DELETION:
                account_deleted, account_operations = await apply_account(session, value)
                deleted += account_deleted
                operations += account_operations
                continue
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
