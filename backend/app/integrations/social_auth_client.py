from __future__ import annotations

import asyncio
import hashlib
import hmac
import re
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from time import monotonic
from typing import Any

import httpx
from email_validator import EmailNotValidError, validate_email
from jose import JWSError, JWTError, jwt

from app.core.config import Settings, settings
from app.models.social_identity import SocialProvider

GOOGLE_JWKS_URL = "https://www.googleapis.com/oauth2/v3/certs"
GOOGLE_ISSUERS = {"accounts.google.com", "https://accounts.google.com"}
KAKAO_JWKS_URL = "https://kauth.kakao.com/.well-known/jwks.json"
KAKAO_ISSUERS = {"https://kauth.kakao.com"}
NAVER_PROFILE_URL = "https://openapi.naver.com/v1/nid/me"
APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys"
APPLE_TOKEN_URL = "https://appleid.apple.com/auth/token"
APPLE_ISSUER = "https://appleid.apple.com"
DEFAULT_JWKS_TTL_SECONDS = 3600
MAX_JWKS_TTL_SECONDS = 86400
CACHE_MAX_AGE_PATTERN = re.compile(r"(?:^|,)\s*max-age=(\d+)\s*(?:,|$)", re.IGNORECASE)
WHITESPACE_PATTERN = re.compile(r"\s+")


class SocialAuthClientError(Exception):
    pass


class SocialAuthNotConfiguredError(SocialAuthClientError):
    pass


class SocialAuthInvalidCredentialError(SocialAuthClientError):
    pass


class SocialAuthTimeoutError(SocialAuthClientError):
    pass


class SocialAuthUpstreamError(SocialAuthClientError):
    pass


@dataclass(frozen=True)
class SocialProfile:
    provider: SocialProvider
    subject: str
    email: str | None
    display_name: str


@dataclass(frozen=True)
class AppleTokenGrant:
    id_token: str = field(repr=False)
    refresh_token: str | None = field(default=None, repr=False)
    access_token: str | None = field(default=None, repr=False)


@dataclass(frozen=True)
class _JWKSCacheEntry:
    keys: dict[str, dict[str, Any]]
    expires_at: float


