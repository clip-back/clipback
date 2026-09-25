import json
import logging
from dataclasses import dataclass
from datetime import UTC, datetime

from fastapi import HTTPException

from app.core.config import settings
from app.core.exceptions import InvalidStateError, NotFoundError, SystemConfigurationError
from app.integrations.storage_client import StorageClient
from app.models.content import (
    Content,
    ContentSource as ModelContentSource,
    ContentType as ModelContentType,
)
from app.models.content_asset import AssetType
from app.models.content_event import ContentEvent, ContentEventType
from app.models.recommendation import RecommendationTargetKind, RecommendationType
from app.models.summary_job import SummaryJob
from app.models.tag import Tag
from app.repositories.category_repository import CategoryRepository
from app.repositories.content_asset_repository import ContentAssetRepository
from app.repositories.content_repository import ContentRepository
from app.repositories.event_repository import EventRepository
from app.repositories.recommendation_repository import RecommendationRepository
from app.repositories.tag_repository import TagRepository
from app.schemas.category import CategoryRead
from app.schemas.content import (
    MAX_CONTENT_URL_LENGTH,
    ContentAssetRead,
    ContentAssetType,
    ContentCategoryUpdate,
    ContentCreate,
    ContentFavoriteUpdate,
    ContentRead,
    ContentSource,
    ContentTagUpdate,
    ContentType,
    ContentViewCreate,
    ContentViewEvent,
)
from app.schemas.tag import TagRead
from app.services.category_recommendation_service import (
    CategoryAssignmentMethod,
    CategoryRecommendationFailureReason,
    CategoryRecommendationResult,
    CategoryRecommendationService,
)
from app.services.youtube_url import is_youtube_url, normalize_youtube_url

DEFAULT_CONTENT_TITLE = "저장한 콘텐츠"
DEFAULT_CONTENT_SUMMARY = "요약 정보가 아직 없습니다."
MAX_EVENT_METADATA_LENGTH = 1000

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class PendingContentAsset:
    asset_type: AssetType
    storage_key: str
    mime_type: str | None


