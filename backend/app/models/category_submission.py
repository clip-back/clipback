from datetime import datetime
from uuid import UUID

from sqlalchemy import JSON, DateTime, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class CategorySubmission(Base):
    __tablename__ = "category_submissions"

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True,
    )
    key: Mapped[UUID] = mapped_column(primary_key=True)
    kind: Mapped[str] = mapped_column(String(16))
    # No category FK: a completed submission remains valid after category deletion.
    target_id: Mapped[int | None] = mapped_column()
    fingerprint: Mapped[str] = mapped_column(String(64))
    status: Mapped[str] = mapped_column(String(16))
    status_code: Mapped[int] = mapped_column()
    result: Mapped[dict] = mapped_column(JSON)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
