from pathlib import Path
from uuid import uuid4

import pytest
from alembic.migration import MigrationContext
from alembic.operations import Operations
from alembic.script import ScriptDirectory
from sqlalchemy import inspect, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.event_repository import EventRepository

PREVIOUS_REVISION = "202609220011"
RECOMMENDATION_REVISION = "202609240012"
MIGRATIONS = Path(__file__).resolve().parents[2] / "alembic"


def _create_legacy_schema(connection, schema: str) -> None:
    # Never fall back to public: every unqualified migration statement stays isolated.
    connection.execute(text(f'CREATE SCHEMA "{schema}"'))
    connection.execute(text(f'SET LOCAL search_path TO "{schema}"'))
    scripts = ScriptDirectory(str(MIGRATIONS))
    revisions = list(scripts.walk_revisions(base="base", head=PREVIOUS_REVISION))
    with Operations.context(MigrationContext.configure(connection)):
        for revision in reversed(revisions):
            revision.module.upgrade()


def _run_recommendation_revision(connection, direction: str) -> None:
    revision = ScriptDirectory(str(MIGRATIONS)).get_revision(RECOMMENDATION_REVISION)
    assert revision.down_revision == PREVIOUS_REVISION
    with Operations.context(MigrationContext.configure(connection)):
        getattr(revision.module, direction)()


async def _seed_legacy_history(connection) -> None:
    await connection.execute(
        text("""
        INSERT INTO users (id, display_name) VALUES (1, 'owner'), (2, 'other')
    """)
    )
    await connection.execute(
        text("""
        INSERT INTO categories (id, user_id, name, is_default)
        VALUES (1001, 1, '취업', false), (1002, 1, '자기계발', false)
    """)
    )
    await connection.execute(
        text("""
        INSERT INTO contents (
            id, user_id, content_type, source, title, summary, original_url,
            is_favorite, saved_at, last_viewed_at
        ) VALUES
            (1, 1, 'link', 'web', 'Repeated', 'Saved summary', 'https://example.com/1',
             true, '2026-09-01 09:00:00+09', '2026-09-20 12:00:00+09'),
            (2, 1, 'link', 'web', 'Unopened', '', 'https://example.com/2',
             false, '2026-09-02 09:00:00+09', NULL),
            (3, 2, 'link', 'web', 'Other owner', '', 'https://example.com/3',
             false, '2026-09-03 09:00:00+09', '2026-09-19 12:00:00+09'),
            (4, 1, 'link', 'web', 'Deleted', '', 'https://example.com/4',
             false, '2026-09-04 09:00:00+09', NULL)
    """)
    )
    await connection.execute(
        text("""
        INSERT INTO content_categories (content_id, category_id)
        VALUES (1, 1001), (1, 1002), (2, 1001)
    """)
    )
    events = [
        (1, 1, "content_created"),
        (1, 1, "content_reopened"),
        (1, 1, "content_reopened"),
        (1, 1, "content_reopened"),
        (2, 1, "content_reopened"),  # Different user must not inflate content 1.
        (1, 2, "content_created"),
        (1, 2, "card_clicked"),
        (2, 3, "content_reopened"),
        (2, 3, "content_reopened"),
        (1, 3, "content_reopened"),  # Owner 1's history is not owner 2's count.
        (1, 4, "content_created"),
        (1, 4, "content_reopened"),
        (1, None, "category_filter_used"),
    ]
    await connection.execute(
        text("""
            INSERT INTO content_events (
                user_id, content_id, category_id, event_type, metadata_json, created_at
            ) VALUES (
                :user_id, :content_id, :category_id, :event_type,
                :metadata_json, '2026-09-20 12:00:00+09'
            )
        """),
        [
            {
                "user_id": user_id,
                "content_id": content_id,
                "category_id": 1001 if user_id == 1 else None,
                "event_type": event_type,
                "metadata_json": '{"legacy":true}',
            }
            for user_id, content_id, event_type in events
        ],
    )
    await connection.execute(text("DELETE FROM contents WHERE id = 4"))


