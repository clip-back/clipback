"""Persist operator image admission and anonymous daily transfer observations."""

import sqlalchemy as sa
from alembic import op

revision = "202610230018"
down_revision = "202610230017"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "image_storage_control",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("uploads_paused", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
        sa.CheckConstraint("id = 1", name="ck_image_storage_control_singleton"),
    )
    op.create_table(
        "image_transfer_counters",
        sa.Column("day", sa.Date(), primary_key=True),
        sa.Column("kind", sa.String(32), primary_key=True),
        sa.Column("operations", sa.BigInteger(), nullable=False, server_default="0"),
        sa.Column("size_bytes", sa.BigInteger(), nullable=False, server_default="0"),
    )


def downgrade():
    op.drop_table("image_transfer_counters")
    op.drop_table("image_storage_control")
