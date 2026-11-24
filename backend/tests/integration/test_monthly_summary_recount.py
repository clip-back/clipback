from pathlib import Path

import pytest
from sqlalchemy import text

from app.integrations.summary import SummaryError
from tests.integration.helpers import guest, request
from tests.integration.test_screenshot_usage_limits import screenshot
from tests.integration.test_usage_limits import assert_summary, save, worker as worker

SQL = Path(__file__).resolve().parents[2] / "alembic" / "sql"


@pytest.mark.asyncio
async def test_recount_during_worker_attempt_keeps_new_saves_and_releases_final_failure(
    api, database_connection, png_bytes, worker,
):
    summary_worker, fake_provider = worker
    headers, _, user = await guest(api)
    old_link = await save(api, headers)
    assert_summary(old_link)
    await database_connection.execute(text("""
        DELETE FROM usage_records WHERE content_id = :id AND kind = 'ai_summary'
    """), {"id": old_link["id"]})
    backfill = text((SQL / "backfill_monthly_summary_usage.sql").read_text(encoding="utf-8"))

    async def summary_rows():
        return dict((await database_connection.execute(text("""
            SELECT content_id, recorded_at FROM usage_records
            WHERE kind = 'ai_summary' AND user_id = :user_id
        """), {"user_id": user["id"]})).all())

    # Run the actual worker to processing, save with the new server, and then recount
    # before its final failure. Another new write follows the recount.
    active_rows = {}

    async def during_attempt():
        photo = await screenshot(api, headers, png_bytes)
        initial = await summary_rows()
        assert set(initial) == {photo["id"]}
        assert (await database_connection.execute(backfill)).one() == (1, 0)
        rows = await summary_rows()
        assert set(rows) == {old_link["id"], photo["id"]}
        assert rows[photo["id"]] == initial[photo["id"]]
        active_rows.update(initial)
        new_link = await save(api, headers)
        assert_summary(new_link)
        active_rows[new_link["id"]] = (await summary_rows())[new_link["id"]]

    fake_provider.action = during_attempt
    fake_provider.error = SummaryError("invalid_response")
    assert await summary_worker.run_once()
    assert fake_provider.calls == 1
    detail = await request(api, "GET", f"contents/{old_link['id']}", headers=headers)
    assert_summary(detail, "failed", "invalid_response")
    assert len(active_rows) == 2
    assert await summary_rows() == active_rows
    assert (await database_connection.execute(backfill)).one() == (0, 0)
    assert await summary_rows() == active_rows
