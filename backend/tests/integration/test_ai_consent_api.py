"""#475 GET /users/me ai_consent_status and PUT /users/me/ai-consent contract."""

import re

import pytest
from sqlalchemy import text

from app.services import ai_consent
from tests.integration.helpers import guest, request

pytestmark = pytest.mark.asyncio
ISO = re.compile(r"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(\.\d+)?Z$")


async def put(api, headers, status_value="granted", version=1, *, status=200):
    return await request(api, "PUT", "users/me/ai-consent", headers=headers, status=status,
                         json={"status": status_value, "notice_version": version})


async def stored(db, user_id):
    row = (await db.execute(text(
        "SELECT status, notice_version, decided_at, granted_after_denial "
        "FROM ai_transfer_consents WHERE user_id = :u"), {"u": user_id})).one_or_none()
    return None if row is None else tuple(row)


async def share_headers(api, headers):
    data = await request(api, "POST", "auth/share-credential", headers=headers)
    return {"Authorization": f"Bearer {data['share_token']}"}


async def test_status_follows_each_decision(api, database_connection):
    headers, _, user = await guest(api)
    assert user["ai_consent_status"] == "undecided"
    assert await stored(database_connection, user["id"]) is None
    for value in ("granted", "denied", "granted"):
        body = await put(api, headers, value)
        assert set(body) == {"status", "notice_version", "decided_at"}
        assert (body["status"], body["notice_version"]) == (value, 1)
        assert ISO.match(body["decided_at"]), body
        me = await request(api, "GET", "users/me", headers=headers)
        assert me["ai_consent_status"] == value


@pytest.mark.parametrize(("steps", "flag"), [
    (["granted"], False),
    (["denied"], False),
    (["granted", "denied"], False),
    (["denied", "granted"], True),
    (["granted", "denied", "granted"], True),
    (["denied", "granted", "denied"], False),
    (["denied", "granted", "granted"], True),
])
async def test_granted_after_denial_marks_only_a_grant_replacing_a_denial(
    api, database_connection, steps, flag,
):
    headers, _, user = await guest(api)
    for value in steps:
        await put(api, headers, value)
    status_value, version, _, granted_after_denial = await stored(database_connection, user["id"])
    assert (status_value, version, granted_after_denial) == (steps[-1], 1, flag)


@pytest.mark.parametrize("value", ["granted", "denied"])
async def test_same_status_again_keeps_the_stored_time(api, database_connection, value):
    headers, _, user = await guest(api)
    first = await put(api, headers, value)
    before = await stored(database_connection, user["id"])
    again = await put(api, headers, value)
    assert again == first
    assert await stored(database_connection, user["id"]) == before


INVALID = [
    {"status": None, "notice_version": 1},
    {"status": 1, "notice_version": 1},
    {"status": ["granted"], "notice_version": 1},
    {"status": "GRANTED", "notice_version": 1},
    {"status": "undecided", "notice_version": 1},
    {"status": "granted", "notice_version": None},
    {"status": "granted", "notice_version": "1"},
    {"status": "granted", "notice_version": [1]},
    {"status": "granted", "notice_version": 1.0},
    {"status": "granted", "notice_version": True},
    {"status": "granted", "notice_version": 0},
    {"status": "granted", "notice_version": -1},
    {"status": "granted", "notice_version": 2},
    {"status": "granted"},
    {"notice_version": 1},
    {},
    ["granted", 1],
    None,
]


@pytest.mark.parametrize("body", INVALID)
async def test_invalid_body_is_422_without_a_record(api, database_connection, body):
    headers, _, user = await guest(api)
    response = await api.put("/api/v1/users/me/ai-consent", headers=headers, json=body)
    assert response.status_code == 422, (body, response.text)
    assert await stored(database_connection, user["id"]) is None


async def test_invalid_body_keeps_an_existing_record(api, database_connection):
    headers, _, user = await guest(api)
    await put(api, headers, "granted")
    before = await stored(database_connection, user["id"])
    await put(api, headers, "denied", 2, status=422)
    assert await stored(database_connection, user["id"]) == before


async def test_share_token_missing_token_and_deleted_account_are_401(api, database_connection):
    headers, _, user = await guest(api)
    share = await share_headers(api, headers)
    for auth in (share, {}, {"Authorization": "Bearer invalid"}):
        response = await api.put("/api/v1/users/me/ai-consent", headers=auth,
                                 json={"status": "granted", "notice_version": 1})
        assert response.status_code == 401, response.text
    assert await stored(database_connection, user["id"]) is None
    await put(api, headers, "granted")
    await request(api, "DELETE", "users/me", headers=headers, status=204,
                  json={"reasons": ["other"]})
    for value in ("granted", "denied"):
        await put(api, headers, value, status=401)
    assert await stored(database_connection, user["id"]) is None


async def test_share_token_cannot_read_status(api):
    headers, _, _ = await guest(api)
    response = await api.get("/api/v1/users/me", headers=await share_headers(api, headers))
    assert response.status_code == 401


async def test_read_failure_rolls_back_the_whole_change(api, database_connection, monkeypatch):
    headers, _, user = await guest(api)
    await put(api, headers, "granted")
    before = await stored(database_connection, user["id"])
    monkeypatch.setattr(ai_consent, "_SELECT", text("SELECT 1 / 0"))
    response = await api.put("/api/v1/users/me/ai-consent", headers=headers,
                             json={"status": "denied", "notice_version": 1})
    assert (response.status_code, response.text) == (500, "Internal Server Error")
    assert await stored(database_connection, user["id"]) == before
