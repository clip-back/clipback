import base64
import hashlib
import time
from urllib.parse import parse_qs

import httpx
import pytest
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec
from jose import jwt

from app.core.config import Settings
from app.integrations.social_auth_client import (
    APPLE_ISSUER,
    APPLE_JWKS_URL,
    APPLE_TOKEN_URL,
    SocialAuthClient,
    SocialAuthInvalidCredentialError,
    SocialAuthNotConfiguredError,
    SocialAuthTimeoutError,
    SocialAuthUpstreamError,
)
from app.models.social_identity import SocialProvider
from tests.integrations.test_social_auth_client import encode_token, generate_signing_key


def apple_client(handler, **overrides):
    signing_key = ec.generate_private_key(ec.SECP256R1())
    pem = signing_key.private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.PKCS8,
        serialization.NoEncryption(),
    ).decode()
    config = Settings(
        _env_file=None,
        youtube_summary_enabled=False,
        **{
            "apple_client_id": "com.example.clipback",
            "apple_team_id": "TEAM123",
            "apple_key_id": "KEY123",
            "apple_private_key": pem,
            **overrides,
        },
    )
    return SocialAuthClient(config, httpx.AsyncClient(transport=httpx.MockTransport(handler)))


def apple_token(private_key, **overrides):
    return encode_token(
        private_key,
        **{
            "kid": "apple-key",
            "issuer": APPLE_ISSUER,
            "audience": "com.example.clipback",
            "subject": "apple-user",
            "extra_claims": {"nonce": "server-nonce"},
            **overrides,
        },
    )


@pytest.mark.asyncio
@pytest.mark.parametrize("email_verified", [True, "true", False, "false", None])
async def test_apple_verifies_nonce_and_nullable_verified_relay_email(email_verified):
    private, public = generate_signing_key("apple-key")

    def handler(request):
        assert str(request.url) == APPLE_JWKS_URL
        return httpx.Response(200, json={"keys": [public]})

    client = apple_client(handler)
    token = apple_token(
        private,
        extra_claims={
            "nonce": "server-nonce",
            "email": "private@privaterelay.appleid.com",
            "email_verified": email_verified,
            "at_hash": "SDK-access-token-is-not-sent-to-Clipback",
        },
    )
    profile = await client.verify_apple_identity(
        token,
        nonce_hash=hashlib.sha256(b"server-nonce").hexdigest(),
        display_name="  Apple\n User  ",
    )
    assert profile.provider == SocialProvider.APPLE
    assert profile.subject == "apple-user"
    assert profile.display_name == "Apple User"
    assert profile.email == (
        "private@privaterelay.appleid.com" if email_verified in (True, "true") else None
    )


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "overrides",
    [
        {"audience": "another-app"},
        {"audience": ["com.example.clipback"]},
        {"issuer": "https://attacker.example"},
        {"expires_at": int(time.time()) - 60},
        {"subject": None},
        {"extra_claims": {}},
        {"extra_claims": {"nonce": "different-nonce"}},
        {"extra_claims": {"nonce": 42}},
    ],
)
async def test_apple_rejects_invalid_claims_or_nonce(overrides):
    private, public = generate_signing_key("apple-key")
    client = apple_client(lambda _: httpx.Response(200, json={"keys": [public]}))
    with pytest.raises(SocialAuthInvalidCredentialError):
        await client.verify_apple_identity(
            apple_token(private, **overrides),
            nonce_hash=hashlib.sha256(b"server-nonce").hexdigest(),
        )


@pytest.mark.asyncio
async def test_apple_code_exchange_signs_server_secret_and_does_not_send_native_redirect_uri():
    client = None

    def handler(request):
        assert request.method == "POST" and str(request.url) == APPLE_TOKEN_URL
        body = parse_qs(request.content.decode())
        assert body["client_id"] == ["com.example.clipback"]
        assert body["grant_type"] == ["authorization_code"]
        assert body["code"] == ["one-time-code"]
        assert "redirect_uri" not in body
        public_key = serialization.load_pem_private_key(
            client.config.apple_private_key.get_secret_value().encode(), password=None
        ).public_key()
        claims = jwt.decode(
            body["client_secret"][0],
            public_key,
            algorithms=["ES256"],
            audience=APPLE_ISSUER,
            issuer="TEAM123",
        )
        assert claims["sub"] == "com.example.clipback"
        assert claims["exp"] - claims["iat"] == 300
        assert jwt.get_unverified_header(body["client_secret"][0])["kid"] == "KEY123"
        return httpx.Response(
            200, json={
                "id_token": "identity", "refresh_token": "provider-refresh",
                "access_token": "provider-access",
            }
        )

    client = apple_client(handler)
    result = await client.exchange_apple_code("one-time-code")
    assert result.refresh_token == "provider-refresh"
    assert result.access_token == "provider-access"
    assert "provider-refresh" not in repr(result)
    assert "identity" not in repr(result)
    assert "provider-access" not in repr(result)


