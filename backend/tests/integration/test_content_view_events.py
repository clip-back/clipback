from datetime import date
from uuid import uuid4

import pytest
from sqlalchemy import func, insert, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.content import Content
from app.models.content_event import ContentEvent, ContentEventType
from app.models.recommendation import (
    RecommendationBatch,
    RecommendationBatchItem,
    RecommendationExposure,
)
from app.repositories.content_repository import ContentRepository
from app.repositories.event_repository import EventRepository
from tests.integration.helpers import guest, link, request

pytestmark = pytest.mark.asyncio


async def _view(api, headers, content_id, payload, *, status=201):
    return await request(
        api, "POST", f"contents/{content_id}/view", headers=headers, json=payload, status=status
    )


async def _views(connection, user_id):
    return (
        await connection.execute(
            select(ContentEvent.__table__)
            .where(
                ContentEvent.user_id == user_id,
                ContentEvent.event_type == ContentEventType.CONTENT_REOPENED,
            )
            .order_by(ContentEvent.id)
        )
    ).mappings().all()


async def _content(connection, content_id):
    return (
        await connection.execute(
            select(
                Content.open_count,
                Content.last_viewed_at,
                Content.recommendation_count,
                Content.last_recommended_at,
                Content.last_recommended_surface,
            ).where(Content.id == content_id)
        )
    ).mappings().one()


async def _item(connection, user_id, *, content_id=None, category_id=None, surface=None):
    target_kind = "CATEGORY" if category_id is not None else "CONTENT"
    surface = surface or ("WEEKLY_PICK" if target_kind == "CATEGORY" else "TODAY")
    batch_id = await connection.scalar(
        insert(RecommendationBatch)
        .values(
            user_id=user_id,
            type=surface,
            recommendation_date=date(2000, 1, 1) if surface == "TODAY" else None,
        )
        .returning(RecommendationBatch.id)
    )
    return await connection.scalar(
        insert(RecommendationBatchItem)
        .values(
            batch_id=batch_id,
            rank=1,
            target_kind=target_kind,
            target_id_snapshot=category_id or content_id,
            content_id=content_id,
            category_id=category_id,
            card_type="MOST_SAVED" if target_kind == "CATEGORY" else None,
        )
        .returning(RecommendationBatchItem.id)
    )


async def test_view_retry_preserves_event_counter_time_and_snapshot(api, database_connection):
    headers, _, user = await guest(api)
    categories = await request(api, "GET", "categories", headers=headers)
    category_ids = [category["id"] for category in categories if category["name"] != "미분류"][:2]
    content = await link(api, headers, category_ids=list(reversed(category_ids)))
    payload = {"client_event_id": str(uuid4())}

    result = await _view(api, headers, content["id"], payload)
    assert result == {"content_id": content["id"], "event_type": "content_reopened"}
    original_events = await _views(database_connection, user["id"])
    original_content = await _content(database_connection, content["id"])
    assert len(original_events) == 1
    assert original_events[0]["category_ids_at_event"] == sorted(category_ids)
    assert original_events[0]["created_at"] == original_content["last_viewed_at"]
    assert original_content["open_count"] == 1

    await request(
        api,
        "PUT",
        f"contents/{content['id']}/categories",
        headers=headers,
        json={"category_ids": [category_ids[0]]},
    )
    assert await _view(api, headers, content["id"], payload) == result
    assert await _views(database_connection, user["id"]) == original_events
    assert await _content(database_connection, content["id"]) == original_content

    await _view(api, headers, content["id"], {"client_event_id": str(uuid4())})
    events = await _views(database_connection, user["id"])
    current = await _content(database_connection, content["id"])
    assert len(events) == 2 and current["open_count"] == 2
    assert events[1]["category_ids_at_event"] == [category_ids[0]]
    assert events[1]["created_at"] == current["last_viewed_at"]
    assert events[1]["created_at"] > original_events[0]["created_at"]


