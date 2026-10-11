"""add Apple login challenges and encrypted provider credentials

Revision ID: 202610110013
Revises: 202609240012
"""

import sqlalchemy as sa
from alembic import op

revision = "202610110013"
down_revision = "202609240012"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Naver values remain readable for historical accounts; new auth is disabled in the API.
    op.drop_constraint("social_provider", "social_identities", type_="check")
    op.create_check_constraint(
        "social_provider", "social_identities", "provider IN ('google', 'naver', 'kakao', 'apple')"
    )
    op.create_table(
        "apple_auth_challenges",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("nonce_hash", sa.String(64), nullable=False),
        sa.Column("purpose", sa.String(7), nullable=False),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE")),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("consumed_at", sa.DateTime(timezone=True)),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint("purpose IN ('login', 'upgrade')", name="apple_challenge_purpose"),
        sa.CheckConstraint(
            "(purpose = 'login' AND user_id IS NULL) OR "
            "(purpose = 'upgrade' AND user_id IS NOT NULL)",
            name="apple_challenge_user_binding",
        ),
    )
    op.create_index("ix_apple_auth_challenges_expires_at", "apple_auth_challenges", ["expires_at"])
    op.create_table(
        "apple_credentials",
        sa.Column(
            "social_identity_id",
            sa.Integer(),
            sa.ForeignKey("social_identities.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column("client_id", sa.String(255), nullable=False),
        sa.Column("refresh_token_encrypted", sa.Text()),
        sa.Column("last_verified_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True)),
    )


def downgrade() -> None:
    # Removing Apple identities would silently orphan accounts. Restore a compatible backup instead.
    if op.get_bind().scalar(
        sa.text("SELECT EXISTS (SELECT 1 FROM social_identities WHERE provider = 'apple')")
    ):
        raise RuntimeError("Cannot remove Apple authentication while Apple identities exist")
    op.drop_table("apple_credentials")
    op.drop_index("ix_apple_auth_challenges_expires_at", table_name="apple_auth_challenges")
    op.drop_table("apple_auth_challenges")
    op.drop_constraint("social_provider", "social_identities", type_="check")
    op.create_check_constraint(
        "social_provider", "social_identities", "provider IN ('google', 'naver', 'kakao')"
    )
