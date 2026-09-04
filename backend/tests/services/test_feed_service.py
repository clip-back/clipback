from datetime import UTC, datetime, timedelta
from types import SimpleNamespace

import pytest
from fastapi import HTTPException

from app.schemas.content import ContentSource, ContentType
from app.services.feed_service import FeedService


class FakeContentRepository:
    def __init__(self, contents: list[SimpleNamespace]) -> None:
        self.contents = contents
        self.calls: list[dict[str, int | None]] = []

    async def list_feed(
        self,
        *,
        user_id: int,
        category_id: int | None,
        cursor_id: int | None,
        limit: int,
        is_favorite: bool | None = None,
    ) -> list[SimpleNamespace]:
        self.calls.append(
            {
                "user_id": user_id,
                "category_id": category_id,
                "is_favorite": is_favorite,
                "cursor_id": cursor_id,
                "limit": limit,
            }
        )

        contents = [content for content in self.contents if content.user_id == user_id]
        if category_id is not None:
            contents = [
                content
                for content in contents
                if any(category.id == category_id for category in content.categories)
            ]
        if is_favorite is not None:
            contents = [
                content for content in contents if content.is_favorite == is_favorite
            ]
        if cursor_id is not None:
            contents = [content for content in contents if content.id < cursor_id]

        return sorted(contents, key=lambda content: (content.saved_at, content.id), reverse=True)[
            :limit
        ]


def category(category_id: int, name: str) -> SimpleNamespace:
    return SimpleNamespace(id=category_id, name=name, color=None, is_default=True)


def content(
    content_id: int,
    *,
    saved_at: datetime,
    categories: list[SimpleNamespace],
    user_id: int = 1,
    is_favorite: bool = False,
) -> SimpleNamespace:
    return SimpleNamespace(
        id=content_id,
        user_id=user_id,
        content_type=ContentType.LINK,
        source=ContentSource.WEB,
        title=f"콘텐츠 {content_id}",
        summary="요약",
        original_url="https://example.com/original",
        is_favorite=is_favorite,
        categories=categories,
        tags=[],
        assets=[],
        saved_at=saved_at,
        last_viewed_at=None,
    )


@pytest.mark.asyncio
async def test_read_feed_returns_latest_contents_with_category_filter_and_cursor() -> None:
    now = datetime.now(UTC)
    work = category(1, "업무 팁")
    study = category(2, "공부")
    repository = FakeContentRepository(
        [
            content(1, saved_at=now - timedelta(minutes=3), categories=[work]),
            content(2, saved_at=now - timedelta(minutes=2), categories=[study]),
            content(3, saved_at=now - timedelta(minutes=1), categories=[work]),
            content(4, saved_at=now, categories=[work]),
            content(5, saved_at=now + timedelta(minutes=1), categories=[work], user_id=2),
        ]
    )
    service = FeedService(content_repository=repository)

    first_page = await service.read_feed(user_id=1, category_id=1, limit=1, cursor=None)
    second_page = await service.read_feed(
        user_id=1,
        category_id=1,
        limit=2,
        cursor=first_page.next_cursor,
    )

    assert [item.id for item in first_page.items] == [4]
    assert first_page.next_cursor == "4"
    assert [item.id for item in second_page.items] == [3, 1]
    assert second_page.next_cursor is None
    assert repository.calls[0] == {
        "user_id": 1,
        "category_id": 1,
        "is_favorite": None,
        "cursor_id": None,
        "limit": 2,
    }
    assert repository.calls[1]["cursor_id"] == 4


@pytest.mark.asyncio
async def test_read_feed_filters_favorites_with_category_and_cursor() -> None:
    now = datetime.now(UTC)
    work = category(1, "업무 팁")
    study = category(2, "공부")
    repository = FakeContentRepository(
        [
            content(
                1,
                saved_at=now - timedelta(minutes=3),
                categories=[work],
                is_favorite=True,
            ),
            content(
                2,
                saved_at=now - timedelta(minutes=2),
                categories=[work],
                is_favorite=False,
            ),
            content(
                3,
                saved_at=now - timedelta(minutes=1),
                categories=[work],
                is_favorite=True,
            ),
            content(
                4,
                saved_at=now,
                categories=[study],
                is_favorite=True,
            ),
            content(
                5,
                saved_at=now + timedelta(minutes=1),
                categories=[work],
                user_id=2,
                is_favorite=True,
            ),
        ]
    )
    service = FeedService(content_repository=repository)

    first_page = await service.read_feed(
        user_id=1,
        category_id=1,
        is_favorite=True,
        limit=1,
        cursor=None,
    )
    second_page = await service.read_feed(
        user_id=1,
        category_id=1,
        is_favorite=True,
        limit=1,
        cursor=first_page.next_cursor,
    )

    assert [item.id for item in first_page.items] == [3]
    assert first_page.next_cursor == "3"
    assert [item.id for item in second_page.items] == [1]
    assert second_page.next_cursor is None
    assert repository.calls[0] == {
        "user_id": 1,
        "category_id": 1,
        "is_favorite": True,
        "cursor_id": None,
        "limit": 2,
    }
    assert repository.calls[1]["cursor_id"] == 3


@pytest.mark.asyncio
async def test_read_feed_filters_non_favorites() -> None:
    now = datetime.now(UTC)
    work = category(1, "업무 팁")
    repository = FakeContentRepository(
        [
            content(1, saved_at=now, categories=[work], is_favorite=True),
            content(2, saved_at=now, categories=[work], is_favorite=False),
        ]
    )
    service = FeedService(content_repository=repository)

    result = await service.read_feed(
        user_id=1,
        category_id=None,
        is_favorite=False,
        limit=20,
        cursor=None,
    )

    assert [item.id for item in result.items] == [2]
    assert result.next_cursor is None


@pytest.mark.asyncio
async def test_read_feed_rejects_invalid_cursor() -> None:
    service = FeedService(content_repository=FakeContentRepository([]))

    with pytest.raises(HTTPException) as exc_info:
        await service.read_feed(user_id=1, category_id=None, limit=20, cursor="bad")

    assert exc_info.value.status_code == 422
