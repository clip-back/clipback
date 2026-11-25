"""Run the operator SQL on a disposable restored target, separate from the source."""

from pathlib import Path
from uuid import uuid4

import asyncpg
import pytest
import pytest_asyncio
from alembic.migration import MigrationContext
from alembic.operations import Operations
from alembic.script import ScriptDirectory
from sqlalchemy import text
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.schema import CreateSchema, DropSchema

from app.db.base import Base
from app.models.ai_transfer_consent import AITransferConsent
from app.models.content import Content
from app.models.summary_job import SummaryJob
from app.models.usage_record import UsageRecord
from app.models.user import User
from app.services.ai_consent import ai_allowed, read_consent

MIGRATIONS = Path(__file__).resolve().parents[2] / "alembic"
CLEANUP = (MIGRATIONS / "sql/cleanup_restored_ai_consent.sql").read_text()
TABLES = (
    User.__table__, Content.__table__, AITransferConsent.__table__,
    SummaryJob.__table__, UsageRecord.__table__,
)
COUNTS = """
SELECT (SELECT count(*) FROM ai_transfer_consents),
       (SELECT count(*) FROM ai_transfer_consents WHERE status = 'granted'),
       (SELECT count(*) FROM summary_jobs WHERE status IN ('queued', 'processing')),
       (SELECT count(*) FROM usage_records WHERE kind = 'ai_summary')
"""


@pytest_asyncio.fixture
async def restore_schemas(database_connection):
    upstream = database_connection.engine
    namespaces = []
    engines = []
    try:
        for label in ("source", "target"):
            name = f"consent_{label}_{uuid4().hex}"
            async with upstream.begin() as conn:
                await conn.execute(CreateSchema(name))
            namespaces.append(name)
            engine = create_async_engine(
                upstream.url, connect_args={"server_settings": {"search_path": name}},
            )
            engines.append(engine)
            async with engine.begin() as conn:
                await conn.run_sync(Base.metadata.create_all, tables=TABLES)
        yield namespaces, engines
    finally:
        for engine in engines:
            await engine.dispose()
        async with upstream.begin() as conn:
            for namespace in reversed(namespaces):
                await conn.execute(DropSchema(namespace, cascade=True))


async def seed(engine, *, legacy=False):
    async with engine.begin() as conn:
        await conn.execute(text("""
            INSERT INTO users(id, display_name)
                SELECT n, 'restore fixture' FROM generate_series(1, 7) AS n
        """))
        await conn.execute(text("""
            INSERT INTO contents(id, user_id, content_type, source, title, summary)
                SELECT n, least(n, 7), 'link', 'youtube', 'title', 'unchanged'
                FROM generate_series(1, 8) AS n
        """))
        await conn.execute(text("""
            INSERT INTO summary_jobs(content_id, kind, target_id, status, attempts,
                                     lease_token, lease_expires_at, model, usage,
                                     apply_title, apply_summary, apply_category)
                SELECT id, 'youtube', 'dQw4w9WgXcQ',
                       CASE WHEN id = 8 THEN 'completed'
                            WHEN id % 2 = 0 THEN 'processing' ELSE 'queued' END,
                       CASE WHEN id % 2 = 0 THEN 1 ELSE 0 END,
                       CASE WHEN id % 2 = 0 AND id < 8 THEN 'restore-token' END,
                       CASE WHEN id % 2 = 0 AND id < 8 THEN now() END,
                       'model', '[]', true, true, true
                FROM contents
        """))
        await conn.execute(text("""
            INSERT INTO usage_records(user_id, kind, recorded_at, content_id)
                SELECT user_id, 'ai_summary', now(), id FROM contents
                UNION ALL SELECT 7, 'category_recommendation', now(), null
        """))
        if not legacy:
            await conn.execute(text("""
                INSERT INTO ai_transfer_consents
                    (user_id, status, notice_version, decided_at, granted_after_denial)
                VALUES (2, 'granted', 1, now(), false), (3, 'granted', 1, now(), false),
                       (4, 'denied', 1, now(), false), (5, 'denied', 1, now(), false),
                       (6, 'granted', 1, now(), true)
            """))


async def cleanup(engine):
    async with engine.connect() as conn:
        raw = (await conn.get_raw_connection()).driver_connection
        try:
            await raw.execute(CLEANUP)
        finally:
            if raw.is_in_transaction():
                await raw.execute("ROLLBACK")


