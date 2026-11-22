"""Persist AI usage records.

Revision ID: 202611220024
Revises: 202611170023
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "202611220024"
down_revision: str | None = "202611170023"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "usage_records",
        sa.Column("id", sa.BigInteger(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"),
                  nullable=False),
        sa.Column("kind", sa.String(24), nullable=False),
        sa.Column("recorded_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("content_id", sa.Integer(), sa.ForeignKey("contents.id", ondelete="SET NULL")),
        sa.CheckConstraint("kind IN ('ai_summary', 'category_recommendation')", name="usage_kind"),
    )
    op.create_index(
        "ix_usage_records_user_period", "usage_records", ["user_id", "recorded_at", "kind"],
    )
    op.create_index("ix_usage_records_content_id", "usage_records", ["content_id"])
    op.create_index(
        "uq_usage_records_summary_content", "usage_records", ["content_id"], unique=True,
        postgresql_where=sa.text("kind = 'ai_summary' AND content_id IS NOT NULL"),
    )


def downgrade() -> None:
    op.execute(sa.text("""
        UPDATE summary_jobs SET error_code = 'daily_limit_exceeded'
        WHERE error_code = 'monthly_limit_exceeded'
    """))
    op.drop_table("usage_records")
