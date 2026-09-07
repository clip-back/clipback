from fastapi import APIRouter, Query, status

from app.api.deps import CurrentUserId, DatabaseSession
from app.repositories.category_repository import CategoryRepository
from app.schemas.category import CategoryCreate, CategoryRead, CategorySummaryRead
from app.services.category_service import CategoryService

router = APIRouter()


@router.get("", response_model=list[CategorySummaryRead])
async def list_categories(
    db: DatabaseSession,
    current_user_id: CurrentUserId,
) -> list[CategorySummaryRead]:
    service = CategoryService(
        category_repository=CategoryRepository(db),
    )
    return await service.list_categories(user_id=current_user_id)


@router.get("/recent", response_model=list[CategorySummaryRead])
async def list_recent_categories(
    db: DatabaseSession,
    current_user_id: CurrentUserId,
    limit: int = Query(default=2, ge=1, le=20),
) -> list[CategorySummaryRead]:
    service = CategoryService(
        category_repository=CategoryRepository(db),
    )
    return await service.list_recent_categories(user_id=current_user_id, limit=limit)


@router.post("", response_model=CategoryRead, status_code=status.HTTP_201_CREATED)
async def create_category(
    payload: CategoryCreate,
    db: DatabaseSession,
    current_user_id: CurrentUserId,
) -> CategoryRead:
    service = CategoryService(
        category_repository=CategoryRepository(db),
    )
    return await service.create_category(user_id=current_user_id, payload=payload)
