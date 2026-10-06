from datetime import date, timedelta
from types import SimpleNamespace
from uuid import uuid4

import pytest
import pytest_asyncio
from sqlalchemy import delete, insert, select, update
from sqlalchemy.exc import IntegrityError

from app.models.category import Category
from app.models.content import Content, ContentSource, ContentType
from app.models.content_event import ContentEvent, ContentEventType
from app.models.recommendation import (
    RecommendationBatch,
    RecommendationBatchItem,
    RecommendationCardType,
    RecommendationExposure,
    RecommendationTargetKind,
    RecommendationType,
)
from app.models.user import User
from app.repositories.event_repository import EventRepository

TODAY = date(2026, 9, 24)


@pytest_asyncio.fixture
async def recommendation_data(database_session):
    session = database_session
    user, other = User(display_name="추천 사용자"), User(display_name="다른 사용자")
    session.add_all([user, other])
    await session.flush()
    category = Category(user_id=user.id, name="추천 카테고리")
    contents = [
        Content(
            user_id=owner.id,
            content_type=ContentType.LINK,
            source=ContentSource.WEB,
            title="추천 콘텐츠",
            summary="추천 스키마 검증",
        )
        for owner in (user, other)
    ]
    batches = [
        RecommendationBatch(
            user_id=owner.id,
            type=RecommendationType.TODAY,
            recommendation_date=TODAY,
        )
        for owner in (user, other)
    ]
    weekly = RecommendationBatch(user_id=user.id, type=RecommendationType.WEEKLY_PICK)
    session.add_all([category, *contents, *batches, weekly])
    await session.flush()
    items = [
        RecommendationBatchItem(
            batch_id=batch.id,
            rank=1,
            target_kind=RecommendationTargetKind.CONTENT,
            target_id_snapshot=content.id,
            content_id=content.id,
            score=0.5,
        )
        for batch, content in zip(batches, contents, strict=True)
    ]
    category_item = RecommendationBatchItem(
        batch_id=weekly.id,
        rank=1,
        target_kind=RecommendationTargetKind.CATEGORY,
        target_id_snapshot=category.id,
        category_id=category.id,
        card_type=RecommendationCardType.REDISCOVERY,
    )
    session.add_all([*items, category_item])
    await session.flush()
    return SimpleNamespace(
        user=user,
        other=other,
        content=contents[0],
        other_content=contents[1],
        category=category,
        batch=batches[0],
        weekly=weekly,
        content_item=items[0],
        other_item=items[1],
        category_item=category_item,
    )


@pytest.mark.asyncio
async def test_defaults_and_snapshot_null_are_distinct_from_empty(
    database_session, recommendation_data
) -> None:
    session, data = database_session, recommendation_data
    assert data.content.open_count == data.content.recommendation_count == 0
    assert data.content.last_recommended_at is None
    assert data.content.last_recommended_surface is None
    assert data.batch.generated_at.utcoffset() is not None
    events = [
        ContentEvent(user_id=data.user.id, event_type=ContentEventType.CONTENT_CREATED),
        ContentEvent(
            user_id=data.user.id,
            event_type=ContentEventType.CONTENT_REOPENED,
            category_ids_at_event=[],
        ),
        ContentEvent(
            user_id=data.user.id,
            event_type=ContentEventType.CONTENT_REOPENED,
            category_id=data.category.id,
            category_ids_at_event=[data.category.id, 123456789],
        ),
    ]
    session.add_all(events)
    await session.flush()
    category_id = data.category.id
    await session.execute(delete(Category).where(Category.id == category_id))
    for event in events:
        await session.refresh(event)
        assert event.client_event_id is None and event.recommendation_item_id is None
    assert events[0].category_ids_at_event is None
    assert events[1].category_ids_at_event == []
    assert events[2].category_ids_at_event == [category_id, 123456789]
    assert events[2].category_id is None


