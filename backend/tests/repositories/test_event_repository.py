import pytest
from sqlalchemy import delete, event, select

from app.models.content import Content, ContentSource, ContentType
from app.models.content_event import ContentEvent, ContentEventType
from app.models.user import User
from app.repositories.event_repository import EventRepository


@pytest.mark.asyncio
async def test_lifetime_counts_survive_deletion_and_exclude_other_users(database_session) -> None:
    session = database_session
    user, other = User(display_name="통계 사용자"), User(display_name="다른 사용자")
    session.add_all([user, other])
    await session.flush()
    content = Content(
        user_id=user.id,
        content_type=ContentType.LINK,
        source=ContentSource.WEB,
        title="테스트",
        summary="누적 통계",
        original_url="https://example.com",
    )
    session.add(content)
    await session.flush()
    repository = EventRepository(session)
    assert dict(await repository.read_user_stats(user.id)) == {
        "saved_count": 0,
        "reopened_count": 0,
    }
    for kind in [ContentEventType.CONTENT_CREATED] + [ContentEventType.CONTENT_REOPENED] * 3:
        await repository.create(user_id=user.id, event_type=kind, content_id=content.id)
    for kind in ContentEventType:
        if kind not in (ContentEventType.CONTENT_CREATED, ContentEventType.CONTENT_REOPENED):
            await repository.create(user_id=user.id, event_type=kind, content_id=content.id)
    await repository.create(user_id=other.id, event_type=ContentEventType.CONTENT_CREATED)

    assert dict(await repository.read_user_stats(user.id)) == {
        "saved_count": 1,
        "reopened_count": 3,
    }
    assert dict(await repository.read_user_stats(other.id)) == {
        "saved_count": 1,
        "reopened_count": 0,
    }

    await session.execute(delete(Content).where(Content.id == content.id))
    content_ids = (
        await session.scalars(
            select(ContentEvent.content_id).where(ContentEvent.user_id == user.id)
        )
    ).all()
    assert content_ids and all(content_id is None for content_id in content_ids)
    assert dict(await repository.read_user_stats(user.id)) == {
        "saved_count": 1,
        "reopened_count": 3,
    }


@pytest.mark.asyncio
async def test_stats_reflect_new_events_and_rollback(database_session) -> None:
    session = database_session
    user = User(display_name="롤백 사용자")
    session.add(user)
    await session.flush()
    repository = EventRepository(session)
    async with session.begin_nested() as transaction:
        await repository.create(user_id=user.id, event_type=ContentEventType.CONTENT_CREATED)
        assert (await repository.read_user_stats(user.id))["saved_count"] == 1
        await transaction.rollback()

    assert dict(await repository.read_user_stats(user.id)) == {
        "saved_count": 0,
        "reopened_count": 0,
    }
    await repository.create(user_id=user.id, event_type=ContentEventType.CONTENT_REOPENED)
    assert dict(await repository.read_user_stats(user.id)) == {
        "saved_count": 0,
        "reopened_count": 1,
    }


@pytest.mark.asyncio
async def test_stats_uses_one_query(database_session) -> None:
    user = User(display_name="쿼리 사용자")
    database_session.add(user)
    await database_session.flush()
    connection = await database_session.connection()
    statements = []

    def record_query(conn, cursor, statement, parameters, context, executemany):
        statements.append(statement)

    event.listen(connection.sync_connection, "before_cursor_execute", record_query)
    try:
        await EventRepository(database_session).read_user_stats(user.id)
        assert len(statements) == 1
    finally:
        event.remove(connection.sync_connection, "before_cursor_execute", record_query)
