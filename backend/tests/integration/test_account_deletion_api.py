"""`DELETE /users/me`: the app's account deletion request (#253, spec state and order tables)."""

import asyncio
import threading
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

import pytest
import pytest_asyncio
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.integrations.deletion_ledger import LedgerUnavailableError, get_deletion_ledger
from app.models.image_deletion import ImageDeletion
from app.services import account_deletion_service
from app.services.image_deletion_service import retry_image_deletions
from app.services.maintenance import MaintenanceError, MaintenanceGate
from tests.integration.helpers import guest, link, request
from tests.integration.test_account_deletion import cleanup_rows, session_for, user_exists
from tests.integration.test_image_deletion import committed_api as committed_api, upload

pytestmark = pytest.mark.asyncio
ME = "/api/v1/users/me"
REASONS = {"reasons": ["low_usage", "other"]}
SEOUL = ZoneInfo("Asia/Seoul")


async def delete_me(api, headers=None, **body):
    return await api.request("DELETE", ME, headers=headers or {}, **body)


async def reason_rows(connection):
    rows = await connection.execute(
        text("SELECT reasons, deleted_on FROM account_deletion_reasons ORDER BY id")
    )
    return [tuple(row) for row in rows]


def ledger_events():
    return get_deletion_ledger().read_verified_events()


async def account_with_data(api, png_bytes):
    """A social account with a link and an image, so every deletion step has work to do."""
    tokens = await request(api, "POST", "auth/social/kakao", json={"token": "leaving"})
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}
    user = await request(api, "GET", "users/me", headers=headers)
    content = await link(api, headers)
    image = await upload(api, headers, png_bytes)
    return headers, user, content, image


async def unchanged(api, connection, headers, user, content, image, png_bytes):
    """The account, its contents and its original are all still there."""
    assert (await request(api, "GET", "users/me", headers=headers))["id"] == user["id"]
    await request(api, "GET", f"contents/{content['id']}", headers=headers)
    original = await api.get(image["assets"][0]["download_url"], headers=headers)
    assert original.status_code == 200 and original.content == png_bytes
    assert await reason_rows(connection) == []


async def test_delete_me_deletes_the_account_once_and_records_only_reasons_and_date(
    api, database_connection, png_bytes, tmp_path,
):
    other_headers, _, other = await guest(api)
    other_content = await link(api, other_headers)
    headers, user, _, image = await account_with_data(api, png_bytes)
    before = datetime.now(SEOUL).date()

    response = await delete_me(api, headers, json=REASONS)

    after = datetime.now(SEOUL).date()
    assert response.status_code == 204 and response.content == b""
    assert not await user_exists(database_connection, user["id"])
    await request(api, "GET", "users/me", headers=headers, status=401)
    # One ledger record for the whole deletion, holding the image contents (U3).
    events = ledger_events()
    assert len(events) == 1 and events[0]["kind"] == "account_deletion"
    assert events[0]["user_id"] == user["id"]
    assert [item["content_id"] for item in events[0]["contents"]] == [image["id"]]
    # The original is removed after the commit; its cleanup row is complete.
    assert [row[1] for row in await cleanup_rows(database_connection, user["id"])] == [image["id"]]
    assert await database_connection.scalar(
        select(ImageDeletion.completed).where(ImageDeletion.user_id == user["id"])
    )
    assert list(tmp_path.rglob("*.png")) == []
    # The reason record has no account number, email or name (D18).
    columns = await database_connection.scalars(text(
        "SELECT column_name FROM information_schema.columns "
        "WHERE table_name = 'account_deletion_reasons' ORDER BY column_name"
    ))
    assert list(columns) == ["deleted_on", "id", "reasons"]
    [(reasons, deleted_on)] = await reason_rows(database_connection)
    assert reasons == ["low_usage", "other"]
    assert deleted_on in {before, after}
    # Another account is untouched.
    assert (await request(api, "GET", "users/me", headers=other_headers))["id"] == other["id"]
    await request(api, "GET", f"contents/{other_content['id']}", headers=other_headers)


async def test_same_social_account_signs_up_again_as_a_new_empty_account(api, png_bytes):
    headers, user, _, _ = await account_with_data(api, png_bytes)
    defaults = {c["name"] for c in await request(api, "GET", "categories", headers=headers)}
    await request(api, "POST", "categories", headers=headers, status=201, json={"name": "내 분류"})
    await request(api, "DELETE", "users/me", headers=headers, json=REASONS, status=204)

    tokens = await request(api, "POST", "auth/social/kakao", json={"token": "leaving"})
    assert tokens["is_new_user"] is True
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}
    assert (await request(api, "GET", "users/me", headers=headers))["id"] != user["id"]
    assert (await request(api, "GET", "feed", headers=headers))["total_count"] == 0
    names = {c["name"] for c in await request(api, "GET", "categories", headers=headers)}
    assert names == defaults


