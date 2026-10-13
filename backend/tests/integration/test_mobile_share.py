from datetime import UTC, datetime, timedelta
from uuid import uuid4

import pytest
from jose import jwt
from sqlalchemy import update

from app.core.config import settings
from app.core.security import ALGORITHM, create_access_token, decode_access_token
from app.models.auth_session import AuthSession
from tests.integration.helpers import guest, request

pytestmark = pytest.mark.asyncio


async def credential(api, headers):
    response = await api.post("/api/v1/auth/share-credential", headers=headers)
    assert response.status_code == 200, response.text
    assert response.headers["cache-control"] == "no-store"
    result = response.json()
    return {"Authorization": f"Bearer {result['share_token']}"}, result


async def test_share_credential_has_only_two_write_permissions(api, png_bytes):
    headers, tokens, user = await guest(api)
    share, result = await credential(api, headers)
    claims = jwt.decode(result["share_token"], settings.secret_key, algorithms=[ALGORITHM])
    access = decode_access_token(tokens["access_token"])
    assert claims["type"] == "share" and claims["scope"] == "share:write"
    assert result["user_id"] == user["id"] and result["session_id"] == access.session_id
    assert claims["exp"] <= access.expires_at.timestamp()
    assert "refresh_token" not in result
    content = await request(api, "POST", "contents/share", status=201, headers=share,
                            json={"url": "https://youtu.be/dQw4w9WgXcQ"})
    image = await request(api, "POST", "uploads/screenshots", status=201, headers=share,
                          files={"file": ("test.png", png_bytes, "image/png")})
    for method, path, body in [
        ("GET", "users/me", None), ("GET", "feed", None), ("GET", "categories", None),
        ("GET", f"contents/{content['id']}", None),
        ("GET", f"uploads/assets/{image['assets'][0]['id']}", None),
        ("PUT", f"contents/{content['id']}/favorite", {"is_favorite": True}),
        ("DELETE", f"contents/{content['id']}", None),
        ("POST", "contents", {"original_url": "https://youtu.be/dQw4w9WgXcQ"}),
        ("POST", "auth/share-credential", None),
    ]:
        await request(api, method, path, status=401, headers=share,
                      **({"json": body} if body else {}))
    await request(api, "POST", "auth/refresh", status=401,
                  json={"refresh_token": result["share_token"]})
    assert (await request(api, "GET", "users/me", headers=headers))["id"] == user["id"]


@pytest.mark.parametrize("change", ["logout", "upgrade", "parent_expiry", "token_expiry",
                                    "wrong_scope", "wrong_user", "missing_exp"])
async def test_share_credential_rejects_invalid_parent_and_claims(api, database_connection, change):
    headers, tokens, user = await guest(api)
    share, result = await credential(api, headers)
    if change == "logout":
        await request(api, "POST", "auth/logout", status=204,
                      json={"refresh_token": tokens["refresh_token"]})
    elif change == "upgrade":
        await request(api, "POST", "auth/social/kakao/upgrade", headers=headers,
                      json={"token": f"share-upgrade-{uuid4()}"})
    elif change == "parent_expiry":
        await database_connection.execute(update(AuthSession).where(
            AuthSession.id == result["session_id"],
        ).values(expires_at=datetime.now(UTC) - timedelta(seconds=1)))
    else:
        claims = jwt.decode(result["share_token"], settings.secret_key, algorithms=[ALGORITHM])
        if change == "token_expiry":
            claims["exp"] = int(datetime.now(UTC).timestamp()) - 1
        elif change == "wrong_scope":
            claims["scope"] = "share:read"
        elif change == "missing_exp":
            del claims["exp"]
        else:
            claims["sub"] = str(user["id"] + 999999)
        share = {"Authorization": "Bearer " + jwt.encode(
            claims, settings.secret_key, algorithm=ALGORITHM,
        )}
    await request(api, "POST", "contents/share", status=401, headers=share,
                  json={"url": "https://youtu.be/dQw4w9WgXcQ"})


async def test_share_credential_expiry_capped_by_access_and_parent(api, database_connection):
    headers, tokens, user = await guest(api)
    access = decode_access_token(tokens["access_token"])
    shortened = datetime.now(UTC) + timedelta(minutes=10)
    await database_connection.execute(update(AuthSession).where(
        AuthSession.id == access.session_id,
    ).values(expires_at=shortened))
    _, result = await credential(api, headers)
    assert datetime.fromisoformat(result["expires_at"].replace("Z", "+00:00")) == shortened
    token = create_access_token(user_id=user["id"], session_id=access.session_id,
                                expires_delta=timedelta(minutes=1))
    _, result = await credential(api, {"Authorization": f"Bearer {token}"})
    assert datetime.fromisoformat(result["expires_at"].replace("Z", "+00:00")) < shortened


async def test_parent_refresh_keeps_share_credential_valid(api):
    headers, tokens, _ = await guest(api)
    share, _ = await credential(api, headers)
    await request(api, "POST", "auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    await request(api, "POST", "contents/share", status=201, headers=share,
                  json={"url": "https://youtu.be/dQw4w9WgXcQ"})


async def test_receipt_replay_conflict_delete_and_user_isolation(api):
    headers, _, _ = await guest(api)
    other, _, _ = await guest(api)
    key = str(uuid4())
    body = {"url": "https://youtu.be/dQw4w9WgXcQ"}
    writes = {**headers, "Idempotency-Key": key}
    first = await request(api, "POST", "contents/share", status=201, headers=writes, json=body)
    assert await request(api, "POST", "contents/share", status=201,
                         headers=writes, json=body) == first
    await request(api, "POST", "contents/share", status=409, headers=writes,
                  json={**body, "is_favorite": True})
    separate = await request(api, "POST", "contents/share", status=201,
                             headers={**other, "Idempotency-Key": key}, json=body)
    assert separate["id"] != first["id"]
    await request(api, "DELETE", f"contents/{first['id']}", status=204, headers=headers)
    await request(api, "POST", "contents/share", status=410, headers=writes, json=body)
    # A new share of the same URL is a separate action, not URL deduplication.
    new = await request(api, "POST", "contents/share", status=201,
                        headers={**headers, "Idempotency-Key": str(uuid4())}, json=body)
    assert new["id"] != first["id"]


async def test_idempotency_header_requires_uuid_and_preserves_headerless_behavior(api):
    headers, _, _ = await guest(api)
    body = {"url": "https://youtu.be/dQw4w9WgXcQ"}
    await request(api, "POST", "contents/share", status=422,
                  headers={**headers, "Idempotency-Key": "bad"}, json=body)
    first = await request(api, "POST", "contents/share", status=201, headers=headers, json=body)
    second = await request(api, "POST", "contents/share", status=201, headers=headers, json=body)
    assert first["id"] != second["id"]
