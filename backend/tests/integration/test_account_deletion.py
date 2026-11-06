"""Account deletion: ledger record, DB deletion, operator retry and restore replay (#251)."""

import asyncio
import json
import os
import sys
from datetime import date
from pathlib import Path
from uuid import uuid4

import pytest
from sqlalchemy import insert, select, text
from sqlalchemy.ext.asyncio import AsyncSession

import app.models  # noqa: F401  (registers every table on Base.metadata)
from app.db.base import Base
from app.integrations.deletion_ledger import get_deletion_ledger
from app.models.category import Category
from app.models.content_event import ContentEvent
from app.models.image_deletion import ImageDeletion
from app.models.recommendation import RecommendationBatch, RecommendationBatchItem
from app.models.user import User
from app.repositories.content_repository import ContentRepository
from app.services.account_deletion_service import (
    account_content_operation_id,
    apply_account_deletion,
    record_account_deletion,
)
from app.services.image_deletion_service import record_image_deletion, retry_image_deletions
from tests.integration.helpers import guest, link, request
from tests.integration.test_image_deletion import committed_api as committed_api, upload

pytestmark = pytest.mark.asyncio
BACKEND = Path(__file__).resolve().parents[2]
REPLAY_SOURCE = (BACKEND / "scripts" / "recovery_deletions.py").read_text()
# A historical API image has neither the account deletion module nor the new ledger names.
HISTORICAL_IMAGE = (
    "import sys\n"
    "import app.services.image_deletion_service\n"
    "import app.integrations.deletion_ledger as ledger\n"
    "sys.modules['app.services.account_deletion_service'] = None\n"
    "for name in ('ACCOUNT_DELETION', 'AccountDeletionIntent', 'DeletedContent',\n"
    "             'validate_deletion_event', 'deleted_contents'):\n"
    "    delattr(ledger, name)\n"
)
# Global upload quota counters are service state, not account data.
NOT_ACCOUNT_DATA = {"image_deletions", "image_storage_control", "image_transfer_counters"}


def session_for(connection):
    return AsyncSession(
        bind=connection, expire_on_commit=False, join_transaction_mode="create_savepoint"
    )


async def database_rows(connection):
    rows = {}
    for table in Base.metadata.sorted_tables:
        if table.name not in NOT_ACCOUNT_DATA:
            result = await connection.execute(select(table))
            rows[table.name] = sorted(repr(tuple(row)) for row in result)
    return rows


async def cleanup_rows(connection, user_id):
    rows = await connection.execute(
        select(ImageDeletion.operation_id, ImageDeletion.content_id, ImageDeletion.intent)
        .where(ImageDeletion.user_id == user_id)
        .order_by(ImageDeletion.content_id)
    )
    return [tuple(row) for row in rows]


async def user_exists(connection, user_id):
    return await connection.scalar(select(User.id).where(User.id == user_id)) is not None


async def recommended(api, connection, headers, user_id, content_id):
    """A recommendation item with an exposure and a card click that both reference it."""
    batch_id = await connection.scalar(
        insert(RecommendationBatch)
        .values(user_id=user_id, type="TODAY", recommendation_date=date(2000, 1, 1))
        .returning(RecommendationBatch.id)
    )
    item_id = await connection.scalar(
        insert(RecommendationBatchItem)
        .values(batch_id=batch_id, rank=1, target_kind="CONTENT",
                target_id_snapshot=content_id, content_id=content_id)
        .returning(RecommendationBatchItem.id)
    )
    await request(api, "POST", "recommendations/exposures", headers=headers, status=201,
                  json={"client_event_id": str(uuid4()), "recommendation_item_id": item_id})
    await connection.execute(insert(ContentEvent).values(
        user_id=user_id, content_id=content_id, event_type="card_clicked",
        recommendation_item_id=item_id,
    ))


