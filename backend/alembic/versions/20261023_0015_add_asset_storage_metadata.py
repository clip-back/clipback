"""Keep original image storage location and integrity metadata.

Revision ID: 202610230015
Revises: 202610120014
"""

import sqlalchemy as sa
from alembic import op

revision = "202610230015"
down_revision = "202610120014"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("content_assets", sa.Column(
        "storage_backend", sa.String(16), nullable=False, server_default="local",
    ))
    op.add_column("content_assets", sa.Column("size_bytes", sa.BigInteger(), nullable=True))
    op.add_column("content_assets", sa.Column("sha256", sa.String(64), nullable=True))
    op.create_check_constraint(
        "asset_storage_backend", "content_assets", "storage_backend IN ('local', 's3')",
    )
    op.create_check_constraint(
        "asset_size_bytes", "content_assets", "size_bytes IS NULL OR size_bytes >= 0",
    )


def downgrade() -> None:
    op.drop_constraint("asset_size_bytes", "content_assets", type_="check")
    op.drop_constraint("asset_storage_backend", "content_assets", type_="check")
    op.drop_column("content_assets", "sha256")
    op.drop_column("content_assets", "size_bytes")
    op.drop_column("content_assets", "storage_backend")
