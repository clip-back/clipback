from pathlib import Path

import pytest
from alembic.migration import MigrationContext
from alembic.operations import Operations
from alembic.script import ScriptDirectory
from sqlalchemy import text

from app.core.config import settings
from tests.integration.helpers import guest
from tests.integration.test_usage_limits import assert_summary, save

MIGRATIONS = Path(__file__).resolve().parents[2] / "alembic"


@pytest.mark.asyncio
async def test_downgrade_converts_monthly_reason_and_drops_usage(
    api, database_connection, monkeypatch,
):
    monkeypatch.setattr(settings, "youtube_summary_enabled", True)
    headers, _, _ = await guest(api)
    for _ in range(20):
        assert_summary(await save(api, headers))
    skipped = await save(api, headers)
    assert_summary(skipped, "skipped", "monthly_limit_exceeded")

    def downgrade(connection):
        revision = ScriptDirectory(str(MIGRATIONS)).get_revision("202611220024")
        with Operations.context(MigrationContext.configure(connection)):
            revision.module.downgrade()

    await database_connection.run_sync(downgrade)
    code = await database_connection.scalar(
        text("SELECT error_code FROM summary_jobs WHERE content_id = :id"), {"id": skipped["id"]},
    )
    assert code == "daily_limit_exceeded"
    assert await database_connection.scalar(text("SELECT to_regclass('usage_records')")) is None
