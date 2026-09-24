from collections.abc import Sequence
from datetime import datetime

from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.category import Category
from app.models.content import Content, ContentSource, ContentType
from app.models.content_category import content_categories
from app.models.tag import Tag
from app.schemas.feed import FeedCursor

SEARCH_PATTERN_ESCAPE = "\\"


class ContentRepository:
    """Data access for saved link and screenshot content."""

    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def create(
        self,
        *,
        user_id: int,
        content_type: ContentType,
        source: ContentSource,
        title: str,
        summary: str,
        original_url: str | None,
        is_favorite: bool,
        categories: Sequence[Category],
        tags: Sequence[Tag],
    ) -> Content:
        content = Content(
            user_id=user_id,
            content_type=content_type,
            source=source,
            title=title,
            summary=summary,
            original_url=original_url,
            is_favorite=is_favorite,
        )
        content.categories = list(categories)
        content.tags = list(tags)
        self.session.add(content)
        await self.session.flush()
        return content

    async def get_owned(
        self,
        *,
        user_id: int,
        content_id: int,
        for_update: bool = False,
    ) -> Content | None:
        if for_update:
            await self.session.execute(
                select(Content.id)
                .where(
                    Content.id == content_id,
                    Content.user_id == user_id,
                )
                .with_for_update()
            )
        result = await self.session.scalars(
            select(Content)
            .options(
                selectinload(Content.categories),
                selectinload(Content.tags),
                selectinload(Content.assets),
                selectinload(Content.summary_job),
            )
            .where(Content.id == content_id, Content.user_id == user_id)
            .execution_options(populate_existing=True)
        )
        return result.first()

    async def get_feed_cursor(self, *, user_id: int, content_id: int) -> FeedCursor | None:
        result = await self.session.execute(
            select(Content.saved_at, Content.id).where(
                Content.user_id == user_id, Content.id == content_id
            )
        )
        row = result.one_or_none()
        return FeedCursor(saved_at=row.saved_at, id=row.id) if row is not None else None

    async def list_feed(
        self,
        *,
        user_id: int,
        category_id: int | None,
        cursor: FeedCursor | None,
        limit: int,
        is_favorite: bool | None = None,
        search_query: str | None = None,
    ) -> list[Content]:
        statement = (
            select(Content)
            .options(
                selectinload(Content.categories),
                selectinload(Content.tags),
                selectinload(Content.assets),
                selectinload(Content.summary_job),
            )
            .where(Content.user_id == user_id)
        )

        if category_id is not None:
            statement = statement.join(
                content_categories,
                Content.id == content_categories.c.content_id,
            ).where(content_categories.c.category_id == category_id)

        if is_favorite is not None:
            statement = statement.where(Content.is_favorite == is_favorite)

        if search_query is not None:
            pattern = self._build_search_pattern(search_query)
            tag_pattern = self._build_search_pattern(search_query.casefold())
            statement = statement.where(
                or_(
                    Content.title.ilike(pattern, escape=SEARCH_PATTERN_ESCAPE),
                    Content.summary.ilike(pattern, escape=SEARCH_PATTERN_ESCAPE),
                    Content.tags.any(
                        Tag.normalized_name.ilike(
                            tag_pattern,
                            escape=SEARCH_PATTERN_ESCAPE,
                        )
                    ),
                )
            )

        if cursor is not None:
            statement = statement.where(
                or_(
                    Content.saved_at < cursor.saved_at,
                    and_(Content.saved_at == cursor.saved_at, Content.id < cursor.id),
                )
            )

        statement = statement.order_by(Content.saved_at.desc(), Content.id.desc()).limit(limit)

        result = await self.session.scalars(statement)
        return list(result)

    @staticmethod
    def _build_search_pattern(search_query: str) -> str:
        escaped = search_query.replace(SEARCH_PATTERN_ESCAPE, "\\\\")
        escaped = escaped.replace("%", "\\%").replace("_", "\\_")
        return f"%{escaped}%"

    async def mark_viewed(self, content: Content, *, viewed_at: datetime) -> Content:
        content.open_count += 1
        content.last_viewed_at = viewed_at
        await self.session.flush()
        return content

    async def set_favorite(self, *, content: Content, is_favorite: bool) -> Content:
        content.is_favorite = is_favorite
        await self.session.flush()
        return content

    async def delete(self, content: Content) -> None:
        await self.session.delete(content)
        await self.session.flush()

    async def replace_categories(
        self,
        *,
        content: Content,
        categories: Sequence[Category],
    ) -> Content:
        content.categories = list(categories)
        await self.session.flush()
        return content

    async def replace_tags(
        self,
        *,
        content: Content,
        tags: Sequence[Tag],
    ) -> Content:
        content.tags = list(tags)
        await self.session.flush()
        return content

    async def lock_category_contents(self, user_id: int, category_id: int) -> list[int]:
        result = await self.session.scalars(
            select(Content.id)
            .join(content_categories)
            .where(
                Content.user_id == user_id,
                content_categories.c.category_id == category_id,
            )
            .order_by(Content.id)
            .with_for_update(of=Content)
        )
        return list(result)
