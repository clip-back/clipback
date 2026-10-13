import hashlib
import secrets
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from uuid import uuid4

from jose import JWTError, jwt

from app.core.config import settings
from app.core.exceptions import AuthenticationError

ALGORITHM = "HS256"


@dataclass(frozen=True)
class AccessTokenClaims:
    user_id: int
    session_id: int
    expires_at: datetime


def create_access_token(
    *,
    user_id: int,
    session_id: int,
    expires_delta: timedelta | None = None,
    now: datetime | None = None,
) -> str:
    issued_at = now or datetime.now(UTC)
    expire = issued_at + (
        expires_delta or timedelta(minutes=settings.access_token_expire_minutes)
    )
    payload = {
        "sub": str(user_id),
        "sid": session_id,
        "type": "access",
        "iat": issued_at,
        "exp": expire,
        "jti": str(uuid4()),
    }
    return jwt.encode(payload, settings.secret_key, algorithm=ALGORITHM)


def decode_access_token(token: str) -> AccessTokenClaims:
    try:
        payload = jwt.decode(token, settings.secret_key, algorithms=[ALGORITHM])
        if payload.get("type") != "access":
            raise AuthenticationError()
        user_id = int(payload["sub"])
        session_id = int(payload["sid"])
        expires_at = datetime.fromtimestamp(float(payload["exp"]), UTC)
        if user_id <= 0 or session_id <= 0:
            raise AuthenticationError()
    except (JWTError, KeyError, TypeError, ValueError, OverflowError) as exc:
        raise AuthenticationError() from exc

    return AccessTokenClaims(
        user_id=user_id, session_id=session_id,
        expires_at=expires_at,
    )


def generate_refresh_token() -> str:
    return secrets.token_urlsafe(48)


def hash_refresh_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


SHARE_WRITE_SCOPE = "share:write"


def create_share_token(*, user_id: int, session_id: int, expires_at: datetime) -> str:
    return jwt.encode(
        {"sub": str(user_id), "sid": session_id, "type": "share",
         "scope": SHARE_WRITE_SCOPE, "exp": expires_at,
         "iat": datetime.now(UTC), "jti": str(uuid4())},
        settings.secret_key, algorithm=ALGORITHM,
    )


def decode_share_write_token(token: str) -> AccessTokenClaims:
    try:
        payload = jwt.decode(token, settings.secret_key, algorithms=[ALGORITHM])
        if payload.get("type") == "access":
            return decode_access_token(token)
        if payload.get("type") != "share" or payload.get("scope") != SHARE_WRITE_SCOPE:
            raise AuthenticationError()
        user_id, session_id = int(payload["sub"]), int(payload["sid"])
        expires_at = datetime.fromtimestamp(float(payload["exp"]), UTC)
        if user_id <= 0 or session_id <= 0:
            raise AuthenticationError()
        return AccessTokenClaims(user_id, session_id, expires_at)
    except (JWTError, KeyError, TypeError, ValueError, OverflowError) as exc:
        raise AuthenticationError() from exc
