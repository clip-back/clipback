from datetime import datetime
from enum import StrEnum

from sqlalchemy import DateTime, Enum, ForeignKey, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class ContentSource(StrEnum):
    INSTAGRAM = "instagram"
    YOUTUBE = "youtube"
    TIKTOK = "tiktok"
    SCREENSHOT = "screenshot"
    WEB = "web"
    UNKNOWN = "unknown"


class ContentType(StrEnum):
    LINK = "link"
    SCREENSHOT = "screenshot"


class Content(Base):
    __tablename__ = "contents"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    category_id: Mapped[int] = mapped_column(ForeignKey("categories.id"), index=True)
    content_type: Mapped[ContentType] = mapped_column(Enum(ContentType), index=True)
    source: Mapped[ContentSource] = mapped_column(Enum(ContentSource), default=ContentSource.UNKNOWN)
    title: Mapped[str] = mapped_column(String(120))
    summary: Mapped[str] = mapped_column(Text)
    original_url: Mapped[str | None] = mapped_column(String(2048), nullable=True)
    saved_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    last_viewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    user = relationship("User", back_populates="contents")
    category = relationship("Category", back_populates="contents")
    assets = relationship("ContentAsset", back_populates="content", cascade="all, delete-orphan")
    events = relationship("ContentEvent", back_populates="content", cascade="all, delete-orphan")
    tags = relationship("Tag", secondary="content_tags", back_populates="contents")

