from datetime import datetime

from sqlalchemy import JSON, Boolean, DateTime, Integer, String, false
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class ImageDeletion(Base):
    """Outlives deleted content and users; independently durable intent also lives in the ledger."""

    __tablename__ = "image_deletions"

    operation_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    user_id: Mapped[int] = mapped_column(Integer, index=True)
    content_id: Mapped[int] = mapped_column(Integer, index=True)
    intent: Mapped[dict] = mapped_column(JSON)
    deleted_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    completed: Mapped[bool] = mapped_column(Boolean, default=False, server_default=false())
    attempts: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    last_error: Mapped[str | None] = mapped_column(String(64), nullable=True)
