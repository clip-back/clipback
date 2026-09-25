import importlib
from datetime import UTC, datetime, timedelta
from types import SimpleNamespace
from uuid import uuid4

import pytest
from sqlalchemy import func, insert, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.content import Content
from app.models.content_event import ContentEvent
from app.models.recommendation import (
    RecommendationBatch,
    RecommendationBatchItem,
    RecommendationExposure,
)
from app.models.summary_job import SummaryJob
from tests.integration.helpers import guest, link, request

pytestmark = pytest.mark.asyncio
NOW = datetime(2026, 10, 3, 12, tzinfo=UTC)


@pytest.fixture
def recommendation_clock(monkeypatch):
    state = SimpleNamespace(now=NOW)
    service = importlib.import_module("app.services.recommendation_service")
    monkeypatch.setattr(service, "utc_now", lambda: state.now)
    return state


async def _today(api, headers):
    response = await api.get("/api/v1/recommendations/today", headers=headers)
    assert response.status_code == 200, response.text
    assert response.headers["cache-control"] == "no-store"
    body = response.json()
    assert set(body) == {"stage", "recommendation_date", "batch_id", "generated_at", "items"}
    for item in body["items"]:
        assert set(item) == {"recommendation_item_id", "rank", "content"}
    return body


async def _save_many(api, headers, connection, count, **overrides):
    contents = []
    for index in range(count):
        content = await link(api, headers, title=f"Saved {index}", **overrides)
        await connection.execute(
            update(Content)
            .where(Content.id == content["id"])
            .values(saved_at=NOW - timedelta(days=10, minutes=count - index))
        )
        contents.append(content)
    return contents


def _ids(response):
    return [item["content"]["id"] for item in response["items"]]


async def _batches(connection, user_id):
    return (
        await connection.execute(
            select(RecommendationBatch.__table__)
            .where(RecommendationBatch.user_id == user_id)
            .order_by(RecommendationBatch.id)
        )
    ).mappings().all()


async def _items(connection, batch_id):
    return (
        await connection.execute(
            select(RecommendationBatchItem.__table__)
            .where(RecommendationBatchItem.batch_id == batch_id)
            .order_by(RecommendationBatchItem.rank)
        )
    ).mappings().all()


async def _exposure(connection, user_id, batch_id, rank, content_id, when):
    item_id = await connection.scalar(
        insert(RecommendationBatchItem)
        .values(
            batch_id=batch_id,
            rank=rank,
            target_kind="CONTENT",
            target_id_snapshot=content_id,
            content_id=content_id,
        )
        .returning(RecommendationBatchItem.id)
    )
    await connection.execute(
        insert(RecommendationExposure).values(
            user_id=user_id,
            client_event_id=uuid4(),
            recommendation_item_id=item_id,
            recommended_at=when,
        )
    )
    return item_id


@pytest.mark.parametrize("count,stage", [(0, 0), (4, 0), (5, 1), (9, 1), (10, 2)])
async def test_stage_counts_distinct_current_content_rows(
    api, database_connection, recommendation_clock, count, stage
):
    headers, _, user = await guest(api)
    categories = await request(api, "GET", "categories", headers=headers)
    category_ids = [category["id"] for category in categories if category["name"] != "미분류"][:2]
    contents = await _save_many(
        api, headers, database_connection, count, category_ids=category_ids
    )
    response = await _today(api, headers)
    assert response["stage"] == stage
    assert response["recommendation_date"] == "2026-10-03"
    assert len(response["items"]) == (0 if stage == 0 else 5)
    assert set(_ids(response)).issubset({content["id"] for content in contents})
    assert len(_ids(response)) == len(set(_ids(response)))
    batches = await _batches(database_connection, user["id"])
    if stage == 0:
        assert response["batch_id"] is None and response["generated_at"] is None
        assert batches == []
    else:
        assert len(batches) == 1 and batches[0]["id"] == response["batch_id"]
        assert batches[0]["generated_at"] == recommendation_clock.now
        items = await _items(database_connection, response["batch_id"])
        assert [item["rank"] for item in items] == [1, 2, 3, 4, 5]
        assert [item["target_id_snapshot"] for item in items] == _ids(response)
        assert all(item["target_kind"] == "CONTENT" for item in items)
        if stage == 1:
            assert all(item["score"] is None for item in items)
        else:
            assert all(0 <= item["score"] <= 1 for item in items)


