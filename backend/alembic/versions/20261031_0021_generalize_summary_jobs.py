"""Let summary jobs carry a kind and a kind-specific target identifier."""

import sqlalchemy as sa
from alembic import op

revision = "202610310021"
down_revision = "202610260020"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        "summary_jobs",
        sa.Column("kind", sa.String(20), nullable=False, server_default="youtube"),
    )
    op.alter_column("summary_jobs", "kind", server_default=None)
    op.alter_column(
        "summary_jobs",
        "video_id",
        new_column_name="target_id",
        existing_type=sa.String(11),
        type_=sa.String(2048),
        existing_nullable=False,
    )


def downgrade():
    # Only YouTube jobs fit the 11-character video id column.
    op.execute("DELETE FROM summary_jobs WHERE kind <> 'youtube'")
    op.alter_column(
        "summary_jobs",
        "target_id",
        new_column_name="video_id",
        existing_type=sa.String(2048),
        type_=sa.String(11),
        existing_nullable=False,
    )
    op.drop_column("summary_jobs", "kind")
