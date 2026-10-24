from datetime import date, datetime

from sqlalchemy import BigInteger, Boolean, CheckConstraint, Date, DateTime, String, false, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class ImageStorageControl(Base):
    __tablename__ = "image_storage_control"
    __table_args__ = (CheckConstraint("id = 1", name="ck_image_storage_control_singleton"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    uploads_paused: Mapped[bool] = mapped_column(Boolean, server_default=false())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class ImageTransferCounter(Base):
    __tablename__ = "image_transfer_counters"

    day: Mapped[date] = mapped_column(Date, primary_key=True)
    kind: Mapped[str] = mapped_column(String(32), primary_key=True)
    operations: Mapped[int] = mapped_column(BigInteger, server_default="0")
    size_bytes: Mapped[int] = mapped_column(BigInteger, server_default="0")
