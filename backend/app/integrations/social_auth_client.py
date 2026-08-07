from __future__ import annotations

import asyncio
import re
from dataclasses import dataclass
from time import monotonic
from typing import Any

import httpx
from email_validator import EmailNotValidError, validate_email
from jose import JWTError, jwt

from app.core.config import Settings, settings
from app.models.social_identity import SocialProvider

GOOGLE_JWKS_URL = "https://www.googleapis.com/oauth2/v3/certs"
GOOGLE_ISSUERS = {"accounts.google.com", "https://accounts.google.com"}
KAKAO_JWKS_URL = "https://kauth.kakao.com/.well-known/jwks.json"
KAKAO_ISSUERS = {"https://kauth.kakao.com"}
NAVER_PROFILE_URL = "https://openapi.naver.com/v1/nid/me"
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
        if self.config.kakao_rest_api_key is None:
            raise SocialAuthNotConfiguredError
        audience = self.config.kakao_rest_api_key.get_secret_value().strip()
        if not audience:
            raise SocialAuthNotConfiguredError

        claims = await self._decode_oidc_token(
            token=token,
            jwks_url=KAKAO_JWKS_URL,
            issuers=KAKAO_ISSUERS,
            audiences={audience},
        )
        email = claims.get("email") if claims.get("email_verified") is True else None
        return self._build_profile(
            provider=SocialProvider.KAKAO,
            subject=claims["sub"],
            email=email,
            display_name=claims.get("nickname"),
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
                options={
                    "require_exp": True,
                    "require_sub": True,
                    "verify_aud": False,
                    "verify_iss": False,
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
