from typing import Annotated

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import AuthenticationError
from app.core.security import decode_access_token
from app.db.session import get_db
from app.repositories.auth_session_repository import AuthSessionRepository
from app.repositories.user_repository import UserRepository


bearer_scheme = HTTPBearer(auto_error=False)


async def get_current_user_id(
    db: AsyncSession = Depends(get_db),
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> int:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise AuthenticationError()

    claims = decode_access_token(credentials.credentials)
    auth_session = await AuthSessionRepository(db).get_active(
        session_id=claims.session_id,
        user_id=claims.user_id,
    )
    if auth_session is None:
        raise AuthenticationError()

    user = await UserRepository(db).get(claims.user_id)
    if user is None:
        raise AuthenticationError()
    return user.id


DatabaseSession = Annotated[AsyncSession, Depends(get_db)]
CurrentUserId = Annotated[int, Depends(get_current_user_id)]
