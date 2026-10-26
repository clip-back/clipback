"""Durable maintenance control records; not application business data."""

from datetime import datetime

from sqlalchemy import BigInteger, DateTime, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class MaintenanceState(Base):
    __tablename__ = "maintenance_state"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    phase: Mapped[str] = mapped_column(String(16), nullable=False)
    run_id: Mapped[str | None] = mapped_column(String(36))
    generation: Mapped[int] = mapped_column(Integer, nullable=False)
    drain_deadline: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    result: Mapped[str | None] = mapped_column(String(32))


class MaintenanceOperation(Base):
    __tablename__ = "maintenance_operations"
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    kind: Mapped[str] = mapped_column(String(32), nullable=False)
    executor: Mapped[str] = mapped_column(String(160), nullable=False)
    run_id: Mapped[str | None] = mapped_column(String(36))
    generation: Mapped[int | None] = mapped_column(Integer)
    registered_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class MaintenanceEvent(Base):
    __tablename__ = "maintenance_events"
    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    action: Mapped[str] = mapped_column(String(32), nullable=False)
    run_id: Mapped[str | None] = mapped_column(String(36))
    operation_id: Mapped[str | None] = mapped_column(String(36))
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
