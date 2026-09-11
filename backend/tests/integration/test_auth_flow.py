from datetime import timedelta

import pytest
from sqlalchemy import func, select

from app.core.security import create_access_token, decode_access_token
from app.models.content import Content
from app.models.content_event import ContentEvent
from tests.integration.helpers import guest, link, request

pytestmark = pytest.mark.asyncio


async def test_guest_refresh_and_logout(api):
    headers, tokens, user = await guest(api)
    assert user["is_guest"] and user["linked_providers"] == []
    assert user["created_at"]
    categories = await request(api, "GET", "categories", headers=headers)
    assert any(c["name"] == "미분류" for c in categories)
    assert any(c["is_default"] and c["name"] != "미분류" for c in categories)
    rotated = await request(
        api, "POST", "auth/refresh", json={"refresh_token": tokens["refresh_token"]}
    )
    assert rotated["refresh_token"] != tokens["refresh_token"]
    await request(
        api, "POST", "auth/refresh", status=401, json={"refresh_token": tokens["refresh_token"]}
    )
    new_headers = {"Authorization": f"Bearer {rotated['access_token']}"}
    assert (await request(api, "GET", "users/me", headers=new_headers))["id"] == user["id"]
    await request(
        api, "POST", "auth/logout", status=204, json={"refresh_token": rotated["refresh_token"]}
    )
    await request(api, "GET", "users/me", headers=new_headers, status=401)
    await request(
        api, "POST", "auth/refresh", status=401, json={"refresh_token": rotated["refresh_token"]}
    )


async def test_social_login_and_guest_upgrade_preserve_identity(api):
    first = await request(api, "POST", "auth/social/kakao", json={"token": "social-user"})
    assert first["is_new_user"] is True
    headers = {"Authorization": f"Bearer {first['access_token']}"}
    user = await request(api, "GET", "users/me", headers=headers)
    categories = await request(api, "GET", "categories", headers=headers)
    second = await request(api, "POST", "auth/social/kakao", json={"token": "social-user"})
    headers2 = {"Authorization": f"Bearer {second['access_token']}"}
    assert not second["is_new_user"]
    assert await request(api, "GET", "users/me", headers=headers2) == user
    assert await request(api, "GET", "categories", headers=headers2) == categories
    assert user["email"] is None and user["linked_providers"] == ["kakao"]

    guest_headers, _, before = await guest(api)
    content = await link(api, guest_headers)
    owned = await request(api, "GET", "categories", headers=guest_headers)
    target = next(c for c in owned if c["name"] != "미분류")
    await request(api, "DELETE", f"categories/{target['id']}", headers=guest_headers, status=204)
    remaining = await request(api, "GET", "categories", headers=guest_headers)
    upgraded = await request(
        api,
        "POST",
        "auth/social/kakao/upgrade",
        headers=guest_headers,
        json={"token": "upgraded-user"},
    )
    upgraded_headers = {"Authorization": f"Bearer {upgraded['access_token']}"}
    after = await request(api, "GET", "users/me", headers=upgraded_headers)
    assert after["id"] == before["id"] and after["created_at"] == before["created_at"]
    assert not after["is_guest"] and after["linked_providers"] == ["kakao"]
    assert await request(api, "GET", "categories", headers=upgraded_headers) == remaining
    assert (await request(api, "GET", f"contents/{content['id']}", headers=upgraded_headers))[
        "id"
    ] == content["id"]


@pytest.mark.parametrize("kind", ["missing", "invalid", "expired", "revoked"])
async def test_invalid_auth_cannot_create_content(api, database_connection, kind):
    headers, tokens, _ = await guest(api)
    if kind == "missing":
        headers = {}
    elif kind == "invalid":
        headers = {"Authorization": "Bearer invalid"}
    elif kind == "expired":
        claims = decode_access_token(tokens["access_token"])
        token = create_access_token(
            user_id=claims.user_id,
            session_id=claims.session_id,
            expires_delta=timedelta(minutes=-1),
        )
        headers = {"Authorization": f"Bearer {token}"}
    else:
        await request(
            api, "POST", "auth/logout", status=204, json={"refresh_token": tokens["refresh_token"]}
        )
    await request(api, "GET", "users/me", headers=headers, status=401)
    await request(
        api,
        "POST",
        "contents",
        headers=headers,
        status=401,
        json={"original_url": "https://example.com/rejected"},
    )
    assert await database_connection.scalar(select(func.count()).select_from(Content)) == 0
    assert await database_connection.scalar(select(func.count()).select_from(ContentEvent)) == 0
