"""Exercise the deployed Alembic command and the operator's SQL against existing rows."""

import asyncio
import json
import os
import sys
from datetime import datetime, timedelta
from pathlib import Path
from uuid import uuid4
from zoneinfo import ZoneInfo

import asyncpg
import pytest
import pytest_asyncio
from sqlalchemy.engine import make_url

BACKEND = Path(__file__).resolve().parents[2]
SQL = BACKEND / "alembic" / "sql"
PREVIOUS = "202611220025"
LEGACY = "202611170023"
KST = ZoneInfo("Asia/Seoul")


def first_runbook_query(heading):
    docs = (BACKEND.parent / "docs" / "railway-deployment.md").read_text(encoding="utf-8")
    section = docs.split(f"### {heading}\n", 1)[1].split("\n### ", 1)[0]
    return section.split("```sql\n", 1)[1].split("\n```", 1)[0]


@pytest_asyncio.fixture
async def migration_database():
    configured = os.environ.get("TEST_DATABASE_URL")
    if not configured:
        pytest.skip("TEST_DATABASE_URL is required for PostgreSQL migration tests")
    source = make_url(configured)
    name = f"monthly_backfill_{uuid4().hex}"
    arguments = dict(host=source.host, port=source.port or 5432,
                     user=source.username, password=source.password)
    admin = await asyncpg.connect(database=source.database, **arguments)
    try:
        await admin.execute(f'CREATE DATABASE "{name}"')
        try:
            environment = {
                **os.environ, "APP_ENVIRONMENT": "test", "YOUTUBE_SUMMARY_ENABLED": "false",
                "DATABASE_URL": source.set(database=name).render_as_string(hide_password=False),
            }

            async def migrate(*args):
                process = await asyncio.create_subprocess_exec(
                    sys.executable, "-m", "alembic", *args, cwd=BACKEND, env=environment,
                    stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT,
                )
                output, _ = await process.communicate()
                assert process.returncode == 0, output.decode()

            async def connect():
                return await asyncpg.connect(database=name, **arguments)

            connection = await connect()
            try:
                yield connection, migrate, connect
            finally:
                await connection.close()
        finally:
            await admin.execute(f'DROP DATABASE "{name}"')
    finally:
        await admin.close()


async def insert_content(connection, content_id, kind, saved_at):
    await connection.execute("""
        INSERT INTO contents (id, user_id, content_type, source, title, summary, saved_at)
        VALUES ($1, 1, $2, $3, 'synthetic title', '', $4)
    """, content_id, kind, "youtube" if kind == "link" else "screenshot", saved_at)


async def insert_job(connection, content_id, status, error_code=None):
    await connection.execute("""
        INSERT INTO summary_jobs
            (content_id, kind, target_id, status, attempts, error_code, model, usage,
             apply_title, apply_summary, apply_category)
        VALUES ($1, 'youtube', 'dQw4w9WgXcQ', $2, 0, $3, 'test', '[]', true, true, true)
    """, content_id, status, error_code)


async def insert_event(connection, content_id, metadata, created_at, event="content_created"):
    await connection.execute("""
        INSERT INTO content_events (user_id, content_id, event_type, metadata_json, created_at)
        VALUES (1, $1, $2, $3, $4)
    """, content_id, event, metadata, created_at)


async def usage(connection):
    return [
        tuple(row) for row in await connection.fetch("""
            SELECT content_id, kind, recorded_at FROM usage_records ORDER BY content_id, kind
        """)
    ]


