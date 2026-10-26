"""Persist global maintenance and admitted operations without resetting business data."""

import sqlalchemy as sa
from alembic import op

revision = "202610260020"
down_revision = "202610250019"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "maintenance_state",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("phase", sa.String(16), nullable=False),
        sa.Column("run_id", sa.String(36)),
        sa.Column("generation", sa.Integer(), nullable=False),
        sa.Column("drain_deadline", sa.DateTime(timezone=True)),
        sa.Column("result", sa.String(32)),
    )
    op.execute("INSERT INTO maintenance_state(id,phase,generation) VALUES (1,'open',0)")
    op.create_table(
        "maintenance_operations",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("kind", sa.String(32), nullable=False),
        sa.Column("executor", sa.String(160), nullable=False),
        sa.Column("run_id", sa.String(36)),
        sa.Column("generation", sa.Integer()),
        sa.Column("registered_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_table(
        "maintenance_events",
        sa.Column("id", sa.BigInteger(), primary_key=True, autoincrement=True),
        sa.Column("action", sa.String(32), nullable=False),
        sa.Column("run_id", sa.String(36)),
        sa.Column("operation_id", sa.String(36)),
        sa.Column("recorded_at", sa.DateTime(timezone=True), nullable=False),
    )


def downgrade():
    op.drop_table("maintenance_events")
    op.drop_table("maintenance_operations")
    op.drop_table("maintenance_state")
