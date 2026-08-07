import time
from collections.abc import Callable

import httpx
import pytest
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from jose import jwt
from jose.utils import base64url_encode

from app.core.config import Settings
from app.integrations.social_auth_client import (
    GOOGLE_JWKS_URL,
    KAKAO_JWKS_URL,
    NAVER_PROFILE_URL,
    SocialAuthClient,
    SocialAuthInvalidCredentialError,
    SocialAuthNotConfiguredError,
    SocialAuthTimeoutError,
    SocialAuthUpstreamError,
)
from app.models.social_identity import SocialProvider


def generate_signing_key(kid: str) -> tuple[bytes, dict[str, str]]:
    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    private_pem = private_key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )
    numbers = private_key.public_key().public_numbers()
    jwk = {
        "kty": "RSA",
        "kid": kid,
        "use": "sig",
        "alg": "RS256",
        "n": base64url_encode(
            numbers.n.to_bytes((numbers.n.bit_length() + 7) // 8, "big")
        ).decode(),
        "e": base64url_encode(
            numbers.e.to_bytes((numbers.e.bit_length() + 7) // 8, "big")
        ).decode(),
    }
    return private_pem, jwk


def encode_token(
    private_key: bytes,
    *,
    kid: str,
    issuer: str = "https://accounts.google.com",
    audience: str = "google-client-id",
    subject: str | None = "google-user-1",
    expires_at: int | None = None,
    extra_claims: dict[str, object] | None = None,
) -> str:
    claims: dict[str, object] = {
        "iss": issuer,
        "aud": audience,
        "exp": expires_at or int(time.time()) + 300,
    }
    if subject is not None:
        claims["sub"] = subject
    claims.update(extra_claims or {})
    return jwt.encode(claims, private_key, algorithm="RS256", headers={"kid": kid})


def build_client(
    handler: Callable[[httpx.Request], httpx.Response],
    *,
    google_client_ids: list[str] | None = None,
    kakao_rest_api_key: str | None = None,
) -> SocialAuthClient:
    http_client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    settings = Settings(
        google_client_ids=google_client_ids or [],
        kakao_rest_api_key=kakao_rest_api_key,
        _env_file=None,
    )
    return SocialAuthClient(config=settings, client=http_client)


@pytest.mark.asyncio
async def test_google_verifies_id_token_and_caches_jwks() -> None:
    private_key, public_jwk = generate_signing_key("google-key")
    requests: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        requests.append(request)
        assert str(request.url) == GOOGLE_JWKS_URL
        return httpx.Response(
            200,
            json={"keys": [public_jwk]},
            headers={"Cache-Control": "public, max-age=3600"},
        )

    client = build_client(handler, google_client_ids=["google-client-id"])
    token = encode_token(
        private_key,
        kid="google-key",
        extra_claims={
            "email": "User@Example.com",
            "email_verified": True,
            "name": "  Google   User  ",
        },
    )

    first = await client.verify(provider=SocialProvider.GOOGLE, token=token)
    second = await client.verify(provider=SocialProvider.GOOGLE, token=token)

    assert first == second
    assert first.subject == "google-user-1"
    assert first.email == "User@example.com"
    assert first.display_name == "Google User"
    assert len(requests) == 1


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "token_factory",
    [
        lambda key: encode_token(key, kid="key", issuer="https://attacker.example"),
        lambda key: encode_token(key, kid="key", audience="other-client"),
        lambda key: encode_token(key, kid="key", expires_at=int(time.time()) - 1),
        lambda key: encode_token(key, kid="key", subject=None),
    ],
)
async def test_google_rejects_invalid_claims(token_factory) -> None:
    private_key, public_jwk = generate_signing_key("key")

    def handler(_: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"keys": [public_jwk]})

    client = build_client(handler, google_client_ids=["google-client-id"])

    with pytest.raises(SocialAuthInvalidCredentialError):
        await client.verify(
            provider=SocialProvider.GOOGLE,
            token=token_factory(private_key),
        )


@pytest.mark.asyncio
async def test_google_rejects_wrong_signature_and_algorithm() -> None:
    _, public_jwk = generate_signing_key("key")
    attacker_key, _ = generate_signing_key("key")

    def handler(_: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"keys": [public_jwk]})

    client = build_client(handler, google_client_ids=["google-client-id"])
    wrong_signature = encode_token(attacker_key, kid="key")
    wrong_algorithm = jwt.encode(
        {
            "iss": "https://accounts.google.com",
            "aud": "google-client-id",
            "sub": "google-user-1",
            "exp": int(time.time()) + 300,
        },
        "secret",
        algorithm="HS256",
        headers={"kid": "key"},
    )

    with pytest.raises(SocialAuthInvalidCredentialError):
        await client.verify(provider=SocialProvider.GOOGLE, token=wrong_signature)
    with pytest.raises(SocialAuthInvalidCredentialError):
        await client.verify(provider=SocialProvider.GOOGLE, token=wrong_algorithm)


