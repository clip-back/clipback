"""Retain image deletion retries independently of content rows."""

import sqlalchemy as sa
from alembic import op

revision = "202610230017"
down_revision = "202610230015"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "image_deletions",
        sa.Column("operation_id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("content_id", sa.Integer(), nullable=False),
        sa.Column("intent", sa.JSON(), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("completed", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("attempts", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("last_error", sa.String(64), nullable=True),
    )
    op.create_index("ix_image_deletions_user_id", "image_deletions", ["user_id"])
    op.create_index("ix_image_deletions_content_id", "image_deletions", ["content_id"])


def downgrade():
    op.drop_table("image_deletions")
