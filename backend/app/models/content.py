from datetime import datetime
from enum import StrEnum

from sqlalchemy import Boolean, DateTime, Enum, ForeignKey, String, Text, false, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.db.types import enum_values
from app.models.content_category import content_categories
from app.models.content_tag import content_tags


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
    content_type: Mapped[ContentType] = mapped_column(
        Enum(
            ContentType,
            values_callable=enum_values,
            native_enum=False,
            create_constraint=True,
            name="content_type",
        ),
        index=True,
    )
    source: Mapped[ContentSource] = mapped_column(
        Enum(
            ContentSource,
            values_callable=enum_values,
            native_enum=False,
            create_constraint=True,
            name="content_source",
        ),
        default=ContentSource.UNKNOWN,
    )
    title: Mapped[str] = mapped_column(String(120))
    summary: Mapped[str] = mapped_column(Text)
    original_url: Mapped[str | None] = mapped_column(String(2048), nullable=True)
    is_favorite: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        server_default=false(),
        index=True,
    )
    saved_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    last_viewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    user = relationship("User", back_populates="contents")
    categories = relationship("Category", secondary=content_categories, back_populates="contents")
    tags = relationship("Tag", secondary=content_tags, back_populates="contents")
    assets = relationship(
        "ContentAsset",
        back_populates="content",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    events = relationship(
        "ContentEvent",
        back_populates="content",
        passive_deletes=True,
    )
