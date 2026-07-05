from fastapi import APIRouter, status

from app.api.deps import CurrentUserId, DatabaseSession
from app.repositories.category_repository import CategoryRepository
from app.repositories.user_repository import UserRepository
from app.schemas.category import CategoryCreate, CategoryRead
from app.services.category_service import CategoryService

router = APIRouter()


@router.get("", response_model=list[CategoryRead])
async def list_categories(
    db: DatabaseSession,
    current_user_id: CurrentUserId,
) -> list[CategoryRead]:
    service = CategoryService(
        category_repository=CategoryRepository(db),
        user_repository=UserRepository(db),
    )
    return await service.list_categories(user_id=current_user_id)


@router.post("", response_model=CategoryRead, status_code=status.HTTP_201_CREATED)
async def create_category(
    payload: CategoryCreate,
    db: DatabaseSession,
    current_user_id: CurrentUserId,
) -> CategoryRead:
    service = CategoryService(
        category_repository=CategoryRepository(db),
        user_repository=UserRepository(db),
    )
    return await service.create_category(user_id=current_user_id, payload=payload)
