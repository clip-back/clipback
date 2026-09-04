"""add content delete rules

Revision ID: 202609030009
Revises: 202609030008
Create Date: 2026-09-03 00:00:00.000000
"""

from collections.abc import Sequence

from alembic import op

revision: str = "202609030009"
down_revision: str | None = "202609030008"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.drop_constraint(
        "content_assets_content_id_fkey",
        "content_assets",
        type_="foreignkey",
    )
    op.create_foreign_key(
        "content_assets_content_id_fkey",
        "content_assets",
        "contents",
        ["content_id"],
        ["id"],
        ondelete="CASCADE",
    )

    op.drop_constraint(
        "content_events_content_id_fkey",
        "content_events",
        type_="foreignkey",
    )
    op.create_foreign_key(
        "content_events_content_id_fkey",
        "content_events",
        "contents",
        ["content_id"],
        ["id"],
        ondelete="SET NULL",
    )


def downgrade() -> None:
    op.drop_constraint(
        "content_events_content_id_fkey",
        "content_events",
        type_="foreignkey",
    )
    op.create_foreign_key(
        "content_events_content_id_fkey",
        "content_events",
        "contents",
        ["content_id"],
        ["id"],
    )

    op.drop_constraint(
        "content_assets_content_id_fkey",
        "content_assets",
        type_="foreignkey",
    )
    op.create_foreign_key(
        "content_assets_content_id_fkey",
        "content_assets",
        "contents",
        ["content_id"],
        ["id"],
    )
