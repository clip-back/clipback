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

    async def list_available(self, user_id: int) -> list[SimpleNamespace]:
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
            SimpleNamespace(id=1, name="취업", color="#4F46E5", is_default=True),
            SimpleNamespace(id=2, name="여행", color=None, is_default=False),
        ]
    )
    service = CategoryService(
        category_repository=category_repository,
    )

    categories = await service.list_categories(user_id=1)

    assert [category.name for category in categories] == ["취업", "여행"]


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
