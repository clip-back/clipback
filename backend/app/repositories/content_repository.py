from collections.abc import Sequence
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.category import Category
from app.models.content import Content, ContentSource, ContentType
from app.models.content_category import content_categories
from app.models.tag import Tag


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

    async def get_owned(self, *, user_id: int, content_id: int) -> Content | None:
        result = await self.session.scalars(
            select(Content)
            .options(
                selectinload(Content.categories),
                selectinload(Content.tags),
                selectinload(Content.assets),
            )
            .where(Content.id == content_id, Content.user_id == user_id)
        )
        return result.first()

    async def list_feed(
        self,
        *,
        user_id: int,
        category_id: int | None,
        cursor_id: int | None,
        limit: int,
        is_favorite: bool | None = None,
    ) -> list[Content]:
        statement = (
            select(Content)
            .options(
                selectinload(Content.categories),
                selectinload(Content.tags),
                selectinload(Content.assets),
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

        if cursor_id is not None:
            statement = statement.where(Content.id < cursor_id)

        statement = statement.order_by(Content.saved_at.desc(), Content.id.desc()).limit(limit)

        result = await self.session.scalars(statement)
        return list(result)

    async def mark_viewed(self, content: Content) -> Content:
        content.last_viewed_at = datetime.now(UTC)
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