async def test_bodyless_and_explicit_null_views_remain_independent(api, database_connection):
    headers, _, user = await guest(api)
    content = await link(api, headers)
    requests = ({}, {"content": "null", "headers": {**headers, "Content-Type": "application/json"}})
    for kwargs in requests:
        response = await api.post(
            f"/api/v1/contents/{content['id']}/view", **({"headers": headers} | kwargs)
        )
        assert response.status_code == 201, response.text
        assert response.json() == {"content_id": content["id"], "event_type": "content_reopened"}
    events = await _views(database_connection, user["id"])
    assert len(events) == 2
    assert all(event["client_event_id"] is None for event in events)
    assert all(
        event["category_ids_at_event"] == [content["categories"][0]["id"]] for event in events
    )
    assert (await _content(database_connection, content["id"]))["open_count"] == 2


@pytest.mark.parametrize(
    "payload",
    [
        {},
        {"recommendation_item_id": 1},
        {"client_event_id": None},
        {"client_event_id": "bad-uuid"},
        {"client_event_id": str(uuid4()), "recommendation_item_id": 0},
        {"client_event_id": str(uuid4()), "recommendation_item_id": -1},
        {"client_event_id": str(uuid4()), "recommendation_item_id": 2147483648},
        {"client_event_id": str(uuid4()), "recommendation_item_id": 1.5},
        {"client_event_id": str(uuid4()), "recommendation_item_id": True},
        {"client_event_id": str(uuid4()), "recommendation_item_id": 1.0},
        {"client_event_id": str(uuid4()), "recommendation_item_id": "1"},
        {"client_event_id": str(uuid4()), "recommendation_item_id": "bad-id"},
        {"client_event_id": str(uuid4()), "unexpected": True},
        [],
        "not-an-object",
    ],
)
async def test_invalid_view_body_is_rejected_without_writes(api, database_connection, payload):
    headers, _, user = await guest(api)
    content = await link(api, headers)
    await _view(api, headers, content["id"], payload, status=422)
    assert await _views(database_connection, user["id"]) == []
    assert (await _content(database_connection, content["id"]))["open_count"] == 0


async def test_view_requires_authentication_and_owned_existing_content(api, database_connection):
    headers, _, user = await guest(api)
    outsider, _, _ = await guest(api)
    content = await link(api, headers)
    payload = {"client_event_id": str(uuid4())}
    await _view(api, {}, content["id"], payload, status=401)
    await _view(api, outsider, content["id"], payload, status=404)
    await _view(api, headers, 2147483647, payload, status=404)
    assert await _views(database_connection, user["id"]) == []


async def test_event_id_is_scoped_to_user_and_conflicts_on_different_content(
    api, database_connection
):
    headers, _, user = await guest(api)
    other_headers, _, other_user = await guest(api)
    first = await link(api, headers)
    second = await link(api, headers)
    other = await link(api, other_headers)
    payload = {"client_event_id": str(uuid4())}
    await _view(api, headers, first["id"], payload)
    await _view(api, headers, second["id"], payload, status=409)
    await _view(api, other_headers, other["id"], payload)
    assert len(await _views(database_connection, user["id"])) == 1
    assert len(await _views(database_connection, other_user["id"])) == 1
    assert (await _content(database_connection, second["id"]))["open_count"] == 0


async def test_event_id_conflicts_with_another_event_type(api, database_connection):
    headers, _, user = await guest(api)
    content = await link(api, headers)
    event_id = uuid4()
    await database_connection.execute(
        insert(ContentEvent).values(
            user_id=user["id"],
            content_id=content["id"],
            event_type=ContentEventType.ORIGINAL_LINK_OPENED,
            client_event_id=event_id,
        )
    )
    await _view(api, headers, content["id"], {"client_event_id": str(event_id)}, status=409)
    assert await _views(database_connection, user["id"]) == []
    assert (await _content(database_connection, content["id"]))["open_count"] == 0


