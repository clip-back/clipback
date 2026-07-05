"""create initial tables

Revision ID: 202607050001
Revises:
Create Date: 2026-07-05 00:00:00.000000
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


revision: str = "202607050001"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


content_type_enum = sa.Enum(
    "link",
    "screenshot",
    name="content_type",
    native_enum=False,
    create_constraint=True,
)
content_source_enum = sa.Enum(
    "instagram",
    "youtube",
    "tiktok",
    "screenshot",
    "web",
    "unknown",
    name="content_source",
    native_enum=False,
    create_constraint=True,
)
asset_type_enum = sa.Enum(
    "screenshot",
    "thumbnail",
    "ocr_text",
    name="asset_type",
    native_enum=False,
    create_constraint=True,
)
content_event_type_enum = sa.Enum(
    "content_created",
    "content_reopened",
    "category_filter_used",
    "card_clicked",
    "original_link_opened",
    name="content_event_type",
    native_enum=False,
    create_constraint=True,
)


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("email", sa.String(length=255), nullable=True),
        sa.Column("display_name", sa.String(length=80), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("email"),
    )
    op.create_index(op.f("ix_users_id"), "users", ["id"], unique=False)

    op.create_table(
        "categories",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=True),
        sa.Column("name", sa.String(length=40), nullable=False),
        sa.Column("color", sa.String(length=20), nullable=True),
        sa.Column("is_default", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "name", name="uq_categories_user_id_name"),
    )
    op.create_index(op.f("ix_categories_id"), "categories", ["id"], unique=False)
    op.create_index(op.f("ix_categories_name"), "categories", ["name"], unique=False)
    op.create_index(op.f("ix_categories_user_id"), "categories", ["user_id"], unique=False)

    op.create_table(
        "tags",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=40), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_tags_id"), "tags", ["id"], unique=False)
    op.create_index(op.f("ix_tags_name"), "tags", ["name"], unique=True)

    op.create_table(
        "contents",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("category_id", sa.Integer(), nullable=False),
        sa.Column("content_type", content_type_enum, nullable=False),
        sa.Column("source", content_source_enum, nullable=False),
        sa.Column("title", sa.String(length=120), nullable=False),
        sa.Column("summary", sa.Text(), nullable=False),
        sa.Column("original_url", sa.String(length=2048), nullable=True),
        sa.Column("is_favorite", sa.Boolean(), server_default=sa.false(), nullable=False),
        sa.Column("saved_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("last_viewed_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["category_id"], ["categories.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_contents_category_id"), "contents", ["category_id"], unique=False)
    op.create_index(op.f("ix_contents_content_type"), "contents", ["content_type"], unique=False)
    op.create_index(op.f("ix_contents_id"), "contents", ["id"], unique=False)
    op.create_index(op.f("ix_contents_is_favorite"), "contents", ["is_favorite"], unique=False)
    op.create_index(op.f("ix_contents_user_id"), "contents", ["user_id"], unique=False)

    op.create_table(
        "content_assets",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("content_id", sa.Integer(), nullable=False),
        sa.Column("asset_type", asset_type_enum, nullable=False),
        sa.Column("storage_key", sa.String(length=512), nullable=False),
        sa.Column("mime_type", sa.String(length=120), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["content_id"], ["contents.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_content_assets_content_id"), "content_assets", ["content_id"], unique=False)
    op.create_index(op.f("ix_content_assets_id"), "content_assets", ["id"], unique=False)

    op.create_table(
        "content_events",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("content_id", sa.Integer(), nullable=True),
        sa.Column("event_type", content_event_type_enum, nullable=False),
        sa.Column("metadata_json", sa.String(length=1000), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["content_id"], ["contents.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_content_events_content_id"), "content_events", ["content_id"], unique=False)
    op.create_index(op.f("ix_content_events_event_type"), "content_events", ["event_type"], unique=False)
    op.create_index(op.f("ix_content_events_id"), "content_events", ["id"], unique=False)
    op.create_index(op.f("ix_content_events_user_id"), "content_events", ["user_id"], unique=False)

    op.create_table(
        "content_tags",
        sa.Column("content_id", sa.Integer(), nullable=False),
        sa.Column("tag_id", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(["content_id"], ["contents.id"]),
        sa.ForeignKeyConstraint(["tag_id"], ["tags.id"]),
        sa.PrimaryKeyConstraint("content_id", "tag_id"),
    )


def downgrade() -> None:
    op.drop_table("content_tags")

    op.drop_index(op.f("ix_content_events_user_id"), table_name="content_events")
    op.drop_index(op.f("ix_content_events_id"), table_name="content_events")
    op.drop_index(op.f("ix_content_events_event_type"), table_name="content_events")
    op.drop_index(op.f("ix_content_events_content_id"), table_name="content_events")
    op.drop_table("content_events")

    op.drop_index(op.f("ix_content_assets_id"), table_name="content_assets")
    op.drop_index(op.f("ix_content_assets_content_id"), table_name="content_assets")
    op.drop_table("content_assets")

    op.drop_index(op.f("ix_contents_user_id"), table_name="contents")
    op.drop_index(op.f("ix_contents_is_favorite"), table_name="contents")
    op.drop_index(op.f("ix_contents_id"), table_name="contents")
    op.drop_index(op.f("ix_contents_content_type"), table_name="contents")
    op.drop_index(op.f("ix_contents_category_id"), table_name="contents")
    op.drop_table("contents")

    op.drop_index(op.f("ix_tags_name"), table_name="tags")
    op.drop_index(op.f("ix_tags_id"), table_name="tags")
    op.drop_table("tags")

    op.drop_index(op.f("ix_categories_user_id"), table_name="categories")
    op.drop_index(op.f("ix_categories_name"), table_name="categories")
    op.drop_index(op.f("ix_categories_id"), table_name="categories")
    op.drop_table("categories")

    op.drop_index(op.f("ix_users_id"), table_name="users")
    op.drop_table("users")