async def test_account_with_every_kind_of_data_is_deleted_without_leftover_rows(
    api, database_connection, png_bytes, tmp_path,
):
    other_headers, _, other = await guest(api)
    other_categories = await request(api, "GET", "categories", headers=other_headers)
    personal = next(c for c in other_categories if c["name"] != "미분류")
    other_link = await link(api, other_headers, category_ids=[personal["id"]],
                            tag_names=["다른 계정 태그"])
    await upload(api, other_headers, png_bytes)
    await recommended(api, database_connection, other_headers, other["id"], other_link["id"])
    before = await database_rows(database_connection)

    tokens = await request(api, "POST", "auth/social/kakao", json={"token": "leaving-user"})
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}
    user = await request(api, "GET", "users/me", headers=headers)
    owned = await request(api, "POST", "categories", headers=headers, status=201,
                          json={"name": "탈퇴 계정 카테고리"})
    content = await link(api, headers, category_ids=[owned["id"]], tag_names=["탈퇴 태그"])
    await request(api, "POST", f"contents/{content['id']}/view", headers=headers, status=201,
                  json={"client_event_id": str(uuid4())})
    await recommended(api, database_connection, headers, user["id"], content["id"])
    images = [await upload(api, headers, png_bytes) for _ in range(2)]

    async with session_for(database_connection) as session:
        intent = await record_account_deletion(session, user["id"])
        operations = await apply_account_deletion(session, intent)
        await session.commit()

    # Nothing of the account remains; other accounts and shared categories are untouched.
    assert await database_rows(database_connection) == before
    shared = await database_connection.scalars(
        select(Category.name).where(Category.user_id.is_(None))
    )
    assert "미분류" in set(shared)
    # One ledger record for the deletion, without email or name (ADR 0008).
    events = get_deletion_ledger().read_verified_events()
    assert events[-1] == intent
    assert set(intent) == {
        "kind", "operation_id", "user_id", "user_created_at", "deleted_at", "contents",
    }
    assert intent["user_id"] == user["id"]
    assert [item["content_id"] for item in intent["contents"]] == [i["id"] for i in images]
    # One cleanup row per image content, shaped like an image deletion row.
    rows = await cleanup_rows(database_connection, user["id"])
    expected = [
        account_content_operation_id(intent["operation_id"], item["content_id"], item["saved_at"])
        for item in intent["contents"]
    ]
    assert [row[0] for row in rows] == operations == expected
    assert [row[2] for row in rows] == [
        {**item, "operation_id": operation, "user_id": user["id"],
         "deleted_at": intent["deleted_at"]}
        for item, operation in zip(intent["contents"], expected, strict=True)
    ]
    response = await api.get("/api/v1/users/me", headers=headers)
    assert response.status_code == 401


async def test_guest_account_without_images_gets_no_cleanup_rows(api, database_connection):
    headers, _, user = await guest(api)
    await link(api, headers)
    async with session_for(database_connection) as session:
        intent = await record_account_deletion(session, user["id"])
        assert await apply_account_deletion(session, intent) == []
        await session.commit()
    assert intent["contents"] == []
    assert not await user_exists(database_connection, user["id"])
    assert await cleanup_rows(database_connection, user["id"]) == []


async def test_missing_account_writes_no_record(database_connection):
    async with session_for(database_connection) as session:
        assert await record_account_deletion(session, 2_000_000_000) is None
    assert get_deletion_ledger().read_verified_checkpoint()["sequence"] == 0


async def test_retry_finishes_a_confirmed_deletion_including_images_saved_after_the_record(
    api, database_connection, png_bytes, tmp_path,
):
    headers, _, user = await guest(api)
    kept = await upload(api, headers, png_bytes)
    deleted_before = await upload(api, headers, png_bytes)
    await request(api, "DELETE", f"contents/{deleted_before['id']}", headers=headers, status=204)
    async with session_for(database_connection) as session:
        first = await record_account_deletion(session, user["id"])
        # The DB transaction fails after the ledger write (U2).
        await session.rollback()
    added = await upload(api, headers, png_bytes)
    async with session_for(database_connection) as session:
        assert await record_account_deletion(session, user["id"]) == first
        await session.rollback()
    assert get_deletion_ledger().read_verified_checkpoint()["sequence"] == 2
    # A separately deleted image is in neither the record nor the account's cleanup rows.
    assert [item["content_id"] for item in first["contents"]] == [kept["id"]]

    async with session_for(database_connection) as session:
        result = await retry_image_deletions(session)
    assert result == {"reconciled": 0, "attempted": 2, "pending": 0, "deleted_accounts": 1}
    assert not await user_exists(database_connection, user["id"])
    rows = await cleanup_rows(database_connection, user["id"])
    assert [row[1] for row in rows] == [kept["id"], deleted_before["id"], added["id"]]
    account_rows = {row[0] for row in rows if row[1] != deleted_before["id"]}
    assert account_rows == {
        account_content_operation_id(first["operation_id"], item["id"], item["saved_at"])
        for item in (kept, added)
    }
    assert not list(tmp_path.rglob("*.png"))

    async with session_for(database_connection) as session:
        again = await retry_image_deletions(session)
    assert again == {"reconciled": 0, "attempted": 0, "pending": 0, "deleted_accounts": 0}
    assert await cleanup_rows(database_connection, user["id"]) == rows


async def test_retry_keeps_an_account_with_the_same_number_but_another_creation_time(
    api, database_connection, png_bytes,
):
    headers, _, user = await guest(api)
    image = await upload(api, headers, png_bytes)
    async with session_for(database_connection) as session:
        await record_account_deletion(session, user["id"])
        await session.rollback()
    # A restore rewinds the id sequence; a later signup may reuse the deleted number (U1).
    await database_connection.execute(
        text("UPDATE users SET created_at = created_at + interval '1 second' WHERE id = :id"),
        {"id": user["id"]},
    )
    async with session_for(database_connection) as session:
        result = await retry_image_deletions(session)
    assert result == {"reconciled": 0, "attempted": 0, "pending": 0, "deleted_accounts": 0}
    assert await user_exists(database_connection, user["id"])
    await request(api, "GET", f"contents/{image['id']}", headers=headers)


