from datetime import date, datetime
from enum import StrEnum
from uuid import UUID

from sqlalchemy import (
    CheckConstraint,
    Date,
    DateTime,
    Double,
    Enum,
    ForeignKey,
    Index,
    UniqueConstraint,
    Uuid,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.types import enum_values


class RecommendationType(StrEnum):
    TODAY = "TODAY"
    WEEKLY_PICK = "WEEKLY_PICK"


class RecommendationTargetKind(StrEnum):
    CONTENT = "CONTENT"
    CATEGORY = "CATEGORY"


class RecommendationCardType(StrEnum):
    MOST_SAVED = "MOST_SAVED"
    MOST_VIEWED = "MOST_VIEWED"
    REDISCOVERY = "REDISCOVERY"


class RecommendationBatch(Base):
    __tablename__ = "recommendation_batches"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "type",
            "recommendation_date",
            name="uq_recommendation_batches_user_type_date",
        ),
        CheckConstraint(
            "(type = 'TODAY' AND recommendation_date IS NOT NULL) OR "
            "(type = 'WEEKLY_PICK' AND recommendation_date IS NULL)",
            name="ck_recommendation_batches_date",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    type: Mapped[RecommendationType] = mapped_column(
        Enum(
            RecommendationType,
            values_callable=enum_values,
            native_enum=False,
            create_constraint=True,
            name="recommendation_type",
        )
    )
    recommendation_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    generated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class RecommendationBatchItem(Base):
    __tablename__ = "recommendation_batch_items"
    __table_args__ = (
        UniqueConstraint("batch_id", "rank", name="uq_recommendation_batch_items_batch_rank"),
        UniqueConstraint(
            "batch_id",
            "target_kind",
            "target_id_snapshot",
            name="uq_recommendation_batch_items_batch_target",
        ),
        CheckConstraint("rank > 0", name="ck_recommendation_batch_items_rank"),
        CheckConstraint("target_id_snapshot > 0", name="ck_recommendation_batch_items_snapshot"),
        CheckConstraint(
            "score IS NULL OR (score >= 0 AND score <= 1)",
            name="ck_recommendation_batch_items_score",
        ),
        CheckConstraint(
            "(target_kind = 'CONTENT' AND category_id IS NULL AND card_type IS NULL) OR "
            "(target_kind = 'CATEGORY' AND content_id IS NULL "
            "AND score IS NULL AND card_type IS NOT NULL)",
            name="ck_recommendation_batch_items_target",
        ),
        CheckConstraint(
            "(content_id IS NULL OR content_id = target_id_snapshot) AND "
            "(category_id IS NULL OR category_id = target_id_snapshot)",
            name="ck_recommendation_batch_items_live_target",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    batch_id: Mapped[int] = mapped_column(
        ForeignKey("recommendation_batches.id", ondelete="RESTRICT")
    )
    rank: Mapped[int]
    target_kind: Mapped[RecommendationTargetKind] = mapped_column(
        Enum(
            RecommendationTargetKind,
            values_callable=enum_values,
            native_enum=False,
            create_constraint=True,
            name="recommendation_target_kind",
        )
    )
    target_id_snapshot: Mapped[int]
    content_id: Mapped[int | None] = mapped_column(
        ForeignKey("contents.id", ondelete="SET NULL"), nullable=True, index=True
    )
    category_id: Mapped[int | None] = mapped_column(
        ForeignKey("categories.id", ondelete="SET NULL"), nullable=True, index=True
    )
    score: Mapped[float | None] = mapped_column(Double, nullable=True)
    card_type: Mapped[RecommendationCardType | None] = mapped_column(
        Enum(
            RecommendationCardType,
            values_callable=enum_values,
            native_enum=False,
            create_constraint=True,
            name="recommendation_card_type",
        ),
        nullable=True,
    )


class RecommendationExposure(Base):
    __tablename__ = "recommendation_exposures"
    __table_args__ = (
        UniqueConstraint(
            "user_id", "client_event_id", name="uq_recommendation_exposures_user_client_event"
        ),
        Index("ix_recommendation_exposures_user_time", "user_id", "recommended_at"),
        Index("ix_recommendation_exposures_item_time", "recommendation_item_id", "recommended_at"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    client_event_id: Mapped[UUID] = mapped_column(Uuid)
    recommendation_item_id: Mapped[int] = mapped_column(
        ForeignKey("recommendation_batch_items.id", ondelete="RESTRICT")
    )
    recommended_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
