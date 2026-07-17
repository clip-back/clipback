from datetime import UTC, datetime
from types import SimpleNamespace

from fastapi import HTTPException
import pytest

from app.core.exceptions import NotFoundError
from app.models.content_event import ContentEventType
from app.schemas.content import ContentCreate, ContentSource, ContentType
from app.services.content_service import ContentService


class FakeSession:
    def __init__(self) -> None:
        self.committed = False
        self.rolled_back = False

    async def commit(self) -> None:
        self.committed = True

    async def rollback(self) -> None:
        self.rolled_back = True


class FakeContentRepository:
    def __init__(self, contents: list[SimpleNamespace] | None = None) -> None:
        self.session = FakeSession()
        self.contents = {content.id: content for content in contents or []}
        self.created_categories: list[SimpleNamespace] = []

    async def create(
        self,
        *,
        user_id: int,
        content_type,
        source,
        title: str,
        summary: str,
        original_url: str | None,
        is_favorite: bool,
        categories: list[SimpleNamespace],
    ) -> SimpleNamespace:
        content = SimpleNamespace(
            id=max(self.contents, default=0) + 1,
            user_id=user_id,
            content_type=content_type,
            source=source,
            title=title,
            summary=summary,
            original_url=original_url,
            is_favorite=is_favorite,
            categories=categories,
            saved_at=datetime.now(UTC),
            last_viewed_at=None,
        )
        self.contents[content.id] = content
        self.created_categories = categories
        return content

    async def get_owned(self, *, user_id: int, content_id: int) -> SimpleNamespace | None:
        content = self.contents.get(content_id)
        if content is None or content.user_id != user_id:
            return None
        return content

    async def mark_viewed(self, content: SimpleNamespace) -> SimpleNamespace:
        content.last_viewed_at = datetime.now(UTC)
        return content


class FakeCategoryRepository:
    def __init__(
        self,
        categories: list[SimpleNamespace],
        uncategorized: SimpleNamespace | None = None,
    ) -> None:
        self.categories = {category.id: category for category in categories}
        self.uncategorized = uncategorized

    async def list_available_by_ids(
        self,
        user_id: int,
        category_ids: list[int],
    ) -> list[SimpleNamespace]:
        return [
            self.categories[category_id]
            for category_id in category_ids
            if category_id in self.categories
        ]

    async def get_uncategorized(self) -> SimpleNamespace | None:
        return self.uncategorized


class FakeEventRepository:
    def __init__(self) -> None:
        self.events: list[SimpleNamespace] = []

    async def create(
        self,
        *,
        user_id: int,
        event_type: ContentEventType,
        content_id: int | None = None,
        metadata_json: str | None = None,
    ) -> SimpleNamespace:
        event = SimpleNamespace(
            user_id=user_id,
            event_type=event_type,
            content_id=content_id,
            metadata_json=metadata_json,
        )
        self.events.append(event)
        return event


def build_service(
    *,
    categories: list[SimpleNamespace] | None = None,
    uncategorized: SimpleNamespace | None = None,
    contents: list[SimpleNamespace] | None = None,
) -> tuple[ContentService, FakeContentRepository, FakeEventRepository]:
    content_repository = FakeContentRepository(contents)
    event_repository = FakeEventRepository()
    service = ContentService(
        content_repository=content_repository,
        category_repository=FakeCategoryRepository(categories or [], uncategorized),
        event_repository=event_repository,
    )
    return service, content_repository, event_repository


def category(
    category_id: int,
    name: str,
    *,
    is_default: bool = False,
) -> SimpleNamespace:
    return SimpleNamespace(id=category_id, name=name, color=None, is_default=is_default)


def content(content_id: int, *, user_id: int = 1) -> SimpleNamespace:
    return SimpleNamespace(
        id=content_id,
        user_id=user_id,
        content_type=ContentType.LINK,
        source=ContentSource.WEB,
        title="저장한 콘텐츠",
        summary="요약",
        original_url="https://example.com/original",
        is_favorite=False,
        categories=[category(1, "취업", is_default=True)],
        saved_at=datetime.now(UTC),
        last_viewed_at=None,
    )


