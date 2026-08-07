from datetime import UTC, datetime
from types import SimpleNamespace

import pytest
from fastapi import HTTPException

from app.models.content import ContentType
from app.models.content_event import ContentEventType
from app.schemas.metrics import (
    CardClickedEventCreate,
    CategoryFilterUsedEventCreate,
    MetricEventType,
    OriginalLinkOpenedEventCreate,
)
from app.services.metrics_service import MetricsService


class FakeSession:
    def __init__(self) -> None:
        self.commit_count = 0
        self.rollback_count = 0

    async def commit(self) -> None:
        self.commit_count += 1

    async def rollback(self) -> None:
        self.rollback_count += 1


class FakeEventRepository:
    def __init__(self, *, fail: bool = False) -> None:
        self.session = FakeSession()
        self.events: list[SimpleNamespace] = []
        self.fail = fail

    async def create(
        self,
        *,
        user_id: int,
        event_type: ContentEventType,
        content_id: int | None = None,
        category_id: int | None = None,
        metadata_json: str | None = None,
    ) -> SimpleNamespace:
        if self.fail:
            raise RuntimeError("database unavailable")
        event = SimpleNamespace(
            id=len(self.events) + 1,
            user_id=user_id,
            event_type=event_type,
            content_id=content_id,
            category_id=category_id,
            metadata_json=metadata_json,
            created_at=datetime.now(UTC),
        )
        self.events.append(event)
        return event


class FakeContentRepository:
    def __init__(self, contents: list[SimpleNamespace] | None = None) -> None:
        self.contents = {content.id: content for content in contents or []}

    async def get_owned(self, *, user_id: int, content_id: int) -> SimpleNamespace | None:
        content = self.contents.get(content_id)
        if content is None or content.user_id != user_id:
            return None
        return content


class FakeCategoryRepository:
    def __init__(self, categories: list[SimpleNamespace] | None = None) -> None:
        self.categories = {category.id: category for category in categories or []}

    async def list_available_by_ids(
        self,
        user_id: int,
        category_ids: list[int],
    ) -> list[SimpleNamespace]:
        return [
            category
            for category_id in category_ids
            if (category := self.categories.get(category_id)) is not None
            and (category.user_id is None or category.user_id == user_id)
        ]


def category(category_id: int, *, user_id: int | None = None) -> SimpleNamespace:
    return SimpleNamespace(id=category_id, user_id=user_id)


def content(
    content_id: int,
    *,
    user_id: int = 1,
    content_type: ContentType = ContentType.LINK,
    original_url: str | None = "https://example.com/post",
    categories: list[SimpleNamespace] | None = None,
) -> SimpleNamespace:
    return SimpleNamespace(
        id=content_id,
        user_id=user_id,
        content_type=content_type,
        original_url=original_url,
        categories=categories or [],
    )


def build_service(
    *,
    contents: list[SimpleNamespace] | None = None,
    categories: list[SimpleNamespace] | None = None,
    fail_event_create: bool = False,
) -> tuple[MetricsService, FakeEventRepository]:
    event_repository = FakeEventRepository(fail=fail_event_create)
    return (
        MetricsService(
            event_repository=event_repository,
            content_repository=FakeContentRepository(contents),
            category_repository=FakeCategoryRepository(categories),
        ),
        event_repository,
    )


@pytest.mark.asyncio
@pytest.mark.parametrize("event_category", [category(1), category(2, user_id=7)])
async def test_record_category_filter_for_available_category(event_category) -> None:
    service, event_repository = build_service(categories=[event_category])

    result = await service.record_event(
        user_id=7,
        payload=CategoryFilterUsedEventCreate(
            event_type=MetricEventType.CATEGORY_FILTER_USED,
            category_id=event_category.id,
        ),
    )

    event = event_repository.events[0]
    assert result.id == event.id
    assert event.user_id == 7
    assert event.event_type == ContentEventType.CATEGORY_FILTER_USED
    assert event.content_id is None
    assert event.category_id == event_category.id
    assert event.metadata_json is None
    assert event_repository.session.commit_count == 1


@pytest.mark.asyncio
async def test_record_category_filter_hides_unavailable_category() -> None:
    service, event_repository = build_service(categories=[category(1, user_id=9)])

    with pytest.raises(HTTPException) as exc_info:
        await service.record_event(
            user_id=7,
            payload=CategoryFilterUsedEventCreate(
                event_type=MetricEventType.CATEGORY_FILTER_USED,
                category_id=1,
            ),
        )

    assert exc_info.value.status_code == 404
    assert event_repository.events == []
    assert event_repository.session.rollback_count == 1


@pytest.mark.asyncio
async def test_record_card_click_preserves_every_duplicate_action() -> None:
    saved_content = content(5, user_id=7)
    service, event_repository = build_service(contents=[saved_content])
    payload = CardClickedEventCreate(
        event_type=MetricEventType.CARD_CLICKED,
        content_id=5,
    )

    first = await service.record_event(user_id=7, payload=payload)
    second = await service.record_event(user_id=7, payload=payload)

    assert [first.id, second.id] == [1, 2]
    assert len(event_repository.events) == 2
    assert all(event.content_id == 5 for event in event_repository.events)
    assert all(event.category_id is None for event in event_repository.events)
    assert event_repository.session.commit_count == 2


