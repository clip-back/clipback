import base64
import json
from datetime import UTC, datetime, timedelta, timezone
from types import SimpleNamespace

import pytest
from fastapi import HTTPException

from app.schemas.content import ContentSource, ContentType
from app.schemas.feed import FeedCursor
from app.services.feed_service import FeedService


class FakeContentRepository:
    def __init__(self, contents: list[SimpleNamespace]) -> None:
        self.contents = contents
        self.calls: list[dict[str, object]] = []
        self.cursor_lookups: list[tuple[int, int]] = []

    async def get_feed_cursor(self, *, user_id: int, content_id: int) -> FeedCursor | None:
        self.cursor_lookups.append((user_id, content_id))
        for item in self.contents:
            if item.user_id == user_id and item.id == content_id:
                return FeedCursor(saved_at=item.saved_at, id=item.id)
        return None

    async def list_feed(
        self,
        *,
        user_id: int,
        category_id: int | None,
        cursor: FeedCursor | None,
        limit: int,
        is_favorite: bool | None = None,
        search_query: str | None = None,
    ) -> list[SimpleNamespace]:
        self.calls.append(
            {
                "user_id": user_id,
                "category_id": category_id,
                "is_favorite": is_favorite,
                "search_query": search_query,
                "cursor": cursor,
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
        if search_query is not None:
            folded_query = search_query.casefold()
            contents = [
                content
                for content in contents
                if folded_query in content.title.casefold()
                or folded_query in content.summary.casefold()
                or any(folded_query in tag.normalized_name for tag in content.tags)
            ]
        if cursor is not None:
            contents = [
                content
                for content in contents
                if (content.saved_at, content.id) < (cursor.saved_at, cursor.id)
            ]

        return sorted(contents, key=lambda content: (content.saved_at, content.id), reverse=True)[
            :limit
        ]


def category(category_id: int, name: str) -> SimpleNamespace:
    return SimpleNamespace(id=category_id, name=name, color=None, is_default=True)


def tag(tag_id: int, name: str) -> SimpleNamespace:
    return SimpleNamespace(id=tag_id, name=name, normalized_name=name.casefold())


def content(
    content_id: int,
    *,
    saved_at: datetime,
    categories: list[SimpleNamespace],
    user_id: int = 1,
    is_favorite: bool = False,
    title: str | None = None,
    summary: str = "요약",
    tags: list[SimpleNamespace] | None = None,
) -> SimpleNamespace:
    return SimpleNamespace(
        id=content_id,
        user_id=user_id,
        content_type=ContentType.LINK,
        source=ContentSource.WEB,
        title=title or f"콘텐츠 {content_id}",
        summary=summary,
        original_url="https://example.com/original",
        is_favorite=is_favorite,
        categories=categories,
        tags=tags or [],
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
    assert first_page.next_cursor.startswith("v1.")
    assert [item.id for item in second_page.items] == [3, 1]
    assert second_page.next_cursor is None
    assert repository.calls[0] == {
        "user_id": 1,
        "category_id": 1,
        "is_favorite": None,
        "search_query": None,
        "cursor": None,
        "limit": 2,
    }
    assert repository.calls[1]["cursor"] == FeedCursor(saved_at=now, id=4)
    assert repository.cursor_lookups == []


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
        query="콘텐츠",
        limit=1,
        cursor=None,
    )
    second_page = await service.read_feed(
        user_id=1,
        category_id=1,
        is_favorite=True,
        query="콘텐츠",
        limit=1,
        cursor=first_page.next_cursor,
    )

    assert [item.id for item in first_page.items] == [3]
    assert first_page.next_cursor.startswith("v1.")
    assert [item.id for item in second_page.items] == [1]
    assert second_page.next_cursor is None
    assert repository.calls[0] == {
        "user_id": 1,
        "category_id": 1,
        "is_favorite": True,
        "search_query": "콘텐츠",
        "cursor": None,
        "limit": 2,
    }
    assert repository.calls[1]["cursor"] == FeedCursor(saved_at=now - timedelta(minutes=1), id=3)


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
@pytest.mark.parametrize(
    ("query", "expected_id"),
    [
        ("backend", 1),
        ("FLUTTER", 2),
        ("ＰＹＴＨＯＮ", 3),
    ],
)
async def test_read_feed_searches_title_summary_and_tags(
    query: str,
    expected_id: int,
) -> None:
    now = datetime.now(UTC)
    work = category(1, "업무 팁")
    repository = FakeContentRepository(
        [
            content(
                1,
                saved_at=now,
                categories=[work],
                title="FastAPI Backend Guide",
            ),
            content(
                2,
                saved_at=now,
                categories=[work],
                summary="Flutter 상태 관리",
            ),
            content(
                3,
                saved_at=now,
                categories=[work],
                tags=[tag(1, "Python")],
            ),
            content(
                4,
                saved_at=now,
                categories=[work],
                user_id=2,
                title=f"다른 사용자 {query}",
            ),
        ]
    )
    service = FeedService(content_repository=repository)

    result = await service.read_feed(
        user_id=1,
        category_id=None,
        query=query,
        limit=20,
        cursor=None,
    )

    assert [item.id for item in result.items] == [expected_id]


@pytest.mark.asyncio
async def test_read_feed_treats_blank_search_query_as_unfiltered() -> None:
    now = datetime.now(UTC)
    work = category(1, "업무 팁")
    repository = FakeContentRepository([content(1, saved_at=now, categories=[work])])
    service = FeedService(content_repository=repository)

    result = await service.read_feed(
        user_id=1,
        category_id=None,
        query="   ",
        limit=20,
        cursor=None,
    )

    assert [item.id for item in result.items] == [1]
    assert repository.calls[0]["search_query"] is None


@pytest.mark.asyncio
async def test_read_feed_rejects_invalid_cursor() -> None:
    service = FeedService(content_repository=FakeContentRepository([]))

    with pytest.raises(HTTPException) as exc_info:
        await service.read_feed(user_id=1, category_id=None, limit=20, cursor="bad")

    assert exc_info.value.status_code == 422


def cursor_payload(payload: object) -> str:
    return "v1." + base64.urlsafe_b64encode(json.dumps(payload).encode()).decode().rstrip("=")


@pytest.mark.asyncio
async def test_cursor_round_trip_preserves_microseconds_and_normalizes_timezone():
    repository = FakeContentRepository([])
    service = FeedService(repository)
    local = datetime(2026, 9, 22, 15, 10, 20, 123456, tzinfo=timezone(timedelta(hours=9)))
    expected = FeedCursor(saved_at=local.astimezone(UTC), id=2_147_483_647)
    encoded = service._encode_cursor(FeedCursor(saved_at=local, id=expected.id))
    assert encoded.startswith("v1.") and len(encoded) <= 512
    raw = encoded[3:] + "=" * (-len(encoded[3:]) % 4)
    assert json.loads(base64.urlsafe_b64decode(raw)) == {
        "saved_at": "2026-09-22T06:10:20.123456+00:00",
        "id": expected.id,
    }
    for token in [encoded, cursor_payload({"saved_at": local.isoformat(), "id": expected.id})]:
        assert await service._parse_cursor(token, user_id=1) == expected
    assert repository.cursor_lookups == []


@pytest.mark.asyncio
async def test_legacy_cursor_uses_saved_time_and_emits_versioned_cursor():
    now = datetime.now(UTC)
    repository = FakeContentRepository(
        [
            content(4, saved_at=now, categories=[]),
            content(5, saved_at=now - timedelta(seconds=1), categories=[]),
            content(6, saved_at=now - timedelta(seconds=2), categories=[]),
        ]
    )
    page = await FeedService(repository).read_feed(
        user_id=1, category_id=None, limit=1, cursor="4"
    )
    assert [item.id for item in page.items] == [5]
    assert page.next_cursor.startswith("v1.")
    assert repository.cursor_lookups == [(1, 4)]
    assert repository.calls[0]["cursor"] == FeedCursor(saved_at=now, id=4)


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "cursor",
    [
        "", "0", "-1", "1.5", "2147483648", "9" * 513,
        "v2.e30", "v1.", "v1.a", "v1.%", "v1._w", "v1.bm90LWpzb24",
        cursor_payload(None), cursor_payload([]), cursor_payload({}),
        cursor_payload({"saved_at": "2026-09-22T00:00:00Z"}),
        cursor_payload({"saved_at": "2026-09-22T00:00:00Z", "id": 1, "extra": 1}),
    ]
    + [
        cursor_payload({"saved_at": "2026-09-22T00:00:00Z", "id": value})
        for value in [None, True, "1", 1.5, 0, -1, 2_147_483_648]
    ]
    + [
        cursor_payload({"saved_at": value, "id": 1})
        for value in [
            None, 1, True, [], "bad", "2026-09-22", "2026-09-22T00:00:00",
            "0001-01-01T00:00:00+14:00",
        ]
    ],
)
async def test_invalid_cursor_is_422_without_repository_queries(cursor):
    repository = FakeContentRepository([])
    with pytest.raises(HTTPException) as exc_info:
        await FeedService(repository).read_feed(
            user_id=1, category_id=None, limit=20, cursor=cursor
        )
    assert exc_info.value.status_code == 422
    assert repository.calls == []
    assert repository.cursor_lookups == []
