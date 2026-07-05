from sqlalchemy import Column, ForeignKey, Index, Table

from app.db.base import Base

content_categories = Table(
    "content_categories",
    Base.metadata,
    Column("content_id", ForeignKey("contents.id", ondelete="CASCADE"), primary_key=True),
    Column("category_id", ForeignKey("categories.id", ondelete="RESTRICT"), primary_key=True),
    Index("ix_content_categories_category_id", "category_id"),
)
