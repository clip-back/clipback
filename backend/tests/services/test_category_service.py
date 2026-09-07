from datetime import UTC, datetime
from types import SimpleNamespace

import pytest

from app.core.exceptions import InvalidStateError
from app.schemas.category import CategoryCreate
from app.services.category_service import CategoryService


class FakeSession:
    def __init__(self) -> None:
        self.committed = False
        self.rolled_back = False

    async def commit(self) -> None:
        self.committed = True

    async def rollback(self) -> None:
        self.rolled_back = True


class FakeCategoryRepository:
    def __init__(self, categories: list[SimpleNamespace] | None = None) -> None:
        self.categories = categories or []
        self.session = FakeSession()
        self.calls: list[tuple[int, int | None]] = []

    async def list_summaries(self, user_id: int) -> list[SimpleNamespace]:
        self.calls.append((user_id, None))
        return self.categories

    async def list_recent(self, user_id: int, limit: int) -> list[SimpleNamespace]:
        self.calls.append((user_id, limit))
        return self.categories

    async def find_available_by_name(self, user_id: int, name: str) -> SimpleNamespace | None:
        normalized_name = name.lower()
        for category in self.categories:
            if category.name.lower() == normalized_name:
                return category
        return None

    async def create(self, user_id: int, payload: CategoryCreate) -> SimpleNamespace:
        category = SimpleNamespace(
            id=len(self.categories) + 1,
            user_id=user_id,
            name=payload.name,
            color=payload.color,
            is_default=False,
        )
        self.categories.append(category)
        return category


@pytest.mark.asyncio
async def test_list_categories_returns_available_categories() -> None:
    category_repository = FakeCategoryRepository(
        [
            SimpleNamespace(
                id=1,
                name="취업",
                color="#4F46E5",
                is_default=True,
                content_count=3,
                last_saved_at=datetime(2026, 9, 7, tzinfo=UTC),
            ),
            SimpleNamespace(
                id=2,
                name="여행",
                color=None,
                is_default=False,
                content_count=0,
                last_saved_at=None,
            ),
        ]
    )
    service = CategoryService(
        category_repository=category_repository,
    )

    categories = await service.list_categories(user_id=1)

    assert [category.name for category in categories] == ["취업", "여행"]
    assert categories[0].content_count == 3
    assert categories[0].last_saved_at == datetime(2026, 9, 7, tzinfo=UTC)
    assert categories[1].content_count == 0
    assert categories[1].last_saved_at is None
    assert category_repository.calls == [(1, None)]


@pytest.mark.asyncio
async def test_recent_categories_preserves_repository_order_and_passes_limit() -> None:
    repository = FakeCategoryRepository(
        [
            SimpleNamespace(
                id=8,
                name="여행",
                color=None,
                is_default=False,
                content_count=1,
                last_saved_at=datetime(2026, 9, 7, tzinfo=UTC),
            ),
            SimpleNamespace(
                id=3,
                name="취업",
                color=None,
                is_default=True,
                content_count=2,
                last_saved_at=datetime(2026, 9, 6, tzinfo=UTC),
            ),
        ]
    )
    categories = await CategoryService(repository).list_recent_categories(user_id=7, limit=2)

    assert [category.id for category in categories] == [8, 3]
    assert [category.content_count for category in categories] == [1, 2]
    assert repository.calls == [(7, 2)]


@pytest.mark.asyncio
async def test_category_lists_can_be_empty() -> None:
    service = CategoryService(FakeCategoryRepository())

    assert await service.list_categories(user_id=1) == []
    assert await service.list_recent_categories(user_id=1, limit=2) == []


@pytest.mark.asyncio
async def test_create_category_trims_name_and_commits() -> None:
    category_repository = FakeCategoryRepository()
    service = CategoryService(
        category_repository=category_repository,
    )

    category = await service.create_category(
        user_id=1,
        payload=CategoryCreate(name="  여행  ", color="#0891B2"),
    )

    assert category.name == "여행"
    assert category.color == "#0891B2"
    assert category.is_default is False
    assert category_repository.session.committed is True
    assert set(category.model_dump()) == {"id", "name", "color", "is_default"}


@pytest.mark.asyncio
async def test_create_category_rejects_duplicate_names() -> None:
    category_repository = FakeCategoryRepository(
        [SimpleNamespace(id=1, name="취업", color="#4F46E5", is_default=True)]
    )
    service = CategoryService(
        category_repository=category_repository,
    )

    with pytest.raises(InvalidStateError):
        await service.create_category(user_id=1, payload=CategoryCreate(name="취업"))