async def test_today_auth_and_user_isolation(api, database_connection, recommendation_clock):
    headers, _, user = await guest(api)
    other_headers, _, other_user = await guest(api)
    own = await _save_many(api, headers, database_connection, 5)
    other = await _save_many(api, other_headers, database_connection, 5)
    unauthorized = await api.get("/api/v1/recommendations/today")
    assert unauthorized.status_code == 401
    first = await _today(api, headers)
    second = await _today(api, other_headers)
    assert set(_ids(first)) == {content["id"] for content in own}
    assert set(_ids(second)) == {content["id"] for content in other}
    assert first["batch_id"] != second["batch_id"]
    assert len(await _batches(database_connection, user["id"])) == 1
    assert len(await _batches(database_connection, other_user["id"])) == 1


async def test_stage_one_priority_and_recent_view_save_are_not_excluded(
    api, database_connection, recommendation_clock
):
    headers, _, _ = await guest(api)
    contents = await _save_many(api, headers, database_connection, 7)
    for index in range(4):
        await database_connection.execute(
            update(Content)
            .where(Content.id == contents[index]["id"])
            .values(last_viewed_at=NOW - timedelta(minutes=4 - index), open_count=1)
        )
    await database_connection.execute(
        update(Content).where(Content.id == contents[6]["id"]).values(saved_at=NOW)
    )
    response = await _today(api, headers)
    assert _ids(response) == [contents[index]["id"] for index in [6, 5, 4, 0, 1]]


async def test_stage_one_uses_actual_yesterday_exposures_with_kst_boundaries(
    api, database_connection, recommendation_clock
):
    headers, _, user = await guest(api)
    contents = await _save_many(api, headers, database_connection, 8)
    previous_start = datetime(2026, 10, 1, 15, tzinfo=UTC)
    today_start = previous_start + timedelta(days=1)
    previous_batch = await database_connection.scalar(
        insert(RecommendationBatch)
        .values(user_id=user["id"], type="TODAY", recommendation_date=previous_start.date())
        .returning(RecommendationBatch.id)
    )
    newest_item = await _exposure(
        database_connection, user["id"], previous_batch, 1, contents[7]["id"], previous_start
    )
    await _exposure(
        database_connection,
        user["id"],
        previous_batch,
        2,
        contents[6]["id"],
        today_start - timedelta(microseconds=1),
    )
    outside_item = await _exposure(
        database_connection,
        user["id"],
        previous_batch,
        3,
        contents[5]["id"],
        previous_start - timedelta(microseconds=1),
    )
    await _exposure(
        database_connection, user["id"], previous_batch, 4, contents[4]["id"], today_start
    )
    # A later exposure must not erase the separate event from yesterday.
    await database_connection.execute(
        insert(RecommendationExposure).values(
            user_id=user["id"],
            client_event_id=uuid4(),
            recommendation_item_id=newest_item,
            recommended_at=NOW,
        )
    )
    await database_connection.execute(
        update(Content).where(Content.id == contents[7]["id"]).values(last_recommended_at=NOW)
    )
    # Category-card exposure does not expose its member contents.
    weekly_batch = await database_connection.scalar(
        insert(RecommendationBatch)
        .values(user_id=user["id"], type="WEEKLY_PICK")
        .returning(RecommendationBatch.id)
    )
    category_id = contents[0]["categories"][0]["id"]
    category_item = await database_connection.scalar(
        insert(RecommendationBatchItem)
        .values(
            batch_id=weekly_batch,
            rank=1,
            target_kind="CATEGORY",
            target_id_snapshot=category_id,
            category_id=category_id,
            card_type="MOST_SAVED",
        )
        .returning(RecommendationBatchItem.id)
    )
    await database_connection.execute(
        insert(RecommendationExposure).values(
            user_id=user["id"],
            client_event_id=uuid4(),
            recommendation_item_id=category_item,
            recommended_at=previous_start,
        )
    )
    # The FK allows inconsistent ownership; lookup must still isolate both owners.
    _, _, outsider = await guest(api)
    await database_connection.execute(
        insert(RecommendationExposure).values(
            user_id=outsider["id"],
            client_event_id=uuid4(),
            recommendation_item_id=outside_item,
            recommended_at=previous_start,
        )
    )
    outsider_batch = await database_connection.scalar(
        insert(RecommendationBatch)
        .values(user_id=outsider["id"], type="TODAY", recommendation_date=previous_start.date())
        .returning(RecommendationBatch.id)
    )
    await _exposure(
        database_connection, user["id"], outsider_batch, 1, contents[3]["id"], previous_start
    )
    response = await _today(api, headers)
    assert _ids(response) == [contents[index]["id"] for index in [5, 4, 3, 2, 1]]


