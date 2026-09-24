from datetime import UTC, date, datetime, timedelta
from types import SimpleNamespace
from uuid import UUID, uuid4

import pytest
from sqlalchemy import insert, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.content import Content
from app.models.content_event import ContentEvent
from app.models.recommendation import (
    RecommendationBatch,
    RecommendationBatchItem,
    RecommendationExposure,
)
from app.repositories.content_repository import ContentRepository
from app.repositories.recommendation_repository import RecommendationRepository
from app.services import recommendation_service
from tests.integration.helpers import guest, link, request

pytestmark = pytest.mark.asyncio
NOW = datetime(2026, 10, 3, 12, tzinfo=UTC)


@pytest.fixture
def exposure_clock(monkeypatch):
    state = SimpleNamespace(now=NOW)
    monkeypatch.setattr(recommendation_service, "utc_now", lambda: state.now)
    return state


async def _item(
    connection,
    user_id,
    *,
    content_id=None,
    category_id=None,
    surface=None,
    card_type="MOST_SAVED",
    day=1,
):
    kind = "CATEGORY" if category_id is not None else "CONTENT"
    surface = surface or ("WEEKLY_PICK" if kind == "CATEGORY" else "TODAY")
    batch_id = await connection.scalar(
        insert(RecommendationBatch)
        .values(
            user_id=user_id,
            type=surface,
            recommendation_date=date(2000, 1, day) if surface == "TODAY" else None,
        )
        .returning(RecommendationBatch.id)
    )
    return await connection.scalar(
        insert(RecommendationBatchItem)
        .values(
            batch_id=batch_id,
            rank=1,
            target_kind=kind,
            target_id_snapshot=category_id or content_id,
            content_id=content_id,
            category_id=category_id,
            card_type=card_type if kind == "CATEGORY" else None,
        )
        .returning(RecommendationBatchItem.id)
    )


async def _expose(api, headers, payload, *, status=201):
    response = await api.post(
        "/api/v1/recommendations/exposures", headers=headers, json=payload
    )
    assert response.status_code == status, response.text
    if status == 201:
        assert response.headers["cache-control"] == "no-store"
        body = response.json()
        assert set(body) == {
            "exposure_id", "client_event_id", "recommendation_item_id", "recommended_at"
        }
        assert body["exposure_id"] > 0
        assert body["client_event_id"] == payload["client_event_id"]
        assert body["recommendation_item_id"] == payload["recommendation_item_id"]
    return response.json()


async def _contents(connection, user_id):
    return (
        await connection.execute(
            select(Content.__table__).where(Content.user_id == user_id).order_by(Content.id)
        )
    ).mappings().all()


async def _exposures(connection, user_id):
    return (
        await connection.execute(
            select(RecommendationExposure.__table__)
            .where(RecommendationExposure.user_id == user_id)
            .order_by(RecommendationExposure.id)
        )
    ).mappings().all()


async def _events(connection, user_id):
    return (
        await connection.execute(
            select(ContentEvent.__table__)
            .where(ContentEvent.user_id == user_id)
            .order_by(ContentEvent.id)
        )
    ).mappings().all()


async def test_content_exposure_retries_are_stable_and_new_ids_count_separately(
    api, database_connection, exposure_clock
):
    headers, _, user = await guest(api)
    content = await link(api, headers)
    item_id = await _item(database_connection, user["id"], content_id=content["id"])
    payload = {"client_event_id": str(uuid4()), "recommendation_item_id": item_id}
    before = (await _contents(database_connection, user["id"]))[0]
    old_events = await _events(database_connection, user["id"])
    response = await _expose(api, headers, payload)
    assert datetime.fromisoformat(response["recommended_at"]) == exposure_clock.now
    first_state = await _contents(database_connection, user["id"])
    assert first_state == [{
        **before,
        "recommendation_count": 1,
        "last_recommended_at": NOW,
        "last_recommended_surface": "TODAY",
    }]
    exposure_clock.now += timedelta(minutes=1)
    assert await _expose(api, headers, payload) == response
    assert await _contents(database_connection, user["id"]) == first_state
    assert len(await _exposures(database_connection, user["id"])) == 1

    new_payload = {**payload, "client_event_id": str(uuid4())}
    second = await _expose(api, headers, new_payload)
    assert second["exposure_id"] != response["exposure_id"]
    latest = (await _contents(database_connection, user["id"]))[0]
    assert latest["recommendation_count"] == 2
    assert latest["last_recommended_at"] == exposure_clock.now
    records = await _exposures(database_connection, user["id"])
    assert len(records) == 2
    assert records[0]["client_event_id"] == UUID(payload["client_event_id"])
    assert records[1]["recommended_at"] == latest["last_recommended_at"]
    assert await _events(database_connection, user["id"]) == old_events
    assert await request(api, "GET", "users/me/stats", headers=headers) == {
        "saved_count": 1, "reopened_count": 0
    }


