"""Run the deployment migration command on isolated PostgreSQL databases."""

import asyncio
import json
import os
import sys
from pathlib import Path
from uuid import uuid4

import asyncpg
import pytest
from alembic.config import Config
from alembic.script import ScriptDirectory
from sqlalchemy.engine import make_url

BACKEND = Path(__file__).resolve().parents[2]


@pytest.mark.asyncio
@pytest.mark.parametrize("starting_revision", ["base", "202610250015", "202610230018"])
async def test_upgrade_head_preserves_both_deployed_branches(starting_revision):
    configured = os.environ.get("TEST_DATABASE_URL")
    if not configured:
        pytest.skip("TEST_DATABASE_URL is required for PostgreSQL migration tests")
    source = make_url(configured)
    name = f"merge94_{uuid4().hex}"
    arguments = dict(host=source.host, port=source.port or 5432,
                     user=source.username, password=source.password)
    admin = await asyncpg.connect(database=source.database, **arguments)
    await admin.execute(f'CREATE DATABASE "{name}"')
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

    connection = None
    try:
        if starting_revision != "base":
            await migrate("upgrade", starting_revision)
            connection = await asyncpg.connect(database=name, **arguments)
            await connection.execute("INSERT INTO users (id, display_name) VALUES (94, 'owner')")
            await connection.execute("""
                INSERT INTO categories (id, user_id, name, is_default)
                VALUES (94, 94, 'preserved', false)
            """)
            await connection.execute("""
                INSERT INTO contents (id, user_id, content_type, source, title, summary,
                                      is_favorite, open_count, recommendation_count)
                VALUES (94, 94, 'screenshot', 'screenshot', 'original', '', false, 0, 0)
            """)
            await connection.execute("""
                INSERT INTO content_assets (id, content_id, asset_type, storage_key, mime_type)
                VALUES (94, 94, 'screenshot', '94/original.png', 'image/png')
            """)
            if starting_revision == "202610230018":
                await connection.execute("""
                    UPDATE content_assets SET size_bytes=3, sha256=repeat('a', 64) WHERE id=94
                """)
            if starting_revision == "202610250015":
                await connection.execute("""
                    INSERT INTO category_submissions
                    (user_id, key, kind, fingerprint, status, status_code, result)
                    VALUES (94, '00000000-0000-0000-0000-000000000094', 'create',
                            'retained', 'success', 201, '{"id":94,"name":"preserved"}')
                """)
        await migrate("upgrade", "head")
        await migrate("check")
        if connection is None:
            connection = await asyncpg.connect(database=name, **arguments)
        assert await connection.fetchval("SELECT count(*) FROM alembic_version") == 1
        revision = await connection.fetchval("SELECT version_num FROM alembic_version")
        config = Config(str(BACKEND / "alembic.ini"))
        config.set_main_option("script_location", str(BACKEND / "alembic"))
        assert revision == ScriptDirectory.from_config(config).get_current_head()
        assert tuple(await connection.fetchrow(
            "SELECT id,phase,run_id,generation,drain_deadline,result FROM maintenance_state"
        )) == (1, "open", None, 0, None, None)
        assert await connection.fetchval("SELECT count(*) FROM maintenance_operations") == 0
        assert await connection.fetchval("SELECT count(*) FROM maintenance_events") == 0
        if starting_revision != "base":
            category_name = await connection.fetchval("SELECT name FROM categories WHERE id=94")
            assert category_name == "preserved"
            assert await connection.fetchval("SELECT title FROM contents WHERE id=94") == "original"
            asset = await connection.fetchrow("""
                SELECT storage_key, storage_backend, size_bytes, sha256
                FROM content_assets WHERE id=94
            """)
            integrity = (3, "a" * 64) if starting_revision == "202610230018" else (None, None)
            assert tuple(asset) == ("94/original.png", "local", *integrity)
            if starting_revision == "202610250015":
                row = await connection.fetchrow("""
                    SELECT status_code, result FROM category_submissions WHERE user_id=94
                """)
                assert row["status_code"] == 201
                assert json.loads(row["result"]) == {"id": 94, "name": "preserved"}
        # Re-running a deployment upgrade must not silently thaw or erase an admitted executor.
        run_id, operation_id = str(uuid4()), str(uuid4())
        await connection.execute(
            "UPDATE maintenance_state SET phase='draining',run_id=$1,generation=7,"
            "drain_deadline=now()+interval '60 seconds',result='draining' WHERE id=1", run_id,
        )
        await connection.execute(
            "INSERT INTO maintenance_operations(id,kind,executor,registered_at) "
            "VALUES($1,'migration-fixture','stopped-test-executor',now())", operation_id,
        )
        await migrate("upgrade", "head")
        assert tuple(await connection.fetchrow(
            "SELECT phase,run_id,generation,result FROM maintenance_state WHERE id=1"
        )) == ("draining", run_id, 7, "draining")
        assert await connection.fetchval(
            "SELECT id FROM maintenance_operations WHERE id=$1", operation_id,
        ) == operation_id
    finally:
        if connection is not None:
            await connection.close()
        await admin.execute(f'DROP DATABASE "{name}" WITH (FORCE)')
        await admin.close()
