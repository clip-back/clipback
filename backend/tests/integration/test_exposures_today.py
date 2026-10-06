import importlib
from datetime import UTC, datetime, timedelta
from random import Random
from types import SimpleNamespace
from uuid import uuid4

import pytest
from sqlalchemy import insert, select, update

from app.models.content import Content
from app.models.recommendation import RecommendationBatch, RecommendationBatchItem
from tests.integration.helpers import guest
from tests.integration.test_today_recommendations import NOW, _ids, _items, _save_many, _today

pytestmark = pytest.mark.asyncio


@pytest.fixture
def exposure_clock(monkeypatch):
    state = SimpleNamespace(now=NOW)
    service = importlib.import_module("app.services.recommendation_service")
    monkeypatch.setattr(service, "utc_now", lambda: state.now)
    monkeypatch.setattr(service, "random", SimpleNamespace(Random=lambda: Random(0)))
    return state


async def _content_items(connection, user_id, contents):
    generated_at = NOW - timedelta(days=30)
    batch_id = await connection.scalar(
        insert(RecommendationBatch)
        .values(
            user_id=user_id,
            type="TODAY",
            recommendation_date=generated_at.date(),
            generated_at=generated_at,
        )
        .returning(RecommendationBatch.id)
    )
    item_ids = []
    for rank, content in enumerate(contents, 1):
        item_ids.append(await connection.scalar(
            insert(RecommendationBatchItem)
            .values(
                batch_id=batch_id,
                rank=rank,
                target_kind="CONTENT",
                target_id_snapshot=content["id"],
                content_id=content["id"],
            )
            .returning(RecommendationBatchItem.id)
        ))
    return item_ids


async def _category_item(connection, user_id, category_id):
    batch_id = await connection.scalar(
        insert(RecommendationBatch)
        .values(user_id=user_id, type="WEEKLY_PICK", generated_at=NOW - timedelta(days=30))
        .returning(RecommendationBatch.id)
    )
    return await connection.scalar(
        insert(RecommendationBatchItem)
        .values(
            batch_id=batch_id,
            rank=1,
            target_kind="CATEGORY",
            target_id_snapshot=category_id,
            category_id=category_id,
            card_type="MOST_SAVED",
        )
        .returning(RecommendationBatchItem.id)
    )


async def _expose(api, headers, item_id, when):
    client_event_id = str(uuid4())
    response = await api.post(
        "/api/v1/recommendations/exposures",
        headers=headers,
        json={"client_event_id": client_event_id, "recommendation_item_id": item_id},
    )
    assert response.status_code == 201, response.text
    result = response.json()
    assert set(result) == {
        "exposure_id", "client_event_id", "recommendation_item_id", "recommended_at"
    }
    assert result["exposure_id"] > 0
    assert result["client_event_id"] == client_event_id
    assert result["recommendation_item_id"] == item_id
    assert datetime.fromisoformat(result["recommended_at"]) == when
    return result


async def test_exposure_posts_drive_stage_one_priority_at_kst_day_boundaries(
    api, database_connection, exposure_clock
):
    headers, _, user = await guest(api)
    contents = await _save_many(api, headers, database_connection, 8)
    items = await _content_items(database_connection, user["id"], contents)
    previous_start = datetime(2026, 10, 1, 15, tzinfo=UTC)
    today_start = previous_start + timedelta(days=1)
    for index, when in [
        (7, previous_start - timedelta(microseconds=1)),
        (6, previous_start),
        (5, today_start - timedelta(microseconds=1)),
        (4, today_start),
    ]:
        exposure_clock.now = when
        await _expose(api, headers, items[index], when)

    category_item = await _category_item(
        database_connection, user["id"], contents[0]["categories"][0]["id"]
    )
    exposure_clock.now = previous_start
    await _expose(api, headers, category_item, exposure_clock.now)
    # Another visit today must not erase this item's separate exposure from yesterday.
    exposure_clock.now = NOW
    await _expose(api, headers, items[6], exposure_clock.now)
    response = await _today(api, headers)
    assert response["stage"] == 1 and response["recommendation_date"] == "2026-10-03"
    assert _ids(response) == [contents[index]["id"] for index in [7, 4, 3, 2, 1]]