async def test_restore_replay_applies_ledger_order_and_only_matching_accounts(
    api, database_connection, png_bytes, tmp_path, monkeypatch,
):
    import scripts.recovery_deletions as replay

    headers, _, user = await guest(api)
    deleted_first = await upload(api, headers, png_bytes)
    image = await upload(api, headers, png_bytes)
    content = await link(api, headers)
    other_headers, _, other = await guest(api)
    other_image = await upload(api, other_headers, png_bytes)
    async with session_for(database_connection) as session:
        repository = ContentRepository(session)
        image_record = await record_image_deletion(
            session,
            await repository.get_owned(user_id=user["id"], content_id=deleted_first["id"]),
        )
        account = await record_account_deletion(session, user["id"])
        await record_account_deletion(session, other["id"])
        # The restored DB predates all three deletions.
        await session.rollback()
    await database_connection.execute(
        text("UPDATE users SET created_at = created_at - interval '1 day' WHERE id = :id"),
        {"id": other["id"]},
    )
    events = get_deletion_ledger().read_verified_events()
    monkeypatch.setattr(replay, "AsyncSessionLocal", lambda: session_for(database_connection))

    result = await replay.apply(events)

    assert result["deleted"] == [
        {"content_id": deleted_first["id"], "asset_ids": [deleted_first["assets"][0]["id"]]},
        {"content_id": image["id"], "asset_ids": [image["assets"][0]["id"]]},
        {"content_id": content["id"], "asset_ids": []},
    ]
    assert not await user_exists(database_connection, user["id"])
    assert await user_exists(database_connection, other["id"])
    await request(api, "GET", f"contents/{other_image['id']}", headers=other_headers)
    # The earlier image record keeps its own cleanup row; the account adds only the rest.
    rows = await cleanup_rows(database_connection, user["id"])
    assert [(row[0], row[1]) for row in rows] == [
        (image_record, deleted_first["id"]),
        (account_content_operation_id(account["operation_id"], image["id"], image["saved_at"]),
         image["id"]),
    ]
    assert all(row[2]["deleted_at"] == account["deleted_at"] for row in rows[1:])
    assert len(list(tmp_path.rglob("*.png"))) == 1

    # Replaying the same ledger again adds nothing.
    assert await replay.apply(events) == {"deleted": []}
    assert await cleanup_rows(database_connection, user["id"]) == rows


async def test_replay_source_runs_as_python_c_without_new_modules(
    committed_api, png_bytes, tmp_path,
):
    client, headers, sessions = committed_api
    me = await request(client, "GET", "users/me", headers=headers)
    image = await upload(client, headers, png_bytes)
    content = await link(client, headers)
    async with sessions() as session:
        account = await record_account_deletion(session, me["id"])
        await session.rollback()
    process = await asyncio.create_subprocess_exec(
        sys.executable, "-c", HISTORICAL_IMAGE + REPLAY_SOURCE,
        cwd=BACKEND,
        env={
            **os.environ,
            "DATABASE_URL": os.environ["TEST_DATABASE_URL"],
            "STORAGE_ROOT": str(tmp_path),
            "YOUTUBE_SUMMARY_ENABLED": "false",
        },
        stdin=asyncio.subprocess.PIPE,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    output, error = await asyncio.wait_for(
        process.communicate(json.dumps({"events": [account]}).encode()), timeout=60
    )
    assert process.returncode == 0, error.decode()
    assert json.loads(output) == {"deleted": [
        {"content_id": image["id"], "asset_ids": [image["assets"][0]["id"]]},
        {"content_id": content["id"], "asset_ids": []},
    ]}
    async with sessions() as session:
        assert await session.get(User, me["id"]) is None
        job = await session.get(
            ImageDeletion,
            account_content_operation_id(account["operation_id"], image["id"], image["saved_at"]),
        )
        assert job.completed is True and job.content_id == image["id"]
    assert not list(tmp_path.rglob("*.png"))
    assert (await client.get("/api/v1/users/me", headers=headers)).status_code == 401


async def test_record_keeps_the_account_creation_time(api, database_connection):
    _, _, user = await guest(api)
    async with session_for(database_connection) as session:
        intent = await record_account_deletion(session, user["id"])
        created_at = await session.scalar(select(User.created_at).where(User.id == user["id"]))
        await session.rollback()
    assert intent["user_created_at"] == created_at.isoformat()
