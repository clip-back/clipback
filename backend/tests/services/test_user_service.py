from datetime import UTC, datetime
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.core.exceptions import AuthenticationError
from app.models.social_identity import SocialProvider
from app.services.user_service import UserService


@pytest.mark.asyncio
@pytest.mark.parametrize("is_guest", [True, False])
async def test_read_me_composes_account_without_internal_fields(is_guest) -> None:
    user = SimpleNamespace(
        id=7,
        email=None,
        display_name="사용자",
        is_guest=is_guest,
        created_at=datetime(2026, 9, 7, 3, tzinfo=UTC),
        provider_subject="internal-subject",
        access_token="internal-token",
    )
    users = AsyncMock()
    users.get.return_value = user
    identities = AsyncMock()
    providers = [] if is_guest else [SocialProvider.GOOGLE, SocialProvider.KAKAO]
    identities.list_providers.return_value = providers
    service = UserService(users, identities, AsyncMock())

    result = await service.read_me(user_id=7)

    assert result.model_dump(mode="json") == {
        "id": 7,
        "email": None,
        "display_name": "사용자",
        "is_guest": is_guest,
        "created_at": "2026-09-07T03:00:00Z",
        "linked_providers": [provider.value for provider in providers],
    }
    users.get.assert_awaited_once_with(7)
    identities.list_providers.assert_awaited_once_with(user_id=7)


@pytest.mark.asyncio
async def test_missing_user_is_authentication_error() -> None:
    users = AsyncMock()
    users.get.return_value = None
    identities = AsyncMock()

    with pytest.raises(AuthenticationError):
        await UserService(users, identities, AsyncMock()).read_me(user_id=7)
    identities.list_providers.assert_not_awaited()


@pytest.mark.asyncio
@pytest.mark.parametrize("counts", [(0, 0), (1, 3)])
async def test_stats_preserves_cumulative_counts_and_user_scope(counts) -> None:
    events = AsyncMock()
    events.read_user_stats.return_value = {"saved_count": counts[0], "reopened_count": counts[1]}

    result = await UserService(AsyncMock(), AsyncMock(), events).read_stats(user_id=7)

    assert result.model_dump() == events.read_user_stats.return_value
    events.read_user_stats.assert_awaited_once_with(user_id=7)
