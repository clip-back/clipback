"""Prepare recommendation storage and initialize existing view counts."""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "202609240012"
down_revision = "202609220011"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "recommendation_batches",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column(
            "type",
            sa.Enum(
                "TODAY",
                "WEEKLY_PICK",
                name="recommendation_type",
                native_enum=False,
                create_constraint=True,
            ),
            nullable=False,
        ),
        sa.Column("recommendation_date", sa.Date(), nullable=True),
        sa.Column(
            "generated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.UniqueConstraint(
            "user_id",
            "type",
            "recommendation_date",
            name="uq_recommendation_batches_user_type_date",
        ),
        sa.CheckConstraint(
            "(type = 'TODAY' AND recommendation_date IS NOT NULL) OR "
            "(type = 'WEEKLY_PICK' AND recommendation_date IS NULL)",
            name="ck_recommendation_batches_date",
        ),
    )
    op.create_table(
        "recommendation_batch_items",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "batch_id",
            sa.Integer(),
            sa.ForeignKey("recommendation_batches.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column("rank", sa.Integer(), nullable=False),
        sa.Column(
            "target_kind",
            sa.Enum(
                "CONTENT",
                "CATEGORY",
                name="recommendation_target_kind",
                native_enum=False,
                create_constraint=True,
            ),
            nullable=False,
        ),
        sa.Column("target_id_snapshot", sa.Integer(), nullable=False),
        sa.Column(
            "content_id",
            sa.Integer(),
            sa.ForeignKey("contents.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "category_id",
            sa.Integer(),
            sa.ForeignKey("categories.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("score", sa.Double(), nullable=True),
        sa.Column(
            "card_type",
            sa.Enum(
                "MOST_SAVED",
                "MOST_VIEWED",
                "REDISCOVERY",
                name="recommendation_card_type",
                native_enum=False,
                create_constraint=True,
            ),
            nullable=True,
        ),
        sa.UniqueConstraint("batch_id", "rank", name="uq_recommendation_batch_items_batch_rank"),
        sa.UniqueConstraint(
            "batch_id",
            "target_kind",
            "target_id_snapshot",
            name="uq_recommendation_batch_items_batch_target",
        ),
        sa.CheckConstraint("rank > 0", name="ck_recommendation_batch_items_rank"),
        sa.CheckConstraint("target_id_snapshot > 0", name="ck_recommendation_batch_items_snapshot"),
        sa.CheckConstraint(
            "score IS NULL OR (score >= 0 AND score <= 1)",
            name="ck_recommendation_batch_items_score",
        ),
        sa.CheckConstraint(
            "(target_kind = 'CONTENT' AND category_id IS NULL AND card_type IS NULL) OR "
            "(target_kind = 'CATEGORY' AND content_id IS NULL "
            "AND score IS NULL AND card_type IS NOT NULL)",
            name="ck_recommendation_batch_items_target",
        ),
        sa.CheckConstraint(
            "(content_id IS NULL OR content_id = target_id_snapshot) AND "
            "(category_id IS NULL OR category_id = target_id_snapshot)",
            name="ck_recommendation_batch_items_live_target",
        ),
    )
    op.create_table(
        "recommendation_exposures",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("client_event_id", sa.Uuid(), nullable=False),
        sa.Column(
            "recommendation_item_id",
            sa.Integer(),
            sa.ForeignKey("recommendation_batch_items.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column(
            "recommended_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.UniqueConstraint(
            "user_id", "client_event_id", name="uq_recommendation_exposures_user_client_event"
        ),
    )

    op.add_column(
        "contents", sa.Column("open_count", sa.Integer(), server_default="0", nullable=False)
    )
    op.add_column(
        "contents",
        sa.Column("recommendation_count", sa.Integer(), server_default="0", nullable=False),
    )
    op.add_column(
        "contents", sa.Column("last_recommended_at", sa.DateTime(timezone=True), nullable=True)
    )
    op.add_column("contents", sa.Column("last_recommended_surface", sa.String(11), nullable=True))
    op.create_check_constraint("ck_contents_open_count", "contents", "open_count >= 0")
    op.create_check_constraint(
        "ck_contents_recommendation_count", "contents", "recommendation_count >= 0"
    )
    op.create_check_constraint(
        "content_recommendation_surface",
        "contents",
        "last_recommended_surface IN ('TODAY', 'WEEKLY_PICK')",
    )

    op.add_column("content_events", sa.Column("client_event_id", sa.Uuid(), nullable=True))
    op.add_column(
        "content_events",
        sa.Column("category_ids_at_event", postgresql.ARRAY(sa.Integer()), nullable=True),
    )
    op.add_column(
        "content_events", sa.Column("recommendation_item_id", sa.Integer(), nullable=True)
    )
    op.create_foreign_key(
        "fk_content_events_recommendation_item_id",
        "content_events",
        "recommendation_batch_items",
        ["recommendation_item_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    op.create_unique_constraint(
        "uq_content_events_user_client_event", "content_events", ["user_id", "client_event_id"]
    )
    op.create_index(
        "ix_content_events_user_type_time",
        "content_events",
        ["user_id", "event_type", "created_at"],
    )
    op.create_index(
        "ix_content_events_recommendation_item_id", "content_events", ["recommendation_item_id"]
    )
    op.create_index(
        "ix_recommendation_batch_items_content_id", "recommendation_batch_items", ["content_id"]
    )
    op.create_index(
        "ix_recommendation_batch_items_category_id", "recommendation_batch_items", ["category_id"]
    )
    op.create_index(
        "ix_recommendation_exposures_user_time",
        "recommendation_exposures",
        ["user_id", "recommended_at"],
    )
    op.create_index(
        "ix_recommendation_exposures_item_time",
        "recommendation_exposures",
        ["recommendation_item_id", "recommended_at"],
    )

    # Stop old writers until the stage-2 event writer is active.
    # No trigger maintains this count yet.
    op.execute("""
        UPDATE contents AS content
        SET open_count = (
            SELECT COUNT(*)
            FROM content_events AS event
            WHERE event.content_id = content.id
              AND event.user_id = content.user_id
              AND event.event_type = 'content_reopened'
        )
    """)


def downgrade() -> None:
    op.drop_index("ix_content_events_recommendation_item_id", table_name="content_events")
    op.drop_index("ix_content_events_user_type_time", table_name="content_events")
    op.drop_constraint("uq_content_events_user_client_event", "content_events", type_="unique")
    op.drop_constraint(
        "fk_content_events_recommendation_item_id", "content_events", type_="foreignkey"
    )
    op.drop_column("content_events", "recommendation_item_id")
    op.drop_column("content_events", "category_ids_at_event")
    op.drop_column("content_events", "client_event_id")
    op.drop_constraint("content_recommendation_surface", "contents", type_="check")
    op.drop_constraint("ck_contents_recommendation_count", "contents", type_="check")
    op.drop_constraint("ck_contents_open_count", "contents", type_="check")
    op.drop_column("contents", "last_recommended_surface")
    op.drop_column("contents", "last_recommended_at")
    op.drop_column("contents", "recommendation_count")
    op.drop_column("contents", "open_count")
    op.drop_table("recommendation_exposures")
    op.drop_table("recommendation_batch_items")
    op.drop_table("recommendation_batches")
