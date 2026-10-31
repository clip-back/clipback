from pathlib import Path
from uuid import uuid4

import pytest
from alembic.migration import MigrationContext
from alembic.operations import Operations
from alembic.script import ScriptDirectory
from sqlalchemy import text

PREVIOUS_REVISION = "202610260020"
KIND_REVISION = "202610310021"
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


def _run_kind_revision(connection, direction: str) -> None:
    revision = ScriptDirectory(str(MIGRATIONS)).get_revision(KIND_REVISION)
    assert revision.down_revision == PREVIOUS_REVISION
    with Operations.context(MigrationContext.configure(connection)):
        getattr(revision.module, direction)()


@pytest.mark.asyncio
async def test_existing_youtube_jobs_keep_their_target_as_youtube_kind(database_connection) -> None:
    connection = database_connection
    await connection.run_sync(_create_legacy_schema, f"summary_kind_migration_{uuid4().hex}")
    await connection.execute(text("INSERT INTO users (id, display_name) VALUES (1, 'owner')"))
    await connection.execute(
        text("""
        INSERT INTO contents (id, user_id, content_type, source, title, summary, original_url)
        VALUES (1, 1, 'link', 'youtube', 't', 's', 'https://www.youtube.com/watch?v=dQw4w9WgXcQ')
    """)
    )
    await connection.execute(
        text("""
        INSERT INTO summary_jobs (
            content_id, video_id, status, attempts, model, usage,
            apply_title, apply_summary, apply_category
        ) VALUES (1, 'dQw4w9WgXcQ', 'queued', 0, 'm', '[]', true, true, true)
    """)
    )

    await connection.run_sync(_run_kind_revision, "upgrade")

    row = (
        await connection.execute(
            text("SELECT kind, target_id, status FROM summary_jobs WHERE content_id = 1")
        )
    ).one()
    assert tuple(row) == ("youtube", "dQw4w9WgXcQ", "queued")

    await connection.run_sync(_run_kind_revision, "downgrade")

    video_id = await connection.scalar(
        text("SELECT video_id FROM summary_jobs WHERE content_id = 1")
    )
    assert video_id == "dQw4w9WgXcQ"