@pytest.mark.asyncio
async def test_upgrade_backfills_only_eligible_current_kst_month_contents(migration_database):
    connection, migrate, _ = migration_database
    await migrate("upgrade", PREVIOUS)
    await connection.execute("SET TIME ZONE 'America/Los_Angeles'")
    await connection.execute("INSERT INTO users (id, display_name) VALUES (1, 'synthetic owner')")
    start = datetime.now(KST).replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    past = start - timedelta(microseconds=1)
    end = (start + timedelta(days=31)).replace(day=1)
    last = end - timedelta(microseconds=1)

    for content_id, status in enumerate(
        ("queued", "processing", "completed", "failed", "skipped", "completed"), start=1,
    ):
        await insert_content(connection, content_id, "link", past if content_id == 6 else start)
        await insert_job(connection, content_id, status)
    for content_id, metadata in enumerate((
        '{"ocr_status":"success"}',
        '{ "ocr_status": "success" }',
        '{"ocr_status":"no_text"}',
        '{"ocr_status":"success"',
        None,
        '',
        '{"nested":{"ocr_status":"success"}}',
        '{"ocr_status":"success"}',
        '{"ocr_status":"success"}',
        '{"ocr_status":"success"}',
    ), start=7):
        saved_at = past if content_id == 14 else start
        await insert_content(connection, content_id, "screenshot", saved_at)
        await insert_event(
            connection, content_id, metadata, past if content_id == 15 else start,
            event="card_clicked" if content_id == 16 else "content_created",
        )
    await insert_event(connection, 7, '{"ocr_status":"success"}', start)
    for content_id, saved_at in ((19, last), (20, end), (23, past)):
        await insert_content(connection, content_id, "link", saved_at)
        await insert_job(connection, content_id, "queued")
    for content_id, saved_at in ((21, last), (22, end)):
        await insert_content(connection, content_id, "screenshot", saved_at)
        await insert_event(connection, content_id, '{"ocr_status":"success"}', saved_at)
    await connection.execute("""
        INSERT INTO usage_records (user_id, content_id, kind, recorded_at) VALUES
            (1, 4, 'ai_summary', $1), (1, 5, 'ai_summary', $1),
            (1, 1, 'category_recommendation', $1), (1, 4, 'category_recommendation', $1),
            (1, NULL, 'ai_summary', $1),
            (1, 6, 'ai_summary', $2), (1, 20, 'category_recommendation', $3)
    """, start, past, end)
    preflight = (SQL / "check_monthly_summary_backfill.sql").read_text(encoding="utf-8")
    assert tuple(await connection.fetchrow(preflight)) == (10, 3, 4, 3)

    await migrate("upgrade", "head")

    assert await usage(connection) == [
        (1, "ai_summary", start), (1, "category_recommendation", start),
        (2, "ai_summary", start), (3, "ai_summary", start),
        (4, "category_recommendation", start), (6, "ai_summary", past),
        (7, "ai_summary", start), (8, "ai_summary", start), (19, "ai_summary", last),
        (20, "category_recommendation", end), (21, "ai_summary", last),
        (None, "ai_summary", start),
    ]
    recount_totals = first_runbook_query("배포와 재집계")
    assert tuple(await connection.fetchrow(recount_totals)) == (8, 2)

    # An old server writes no usage, and its worker leaves a backfilled failed row behind.
    await insert_content(connection, 17, "link", start)
    await insert_job(connection, 17, "queued")
    await insert_content(connection, 18, "screenshot", start)
    await insert_event(connection, 18, '{"ocr_status":"success"}', start)
    await connection.execute("UPDATE summary_jobs SET status = 'failed' WHERE content_id = 2")
    backfill = (SQL / "backfill_monthly_summary_usage.sql").read_text(encoding="utf-8")

    assert tuple(await connection.fetchrow(backfill)) == (2, 1)
    expected = [
        (1, "ai_summary", start), (1, "category_recommendation", start),
        (3, "ai_summary", start), (4, "category_recommendation", start),
        (6, "ai_summary", past), (7, "ai_summary", start), (8, "ai_summary", start),
        (17, "ai_summary", start), (18, "ai_summary", start), (19, "ai_summary", last),
        (20, "category_recommendation", end), (21, "ai_summary", last),
        (None, "ai_summary", start),
    ]
    assert await usage(connection) == expected
    assert tuple(await connection.fetchrow(recount_totals)) == (9, 2)
    assert tuple(await connection.fetchrow(backfill)) == (0, 0)
    assert await usage(connection) == expected


async def rollback_state(connection):
    columns = await connection.fetch("""
        SELECT table_name, column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema = 'public'
        ORDER BY table_name, ordinal_position
    """)
    indexes = await connection.fetch("""
        SELECT tablename, indexname, indexdef
        FROM pg_indexes WHERE schemaname = 'public'
        ORDER BY tablename, indexname
    """)
    constraints = await connection.fetch("""
        SELECT c.conrelid::regclass::text AS relation, c.conname, pg_get_constraintdef(c.oid)
        FROM pg_constraint c JOIN pg_namespace n ON n.oid = c.connamespace
        WHERE n.nspname = 'public'
        ORDER BY relation, c.conname
    """)
    return (
        columns, indexes, constraints,
        await connection.fetchval("SELECT version_num FROM alembic_version"),
        # Keep the result type stable across DDL while comparing every field.
        await connection.fetch("SELECT to_jsonb(c) FROM contents c ORDER BY c.id"),
        await connection.fetch("SELECT to_jsonb(j) FROM summary_jobs j ORDER BY j.content_id"),
    )


