from pathlib import Path
from uuid import uuid4

import pytest
from alembic.migration import MigrationContext
from alembic.operations import Operations
from alembic.script import ScriptDirectory
from sqlalchemy import text

PREVIOUS_REVISION = "202610310021"
REASON_REVISION = "202611060022"
MIGRATIONS = Path(__file__).resolve().parents[2] / "alembic"


def _create_previous_schema(connection, schema: str) -> None:
    # Never fall back to public: every unqualified migration statement stays isolated.
    connection.execute(text(f'CREATE SCHEMA "{schema}"'))
    connection.execute(text(f'SET LOCAL search_path TO "{schema}"'))
    scripts = ScriptDirectory(str(MIGRATIONS))
    revisions = list(scripts.walk_revisions(base="base", head=PREVIOUS_REVISION))
    with Operations.context(MigrationContext.configure(connection)):
        for revision in reversed(revisions):
            revision.module.upgrade()


def _run_reason_revision(connection, direction: str) -> None:
    revision = ScriptDirectory(str(MIGRATIONS)).get_revision(REASON_REVISION)
    assert revision.down_revision == PREVIOUS_REVISION
    with Operations.context(MigrationContext.configure(connection)):
        getattr(revision.module, direction)()


@pytest.mark.asyncio
async def test_existing_database_gains_an_unlinked_reason_table(database_connection) -> None:
    connection = database_connection
    schema = f"reason_migration_{uuid4().hex}"
    await connection.run_sync(_create_previous_schema, schema)
    await connection.execute(text("INSERT INTO users (id, display_name) VALUES (1, 'owner')"))
    await connection.execute(text(
        "INSERT INTO contents (id, user_id, content_type, source, title, summary) "
        "VALUES (1, 1, 'link', 'web', 't', 's')"
    ))

    await connection.run_sync(_run_reason_revision, "upgrade")

    columns = await connection.execute(text(
        "SELECT column_name, data_type, is_nullable FROM information_schema.columns "
        "WHERE table_schema = :schema AND table_name = 'account_deletion_reasons' "
        "ORDER BY column_name"
    ), {"schema": schema})
    assert [tuple(row) for row in columns] == [
        ("deleted_on", "date", "NO"),
        ("id", "integer", "NO"),
        ("reasons", "ARRAY", "NO"),
    ]
    references = await connection.scalar(text(
        "SELECT count(*) FROM pg_constraint WHERE contype = 'f' "
        "AND conrelid = 'account_deletion_reasons'::regclass"
    ))
    assert references == 0
    # Existing rows are untouched.
    assert (await connection.execute(text("SELECT id, user_id FROM contents"))).all() == [(1, 1)]
    await connection.execute(text(
        "INSERT INTO account_deletion_reasons (reasons, deleted_on) "
        "VALUES (ARRAY['rejoin', 'other'], DATE '2026-11-06')"
    ))

    await connection.run_sync(_run_reason_revision, "downgrade")

    assert await connection.scalar(
        text("SELECT to_regclass('account_deletion_reasons')")
    ) is None
    assert (await connection.execute(text("SELECT id FROM users"))).all() == [(1,)]
