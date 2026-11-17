"""Align default category colors with the app palette.

Revision ID: 202611170023
Revises: 202611060022
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "202611170023"
down_revision: str | None = "202611060022"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

COLOR_CHANGES = (
    ("업무 팁", "#DC2626", "#FF6277"),
    ("생활 꿀팁", "#D97706", "#FFA24B"),
    ("공부", "#059669", "#5BD89D"),
    ("취업", "#4F46E5", "#64B5F6"),
    ("제품 추천", "#7C3AED", "#B9AAFF"),
    ("장소", "#0891B2", "#FFD75C"),
)


def _replace_colors(*, reverse: bool) -> None:
    for name, old_color, new_color in COLOR_CHANGES:
        if reverse:
            old_color, new_color = new_color, old_color
        op.execute(sa.text("""
            UPDATE categories SET color = :new_color
            WHERE is_default = true AND name = :name AND lower(color) = lower(:old_color)
        """).bindparams(name=name, old_color=old_color, new_color=new_color))


def upgrade() -> None:
    _replace_colors(reverse=False)


def downgrade() -> None:
    # A user who deliberately chose the same new palette color is indistinguishable
    # from a migrated row and is also reverted. No selection history is available.
    _replace_colors(reverse=True)
