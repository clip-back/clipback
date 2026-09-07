from fastapi import APIRouter, Query, Response, status

from app.api.deps import CurrentUserId, DatabaseSession
from app.repositories.category_repository import CategoryRepository
from app.schemas.category import CategoryCreate, CategoryRead, CategorySummaryRead, CategoryUpdate
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


@router.patch("/{category_id}", response_model=CategoryRead)
async def update_category(
    category_id: int,
    payload: CategoryUpdate,
    db: DatabaseSession,
    current_user_id: CurrentUserId,
) -> CategoryRead:
    service = CategoryService(category_repository=CategoryRepository(db))
    return await service.update_category(current_user_id, category_id, payload)


@router.delete("/{category_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_category(
    category_id: int,
    db: DatabaseSession,
    current_user_id: CurrentUserId,
) -> Response:
    service = CategoryService(category_repository=CategoryRepository(db))
    await service.delete_category(current_user_id, category_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