@pytest.mark.parametrize("card_type", ["MOST_SAVED", "MOST_VIEWED", "REDISCOVERY"])
async def test_category_exposure_only_records_history_for_all_card_types(
    api, database_connection, exposure_clock, card_type
):
    headers, _, user = await guest(api)
    content = await link(api, headers)
    category_id = content["categories"][0]["id"]
    await link(api, headers, category_ids=[category_id])
    item_id = await _item(
        database_connection, user["id"], category_id=category_id, card_type=card_type
    )
    before = await _contents(database_connection, user["id"])
    old_events = await _events(database_connection, user["id"])
    payload = {"client_event_id": str(uuid4()), "recommendation_item_id": item_id}
    first = await _expose(api, headers, payload)
    exposure_clock.now += timedelta(minutes=5)
    assert await _expose(api, headers, payload) == first
    await _expose(api, headers, {**payload, "client_event_id": str(uuid4())})
    assert len(await _exposures(database_connection, user["id"])) == 2
    assert await _contents(database_connection, user["id"]) == before
    assert await _events(database_connection, user["id"]) == old_events


async def test_view_and_exposure_ids_are_independent_and_neither_records_the_other_action(
    api, database_connection, exposure_clock
):
    headers, _, user = await guest(api)
    content = await link(api, headers)
    item_id = await _item(database_connection, user["id"], content_id=content["id"])
    payload = {"client_event_id": str(uuid4()), "recommendation_item_id": item_id}
    await request(
        api, "POST", f"contents/{content['id']}/view", headers=headers, json=payload, status=201
    )
    after_view = (await _contents(database_connection, user["id"]))[0]
    assert after_view["open_count"] == 1 and after_view["recommendation_count"] == 0
    assert await _exposures(database_connection, user["id"]) == []
    view_events = await _events(database_connection, user["id"])
    await _expose(api, headers, payload)
    after_exposure = (await _contents(database_connection, user["id"]))[0]
    assert after_exposure["open_count"] == 1 and after_exposure["recommendation_count"] == 1
    assert after_exposure["last_viewed_at"] == after_view["last_viewed_at"]
    assert await _events(database_connection, user["id"]) == view_events
    await request(
        api, "POST", f"contents/{content['id']}/view", headers=headers, json=payload, status=201
    )
    assert (await _contents(database_connection, user["id"]))[0] == after_exposure


@pytest.mark.parametrize(
    "payload",
    [
        None,
        {},
        [],
        "not-an-object",
        {"recommendation_item_id": 1},
        {"client_event_id": str(uuid4())},
        {"client_event_id": None, "recommendation_item_id": 1},
        {"client_event_id": "invalid", "recommendation_item_id": 1},
        {"client_event_id": str(uuid4()), "recommendation_item_id": None},
        {"client_event_id": str(uuid4()), "recommendation_item_id": 0},
        {"client_event_id": str(uuid4()), "recommendation_item_id": -1},
        {"client_event_id": str(uuid4()), "recommendation_item_id": True},
        {"client_event_id": str(uuid4()), "recommendation_item_id": 1.0},
        {"client_event_id": str(uuid4()), "recommendation_item_id": "1"},
        {"client_event_id": str(uuid4()), "recommendation_item_id": 2_147_483_648},
        {
            "client_event_id": str(uuid4()),
            "recommendation_item_id": 1,
            "recommended_at": NOW.isoformat(),
        },
    ],
)
async def test_exposure_rejects_invalid_body_without_writes(api, database_connection, payload):
    headers, _, user = await guest(api)
    await _expose(api, headers, payload, status=422)
    assert await _exposures(database_connection, user["id"]) == []


