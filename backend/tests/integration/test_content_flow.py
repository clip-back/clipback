import json

import pytest
from sqlalchemy import select

from app.models.content_event import ContentEvent
from tests.integration.helpers import guest, link, request

pytestmark = pytest.mark.asyncio


async def test_direct_shared_and_fallback_storage(api, external_responses, database_connection):
    headers, _, user = await guest(api)
    categories = await request(api, "GET", "categories", headers=headers)
    personal, second = [c for c in categories if c["name"] != "미분류"][:2]
    selected_ids = sorted([personal["id"], second["id"]])
    direct = await link(
        api,
        headers,
        category_ids=[second["id"], personal["id"], second["id"]],
        tag_names=["직접 태그"],
    )
    assert external_responses.ai_calls == 0
    assert direct["title"] == "통합 제목" and direct["summary"] == "통합 설명"
    assert [c["id"] for c in direct["categories"]] == selected_ids
    assert [t["name"] for t in direct["tags"]] == ["직접 태그"]
    shared = await request(
        api,
        "POST",
        "contents/share",
        status=201,
        headers=headers,
        json={
            "url": "https://www.instagram.com/p/ABC123/?utm_source=test",
            "tag_names": ["공유 태그"],
        },
    )
    assert shared["source"] == "instagram"
    assert shared["title"] == "통합 제목" and shared["summary"] == "통합 설명"
    assert shared["categories"] and shared["categories"][0]["name"] != "미분류"
    assert [t["name"] for t in shared["tags"]] == ["공유 태그"]
    assert external_responses.ai_calls == 1
    external_responses.ai_fails = True
    fallback = await link(api, headers)
    assert [c["name"] for c in fallback["categories"]] == ["미분류"]
    rows = (
        await database_connection.execute(
            select(
                ContentEvent.content_id,
                ContentEvent.event_type,
                ContentEvent.metadata_json,
                ContentEvent.category_ids_at_event,
            ).where(ContentEvent.user_id == user["id"])
        )
    ).all()
    assert {r.content_id for r in rows} == {direct["id"], shared["id"], fallback["id"]}
    assert len(rows) == 3 and all(r.event_type.value == "content_created" for r in rows)
    snapshots = {r.content_id: r.category_ids_at_event for r in rows}
    assert snapshots == {
        content["id"]: sorted(c["id"] for c in content["categories"])
        for content in [direct, shared, fallback]
    }
    metadata = {r.content_id: json.loads(r.metadata_json) for r in rows}
    assert metadata[direct["id"]]["category_assignment_method"] == "user"
    assert metadata[shared["id"]]["category_assignment_method"] == "ai"
    assert metadata[shared["id"]]["recommended_category_id"] == shared["categories"][0]["id"]
    assert metadata[fallback["id"]]["category_assignment_method"] == "uncategorized"
    assert metadata[fallback["id"]]["category_recommendation_failure_reason"] == "error"


async def test_feed_search_filters_and_cursor(api):
    headers, _, _ = await guest(api)
    categories = await request(api, "GET", "categories", headers=headers)
    ids = [c["id"] for c in categories if c["name"] != "미분류"]
    one = await link(api, headers, title="여행 일정", category_ids=[ids[0]], tag_names=["바다"])
    two = await link(api, headers, title="업무 기록", category_ids=[ids[1]])
    three = await link(api, headers, title="여행 준비", category_ids=[ids[0]])
    await request(
        api, "PUT", f"contents/{one['id']}/favorite", headers=headers, json={"is_favorite": True}
    )
    for params, expected in [
        ({"q": "바다"}, [one["id"]]),
        ({"q": "여행"}, [three["id"], one["id"]]),
        ({"category_id": ids[1]}, [two["id"]]),
        ({"is_favorite": True, "category_id": ids[0]}, [one["id"]]),
    ]:
        page = await request(api, "GET", "feed", headers=headers, params=params)
        assert [c["id"] for c in page["items"]] == expected
    found, cursor = [], None
    for _ in range(4):
        params = {"limit": 1}
        if cursor:
            params["cursor"] = cursor
        page = await request(api, "GET", "feed", headers=headers, params=params)
        found.extend(c["id"] for c in page["items"])
        cursor = page["next_cursor"]
        if cursor is None:
            break
    assert cursor is None and found == [three["id"], two["id"], one["id"]]
    assert (await request(api, "GET", f"contents/{one['id']}", headers=headers))["is_favorite"]


