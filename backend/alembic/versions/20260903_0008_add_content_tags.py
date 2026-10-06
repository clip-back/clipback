"""add content tags

Revision ID: 202609030008
Revises: 202608070007
Create Date: 2026-09-03 00:00:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "202609030008"
down_revision: str | None = "202608070007"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "tags",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=40), nullable=False),
        sa.Column("normalized_name", sa.String(length=40), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "user_id",
            "normalized_name",
            name="uq_tags_user_id_normalized_name",
        ),
    )
    op.create_index(op.f("ix_tags_id"), "tags", ["id"], unique=False)
    op.create_index(op.f("ix_tags_user_id"), "tags", ["user_id"], unique=False)

    op.create_table(
        "content_tags",
        sa.Column("content_id", sa.Integer(), nullable=False),
        sa.Column("tag_id", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(["content_id"], ["contents.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["tag_id"], ["tags.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("content_id", "tag_id"),
    )
    op.create_index(
        op.f("ix_content_tags_tag_id"),
        "content_tags",
        ["tag_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_content_tags_tag_id"), table_name="content_tags")
    op.drop_table("content_tags")
    op.drop_index(op.f("ix_tags_user_id"), table_name="tags")
    op.drop_index(op.f("ix_tags_id"), table_name="tags")
    op.drop_table("tags")