async def test_exposure_requires_auth_and_a_body(api, database_connection):
    headers, _, user = await guest(api)
    await _expose(
        api,
        {},
        {"client_event_id": str(uuid4()), "recommendation_item_id": 1},
        status=401,
    )
    missing = await api.post("/api/v1/recommendations/exposures", headers=headers)
    assert missing.status_code == 422
    explicit_null = await api.post(
        "/api/v1/recommendations/exposures",
        headers={**headers, "Content-Type": "application/json"},
        content="null",
    )
    assert explicit_null.status_code == 422
    assert await _exposures(database_connection, user["id"]) == []


@pytest.mark.parametrize(
    "case", ["missing", "foreign_batch", "foreign_content", "foreign_category"]
)
async def test_new_exposure_rejects_inaccessible_item_or_live_target(
    api, database_connection, case
):
    headers, _, user = await guest(api)
    other_headers, _, other_user = await guest(api)
    own = await link(api, headers)
    foreign = await link(api, other_headers)
    if case == "missing":
        item_id = 2_147_483_647
    elif case == "foreign_batch":
        item_id = await _item(database_connection, other_user["id"], content_id=own["id"])
    elif case == "foreign_content":
        item_id = await _item(database_connection, user["id"], content_id=foreign["id"])
    else:
        item_id = await _item(
            database_connection, user["id"], category_id=foreign["categories"][0]["id"]
        )
    before = await _contents(database_connection, user["id"])
    await _expose(
        api,
        headers,
        {"client_event_id": str(uuid4()), "recommendation_item_id": item_id},
        status=404,
    )
    assert await _exposures(database_connection, user["id"]) == []
    assert await _contents(database_connection, user["id"]) == before


@pytest.mark.parametrize("surface", ["TODAY", "WEEKLY_PICK"])
async def test_exposure_rejects_accessible_surface_target_mismatch(
    api, database_connection, surface
):
    headers, _, user = await guest(api)
    content = await link(api, headers)
    target = {"content_id": content["id"]} if surface == "WEEKLY_PICK" else {
        "category_id": content["categories"][0]["id"]
    }
    item_id = await _item(database_connection, user["id"], surface=surface, **target)
    await _expose(
        api,
        headers,
        {"client_event_id": str(uuid4()), "recommendation_item_id": item_id},
        status=422,
    )
    assert await _exposures(database_connection, user["id"]) == []


@pytest.mark.parametrize("kind", ["CONTENT", "CATEGORY"])
async def test_retry_survives_target_deletion_but_new_exposure_is_rejected(
    api, database_connection, exposure_clock, kind
):
    headers, _, user = await guest(api)
    content = await link(api, headers)
    category_id = content["categories"][0]["id"]
    target = {"content_id": content["id"]} if kind == "CONTENT" else {"category_id": category_id}
    item_id = await _item(database_connection, user["id"], **target)
    payload = {"client_event_id": str(uuid4()), "recommendation_item_id": item_id}
    original = await _expose(api, headers, payload)
    deletion = f"contents/{content['id']}" if kind == "CONTENT" else f"categories/{category_id}"
    await request(api, "DELETE", deletion, headers=headers, status=204)
    exposure_clock.now += timedelta(days=1)
    assert await _expose(api, headers, payload) == original
    await _expose(
        api, headers, {**payload, "client_event_id": str(uuid4())}, status=404
    )
    assert len(await _exposures(database_connection, user["id"])) == 1
    stored = (
        await database_connection.execute(
            select(RecommendationBatchItem.__table__).where(RecommendationBatchItem.id == item_id)
        )
    ).mappings().one()
    assert stored["content_id"] is None and stored["category_id"] is None
    assert stored["target_id_snapshot"] == (content["id"] if kind == "CONTENT" else category_id)