@pytest.mark.parametrize("at_boundary", [False, True])
async def test_exposure_posts_drive_stage_two_72_hour_filter(
    api, database_connection, exposure_clock, at_boundary
):
    headers, _, user = await guest(api)
    contents = await _save_many(api, headers, database_connection, 10)
    await database_connection.execute(
        update(Content)
        .where(Content.user_id == user["id"])
        .values(saved_at=NOW - timedelta(days=30))
    )
    item_ids = await _content_items(database_connection, user["id"], contents[:5])
    exposure_clock.now = NOW - timedelta(hours=72)
    if not at_boundary:
        exposure_clock.now += timedelta(microseconds=1)
    for item_id in item_ids:
        await _expose(api, headers, item_id, exposure_clock.now)
    exposure_clock.now = NOW
    response = await _today(api, headers)
    selected = set(_ids(response))
    exposed = {content["id"] for content in contents[:5]}
    assert response["stage"] == 2 and len(selected) == 5
    if at_boundary:
        # The fixed RNG selects from both groups once the 72 hours have elapsed.
        assert selected & exposed
        assert selected - exposed
    else:
        assert selected == {content["id"] for content in contents[5:]}


async def test_exposure_post_updates_recency_component_of_stage_two_score(
    api, database_connection, exposure_clock
):
    headers, _, user = await guest(api)
    contents = await _save_many(api, headers, database_connection, 10)
    await database_connection.execute(
        update(Content)
        .where(Content.user_id == user["id"])
        .values(saved_at=NOW - timedelta(days=30))
    )
    await database_connection.execute(
        update(Content)
        .where(Content.id.in_([content["id"] for content in contents[5:]]))
        .values(last_viewed_at=NOW, open_count=1)
    )
    [item_id] = await _content_items(database_connection, user["id"], contents[:1])
    exposure_clock.now = NOW - timedelta(days=7)
    await _expose(api, headers, item_id, exposure_clock.now)
    exposure_clock.now = NOW
    response = await _today(api, headers)
    assert set(_ids(response)) == {content["id"] for content in contents[:5]}
    scores = {
        item["content_id"]: item["score"]
        for item in await _items(database_connection, response["batch_id"])
    }
    # A=1, L=1, V=1, R=7/14, F=0; never-exposed content retains R=1.
    assert scores[contents[0]["id"]] == pytest.approx(0.775)
    assert all(scores[content["id"]] == pytest.approx(0.9) for content in contents[1:5])


async def test_category_exposure_does_not_change_stage_two_candidates_or_scores(
    api, database_connection, exposure_clock
):
    headers, _, user = await guest(api)
    contents = await _save_many(api, headers, database_connection, 10)
    await database_connection.execute(
        update(Content)
        .where(Content.user_id == user["id"])
        .values(saved_at=NOW - timedelta(days=30))
    )
    category_id = contents[0]["categories"][0]["id"]
    assert all([category["id"] for category in content["categories"]] == [category_id]
               for content in contents)
    category_item = await _category_item(database_connection, user["id"], category_id)
    await _expose(api, headers, category_item, exposure_clock.now)
    counters = (await database_connection.execute(
        select(
            Content.recommendation_count,
            Content.last_recommended_at,
            Content.last_recommended_surface,
            Content.open_count,
            Content.last_viewed_at,
        ).where(Content.user_id == user["id"])
    )).all()
    assert counters == [(0, None, None, 0, None)] * 10
    response = await _today(api, headers)
    assert response["stage"] == 2 and len(response["items"]) == 5
    assert all(
        item["score"] == pytest.approx(0.9)
        for item in await _items(database_connection, response["batch_id"])
    )


async def test_exposure_posts_preserve_the_existing_today_batch(
    api, database_connection, exposure_clock
):
    headers, _, _ = await guest(api)
    await _save_many(api, headers, database_connection, 10)
    original = await _today(api, headers)
    stored_items = await _items(database_connection, original["batch_id"])
    for item in original["items"]:
        await _expose(api, headers, item["recommendation_item_id"], exposure_clock.now)
    exposure_clock.now += timedelta(hours=1)
    assert await _today(api, headers) == original
    assert await _items(database_connection, original["batch_id"]) == stored_items
    counters = (await database_connection.execute(
        select(Content.recommendation_count, Content.last_recommended_at)
        .where(Content.id.in_(_ids(original)))
    )).all()
    assert counters == [(1, NOW)] * 5
