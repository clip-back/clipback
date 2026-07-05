"""use categories for content classification

Revision ID: 202607050003
Revises: 202607050002
Create Date: 2026-07-05 00:00:00.000000
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


revision: str = "202607050003"
down_revision: str | None = "202607050002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


content_categories = sa.table(
    "content_categories",
    sa.column("content_id", sa.Integer()),
    sa.column("category_id", sa.Integer()),
)
categories = sa.table(
    "categories",
    sa.column("id", sa.Integer()),
    sa.column("user_id", sa.Integer()),
    sa.column("name", sa.String()),
    sa.column("color", sa.String()),
    sa.column("is_default", sa.Boolean()),
)

UNCATEGORIZED_CATEGORY = {
    "user_id": None,
    "name": "미분류",
    "color": "#6B7280",
    "is_default": True,
}


def upgrade() -> None:
    op.create_table(
        "content_categories",
        sa.Column("content_id", sa.Integer(), nullable=False),
        sa.Column("category_id", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(["category_id"], ["categories.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["content_id"], ["contents.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("content_id", "category_id"),
    )
    op.create_index(
        op.f("ix_content_categories_category_id"),
        "content_categories",
        ["category_id"],
        unique=False,
    )

    op.bulk_insert(categories, [UNCATEGORIZED_CATEGORY])

    op.execute(
        """
        INSERT INTO content_categories (content_id, category_id)
        SELECT id, category_id
        FROM contents
        """
    )

    op.drop_table("content_tags")

    op.drop_index(op.f("ix_tags_name"), table_name="tags")
    op.drop_index(op.f("ix_tags_id"), table_name="tags")
    op.drop_table("tags")

    op.drop_index(op.f("ix_contents_category_id"), table_name="contents")
    op.drop_constraint("contents_category_id_fkey", "contents", type_="foreignkey")
    op.drop_column("contents", "category_id")


def downgrade() -> None:
    op.add_column("contents", sa.Column("category_id", sa.Integer(), nullable=True))

    op.execute(
        """
        UPDATE contents
        SET category_id = selected_categories.category_id
        FROM (
            SELECT DISTINCT ON (content_id)
                   content_id,
                   category_id
            FROM content_categories
            ORDER BY content_id, category_id
        ) AS selected_categories
        WHERE contents.id = selected_categories.content_id
        """
    )
    op.execute(
        """
        UPDATE contents
        SET category_id = (
            SELECT id
            FROM categories
            WHERE user_id IS NULL
              AND name = '미분류'
            ORDER BY id
            LIMIT 1
        )
        WHERE category_id IS NULL
        """
    )

    op.alter_column("contents", "category_id", nullable=False)
    op.create_foreign_key(
        "contents_category_id_fkey",
        "contents",
        "categories",
        ["category_id"],
        ["id"],
    )
    op.create_index(op.f("ix_contents_category_id"), "contents", ["category_id"], unique=False)

    op.create_table(
        "tags",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=40), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_tags_id"), "tags", ["id"], unique=False)
    op.create_index(op.f("ix_tags_name"), "tags", ["name"], unique=True)

    op.create_table(
        "content_tags",
        sa.Column("content_id", sa.Integer(), nullable=False),
        sa.Column("tag_id", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(["content_id"], ["contents.id"]),
        sa.ForeignKeyConstraint(["tag_id"], ["tags.id"]),
        sa.PrimaryKeyConstraint("content_id", "tag_id"),
    )

    op.execute(
        """
        DELETE FROM categories
        WHERE user_id IS NULL
          AND name = '미분류'
          AND is_default IS TRUE
          AND NOT EXISTS (
              SELECT 1
              FROM contents
              WHERE contents.category_id = categories.id
          )
        """
    )
    op.drop_index(op.f("ix_content_categories_category_id"), table_name="content_categories")
    op.drop_table("content_categories")
