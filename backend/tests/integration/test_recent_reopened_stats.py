from datetime import timedelta
from uuid import uuid4

import pytest
from sqlalchemy import select

from app.models.content_event import ContentEvent, ContentEventType
from app.services import user_service
from tests.integration.helpers import guest, link, request

pytestmark = pytest.mark.asyncio

WINDOW = timedelta(days=7)


async def _view(api, headers, content_id, client_event_id=None):
    payload = {"client_event_id": client_event_id or str(uuid4())}
    await request(
        api, "POST", f"contents/{content_id}/view", headers=headers, json=payload, status=201
    )


async def _stats(api, headers):
    return await request(api, "GET", "users/me/stats", headers=headers)


async def _social(api):
    tokens = await request(api, "POST", "auth/social/kakao", json={"token": "recent-reopened"})
    return {"Authorization": f"Bearer {tokens['access_token']}"}


async def test_repeated_views_count_once_and_distinct_contents_add_up(api):
    headers, _, _ = await guest(api)
    first = await link(api, headers)
    second = await link(api, headers, original_url="https://example.com/second")
    for _ in range(3):
        await _view(api, headers, first["id"])
    assert await _stats(api, headers) == {
        "saved_count": 2,
        "reopened_count": 3,
        "recent_reopened_count": 1,
    }

    await _view(api, headers, second["id"])
    assert await _stats(api, headers) == {
        "saved_count": 2,
        "reopened_count": 4,
        "recent_reopened_count": 2,
    }


async def test_saved_but_unopened_contents_are_zero(api):
    headers, _, _ = await guest(api)
    content = await link(api, headers)
    await request(api, "GET", f"contents/{content['id']}", headers=headers)
    assert await _stats(api, headers) == {
        "saved_count": 1,
        "reopened_count": 0,
        "recent_reopened_count": 0,
    }


async def test_retried_view_request_counts_once(api):
    headers, _, _ = await guest(api)
    content = await link(api, headers)
    client_event_id = str(uuid4())
    for _ in range(2):
        await _view(api, headers, content["id"], client_event_id)
    assert await _stats(api, headers) == {
        "saved_count": 1,
        "reopened_count": 1,
        "recent_reopened_count": 1,
    }


async def test_window_includes_exactly_seven_days_and_excludes_one_microsecond_later(
    api, database_connection, monkeypatch
):
    headers, _, user = await guest(api)
    content = await link(api, headers)
    await _view(api, headers, content["id"])
    viewed_at = await database_connection.scalar(
        select(ContentEvent.created_at).where(
            ContentEvent.user_id == user["id"],
            ContentEvent.event_type == ContentEventType.CONTENT_REOPENED,
        )
    )

    monkeypatch.setattr(user_service, "utc_now", lambda: viewed_at + WINDOW)
    assert await _stats(api, headers) == {
        "saved_count": 1,
        "reopened_count": 1,
        "recent_reopened_count": 1,
    }
    monkeypatch.setattr(
        user_service, "utc_now", lambda: viewed_at + WINDOW + timedelta(microseconds=1)
    )
    assert await _stats(api, headers) == {
        "saved_count": 1,
        "reopened_count": 1,
        "recent_reopened_count": 0,
    }


async def test_deleting_viewed_content_removes_it_from_recent_count(api):
    headers, _, _ = await guest(api)
    first = await link(api, headers)
    second = await link(api, headers, original_url="https://example.com/second")
    for content in (first, second, first):
        await _view(api, headers, content["id"])
    await request(api, "DELETE", f"contents/{first['id']}", headers=headers, status=204)
    assert await _stats(api, headers) == {
        "saved_count": 2,
        "reopened_count": 3,
        "recent_reopened_count": 1,
    }


async def test_guest_and_social_accounts_follow_same_rule_without_mixing(api):
    guest_headers, _, _ = await guest(api)
    social_headers = await _social(api)
    guest_content = await link(api, guest_headers)
    social_content = await link(api, social_headers)
    for _ in range(2):
        await _view(api, guest_headers, guest_content["id"])
    await _view(api, social_headers, social_content["id"])

    assert await _stats(api, guest_headers) == {
        "saved_count": 1,
        "reopened_count": 2,
        "recent_reopened_count": 1,
    }
    assert await _stats(api, social_headers) == {
        "saved_count": 1,
        "reopened_count": 1,
        "recent_reopened_count": 1,
    }
