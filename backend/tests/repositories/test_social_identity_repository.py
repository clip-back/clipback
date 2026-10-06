import pytest

from app.models.social_identity import SocialProvider
from app.models.user import User
from app.repositories.social_identity_repository import SocialIdentityRepository


@pytest.mark.asyncio
async def test_providers_are_sorted_and_scoped_to_user(database_session) -> None:
    user = User(display_name="소셜 사용자", is_guest=False)
    other = User(display_name="다른 사용자", is_guest=False)
    guest = User(display_name="Guest")
    database_session.add_all([user, other, guest])
    await database_session.flush()
    repository = SocialIdentityRepository(database_session)
    for provider in [SocialProvider.NAVER, SocialProvider.GOOGLE, SocialProvider.KAKAO]:
        await repository.create(
            user_id=user.id,
            provider=provider,
            provider_subject=f"test-subject-{user.id}",
        )
    await repository.create(
        user_id=other.id,
        provider=SocialProvider.NAVER,
        provider_subject=f"test-subject-{other.id}",
    )

    assert await repository.list_providers(user.id) == [
        SocialProvider.GOOGLE,
        SocialProvider.KAKAO,
        SocialProvider.NAVER,
    ]
    assert await repository.list_providers(other.id) == [SocialProvider.NAVER]
    assert await repository.list_providers(guest.id) == []
