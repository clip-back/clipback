from app.core.exceptions import AuthenticationError
from app.repositories.event_repository import EventRepository
from app.repositories.social_identity_repository import SocialIdentityRepository
from app.repositories.user_repository import UserRepository
from app.schemas.user import UserRead, UserStatsRead


class UserService:
    def __init__(
        self,
        user_repository: UserRepository,
        social_identity_repository: SocialIdentityRepository,
        event_repository: EventRepository,
    ) -> None:
        self.user_repository = user_repository
        self.social_identity_repository = social_identity_repository
        self.event_repository = event_repository

    async def read_me(self, user_id: int) -> UserRead:
        user = await self.user_repository.get(user_id)
        if user is None:
            raise AuthenticationError()
        providers = await self.social_identity_repository.list_providers(user_id=user_id)
        return UserRead(
            id=user.id,
            email=user.email,
            display_name=user.display_name,
            is_guest=user.is_guest,
            created_at=user.created_at,
            linked_providers=providers,
        )

    async def read_stats(self, user_id: int) -> UserStatsRead:
        stats = await self.event_repository.read_user_stats(user_id=user_id)
        return UserStatsRead.model_validate(stats)
