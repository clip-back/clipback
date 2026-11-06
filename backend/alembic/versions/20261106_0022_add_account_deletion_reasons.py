"""Keep account deletion reasons as unlinked statistics: reasons and a Korea date only."""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "202611060022"
down_revision = "202610310021"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "account_deletion_reasons",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("reasons", postgresql.ARRAY(sa.String(32)), nullable=False),
        sa.Column("deleted_on", sa.Date(), nullable=False),
    )


def downgrade():
    op.drop_table("account_deletion_reasons")
