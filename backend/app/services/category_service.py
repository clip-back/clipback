from sqlalchemy.exc import IntegrityError

from app.core.exceptions import InvalidStateError
from app.repositories.category_repository import CategoryRepository
from app.schemas.category import CategoryCreate, CategoryRead, CategorySummaryRead


class CategoryService:
    def __init__(
        self,
        category_repository: CategoryRepository,
    ) -> None:
        self.category_repository = category_repository

    async def list_categories(self, user_id: int) -> list[CategorySummaryRead]:
        categories = await self.category_repository.list_summaries(user_id=user_id)
        return [CategorySummaryRead.model_validate(category) for category in categories]

    async def list_recent_categories(self, user_id: int, limit: int) -> list[CategorySummaryRead]:
        categories = await self.category_repository.list_recent(user_id=user_id, limit=limit)
        return [CategorySummaryRead.model_validate(category) for category in categories]

    async def create_category(self, user_id: int, payload: CategoryCreate) -> CategoryRead:
        existing_category = await self.category_repository.find_available_by_name(
            user_id=user_id,
            name=payload.name,
        )
        if existing_category is not None:
            raise InvalidStateError("Category already exists")

        try:
            category = await self.category_repository.create(user_id=user_id, payload=payload)
            await self.category_repository.session.commit()
        except IntegrityError as exc:
            await self.category_repository.session.rollback()
            raise InvalidStateError("Category already exists") from exc

        return CategoryRead.model_validate(category)
