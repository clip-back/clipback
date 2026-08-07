"""seed default categories

Revision ID: 202607050002
Revises: 202607050001
Create Date: 2026-07-05 00:00:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "202607050002"
down_revision: str | None = "202607050001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


default_categories = sa.table(
    "categories",
    sa.column("user_id", sa.Integer()),
    sa.column("name", sa.String()),
    sa.column("color", sa.String()),
    sa.column("is_default", sa.Boolean()),
)

DEFAULT_CATEGORIES = [
    {"user_id": None, "name": "취업", "color": "#4F46E5", "is_default": True},
    {"user_id": None, "name": "공부", "color": "#059669", "is_default": True},
    {"user_id": None, "name": "업무 팁", "color": "#DC2626", "is_default": True},
    {"user_id": None, "name": "생활 꿀팁", "color": "#D97706", "is_default": True},
    {"user_id": None, "name": "장소", "color": "#0891B2", "is_default": True},
    {"user_id": None, "name": "제품 추천", "color": "#7C3AED", "is_default": True},
]


def upgrade() -> None:
    op.bulk_insert(default_categories, DEFAULT_CATEGORIES)


def downgrade() -> None:
    op.execute(
        default_categories.delete().where(
            default_categories.c.user_id.is_(None),
            default_categories.c.is_default.is_(True),
            default_categories.c.name.in_([category["name"] for category in DEFAULT_CATEGORIES]),
        )
    )