async def test_null_referral_matches_omission_but_cannot_be_added_on_retry(
    api, database_connection
):
    headers, _, user = await guest(api)
    content = await link(api, headers)
    item_id = await _item(database_connection, user["id"], content_id=content["id"])
    payload = {"client_event_id": str(uuid4()), "recommendation_item_id": None}
    await _view(api, headers, content["id"], payload)
    await _view(api, headers, content["id"], {"client_event_id": payload["client_event_id"]})
    await _view(
        api, headers, content["id"], {**payload, "recommendation_item_id": item_id}, status=409
    )
    events = await _views(database_connection, user["id"])
    assert len(events) == 1 and events[0]["recommendation_item_id"] is None
    assert (await _content(database_connection, content["id"]))["open_count"] == 1


@pytest.mark.parametrize("kind", ["CONTENT", "CATEGORY"])
async def test_referral_accepts_owned_target_without_exposure_and_does_not_update_recommendations(
    api, database_connection, kind
):
    headers, _, user = await guest(api)
    content = await link(api, headers)
    target = {"content_id": content["id"]} if kind == "CONTENT" else {
        "category_id": content["categories"][0]["id"]
    }
    item_id = await _item(database_connection, user["id"], **target)
    payload = {"client_event_id": str(uuid4()), "recommendation_item_id": item_id}
    await _view(api, headers, content["id"], payload)
    original = await _content(database_connection, content["id"])
    await _view(api, headers, content["id"], payload)

    events = await _views(database_connection, user["id"])
    assert len(events) == 1 and events[0]["recommendation_item_id"] == item_id
    assert original == await _content(database_connection, content["id"])
    assert original["recommendation_count"] == 0
    assert original["last_recommended_at"] is None
    assert original["last_recommended_surface"] is None
    assert await database_connection.scalar(
        select(func.count()).select_from(RecommendationExposure).where(
            RecommendationExposure.user_id == user["id"]
        )
    ) == 0
    await _view(
        api,
        headers,
        content["id"],
        {"client_event_id": payload["client_event_id"]},
        status=409,
    )


@pytest.mark.parametrize(
    "case", ["missing", "foreign_batch", "foreign_content", "foreign_category"]
)
async def test_referral_hides_inaccessible_items_and_live_targets(api, database_connection, case):
    headers, _, user = await guest(api)
    outsider, _, other_user = await guest(api)
    content = await link(api, headers)
    other = await link(api, outsider)
    if case == "missing":
        item_id = 2147483647
    elif case == "foreign_batch":
        item_id = await _item(database_connection, other_user["id"], content_id=content["id"])
    elif case == "foreign_content":
        item_id = await _item(database_connection, user["id"], content_id=other["id"])
    else:
        item_id = await _item(
            database_connection, user["id"], category_id=other["categories"][0]["id"]
        )
    await _view(
        api,
        headers,
        content["id"],
        {"client_event_id": str(uuid4()), "recommendation_item_id": item_id},
        status=404,
    )
    assert await _views(database_connection, user["id"]) == []
    assert (await _content(database_connection, content["id"]))["open_count"] == 0


@pytest.mark.parametrize(
    "case", ["other_content", "other_category", "today_category", "weekly_content"]
)
async def test_referral_rejects_wrong_target_and_surface_kind(api, database_connection, case):
    headers, _, user = await guest(api)
    categories = await request(api, "GET", "categories", headers=headers)
    category_ids = [category["id"] for category in categories if category["name"] != "미분류"][:2]
    content = await link(api, headers, category_ids=[category_ids[0]])
    if case == "other_content":
        other = await link(api, headers)
        target = {"content_id": other["id"]}
    elif case == "other_category":
        target = {"category_id": category_ids[1]}
    elif case == "today_category":
        target = {"category_id": category_ids[0], "surface": "TODAY"}
    else:
        target = {"content_id": content["id"], "surface": "WEEKLY_PICK"}
    item_id = await _item(database_connection, user["id"], **target)
    await _view(
        api,
        headers,
        content["id"],
        {"client_event_id": str(uuid4()), "recommendation_item_id": item_id},
        status=422,
    )
    assert await _views(database_connection, user["id"]) == []


