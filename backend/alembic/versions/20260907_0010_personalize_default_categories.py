"""Give each existing user their own default categories.

Revision ID: 202609070010
Revises: 202609030009
"""

from collections.abc import Sequence

from alembic import op

revision: str = "202609070010"
down_revision: str | None = "202609030009"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # Run with application writes stopped: legacy writers still use template IDs.
    op.execute("""
        INSERT INTO categories (user_id, name, color, is_default)
        SELECT u.id, template.name, template.color, true
        FROM users u CROSS JOIN categories template
        WHERE template.user_id IS NULL AND template.is_default
          AND template.name <> '미분류'
          AND NOT EXISTS (
              SELECT 1 FROM categories owned
              WHERE owned.user_id = u.id AND lower(owned.name) = lower(template.name)
          )
    """)
    op.execute("""
        CREATE TEMP TABLE personalized_category_ids ON COMMIT DROP AS
        SELECT u.id AS user_id, template.id AS old_id, min(owned.id) AS new_id
        FROM users u CROSS JOIN categories template
        JOIN categories owned ON lower(owned.name) = lower(template.name)
        WHERE template.user_id IS NULL AND template.is_default
          AND template.name <> '미분류' AND owned.user_id = u.id
        GROUP BY u.id, template.id
    """)
    op.execute("""
        INSERT INTO content_categories (content_id, category_id)
        SELECT link.content_id, mapping.new_id
        FROM content_categories link
        JOIN contents content ON content.id = link.content_id
        JOIN personalized_category_ids mapping
          ON mapping.old_id = link.category_id AND mapping.user_id = content.user_id
        ON CONFLICT DO NOTHING
    """)
    op.execute("""
        DELETE FROM content_categories link USING contents content,
          personalized_category_ids mapping
        WHERE content.id = link.content_id AND mapping.user_id = content.user_id
          AND mapping.old_id = link.category_id
    """)
    op.execute("""
        UPDATE content_events event SET category_id = mapping.new_id
        FROM personalized_category_ids mapping
        WHERE event.user_id = mapping.user_id AND event.category_id = mapping.old_id
    """)


def downgrade() -> None:
    raise RuntimeError(
        "Personalized categories cannot be merged losslessly. Restore a pre-migration backup."
    )