@pytest.mark.asyncio
async def test_record_card_click_accepts_assigned_category_context() -> None:
    assigned_category = category(3, user_id=7)
    service, event_repository = build_service(
        contents=[content(5, user_id=7, categories=[assigned_category])],
        categories=[assigned_category],
    )

    await service.record_event(
        user_id=7,
        payload=CardClickedEventCreate(
            event_type=MetricEventType.CARD_CLICKED,
            content_id=5,
            category_id=3,
        ),
    )

    assert event_repository.events[0].category_id == 3


@pytest.mark.asyncio
async def test_record_card_click_rejects_unassigned_category_context() -> None:
    assigned_category = category(3, user_id=7)
    other_category = category(4, user_id=7)
    service, event_repository = build_service(
        contents=[content(5, user_id=7, categories=[assigned_category])],
        categories=[assigned_category, other_category],
    )

    with pytest.raises(HTTPException) as exc_info:
        await service.record_event(
            user_id=7,
            payload=CardClickedEventCreate(
                event_type=MetricEventType.CARD_CLICKED,
                content_id=5,
                category_id=4,
            ),
        )

    assert exc_info.value.status_code == 422
    assert event_repository.events == []


@pytest.mark.asyncio
async def test_record_card_click_hides_unavailable_category_context() -> None:
    assigned_category = category(3, user_id=7)
    unavailable_category = category(4, user_id=9)
    service, event_repository = build_service(
        contents=[content(5, user_id=7, categories=[assigned_category])],
        categories=[assigned_category, unavailable_category],
    )

    with pytest.raises(HTTPException) as exc_info:
        await service.record_event(
            user_id=7,
            payload=CardClickedEventCreate(
                event_type=MetricEventType.CARD_CLICKED,
                content_id=5,
                category_id=4,
            ),
        )

    assert exc_info.value.status_code == 404
    assert event_repository.events == []


@pytest.mark.asyncio
async def test_record_card_click_hides_unowned_content() -> None:
    service, event_repository = build_service(contents=[content(5, user_id=9)])

    with pytest.raises(HTTPException) as exc_info:
        await service.record_event(
            user_id=7,
            payload=CardClickedEventCreate(
                event_type=MetricEventType.CARD_CLICKED,
                content_id=5,
            ),
        )

    assert exc_info.value.status_code == 404
    assert event_repository.events == []


@pytest.mark.asyncio
async def test_record_original_link_opened_for_link_content() -> None:
    service, event_repository = build_service(contents=[content(5, user_id=7)])

    result = await service.record_event(
        user_id=7,
        payload=OriginalLinkOpenedEventCreate(
            event_type=MetricEventType.ORIGINAL_LINK_OPENED,
            content_id=5,
        ),
    )

    assert result.event_type == MetricEventType.ORIGINAL_LINK_OPENED
    assert event_repository.events[0].event_type == ContentEventType.ORIGINAL_LINK_OPENED
    assert event_repository.events[0].content_id == 5


@pytest.mark.asyncio
async def test_record_original_link_opened_hides_unowned_content() -> None:
    service, event_repository = build_service(contents=[content(5, user_id=9)])

    with pytest.raises(HTTPException) as exc_info:
        await service.record_event(
            user_id=7,
            payload=OriginalLinkOpenedEventCreate(
                event_type=MetricEventType.ORIGINAL_LINK_OPENED,
                content_id=5,
            ),
        )

    assert exc_info.value.status_code == 404
    assert event_repository.events == []


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "invalid_content",
    [
        content(5, user_id=7, content_type=ContentType.SCREENSHOT, original_url=None),
        content(6, user_id=7, original_url=None),
    ],
)
async def test_record_original_link_opened_rejects_content_without_link(invalid_content) -> None:
    service, event_repository = build_service(contents=[invalid_content])

    with pytest.raises(HTTPException) as exc_info:
        await service.record_event(
            user_id=7,
            payload=OriginalLinkOpenedEventCreate(
                event_type=MetricEventType.ORIGINAL_LINK_OPENED,
                content_id=invalid_content.id,
            ),
        )

    assert exc_info.value.status_code == 422
    assert event_repository.events == []


@pytest.mark.asyncio
async def test_record_event_rolls_back_database_failure() -> None:
    service, event_repository = build_service(
        contents=[content(5, user_id=7)],
        fail_event_create=True,
    )

    with pytest.raises(RuntimeError, match="database unavailable"):
        await service.record_event(
            user_id=7,
            payload=CardClickedEventCreate(
                event_type=MetricEventType.CARD_CLICKED,
                content_id=5,
            ),
        )

    assert event_repository.session.commit_count == 0
    assert event_repository.session.rollback_count == 1