@pytest.mark.parametrize("kind", ["CONTENT", "CATEGORY"])
async def test_target_metadata_changes_preserve_retries_and_allow_new_exposures(
    api, database_connection, exposure_clock, kind
):
    headers, _, user = await guest(api)
    content = await link(api, headers)
    category_id = content["categories"][0]["id"]
    target = {"content_id": content["id"]} if kind == "CONTENT" else {"category_id": category_id}
    item_id = await _item(database_connection, user["id"], **target)
    payload = {"client_event_id": str(uuid4()), "recommendation_item_id": item_id}
    original = await _expose(api, headers, payload)
    original_exposures = await _exposures(database_connection, user["id"])

    if kind == "CONTENT":
        categories = await request(api, "GET", "categories", headers=headers)
        replacement = next(
            category["id"] for category in categories
            if category["id"] != category_id and category["name"] != "미분류"
        )
        await request(
            api,
            "PUT",
            f"contents/{content['id']}/categories",
            headers=headers,
            json={"category_ids": [replacement]},
        )
        await request(
            api,
            "PUT",
            f"contents/{content['id']}/favorite",
            headers=headers,
            json={"is_favorite": True},
        )
    else:
        await request(
            api,
            "PATCH",
            f"categories/{category_id}",
            headers=headers,
            json={"name": "새 카테고리 이름"},
        )

    after_changes = await _contents(database_connection, user["id"])
    after_change_events = await _events(database_connection, user["id"])
    exposure_clock.now += timedelta(minutes=2)
    assert await _expose(api, headers, payload) == original
    assert await _contents(database_connection, user["id"]) == after_changes
    assert await _exposures(database_connection, user["id"]) == original_exposures

    fresh = await _expose(api, headers, {**payload, "client_event_id": str(uuid4())})
    assert fresh["exposure_id"] != original["exposure_id"]
    assert datetime.fromisoformat(fresh["recommended_at"]) == exposure_clock.now
    assert len(await _exposures(database_connection, user["id"])) == 2
    expected = after_changes if kind == "CATEGORY" else [{
        **after_changes[0],
        "recommendation_count": 2,
        "last_recommended_at": exposure_clock.now,
    }]
    assert await _contents(database_connection, user["id"]) == expected
    assert await _events(database_connection, user["id"]) == after_change_events


@pytest.mark.parametrize("conflicting_target", ["owned", "missing", "foreign", "wrong_kind"])
async def test_same_event_id_with_different_item_conflicts_before_target_validation(
    api, database_connection, conflicting_target
):
    headers, _, user = await guest(api)
    content = await link(api, headers)
    original_item = await _item(database_connection, user["id"], content_id=content["id"])
    payload = {"client_event_id": str(uuid4()), "recommendation_item_id": original_item}
    original = await _expose(api, headers, payload)
    if conflicting_target == "missing":
        other_item = 2_147_483_647
    elif conflicting_target == "foreign":
        other_headers, _, other_user = await guest(api)
        foreign = await link(api, other_headers)
        other_item = await _item(database_connection, other_user["id"], content_id=foreign["id"])
    elif conflicting_target == "wrong_kind":
        other_item = await _item(
            database_connection,
            user["id"],
            category_id=content["categories"][0]["id"],
            surface="TODAY",
            day=2,
        )
    else:
        other_item = await _item(
            database_connection, user["id"], category_id=content["categories"][0]["id"]
        )
    await _expose(api, headers, {**payload, "recommendation_item_id": other_item}, status=409)
    assert await _expose(api, headers, payload) == original
    assert len(await _exposures(database_connection, user["id"])) == 1
    assert (await _contents(database_connection, user["id"]))[0]["recommendation_count"] == 1


async def test_same_event_uuid_can_be_used_by_different_users(api, database_connection):
    event_id = str(uuid4())
    exposures = []
    for _ in range(2):
        headers, _, user = await guest(api)
        content = await link(api, headers)
        item_id = await _item(database_connection, user["id"], content_id=content["id"])
        exposures.append(await _expose(
            api, headers, {"client_event_id": event_id, "recommendation_item_id": item_id}
        ))
        assert len(await _exposures(database_connection, user["id"])) == 1
        assert (await _contents(database_connection, user["id"]))[0]["recommendation_count"] == 1
    assert exposures[0]["exposure_id"] != exposures[1]["exposure_id"]


