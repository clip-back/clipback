from datetime import datetime
from enum import StrEnum

from sqlalchemy import DateTime, Enum, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class ContentEventType(StrEnum):
    CONTENT_CREATED = "content_created"
    CONTENT_REOPENED = "content_reopened"
    CATEGORY_FILTER_USED = "category_filter_used"
    ORIGINAL_LINK_OPENED = "original_link_opened"


class ContentEvent(Base):
    __tablename__ = "content_events"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    content_id: Mapped[int | None] = mapped_column(ForeignKey("contents.id"), nullable=True, index=True)
    event_type: Mapped[ContentEventType] = mapped_column(Enum(ContentEventType), index=True)
    metadata_json: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    content = relationship("Content", back_populates="events")

