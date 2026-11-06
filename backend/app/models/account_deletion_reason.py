from datetime import date

from sqlalchemy import Date, Integer, String
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class AccountDeletionReason(Base):
    """Chosen reasons and the Korea date of one deletion; never linked to an account (D18)."""

    __tablename__ = "account_deletion_reasons"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    reasons: Mapped[list[str]] = mapped_column(ARRAY(String(32)))
    deleted_on: Mapped[date] = mapped_column(Date)