@pytest.mark.asyncio
async def test_today_is_unique_per_user_and_date_but_weekly_can_repeat(
    database_session, recommendation_data
) -> None:
    session, data = database_session, recommendation_data
    # The fixture already creates another user's batch for the same date.
    session.add_all(
        [
            RecommendationBatch(
                user_id=data.user.id,
                type=RecommendationType.TODAY,
                recommendation_date=TODAY + timedelta(days=1),
            ),
            RecommendationBatch(user_id=data.user.id, type=RecommendationType.WEEKLY_PICK),
            RecommendationBatch(user_id=data.user.id, type=RecommendationType.WEEKLY_PICK),
        ]
    )
    await session.flush()
    with pytest.raises(IntegrityError):
        async with session.begin_nested():
            await session.execute(
                insert(RecommendationBatch).values(
                    user_id=data.user.id,
                    type=RecommendationType.TODAY,
                    recommendation_date=TODAY,
                )
            )


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "values",
    [
        {"recommendation_date": None},
        {"type": RecommendationType.WEEKLY_PICK},
        {"type": "UNKNOWN"},
    ],
)
async def test_batch_rejects_invalid_type_or_date(
    database_session, recommendation_data, values
) -> None:
    with pytest.raises(IntegrityError):
        async with database_session.begin_nested():
            await database_session.execute(
                update(RecommendationBatch)
                .where(RecommendationBatch.id == recommendation_data.batch.id)
                .values(**values)
            )


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "values",
    [
        {"open_count": -1},
        {"recommendation_count": -1},
        {"open_count": None},
        {"recommendation_count": None},
        {"last_recommended_surface": "UNKNOWN"},
    ],
)
async def test_content_rejects_invalid_counters_or_surface(
    database_session, recommendation_data, values
) -> None:
    with pytest.raises(IntegrityError):
        async with database_session.begin_nested():
            await database_session.execute(
                update(Content)
                .where(Content.id == recommendation_data.content.id)
                .values(**values)
            )


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("item_name", "values"),
    [
        ("content_item", {"rank": 0}),
        ("content_item", {"rank": None}),
        ("content_item", {"target_kind": None}),
        ("content_item", {"target_kind": "UNKNOWN"}),
        ("content_item", {"target_id_snapshot": None}),
        ("content_item", {"target_id_snapshot": -1}),
        ("content_item", {"target_id_snapshot": "different_id"}),
        ("content_item", {"category_id": "category"}),
        ("content_item", {"score": -0.01}),
        ("content_item", {"score": 1.01}),
        ("content_item", {"card_type": RecommendationCardType.MOST_SAVED}),
        ("category_item", {"content_id": "content"}),
        ("category_item", {"target_id_snapshot": "different_id"}),
        ("category_item", {"score": 0.5}),
        ("category_item", {"card_type": None}),
        ("category_item", {"card_type": "UNKNOWN"}),
    ],
)
async def test_item_rejects_invalid_target_rank_score_and_card_type(
    database_session, recommendation_data, item_name, values
) -> None:
    data = recommendation_data
    values = {
        key: getattr(data, value).id if value in ("category", "content") else value
        for key, value in values.items()
    }
    if values.get("target_id_snapshot") == "different_id":
        values["target_id_snapshot"] = getattr(data, item_name).target_id_snapshot + 1
    with pytest.raises(IntegrityError):
        async with database_session.begin_nested():
            await database_session.execute(
                update(RecommendationBatchItem)
                .where(RecommendationBatchItem.id == getattr(data, item_name).id)
                .values(**values)
            )


@pytest.mark.asyncio
async def test_content_score_allows_null_and_both_endpoints(
    database_session, recommendation_data
) -> None:
    for score in (None, 0.0, 1.0):
        await database_session.execute(
            update(RecommendationBatchItem)
            .where(RecommendationBatchItem.id == recommendation_data.content_item.id)
            .values(score=score)
        )


@pytest.mark.asyncio
@pytest.mark.parametrize("duplicate", ["rank", "target"])
async def test_batch_items_reject_duplicate_rank_or_target(
    database_session, recommendation_data, duplicate
) -> None:
    data = recommendation_data
    with pytest.raises(IntegrityError):
        async with database_session.begin_nested():
            await database_session.execute(
                insert(RecommendationBatchItem).values(
                    batch_id=data.batch.id,
                    rank=1 if duplicate == "rank" else 2,
                    target_kind=RecommendationTargetKind.CONTENT,
                    target_id_snapshot=(
                        data.other_content.id if duplicate == "rank" else data.content.id
                    ),
                    content_id=(
                        data.other_content.id if duplicate == "rank" else data.content.id
                    ),
                )
            )


