"""Restore probe checks for applied account deletion records (#252, ADR 0008)."""

import threading
from datetime import timedelta
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from uuid import uuid4

import pytest
from sqlalchemy import select

from app.models.user import User
from app.services.account_deletion_service import record_account_deletion
from scripts import recovery_deletions, recovery_probe
from tests.integration.helpers import guest, link, request
from tests.integration.test_account_deletion import recommended, session_for
from tests.integration.test_image_deletion import upload

# The spec's list: account, contents, events, recommendations, categories, tags,
# sessions and social connections.
ACCOUNT_TABLES = {
    "users", "contents", "content_events", "recommendation_batches",
    "recommendation_exposures", "categories", "tags", "auth_sessions", "social_identities",
}


async def account_with_every_kind_of_data(api, connection, png_bytes):
    tokens = await request(api, "POST", "auth/social/kakao", json={"token": "probe-user"})
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}
    user = await request(api, "GET", "users/me", headers=headers)
    owned = await request(api, "POST", "categories", headers=headers, status=201,
                          json={"name": "복원 확인 카테고리"})
    content = await link(api, headers, category_ids=[owned["id"]], tag_names=["복원 태그"])
    await request(api, "POST", f"contents/{content['id']}/view", headers=headers, status=201,
                  json={"client_event_id": str(uuid4())})
    await recommended(api, connection, headers, user["id"], content["id"])
    await upload(api, headers, png_bytes)
    return user


@pytest.mark.asyncio
async def test_probe_counts_every_account_table_until_the_replay_deletes_the_account(
    api, database_connection, png_bytes,
):
    user = await account_with_every_kind_of_data(api, database_connection, png_bytes)
    _, _, other = await guest(api)

    async with session_for(database_connection) as session:
        rows = await recovery_probe.account_rows(session, [user["id"]])
        # Leftover rows in any of these tables would fail the restore.
        assert {table for table, count in rows.items() if count} >= ACCOUNT_TABLES

        record = await record_account_deletion(session, user["id"])
        await recovery_deletions.apply_account(session, record)

        assert set(rows) == set(await recovery_probe.account_rows(session, [user["id"]]))
        assert not any((await recovery_probe.account_rows(session, [user["id"]])).values())
        # Another account's rows are still counted when it is named.
        assert any((await recovery_probe.account_rows(session, [other["id"]])).values())
        await session.rollback()


@pytest.mark.asyncio
async def test_probe_matches_recorded_accounts_by_number_and_creation_time(
    api, database_connection,
):
    _, _, recorded = await guest(api)
    _, _, reused = await guest(api)
    async with session_for(database_connection) as session:
        created = {
            user_id: await session.scalar(select(User.created_at).where(User.id == user_id))
            for user_id in (recorded["id"], reused["id"])
        }
        records = [
            {"user_id": recorded["id"], "user_created_at": created[recorded["id"]].isoformat()},
            # Same number, another account (U1): it is not the deleted account.
            {"user_id": reused["id"],
             "user_created_at": (created[reused["id"]] - timedelta(days=1)).isoformat()},
            {"user_id": 2**31 - 1, "user_created_at": created[recorded["id"]].isoformat()},
        ]

        assert await recovery_probe.matching_accounts(session, records) == [recorded["id"]]
        assert await recovery_probe.matching_accounts(session, []) == []
        await session.rollback()


class FakeApi(BaseHTTPRequestHandler):
    statuses = {}

    def do_GET(self):
        self.send_response(self.statuses[self.path.removeprefix("/api/v1/")])
        self.end_headers()
        self.wfile.write(b"{}")

    def log_message(self, *args):
        pass


@pytest.fixture
def fake_api(monkeypatch):
    server = ThreadingHTTPServer(("127.0.0.1", 0), FakeApi)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    monkeypatch.setenv("PORT", str(server.server_address[1]))
    try:
        yield FakeApi.statuses
    finally:
        server.shutdown()
        server.server_close()
        FakeApi.statuses = {}


DELETED = [{"content_id": 5, "asset_ids": [6]}]
DELETED_PATHS = ["contents/5", "uploads/assets/6", "uploads/assets/6/access"]


def test_deleted_token_account_passes_only_with_401(fake_api):
    fake_api.update({"users/me": 401, **dict.fromkeys(DELETED_PATHS, 401)})
    recovery_probe.check_deleted_access("token", DELETED, token_account_deleted=True)

    fake_api["users/me"] = 200
    with pytest.raises(ValueError, match="exposed"):
        recovery_probe.check_deleted_access("token", DELETED, token_account_deleted=True)

    fake_api.update({"users/me": 401, "uploads/assets/6": 404})
    with pytest.raises(ValueError, match="differs"):
        recovery_probe.check_deleted_access("token", DELETED, token_account_deleted=True)


def test_living_token_account_still_expects_404_for_deleted_paths(fake_api):
    fake_api.update(dict.fromkeys(DELETED_PATHS, 404))
    recovery_probe.check_deleted_access("token", DELETED, token_account_deleted=False)

    fake_api["contents/5"] = 401
    with pytest.raises(ValueError, match="differs"):
        recovery_probe.check_deleted_access("token", DELETED, token_account_deleted=False)

    fake_api["contents/5"] = 200
    with pytest.raises(ValueError, match="exposed"):
        recovery_probe.check_deleted_access("token", DELETED, token_account_deleted=False)
