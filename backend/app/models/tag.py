from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.content_tag import content_tags


class Tag(Base):
    __tablename__ = "tags"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "normalized_name",
            name="uq_tags_user_id_normalized_name",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
    )
    name: Mapped[str] = mapped_column(String(40))
    normalized_name: Mapped[str] = mapped_column(String(40))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )

    user = relationship("User", back_populates="tags")
    contents = relationship("Content", secondary=content_tags, back_populates="tags")
