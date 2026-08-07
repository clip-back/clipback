from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User


class UserRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get(self, user_id: int) -> User | None:
        return await self.session.get(User, user_id)

    async def get_for_update(self, user_id: int) -> User | None:
        result = await self.session.scalars(
            select(User).where(User.id == user_id).with_for_update()
        )
        return result.first()

    async def create_guest(self) -> User:
        user = User(display_name="Guest", is_guest=True)
        self.session.add(user)
        await self.session.flush()
        await self.session.refresh(user)
        return user

    async def create_social(self, *, email: str | None, display_name: str) -> User:
        user = User(
            email=email,
            display_name=display_name,
            is_guest=False,
        )
        self.session.add(user)
        await self.session.flush()
        return user

    async def promote_guest(
        self,
        user: User,
        *,
        email: str | None,
        display_name: str,
    ) -> User:
        user.email = email
        user.display_name = display_name
        user.is_guest = False
        await self.session.flush()
        return user

    async def list_all(self) -> list[User]:
        result = await self.session.scalars(select(User).order_by(User.id.asc()))
        return list(result)
