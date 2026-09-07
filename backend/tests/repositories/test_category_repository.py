from datetime import UTC, datetime, timedelta
from types import SimpleNamespace

import pytest
import pytest_asyncio
from sqlalchemy import delete, event, insert, select

from app.models.category import Category
from app.models.content import Content, ContentSource, ContentType
from app.models.content_category import content_categories
from app.models.user import User
from app.repositories.category_repository import CategoryRepository

SAVED_AT = datetime(2026, 9, 7, 3, tzinfo=UTC)


@pytest_asyncio.fixture
async def category_data(database_session):
    session = database_session
    user = User(display_name="Category test user")
    other_user = User(display_name="Other category test user")
    session.add_all([user, other_user])
    await session.flush()
    default = await session.scalar(
        select(Category)
        .where(
            Category.user_id.is_(None),
            Category.is_default.is_(True),
            Category.name != "미분류",
        )
        .order_by(Category.id)
        .limit(1)
    )
    repository = CategoryRepository(session)
    uncategorized = await repository.get_uncategorized()
    assert default is not None and uncategorized is not None, "Run alembic upgrade head first"
    personal = Category(user_id=user.id, name="개인", color="#0891B2")
    empty = Category(user_id=user.id, name="빈 카테고리")
    other = Category(user_id=other_user.id, name="다른 사용자")
    session.add_all([personal, empty, other])
    await session.flush()
    return SimpleNamespace(
        user=user,
        other_user=other_user,
        default=default,
        uncategorized=uncategorized,
        personal=personal,
        empty=empty,
        other=other,
        repository=repository,
    )


async def save_content(
    session,
    *,
    user_id,
    categories,
    saved_at=SAVED_AT,
    content_type=ContentType.LINK,
    is_favorite=False,
) -> Content:
    content = Content(
        user_id=user_id,
        title="집계 테스트",
        summary="테스트 콘텐츠",
        content_type=content_type,
        source=ContentSource.WEB if content_type == ContentType.LINK else ContentSource.SCREENSHOT,
        original_url="https://example.com" if content_type == ContentType.LINK else None,
        saved_at=saved_at,
        is_favorite=is_favorite,
    )
    session.add(content)
    await session.flush()
    await session.execute(
        insert(content_categories),
        [{"content_id": content.id, "category_id": category.id} for category in categories],
    )
    return content


@pytest.mark.asyncio
async def test_summaries_isolate_users_and_count_each_category_once(
    database_session,
    category_data,
) -> None:
    data = category_data
    await save_content(
        database_session,
        user_id=data.user.id,
        categories=[data.default, data.personal],
    )
    await save_content(
        database_session,
        user_id=data.user.id,
        categories=[data.personal],
        saved_at=SAVED_AT + timedelta(days=1),
        content_type=ContentType.SCREENSHOT,
        is_favorite=True,
    )
    await save_content(
        database_session,
        user_id=data.user.id,
        categories=[data.uncategorized],
    )
    await save_content(
        database_session,
        user_id=data.other_user.id,
        categories=[data.default, data.other],
        saved_at=SAVED_AT + timedelta(days=2),
    )

    rows = await data.repository.list_summaries(data.user.id)
    summaries = {row["id"]: row for row in rows}

    assert data.other.id not in summaries
    assert summaries[data.default.id]["content_count"] == 1
    assert summaries[data.default.id]["last_saved_at"] == SAVED_AT
    assert summaries[data.personal.id]["content_count"] == 2
    assert summaries[data.personal.id]["last_saved_at"] == SAVED_AT + timedelta(days=1)
    assert summaries[data.uncategorized.id]["content_count"] == 1
    assert summaries[data.empty.id]["content_count"] == 0
    assert summaries[data.empty.id]["last_saved_at"] is None
    assert [(row["is_default"], row["id"]) for row in rows] == sorted(
        [(row["is_default"], row["id"]) for row in rows],
        key=lambda item: (not item[0], item[1]),
    )
    other_rows = {
        row["id"]: row for row in await data.repository.list_summaries(data.other_user.id)
    }
    assert other_rows[data.default.id]["content_count"] == 1
    assert other_rows[data.default.id]["last_saved_at"] == SAVED_AT + timedelta(days=2)
    assert data.personal.id not in other_rows


