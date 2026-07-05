from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User


class UserRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get(self, user_id: int) -> User | None:
        return await self.session.get(User, user_id)

    async def ensure_guest_user(self, user_id: int) -> User:
        user = await self.get(user_id)
        if user is not None:
            return user

        user = User(id=user_id, display_name="Guest")
        self.session.add(user)
        await self.session.flush()
        await self.session.refresh(user)
        return user

    async def list_all(self) -> list[User]:
        result = await self.session.scalars(select(User).order_by(User.id.asc()))
        return list(result)
