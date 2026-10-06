import random
from datetime import UTC, date, datetime, timedelta
from types import SimpleNamespace
from uuid import uuid4

import pytest
from sqlalchemy import insert, select, update
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.core.config import settings
from app.integrations.youtube_summary_client import VideoSummary
from app.models.content import Content
from app.models.content_category import content_categories
from app.models.content_event import ContentEvent
from app.models.recommendation import (
    RecommendationBatch,
    RecommendationBatchItem,
    RecommendationExposure,
)
from app.models.summary_job import SummaryJob
from app.repositories.recommendation_repository import RecommendationRepository
from app.services import recommendation_service
from app.services.summary_worker import SummaryWorker
from tests.integration.helpers import guest, link, request

pytestmark = pytest.mark.asyncio
NOW = datetime(2026, 10, 3, 12, tzinfo=UTC)
START = datetime(2026, 9, 26, 15, tzinfo=UTC)


@pytest.fixture
def weekly_clock(monkeypatch):
    state = SimpleNamespace(now=NOW)
    monkeypatch.setattr(recommendation_service, "utc_now", lambda: state.now)
    original_init = recommendation_service.RecommendationService.__init__

    def seeded_init(self, *args, **kwargs):
        kwargs["rng"] = random.Random(7)
        original_init(self, *args, **kwargs)

    monkeypatch.setattr(recommendation_service.RecommendationService, "__init__", seeded_init)
    return state


async def _categories(api, headers):
    return [
        category for category in await request(api, "GET", "categories", headers=headers)
        if category["name"] != "미분류"
    ]


async def _save(
    api, headers, connection, category_ids, *, history=True, saved_at=None, **overrides
):
    content = await link(api, headers, category_ids=category_ids, **overrides)
    await connection.execute(
        update(Content)
        .where(Content.id == content["id"])
        .values(saved_at=saved_at or NOW - timedelta(days=10))
    )
    await connection.execute(
        update(ContentEvent)
        .where(
            ContentEvent.content_id == content["id"], ContentEvent.event_type == "content_created"
        )
        .values(
            created_at=NOW - timedelta(hours=2),
            category_ids_at_event=category_ids if history else None,
        )
    )
    return content


async def _event(
    connection, user_id, content_id, category_ids, *, when=None, kind="content_reopened"
):
    return await connection.scalar(
        insert(ContentEvent)
        .values(
            user_id=user_id,
            content_id=content_id,
            event_type=kind,
            category_ids_at_event=category_ids,
            created_at=when or NOW - timedelta(hours=1),
        )
        .returning(ContentEvent.id)
    )


async def _candidates(connection, user_id, *, start=START, end=NOW, content_ids=None):
    async with AsyncSession(
        bind=connection, expire_on_commit=False, join_transaction_mode="create_savepoint"
    ) as session:
        if content_ids is None:
            content_ids = list(await session.scalars(
                select(Content.id).where(Content.user_id == user_id)
            ))
        candidates = await RecommendationRepository(session).list_weekly_candidates(
            user_id=user_id, content_ids=content_ids, start=start, end=end
        )
        return {candidate.category.id: candidate for candidate in candidates}


async def _rows(connection, model, user_id):
    return (
        await connection.execute(
            select(model.__table__).where(model.user_id == user_id).order_by(model.id)
        )
    ).mappings().all()


async def _weekly(api, headers):
    response = await api.get("/api/v1/recommendations/weekly", headers=headers)
    assert response.status_code == 200, response.text
    assert response.headers["cache-control"] == "no-store"
    body = response.json()
    assert set(body) == {"period_start", "period_end", "batch_id", "generated_at", "items"}
    for item in body["items"]:
        assert set(item) == {"recommendation_item_id", "rank", "card_type", "category"}
        assert set(item["category"]) == {
            "id", "name", "color", "is_default", "content_count", "last_saved_at"
        }
    return body


