from datetime import datetime
from uuid import UUID

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, String, Text, Uuid, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class AppleAuthChallenge(Base):
    __tablename__ = "apple_auth_challenges"
    __table_args__ = (
        CheckConstraint("purpose IN ('login', 'upgrade')", name="apple_challenge_purpose"),
        CheckConstraint(
            "(purpose = 'login' AND user_id IS NULL) OR "
            "(purpose = 'upgrade' AND user_id IS NOT NULL)",
            name="apple_challenge_user_binding",
        ),
    )

    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True)
    nonce_hash: Mapped[str] = mapped_column(String(64))
    purpose: Mapped[str] = mapped_column(String(7))
    user_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=True
    )
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    consumed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class AppleCredential(Base):
    __tablename__ = "apple_credentials"

    social_identity_id: Mapped[int] = mapped_column(
        ForeignKey("social_identities.id", ondelete="CASCADE"), primary_key=True
    )
    client_id: Mapped[str] = mapped_column(String(255))
    refresh_token_encrypted: Mapped[str | None] = mapped_column(Text, nullable=True)
    last_verified_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