@pytest.mark.asyncio
async def test_recent_excludes_uncategorized_and_empty_and_limits_after_sorting(
    database_session,
    category_data,
) -> None:
    data = category_data
    for category, offset in [(data.default, 0), (data.personal, 1), (data.uncategorized, 2)]:
        await save_content(
            database_session,
            user_id=data.user.id,
            categories=[category],
            saved_at=SAVED_AT + timedelta(days=offset),
        )
    await save_content(
        database_session,
        user_id=data.other_user.id,
        categories=[data.other, data.empty],
        saved_at=SAVED_AT + timedelta(days=3),
    )

    rows = await data.repository.list_recent(data.user.id, limit=20)
    assert [row["id"] for row in rows] == [data.personal.id, data.default.id]
    assert [row["id"] for row in await data.repository.list_recent(data.user.id, limit=1)] == [
        data.personal.id,
    ]


@pytest.mark.asyncio
async def test_recent_breaks_ties_by_id(database_session, category_data) -> None:
    data = category_data
    await save_content(
        database_session,
        user_id=data.user.id,
        categories=[data.personal, data.default],
    )

    rows = await data.repository.list_recent(data.user.id, limit=2)

    assert [row["id"] for row in rows] == sorted([data.personal.id, data.default.id])


@pytest.mark.asyncio
async def test_delete_and_move_recompute_statistics_from_original_save_time(
    database_session,
    category_data,
) -> None:
    data = category_data
    old = await save_content(
        database_session,
        user_id=data.user.id,
        categories=[data.personal],
    )
    latest = await save_content(
        database_session,
        user_id=data.user.id,
        categories=[data.personal],
        saved_at=SAVED_AT + timedelta(days=2),
    )
    await save_content(
        database_session,
        user_id=data.user.id,
        categories=[data.default],
        saved_at=SAVED_AT + timedelta(days=1),
    )
    await database_session.execute(delete(Content).where(Content.id == latest.id))
    summaries = {row["id"]: row for row in await data.repository.list_summaries(data.user.id)}
    assert summaries[data.personal.id]["content_count"] == 1
    assert summaries[data.personal.id]["last_saved_at"] == SAVED_AT

    await database_session.execute(
        delete(content_categories).where(content_categories.c.content_id == old.id)
    )
    await database_session.execute(
        insert(content_categories).values(
            content_id=old.id,
            category_id=data.empty.id,
        )
    )
    summaries = {row["id"]: row for row in await data.repository.list_summaries(data.user.id)}
    assert summaries[data.personal.id]["content_count"] == 0
    assert summaries[data.personal.id]["last_saved_at"] is None
    assert summaries[data.empty.id]["content_count"] == 1
    assert summaries[data.empty.id]["last_saved_at"] == SAVED_AT
    assert [row["id"] for row in await data.repository.list_recent(data.user.id, limit=20)] == [
        data.default.id,
        data.empty.id,
    ]

    await database_session.execute(delete(Content).where(Content.user_id == data.user.id))
    summaries = await data.repository.list_summaries(data.user.id)
    assert all(row["content_count"] == 0 and row["last_saved_at"] is None for row in summaries)
    assert await data.repository.list_recent(data.user.id, limit=20) == []


@pytest.mark.asyncio
async def test_category_summaries_each_use_one_query(database_session, category_data) -> None:
    data = category_data
    await save_content(database_session, user_id=data.user.id, categories=[data.personal])
    connection = await database_session.connection()
    statements = []

    def record_query(conn, cursor, statement, parameters, context, executemany):
        statements.append(statement)

    event.listen(connection.sync_connection, "before_cursor_execute", record_query)
    try:
        await data.repository.list_summaries(data.user.id)
        assert len(statements) == 1
        statements.clear()
        await data.repository.list_recent(data.user.id, limit=2)
        assert len(statements) == 1
    finally:
        event.remove(connection.sync_connection, "before_cursor_execute", record_query)
