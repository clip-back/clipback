from fastapi import APIRouter, status

from app.schemas.content import ContentCreate, ContentRead, ContentViewEvent
from app.services.content_service import ContentService

router = APIRouter()


@router.post("", response_model=ContentRead, status_code=status.HTTP_201_CREATED)
async def create_content(payload: ContentCreate) -> ContentRead:
    return await ContentService().create_placeholder(payload)


@router.get("/{content_id}", response_model=ContentRead)
async def read_content(content_id: int) -> ContentRead:
    return await ContentService().read_placeholder(content_id)


@router.post("/{content_id}/view", response_model=ContentViewEvent, status_code=status.HTTP_201_CREATED)
async def record_content_view(content_id: int) -> ContentViewEvent:
    return ContentViewEvent(content_id=content_id, event_type="content_reopened")

