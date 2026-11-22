from datetime import datetime

from sqlalchemy import BigInteger, CheckConstraint, DateTime, ForeignKey, Index, String, text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class UsageRecord(Base):
    __tablename__ = "usage_records"
    __table_args__ = (
        CheckConstraint("kind IN ('ai_summary', 'category_recommendation')", name="usage_kind"),
        Index("ix_usage_records_user_period", "user_id", "recorded_at", "kind"),
        Index(
            "uq_usage_records_summary_content", "content_id", unique=True,
            postgresql_where=text("kind = 'ai_summary' AND content_id IS NOT NULL"),
        ),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    kind: Mapped[str] = mapped_column(String(24))
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    content_id: Mapped[int | None] = mapped_column(
        ForeignKey("contents.id", ondelete="SET NULL"), index=True,
    )