@pytest.mark.parametrize("exposed_count", [3, 6])
async def test_stage_one_fills_shortage_from_yesterday_without_duplicates(
    api, database_connection, recommendation_clock, exposed_count
):
    headers, _, user = await guest(api)
    contents = await _save_many(api, headers, database_connection, 6)
    batch_id = await database_connection.scalar(
        insert(RecommendationBatch)
        .values(
            user_id=user["id"], type="TODAY", recommendation_date=NOW.date() - timedelta(days=1)
        )
        .returning(RecommendationBatch.id)
    )
    for rank, content in enumerate(contents[-exposed_count:], 1):
        await _exposure(
            database_connection, user["id"], batch_id, rank, content["id"], NOW - timedelta(days=1)
        )
    response = await _today(api, headers)
    expected = [2, 1, 0, 5, 4] if exposed_count == 3 else [5, 4, 3, 2, 1]
    assert _ids(response) == [contents[index]["id"] for index in expected]


async def test_zero_candidates_are_not_persisted_and_reconsidered_on_next_request(
    api, database_connection, recommendation_clock
):
    headers, _, user = await guest(api)
    contents = await _save_many(api, headers, database_connection, 10)
    await database_connection.execute(
        update(Content)
        .where(Content.user_id == user["id"])
        .values(last_viewed_at=NOW, open_count=1)
    )
    empty = await _today(api, headers)
    assert empty == {
        "stage": 2,
        "recommendation_date": "2026-10-03",
        "batch_id": None,
        "generated_at": None,
        "items": [],
    }
    assert await _batches(database_connection, user["id"]) == []
    await database_connection.execute(
        update(Content)
        .where(Content.id == contents[0]["id"])
        .values(last_viewed_at=NOW - timedelta(hours=24))
    )
    available = await _today(api, headers)
    assert _ids(available) == [contents[0]["id"]]
    assert available["batch_id"] is not None
    assert len(await _batches(database_connection, user["id"])) == 1


async def test_daily_selection_is_fixed_while_content_fields_stay_current(
    api, database_connection, recommendation_clock
):
    headers, _, _ = await guest(api)
    categories = await request(api, "GET", "categories", headers=headers)
    category_ids = [category["id"] for category in categories if category["name"] != "미분류"][:2]
    await _save_many(api, headers, database_connection, 10, category_ids=[category_ids[0]])
    original = await _today(api, headers)
    persisted = await _items(database_connection, original["batch_id"])
    selected = original["items"][0]
    content_id = selected["content"]["id"]
    await request(
        api, "PUT", f"contents/{content_id}/favorite", headers=headers, json={"is_favorite": True}
    )
    await request(
        api, "PUT", f"contents/{content_id}/tags", headers=headers, json={"tag_names": ["updated"]}
    )
    await request(
        api,
        "PUT",
        f"contents/{content_id}/categories",
        headers=headers,
        json={"category_ids": [category_ids[1]]},
    )
    await request(
        api,
        "POST",
        f"contents/{content_id}/view",
        status=201,
        headers=headers,
        json={
            "client_event_id": str(uuid4()),
            "recommendation_item_id": selected["recommendation_item_id"],
        },
    )
    updated = await _today(api, headers)
    assert updated["batch_id"] == original["batch_id"]
    assert updated["generated_at"] == original["generated_at"]
    assert _ids(updated) == _ids(original)
    assert await _items(database_connection, original["batch_id"]) == persisted
    assert updated["items"][0]["content"] == await request(
        api, "GET", f"contents/{content_id}", headers=headers
    )
    assert updated["items"][0]["content"]["is_favorite"]
    assert updated["items"][0]["content"]["last_viewed_at"] is not None


async def test_deleted_item_keeps_rank_gap_without_replacement(
    api, database_connection, recommendation_clock
):
    headers, _, _ = await guest(api)
    await _save_many(api, headers, database_connection, 9)
    original = await _today(api, headers)
    removed = original["items"][2]
    await request(
        api, "DELETE", f"contents/{removed['content']['id']}", headers=headers, status=204
    )
    current = await _today(api, headers)
    assert current["batch_id"] == original["batch_id"]
    assert current["items"] == original["items"][:2] + original["items"][3:]
    assert [item["rank"] for item in current["items"]] == [1, 2, 4, 5]
    stored = await _items(database_connection, current["batch_id"])
    assert len(stored) == 5 and stored[2]["content_id"] is None
    assert stored[2]["target_id_snapshot"] == removed["content"]["id"]


