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

    async def flush(self) -> None:
        pass

    async def commit(self) -> None:
        self.committed = True

    async def rollback(self) -> None:
        self.rolled_back = True


class FakeCategoryRepository:
    def __init__(self, categories: list[SimpleNamespace] | None = None) -> None:
        self.categories = categories or []
        self.session = FakeSession()
        self.calls: list[tuple[int, int | None]] = []

    async def lock_user(self, user_id: int) -> None:
        pass

    async def get_owned(self, user_id: int, category_id: int):
        return next(
            (c for c in self.categories if c.id == category_id and c.user_id == user_id), None
        )

    async def list_summaries(self, user_id: int) -> list[SimpleNamespace]:
        self.calls.append((user_id, None))
        return self.categories

    async def list_recent(self, user_id: int, limit: int) -> list[SimpleNamespace]:
        self.calls.append((user_id, limit))
        return self.categories

    async def find_available_by_name(
        self, user_id: int, name: str, exclude_id=None
    ) -> SimpleNamespace | None:
        normalized_name = name.lower()
        for category in self.categories:
            if category.name.lower() == normalized_name and category.id != exclude_id:
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


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "changes,expected",
    [
        ({"name": "  Trip  "}, ("Trip", "red")),
        ({"color": None}, ("여행", None)),
        ({"color": "blue"}, ("여행", "blue")),
        ({"name": "Trip", "color": "blue"}, ("Trip", "blue")),
        ({"name": "여행", "color": "red"}, ("여행", "red")),
    ],
)
async def test_update_personal_default(changes, expected):
    from app.schemas.category import CategoryUpdate

    repository = FakeCategoryRepository(
        [
            SimpleNamespace(id=1, user_id=7, name="여행", color="red", is_default=True),
        ]
    )
    result = await CategoryService(repository).update_category(7, 1, CategoryUpdate(**changes))
    assert (result.name, result.color) == expected
    assert result.is_default is True
    assert repository.session.committed


@pytest.mark.asyncio
async def test_update_rejects_duplicate_and_allows_self_case_change():
    from app.schemas.category import CategoryUpdate

    repository = FakeCategoryRepository(
        [
            SimpleNamespace(id=1, user_id=7, name="Trip", color=None, is_default=True),
            SimpleNamespace(id=2, user_id=7, name="Study", color=None, is_default=False),
        ]
    )
    service = CategoryService(repository)
    with pytest.raises(InvalidStateError):
        await service.update_category(7, 1, CategoryUpdate(name="STUDY"))
    result = await service.update_category(7, 1, CategoryUpdate(name="TRIP"))
    assert result.name == "TRIP"


@pytest.mark.asyncio
@pytest.mark.parametrize("owner", [None, 8])
async def test_update_rejects_non_owned_categories(owner):
    from app.core.exceptions import NotFoundError
    from app.schemas.category import CategoryUpdate

    repository = FakeCategoryRepository(
        [
            SimpleNamespace(id=1, user_id=owner, name="미분류", color=None, is_default=True),
        ]
    )
    with pytest.raises(NotFoundError):
        await CategoryService(repository).update_category(7, 1, CategoryUpdate(color=None))
    assert repository.session.rolled_back
