"""retain category submission results independently of current categories

Revision ID: 202610250015
Revises: 202610120014
"""

import sqlalchemy as sa
from alembic import op

revision = "202610250015"
down_revision = "202610120014"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "category_submissions",
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"),
                  primary_key=True),
        sa.Column("key", sa.Uuid(), primary_key=True),
        sa.Column("kind", sa.String(16), nullable=False),
        sa.Column("target_id", sa.Integer(), nullable=True),
        sa.Column("fingerprint", sa.String(64), nullable=False),
        sa.Column("status", sa.String(16), nullable=False),
        sa.Column("status_code", sa.Integer(), nullable=False),
        sa.Column("result", sa.JSON(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.func.now()),
    )


def downgrade() -> None:
    op.drop_table("category_submissions")