async def test_deleted_all_selection_stays_empty_until_next_date(
    api, database_connection, recommendation_clock
):
    headers, _, user = await guest(api)
    await _save_many(api, headers, database_connection, 10)
    original = await _today(api, headers)
    for content_id in _ids(original):
        await request(api, "DELETE", f"contents/{content_id}", headers=headers, status=204)
    await _save_many(api, headers, database_connection, 1)
    empty = await _today(api, headers)
    assert empty["stage"] == 1 and empty["items"] == []
    assert empty["batch_id"] == original["batch_id"]
    assert empty["generated_at"] == original["generated_at"]
    assert len(await _batches(database_connection, user["id"])) == 1
    recommendation_clock.now += timedelta(days=1)
    next_day = await _today(api, headers)
    assert next_day["batch_id"] != original["batch_id"] and len(next_day["items"]) == 5
    assert len(await _batches(database_connection, user["id"])) == 2


async def test_stage_zero_hides_items_preserves_batch_metadata_and_restores_same_batch(
    api, database_connection, recommendation_clock
):
    headers, _, user = await guest(api)
    await _save_many(api, headers, database_connection, 5)
    original = await _today(api, headers)
    await request(
        api, "DELETE", f"contents/{_ids(original)[0]}", headers=headers, status=204
    )
    hidden = await _today(api, headers)
    assert hidden["stage"] == 0 and hidden["items"] == []
    assert hidden["batch_id"] == original["batch_id"]
    assert hidden["generated_at"] == original["generated_at"]
    await _save_many(api, headers, database_connection, 1)
    restored = await _today(api, headers)
    assert restored["stage"] == 1 and restored["items"] == original["items"][1:]
    assert restored["batch_id"] == original["batch_id"]
    assert len(await _batches(database_connection, user["id"])) == 1


async def test_stage_changes_keep_original_items(api, database_connection, recommendation_clock):
    headers, _, _ = await guest(api)
    contents = await _save_many(api, headers, database_connection, 9)
    original = await _today(api, headers)
    await _save_many(api, headers, database_connection, 1)
    promoted = await _today(api, headers)
    assert promoted == {**original, "stage": 2}
    for content in contents[:2]:
        assert content["id"] not in _ids(original)
        await request(api, "DELETE", f"contents/{content['id']}", headers=headers, status=204)
    demoted = await _today(api, headers)
    assert demoted == original


async def test_kst_midnight_starts_a_new_batch(api, database_connection, recommendation_clock):
    headers, _, user = await guest(api)
    await _save_many(api, headers, database_connection, 5)
    recommendation_clock.now = datetime(2026, 10, 3, 14, 59, 59, tzinfo=UTC)
    before = await _today(api, headers)
    recommendation_clock.now = datetime(2026, 10, 3, 15, tzinfo=UTC)
    after = await _today(api, headers)
    assert (before["recommendation_date"], after["recommendation_date"]) == (
        "2026-10-03", "2026-10-04"
    )
    assert before["batch_id"] != after["batch_id"]
    assert _ids(before) == _ids(after)
    assert {item["recommendation_item_id"] for item in before["items"]}.isdisjoint(
        item["recommendation_item_id"] for item in after["items"]
    )
    batches = await _batches(database_connection, user["id"])
    assert [batch["generated_at"] for batch in batches] == [
        datetime(2026, 10, 3, 14, 59, 59, tzinfo=UTC), recommendation_clock.now
    ]


