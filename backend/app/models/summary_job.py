from datetime import datetime

from sqlalchemy import JSON, Boolean, DateTime, ForeignKey, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class SummaryJob(Base):
    __tablename__ = "summary_jobs"

    content_id: Mapped[int] = mapped_column(
        ForeignKey("contents.id", ondelete="CASCADE"), primary_key=True
    )
    video_id: Mapped[str] = mapped_column(String(11))
    status: Mapped[str] = mapped_column(String(20), index=True)
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    next_run_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    lease_expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    lease_token: Mapped[str | None] = mapped_column(String(36))
    error_code: Mapped[str | None] = mapped_column(String(40))
    model: Mapped[str] = mapped_column(String(120))
    usage: Mapped[list] = mapped_column(JSON, default=list)
    apply_title: Mapped[bool] = mapped_column(Boolean)
    apply_summary: Mapped[bool] = mapped_column(Boolean)
    apply_category: Mapped[bool] = mapped_column(Boolean)
