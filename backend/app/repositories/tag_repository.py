from collections.abc import Sequence

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.tag import Tag


class TagRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get_or_create_many(self, *, user_id: int, names: Sequence[str]) -> list[Tag]:
        if not names:
            return []

        normalized_to_name = {name.casefold(): name for name in names}
        normalized_names = list(normalized_to_name)
        existing = await self._list_by_normalized_names(
            user_id=user_id,
            normalized_names=normalized_names,
        )
        existing_names = {tag.normalized_name for tag in existing}
        missing = [
            {
                "user_id": user_id,
                "name": normalized_to_name[normalized_name],
                "normalized_name": normalized_name,
            }
            for normalized_name in normalized_names
            if normalized_name not in existing_names
        ]
        if missing:
            statement = insert(Tag).values(missing)
            statement = statement.on_conflict_do_nothing(
                constraint="uq_tags_user_id_normalized_name"
            )
            await self.session.execute(statement)
            await self.session.flush()

        tags = await self._list_by_normalized_names(
            user_id=user_id,
            normalized_names=normalized_names,
        )
        tags_by_name = {tag.normalized_name: tag for tag in tags}
        return [tags_by_name[normalized_name] for normalized_name in normalized_names]

    async def _list_by_normalized_names(
        self,
        *,
        user_id: int,
        normalized_names: Sequence[str],
    ) -> list[Tag]:
        result = await self.session.scalars(
            select(Tag).where(
                Tag.user_id == user_id,
                Tag.normalized_name.in_(normalized_names),
            )
        )
        return list(result)
