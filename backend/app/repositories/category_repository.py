from collections.abc import Sequence

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.category import Category
from app.schemas.category import CategoryCreate


class CategoryRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def list_available(self, user_id: int) -> list[Category]:
        result = await self.session.scalars(
            select(Category)
            .where(or_(Category.user_id.is_(None), Category.user_id == user_id))
            .order_by(Category.is_default.desc(), Category.id.asc())
        )
        return list(result)

    async def find_available_by_name(self, user_id: int, name: str) -> Category | None:
        result = await self.session.scalars(
            select(Category).where(
                or_(Category.user_id.is_(None), Category.user_id == user_id),
                func.lower(Category.name) == name.lower(),
            )
        )
        return result.first()

    async def list_available_by_ids(
        self,
        user_id: int,
        category_ids: Sequence[int],
    ) -> list[Category]:
        if not category_ids:
            return []

        result = await self.session.scalars(
            select(Category)
            .where(
                Category.id.in_(category_ids),
                or_(Category.user_id.is_(None), Category.user_id == user_id),
            )
            .order_by(Category.id.asc())
        )
        return list(result)

    async def get_uncategorized(self) -> Category | None:
        result = await self.session.scalars(
            select(Category)
            .where(
                Category.user_id.is_(None),
                Category.name == "미분류",
                Category.is_default.is_(True),
            )
            .order_by(Category.id.asc())
        )
        return result.first()

    async def create(self, user_id: int, payload: CategoryCreate) -> Category:
        category = Category(
            user_id=user_id,
            name=payload.name,
            color=payload.color,
            is_default=False,
        )
        self.session.add(category)
        await self.session.flush()
        await self.session.refresh(category)
        return category
