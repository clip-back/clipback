"""add category to content events

Revision ID: 202608070006
Revises: 202607280005
Create Date: 2026-08-07 00:00:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "202608070006"
down_revision: str | None = "202607280005"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "content_events",
        sa.Column("category_id", sa.Integer(), nullable=True),
    )
    op.create_foreign_key(
        "content_events_category_id_fkey",
        "content_events",
        "categories",
        ["category_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_index(
        op.f("ix_content_events_category_id"),
        "content_events",
        ["category_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_content_events_category_id"), table_name="content_events")
    op.drop_constraint(
        "content_events_category_id_fkey",
        "content_events",
        type_="foreignkey",
    )
    op.drop_column("content_events", "category_id")
