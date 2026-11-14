"""The manual backup's minimal seed must support real maintenance SQL without Docker."""

import os
from datetime import UTC, datetime
from uuid import uuid4

import pytest
import pytest_asyncio
from sqlalchemy import text
from sqlalchemy.exc import ProgrammingError
from sqlalchemy.ext.asyncio import create_async_engine

from app.integrations.deletion_ledger import DeletionLedger, LocalLedgerStore
from scripts.image_backup_jobs import prune_cleanup_rows, reflected_prefix
from tests.support.manual_backup_seed import manual_backup_seed_sql

pytestmark = pytest.mark.asyncio


@pytest_asyncio.fixture
async def seed_engine():
    database_url = os.environ.get("TEST_DATABASE_URL")
    if not database_url:
        pytest.skip("TEST_DATABASE_URL is required for PostgreSQL tests")
    schema = "manual_backup_seed_" + uuid4().hex
    # Every pooled connection, including prune_cleanup_rows' own connection, is isolated.
    # Do not fall back to public: migrated tables there would hide an incomplete seed.
    engine = create_async_engine(
        database_url, connect_args={"server_settings": {"search_path": schema}},
    )
    try:
        async with engine.begin() as connection:
            await connection.execute(text(f'CREATE SCHEMA "{schema}"'))
        try:
            async with engine.begin() as connection:
                raw = await connection.get_raw_connection()
                await raw.driver_connection.execute(manual_backup_seed_sql())
            yield engine
        finally:
            async with engine.begin() as connection:
                await connection.execute(text(f'DROP SCHEMA "{schema}" CASCADE'))
    finally:
        await engine.dispose()


@pytest.fixture
def empty_ledger(tmp_path):
    ledger = DeletionLedger(LocalLedgerStore(tmp_path / "ledger"))
    ledger.initialize()
    return ledger


async def test_current_seed_supports_maintenance_and_preserves_pending(seed_engine, empty_ledger):
    async with seed_engine.connect() as connection:
        assert await reflected_prefix(connection, []) == 0
    assert await prune_cleanup_rows(empty_ledger, seed_engine, now=datetime.now(UTC)) == 0
    # Read after the real DELETE's commit through a separate connection.
    async with seed_engine.connect() as connection:
        rows = (await connection.execute(text(
            "SELECT operation_id, completed, attempts FROM image_deletions"
        ))).all()
    assert rows == [("pending98", False, 0)]


async def test_missing_user_created_at_reaches_undefined_column(seed_engine):
    async with seed_engine.begin() as connection:
        await connection.execute(text("ALTER TABLE users DROP COLUMN created_at"))
    async with seed_engine.connect() as connection:
        with pytest.raises(ProgrammingError) as error:
            await reflected_prefix(connection, [])
    assert error.value.orig.sqlstate == "42703"


@pytest.mark.parametrize("column", ["user_id", "content_id", "intent", "deleted_at"])
async def test_missing_cleanup_column_reaches_undefined_column(seed_engine, empty_ledger, column):
    # Mutate the shared seed after applying it; never maintain a second schema copy.
    async with seed_engine.begin() as connection:
        await connection.execute(text(f"ALTER TABLE image_deletions DROP COLUMN {column}"))
    with pytest.raises(ProgrammingError) as error:
        await prune_cleanup_rows(empty_ledger, seed_engine, now=datetime.now(UTC))
    assert error.value.orig.sqlstate == "42703"
