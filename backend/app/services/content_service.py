import json
from dataclasses import dataclass

from fastapi import HTTPException

from app.core.config import settings
from app.core.exceptions import NotFoundError, SystemConfigurationError
from app.models.content import (
    Content,
    ContentSource as ModelContentSource,
    ContentType as ModelContentType,
)
from app.models.content_asset import AssetType
from app.models.content_event import ContentEventType
from app.repositories.category_repository import CategoryRepository
from app.repositories.content_asset_repository import ContentAssetRepository
from app.repositories.content_repository import ContentRepository
from app.repositories.event_repository import EventRepository
from app.schemas.category import CategoryRead
from app.schemas.content import (
    ContentAssetRead,
    ContentAssetType,
    ContentCategoryUpdate,
    ContentCreate,
    ContentRead,
    ContentSource,
    ContentType,
    ContentViewEvent,
)
from app.services.category_recommendation_service import (
    CategoryAssignmentMethod,
    CategoryRecommendationFailureReason,
    CategoryRecommendationResult,
    CategoryRecommendationService,
)

DEFAULT_CONTENT_TITLE = "저장한 콘텐츠"
DEFAULT_CONTENT_SUMMARY = "요약 정보가 아직 없습니다."
MAX_EVENT_METADATA_LENGTH = 1000


@dataclass(frozen=True)
class PendingContentAsset:
    asset_type: AssetType
    storage_key: str
    mime_type: str | None


def content_to_read(content: Content) -> ContentRead:
    return ContentRead(
        id=content.id,
        categories=[
            CategoryRead.model_validate(category)
            for category in sorted(content.categories, key=lambda item: item.id)
        ],
        assets=[
            ContentAssetRead(
                id=asset.id,
                asset_type=ContentAssetType(asset.asset_type.value),
                mime_type=asset.mime_type,
                download_url=f"{settings.api_v1_prefix}/uploads/assets/{asset.id}",
            )
            for asset in sorted(content.assets, key=lambda item: item.id)
        ],
        content_type=ContentType(content.content_type.value),
        source=ContentSource(content.source.value),
        title=content.title,
        summary=content.summary,
        original_url=content.original_url,
        is_favorite=content.is_favorite,
        saved_at=content.saved_at,
        last_viewed_at=content.last_viewed_at,
    )