@pytest.mark.asyncio
async def test_console_rollback_matches_alembic_downgrade(migration_database):
    connection, migrate, connect = migration_database
    await migrate("upgrade", "head")
    await connection.execute("INSERT INTO users (id, display_name) VALUES (1, 'synthetic owner')")
    now = datetime.now(KST)
    await insert_content(connection, 11, "link", now)
    await insert_job(connection, 11, "skipped", "monthly_limit_exceeded")
    await insert_content(connection, 12, "screenshot", now)
    await connection.execute("""
        UPDATE contents SET screenshot_summary_skip_reason = 'monthly_limit_exceeded' WHERE id = 12;
        INSERT INTO usage_records (user_id, content_id, kind, recorded_at)
        VALUES (1, 11, 'ai_summary', now())
    """)

    console_sql = (SQL / "rollback_monthly_summary_limit.sql").read_text(encoding="utf-8")
    check_state = first_runbook_query("이전 서버로 되돌리기")
    original = await rollback_state(connection)
    peer = await connect()
    try:
        async with peer.transaction():
            await peer.execute("LOCK TABLE usage_records IN ACCESS SHARE MODE")
            with pytest.raises(asyncpg.LockNotAvailableError):
                async with connection.transaction():
                    await connection.execute("SET LOCAL lock_timeout = '100ms'")
                    await connection.execute(console_sql)
    finally:
        await peer.close()
    assert await rollback_state(connection) == original
    assert tuple(await connection.fetchrow(check_state)) == ("202611230026", True, True)

    transaction = connection.transaction()
    await transaction.start()
    try:
        await connection.execute(console_sql)
        console = await rollback_state(connection)
        assert tuple(await connection.fetchrow(check_state)) == (LEGACY, False, False)
    finally:
        await transaction.rollback()
    await migrate("downgrade", LEGACY)
    assert await rollback_state(connection) == console
    columns, _, _, revision, contents, jobs = console
    assert revision == LEGACY
    assert "usage_records" not in {row["table_name"] for row in columns}
    assert "screenshot_summary_skip_reason" not in {row["column_name"] for row in columns}
    contents = [json.loads(row[0]) for row in contents]
    jobs = [json.loads(row[0]) for row in jobs]
    assert [row["id"] for row in contents] == [11, 12]
    assert [(r["content_id"], r["status"], r["error_code"]) for r in jobs] == [
        (11, "skipped", "daily_limit_exceeded")
    ]
    with pytest.raises(asyncpg.PostgresError, match="Expected only Alembic revision"):
        await connection.execute(console_sql)
    assert await rollback_state(connection) == console


@pytest.mark.asyncio
async def test_backfill_rechecks_job_status_when_worker_finishes_first(migration_database):
    connection, migrate, connect = migration_database
    await migrate("upgrade", "head")
    await connection.execute("INSERT INTO users (id, display_name) VALUES (1, 'synthetic owner')")
    await insert_content(connection, 1, "link", datetime.now(KST))
    await insert_job(connection, 1, "processing")
    backfill = (SQL / "backfill_monthly_summary_usage.sql").read_text(encoding="utf-8")
    peer = await connect()
    try:
        async with asyncio.TaskGroup() as tasks:
            async with connection.transaction():
                # Claim timeout takes the job lock and releases the usage in one transaction.
                await connection.execute(
                    "UPDATE summary_jobs SET status = 'failed' WHERE content_id = 1"
                )
                await connection.execute("DELETE FROM usage_records WHERE content_id = 1")
                recount = tasks.create_task(peer.fetchrow(backfill, timeout=5))
                async with asyncio.timeout(5):
                    while not await connection.fetchval("""
                        SELECT pg_backend_pid() = ANY(pg_blocking_pids($1))
                    """, peer.get_server_pid()):
                        await asyncio.sleep(0.01)
        assert tuple(recount.result()) == (0, 0)
        assert await usage(connection) == []
    finally:
        await peer.close()