async def _legacy_snapshot(connection) -> dict:
    queries = {
        "users": "SELECT * FROM users ORDER BY id",
        "categories": "SELECT * FROM categories ORDER BY id",
        "contents": """
            SELECT id, user_id, content_type, source, title, summary, original_url,
                   is_favorite, saved_at, last_viewed_at FROM contents ORDER BY id
        """,
        "content_categories": """
            SELECT * FROM content_categories ORDER BY content_id, category_id
        """,
        "events": """
            SELECT id, user_id, content_id, category_id, event_type, metadata_json, created_at
            FROM content_events ORDER BY id
        """,
    }
    snapshot = {}
    for key, query in queries.items():
        snapshot[key] = (await connection.execute(text(query))).mappings().all()
    async with AsyncSession(bind=connection, join_transaction_mode="create_savepoint") as session:
        repository = EventRepository(session)
        snapshot["stats"] = [dict(await repository.read_user_stats(user_id)) for user_id in (1, 2)]
    return snapshot


async def _assert_initialized_counts(connection) -> None:
    rows = (
        await connection.execute(
            text("""
        SELECT id, open_count, recommendation_count,
               last_recommended_at, last_recommended_surface
        FROM contents ORDER BY id
    """)
        )
    ).all()
    assert rows == [(1, 3, 0, None, None), (2, 0, 0, None, None), (3, 2, 0, None, None)]
    snapshots = (
        await connection.execute(
            text("""
        SELECT client_event_id, category_ids_at_event, recommendation_item_id
        FROM content_events ORDER BY id
    """)
        )
    ).all()
    assert snapshots and all(row == (None, None, None) for row in snapshots)


@pytest.mark.asyncio
async def test_legacy_upgrade_backfills_counts_and_preserves_history(database_connection) -> None:
    connection = database_connection
    schema = f"recommendation_migration_{uuid4().hex}"
    await connection.run_sync(_create_legacy_schema, schema)
    await _seed_legacy_history(connection)
    before = await _legacy_snapshot(connection)
    assert before["stats"] == [
        {"saved_count": 3, "reopened_count": 5},
        {"saved_count": 0, "reopened_count": 3},
    ]
    assert len(before["events"]) == 13
    assert sum(event["content_id"] is None for event in before["events"]) == 3

    await connection.run_sync(_run_recommendation_revision, "upgrade")

    assert await _legacy_snapshot(connection) == before
    await _assert_initialized_counts(connection)

    # Exercise downgrade with actual new data and a legacy event referring to a new item.
    await connection.execute(
        text("""
        INSERT INTO recommendation_batches (id, user_id, type, recommendation_date)
        VALUES (1, 1, 'TODAY', '2026-09-24')
    """)
    )
    await connection.execute(
        text("""
        INSERT INTO recommendation_batch_items (
            id, batch_id, rank, target_kind, target_id_snapshot, content_id, score
        ) VALUES (1, 1, 1, 'CONTENT', 1, 1, 0.5)
    """)
    )
    await connection.execute(
        text("""
            INSERT INTO recommendation_exposures (
                user_id, client_event_id, recommendation_item_id
            ) VALUES (1, :event_id, 1)
        """),
        {"event_id": uuid4()},
    )
    await connection.execute(
        text("""
            INSERT INTO content_events (
                user_id, content_id, event_type, client_event_id,
                category_ids_at_event, recommendation_item_id
            ) VALUES (1, 1, 'card_clicked', :event_id, ARRAY[1001, 1002], 1)
        """),
        {"event_id": uuid4()},
    )
    before_downgrade = await _legacy_snapshot(connection)

    await connection.run_sync(_run_recommendation_revision, "downgrade")

    assert await _legacy_snapshot(connection) == before_downgrade
    tables = await connection.run_sync(lambda sync: inspect(sync).get_table_names(schema=schema))
    assert not {
        "recommendation_batches",
        "recommendation_batch_items",
        "recommendation_exposures",
    }.intersection(tables)
    for table, removed in (
        (
            "contents",
            {
                "open_count",
                "recommendation_count",
                "last_recommended_at",
                "last_recommended_surface",
            },
        ),
        ("content_events", {"client_event_id", "category_ids_at_event", "recommendation_item_id"}),
    ):
        columns = await connection.run_sync(
            lambda sync: {
                column["name"] for column in inspect(sync).get_columns(table, schema=schema)
            }
        )
        assert not removed.intersection(columns)

    await connection.run_sync(_run_recommendation_revision, "upgrade")

    assert await _legacy_snapshot(connection) == before_downgrade
    await _assert_initialized_counts(connection)
