from datetime import datetime
from enum import StrEnum

from sqlalchemy import BigInteger, CheckConstraint, DateTime, Enum, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.db.types import enum_values


class AssetType(StrEnum):
    SCREENSHOT = "screenshot"
    THUMBNAIL = "thumbnail"
    OCR_TEXT = "ocr_text"


class ContentAsset(Base):
    __tablename__ = "content_assets"
    __table_args__ = (
        CheckConstraint("storage_backend IN ('local', 's3')", name="asset_storage_backend"),
        CheckConstraint("size_bytes IS NULL OR size_bytes >= 0", name="asset_size_bytes"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    content_id: Mapped[int] = mapped_column(
        ForeignKey("contents.id", ondelete="CASCADE"),
        index=True,
    )
    asset_type: Mapped[AssetType] = mapped_column(
        Enum(
            AssetType,
            values_callable=enum_values,
            native_enum=False,
            create_constraint=True,
            name="asset_type",
        )
    )
    storage_key: Mapped[str] = mapped_column(String(512))
    mime_type: Mapped[str | None] = mapped_column(String(120), nullable=True)
    storage_backend: Mapped[str] = mapped_column(
        String(16), default="local", server_default="local",
    )
    size_bytes: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    sha256: Mapped[str | None] = mapped_column(String(64), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    content = relationship("Content", back_populates="assets")
