import json
import runpy
from pathlib import Path

import pytest
import pytest_asyncio
from alembic.migration import MigrationContext
from alembic.operations import Operations
from sqlalchemy import insert, select

from app.core.exceptions import InvalidStateError, NotFoundError, SystemConfigurationError
from app.models.category import Category
from app.models.content import Content, ContentSource, ContentType
from app.models.content_asset import AssetType, ContentAsset
from app.models.content_category import content_categories
from app.models.content_event import ContentEvent, ContentEventType
from app.models.tag import Tag
from app.models.user import User
from app.repositories.category_repository import CategoryRepository
from app.repositories.content_repository import ContentRepository
from app.repositories.event_repository import EventRepository
from app.repositories.user_repository import UserRepository
from app.schemas.category import CategoryCreate, CategoryUpdate
from app.services.category_service import CategoryService


@pytest_asyncio.fixture
async def owned_categories(database_session):
    session = database_session
    user = await UserRepository(session).create_guest()
    other = await UserRepository(session).create_social(email=None, display_name="Other")
    repository = CategoryRepository(session)
    categories = await repository.list_recommendation_candidates(user.id)
    other_categories = await repository.list_recommendation_candidates(other.id)
    assert len(categories) >= 2
    await session.commit()
    return user.id, other.id, categories, other_categories


async def save(session, user_id, categories):
    content = Content(
        user_id=user_id,
        title="보존",
        summary="요약",
        content_type=ContentType.SCREENSHOT,
        source=ContentSource.SCREENSHOT,
        is_favorite=True,
        categories=categories,
        tags=[Tag(user_id=user_id, name="보존", normalized_name="보존")],
        assets=[
            ContentAsset(
                asset_type=AssetType.SCREENSHOT, storage_key="test/image.png", mime_type="image/png"
            )
        ],
    )
    session.add(content)
    await session.flush()
    await EventRepository(session).create(
        user_id=user_id,
        content_id=content.id,
        category_id=categories[0].id,
        event_type=ContentEventType.CONTENT_CREATED,
    )
    return content


@pytest.mark.asyncio
async def test_personal_defaults_are_isolated_and_deleted_defaults_stay_deleted(
    database_session,
    owned_categories,
):
    session = database_session
    uid, other_uid, categories, other_categories = owned_categories
    repo = CategoryRepository(session)
    service = CategoryService(repo)
    target = categories[0]
    original_name = target.name
    assert {c.id for c in categories}.isdisjoint(c.id for c in other_categories)
    assert [c.name for c in categories] == [c.name for c in other_categories]
    await service.update_category(uid, target.id, CategoryUpdate(name="개인 이름", color=None))
    assert other_categories[0].name == original_name
    assert await repo.list_available_by_ids(other_uid, [target.id]) == []
    template = await session.scalar(
        select(Category).where(
            Category.user_id.is_(None),
            Category.name == original_name,
        )
    )
    assert await repo.list_available_by_ids(uid, [template.id]) == []
    await service.delete_category(uid, target.id)
    await UserRepository(session).get(uid)
    assert target.id not in [c.id for c in await repo.list_recommendation_candidates(uid)]
    assert other_categories[0].id in [
        c.id for c in await repo.list_recommendation_candidates(other_uid)
    ]
    await service.create_category(uid, CategoryCreate(name=original_name))
    with pytest.raises(NotFoundError):
        await service.delete_category(uid, target.id)


@pytest.mark.asyncio
@pytest.mark.parametrize("multiple", [False, True])
async def test_delete_preserves_content_and_history(database_session, owned_categories, multiple):
    session = database_session
    uid, _, categories, _ = owned_categories
    target, remaining = categories[:2]
    content = await save(session, uid, [target, remaining] if multiple else [target])
    content_id, target_id = content.id, target.id
    saved_at = content.saved_at
    asset_id, tag_id = content.assets[0].id, content.tags[0].id
    await session.commit()
    await CategoryService(CategoryRepository(session)).delete_category(uid, target_id)
    updated = await ContentRepository(session).get_owned(user_id=uid, content_id=content_id)
    uncategorized = await CategoryRepository(session).get_uncategorized()
    after = [remaining.id] if multiple else [uncategorized.id]
    assert [c.id for c in updated.categories] == after
    assert updated.saved_at == saved_at and updated.is_favorite
    assert updated.title == "보존" and updated.summary == "요약"
    assert [a.id for a in updated.assets] == [asset_id]
    assert [t.id for t in updated.tags] == [tag_id]
    rows = list(
        await session.scalars(
            select(ContentEvent)
            .where(
                ContentEvent.user_id == uid,
            )
            .order_by(ContentEvent.id)
            .execution_options(populate_existing=True)
        )
    )
    assert len(rows) == 2
    assert rows[0].category_id is None
    assert rows[1].event_type == ContentEventType.CATEGORY_CHANGED
    assert json.loads(rows[1].metadata_json) == {
        "before_category_ids": sorted([target_id, remaining.id] if multiple else [target_id]),
        "after_category_ids": after,
    }
    assert dict(await EventRepository(session).read_user_stats(uid)) == {
        "saved_count": 1,
        "reopened_count": 0,
    }
    summaries = await CategoryRepository(session).list_summaries(uid)
    assert target_id not in [row["id"] for row in summaries]
    assert next(row for row in summaries if row["id"] == after[0])["content_count"] == 1
    recent = await CategoryRepository(session).list_recent(uid, 20)
    assert [row["id"] for row in recent] == ([remaining.id] if multiple else [])


