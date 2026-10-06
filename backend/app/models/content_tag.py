from sqlalchemy import Column, ForeignKey, Index, Table

from app.db.base import Base

content_tags = Table(
    "content_tags",
    Base.metadata,
    Column("content_id", ForeignKey("contents.id", ondelete="CASCADE"), primary_key=True),
    Column("tag_id", ForeignKey("tags.id", ondelete="CASCADE"), primary_key=True),
    Index("ix_content_tags_tag_id", "tag_id"),
)