async def test_category_changes_keep_summaries_and_events_consistent(api, database_connection):
    headers, _, user = await guest(api)
    categories = await request(api, "GET", "categories", headers=headers)
    first, second = [c for c in categories if c["name"] != "미분류"][:2]
    renamed = await request(
        api,
        "PATCH",
        f"categories/{first['id']}",
        headers=headers,
        json={"name": "개인 분류", "color": "#0891B2"},
    )
    assert renamed["name"] == "개인 분류" and renamed["color"] == "#0891B2"
    content = await link(api, headers, category_ids=[first["id"]])
    await request(
        api,
        "PUT",
        f"contents/{content['id']}/categories",
        headers=headers,
        json={"category_ids": [first["id"], second["id"]]},
    )
    for target, expected_name in [(first, second["name"]), (second, "미분류")]:
        await request(api, "DELETE", f"categories/{target['id']}", headers=headers, status=204)
        detail = await request(api, "GET", f"contents/{content['id']}", headers=headers)
        assert [c["name"] for c in detail["categories"]] == [expected_name]
        assert detail["saved_at"] == content["saved_at"]
        summaries = await request(api, "GET", "categories", headers=headers)
        assert target["id"] not in [c["id"] for c in summaries]
        counted = next(c for c in summaries if c["name"] == expected_name)
        assert counted["content_count"] == 1 and counted["last_saved_at"] == content["saved_at"]
        recent = await request(api, "GET", "categories/recent", headers=headers)
        assert [c["name"] for c in recent] == ([] if expected_name == "미분류" else [expected_name])
    changes = (
        (
            await database_connection.execute(
                select(ContentEvent.metadata_json)
                .where(
                    ContentEvent.user_id == user["id"],
                    ContentEvent.event_type == "category_changed",
                )
                .order_by(ContentEvent.id)
            )
        )
        .scalars()
        .all()
    )
    unclassified = detail["categories"][0]["id"]
    assert [json.loads(value) for value in changes] == [
        {
            "before_category_ids": [first["id"]],
            "after_category_ids": sorted([first["id"], second["id"]]),
        },
        {
            "before_category_ids": sorted([first["id"], second["id"]]),
            "after_category_ids": [second["id"]],
        },
        {"before_category_ids": [second["id"]], "after_category_ids": [unclassified]},
    ]
    snapshots = (
        await database_connection.execute(
            select(ContentEvent.event_type, ContentEvent.category_ids_at_event)
            .where(ContentEvent.user_id == user["id"])
            .order_by(ContentEvent.id)
        )
    ).all()
    assert [(event_type.value, ids) for event_type, ids in snapshots] == [
        ("content_created", [first["id"]]),
        ("category_changed", None),
        ("category_changed", None),
        ("category_changed", None),
    ]
    assert await request(api, "GET", "users/me/stats", headers=headers) == {
        "saved_count": 1,
        "reopened_count": 0,
    }


async def test_repeated_views_and_deletion_preserve_cumulative_stats(api, database_connection):
    headers, _, user = await guest(api)
    content = await link(api, headers)
    await request(api, "GET", f"contents/{content['id']}", headers=headers)
    assert await request(api, "GET", "users/me/stats", headers=headers) == {
        "saved_count": 1,
        "reopened_count": 0,
    }
    for _ in range(3):
        await request(api, "POST", f"contents/{content['id']}/view", headers=headers, status=201)
    for deleted in [False, True]:
        if deleted:
            await request(api, "DELETE", f"contents/{content['id']}", headers=headers, status=204)
            await request(api, "GET", f"contents/{content['id']}", headers=headers, status=404)
        assert await request(api, "GET", "users/me/stats", headers=headers) == {
            "saved_count": 1,
            "reopened_count": 3,
        }
    references = (
        (
            await database_connection.execute(
                select(ContentEvent.content_id).where(
                    ContentEvent.user_id == user["id"],
                )
            )
        )
        .scalars()
        .all()
    )
    assert references == [None] * 4
