from fastapi import APIRouter, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUserId, DatabaseSession
from app.repositories.category_repository import CategoryRepository
from app.repositories.content_repository import ContentRepository
from app.repositories.event_repository import EventRepository
from app.schemas.content import ContentCreate, ContentRead, ContentShareCreate, ContentViewEvent
from app.services.content_service import ContentService
from app.services.share_intake_service import ShareIntakeService

router = APIRouter()


@router.post("", response_model=ContentRead, status_code=status.HTTP_201_CREATED)
async def create_content(
    payload: ContentCreate,
    db: DatabaseSession,
    current_user_id: CurrentUserId,
) -> ContentRead:
    return await _build_content_service(db).create_content(
        user_id=current_user_id,
        payload=payload,
    )


@router.post("/share", response_model=ContentRead, status_code=status.HTTP_201_CREATED)
async def create_content_from_share(
    payload: ContentShareCreate,
    db: DatabaseSession,
    current_user_id: CurrentUserId,
) -> ContentRead:
    return await ShareIntakeService(
        content_service=_build_content_service(db),
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
    return ContentService(
        content_repository=ContentRepository(db),
        category_repository=CategoryRepository(db),
        event_repository=EventRepository(db),
    )
