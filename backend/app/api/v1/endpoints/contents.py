from fastapi import APIRouter, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUserId, DatabaseSession
from app.integrations.ai_client import get_ai_client
from app.repositories.category_repository import CategoryRepository
from app.repositories.content_repository import ContentRepository
from app.repositories.event_repository import EventRepository
from app.schemas.content import (
    ContentCategoryUpdate,
    ContentCreate,
    ContentRead,
    ContentShareCreate,
    ContentType,
    ContentViewEvent,
)
from app.services.content_service import ContentService
from app.services.category_recommendation_service import CategoryRecommendationService
from app.services.extraction_service import ExtractionService
from app.services.share_intake_service import ShareIntakeService

router = APIRouter()


@router.post("", response_model=ContentRead, status_code=status.HTTP_201_CREATED)
async def create_content(
    payload: ContentCreate,
    db: DatabaseSession,
    current_user_id: CurrentUserId,
) -> ContentRead:
    if payload.content_type != ContentType.LINK:
        return await _build_content_service(db).create_content(
            user_id=current_user_id,
            payload=payload,
        )

    extraction_service = ExtractionService()
    extraction = await extraction_service.enrich_link(payload)
    return await _build_content_service(db).create_content(
        user_id=current_user_id,
        payload=extraction_service.apply_to_payload(payload, extraction),
        event_metadata_json=extraction_service.build_event_metadata_json(extraction),
    )


@router.post("/share", response_model=ContentRead, status_code=status.HTTP_201_CREATED)
async def create_content_from_share(
    payload: ContentShareCreate,
    db: DatabaseSession,
    current_user_id: CurrentUserId,
) -> ContentRead:
    return await ShareIntakeService(
        content_service=_build_content_service(db),
        extraction_service=ExtractionService(),
    ).create_instagram_content(
        user_id=current_user_id,
        payload=payload,
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


@router.post(
    "/{content_id}/view",
    response_model=ContentViewEvent,
    status_code=status.HTTP_201_CREATED,
)
async def record_content_view(
    content_id: int,
    db: DatabaseSession,
    current_user_id: CurrentUserId,
) -> ContentViewEvent:
    return await _build_content_service(db).record_view(
        user_id=current_user_id,
        content_id=content_id,
    )


def _build_content_service(db: AsyncSession) -> ContentService:
    category_repository = CategoryRepository(db)
    return ContentService(
        content_repository=ContentRepository(db),
        category_repository=category_repository,
        event_repository=EventRepository(db),
        category_recommendation_service=CategoryRecommendationService(
            category_repository=category_repository,
            ai_client=get_ai_client(),
        ),
    )
