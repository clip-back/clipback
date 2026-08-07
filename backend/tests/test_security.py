from datetime import UTC, datetime, timedelta

import pytest
from jose import jwt

from app.core.config import settings
from app.core.exceptions import AuthenticationError
from app.core.security import ALGORITHM, create_access_token, decode_access_token


def test_access_token_round_trip() -> None:
    token = create_access_token(user_id=7, session_id=11)

    claims = decode_access_token(token)

    assert claims.user_id == 7
    assert claims.session_id == 11


def test_decode_rejects_expired_token() -> None:
    token = create_access_token(
        user_id=1,
        session_id=1,
        expires_delta=timedelta(seconds=-1),
        now=datetime.now(UTC),
    )

    with pytest.raises(AuthenticationError):
        decode_access_token(token)

@pytest.mark.parametrize(
    "payload",
    [
        {"sub": "1", "sid": 1, "type": "refresh"},
        {"sub": "1", "type": "access"},
        {"sid": 1, "type": "access"},
        {"sub": "invalid", "sid": 1, "type": "access"},
    ],
)
def test_decode_rejects_invalid_claims(payload: dict[str, str | int]) -> None:
    payload = {
        **payload,
        "exp": datetime.now(UTC) + timedelta(minutes=5),
    }
    token = jwt.encode(payload, settings.secret_key, algorithm=ALGORITHM)

    with pytest.raises(AuthenticationError):
        decode_access_token(token)


def test_decode_rejects_invalid_signature() -> None:
    token = jwt.encode(
        {
            "sub": "1",
            "sid": 1,
            "type": "access",
            "exp": datetime.now(UTC) + timedelta(minutes=5),
        },
        "wrong-secret",
        algorithm=ALGORITHM,
    )

    with pytest.raises(AuthenticationError):
        decode_access_token(token)