@pytest.mark.asyncio
async def test_unknown_kid_refreshes_jwks_once() -> None:
    first_private, first_public = generate_signing_key("first")
    second_private, second_public = generate_signing_key("second")
    request_count = 0

    def handler(_: httpx.Request) -> httpx.Response:
        nonlocal request_count
        request_count += 1
        keys = [first_public] if request_count == 1 else [first_public, second_public]
        return httpx.Response(
            200,
            json={"keys": keys},
            headers={"Cache-Control": "max-age=3600"},
        )

    client = build_client(handler, google_client_ids=["google-client-id"])
    await client.verify(
        provider=SocialProvider.GOOGLE,
        token=encode_token(first_private, kid="first"),
    )

    profile = await client.verify(
        provider=SocialProvider.GOOGLE,
        token=encode_token(second_private, kid="second", subject="rotated-user"),
    )

    assert profile.subject == "rotated-user"
    assert request_count == 2


@pytest.mark.asyncio
async def test_kakao_verifies_oidc_token() -> None:
    private_key, public_jwk = generate_signing_key("kakao-key")

    def handler(request: httpx.Request) -> httpx.Response:
        assert str(request.url) == KAKAO_JWKS_URL
        return httpx.Response(200, json={"keys": [public_jwk]})

    client = build_client(handler, kakao_rest_api_key="kakao-rest-key")
    token = encode_token(
        private_key,
        kid="kakao-key",
        issuer="https://kauth.kakao.com",
        audience="kakao-rest-key",
        subject="kakao-user-1",
        extra_claims={"nickname": "Kakao User", "email": "ignored@example.com"},
    )

    profile = await client.verify(provider=SocialProvider.KAKAO, token=token)

    assert profile.subject == "kakao-user-1"
    assert profile.email is None
    assert profile.display_name == "Kakao User"


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("profile", "expected_email", "expected_name"),
    [
        (
            {"id": "naver-user-1", "email": "naver@example.com", "nickname": "Naver User"},
            "naver@example.com",
            "Naver User",
        ),
        ({"id": "naver-user-2"}, None, "User"),
    ],
)
async def test_naver_reads_profile(
    profile: dict[str, str],
    expected_email: str | None,
    expected_name: str,
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert str(request.url) == NAVER_PROFILE_URL
        assert request.headers["Authorization"] == "Bearer naver-access-token"
        return httpx.Response(
            200,
            json={"resultcode": "00", "message": "success", "response": profile},
        )

    client = build_client(handler)

    result = await client.verify(
        provider=SocialProvider.NAVER,
        token="naver-access-token",
    )

    assert result.subject == profile["id"]
    assert result.email == expected_email
    assert result.display_name == expected_name


@pytest.mark.asyncio
async def test_naver_maps_invalid_token_and_malformed_response() -> None:
    responses = iter(
        [
            httpx.Response(401),
            httpx.Response(200, json={"resultcode": "00", "response": {}}),
        ]
    )

    def handler(_: httpx.Request) -> httpx.Response:
        return next(responses)

    client = build_client(handler)

    with pytest.raises(SocialAuthInvalidCredentialError):
        await client.verify(provider=SocialProvider.NAVER, token="invalid")
    with pytest.raises(SocialAuthUpstreamError):
        await client.verify(provider=SocialProvider.NAVER, token="malformed")


@pytest.mark.asyncio
async def test_provider_timeout_does_not_expose_token() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ReadTimeout("provider timeout", request=request)

    client = build_client(handler)
    secret_token = "secret-provider-token"

    with pytest.raises(SocialAuthTimeoutError) as error:
        await client.verify(provider=SocialProvider.NAVER, token=secret_token)

    assert secret_token not in str(error.value)


@pytest.mark.asyncio
@pytest.mark.parametrize("provider", [SocialProvider.GOOGLE, SocialProvider.KAKAO])
async def test_oidc_provider_requires_audience_configuration(
    provider: SocialProvider,
) -> None:
    client = build_client(lambda _: httpx.Response(500))

    with pytest.raises(SocialAuthNotConfiguredError):
        await client.verify(provider=provider, token="provider-token")
