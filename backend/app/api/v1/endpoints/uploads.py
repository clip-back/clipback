from fastapi import APIRouter, File, Form, Response, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUserId, DatabaseSession
from app.core.config import settings
from app.integrations.storage_client import LocalStorageClient
from app.repositories.category_repository import CategoryRepository
from app.repositories.content_asset_repository import ContentAssetRepository
from app.repositories.content_repository import ContentRepository
from app.repositories.event_repository import EventRepository
from app.schemas.content import ContentRead
from app.services.content_service import ContentService
from app.services.upload_service import UploadService

router = APIRouter()


@router.post("/screenshots", response_model=ContentRead, status_code=status.HTTP_201_CREATED)
async def upload_screenshot(
    db: DatabaseSession,
    current_user_id: CurrentUserId,
    file: UploadFile = File(...),
    category_ids: list[int] = Form(default_factory=list),
) -> ContentRead:
    return await _build_upload_service(db).upload_screenshot(
        user_id=current_user_id,
        file=file,
        category_ids=category_ids,
    )


@router.get(
    "/assets/{asset_id}",
    response_class=Response,
    responses={
        200: {
            "content": {
                "image/png": {},
                "image/jpeg": {},
                "image/webp": {},
            }
        }
    },
)
async def read_asset(
    asset_id: int,
    db: DatabaseSession,
    current_user_id: CurrentUserId,
) -> Response:
    stored_asset = await _build_upload_service(db).read_asset(
        user_id=current_user_id,
        asset_id=asset_id,
    )
    return Response(
        content=stored_asset.content,
        media_type=stored_asset.mime_type,
        headers={
            "Content-Disposition": "inline",
            "X-Content-Type-Options": "nosniff",
        },
    )


def _build_upload_service(db: AsyncSession) -> UploadService:
    content_asset_repository = ContentAssetRepository(db)
    return UploadService(
        content_service=ContentService(
            content_repository=ContentRepository(db),
            category_repository=CategoryRepository(db),
            event_repository=EventRepository(db),
            content_asset_repository=content_asset_repository,
        ),
        content_asset_repository=content_asset_repository,
        storage_client=LocalStorageClient(settings.storage_root),
    )