@pytest.mark.asyncio
@pytest.mark.parametrize("model", [ContentEvent, RecommendationExposure])
async def test_client_event_ids_are_unique_per_user(database_session, recommendation_data, model):
    session, data = database_session, recommendation_data
    event_id = uuid4()
    values = {"user_id": data.user.id, "client_event_id": event_id}
    other_values = {"user_id": data.other.id, "client_event_id": event_id}
    if model is ContentEvent:
        values["event_type"] = other_values["event_type"] = ContentEventType.CONTENT_REOPENED
        for _ in range(2):
            session.add(
                ContentEvent(user_id=data.user.id, event_type=ContentEventType.CONTENT_REOPENED)
            )
    else:
        values["recommendation_item_id"] = data.content_item.id
        other_values["recommendation_item_id"] = data.other_item.id
    session.add_all([model(**values), model(**other_values)])
    await session.flush()
    with pytest.raises(IntegrityError):
        async with session.begin_nested():
            await session.execute(insert(model).values(**values))
    values["client_event_id"] = uuid4()
    session.add(model(**values))
    await session.flush()


@pytest.mark.asyncio
@pytest.mark.parametrize("missing", ["client_event_id", "recommendation_item_id"])
async def test_exposure_requires_client_id_and_item(
    database_session, recommendation_data, missing
) -> None:
    values = {
        "user_id": recommendation_data.user.id,
        "client_event_id": uuid4(),
        "recommendation_item_id": recommendation_data.content_item.id,
    }
    values[missing] = None
    with pytest.raises(IntegrityError):
        async with database_session.begin_nested():
            await database_session.execute(insert(RecommendationExposure).values(**values))


@pytest.mark.asyncio
async def test_target_deletion_retains_recommendation_history_and_lifetime_stats(
    database_session, recommendation_data
) -> None:
    session, data = database_session, recommendation_data
    events = [
        ContentEvent(
            user_id=data.user.id,
            content_id=data.content.id,
            category_id=data.category.id,
            category_ids_at_event=[data.category.id],
            event_type=kind,
            recommendation_item_id=data.content_item.id,
            metadata_json='{"source":"recommendation"}',
        )
        for kind in (ContentEventType.CONTENT_CREATED, ContentEventType.CONTENT_REOPENED)
    ]
    exposures = [
        RecommendationExposure(
            user_id=data.user.id,
            client_event_id=uuid4(),
            recommendation_item_id=item.id,
        )
        for item in (data.content_item, data.category_item)
    ]
    session.add_all([*events, *exposures])
    await session.flush()
    original_content_id, original_category_id = data.content.id, data.category.id
    stats = dict(await EventRepository(session).read_user_stats(data.user.id))
    assert stats == {"saved_count": 1, "reopened_count": 1}

    await session.execute(delete(Content).where(Content.id == original_content_id))
    await session.execute(delete(Category).where(Category.id == original_category_id))
    for item, snapshot in (
        (data.content_item, original_content_id),
        (data.category_item, original_category_id),
    ):
        await session.refresh(item)
        assert item.content_id is None and item.category_id is None
        assert item.target_id_snapshot == snapshot
    for event in events:
        await session.refresh(event)
        assert event.content_id is None and event.category_id is None
        assert event.category_ids_at_event == [original_category_id]
        assert event.recommendation_item_id == data.content_item.id
        assert event.metadata_json == '{"source":"recommendation"}'
    for exposure in exposures:
        await session.refresh(exposure)
        assert exposure.recommended_at.utcoffset() is not None
    for batch in (data.batch, data.weekly):
        assert await session.scalar(
            select(RecommendationBatch.id).where(RecommendationBatch.id == batch.id)
        ) == batch.id
    assert dict(await EventRepository(session).read_user_stats(data.user.id)) == stats


@pytest.mark.asyncio
@pytest.mark.parametrize("reference", ["batch_item", "exposure", "content_event"])
async def test_history_references_restrict_deletion(
    database_session, recommendation_data, reference
) -> None:
    session, data = database_session, recommendation_data
    if reference == "batch_item":
        model, target_id = RecommendationBatch, data.batch.id
    else:
        model, target_id = RecommendationBatchItem, data.content_item.id
        if reference == "exposure":
            session.add(
                RecommendationExposure(
                    user_id=data.user.id,
                    client_event_id=uuid4(),
                    recommendation_item_id=target_id,
                )
            )
        else:
            session.add(
                ContentEvent(
                    user_id=data.user.id,
                    event_type=ContentEventType.CONTENT_REOPENED,
                    recommendation_item_id=target_id,
                )
            )
        await session.flush()
    with pytest.raises(IntegrityError):
        async with session.begin_nested():
            await session.execute(delete(model).where(model.id == target_id))
    assert await session.scalar(select(model.id).where(model.id == target_id)) == target_id