async def counts(engine):
    async with engine.connect() as conn:
        return tuple((await conn.execute(text(COUNTS))).one())


@pytest.mark.asyncio
async def test_restore_cleanup_handles_original_decisions_and_is_idempotent(restore_schemas):
    (source_name, _), (source, target) = restore_schemas
    await seed(source)
    assert await counts(source) == (5, 3, 7, 8)
    async with target.begin() as conn:
        for table in TABLES:
            await conn.exec_driver_sql(
                f"INSERT INTO {table.name} SELECT * FROM {source_name}.{table.name}"
            )
    assert await counts(target) == (5, 3, 7, 8)  # Isolated verification uses the original counts.

    async with source.begin() as conn:
        # Decisions that arrived after the recovery point: 1 denied, 3 withdrew, 5 re-granted.
        await conn.exec_driver_sql("""
            INSERT INTO ai_transfer_consents
                (user_id, status, notice_version, decided_at, granted_after_denial)
            VALUES (1, 'denied', 1, now(), false)
        """)
        await conn.exec_driver_sql(
            "UPDATE ai_transfer_consents SET status = 'denied' WHERE user_id = 3",
        )
        await conn.exec_driver_sql(
            "UPDATE ai_transfer_consents SET status = 'granted', granted_after_denial = true "
            "WHERE user_id = 5",
        )
    async with target.begin() as conn:
        # Start from the state after the existing restore flow replays a deletion.
        await conn.exec_driver_sql("DELETE FROM contents WHERE user_id = 6")
        await conn.exec_driver_sql("DELETE FROM users WHERE id = 6")
    assert await counts(target) == (4, 2, 6, 7)

    for _ in range(2):
        await cleanup(target)
        assert await counts(target) == (2, 0, 0, 1)
        async with async_sessionmaker(target)() as session:
            for user_id in (1, 2, 3, 4, 5, 7):
                now, record = await read_consent(session, user_id)
                assert (record.status if record else None) == (
                    "denied" if user_id in (4, 5) else None
                )
                assert not ai_allowed(record, required=True, data_at=now)
            assert await session.get(User, 6) is None
            assert await session.get(AITransferConsent, 6) is None
            jobs = (await session.execute(text("""
                SELECT status, error_code, lease_token, lease_expires_at
                FROM summary_jobs ORDER BY content_id
            """))).all()
            assert jobs == [
                ("skipped", "ai_consent_required", None, None),
            ] * 6 + [("completed", None, None, None)]
            records = (await session.execute(text("""
                SELECT kind, content_id FROM usage_records ORDER BY id
            """))).all()
            assert set(records) == {("ai_summary", 8), ("category_recommendation", None)}
    assert await counts(source) == (6, 3, 7, 8)


@pytest.mark.asyncio
async def test_legacy_target_upgrades_to_undecided_before_cleanup(restore_schemas):
    _, (_, target) = restore_schemas
    await seed(target, legacy=True)

    def upgrade(conn):
        revision = ScriptDirectory(str(MIGRATIONS)).get_revision("202611250027")
        with Operations.context(MigrationContext.configure(conn)):
            revision.module.upgrade()

    async with target.begin() as conn:
        await conn.exec_driver_sql("DROP TABLE ai_transfer_consents")
        assert await conn.scalar(text("SELECT to_regclass('ai_transfer_consents')")) is None
        await conn.run_sync(upgrade)
    assert await counts(target) == (0, 0, 7, 8)
    await cleanup(target)
    assert await counts(target) == (0, 0, 0, 1)
    async with async_sessionmaker(target)() as session:
        now, record = await read_consent(session, 1)
        assert record is None and not ai_allowed(record, required=True, data_at=now)


@pytest.mark.asyncio
async def test_cleanup_failure_rolls_back_consent_and_job_changes(restore_schemas):
    _, (_, target) = restore_schemas
    await seed(target)
    async with target.begin() as conn:
        await conn.exec_driver_sql("ALTER TABLE usage_records RENAME TO held_usage_records")
    with pytest.raises(asyncpg.UndefinedTableError, match="usage_records"):
        await cleanup(target)
    async with target.begin() as conn:
        await conn.exec_driver_sql("ALTER TABLE held_usage_records RENAME TO usage_records")
    assert await counts(target) == (5, 3, 7, 8)