@pytest.mark.parametrize("body", [
    pytest.param({}, id="no-body"),
    pytest.param({"content": b'{"reasons": ["rejoin"]', "headers": {
        "Content-Type": "application/json"}}, id="broken-json"),
    pytest.param({"content": b"reasons=rejoin", "headers": {
        "Content-Type": "application/x-www-form-urlencoded"}}, id="not-json"),
    pytest.param({"json": {}}, id="no-list"),
    pytest.param({"json": {"reasons": []}}, id="empty-list"),
    pytest.param({"json": {"reasons": ["unknown"]}}, id="unknown-value"),
    pytest.param({"json": {"reasons": None}}, id="list-null"),
    pytest.param({"json": {"reasons": "rejoin"}}, id="list-string"),
    pytest.param({"json": {"reasons": 1}}, id="list-number"),
    pytest.param({"json": {"reasons": {"rejoin": True}}}, id="list-object"),
    pytest.param({"json": {"reasons": [None]}}, id="item-null"),
    pytest.param({"json": {"reasons": [1]}}, id="item-number"),
    pytest.param({"json": {"reasons": [{"reason": "rejoin"}]}}, id="item-object"),
    pytest.param({"json": {"reasons": [["rejoin"]]}}, id="item-list"),
    pytest.param({"json": {"reasons": [""]}}, id="item-empty-string"),
    pytest.param({"json": {"reasons": ["REJOIN"]}}, id="item-upper-case"),
    pytest.param({"json": {"reasons": ["Low_Usage"]}}, id="item-mixed-case"),
    pytest.param({"json": {"reasons": ["rejoin "]}}, id="item-trailing-space"),
    pytest.param({"json": {"reasons": ["rejoin", "rejoin"]}}, id="duplicate"),
    pytest.param({"json": ["rejoin"]}, id="top-level-list"),
    pytest.param({"content": b"null", "headers": {
        "Content-Type": "application/json"}}, id="top-level-null"),
])
async def test_invalid_body_is_422_and_changes_nothing(
    api, database_connection, png_bytes, body,
):
    headers, user, content, image = await account_with_data(api, png_bytes)
    sent = {**headers, **body.get("headers", {})}

    response = await delete_me(api, sent, **{k: v for k, v in body.items() if k != "headers"})

    assert response.status_code == 422, response.text
    await unchanged(api, database_connection, headers, user, content, image, png_bytes)
    assert ledger_events() == []


async def test_every_allowed_reason_is_accepted(api, database_connection):
    headers, _, _ = await guest(api)
    reasons = ["rejoin", "low_usage", "privacy_security", "other"]
    await request(api, "DELETE", "users/me", headers=headers, json={"reasons": reasons},
                  status=204)
    assert [row[0] for row in await reason_rows(database_connection)] == [reasons]


@pytest.mark.parametrize("authorization", [None, "Bearer not-a-token", "Basic abc"])
async def test_missing_or_invalid_session_is_401(
    api, database_connection, png_bytes, authorization,
):
    headers, user, content, image = await account_with_data(api, png_bytes)
    sent = {"Authorization": authorization} if authorization else {}
    assert (await delete_me(api, sent, json=REASONS)).status_code == 401
    await unchanged(api, database_connection, headers, user, content, image, png_bytes)
    assert ledger_events() == []


async def test_already_deleted_account_is_401(api, database_connection):
    headers, _, _ = await guest(api)
    await request(api, "DELETE", "users/me", headers=headers, json=REASONS, status=204)
    assert (await delete_me(api, headers, json=REASONS)).status_code == 401
    assert len(ledger_events()) == 1
    assert len(await reason_rows(database_connection)) == 1


async def test_ledger_failure_is_503_and_keeps_the_account(
    api, database_connection, png_bytes, monkeypatch, tmp_path,
):
    """Order: ledger record → DB. A failed ledger write never reaches the DB."""
    headers, user, content, image = await account_with_data(api, png_bytes)
    monkeypatch.setattr(settings, "deletion_ledger_root", tmp_path / "missing-ledger")

    response = await delete_me(api, headers, json=REASONS)

    assert response.status_code == 503
    await unchanged(api, database_connection, headers, user, content, image, png_bytes)
    assert await cleanup_rows(database_connection, user["id"]) == []