async def _exposure(
    connection, user_id, target_id, when, *, surface="WEEKLY_PICK", kind="CATEGORY", owner_id=None
):
    batch_id = await connection.scalar(
        insert(RecommendationBatch)
        .values(
            user_id=owner_id or user_id,
            type=surface,
            recommendation_date=date(2000, 1, 1) if surface == "TODAY" else None,
            generated_at=NOW - timedelta(days=30),
        )
        .returning(RecommendationBatch.id)
    )
    item_id = await connection.scalar(
        insert(RecommendationBatchItem)
        .values(
            batch_id=batch_id,
            rank=1,
            target_kind=kind,
            target_id_snapshot=target_id,
            category_id=target_id if kind == "CATEGORY" else None,
            content_id=target_id if kind == "CONTENT" else None,
            card_type="MOST_SAVED" if kind == "CATEGORY" else None,
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


async def test_aggregation_uses_all_snapshot_categories_and_distinct_views_without_join_inflation(
    api, database_connection
):
    headers, _, user = await guest(api)
    first, second = (await _categories(api, headers))[:2]
    a, b = first["id"], second["id"]
    one = await _save(api, headers, database_connection, [a, b])
    two = await _save(api, headers, database_connection, [a])
    await _save(api, headers, database_connection, [b], history=False)
    await database_connection.execute(
        update(ContentEvent)
        .where(ContentEvent.content_id == one["id"], ContentEvent.event_type == "content_created")
        .values(category_ids_at_event=[a, a, b, b])
    )
    await _event(database_connection, user["id"], one["id"], [a, a, b], when=START)
    latest_view = NOW - timedelta(minutes=10)
    await _event(database_connection, user["id"], one["id"], [a, b, b], when=latest_view)
    await _event(database_connection, user["id"], two["id"], [a])
    await _event(database_connection, user["id"], two["id"], [a, b], kind="card_clicked")
    await _exposure(database_connection, user["id"], a, START)
    await _exposure(database_connection, user["id"], a, NOW - timedelta(minutes=5))
    await _exposure(database_connection, user["id"], b, NOW - timedelta(minutes=3))

    candidates = await _candidates(database_connection, user["id"])
    assert set(candidates) == {a, b}
    assert (candidates[a].saved_count, candidates[b].saved_count) == (2, 1)
    assert (candidates[a].viewed_count, candidates[b].viewed_count) == (2, 1)
    assert candidates[a].last_viewed_event_at == candidates[b].last_viewed_event_at == latest_view
    assert candidates[a].last_saved_event_at == NOW - timedelta(hours=2)
    assert candidates[a].category.content_count == candidates[b].category.content_count == 2
    assert candidates[a].category.last_saved_at == NOW - timedelta(days=10)
    assert candidates[a].last_exposed_at == NOW - timedelta(minutes=5)


async def test_activity_window_includes_start_and_excludes_end_and_future(api, database_connection):
    headers, _, user = await guest(api)
    category_id = (await _categories(api, headers))[0]["id"]
    contents = [
        await _save(api, headers, database_connection, [category_id], history=False)
        for _ in range(5)
    ]
    timestamps = [
        START - timedelta(microseconds=1), START, NOW - timedelta(microseconds=1),
        NOW, NOW + timedelta(microseconds=1),
    ]
    for content, timestamp in zip(contents, timestamps, strict=True):
        for kind in ["content_created", "content_reopened"]:
            await _event(
                database_connection, user["id"], content["id"], [category_id],
                when=timestamp, kind=kind,
            )
    candidate = (await _candidates(database_connection, user["id"]))[category_id]
    assert candidate.saved_count == candidate.viewed_count == 2
    assert candidate.last_saved_event_at == candidate.last_viewed_event_at == timestamps[2]


async def test_separate_save_events_for_same_content_are_counted_without_guessing_retries(
    api, database_connection
):
    headers, _, user = await guest(api)
    category_id = (await _categories(api, headers))[0]["id"]
    content = await _save(api, headers, database_connection, [category_id])
    saved_again_at = NOW - timedelta(hours=1)
    await _event(
        database_connection, user["id"], content["id"], [category_id, category_id],
        when=saved_again_at, kind="content_created",
    )
    candidate = (await _candidates(database_connection, user["id"]))[category_id]
    assert candidate.saved_count == 2
    assert candidate.category.content_count == 1
    assert candidate.last_saved_event_at == saved_again_at


async def test_old_snapshots_survive_movement_and_unknown_or_uncategorized_history_is_ignored(
    api, database_connection
):
    headers, _, user = await guest(api)
    categories = await _categories(api, headers)
    a, b = [category["id"] for category in categories[:2]]
    await _save(api, headers, database_connection, [a], history=False)
    moving = await _save(api, headers, database_connection, [a])
    viewed_at = NOW - timedelta(minutes=30)
    await _event(database_connection, user["id"], moving["id"], [a], when=viewed_at)
    await request(
        api, "PUT", f"contents/{moving['id']}/categories", headers=headers,
        json={"category_ids": [b]},
    )
    unknown = await _save(api, headers, database_connection, [b], history=False)
    await database_connection.execute(
        update(ContentEvent)
        .where(
            ContentEvent.content_id == unknown["id"], ContentEvent.event_type == "content_created"
        )
        .values(category_id=b, metadata_json='{"category_ids":[123]}')
    )
    await _event(database_connection, user["id"], unknown["id"], [])
    uncategorized = next(
        category["id"] for category in await request(api, "GET", "categories", headers=headers)
        if category["name"] == "미분류"
    )
    classified_later = await _save(api, headers, database_connection, [uncategorized])
    await request(
        api, "PUT", f"contents/{classified_later['id']}/categories", headers=headers,
        json={"category_ids": [b]},
    )
    candidates = await _candidates(database_connection, user["id"])
    assert set(candidates) == {a, b}
    assert (candidates[a].saved_count, candidates[a].viewed_count) == (1, 1)
    assert candidates[a].last_viewed_event_at == viewed_at
    assert (candidates[b].saved_count, candidates[b].viewed_count) == (0, 0)
    assert candidates[b].last_saved_event_at is None
    assert candidates[b].last_viewed_event_at is None
    assert (candidates[a].category.content_count, candidates[b].category.content_count) == (1, 3)
    snapshot = await database_connection.scalar(
        select(ContentEvent.category_ids_at_event).where(
            ContentEvent.content_id == classified_later["id"],
            ContentEvent.event_type == "content_created",
        )
    )
    assert snapshot == [uncategorized]


async def test_aggregation_filters_each_owner_deleted_targets_and_empty_categories(
    api, database_connection
):
    headers, _, user = await guest(api)
    other_headers, _, other_user = await guest(api)
    a, empty, removed_category = [
        category["id"] for category in (await _categories(api, headers))[:3]
    ]
    foreign_category = (await _categories(api, other_headers))[0]["id"]
    kept = await _save(api, headers, database_connection, [a])
    foreign = await _save(api, other_headers, database_connection, [foreign_category])
    deleted = await _save(api, headers, database_connection, [a])
    losing_category = await _save(api, headers, database_connection, [removed_category])
    await request(api, "DELETE", f"contents/{deleted['id']}", headers=headers, status=204)
    await request(api, "DELETE", f"categories/{removed_category}", headers=headers, status=204)
    await database_connection.execute(insert(content_categories), [
        {"content_id": foreign["id"], "category_id": a},
        {"content_id": kept["id"], "category_id": foreign_category},
    ])
    await _event(database_connection, user["id"], foreign["id"], [a])
    await _event(database_connection, other_user["id"], kept["id"], [a])
    await _event(
        database_connection, user["id"], kept["id"], [foreign_category, empty, 2_147_483_647]
    )
    await _event(database_connection, user["id"], None, [a])
    await _event(database_connection, user["id"], kept["id"], [a])
    candidates = await _candidates(
        database_connection, user["id"],
        content_ids=[kept["id"], foreign["id"], deleted["id"], losing_category["id"]],
    )
    assert set(candidates) == {a}
    assert candidates[a].saved_count == candidates[a].viewed_count == 1
    assert candidates[a].category.content_count == 1


async def test_exposure_recency_uses_weekly_category_events_only_with_owned_half_open_window(
    api, database_connection
):
    headers, _, user = await guest(api)
    other_headers, _, other_user = await guest(api)
    a, b = [category["id"] for category in (await _categories(api, headers))[:2]]
    await _save(api, headers, database_connection, [a], history=False)
    content_b = await _save(api, headers, database_connection, [b], history=False)
    await _exposure(database_connection, user["id"], a, START)
    await _exposure(database_connection, user["id"], a, NOW - timedelta(microseconds=1))
    await _exposure(database_connection, user["id"], a, NOW)
    await _exposure(database_connection, user["id"], a, NOW + timedelta(hours=1))
    await _exposure(database_connection, user["id"], b, START - timedelta(microseconds=1))
    await _exposure(database_connection, user["id"], b, START, surface="TODAY")
    await _exposure(database_connection, user["id"], content_b["id"], START, kind="CONTENT")
    await _exposure(database_connection, user["id"], b, START, owner_id=other_user["id"])
    await _exposure(database_connection, other_user["id"], b, START, owner_id=user["id"])
    candidates = await _candidates(database_connection, user["id"])
    assert candidates[a].last_exposed_at == NOW - timedelta(microseconds=1)
    assert candidates[b].last_exposed_at is None


@pytest.mark.parametrize("count", [0, 1, 2, 3])
async def test_weekly_api_shape_period_and_availability_are_independent_of_today_stage(
    api, database_connection, weekly_clock, count
):
    headers, _, user = await guest(api)
    categories = await _categories(api, headers)
    for category in categories[:count]:
        await _save(api, headers, database_connection, [category["id"]])
    result = await _weekly(api, headers)
    assert datetime.fromisoformat(result["period_start"]) == START
    assert datetime.fromisoformat(result["period_end"]) == NOW
    assert len(result["items"]) == min(2, count)
    assert [item["rank"] for item in result["items"]] == list(range(1, min(2, count) + 1))
    assert len({item["category"]["id"] for item in result["items"]}) == len(result["items"])
    today = await request(api, "GET", "recommendations/today", headers=headers)
    assert today["stage"] == 0
    batches = await _rows(database_connection, RecommendationBatch, user["id"])
    if count == 0:
        assert result["batch_id"] is None and result["generated_at"] is None
        assert batches == []
    else:
        assert result["items"][0]["card_type"] == "MOST_SAVED"
        assert len(batches) == 1 and batches[0]["id"] == result["batch_id"]
        assert batches[0]["type"] == "WEEKLY_PICK" and batches[0]["recommendation_date"] is None
        assert batches[0]["generated_at"] == NOW


async def test_weekly_activity_selects_distinct_cards_and_each_read_stores_new_current_result(
    api, database_connection, weekly_clock
):
    headers, _, user = await guest(api)
    a, b = [category["id"] for category in (await _categories(api, headers))[:2]]
    await _save(api, headers, database_connection, [a])
    await _save(api, headers, database_connection, [a])
    viewed = await _save(api, headers, database_connection, [b])
    await _event(database_connection, user["id"], viewed["id"], [b])
    original = await _weekly(api, headers)
    assert [(item["card_type"], item["category"]["id"]) for item in original["items"]] == [
        ("MOST_SAVED", a), ("MOST_VIEWED", b)
    ]
    await request(
        api, "PATCH", f"categories/{a}", headers=headers,
        json={"name": "최신 카테고리", "color": "#123456"},
    )
    await _save(api, headers, database_connection, [a], saved_at=NOW - timedelta(minutes=1))
    weekly_clock.now += timedelta(minutes=1)
    current = await _weekly(api, headers)
    assert current["batch_id"] != original["batch_id"]
    assert datetime.fromisoformat(current["generated_at"]) == weekly_clock.now
    summaries = {category["id"]: category for category in await _categories(api, headers)}
    assert [item["category"] for item in current["items"]] == [summaries[a], summaries[b]]
    assert current["items"][0]["category"]["content_count"] == 3
    persisted = (
        await database_connection.execute(
            select(RecommendationBatchItem.__table__)
            .where(RecommendationBatchItem.batch_id == current["batch_id"])
            .order_by(RecommendationBatchItem.rank)
        )
    ).mappings().all()
    assert [item["id"] for item in persisted] == [
        item["recommendation_item_id"] for item in current["items"]
    ]
    assert all(item["score"] is None and item["content_id"] is None for item in persisted)
    assert [item["target_id_snapshot"] for item in persisted] == [a, b]
    assert len(await _rows(database_connection, RecommendationBatch, user["id"])) == 2


async def test_youtube_summary_state_does_not_exclude_content_from_weekly(
    api, database_connection, weekly_clock
):
    headers, _, user = await guest(api)
    category_id = (await _categories(api, headers))[0]["id"]
    for state in ["queued", "processing", "completed", "failed", "skipped"]:
        content = await _save(
            api, headers, database_connection, [category_id],
            original_url="https://youtu.be/dQw4w9WgXcQ",
        )
        await database_connection.execute(
            update(SummaryJob).where(SummaryJob.content_id == content["id"]).values(status=state)
        )
    candidate = (await _candidates(database_connection, user["id"]))[category_id]
    assert candidate.category.content_count == candidate.saved_count == 5
    weekly = await _weekly(api, headers)
    assert len(weekly["items"]) == 1
    assert weekly["items"][0]["category"]["content_count"] == 5
    assert weekly["items"][0]["card_type"] == "MOST_SAVED"


async def test_summary_worker_keeps_uncategorized_save_snapshot_out_of_weekly_activity(
    api, database_connection, weekly_clock
):
    headers, _, user = await guest(api)
    category_id = (await _categories(api, headers))[0]["id"]
    content = await link(api, headers, original_url="https://youtu.be/dQw4w9WgXcQ")
    assert [category["name"] for category in content["categories"]] == ["미분류"]
    uncategorized_id = content["categories"][0]["id"]
    await database_connection.execute(
        update(ContentEvent)
        .where(
            ContentEvent.content_id == content["id"], ContentEvent.event_type == "content_created"
        )
        .values(created_at=NOW - timedelta(hours=2))
    )
    original_events = await _rows(database_connection, ContentEvent, user["id"])
    assert len(original_events) == 1
    assert original_events[0]["category_ids_at_event"] == [uncategorized_id]
    assert (await _weekly(api, headers))["items"] == []

    lease_token = str(uuid4())
    await database_connection.execute(
        update(SummaryJob)
        .where(SummaryJob.content_id == content["id"])
        .values(
            status="processing", attempts=1, lease_token=lease_token,
            lease_expires_at=datetime.now(UTC) + timedelta(minutes=5),
        )
    )
    sessions = async_sessionmaker(
        bind=database_connection, expire_on_commit=False, join_transaction_mode="create_savepoint"
    )
    worker = SummaryWorker(sessions, SimpleNamespace(), settings)
    await worker.finish(
        content["id"], user["id"], lease_token,
        VideoSummary("자동 분류한 영상", "영상 요약", category_id, {}), None,
    )
    detail = await request(api, "GET", f"contents/{content['id']}", headers=headers)
    assert detail["summary_status"] == "completed"
    assert [category["id"] for category in detail["categories"]] == [category_id]
    assert detail["saved_at"] == content["saved_at"]
    events = await _rows(database_connection, ContentEvent, user["id"])
    assert events[0] == original_events[0]
    assert [event["event_type"] for event in events] == ["content_created", "category_changed"]
    candidate = (await _candidates(database_connection, user["id"]))[category_id]
    assert candidate.category.content_count == 1
    assert candidate.saved_count == candidate.viewed_count == 0
    weekly = await _weekly(api, headers)
    assert weekly["items"][0]["category"]["id"] == category_id
    assert weekly["items"][0]["card_type"] == "REDISCOVERY"


async def test_no_history_uses_rediscovery_and_exposures_change_next_selection(
    api, database_connection, weekly_clock
):
    headers, _, user = await guest(api)
    categories = (await _categories(api, headers))[:3]
    for category in categories:
        await _save(api, headers, database_connection, [category["id"]], history=False)
    exposed_ids = [category["id"] for category in categories[:2]]
    await _exposure(database_connection, user["id"], exposed_ids[0], START)
    await _exposure(database_connection, user["id"], exposed_ids[1], START + timedelta(days=1))
    result = await _weekly(api, headers)
    assert [item["card_type"] for item in result["items"]] == ["REDISCOVERY", "REDISCOVERY"]
    assert [item["category"]["id"] for item in result["items"]] == [
        categories[2]["id"], exposed_ids[0]
    ]


async def test_empty_current_categories_return_no_new_batch_after_previous_result(
    api, database_connection, weekly_clock
):
    headers, _, user = await guest(api)
    category_id = (await _categories(api, headers))[0]["id"]
    content = await _save(api, headers, database_connection, [category_id])
    original = await _weekly(api, headers)
    await request(api, "DELETE", f"contents/{content['id']}", headers=headers, status=204)
    empty = await _weekly(api, headers)
    assert empty["items"] == [] and empty["batch_id"] is None and empty["generated_at"] is None
    assert len(await _rows(database_connection, RecommendationBatch, user["id"])) == 1
    batches = await _rows(database_connection, RecommendationBatch, user["id"])
    assert batches[0]["id"] == original["batch_id"]


async def test_weekly_auth_user_isolation_and_get_has_no_action_side_effects(
    api, database_connection, weekly_clock
):
    headers, _, user = await guest(api)
    other_headers, _, other_user = await guest(api)
    own_category = (await _categories(api, headers))[0]["id"]
    other_category = (await _categories(api, other_headers))[0]["id"]
    await _save(api, headers, database_connection, [own_category])
    await _save(api, other_headers, database_connection, [other_category])
    unauthorized = await api.get("/api/v1/recommendations/weekly")
    assert unauthorized.status_code == 401
    before = [
        await _rows(database_connection, model, user["id"])
        for model in [Content, ContentEvent, RecommendationExposure]
    ]
    first = await _weekly(api, headers)
    second = await _weekly(api, other_headers)
    assert first["items"][0]["category"]["id"] == own_category
    assert second["items"][0]["category"]["id"] == other_category
    assert first["batch_id"] != second["batch_id"]
    after = [
        await _rows(database_connection, model, user["id"])
        for model in [Content, ContentEvent, RecommendationExposure]
    ]
    assert after == before
    assert len(await _rows(database_connection, RecommendationBatch, other_user["id"])) == 1


async def test_real_weekly_item_supports_view_before_exposure_and_later_category_changes(
    api, database_connection, weekly_clock
):
    headers, _, user = await guest(api)
    a, b = [category["id"] for category in (await _categories(api, headers))[:2]]
    content = await _save(api, headers, database_connection, [a])
    weekly = await _weekly(api, headers)
    item_id = weekly["items"][0]["recommendation_item_id"]
    payload = {"client_event_id": str(uuid4()), "recommendation_item_id": item_id}
    await request(
        api, "POST", f"contents/{content['id']}/view", headers=headers, json=payload, status=201
    )
    assert await _rows(database_connection, RecommendationExposure, user["id"]) == []
    await request(
        api, "PUT", f"contents/{content['id']}/categories", headers=headers,
        json={"category_ids": [b]},
    )
    await request(
        api, "POST", f"contents/{content['id']}/view", headers=headers, json=payload, status=201
    )
    await request(
        api, "POST", f"contents/{content['id']}/view", headers=headers,
        json={**payload, "client_event_id": str(uuid4())}, status=422,
    )
    exposure = await request(
        api, "POST", "recommendations/exposures", headers=headers,
        json={**payload, "client_event_id": str(uuid4())}, status=201,
    )
    assert exposure["recommendation_item_id"] == item_id
    stored_content = (await _rows(database_connection, Content, user["id"]))[0]
    assert stored_content["open_count"] == 1 and stored_content["recommendation_count"] == 0
    fresh = await _weekly(api, headers)
    assert fresh["batch_id"] != weekly["batch_id"]
    assert fresh["items"][0]["category"]["id"] == b
    assert fresh["items"][0]["card_type"] == "REDISCOVERY"


@pytest.mark.parametrize("failure_point", ["batch_insert", "response", "commit"])
async def test_weekly_failure_rolls_back_new_batch_and_subsequent_request_recovers(
    api, database_connection, weekly_clock, monkeypatch, failure_point
):
    headers, _, user = await guest(api)
    category_id = (await _categories(api, headers))[0]["id"]
    await _save(api, headers, database_connection, [category_id])
    create_batch = RecommendationRepository.create_weekly_batch

    async def fail_insert(self, **kwargs):
        await create_batch(self, **kwargs)
        raise RuntimeError("injected Weekly batch failure")

    async def fail_commit(self):
        await self.flush()
        raise RuntimeError("injected Weekly commit failure")

    def fail_response(**kwargs):
        raise RuntimeError("injected Weekly response failure")

    with monkeypatch.context() as patch:
        if failure_point == "batch_insert":
            patch.setattr(RecommendationRepository, "create_weekly_batch", fail_insert)
        elif failure_point == "commit":
            patch.setattr(AsyncSession, "commit", fail_commit)
        else:
            patch.setattr(recommendation_service, "WeeklyRecommendationResponse", fail_response)
        response = await api.get("/api/v1/recommendations/weekly", headers=headers)
        assert response.status_code == 500
    assert await _rows(database_connection, RecommendationBatch, user["id"]) == []
    recovered = await _weekly(api, headers)
    assert len(recovered["items"]) == 1
    assert len(await _rows(database_connection, RecommendationBatch, user["id"])) == 1
