"""Backfill current-month AI summary usage.

Revision ID: 202611230026
Revises: 202611220025
"""

from collections.abc import Sequence
from pathlib import Path

from alembic import op

revision: str = "202611230026"
down_revision: str | None = "202611220025"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    sql = Path(__file__).resolve().parents[1] / "sql" / "backfill_monthly_summary_usage.sql"
    op.execute(sql.read_text(encoding="utf-8"))


def downgrade() -> None:
    # Revision 202611220024 drops the usage table on a full rollback.
    pass
