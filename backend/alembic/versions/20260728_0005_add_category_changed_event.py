"""add category changed event

Revision ID: 202607280005
Revises: 202607170004
Create Date: 2026-07-28 00:00:00.000000
"""

from collections.abc import Sequence

from alembic import op


revision: str = "202607280005"
down_revision: str | None = "202607170004"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


OLD_EVENT_TYPES = (
    "content_created",
    "content_reopened",
    "category_filter_used",
    "card_clicked",
    "original_link_opened",
)
NEW_EVENT_TYPES = (
    "content_created",
    "content_reopened",
    "category_changed",
    "category_filter_used",
    "card_clicked",
    "original_link_opened",
)


def _event_type_constraint(values: tuple[str, ...]) -> str:
    quoted_values = ", ".join(f"'{value}'" for value in values)
    return f"event_type IN ({quoted_values})"


def upgrade() -> None:
    op.drop_constraint("content_event_type", "content_events", type_="check")
    op.create_check_constraint(
        "content_event_type",
        "content_events",
        _event_type_constraint(NEW_EVENT_TYPES),
    )


def downgrade() -> None:
    op.execute("DELETE FROM content_events WHERE event_type = 'category_changed'")
    op.drop_constraint("content_event_type", "content_events", type_="check")
    op.create_check_constraint(
        "content_event_type",
        "content_events",
        _event_type_constraint(OLD_EVENT_TYPES),
    )
