from datetime import datetime
from enum import StrEnum
from uuid import UUID

from sqlalchemy import (
    DateTime,
    Enum,
    ForeignKey,
    Index,
    Integer,
    String,
    UniqueConstraint,
    Uuid,
    func,
)
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.db.types import enum_values


class ContentEventType(StrEnum):
    CONTENT_CREATED = "content_created"
    CONTENT_REOPENED = "content_reopened"
    CATEGORY_CHANGED = "category_changed"
    CATEGORY_FILTER_USED = "category_filter_used"
    CARD_CLICKED = "card_clicked"
    ORIGINAL_LINK_OPENED = "original_link_opened"


class ContentEvent(Base):
    __tablename__ = "content_events"
    __table_args__ = (
        UniqueConstraint("user_id", "client_event_id", name="uq_content_events_user_client_event"),
        Index("ix_content_events_user_type_time", "user_id", "event_type", "created_at"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    content_id: Mapped[int | None] = mapped_column(
        ForeignKey("contents.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    category_id: Mapped[int | None] = mapped_column(
        ForeignKey("categories.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    event_type: Mapped[ContentEventType] = mapped_column(
        Enum(
            ContentEventType,
            values_callable=enum_values,
            native_enum=False,
            create_constraint=True,
            name="content_event_type",
        ),
        index=True,
    )
    metadata_json: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    client_event_id: Mapped[UUID | None] = mapped_column(Uuid, nullable=True)
    category_ids_at_event: Mapped[list[int] | None] = mapped_column(ARRAY(Integer), nullable=True)
    recommendation_item_id: Mapped[int | None] = mapped_column(
        ForeignKey("recommendation_batch_items.id", ondelete="RESTRICT"), nullable=True, index=True
    )

    content = relationship("Content", back_populates="events")
    category = relationship("Category")