class ContentService:
    def __init__(
        self,
        content_repository: ContentRepository,
        category_repository: CategoryRepository,
        event_repository: EventRepository,
        content_asset_repository: ContentAssetRepository | None = None,
        category_recommendation_service: CategoryRecommendationService | None = None,
    ) -> None:
        self.content_repository = content_repository
        self.category_repository = category_repository
        self.event_repository = event_repository
        self.content_asset_repository = content_asset_repository
        self.category_recommendation_service = category_recommendation_service

    async def create_content(
        self,
        user_id: int,
        payload: ContentCreate,
        event_metadata_json: str | None = None,
        recommendation_shared_text: str | None = None,
        asset: PendingContentAsset | None = None,
    ) -> ContentRead:
        if payload.content_type == ContentType.LINK and payload.original_url is None:
            raise HTTPException(
                status_code=422,
                detail="original_url is required for link content",
            )

        category_ids = self._deduplicate_ids(payload.category_ids)
        if category_ids:
            categories = await self.category_repository.list_available_by_ids(
                user_id=user_id,
                category_ids=category_ids,
            )
            if len(categories) != len(category_ids):
                raise NotFoundError("Category not found")
            category_by_id = {category.id: category for category in categories}
            categories = [category_by_id[category_id] for category_id in category_ids]
            recommendation = CategoryRecommendationResult(
                category_id=None,
                assignment_method=CategoryAssignmentMethod.USER,
                failure_reason=None,
            )
        elif payload.content_type == ContentType.LINK:
            recommendation = await self._recommend_category(
                user_id=user_id,
                payload=payload,
                shared_text=recommendation_shared_text,
            )
            categories = []
            if recommendation.category_id is not None:
                categories = await self.category_repository.list_available_by_ids(
                    user_id=user_id,
                    category_ids=[recommendation.category_id],
                )
                if not categories:
                    recommendation = CategoryRecommendationResult(
                        category_id=recommendation.category_id,
                        assignment_method=CategoryAssignmentMethod.UNCATEGORIZED,
                        failure_reason=CategoryRecommendationFailureReason.ERROR,
                    )
            if not categories:
                categories = [await self._get_uncategorized()]
        else:
            categories = [await self._get_uncategorized()]
            recommendation = CategoryRecommendationResult(
                category_id=None,
                assignment_method=CategoryAssignmentMethod.UNCATEGORIZED,
                failure_reason=None,
            )

        event_metadata_json = self._build_event_metadata_json(
            event_metadata_json,
            recommendation,
        )

        if asset is not None and self.content_asset_repository is None:
            raise SystemConfigurationError("Content asset repository is not configured")

        try:
            content = await self.content_repository.create(
                user_id=user_id,
                content_type=ModelContentType(payload.content_type.value),
                source=ModelContentSource(payload.source.value),
                title=self._normalize_text(payload.title, DEFAULT_CONTENT_TITLE),
                summary=self._normalize_text(payload.summary, DEFAULT_CONTENT_SUMMARY),
                original_url=str(payload.original_url) if payload.original_url else None,
                is_favorite=payload.is_favorite,
                categories=categories,
            )
            if asset is not None:
                await self.content_asset_repository.create(
                    content_id=content.id,
                    asset_type=asset.asset_type,
                    storage_key=asset.storage_key,
                    mime_type=asset.mime_type,
                )
            await self.event_repository.create(
                user_id=user_id,
                content_id=content.id,
                event_type=ContentEventType.CONTENT_CREATED,
                metadata_json=event_metadata_json,
            )
            created_content = await self.content_repository.get_owned(
                user_id=user_id,
                content_id=content.id,
            )
            if created_content is None:
                raise NotFoundError("Content not found")
            response = content_to_read(created_content)
            await self.content_repository.session.commit()
        except Exception:
            await self.content_repository.session.rollback()
            raise

        return response

    async def read_content(self, user_id: int, content_id: int) -> ContentRead:
        content = await self.content_repository.get_owned(user_id=user_id, content_id=content_id)
        if content is None:
            raise NotFoundError("Content not found")
        return content_to_read(content)

    async def update_categories(
        self,
        *,
        user_id: int,
        content_id: int,
        payload: ContentCategoryUpdate,
    ) -> ContentRead:
        content = await self.content_repository.get_owned(
            user_id=user_id,
            content_id=content_id,
        )
        if content is None:
            raise NotFoundError("Content not found")

        category_ids = self._deduplicate_ids(payload.category_ids)
        if category_ids:
            categories = await self.category_repository.list_available_by_ids(
                user_id=user_id,
                category_ids=category_ids,
            )
            if len(categories) != len(category_ids):
                raise NotFoundError("Category not found")
            category_by_id = {category.id: category for category in categories}
            categories = [category_by_id[category_id] for category_id in category_ids]
            if len(categories) > 1 and any(
                category.name == "미분류" and category.is_default for category in categories
            ):
                raise HTTPException(
                    status_code=422,
                    detail="Uncategorized category cannot be combined with other categories",
                )
        else:
            categories = [await self._get_uncategorized()]

        before_category_ids = sorted(category.id for category in content.categories)
        after_category_ids = sorted(category.id for category in categories)
        if before_category_ids == after_category_ids:
            return content_to_read(content)

        metadata_json = json.dumps(
            {
                "before_category_ids": before_category_ids,
                "after_category_ids": after_category_ids,
            },
            ensure_ascii=False,
            separators=(",", ":"),
        )

        try:
            await self.content_repository.replace_categories(
                content=content,
                categories=categories,
            )
            await self.event_repository.create(
                user_id=user_id,
                content_id=content.id,
                event_type=ContentEventType.CATEGORY_CHANGED,
                metadata_json=metadata_json,
            )
            await self.content_repository.session.commit()
        except Exception:
            await self.content_repository.session.rollback()
            raise

        updated_content = await self.content_repository.get_owned(
            user_id=user_id,
            content_id=content_id,
        )
        if updated_content is None:
            raise NotFoundError("Content not found")
        return content_to_read(updated_content)

    async def record_view(self, user_id: int, content_id: int) -> ContentViewEvent:
        content = await self.content_repository.get_owned(user_id=user_id, content_id=content_id)
        if content is None:
            raise NotFoundError("Content not found")

        try:
            await self.content_repository.mark_viewed(content)
            await self.event_repository.create(
                user_id=user_id,
                content_id=content.id,
                event_type=ContentEventType.CONTENT_REOPENED,
            )
            await self.content_repository.session.commit()
        except Exception:
            await self.content_repository.session.rollback()
            raise

        return ContentViewEvent(
            content_id=content.id,
            event_type=ContentEventType.CONTENT_REOPENED.value,
        )

    async def _recommend_category(
        self,
        *,
        user_id: int,
        payload: ContentCreate,
        shared_text: str | None,
    ) -> CategoryRecommendationResult:
        if self.category_recommendation_service is None:
            return CategoryRecommendationResult(
                category_id=None,
                assignment_method=CategoryAssignmentMethod.UNCATEGORIZED,
                failure_reason=CategoryRecommendationFailureReason.ERROR,
            )
        return await self.category_recommendation_service.recommend(
            user_id=user_id,
            payload=payload,
            shared_text=shared_text,
        )

    async def _get_uncategorized(self):
        uncategorized = await self.category_repository.get_uncategorized()
        if uncategorized is None:
            raise SystemConfigurationError("Uncategorized category is not configured")
        return uncategorized

    @staticmethod
    def _build_event_metadata_json(
        base_json: str | None,
        recommendation: CategoryRecommendationResult,
    ) -> str:
        metadata: dict[str, object] = {}
        if base_json:
            parsed = json.loads(base_json)
            if isinstance(parsed, dict):
                metadata.update(parsed)
        metadata.update(
            category_assignment_method=recommendation.assignment_method.value,
            recommended_category_id=recommendation.category_id,
            category_recommendation_failure_reason=(
                recommendation.failure_reason.value if recommendation.failure_reason else None
            ),
        )

        serialized = json.dumps(metadata, ensure_ascii=False, separators=(",", ":"))
        while len(serialized) > MAX_EVENT_METADATA_LENGTH:
            string_fields = {
                key: value
                for key, value in metadata.items()
                if isinstance(value, str) and value
            }
            if not string_fields:
                break
            key = max(string_fields, key=lambda item: len(string_fields[item]))
            overflow = len(serialized) - MAX_EVENT_METADATA_LENGTH
            metadata[key] = string_fields[key][: max(0, len(string_fields[key]) - overflow)]
            serialized = json.dumps(metadata, ensure_ascii=False, separators=(",", ":"))
        return serialized

    @staticmethod
    def _deduplicate_ids(category_ids: list[int]) -> list[int]:
        return list(dict.fromkeys(category_ids))

    @staticmethod
    def _normalize_text(value: str | None, default: str) -> str:
        if value is None:
            return default
        normalized = value.strip()
        return normalized or default
