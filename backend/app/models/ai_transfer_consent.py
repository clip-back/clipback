from datetime import datetime

from sqlalchemy import Boolean, CheckConstraint, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class AITransferConsent(Base):
    """An account's AI 전송 동의. No row means undecided; withdrawal overwrites it as denied."""

    __tablename__ = "ai_transfer_consents"
    __table_args__ = (
        CheckConstraint("status IN ('granted', 'denied')", name="ai_consent_status"),
        CheckConstraint("notice_version = 1", name="ai_consent_notice_version"),
    )

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True,
    )
    status: Mapped[str] = mapped_column(String(16))
    notice_version: Mapped[int] = mapped_column(Integer)
    decided_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    # True only for a grant that replaced a denial (재동의).
    granted_after_denial: Mapped[bool] = mapped_column(Boolean)
