from collections.abc import AsyncIterator

from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

import app.models  # noqa: F401
from app.core.config import settings

engine = create_async_engine(settings.database_url, future=True)
AsyncSessionLocal = async_sessionmaker(engine, expire_on_commit=False)


def create_recommendation_engine(database_url: str) -> AsyncEngine:
    # A save already holds a connection. Recommendation recording must have its own pool.
    return create_async_engine(
        database_url, pool_size=2, max_overflow=0, pool_timeout=2, pool_pre_ping=True,
    )


recommendation_engine = create_recommendation_engine(settings.database_url)
RecommendationSessionLocal = async_sessionmaker(recommendation_engine)


async def get_db() -> AsyncIterator[AsyncSession]:
    async with AsyncSessionLocal() as session:
        yield session
