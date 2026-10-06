"""Persist asynchronous YouTube summary jobs."""

import sqlalchemy as sa
from alembic import op

revision = "202609220011"
down_revision = "202609070010"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "summary_jobs",
        sa.Column(
            "content_id",
            sa.Integer(),
            sa.ForeignKey("contents.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column("video_id", sa.String(11), nullable=False),
        sa.Column("status", sa.String(20), nullable=False),
        sa.Column("attempts", sa.Integer(), nullable=False),
        sa.Column(
            "next_run_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column("lease_expires_at", sa.DateTime(timezone=True)),
        sa.Column("lease_token", sa.String(36)),
        sa.Column("error_code", sa.String(40)),
        sa.Column("model", sa.String(120), nullable=False),
        sa.Column("usage", sa.JSON(), nullable=False),
        sa.Column("apply_title", sa.Boolean(), nullable=False),
        sa.Column("apply_summary", sa.Boolean(), nullable=False),
        sa.Column("apply_category", sa.Boolean(), nullable=False),
    )
    op.create_index("ix_summary_jobs_status", "summary_jobs", ["status"])


def downgrade():
    op.drop_table("summary_jobs")
