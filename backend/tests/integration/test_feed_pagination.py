from datetime import UTC, datetime, timedelta

import pytest
from sqlalchemy import update

from app.models.content import Content
from tests.integration.helpers import guest, link, request

pytestmark = pytest.mark.asyncio

BASE_TIME = datetime(2026, 1, 1, tzinfo=UTC)


async def save_at(api, headers, connection, offset, **payload):
    item = await link(api, headers, **payload)
    await connection.execute(
        update(Content)
        .where(Content.id == item["id"])
        .values(saved_at=BASE_TIME + timedelta(microseconds=offset))
    )
    return item


@pytest.mark.parametrize("limit", [1, 2, 3, 100])
async def test_feed_pages_match_full_order_when_ids_and_times_disagree(
    api, database_connection, limit
):
    headers, _, _ = await guest(api)
    items = [
        await save_at(api, headers, database_connection, offset) for offset in [30, 10, 30, 20, 10]
    ]
    expected = [items[index]["id"] for index in [2, 0, 3, 4, 1]]
    full = await request(api, "GET", "feed", headers=headers, params={"limit": 100})
    assert [item["id"] for item in full["items"]] == expected

    found, cursor = [], None
    for _ in range(len(items) + 1):
        params = {"limit": limit}
        if cursor is not None:
            params["cursor"] = cursor
        page = await request(api, "GET", "feed", headers=headers, params=params)
        assert len(page["items"]) <= limit
        found.extend(item["id"] for item in page["items"])
        cursor = page["next_cursor"]
        if cursor is None:
            break

    assert cursor is None
    assert found == expected


async def test_feed_cursor_survives_anchor_deletion_and_newer_insert(api, database_connection):
    headers, _, _ = await guest(api)
    items = [await save_at(api, headers, database_connection, offset) for offset in [30, 20, 10]]
    first = await request(api, "GET", "feed", headers=headers, params={"limit": 1})
    assert first["items"][0]["id"] == items[0]["id"]
    assert first["next_cursor"].startswith("v1.")
    await request(api, "DELETE", f"contents/{items[0]['id']}", headers=headers, status=204)
    newer = await save_at(api, headers, database_connection, 40)

    second = await request(
        api, "GET", "feed", headers=headers, params={"limit": 1, "cursor": first["next_cursor"]}
    )
    third = await request(
        api, "GET", "feed", headers=headers, params={"limit": 1, "cursor": second["next_cursor"]}
    )
    assert [item["id"] for item in second["items"] + third["items"]] == [
        items[1]["id"],
        items[2]["id"],
    ]
    assert third["next_cursor"] is None
    refreshed = await request(api, "GET", "feed", headers=headers)
    assert [item["id"] for item in refreshed["items"]] == [
        newer["id"],
        items[1]["id"],
        items[2]["id"],
    ]


async def test_legacy_cursor_uses_owned_anchor_after_filter_changes(api, database_connection):
    headers, _, _ = await guest(api)
    categories = await request(api, "GET", "categories", headers=headers)
    first, second = [item["id"] for item in categories if item["name"] != "미분류"][:2]
    matching = {
        "category_ids": [first],
        "is_favorite": True,
        "title": "일정",
        "summary": "계획",
        "tag_names": ["여행", "여행지"],
    }
    anchor = await save_at(api, headers, database_connection, 30, **matching)
    wanted = [
        await save_at(api, headers, database_connection, offset, **matching) for offset in [20, 10]
    ]
    for overrides in [
        {"category_ids": [second]},
        {"is_favorite": False},
        {"tag_names": ["업무"]},
    ]:
        await save_at(api, headers, database_connection, 15, **(matching | overrides))

    params = {"q": "여행", "category_id": first, "is_favorite": True, "limit": 1}
    initial = await request(api, "GET", "feed", headers=headers, params=params)
    assert initial["items"][0]["id"] == anchor["id"]
    await request(
        api,
        "PUT",
        f"contents/{anchor['id']}/categories",
        headers=headers,
        json={"category_ids": [second]},
    )
    await request(
        api,
        "PUT",
        f"contents/{anchor['id']}/favorite",
        headers=headers,
        json={"is_favorite": False},
    )

    page = await request(
        api, "GET", "feed", headers=headers, params=params | {"cursor": str(anchor["id"])}
    )
    assert [item["id"] for item in page["items"]] == [wanted[0]["id"]]
    assert page["next_cursor"].startswith("v1.")
    last = await request(
        api, "GET", "feed", headers=headers, params=params | {"cursor": page["next_cursor"]}
    )
    assert [item["id"] for item in last["items"]] == [wanted[1]["id"]]
    assert last["next_cursor"] is None


async def test_legacy_cursor_rejects_missing_deleted_and_foreign_ids_identically(
    api, database_connection
):
    headers, _, _ = await guest(api)
    outsider, _, _ = await guest(api)
    deleted = await save_at(api, headers, database_connection, 10)
    foreign = await save_at(api, outsider, database_connection, 10)
    await request(api, "DELETE", f"contents/{deleted['id']}", headers=headers, status=204)

    errors = [
        await request(
            api, "GET", "feed", headers=headers, params={"cursor": str(content_id)}, status=422
        )
        for content_id in [deleted["id"], foreign["id"], 2_147_483_647]
    ]
    assert errors == [{"detail": "Invalid feed cursor"}] * 3


async def test_versioned_cursor_cannot_bypass_user_filter(api, database_connection):
    headers, _, _ = await guest(api)
    outsider, _, _ = await guest(api)
    own = [await save_at(api, headers, database_connection, offset) for offset in [30, 10]]
    for offset in [40, 20]:
        await save_at(api, outsider, database_connection, offset)
    foreign_page = await request(api, "GET", "feed", headers=outsider, params={"limit": 1})
    page = await request(
        api, "GET", "feed", headers=headers, params={"cursor": foreign_page["next_cursor"]}
    )
    assert [item["id"] for item in page["items"]] == [item["id"] for item in own]
    assert page["next_cursor"] is None


async def test_feed_empty_exact_size_and_exhausted_pages(api, database_connection):
    headers, _, _ = await guest(api)
    empty = await request(api, "GET", "feed", headers=headers)
    assert empty == {"items": [], "next_cursor": None}
    items = [await save_at(api, headers, database_connection, 10) for _ in range(2)]
    exact = await request(api, "GET", "feed", headers=headers, params={"limit": 2})
    assert [item["id"] for item in exact["items"]] == [item["id"] for item in reversed(items)]
    assert exact["next_cursor"] is None
    exhausted = await request(
        api, "GET", "feed", headers=headers, params={"cursor": str(items[0]["id"])}
    )
    assert exhausted == {"items": [], "next_cursor": None}


@pytest.mark.parametrize("cursor", ["v1.a", "v1._w", "v2.e30", "2147483648", "9" * 513])
async def test_feed_api_returns_422_for_invalid_cursors(api, cursor):
    headers, _, _ = await guest(api)
    await request(api, "GET", "feed", headers=headers, params={"cursor": cursor}, status=422)
