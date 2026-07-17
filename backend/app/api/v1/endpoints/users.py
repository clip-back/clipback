from fastapi import APIRouter

from app.api.deps import CurrentUserId, DatabaseSession
from app.core.exceptions import AuthenticationError
from app.repositories.user_repository import UserRepository
from app.schemas.user import UserRead

router = APIRouter()


@router.get("/me", response_model=UserRead)
async def read_me(db: DatabaseSession, current_user_id: CurrentUserId) -> UserRead:
    user = await UserRepository(db).get(current_user_id)
    if user is None:
        raise AuthenticationError()
    return UserRead(
        id=user.id,
        email=user.email,
        display_name=user.display_name,
        is_guest=user.is_guest,
    )
