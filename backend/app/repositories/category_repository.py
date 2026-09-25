from collections.abc import Sequence

from sqlalchemy import RowMapping, Select, delete, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.category import Category
from app.models.content import Content
from app.models.content_category import content_categories
from app.models.user import User
from app.schemas.category import CategoryCreate


class CategoryRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def list_summaries(self, user_id: int) -> list[RowMapping]:
        result = await self.session.execute(
            self._summary_statement(user_id).order_by(Category.is_default.desc(), Category.id.asc())
        )
        return list(result.mappings())

    async def list_recent(self, user_id: int, limit: int) -> list[RowMapping]:
        statement = self._summary_statement(user_id)
        result = await self.session.execute(
            statement.where(
                statement.selected_columns.content_count > 0,
                ~(
                    Category.user_id.is_(None)
                    & Category.is_default.is_(True)
                    & (Category.name == "미분류")
                ),
            )
            .order_by(statement.selected_columns.last_saved_at.desc(), Category.id.asc())
            .limit(limit)
        )
        return list(result.mappings())

    @staticmethod
    def _summary_statement(user_id: int) -> Select:
        counts = (
            select(
                content_categories.c.category_id,
                func.count(Content.id).label("content_count"),
                func.max(Content.saved_at).label("last_saved_at"),
            )
            .select_from(Content)
            .join(content_categories, content_categories.c.content_id == Content.id)
            .where(Content.user_id == user_id)
            .group_by(content_categories.c.category_id)
            .subquery()
        )
        return (
            select(
                Category.id,
                Category.name,
                Category.color,
                Category.is_default,
                func.coalesce(counts.c.content_count, 0).label("content_count"),
                counts.c.last_saved_at,
            )
            .outerjoin(counts, counts.c.category_id == Category.id)
            .where(CategoryRepository.available_to(user_id))
        )

    async def list_recommendation_candidates(self, user_id: int) -> list[Category]:
        result = await self.session.scalars(
            select(Category)
            .where(
                Category.user_id == user_id,
                Category.name != "미분류",
            )
            .order_by(Category.is_default.desc(), Category.id.asc())
        )
        return list(result)

    async def find_available_by_name(
        self,
        user_id: int,
        name: str,
        exclude_id: int | None = None,
    ) -> Category | None:
        result = await self.session.scalars(
            select(Category).where(
                CategoryRepository.available_to(user_id),
                func.lower(Category.name) == name.lower(),
                Category.id != exclude_id if exclude_id is not None else True,
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
                CategoryRepository.available_to(user_id),
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

    @staticmethod
    def available_to(user_id: int):
        return or_(
            Category.user_id == user_id,
            Category.user_id.is_(None)
            & Category.is_default.is_(True)
            & (Category.name == "미분류"),
        )

    async def seed_for_user(self, user_id: int) -> None:
        templates = await self.session.scalars(
            select(Category)
            .where(
                Category.user_id.is_(None),
                Category.is_default.is_(True),
                Category.name != "미분류",
            )
            .order_by(Category.id)
        )
        self.session.add_all(
            [
                Category(user_id=user_id, name=item.name, color=item.color, is_default=True)
                for item in templates
            ]
        )
        await self.session.flush()

    async def lock_user(self, user_id: int) -> None:
        # NO KEY UPDATE serializes names without blocking event/content FK inserts.
        await self.session.execute(
            select(User.id).where(User.id == user_id).with_for_update(key_share=True)
        )

    async def get_owned(self, user_id: int, category_id: int) -> Category | None:
        return await self.session.scalar(
            select(Category).where(Category.id == category_id, Category.user_id == user_id)
        )

    async def get_owned_for_key_share(self, user_id: int, category_id: int) -> Category | None:
        return await self.session.scalar(
            select(Category)
            .where(Category.id == category_id, Category.user_id == user_id)
            .with_for_update(read=True, key_share=True)
            .execution_options(populate_existing=True)
        )

    async def delete_owned(self, user_id: int, category_id: int) -> None:
        await self.session.execute(
            delete(Category).where(Category.id == category_id, Category.user_id == user_id)
        )