@pytest.mark.asyncio
@pytest.mark.parametrize("operation", ["patch", "delete"])
async def test_non_owned_and_uncategorized_are_immutable(
    database_session,
    owned_categories,
    operation,
):
    session = database_session
    uid, _, _, other_categories = owned_categories
    repo = CategoryRepository(session)
    uncategorized = await repo.get_uncategorized()
    ids = [other_categories[0].id, uncategorized.id, -1]
    for category_id in ids:
        with pytest.raises(NotFoundError):
            service = CategoryService(repo)
            if operation == "patch":
                await service.update_category(uid, category_id, CategoryUpdate(color=None))
            else:
                await service.delete_category(uid, category_id)


@pytest.mark.asyncio
@pytest.mark.parametrize("failure", ["missing_uncategorized", "event", "foreign_reference"])
async def test_delete_rolls_back_all_changes(
    database_session, owned_categories, monkeypatch, failure
):
    session = database_session
    uid, other_uid, categories, _ = owned_categories
    target_id = categories[0].id
    content = await save(session, uid, [categories[0]])
    content_id = content.id
    if failure == "foreign_reference":
        # An unexpected reference must fail RESTRICT, never silently remove the link.
        other_content = Content(
            user_id=other_uid,
            title="Other",
            summary="",
            content_type=ContentType.LINK,
            source=ContentSource.WEB,
        )
        session.add(other_content)
        await session.flush()
        await session.execute(
            insert(content_categories).values(
                content_id=other_content.id,
                category_id=target_id,
            )
        )
    await session.commit()
    repo = CategoryRepository(session)
    if failure == "missing_uncategorized":

        async def missing():
            return None

        monkeypatch.setattr(repo, "get_uncategorized", missing)
        error = SystemConfigurationError
    elif failure == "event":

        async def fail(*args, **kwargs):
            raise RuntimeError("injected failure")

        monkeypatch.setattr(EventRepository, "create", fail)
        error = RuntimeError
    else:
        error = InvalidStateError
    with pytest.raises(error):
        await CategoryService(repo).delete_category(uid, target_id)
    assert await repo.get_owned(uid, target_id) is not None
    updated = await ContentRepository(session).get_owned(user_id=uid, content_id=content_id)
    assert [c.id for c in updated.categories] == [target_id]
    events = list(await session.scalars(select(ContentEvent).where(ContentEvent.user_id == uid)))
    assert len(events) == 1 and events[0].event_type == ContentEventType.CONTENT_CREATED


@pytest.mark.asyncio
async def test_migration_moves_legacy_links_and_reuses_name_collision(database_session):
    session = database_session
    # Seed legacy users directly, bypassing the new signup seeding.
    users = [User(display_name="Legacy"), User(display_name="Legacy other")]
    session.add_all(users)
    await session.flush()
    template = await session.scalar(
        select(Category)
        .where(
            Category.user_id.is_(None),
            Category.is_default.is_(True),
            Category.name != "미분류",
        )
        .order_by(Category.id)
    )
    collision = Category(user_id=users[0].id, name=template.name, color="custom", is_default=False)
    session.add(collision)
    await session.flush()
    content = await save(session, users[0].id, [template, collision])
    event = await EventRepository(session).create(
        user_id=users[1].id,
        category_id=template.id,
        event_type=ContentEventType.CATEGORY_FILTER_USED,
        metadata_json='{"historic":true}',
    )
    migration = runpy.run_path(
        str(
            Path(__file__).parents[2]
            / "alembic"
            / "versions"
            / "20260907_0010_personalize_default_categories.py"
        )
    )
    connection = await session.connection()

    def migrate(sync_connection):
        with Operations.context(MigrationContext.configure(sync_connection)):
            migration["upgrade"]()

    await connection.run_sync(migrate)
    updated = await ContentRepository(session).get_owned(user_id=users[0].id, content_id=content.id)
    assert [c.id for c in updated.categories] == [collision.id]
    assert collision.color == "custom" and not collision.is_default
    await session.refresh(event)
    assert event.category_id != template.id
    assert event.metadata_json == '{"historic":true}'
    for user in users:
        candidates = await CategoryRepository(session).list_recommendation_candidates(user.id)
        assert template.id not in [c.id for c in candidates]
        assert len([c for c in candidates if c.name.lower() == template.name.lower()]) == 1


@pytest.mark.asyncio
async def test_rename_and_noop_do_not_record_events(database_session, owned_categories):
    session = database_session
    uid, _, categories, _ = owned_categories
    service = CategoryService(CategoryRepository(session))
    target_id = categories[0].id
    for payload in [
        CategoryUpdate(name="Personal", color="red"),
        CategoryUpdate(name="PERSONAL"),
        CategoryUpdate(name="PERSONAL"),
    ]:
        result = await service.update_category(uid, target_id, payload)
        assert result.color == "red"
    assert (
        list(await session.scalars(select(ContentEvent).where(ContentEvent.user_id == uid))) == []
    )
    with pytest.raises(InvalidStateError):
        await service.update_category(uid, target_id, CategoryUpdate(name="미분류"))


@pytest.mark.asyncio
async def test_guest_promotion_does_not_reseed(database_session, owned_categories):
    session = database_session
    uid, _, categories, _ = owned_categories
    target_id = categories[0].id
    repo = CategoryRepository(session)
    await CategoryService(repo).delete_category(uid, target_id)
    user_repo = UserRepository(session)
    user = await user_repo.get(uid)
    await user_repo.promote_guest(user, email=None, display_name="Social")
    assert target_id not in [c.id for c in await repo.list_recommendation_candidates(uid)]
    assert len(await repo.list_recommendation_candidates(uid)) == len(categories) - 1