async def test_youtube_summary_states_remain_eligible_and_current(
    api, database_connection, recommendation_clock
):
    headers, _, _ = await guest(api)
    contents = await _save_many(
        api, headers, database_connection, 5, original_url="https://youtu.be/dQw4w9WgXcQ"
    )
    states = ["queued", "processing", "failed", "skipped", "completed"]
    for content, status in zip(contents, states, strict=True):
        await database_connection.execute(
            update(SummaryJob)
            .where(SummaryJob.content_id == content["id"])
            .values(status=status, error_code="provider_error" if status == "failed" else None)
        )
    response = await _today(api, headers)
    assert set(_ids(response)) == {content["id"] for content in contents}
    assert {item["content"]["summary_status"] for item in response["items"]} == set(states)
    selected = response["items"][0]["content"]["id"]
    await database_connection.execute(
        update(SummaryJob).where(SummaryJob.content_id == selected).values(status="completed")
    )
    await database_connection.execute(
        update(Content).where(Content.id == selected).values(title="Updated video", summary="Ready")
    )
    updated = await _today(api, headers)
    assert _ids(updated) == _ids(response)
    assert updated["items"][0]["content"]["title"] == "Updated video"
    assert updated["items"][0]["content"]["summary"] == "Ready"
    assert updated["items"][0]["content"]["summary_status"] == "completed"


async def test_today_returns_screenshot_assets_with_existing_content_shape(
    api, database_connection, recommendation_clock, png_bytes
):
    headers, _, _ = await guest(api)
    await _save_many(api, headers, database_connection, 4)
    screenshot = await request(
        api,
        "POST",
        "uploads/screenshots",
        headers=headers,
        files={"file": ("screen.png", png_bytes, "image/png")},
        status=201,
    )
    response = await _today(api, headers)
    card = next(
        item["content"] for item in response["items"] if item["content"]["id"] == screenshot["id"]
    )
    assert card == await request(api, "GET", f"contents/{screenshot['id']}", headers=headers)
    assert card["assets"] and card["assets"][0]["download_url"]


async def test_selection_reads_do_not_record_events_exposures_or_counters(
    api, database_connection, recommendation_clock
):
    headers, _, user = await guest(api)
    await _save_many(api, headers, database_connection, 10)
    before = (
        await database_connection.execute(
            select(Content.__table__).where(Content.user_id == user["id"]).order_by(Content.id)
        )
    ).mappings().all()
    event_ids = list(await database_connection.scalars(
        select(ContentEvent.id).where(ContentEvent.user_id == user["id"]).order_by(ContentEvent.id)
    ))
    first = await _today(api, headers)
    assert await _today(api, headers) == first
    after = (
        await database_connection.execute(
            select(Content.__table__).where(Content.user_id == user["id"]).order_by(Content.id)
        )
    ).mappings().all()
    assert after == before
    assert list(await database_connection.scalars(
        select(ContentEvent.id).where(ContentEvent.user_id == user["id"]).order_by(ContentEvent.id)
    )) == event_ids
    assert await database_connection.scalar(
        select(func.count()).select_from(RecommendationExposure).where(
            RecommendationExposure.user_id == user["id"]
        )
    ) == 0


async def test_existing_batch_never_returns_a_foreign_live_target(
    api, database_connection, recommendation_clock
):
    headers, _, _ = await guest(api)
    other_headers, _, _ = await guest(api)
    await _save_many(api, headers, database_connection, 5)
    other = await link(api, other_headers)
    original = await _today(api, headers)
    foreign_item = original["items"][1]
    await database_connection.execute(
        update(RecommendationBatchItem)
        .where(RecommendationBatchItem.id == foreign_item["recommendation_item_id"])
        .values(content_id=other["id"], target_id_snapshot=other["id"])
    )
    response = await _today(api, headers)
    assert response["batch_id"] == original["batch_id"]
    assert response["items"] == original["items"][:1] + original["items"][2:]
    assert other["id"] not in _ids(response)


@pytest.mark.parametrize("failure_point", ["commit", "response_mapping"])
async def test_batch_failure_rolls_back_and_next_request_recovers(
    api, database_connection, recommendation_clock, monkeypatch, failure_point
):
    headers, _, user = await guest(api)
    await _save_many(api, headers, database_connection, 5)

    async def fail_commit(self):
        await self.flush()
        raise RuntimeError("injected Today commit failure")

    def fail_mapping(content):
        raise RuntimeError("injected Today response mapping failure")

    with monkeypatch.context() as patch:
        if failure_point == "commit":
            patch.setattr(AsyncSession, "commit", fail_commit)
        else:
            service = importlib.import_module("app.services.recommendation_service")
            patch.setattr(service, "content_to_read", fail_mapping)
        response = await api.get("/api/v1/recommendations/today", headers=headers)
        assert response.status_code == 500
    assert await _batches(database_connection, user["id"]) == []
    recovered = await _today(api, headers)
    assert len(recovered["items"]) == 5
    assert len(await _batches(database_connection, user["id"])) == 1
