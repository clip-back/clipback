from sqlalchemy import ForeignKey, String, Table, Column
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

content_tags = Table(
    "content_tags",
    Base.metadata,
    Column("content_id", ForeignKey("contents.id"), primary_key=True),
    Column("tag_id", ForeignKey("tags.id"), primary_key=True),
)


class Tag(Base):
    __tablename__ = "tags"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String(40), unique=True, index=True)

    contents = relationship("Content", secondary=content_tags, back_populates="tags")

