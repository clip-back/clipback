from uuid import UUID

from fastapi import APIRouter, Header, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUserId, DatabaseSession, ShareWriteUserId
from app.integrations.ai_client import get_ai_client
from app.integrations.storage_client import get_storage_client
from app.repositories.category_repository import CategoryRepository
from app.repositories.content_asset_repository import ContentAssetRepository
from app.repositories.content_repository import ContentRepository
from app.repositories.event_repository import EventRepository
from app.repositories.tag_repository import TagRepository
from app.schemas.content import (
    ContentCategoryUpdate,
    ContentCreate,
    ContentFavoriteUpdate,
    ContentRead,
    ContentShareCreate,
    ContentTagUpdate,
    ContentViewCreate,
    ContentViewEvent,
)
from app.services.category_recommendation_service import CategoryRecommendationService
from app.services.content_save_flow import ContentSaveFlow
from app.services.content_service import ContentService
from app.services.extraction_service import ExtractionService
from app.services.share_intake_service import ShareIntakeService

router = APIRouter()


@router.post("", response_model=ContentRead, status_code=status.HTTP_201_CREATED)
async def create_content(
    payload: ContentCreate,
    db: DatabaseSession,
    current_user_id: CurrentUserId,
    idempotency_key: UUID | None = Header(default=None),
) -> ContentRead:
    return await ContentSaveFlow(_build_content_service(db)).save_link(
        user_id=current_user_id,
        payload=payload,
        idempotency_key=idempotency_key,
    )


@router.post("/share", response_model=ContentRead, status_code=status.HTTP_201_CREATED)
async def create_content_from_share(
    payload: ContentShareCreate,
    db: DatabaseSession,
    current_user_id: ShareWriteUserId,
    idempotency_key: UUID | None = Header(default=None),
) -> ContentRead:
    return await ContentSaveFlow(
        _build_content_service(db),
        share_intake=ShareIntakeService(ExtractionService()),
    ).save_shared_link(
        user_id=current_user_id,
        payload=payload,
        idempotency_key=idempotency_key,
    )


@router.get("/{content_id}", response_model=ContentRead)
async def read_content(
    content_id: int,
    db: DatabaseSession,
    current_user_id: CurrentUserId,
) -> ContentRead:
    return await _build_content_service(db).read_content(
        user_id=current_user_id,
        content_id=content_id,
    )


@router.put("/{content_id}/categories", response_model=ContentRead)
async def update_content_categories(
    content_id: int,
    payload: ContentCategoryUpdate,
    db: DatabaseSession,
    current_user_id: CurrentUserId,
) -> ContentRead:
    return await _build_content_service(db).update_categories(
        user_id=current_user_id,
        content_id=content_id,
        payload=payload,
    )


@router.put("/{content_id}/tags", response_model=ContentRead)
async def update_content_tags(
    content_id: int,
    payload: ContentTagUpdate,
    db: DatabaseSession,
    current_user_id: CurrentUserId,
) -> ContentRead:
    return await _build_content_service(db).update_tags(
        user_id=current_user_id,
        content_id=content_id,
        payload=payload,
    )


@router.put("/{content_id}/favorite", response_model=ContentRead)
async def update_content_favorite(
    content_id: int,
    payload: ContentFavoriteUpdate,
    db: DatabaseSession,
    current_user_id: CurrentUserId,
) -> ContentRead:
    return await _build_content_service(db).update_favorite(
        user_id=current_user_id,
        content_id=content_id,
        payload=payload,
    )


@router.delete("/{content_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_content(
    content_id: int,
    db: DatabaseSession,
    current_user_id: CurrentUserId,
) -> Response:
    await _build_content_service(db).delete_content(
        user_id=current_user_id,
        content_id=content_id,
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post(
    "/{content_id}/view",
    response_model=ContentViewEvent,
    status_code=status.HTTP_201_CREATED,
)
async def record_content_view(
    content_id: int,
    db: DatabaseSession,
    current_user_id: CurrentUserId,
    payload: ContentViewCreate | None = None,
) -> ContentViewEvent:
    return await _build_content_service(db).record_view(
        user_id=current_user_id,
        content_id=content_id,
        payload=payload,
    )


def _build_content_service(db: AsyncSession) -> ContentService:
    category_repository = CategoryRepository(db)
    return ContentService(
        content_repository=ContentRepository(db),
        category_repository=category_repository,
        event_repository=EventRepository(db),
        content_asset_repository=ContentAssetRepository(db),
        category_recommendation_service=CategoryRecommendationService(
            category_repository=category_repository,
            ai_client=get_ai_client(),
        ),
        tag_repository=TagRepository(db),
        storage_client=get_storage_client(),
    )
