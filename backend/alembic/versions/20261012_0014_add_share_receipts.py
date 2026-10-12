"""retain mobile share idempotency receipts after content deletion

Revision ID: 202610120014
Revises: 202610110013
"""

import sqlalchemy as sa
from alembic import op

revision = "202610120014"
down_revision = "202610110013"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "share_receipts",
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"),
                  primary_key=True),
        sa.Column("key", sa.Uuid(), primary_key=True),
        sa.Column("kind", sa.String(16), nullable=False),
        sa.Column("fingerprint", sa.String(64), nullable=False),
        sa.Column("content_id", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.func.now()),
    )


def downgrade() -> None:
    op.drop_table("share_receipts")