async def test_database_failure_keeps_account_and_originals_and_the_record_is_reused(
    api, database_connection, png_bytes, monkeypatch, tmp_path,
):
    """Order: DB commit → Bucket. A failed DB transaction leaves every original (U2)."""
    headers, user, content, image = await account_with_data(api, png_bytes)
    original_commit = AsyncSession.commit
    failed = False

    async def fail_once(session):
        nonlocal failed
        if not failed:
            failed = True
            raise ConnectionError("injected database failure")
        await original_commit(session)

    with monkeypatch.context() as fault:
        fault.setattr(AsyncSession, "commit", fail_once)
        response = await delete_me(api, headers, json=REASONS)

    assert response.status_code == 500
    await unchanged(api, database_connection, headers, user, content, image, png_bytes)
    assert len(list(tmp_path.rglob("*.png"))) == 1
    assert await cleanup_rows(database_connection, user["id"]) == []
    # The ledger record stays as a confirmed deletion request.
    [record] = ledger_events()
    assert record["user_id"] == user["id"]

    await request(api, "DELETE", "users/me", headers=headers, json=REASONS, status=204)
    assert ledger_events() == [record]
    assert not await user_exists(database_connection, user["id"])
    assert len(await reason_rows(database_connection)) == 1


async def test_original_cleanup_failure_is_still_204_and_left_for_retry(
    api, database_connection, png_bytes, monkeypatch, tmp_path,
):
    headers, user, _, _ = await account_with_data(api, png_bytes)
    originals = list(tmp_path.rglob("*.png"))
    original_unlink = Path.unlink

    def fail_cleanup(path, *args, **kwargs):
        if path in originals:
            raise OSError("injected original storage outage")
        return original_unlink(path, *args, **kwargs)

    with monkeypatch.context() as fault:
        fault.setattr(Path, "unlink", fail_cleanup)
        response = await delete_me(api, headers, json=REASONS)

    assert response.status_code == 204
    assert not await user_exists(database_connection, user["id"])
    job = await database_connection.execute(
        select(ImageDeletion.completed, ImageDeletion.last_error)
        .where(ImageDeletion.user_id == user["id"])
    )
    assert list(job) == [(False, "original_cleanup_unavailable")]
    assert list(tmp_path.rglob("*.png")) == originals
    async with session_for(database_connection) as session:
        assert (await retry_image_deletions(session))["pending"] == 0
    assert list(tmp_path.rglob("*.png")) == []


async def test_maintenance_is_503_and_changes_nothing(
    api, database_connection, png_bytes, monkeypatch,
):
    headers, user, content, image = await account_with_data(api, png_bytes)

    async def closed(self, kind):
        raise MaintenanceError()

    with monkeypatch.context() as gate:
        gate.setattr(MaintenanceGate, "admit", closed)
        response = await delete_me(api, headers, json=REASONS)

    assert response.status_code == 503
    assert response.json() == {"detail": {"code": "service_maintenance"}}
    await unchanged(api, database_connection, headers, user, content, image, png_bytes)
    assert ledger_events() == []


async def test_any_other_failure_is_5xx_and_keeps_the_account(
    api, database_connection, png_bytes, monkeypatch,
):
    headers, user, content, image = await account_with_data(api, png_bytes)

    async def broken(session, intent):
        raise RuntimeError("injected unexpected failure")

    monkeypatch.setattr(account_deletion_service, "apply_account_deletion", broken)
    response = await delete_me(api, headers, json=REASONS)

    assert response.status_code == 500
    await unchanged(api, database_connection, headers, user, content, image, png_bytes)


# Error priority, highest first (spec "오류 우선순위"). Each row also carries every lower error.
@pytest.mark.parametrize(("row", "maintenance", "authorized", "body", "expected"), [
    (1, True, False, {"content": b"{broken"}, 503),
    (2, False, False, {"content": b"{broken"}, 422),
    (3, False, False, {}, 401),
    (3, False, False, {"json": {"reasons": []}}, 401),
    (3, False, False, {"json": {"reasons": ["unknown"]}}, 401),
    (4, False, True, {"json": {"reasons": ["rejoin", "rejoin"]}}, 422),
    (5, False, True, {"json": REASONS}, 503),
])
async def test_error_priority_on_the_real_route(
    api, database_connection, monkeypatch, tmp_path, row, maintenance, authorized, body, expected,
):
    headers, _, user = await guest(api)

    async def closed(self, kind):
        raise MaintenanceError()

    if row == 5:
        monkeypatch.setattr(settings, "deletion_ledger_root", tmp_path / "missing-ledger")
    sent = {"Content-Type": "application/json", **(headers if authorized else {})}
    with monkeypatch.context() as gate:
        if maintenance:
            gate.setattr(MaintenanceGate, "admit", closed)
        response = await delete_me(api, sent, **body)

    assert response.status_code == expected, response.text
    maintenance_body = {"detail": {"code": "service_maintenance"}}
    assert (response.json() == maintenance_body) is (row == 1)
    if row == 2:
        assert response.json()["detail"][0]["type"] == "json_invalid"
    assert await user_exists(database_connection, user["id"])