async def test_owned_category_can_be_exposed_after_it_becomes_empty(
    api, database_connection, exposure_clock
):
    headers, _, user = await guest(api)
    content = await link(api, headers)
    category_id = content["categories"][0]["id"]
    item_id = await _item(database_connection, user["id"], category_id=category_id)
    await request(api, "DELETE", f"contents/{content['id']}", headers=headers, status=204)
    before = await _events(database_connection, user["id"])
    await _expose(
        api, headers, {"client_event_id": str(uuid4()), "recommendation_item_id": item_id}
    )
    assert len(await _exposures(database_connection, user["id"])) == 1
    assert await _contents(database_connection, user["id"]) == []
    assert await _events(database_connection, user["id"]) == before


@pytest.mark.parametrize("same_item", [True, False])
async def test_database_insert_conflict_rechecks_payload_without_updating_counters(
    api, database_connection, exposure_clock, monkeypatch, same_item
):
    headers, _, user = await guest(api)
    first = await link(api, headers)
    second = await link(api, headers)
    first_item = await _item(database_connection, user["id"], content_id=first["id"])
    second_item = await _item(database_connection, user["id"], content_id=second["id"], day=2)
    payload = {"client_event_id": str(uuid4()), "recommendation_item_id": first_item}
    original_response = await _expose(api, headers, payload)
    before_contents = await _contents(database_connection, user["id"])
    before_exposures = await _exposures(database_connection, user["id"])
    lookup = RecommendationRepository.get_exposure_by_client_event_id
    insert_once = RecommendationRepository.create_exposure_once
    lookup_count = 0
    insert_results = []

    async def miss_first_lookup(self, **kwargs):
        nonlocal lookup_count
        lookup_count += 1
        if lookup_count == 1:
            return None
        return await lookup(self, **kwargs)

    async def actual_conflicting_insert(self, **kwargs):
        result = await insert_once(self, **kwargs)
        insert_results.append(result)
        return result

    exposure_clock.now += timedelta(minutes=5)
    with monkeypatch.context() as patch:
        patch.setattr(
            RecommendationRepository, "get_exposure_by_client_event_id", miss_first_lookup
        )
        patch.setattr(RecommendationRepository, "create_exposure_once", actual_conflicting_insert)
        response = await _expose(
            api,
            headers,
            {**payload, "recommendation_item_id": first_item if same_item else second_item},
            status=201 if same_item else 409,
        )
    assert lookup_count == 2 and insert_results == [None]
    if same_item:
        assert response == original_response
    assert await _contents(database_connection, user["id"]) == before_contents
    assert await _exposures(database_connection, user["id"]) == before_exposures


@pytest.mark.parametrize("failure_point", ["insert", "counter", "commit"])
async def test_exposure_failure_rolls_back_and_same_id_can_retry(
    api, database_connection, exposure_clock, monkeypatch, failure_point
):
    headers, _, user = await guest(api)
    content = await link(api, headers)
    item_id = await _item(database_connection, user["id"], content_id=content["id"])
    payload = {"client_event_id": str(uuid4()), "recommendation_item_id": item_id}
    before = await _contents(database_connection, user["id"])
    old_events = await _events(database_connection, user["id"])
    if failure_point == "insert":
        owner, method = RecommendationRepository, "create_exposure_once"
    elif failure_point == "counter":
        owner, method = ContentRepository, "mark_recommended"
    else:
        owner, method = AsyncSession, "commit"
    original = getattr(owner, method)

    async def fail(self, *args, **kwargs):
        if failure_point != "commit":
            await original(self, *args, **kwargs)
        raise RuntimeError("injected exposure transaction failure")

    with monkeypatch.context() as patch:
        patch.setattr(owner, method, fail)
        response = await api.post(
            "/api/v1/recommendations/exposures", headers=headers, json=payload
        )
        assert response.status_code == 500
    assert await _exposures(database_connection, user["id"]) == []
    assert await _contents(database_connection, user["id"]) == before
    assert await _events(database_connection, user["id"]) == old_events
    await _expose(api, headers, payload)
    assert len(await _exposures(database_connection, user["id"])) == 1
    assert (await _contents(database_connection, user["id"]))[0]["recommendation_count"] == 1