@pytest.mark.parametrize("change", ["reclassify", "delete_category"])
async def test_referral_retry_survives_category_changes_but_new_event_is_revalidated(
    api, database_connection, change
):
    headers, _, user = await guest(api)
    categories = await request(api, "GET", "categories", headers=headers)
    category_ids = [category["id"] for category in categories if category["name"] != "미분류"][:2]
    content = await link(api, headers, category_ids=[category_ids[0]])
    item_id = await _item(database_connection, user["id"], category_id=category_ids[0])
    payload = {"client_event_id": str(uuid4()), "recommendation_item_id": item_id}
    await _view(api, headers, content["id"], payload)
    original_events = await _views(database_connection, user["id"])
    original_content = await _content(database_connection, content["id"])
    if change == "reclassify":
        await request(
            api,
            "PUT",
            f"contents/{content['id']}/categories",
            headers=headers,
            json={"category_ids": [category_ids[1]]},
        )
    else:
        await request(api, "DELETE", f"categories/{category_ids[0]}", headers=headers, status=204)
    await _view(api, headers, content["id"], payload)
    assert await _views(database_connection, user["id"]) == original_events
    assert await _content(database_connection, content["id"]) == original_content
    await _view(
        api,
        headers,
        content["id"],
        {**payload, "client_event_id": str(uuid4())},
        status=422 if change == "reclassify" else 404,
    )
    await request(api, "DELETE", f"contents/{content['id']}", headers=headers, status=204)
    await _view(api, headers, content["id"], payload, status=404)
    assert await request(api, "GET", "users/me/stats", headers=headers) == {
        "saved_count": 1,
        "reopened_count": 1,
    }
    remaining = await _views(database_connection, user["id"])
    assert len(remaining) == 1 and remaining[0]["content_id"] is None
    assert remaining[0]["category_ids_at_event"] == [category_ids[0]]
    assert remaining[0]["recommendation_item_id"] == item_id


async def test_deleted_recommendation_content_is_not_valid_for_another_content(
    api, database_connection
):
    headers, _, user = await guest(api)
    removed = await link(api, headers)
    surviving = await link(api, headers)
    item_id = await _item(database_connection, user["id"], content_id=removed["id"])
    await request(api, "DELETE", f"contents/{removed['id']}", headers=headers, status=204)
    await _view(
        api,
        headers,
        surviving["id"],
        {"client_event_id": str(uuid4()), "recommendation_item_id": item_id},
        status=404,
    )
    assert await _views(database_connection, user["id"]) == []


@pytest.mark.parametrize("failure_point", ["event", "counter", "commit"])
async def test_view_failure_rolls_back_all_writes_and_same_id_can_retry(
    api, database_connection, monkeypatch, failure_point
):
    headers, _, user = await guest(api)
    content = await link(api, headers)
    payload = {"client_event_id": str(uuid4())}
    if failure_point == "commit":
        owner, method = AsyncSession, "commit"
    elif failure_point == "event":
        owner, method = EventRepository, "create_reopened_once"
    else:
        owner, method = ContentRepository, "mark_viewed"
    original = getattr(owner, method)

    async def fail(self, *args, **kwargs):
        if failure_point != "commit":
            await original(self, *args, **kwargs)
        raise RuntimeError("injected view transaction failure")

    with monkeypatch.context() as patch:
        patch.setattr(owner, method, fail)
        response = await api.post(
            f"/api/v1/contents/{content['id']}/view", headers=headers, json=payload
        )
        assert response.status_code == 500

    assert await _views(database_connection, user["id"]) == []
    state = await _content(database_connection, content["id"])
    assert state["open_count"] == 0 and state["last_viewed_at"] is None
    await _view(api, headers, content["id"], payload)
    assert len(await _views(database_connection, user["id"])) == 1
    assert (await _content(database_connection, content["id"]))["open_count"] == 1
