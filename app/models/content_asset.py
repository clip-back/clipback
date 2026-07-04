from datetime import datetime
from enum import StrEnum

from sqlalchemy import DateTime, Enum, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class AssetType(StrEnum):
    SCREENSHOT = "screenshot"
    THUMBNAIL = "thumbnail"
    OCR_TEXT = "ocr_text"


class ContentAsset(Base):
    __tablename__ = "content_assets"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    content_id: Mapped[int] = mapped_column(ForeignKey("contents.id"), index=True)
    asset_type: Mapped[AssetType] = mapped_column(Enum(AssetType))
    storage_key: Mapped[str] = mapped_column(String(512))
    mime_type: Mapped[str | None] = mapped_column(String(120), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    content = relationship("Content", back_populates="assets")