@pytest.mark.asyncio
async def test_create_content_links_available_categories_and_records_event() -> None:
    service, content_repository, event_repository = build_service(
        categories=[category(1, "취업", is_default=True), category(2, "여행")]
    )

    result = await service.create_content(
        user_id=1,
        payload=ContentCreate(
            original_url="https://example.com/post",
            category_ids=[2, 1, 2],
            title="  링크 제목  ",
            summary="  링크 요약  ",
        ),
    )

    assert result.id == 1
    assert result.title == "링크 제목"
    assert result.summary == "링크 요약"
    assert [category.id for category in content_repository.created_categories] == [2, 1]
    assert [category.id for category in result.categories] == [1, 2]
    assert event_repository.events[0].event_type == ContentEventType.CONTENT_CREATED
    assert content_repository.session.committed is True


@pytest.mark.asyncio
async def test_create_content_uses_uncategorized_when_category_ids_are_empty() -> None:
    uncategorized = category(9, "미분류", is_default=True)
    service, content_repository, _ = build_service(uncategorized=uncategorized)

    result = await service.create_content(
        user_id=1,
        payload=ContentCreate(original_url="https://example.com/post", category_ids=[]),
    )

    assert [category.name for category in result.categories] == ["미분류"]
    assert content_repository.contents[1].title == "저장한 콘텐츠"
    assert content_repository.contents[1].summary == "요약 정보가 아직 없습니다."


@pytest.mark.asyncio
async def test_create_content_records_event_metadata_json() -> None:
    service, _, event_repository = build_service(
        categories=[category(1, "취업", is_default=True)]
    )

    await service.create_content(
        user_id=1,
        payload=ContentCreate(
            original_url="https://example.com/post",
            category_ids=[1],
        ),
        event_metadata_json='{"url_source":"url"}',
    )

    assert event_repository.events[0].metadata_json == '{"url_source":"url"}'


@pytest.mark.asyncio
async def test_create_content_rejects_inaccessible_categories() -> None:
    service, content_repository, _ = build_service(
        categories=[category(1, "취업", is_default=True)]
    )

    with pytest.raises(NotFoundError):
        await service.create_content(
            user_id=1,
            payload=ContentCreate(
                original_url="https://example.com/post",
                category_ids=[1, 99],
            ),
        )

    assert content_repository.contents == {}


@pytest.mark.asyncio
async def test_create_link_content_requires_original_url() -> None:
    service, _, _ = build_service(uncategorized=category(9, "미분류", is_default=True))

    with pytest.raises(HTTPException) as exc_info:
        await service.create_content(
            user_id=1,
            payload=ContentCreate(content_type=ContentType.LINK, category_ids=[]),
        )

    assert exc_info.value.status_code == 422


@pytest.mark.asyncio
async def test_read_content_rejects_other_user_content() -> None:
    service, _, _ = build_service(contents=[content(1, user_id=2)])

    with pytest.raises(NotFoundError):
        await service.read_content(user_id=1, content_id=1)


@pytest.mark.asyncio
async def test_record_view_updates_content_and_records_event() -> None:
    service, content_repository, event_repository = build_service(contents=[content(1)])

    result = await service.record_view(user_id=1, content_id=1)

    assert result.content_id == 1
    assert result.event_type == ContentEventType.CONTENT_REOPENED.value
    assert content_repository.contents[1].last_viewed_at is not None
    assert event_repository.events[0].event_type == ContentEventType.CONTENT_REOPENED
    assert content_repository.session.committed is True


@pytest.mark.asyncio
async def test_record_view_rejects_other_user_content() -> None:
    service, _, _ = build_service(contents=[content(1, user_id=2)])

    with pytest.raises(NotFoundError):
        await service.record_view(user_id=1, content_id=1)
