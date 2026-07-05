from fastapi import APIRouter

from app.schemas.user import UserRead

router = APIRouter()


@router.get("/me", response_model=UserRead)
async def read_me() -> UserRead:
    return UserRead(id=1, email=None, display_name="Guest")

