"""Orphan tags are cleaned after ordinary deletions and during isolated restore."""

import asyncio
import json
import sys

import pytest
from sqlalchemy import select, text

from app.integrations.deletion_ledger import get_deletion_ledger
from app.models.tag import Tag
from app.repositories.content_repository import ContentRepository
from app.services.account_deletion_service import record_account_deletion
from app.services.image_deletion_service import record_image_deletion
from scripts import image_backup_jobs, recovery_deletions
from scripts.recovery_point import completed_points
from tests.integration.helpers import guest, link, request
from tests.integration.test_account_deletion import session_for
from tests.integration.test_deletion_ledger_disposal import (
    maintain_env as maintain_env,
    world as world,
)
from tests.integration.test_image_deletion import committed_api as committed_api, upload

pytestmark = pytest.mark.asyncio

EXCLUSIVE = "fixture-exclusive-tag-435"
SHARED = "fixture-shared-tag-435"
DETACHED = "fixture-detached-tag-435"


async def replace_tags(client, headers, content, names):
    return await request(
        client, "PUT", f"contents/{content['id']}/tags", headers=headers,
        json={"tag_names": names},
    )


async def tag_names(connection, user_id):
    return set(await connection.scalars(select(Tag.name).where(Tag.user_id == user_id)))


@pytest.mark.parametrize("kind", ["link", "image"])
async def test_hourly_cleanup_keeps_shared_tag_after_content_deletion(
    kind, committed_api, png_bytes, world, maintain_env, monkeypatch, capsys, caplog,
):
    api, headers, sessions = committed_api
    user = await request(api, "GET", "users/me", headers=headers)
    if kind == "link":
        target = await link(api, headers, tag_names=[EXCLUSIVE, SHARED])
    else:
        target = await upload(api, headers, png_bytes)
        await replace_tags(api, headers, target, [EXCLUSIVE, SHARED])
    survivor = await link(
        api, headers, original_url="https://example.com/survivor", tag_names=[SHARED],
    )
    await request(api, "DELETE", f"contents/{target['id']}", headers=headers, status=204)
    async with sessions() as session:
        assert await tag_names(session, user["id"]) == {EXCLUSIVE, SHARED}
    world.point("fresh", world.ago(hours=1), None)
    monkeypatch.setattr(sys, "argv", ["image_backup_jobs", "maintain"])
    capsys.readouterr()
    caplog.clear()

    for expected in (1, 0):
        status = await asyncio.to_thread(image_backup_jobs.main)
        output = capsys.readouterr()
        assert status == 0
        report = json.loads(output.out)
        assert report.get("orphan_tags_deleted") == expected
        for name in (EXCLUSIVE, SHARED):
            assert name not in output.out
            assert name not in output.err
            assert name not in caplog.text

    async with sessions() as session:
        assert await tag_names(session, user["id"]) == {SHARED}
    detail = await request(api, "GET", f"contents/{survivor['id']}", headers=headers)
    assert [tag["name"] for tag in detail["tags"]] == [SHARED]