class SocialAuthClient:
    def __init__(
        self,
        config: Settings = settings,
        client: httpx.AsyncClient | None = None,
    ) -> None:
        self.config = config
        self._client = client or httpx.AsyncClient(
            timeout=config.social_auth_timeout_seconds,
            follow_redirects=False,
        )
        self._owns_client = client is None
        self._jwks_cache: dict[str, _JWKSCacheEntry] = {}
        self._jwks_lock = asyncio.Lock()

    async def verify(self, *, provider: SocialProvider, token: str) -> SocialProfile:
        if provider == SocialProvider.GOOGLE:
            return await self._verify_google(token)
        if provider == SocialProvider.KAKAO:
            return await self._verify_kakao(token)
        if provider == SocialProvider.NAVER:
            return await self._verify_naver(token)
        raise TypeError("Unsupported social provider")

    async def _verify_google(self, token: str) -> SocialProfile:
        audiences = {
            client_id.strip()
            for client_id in self.config.google_client_ids
            if client_id.strip()
        }
        if not audiences:
            raise SocialAuthNotConfiguredError

        claims = await self._decode_oidc_token(
            token=token,
            jwks_url=GOOGLE_JWKS_URL,
            issuers=GOOGLE_ISSUERS,
            audiences=audiences,
        )
        email = claims.get("email") if claims.get("email_verified") is True else None
        return self._build_profile(
            provider=SocialProvider.GOOGLE,
            subject=claims["sub"],
            email=email,
            display_name=claims.get("name"),
        )

    async def _verify_kakao(self, token: str) -> SocialProfile:
        audiences = {value.strip() for value in self.config.kakao_client_ids if value.strip()}
        if not audiences and self.config.kakao_rest_api_key is not None:
            legacy_audience = self.config.kakao_rest_api_key.get_secret_value().strip()
            if legacy_audience:
                audiences.add(legacy_audience)
        if not audiences:
            raise SocialAuthNotConfiguredError

        claims = await self._decode_oidc_token(
            token=token,
            jwks_url=KAKAO_JWKS_URL,
            issuers=KAKAO_ISSUERS,
            audiences=audiences,
        )
        email = claims.get("email") if claims.get("email_verified") is True else None
        return self._build_profile(
            provider=SocialProvider.KAKAO,
            subject=claims["sub"],
            email=email,
            display_name=claims.get("nickname"),
        )

    def apple_client_id(self) -> str:
        values = (
            self.config.apple_client_id,
            self.config.apple_team_id,
            self.config.apple_key_id,
            self.config.apple_private_key.get_secret_value()
            if self.config.apple_private_key else None,
        )
        if any(not value or not value.strip() for value in values):
            raise SocialAuthNotConfiguredError
        return self.config.apple_client_id.strip()

    async def verify_apple_identity(
        self, token: str, *, nonce_hash: str | None = None, display_name: str | None = None,
        access_token: str | None = None,
    ) -> SocialProfile:
        client_id = self.apple_client_id()
        claims = await self._decode_oidc_token(
            token=token, jwks_url=APPLE_JWKS_URL,
            issuers={APPLE_ISSUER}, audiences={client_id},
            access_token=access_token,
        )
        if claims.get("aud") != client_id:
            raise SocialAuthInvalidCredentialError
        if nonce_hash is not None:
            nonce = claims.get("nonce")
            if not isinstance(nonce, str) or not hmac.compare_digest(
                hashlib.sha256(nonce.encode()).hexdigest(), nonce_hash
            ):
                raise SocialAuthInvalidCredentialError
        verified_email = claims.get("email_verified")
        email = claims.get("email") if verified_email is True or verified_email == "true" else None
        return self._build_profile(
            provider=SocialProvider.APPLE, subject=claims["sub"],
            email=email, display_name=display_name,
        )

    async def exchange_apple_code(self, code: str) -> AppleTokenGrant:
        return await self._request_apple_token({"grant_type": "authorization_code", "code": code})

    async def refresh_apple_token(self, refresh_token: str) -> AppleTokenGrant:
        return await self._request_apple_token(
            {"grant_type": "refresh_token", "refresh_token": refresh_token}
        )

    def _apple_client_secret(self) -> str:
        client_id = self.apple_client_id()
        now = datetime.now(UTC)
        try:
            return jwt.encode(
                {
                    "iss": self.config.apple_team_id.strip(), "sub": client_id,
                    "aud": APPLE_ISSUER, "iat": now, "exp": now + timedelta(minutes=5),
                },
                self.config.apple_private_key.get_secret_value(), algorithm="ES256",
                headers={"kid": self.config.apple_key_id.strip()},
            )
        except (JWSError, JWTError, ValueError, TypeError) as exc:
            raise SocialAuthNotConfiguredError from exc

    async def _request_apple_token(self, fields: dict[str, str]) -> AppleTokenGrant:
        body = {
            "client_id": self.apple_client_id(), "client_secret": self._apple_client_secret(),
            **fields,
        }
        try:
            response = await self._client.post(APPLE_TOKEN_URL, data=body)
        except httpx.TimeoutException as exc:
            raise SocialAuthTimeoutError from exc
        except httpx.HTTPError as exc:
            raise SocialAuthUpstreamError from exc
        try:
            data = response.json()
        except ValueError as exc:
            raise SocialAuthUpstreamError from exc
        if not isinstance(data, dict):
            raise SocialAuthUpstreamError
        if response.status_code == 400:
            if data.get("error") == "invalid_grant":
                raise SocialAuthInvalidCredentialError
            if data.get("error") in {"invalid_client", "unauthorized_client"}:
                raise SocialAuthNotConfiguredError
        if response.status_code != 200:
            raise SocialAuthUpstreamError
        id_token = data.get("id_token")
        refresh_token = data.get("refresh_token")
        access_token = data.get("access_token")
        if not isinstance(id_token, str) or not id_token.strip():
            raise SocialAuthUpstreamError
        if refresh_token is not None and (
            not isinstance(refresh_token, str) or not refresh_token.strip()
        ):
            raise SocialAuthUpstreamError
        if access_token is not None and (
            not isinstance(access_token, str) or not access_token.strip()
        ):
            raise SocialAuthUpstreamError
        return AppleTokenGrant(
            id_token=id_token, refresh_token=refresh_token, access_token=access_token
        )

    async def _verify_naver(self, token: str) -> SocialProfile:
        try:
            response = await self._client.get(
                NAVER_PROFILE_URL,
                headers={"Authorization": f"Bearer {token}"},
            )
        except httpx.TimeoutException as exc:
            raise SocialAuthTimeoutError from exc
        except httpx.HTTPError as exc:
            raise SocialAuthUpstreamError from exc

        if response.status_code in {400, 401, 403}:
            raise SocialAuthInvalidCredentialError
        if response.status_code != 200:
            raise SocialAuthUpstreamError

        try:
            payload = response.json()
            profile = payload["response"]
            if payload["resultcode"] != "00" or not isinstance(profile, dict):
                raise SocialAuthInvalidCredentialError
            subject = profile["id"]
        except SocialAuthInvalidCredentialError:
            raise
        except (KeyError, TypeError, ValueError) as exc:
            raise SocialAuthUpstreamError from exc

        return self._build_profile(
            provider=SocialProvider.NAVER,
            subject=subject,
            email=profile.get("email"),
            display_name=profile.get("nickname") or profile.get("name"),
        )

    async def _decode_oidc_token(
        self,
        *,
        token: str,
        jwks_url: str,
        issuers: set[str],
        audiences: set[str],
        access_token: str | None = None,
    ) -> dict[str, Any]:
        try:
            header = jwt.get_unverified_header(token)
            if header.get("alg") != "RS256" or not isinstance(header.get("kid"), str):
                raise SocialAuthInvalidCredentialError
            key = await self._get_jwk(jwks_url=jwks_url, kid=header["kid"])
            claims = jwt.decode(
                token,
                key,
                algorithms=["RS256"],
                access_token=access_token,
                options={
                    "require_exp": True,
                    "require_sub": True,
                    "verify_aud": False,
                    "verify_iss": False,
                    # SDK login supplies only an ID token. For Apple's server grants,
                    # validate at_hash when the corresponding access token is available.
                    "verify_at_hash": access_token is not None,
                },
            )
        except SocialAuthClientError:
            raise
        except JWTError as exc:
            raise SocialAuthInvalidCredentialError from exc
        except (KeyError, TypeError, ValueError) as exc:
            raise SocialAuthInvalidCredentialError from exc

        if claims.get("iss") not in issuers or not self._audience_matches(
            claims.get("aud"), audiences
        ):
            raise SocialAuthInvalidCredentialError
        subject = claims.get("sub")
        if not isinstance(subject, str) or not subject.strip() or len(subject) > 255:
            raise SocialAuthInvalidCredentialError
        claims["sub"] = subject.strip()
        return claims

    async def _get_jwk(self, *, jwks_url: str, kid: str) -> dict[str, Any]:
        cached = self._jwks_cache.get(jwks_url)
        if cached is not None and cached.expires_at > monotonic() and kid in cached.keys:
            return cached.keys[kid]

        async with self._jwks_lock:
            cached = self._jwks_cache.get(jwks_url)
            if cached is not None and cached.expires_at > monotonic() and kid in cached.keys:
                return cached.keys[kid]
            refreshed = await self._fetch_jwks(jwks_url)
            if kid not in refreshed.keys:
                raise SocialAuthInvalidCredentialError
            return refreshed.keys[kid]

    async def _fetch_jwks(self, jwks_url: str) -> _JWKSCacheEntry:
        try:
            response = await self._client.get(jwks_url)
        except httpx.TimeoutException as exc:
            raise SocialAuthTimeoutError from exc
        except httpx.HTTPError as exc:
            raise SocialAuthUpstreamError from exc
        if response.status_code != 200:
            raise SocialAuthUpstreamError

        try:
            payload = response.json()
            raw_keys = payload["keys"]
            if not isinstance(raw_keys, list):
                raise TypeError
            keys = {
                key["kid"]: key
                for key in raw_keys
                if isinstance(key, dict)
                and isinstance(key.get("kid"), str)
                and key.get("kty") == "RSA"
            }
            if not keys:
                raise ValueError
        except (KeyError, TypeError, ValueError) as exc:
            raise SocialAuthUpstreamError from exc

        ttl = self._cache_ttl(response.headers.get("cache-control", ""))
        entry = _JWKSCacheEntry(keys=keys, expires_at=monotonic() + ttl)
        self._jwks_cache[jwks_url] = entry
        return entry

    async def close(self) -> None:
        if self._owns_client:
            await self._client.aclose()

    @staticmethod
    def _audience_matches(value: Any, audiences: set[str]) -> bool:
        if isinstance(value, str):
            return value in audiences
        if isinstance(value, list) and all(isinstance(item, str) for item in value):
            return bool(set(value) & audiences)
        return False

    @staticmethod
    def _cache_ttl(cache_control: str) -> int:
        match = CACHE_MAX_AGE_PATTERN.search(cache_control)
        if match is None:
            return DEFAULT_JWKS_TTL_SECONDS
        return min(int(match.group(1)), MAX_JWKS_TTL_SECONDS)

    @staticmethod
    def _build_profile(
        *,
        provider: SocialProvider,
        subject: Any,
        email: Any,
        display_name: Any,
    ) -> SocialProfile:
        if not isinstance(subject, str) or not subject.strip() or len(subject.strip()) > 255:
            raise SocialAuthInvalidCredentialError

        normalized_email = None
        if isinstance(email, str) and email.strip():
            try:
                normalized_email = validate_email(
                    email.strip(),
                    check_deliverability=False,
                ).normalized
            except EmailNotValidError:
                normalized_email = None

        normalized_name = ""
        if isinstance(display_name, str):
            normalized_name = WHITESPACE_PATTERN.sub(" ", display_name).strip()[:80]
        return SocialProfile(
            provider=provider,
            subject=subject.strip(),
            email=normalized_email,
            display_name=normalized_name or "User",
        )


_social_auth_client: SocialAuthClient | None = None


def get_social_auth_client() -> SocialAuthClient:
    global _social_auth_client
    if _social_auth_client is None:
        _social_auth_client = SocialAuthClient()
    return _social_auth_client


async def close_social_auth_client() -> None:
    global _social_auth_client
    if _social_auth_client is not None:
        await _social_auth_client.close()
        _social_auth_client = None