def content_to_read(content: Content) -> ContentRead:
    job = getattr(content, "summary_job", None)
    return ContentRead(
        summary_status=job.status if job else "not_requested",
        summary_error_code=job.error_code if job else None,
        id=content.id,
        categories=[
            CategoryRead.model_validate(category)
            for category in sorted(content.categories, key=lambda item: item.id)
        ],
        tags=[
            TagRead.model_validate(tag)
            for tag in sorted(content.tags, key=lambda item: item.id)
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
        tag_repository: TagRepository | None = None,
        storage_client: StorageClient | None = None,
        recommendation_repository: RecommendationRepository | None = None,
    ) -> None:
        self.content_repository = content_repository
        self.category_repository = category_repository
        self.event_repository = event_repository
        self.content_asset_repository = content_asset_repository
        self.category_recommendation_service = category_recommendation_service
        self.tag_repository = tag_repository
        self.storage_client = storage_client
        self.recommendation_repository = recommendation_repository or RecommendationRepository(
            content_repository.session
        )

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

        video_id = None
        if (
            payload.content_type == ContentType.LINK
            and payload.original_url
            and is_youtube_url(str(payload.original_url))
        ):
            url, video_id = normalize_youtube_url(str(payload.original_url))
            payload = payload.model_copy(
                update={"original_url": url, "source": ContentSource.YOUTUBE}
            )
        if payload.original_url and len(str(payload.original_url)) > MAX_CONTENT_URL_LENGTH:
            raise HTTPException(
                status_code=422,
                detail=f"original_url must not exceed {MAX_CONTENT_URL_LENGTH} characters "
                "after normalization",
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
        elif video_id is None and (
            payload.content_type == ContentType.LINK or recommendation_shared_text is not None
        ):
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
            tags = await self._resolve_tags(user_id=user_id, tag_names=payload.tag_names)
            content = await self.content_repository.create(
                user_id=user_id,
                content_type=ModelContentType(payload.content_type.value),
                source=ModelContentSource(payload.source.value),
                title=self._normalize_text(payload.title, DEFAULT_CONTENT_TITLE),
                summary=self._normalize_text(payload.summary, DEFAULT_CONTENT_SUMMARY),
                original_url=str(payload.original_url) if payload.original_url else None,
                is_favorite=payload.is_favorite,
                categories=categories,
                tags=tags,
            )
            if video_id is not None:
                self.content_repository.session.add(
                    SummaryJob(
                        content_id=content.id,
                        video_id=video_id,
                        status="queued" if settings.youtube_summary_enabled else "skipped",
                        error_code=None if settings.youtube_summary_enabled else "disabled",
                        model=settings.gemini_model,
                        apply_title=not bool(payload.title and payload.title.strip()),
                        apply_summary=not bool(payload.summary and payload.summary.strip()),
                        apply_category=not bool(payload.category_ids),
                    )
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
                category_ids_at_event=sorted({category.id for category in content.categories}),
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

    async def update_favorite(
        self,
        *,
        user_id: int,
        content_id: int,
        payload: ContentFavoriteUpdate,
    ) -> ContentRead:
        content = await self.content_repository.get_owned(
            user_id=user_id,
            content_id=content_id,
        )
        if content is None:
            raise NotFoundError("Content not found")
        if content.is_favorite == payload.is_favorite:
            return content_to_read(content)

        try:
            await self.content_repository.set_favorite(
                content=content,
                is_favorite=payload.is_favorite,
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

    async def delete_content(self, *, user_id: int, content_id: int) -> None:
        content = await self.content_repository.get_owned(
            user_id=user_id,
            content_id=content_id,
        )
        if content is None:
            raise NotFoundError("Content not found")

        assets = [(asset.id, asset.storage_key) for asset in content.assets]
        if assets and self.storage_client is None:
            raise SystemConfigurationError("Storage client is not configured")

        try:
            await self.content_repository.delete(content)
            await self.content_repository.session.commit()
        except Exception:
            await self.content_repository.session.rollback()
            raise

        if self.storage_client is None:
            return
        for asset_id, storage_key in assets:
            try:
                await self.storage_client.delete_file(storage_key)
            except Exception:
                logger.exception(
                    "Failed to delete content asset file after database commit: asset_id=%s",
                    asset_id,
                )

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
            for_update=True,
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
        job = getattr(content, "summary_job", None)
        if job is not None:
            job.apply_category = False
        if before_category_ids == after_category_ids:
            if job is not None:
                try:
                    await self.content_repository.session.commit()
                except Exception:
                    await self.content_repository.session.rollback()
                    raise
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

    async def update_tags(
        self,
        *,
        user_id: int,
        content_id: int,
        payload: ContentTagUpdate,
    ) -> ContentRead:
        try:
            content = await self.content_repository.get_owned(
                user_id=user_id,
                content_id=content_id,
                for_update=True,
            )
            if content is None:
                raise NotFoundError("Content not found")
            tags = await self._resolve_tags(user_id=user_id, tag_names=payload.tag_names)
            if sorted(tag.id for tag in content.tags) != sorted(tag.id for tag in tags):
                await self.content_repository.replace_tags(content=content, tags=tags)
            response = content_to_read(content)
            await self.content_repository.session.commit()
        except Exception:
            await self.content_repository.session.rollback()
            raise

        return response

    async def record_view(
        self, user_id: int, content_id: int, payload: ContentViewCreate | None = None
    ) -> ContentViewEvent:
        recommendation_item_id = payload.recommendation_item_id if payload else None
        try:
            content = await self.content_repository.get_owned(
                user_id=user_id, content_id=content_id, for_update=True
            )
            if content is None:
                raise NotFoundError("Content not found")
            existing = (
                await self.event_repository.get_by_client_event_id(
                    user_id=user_id, client_event_id=payload.client_event_id
                )
                if payload else None
            )
            if existing is not None:
                self._validate_view_retry(existing, content_id, recommendation_item_id)
            else:
                if recommendation_item_id is not None:
                    await self._validate_view_recommendation(content, recommendation_item_id)
                viewed_at = datetime.now(UTC)
                event_values = {
                    "user_id": user_id,
                    "content_id": content.id,
                    "category_ids_at_event": sorted(
                        {category.id for category in content.categories}
                    ),
                    "recommendation_item_id": recommendation_item_id,
                    "created_at": viewed_at,
                }
                if payload is None:
                    event = await self.event_repository.create(
                        **event_values, event_type=ContentEventType.CONTENT_REOPENED
                    )
                else:
                    event = await self.event_repository.create_reopened_once(
                        **event_values, client_event_id=payload.client_event_id
                    )
                    if event is None:
                        existing = await self.event_repository.get_by_client_event_id(
                            user_id=user_id, client_event_id=payload.client_event_id
                        )
                        self._validate_view_retry(existing, content_id, recommendation_item_id)
                if event is not None:
                    await self.content_repository.mark_viewed(content, viewed_at=viewed_at)
            await self.content_repository.session.commit()
        except Exception:
            await self.content_repository.session.rollback()
            raise

        return ContentViewEvent(
            content_id=content_id,
            event_type=ContentEventType.CONTENT_REOPENED.value,
        )

    @staticmethod
    def _validate_view_retry(
        event: ContentEvent | None, content_id: int, recommendation_item_id: int | None
    ) -> None:
        if (
            event is None
            or event.event_type != ContentEventType.CONTENT_REOPENED
            or event.content_id != content_id
            or event.recommendation_item_id != recommendation_item_id
        ):
            raise InvalidStateError("Event ID is already used for a different request")

    async def _validate_view_recommendation(
        self, content: Content, recommendation_item_id: int
    ) -> None:
        result = await self.recommendation_repository.get_owned_item(
            user_id=content.user_id, item_id=recommendation_item_id
        )
        if result is None:
            raise NotFoundError("Recommendation item not found")
        item, batch_type = result
        if item.content_id is None and item.category_id is None:
            raise NotFoundError("Recommendation target not found")
        if (
            batch_type == RecommendationType.TODAY
            and item.target_kind == RecommendationTargetKind.CONTENT
            and item.content_id == content.id
        ) or (
            batch_type == RecommendationType.WEEKLY_PICK
            and item.target_kind == RecommendationTargetKind.CATEGORY
            and item.category_id in {category.id for category in content.categories}
        ):
            return
        raise HTTPException(status_code=422, detail="Recommendation does not match content")

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

    async def _resolve_tags(self, *, user_id: int, tag_names: list[str]) -> list[Tag]:
        if not tag_names:
            return []
        if self.tag_repository is None:
            raise SystemConfigurationError("Tag repository is not configured")
        return await self.tag_repository.get_or_create_many(user_id=user_id, names=tag_names)

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
