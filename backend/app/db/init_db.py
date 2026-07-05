from sqlalchemy.ext.asyncio import AsyncEngine

from app.db.base import Base
from app.models import category, content, content_asset, content_event, tag, user  # noqa: F401


async def init_db(engine: AsyncEngine) -> None:
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)

