import json

from sqlalchemy.exc import IntegrityError

from app.core.exceptions import InvalidStateError, NotFoundError, SystemConfigurationError
from app.models.content_event import ContentEventType
from app.repositories.category_repository import CategoryRepository
from app.repositories.content_repository import ContentRepository
from app.repositories.event_repository import EventRepository
from app.schemas.category import CategoryCreate, CategoryRead, CategorySummaryRead, CategoryUpdate


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
        try:
            await self.category_repository.lock_user(user_id)
            await self._check_name(user_id, payload.name)
            category = await self.category_repository.create(user_id=user_id, payload=payload)
            await self.category_repository.session.commit()
        except IntegrityError as exc:
            await self.category_repository.session.rollback()
            raise InvalidStateError("Category already exists") from exc
        except Exception:
            await self.category_repository.session.rollback()
            raise
        return CategoryRead.model_validate(category)

    async def _check_name(self, user_id: int, name: str, category_id: int | None = None) -> None:
        existing = await self.category_repository.find_available_by_name(
            user_id,
            name,
            exclude_id=category_id,
        )
        if existing is not None and existing.id != category_id:
            raise InvalidStateError("Category already exists")

    async def update_category(
        self,
        user_id: int,
        category_id: int,
        payload: CategoryUpdate,
    ) -> CategoryRead:
        session = self.category_repository.session
        try:
            await self.category_repository.lock_user(user_id)
            category = await self.category_repository.get_owned(user_id, category_id)
            if category is None:
                raise NotFoundError("Category not found")
            if "name" in payload.model_fields_set:
                await self._check_name(user_id, payload.name, category_id)
            for field, value in payload.model_dump(exclude_unset=True).items():
                setattr(category, field, value)
            await session.flush()
            result = CategoryRead.model_validate(category)
            await session.commit()
            return result
        except IntegrityError as exc:
            await session.rollback()
            raise InvalidStateError("Category already exists") from exc
        except Exception:
            await session.rollback()
            raise

    async def delete_category(self, user_id: int, category_id: int) -> None:
        session = self.category_repository.session
        contents = ContentRepository(session)
        events = EventRepository(session)
        try:
            await self.category_repository.lock_user(user_id)
            category = await self.category_repository.get_owned(user_id, category_id)
            if category is None:
                raise NotFoundError("Category not found")
            content_ids = await contents.lock_category_contents(user_id, category_id)
            for content_id in content_ids:
                content = await contents.get_owned(user_id=user_id, content_id=content_id)
                if content is None:
                    continue
                before = sorted(item.id for item in content.categories)
                if category_id not in before:
                    continue
                remaining = [item for item in content.categories if item.id != category_id]
                if not remaining:
                    uncategorized = await self.category_repository.get_uncategorized()
                    if uncategorized is None:
                        raise SystemConfigurationError("Uncategorized category is missing")
                    remaining = [uncategorized]
                await contents.replace_categories(content=content, categories=remaining)
                await events.create(
                    user_id=user_id,
                    content_id=content_id,
                    event_type=ContentEventType.CATEGORY_CHANGED,
                    metadata_json=json.dumps(
                        {
                            "before_category_ids": before,
                            "after_category_ids": sorted(item.id for item in remaining),
                        },
                        ensure_ascii=False,
                        separators=(",", ":"),
                    ),
                )
            await self.category_repository.delete_owned(user_id, category_id)
            await session.commit()
        except IntegrityError as exc:
            await session.rollback()
            raise InvalidStateError("Category is in use; refresh and try again") from exc
        except Exception:
            await session.rollback()
            raise
