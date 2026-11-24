"""Store AI 전송 동의 and allow its screenshot skip reason.

Revision ID: 202611250027
Revises: 202611230026
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "202611250027"
down_revision: str | None = "202611230026"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

SKIP_REASON = "ck_contents_screenshot_summary_skip_reason"


def upgrade() -> None:
    op.create_table(
        "ai_transfer_consents",
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"),
                  primary_key=True),
        sa.Column("status", sa.String(16), nullable=False),
        sa.Column("notice_version", sa.Integer(), nullable=False),
        sa.Column("decided_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("granted_after_denial", sa.Boolean(), nullable=False),
        sa.CheckConstraint("status IN ('granted', 'denied')", name="ai_consent_status"),
        sa.CheckConstraint("notice_version = 1", name="ai_consent_notice_version"),
    )
    op.drop_constraint(SKIP_REASON, "contents", type_="check")
    op.create_check_constraint(
        SKIP_REASON,
        "contents",
        "screenshot_summary_skip_reason IS NULL OR "
        "(content_type = 'screenshot' AND "
        "screenshot_summary_skip_reason IN ('monthly_limit_exceeded', 'ai_consent_required'))",
    )


def downgrade() -> None:
    # An older server would process AI for accounts that declined (#474). Roll forward instead.
    raise RuntimeError("Revision 202611250027 cannot be downgraded; deploy a fix forward.")