async def test_cleanup_sql_failure_fails_maintain_after_retention_and_ledger_disposal(
    committed_api, world, maintain_env, monkeypatch, capsys, caplog,
):
    api, headers, sessions = committed_api
    user = await request(api, "GET", "users/me", headers=headers)
    target = await link(api, headers, tag_names=[EXCLUSIVE])
    await request(api, "DELETE", f"contents/{target['id']}", headers=headers, status=204)
    world.point("fresh", world.ago(hours=1), None)
    world.point("expired", world.ago(days=7), None)
    await world.image(world.ago(days=29, hours=12))

    async with world.engine.begin() as connection:
        await connection.execute(text(f"""
            CREATE FUNCTION refuse_orphan_cleanup_test_delete() RETURNS trigger LANGUAGE plpgsql
            AS $$ BEGIN
                IF OLD.user_id = {int(user["id"])} THEN RAISE EXCEPTION '{EXCLUSIVE}'; END IF;
                RETURN OLD;
            END $$;
        """))
        await connection.execute(text("""
            CREATE TRIGGER refuse_orphan_cleanup_test_delete BEFORE DELETE ON tags
            FOR EACH ROW EXECUTE FUNCTION refuse_orphan_cleanup_test_delete()
        """))
    try:
        monkeypatch.setattr(sys, "argv", ["image_backup_jobs", "maintain"])
        capsys.readouterr()
        caplog.clear()
        status = await asyncio.to_thread(image_backup_jobs.main)
        output = capsys.readouterr()
    finally:
        async with world.engine.begin() as connection:
            await connection.execute(text("DROP TRIGGER refuse_orphan_cleanup_test_delete ON tags"))
            await connection.execute(text("DROP FUNCTION refuse_orphan_cleanup_test_delete()"))

    assert status == 1
    report = json.loads(output.out)
    assert report["passed"] is False and report["error"] == "backup_job_failed"
    assert EXCLUSIVE not in output.out + output.err + caplog.text
    assert completed_points(world.store) == ["fresh"]
    assert world.start() == 1 and await world.rows() == set()
    async with sessions() as session:
        assert await tag_names(session, user["id"]) == {EXCLUSIVE}


@pytest.mark.parametrize("matches", [True, False], ids=["matching-image", "reused-image-id"])
async def test_image_replay_cleans_orphans_and_preserves_other_links(
    api, database_connection, png_bytes, monkeypatch, matches,
):
    headers, _, user = await guest(api)
    target = await upload(api, headers, png_bytes)
    await replace_tags(api, headers, target, [EXCLUSIVE, SHARED])
    survivor = await link(api, headers, tag_names=[SHARED, DETACHED])
    await replace_tags(api, headers, survivor, [SHARED])

    async with session_for(database_connection) as session:
        content = await ContentRepository(session).get_owned(
            user_id=user["id"], content_id=target["id"],
        )
        await record_image_deletion(session, content)
        await session.rollback()
    if not matches:
        await database_connection.execute(
            text("UPDATE contents SET saved_at = saved_at - interval '1 day' WHERE id = :id"),
            {"id": target["id"]},
        )
    events = get_deletion_ledger().read_verified_events()
    monkeypatch.setattr(
        recovery_deletions, "AsyncSessionLocal", lambda: session_for(database_connection),
    )

    applied = await recovery_deletions.apply(events)
    expected_deleted = [{"content_id": target["id"], "asset_ids": [target["assets"][0]["id"]]}]
    assert applied == {"deleted": expected_deleted if matches else []}
    expected_tags = {SHARED} if matches else {EXCLUSIVE, SHARED}
    assert await tag_names(database_connection, user["id"]) == expected_tags
    assert await recovery_deletions.apply(events) == {"deleted": []}
    assert await tag_names(database_connection, user["id"]) == expected_tags
    detail = await request(api, "GET", f"contents/{survivor['id']}", headers=headers)
    assert [tag["name"] for tag in detail["tags"]] == [SHARED]


async def test_account_replay_keeps_shared_tag_of_a_living_account(
    api, database_connection, monkeypatch,
):
    headers, _, user = await guest(api)
    target = await link(api, headers, tag_names=[EXCLUSIVE, SHARED])
    other_headers, _, other = await guest(api)
    survivor = await link(api, other_headers, tag_names=[SHARED, DETACHED])
    await replace_tags(api, other_headers, survivor, [SHARED])
    async with session_for(database_connection) as session:
        await record_account_deletion(session, user["id"])
        await session.rollback()
    events = get_deletion_ledger().read_verified_events()
    monkeypatch.setattr(
        recovery_deletions, "AsyncSessionLocal", lambda: session_for(database_connection),
    )

    assert await recovery_deletions.apply(events) == {
        "deleted": [{"content_id": target["id"], "asset_ids": []}],
    }
    assert await tag_names(database_connection, user["id"]) == set()
    assert await tag_names(database_connection, other["id"]) == {SHARED}
    assert await recovery_deletions.apply(events) == {"deleted": []}
    detail = await request(api, "GET", f"contents/{survivor['id']}", headers=other_headers)
    assert [tag["name"] for tag in detail["tags"]] == [SHARED]