@pytest.mark.asyncio
@pytest.mark.parametrize("grant_type", ["authorization_code", "refresh_token"])
@pytest.mark.parametrize("access_token", ["provider-access", None, "wrong-access"])
async def test_apple_server_grants_validate_at_hash_when_access_token_is_available(
    grant_type, access_token
):
    private, public = generate_signing_key("apple-key")
    access_hash = base64.urlsafe_b64encode(
        hashlib.sha256(b"provider-access").digest()[:16]
    ).rstrip(b"=").decode()
    token = apple_token(
        private, extra_claims={"nonce": "server-nonce", "at_hash": access_hash}
    )

    def handler(request):
        if request.method == "GET":
            assert str(request.url) == APPLE_JWKS_URL
            return httpx.Response(200, json={"keys": [public]})
        assert str(request.url) == APPLE_TOKEN_URL
        assert parse_qs(request.content.decode())["grant_type"] == [grant_type]
        payload = {"id_token": token, "refresh_token": "provider-refresh"}
        if access_token is not None:
            payload["access_token"] = access_token
        return httpx.Response(200, json=payload)

    client = apple_client(handler)
    grant = (
        await client.exchange_apple_code("one-time-code")
        if grant_type == "authorization_code"
        else await client.refresh_apple_token("provider-refresh")
    )
    nonce_hash = (
        hashlib.sha256(b"server-nonce").hexdigest()
        if grant_type == "authorization_code" else None
    )
    if access_token == "wrong-access":
        with pytest.raises(SocialAuthInvalidCredentialError):
            await client.verify_apple_identity(
                grant.id_token, nonce_hash=nonce_hash, access_token=grant.access_token
            )
    else:
        profile = await client.verify_apple_identity(
            grant.id_token, nonce_hash=nonce_hash, access_token=grant.access_token
        )
        assert profile.subject == "apple-user"


@pytest.mark.asyncio
async def test_apple_refresh_does_not_require_rotated_provider_refresh_token():
    def handler(request):
        body = parse_qs(request.content.decode())
        assert body["grant_type"] == ["refresh_token"]
        assert body["refresh_token"] == ["old-provider-refresh"]
        return httpx.Response(200, json={"id_token": "new-identity"})

    result = await apple_client(handler).refresh_apple_token("old-provider-refresh")
    assert result.refresh_token is None


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("status", "payload", "error"),
    [
        (400, {"error": "invalid_grant"}, SocialAuthInvalidCredentialError),
        (400, {"error": "invalid_client"}, SocialAuthNotConfiguredError),
        (400, {"error": "unauthorized_client"}, SocialAuthNotConfiguredError),
        (429, {"error": "rate_limited"}, SocialAuthUpstreamError),
        (503, {}, SocialAuthUpstreamError),
        (200, [], SocialAuthUpstreamError),
        (200, {}, SocialAuthUpstreamError),
        (200, {"id_token": "ok", "refresh_token": ""}, SocialAuthUpstreamError),
        (200, {"id_token": "ok", "access_token": ""}, SocialAuthUpstreamError),
        (200, {"id_token": "ok", "access_token": 12}, SocialAuthUpstreamError),
    ],
)
async def test_apple_exchange_maps_errors_without_exposing_provider_response(
    status, payload, error
):
    client = apple_client(lambda _: httpx.Response(status, json=payload))
    with pytest.raises(error) as caught:
        await client.exchange_apple_code("secret-code")
    assert "secret-code" not in str(caught.value)


@pytest.mark.asyncio
async def test_apple_timeout_and_invalid_signing_key_are_distinct():
    def timeout(request):
        raise httpx.ReadTimeout("timeout", request=request)

    with pytest.raises(SocialAuthTimeoutError):
        await apple_client(timeout).exchange_apple_code("secret-code")
    with pytest.raises(SocialAuthNotConfiguredError):
        await apple_client(timeout, apple_private_key="invalid-private-key").exchange_apple_code(
            "code"
        )


@pytest.mark.asyncio
@pytest.mark.parametrize("audience", ["native-app-key", "rest-app-key"])
async def test_kakao_accepts_only_explicit_registered_audiences(audience):
    private, public = generate_signing_key("kakao-key")
    client = apple_client(
        lambda _: httpx.Response(200, json={"keys": [public]}),
        kakao_client_ids=["native-app-key", "rest-app-key"],
        kakao_rest_api_key="legacy-key",
    )
    token = encode_token(
        private,
        kid="kakao-key",
        issuer="https://kauth.kakao.com",
        audience=audience,
    )
    assert (await client.verify(provider=SocialProvider.KAKAO, token=token)).subject
    unregistered = encode_token(
        private,
        kid="kakao-key",
        issuer="https://kauth.kakao.com",
        audience="legacy-key",
    )
    with pytest.raises(SocialAuthInvalidCredentialError):
        await client.verify(provider=SocialProvider.KAKAO, token=unregistered)
