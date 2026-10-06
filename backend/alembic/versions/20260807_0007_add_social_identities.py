"""add social identities

Revision ID: 202608070007
Revises: 202608070006
Create Date: 2026-08-07 00:00:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "202608070007"
down_revision: str | None = "202608070006"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

social_provider_enum = sa.Enum(
    "google",
    "naver",
    "kakao",
    name="social_provider",
    native_enum=False,
    create_constraint=True,
)


def upgrade() -> None:
    op.drop_constraint("users_email_key", "users", type_="unique")
    op.create_table(
        "social_identities",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("provider", social_provider_enum, nullable=False),
        sa.Column("provider_subject", sa.String(length=255), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "provider",
            "provider_subject",
            name="uq_social_identities_provider_subject",
        ),
        sa.UniqueConstraint(
            "user_id",
            "provider",
            name="uq_social_identities_user_provider",
        ),
    )
    op.create_index(
        op.f("ix_social_identities_id"),
        "social_identities",
        ["id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_social_identities_user_id"),
        "social_identities",
        ["user_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_social_identities_user_id"), table_name="social_identities")
    op.drop_index(op.f("ix_social_identities_id"), table_name="social_identities")
    op.drop_table("social_identities")
    op.create_unique_constraint("users_email_key", "users", ["email"])
