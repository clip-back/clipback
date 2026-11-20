from collections.abc import Sequence

from sqlalchemy import Integer, String, column, func, literal, select, values
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
        await self._insert_missing(
            user_id,
            {key: name for key, name in normalized_to_name.items() if key not in existing_names},
        )

        tags = await self._list_by_normalized_names(
            user_id=user_id,
            normalized_names=normalized_names,
            lock=True,
        )
        tags_by_name = {tag.normalized_name: tag for tag in tags}
        # Cleanup can remove a previously seen orphan before the locking lookup.
        missing = {key: name for key, name in normalized_to_name.items() if key not in tags_by_name}
        if missing:
            await self._insert_missing(user_id, missing)
            recreated = await self._list_by_normalized_names(
                user_id=user_id,
                normalized_names=list(missing),
                lock=True,
            )
            tags_by_name.update((tag.normalized_name, tag) for tag in recreated)
        return [tags_by_name[normalized_name] for normalized_name in normalized_names]

    async def _insert_missing(self, user_id: int, names: dict[str, str]) -> None:
        if not names:
            return
        pending = values(
            column("position", Integer),
            column("name", String),
            column("normalized_name", String),
            name="pending_tags",
        ).data([(position, name, key) for position, (key, name) in enumerate(names.items())])
        # Preserve the API's ID order while acquiring unique keys in a consistent order.
        identified = (
            select(
                func.nextval(func.pg_get_serial_sequence("tags", "id")).label("id"),
                pending.c.name,
                pending.c.normalized_name,
            )
            .order_by(pending.c.position)
            .cte("new_tags")
            .prefix_with("MATERIALIZED")
        )
        statement = insert(Tag).from_select(
            [Tag.id, Tag.user_id, Tag.name, Tag.normalized_name],
            select(
                identified.c.id, literal(user_id), identified.c.name, identified.c.normalized_name
            ).order_by(identified.c.normalized_name),
        )
        statement = statement.on_conflict_do_nothing(constraint="uq_tags_user_id_normalized_name")
        await self.session.execute(statement)
        await self.session.flush()

    async def _list_by_normalized_names(
        self,
        *,
        user_id: int,
        normalized_names: Sequence[str],
        lock: bool = False,
    ) -> list[Tag]:
        statement = select(Tag).where(
            Tag.user_id == user_id,
            Tag.normalized_name.in_(normalized_names),
        )
        if lock:
            statement = statement.with_for_update(read=True, key_share=True)
        return list(await self.session.scalars(statement))
