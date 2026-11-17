from pathlib import Path
from uuid import uuid4

import pytest
import pytest_asyncio
from alembic.migration import MigrationContext
from alembic.operations import Operations
from alembic.script import ScriptDirectory
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.category_repository import CategoryRepository

PREVIOUS_REVISION = "202611060022"
COLOR_REVISION = "202611170023"
MIGRATIONS = Path(__file__).resolve().parents[2] / "alembic"
OLD_COLORS = {
    "취업": "#4F46E5", "공부": "#059669", "업무 팁": "#DC2626",
    "생활 꿀팁": "#D97706", "장소": "#0891B2", "제품 추천": "#7C3AED",
}
NEW_COLORS = {
    "취업": "#64B5F6", "공부": "#5BD89D", "업무 팁": "#FF6277",
    "생활 꿀팁": "#FFA24B", "장소": "#FFD75C", "제품 추천": "#B9AAFF",
}
CUSTOM_COLORS = {
    "취업": "#ff6277", "공부": "#4F46E5", "업무 팁": "#123456",
    "생활 꿀팁": "#ffb3c1", "장소": "#1f5e24", "제품 추천": "#abcdef",
}


def _legacy_schema(connection, schema):
    connection.execute(text(f'CREATE SCHEMA "{schema}"'))
    connection.execute(text(f'SET LOCAL search_path TO "{schema}"'))
    scripts = ScriptDirectory(str(MIGRATIONS))
    with Operations.context(MigrationContext.configure(connection)):
        for revision in reversed(list(scripts.walk_revisions(base="base", head=PREVIOUS_REVISION))):
            revision.module.upgrade()


def _migrate(connection, direction):
    revision = ScriptDirectory(str(MIGRATIONS)).get_revision(COLOR_REVISION)
    assert revision.down_revision == PREVIOUS_REVISION
    with Operations.context(MigrationContext.configure(connection)):
        getattr(revision.module, direction)()


@pytest_asyncio.fixture
async def legacy_categories(database_connection):
    connection = database_connection
    await connection.run_sync(_legacy_schema, f"category_colors_{uuid4().hex}")
    await connection.execute(text("""
        INSERT INTO users (id, display_name)
        SELECT id, 'synthetic owner' FROM generate_series(1, 6) AS id
    """))
    for user_id, colors, is_default in (
        (1, OLD_COLORS, True),
        (2, {name: color.lower() for name, color in OLD_COLORS.items()}, True),
        (3, CUSTOM_COLORS, True),
        (4, OLD_COLORS, False),
        (5, dict.fromkeys(OLD_COLORS), True),
    ):
        await connection.execute(text("""
            INSERT INTO categories (user_id, name, color, is_default)
            VALUES (:user_id, :name, :color, :is_default)
        """), [
            {"user_id": user_id, "name": name, "color": color, "is_default": is_default}
            for name, color in colors.items()
        ])
    # An unrelated name with a legacy color must also survive.
    await connection.execute(text("""
        INSERT INTO categories (user_id, name, color, is_default)
        VALUES (3, '이름 변경', '#4F46E5', true)
    """))
    return connection


async def _colors(connection, user_id):
    rows = await connection.execute(text("""
        SELECT name, color FROM categories
        WHERE user_id IS NOT DISTINCT FROM :user_id ORDER BY id
    """), {"user_id": user_id})
    return dict(rows.all())


@pytest.mark.asyncio
async def test_upgrade_updates_templates_and_unchanged_defaults(legacy_categories):
    connection = legacy_categories
    await connection.run_sync(_migrate, "upgrade")
    assert await _colors(connection, None) == {**NEW_COLORS, "미분류": "#6B7280"}
    assert await _colors(connection, 1) == NEW_COLORS


@pytest.mark.asyncio
async def test_upgrade_matches_lowercase_legacy_colors(legacy_categories):
    connection = legacy_categories
    await connection.run_sync(_migrate, "upgrade")
    assert await _colors(connection, 2) == NEW_COLORS


@pytest.mark.asyncio
async def test_upgrade_preserves_user_chosen_colors_and_other_names(legacy_categories):
    connection = legacy_categories
    await connection.run_sync(_migrate, "upgrade")
    assert await _colors(connection, 3) == {**CUSTOM_COLORS, "이름 변경": "#4F46E5"}


@pytest.mark.asyncio
async def test_upgrade_preserves_nondefault_categories(legacy_categories):
    connection = legacy_categories
    await connection.run_sync(_migrate, "upgrade")
    assert await _colors(connection, 4) == OLD_COLORS


@pytest.mark.asyncio
async def test_upgrade_preserves_null_colors(legacy_categories):
    connection = legacy_categories
    await connection.run_sync(_migrate, "upgrade")
    assert await _colors(connection, 5) == dict.fromkeys(OLD_COLORS)


@pytest.mark.asyncio
async def test_new_user_receives_migrated_template_colors(legacy_categories):
    connection = legacy_categories
    await connection.run_sync(_migrate, "upgrade")
    async with AsyncSession(bind=connection, join_transaction_mode="create_savepoint") as session:
        await CategoryRepository(session).seed_for_user(6)
        assert await _colors(connection, 6) == NEW_COLORS


@pytest.mark.asyncio
async def test_downgrade_restores_matching_defaults_and_preserves_other_rows(legacy_categories):
    connection = legacy_categories
    await connection.run_sync(_migrate, "upgrade")
    # Downgrade also reverses a deliberate new-palette selection (case insensitive).
    await connection.execute(text("""
        UPDATE categories SET color = '#64b5f6' WHERE user_id = 1 AND name = '취업'
    """))
    await connection.run_sync(_migrate, "downgrade")
    assert await _colors(connection, None) == {**OLD_COLORS, "미분류": "#6B7280"}
    assert await _colors(connection, 1) == OLD_COLORS
    assert await _colors(connection, 2) == OLD_COLORS
    assert await _colors(connection, 3) == {**CUSTOM_COLORS, "이름 변경": "#4F46E5"}
    assert await _colors(connection, 4) == OLD_COLORS
    assert await _colors(connection, 5) == dict.fromkeys(OLD_COLORS)
    await connection.run_sync(_migrate, "upgrade")
    assert await _colors(connection, 1) == NEW_COLORS
