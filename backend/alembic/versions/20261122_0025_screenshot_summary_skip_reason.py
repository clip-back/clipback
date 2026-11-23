"""Persist the reason a screenshot summary was skipped.

Revision ID: 202611220025
Revises: 202611220024
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "202611220025"
down_revision: str | None = "202611220024"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("contents", sa.Column("screenshot_summary_skip_reason", sa.String(32)))
    op.create_check_constraint(
        "ck_contents_screenshot_summary_skip_reason",
        "contents",
        "screenshot_summary_skip_reason IS NULL OR "
        "(content_type = 'screenshot' AND "
        "screenshot_summary_skip_reason = 'monthly_limit_exceeded')",
    )


def downgrade() -> None:
    # Restore the old server's response value before removing the screenshot reason.
    op.execute(sa.text("""
        UPDATE summary_jobs SET error_code = 'daily_limit_exceeded'
        WHERE error_code = 'monthly_limit_exceeded'
    """))
    op.drop_constraint("ck_contents_screenshot_summary_skip_reason", "contents", type_="check")
    op.drop_column("contents", "screenshot_summary_skip_reason")
