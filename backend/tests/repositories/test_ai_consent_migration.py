"""Revision 202611250027 with the deployed Alembic command: empty DB and a #462 DB."""

import asyncio
import os
import sys
from pathlib import Path
from uuid import uuid4

import asyncpg
import pytest
import pytest_asyncio
from sqlalchemy.engine import make_url

BACKEND = Path(__file__).resolve().parents[2]
PREVIOUS = "202611230026"
SQL = BACKEND / "alembic" / "sql"
pytestmark = pytest.mark.asyncio
REVISION = "202611250027"


@pytest_asyncio.fixture
async def migration_database():
    configured = os.environ.get("TEST_DATABASE_URL")
    if not configured:
        pytest.skip("TEST_DATABASE_URL is required for PostgreSQL migration tests")
    source = make_url(configured)
    name = f"ai_consent_migration_{uuid4().hex}"
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

            async def alembic(*args):
                process = await asyncio.create_subprocess_exec(
                    sys.executable, "-m", "alembic", *args, cwd=BACKEND, env=environment,
                    stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT,
                )
                output, _ = await process.communicate()
                return process.returncode, output.decode()

            connection = await asyncpg.connect(database=name, **arguments)
            try:
                yield connection, alembic
            finally:
                await connection.close()
        finally:
            await admin.execute(f'DROP DATABASE "{name}"')
    finally:
        await admin.close()


async def ok(alembic, *args):
    code, output = await alembic(*args)
    assert code == 0, output
    return output


async def test_empty_database_upgrades_checks_and_refuses_downgrade(migration_database):
    connection, alembic = migration_database
    await ok(alembic, "upgrade", "head")
    await ok(alembic, "check")
    assert await connection.fetchval("SELECT version_num FROM alembic_version") == REVISION
    code, output = await alembic("downgrade", PREVIOUS)
    assert code != 0
    assert "cannot be downgraded" in output
    assert await connection.fetchval("SELECT version_num FROM alembic_version") == REVISION
    assert await connection.fetchval("SELECT to_regclass('ai_transfer_consents')") is not None


async def test_462_database_keeps_rows_and_takes_the_new_constraints(migration_database):
    connection, alembic = migration_database
    await ok(alembic, "upgrade", PREVIOUS)
    user = await connection.fetchval(
        "INSERT INTO users (display_name, is_guest) VALUES ('p', true) RETURNING id")
    await connection.execute("""
        INSERT INTO contents (id, user_id, content_type, source, title, summary,
                              screenshot_summary_skip_reason)
        VALUES (1, $1, 'screenshot', 'screenshot', 't', '', 'monthly_limit_exceeded')
    """, user)
    with pytest.raises(asyncpg.CheckViolationError):
        await connection.execute(
            "UPDATE contents SET screenshot_summary_skip_reason = 'ai_consent_required'")

    await ok(alembic, "upgrade", "head")
    await ok(alembic, "check")
    assert await connection.fetchval(
        "SELECT screenshot_summary_skip_reason FROM contents") == "monthly_limit_exceeded"
    await connection.execute(
        "UPDATE contents SET screenshot_summary_skip_reason = 'ai_consent_required'")
    with pytest.raises(asyncpg.CheckViolationError):
        await connection.execute("UPDATE contents SET screenshot_summary_skip_reason = 'other'")
    # No row means undecided: existing accounts get no backfill.
    assert await connection.fetchval("SELECT count(*) FROM ai_transfer_consents") == 0

    insert = ("INSERT INTO ai_transfer_consents VALUES ($1, $2, $3, now(), false) "
              "ON CONFLICT (user_id) DO UPDATE SET status = excluded.status, "
              "notice_version = excluded.notice_version")
    for status, version in (("granted", 1), ("denied", 1)):
        await connection.execute(insert, user, status, version)
    for status, version in (("undecided", 1), ("granted", 2), ("granted", 0)):
        with pytest.raises(asyncpg.CheckViolationError):
            await connection.execute(insert, user, status, version)
    with pytest.raises(asyncpg.ForeignKeyViolationError):
        await connection.execute(insert, user + 1, "granted", 1)
    await connection.execute("DELETE FROM contents")
    await connection.execute("DELETE FROM users WHERE id = $1", user)
    assert await connection.fetchval("SELECT count(*) FROM ai_transfer_consents") == 0

    code, output = await alembic("downgrade", "-1")
    assert code != 0
    assert "cannot be downgraded" in output
    assert await connection.fetchval("SELECT version_num FROM alembic_version") == REVISION


async def test_462_console_rollback_stops_after_this_revision(migration_database):
    connection, alembic = migration_database
    await ok(alembic, "upgrade", "head")
    console = (SQL / "rollback_monthly_summary_limit.sql").read_text(encoding="utf-8")
    with pytest.raises(asyncpg.RaiseError, match="Expected only Alembic revision 202611230026"):
        await connection.execute(console)
    assert await connection.fetchval("SELECT version_num FROM alembic_version") == REVISION
    assert await connection.fetchval("SELECT to_regclass('usage_records')") is not None