# Overlapping requests of one account (spec "겹침"), over independent committed sessions.

LEDGER_LOCK_WAITERS = text(
    "SELECT count(*) FILTER (WHERE granted), count(*) FILTER (WHERE NOT granted) "
    "FROM pg_locks WHERE locktype = 'advisory' "
    "AND database = (SELECT oid FROM pg_database WHERE datname = current_database())"
)


async def until_lock(sessions, *, holders, waiters):
    for _ in range(250):
        async with sessions() as session:
            if (await session.execute(LEDGER_LOCK_WAITERS)).one() == (holders, waiters):
                return
        await asyncio.sleep(0.02)
    raise AssertionError(f"ledger lock never reached {holders} holder(s), {waiters} waiter(s)")


async def overlap(client, headers, sessions, release):
    """Start the first request, then a second one that waits for its account lock."""
    first = asyncio.create_task(delete_me(client, headers, json=REASONS))
    try:
        # The first request holds the account lock and the ledger lock.
        await until_lock(sessions, holders=2, waiters=0)
        second = asyncio.create_task(delete_me(client, headers, json={"reasons": ["rejoin"]}))
        await until_lock(sessions, holders=2, waiters=1)
    except BaseException:
        release.set()  # A paused first request would block the fixture cleanup.
        raise
    return first, second


async def committed_reasons(sessions, after_id):
    async with sessions() as session:
        rows = await session.execute(text(
            "SELECT reasons FROM account_deletion_reasons WHERE id > :id ORDER BY id"
        ), {"id": after_id})
        return [row[0] for row in rows]


@pytest_asyncio.fixture
async def overlapping(committed_api):
    client, headers, sessions = committed_api
    async with sessions() as session:
        last = await session.scalar(
            text("SELECT coalesce(max(id), 0) FROM account_deletion_reasons")
        )
    try:
        yield client, headers, sessions, last
    finally:
        # Reason rows are not tied to the account, so remove this test's rows explicitly.
        async with sessions() as session:
            await session.execute(
                text("DELETE FROM account_deletion_reasons WHERE id > :id"), {"id": last}
            )
            await session.commit()


def pause_first_db_deletion(monkeypatch, then=None):
    release = asyncio.Event()
    original = account_deletion_service.apply_account_deletion
    calls = 0

    async def paused(session, intent):
        nonlocal calls
        calls += 1
        if calls == 1:
            await release.wait()
            if then is not None:
                await original(session, intent)
                raise then
        return await original(session, intent)

    monkeypatch.setattr(account_deletion_service, "apply_account_deletion", paused)
    return release


async def test_overlap_after_a_successful_first_request_is_401(overlapping, monkeypatch):
    client, headers, sessions, last = overlapping
    release = pause_first_db_deletion(monkeypatch)
    first, second = await overlap(client, headers, sessions, release)
    release.set()

    assert (await first).status_code == 204
    assert (await second).status_code == 401
    assert len(ledger_events()) == 1
    assert await committed_reasons(sessions, last) == [REASONS["reasons"]]


async def test_overlap_after_a_ledger_failure_processes_the_second_request_anew(
    overlapping, monkeypatch,
):
    client, headers, sessions, last = overlapping
    release = threading.Event()
    real_append = type(get_deletion_ledger()).append
    calls = 0

    def append(ledger, intent):
        nonlocal calls
        calls += 1
        if calls == 1:
            release.wait(10)
            raise LedgerUnavailableError("injected ledger outage")
        return real_append(ledger, intent)

    monkeypatch.setattr(type(get_deletion_ledger()), "append", append)
    first, second = await overlap(client, headers, sessions, release)
    release.set()

    assert (await first).status_code == 503
    assert (await second).status_code == 204
    assert len(ledger_events()) == 1
    assert await committed_reasons(sessions, last) == [["rejoin"]]
    await request(client, "GET", "users/me", headers=headers, status=401)


async def test_overlap_after_a_database_failure_reuses_the_same_ledger_record(
    overlapping, monkeypatch,
):
    client, headers, sessions, last = overlapping
    release = pause_first_db_deletion(monkeypatch, then=ConnectionError("injected DB failure"))
    first, second = await overlap(client, headers, sessions, release)
    [record] = ledger_events()
    release.set()

    assert (await first).status_code == 500
    assert (await second).status_code == 204
    assert ledger_events() == [record]
    assert await committed_reasons(sessions, last) == [["rejoin"]]
    await request(client, "GET", "users/me", headers=headers, status=401)
