from fastapi import APIRouter, status

from app.schemas.category import CategoryCreate, CategoryRead
from app.services.category_service import CategoryService

router = APIRouter()


@router.get("", response_model=list[CategoryRead])
async def list_categories() -> list[CategoryRead]:
    return CategoryService().list_default_categories()


@router.post("", response_model=CategoryRead, status_code=status.HTTP_201_CREATED)
async def create_category(payload: CategoryCreate) -> CategoryRead:
    return CategoryService().create_placeholder(payload)

