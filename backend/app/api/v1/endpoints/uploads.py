from uuid import UUID

from fastapi import APIRouter, File, Form, Header, Response, UploadFile, status
from fastapi.exceptions import RequestValidationError
from pydantic import ValidationError
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUserId, DatabaseSession, ShareWriteUserId
from app.integrations.ai_client import get_ai_client
from app.integrations.ocr_client import get_ocr_client
from app.integrations.storage_client import get_storage_client
from app.repositories.category_repository import CategoryRepository
from app.repositories.content_asset_repository import ContentAssetRepository
from app.repositories.content_repository import ContentRepository
from app.repositories.event_repository import EventRepository
from app.repositories.tag_repository import TagRepository
from app.schemas.content import ContentAssetAccess, ContentRead
from app.schemas.tag import TagNamesPayload
from app.services.category_recommendation_service import CategoryRecommendationService
from app.services.content_service import ContentService
from app.services.image_storage_control import ImageUploadControl
from app.services.upload_service import UploadService

router = APIRouter()


@router.post("/screenshots", response_model=ContentRead, status_code=status.HTTP_201_CREATED)
async def upload_screenshot(
    db: DatabaseSession,
    current_user_id: ShareWriteUserId,
    idempotency_key: UUID | None = Header(default=None),
    file: UploadFile = File(...),
    category_ids: list[int] = Form(default_factory=list),
    tag_names: list[str] = Form(default_factory=list),
) -> ContentRead:
    try:
        normalized_tag_names = TagNamesPayload(tag_names=tag_names).tag_names
    except ValidationError as exc:
        raise RequestValidationError(exc.errors()) from exc
    return await _build_upload_service(db).upload_screenshot(
        **({"idempotency_key": idempotency_key} if idempotency_key else {}),
        user_id=current_user_id,
        file=file,
        category_ids=category_ids,
        tag_names=normalized_tag_names,
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


@router.get("/assets/{asset_id}/access", response_model=ContentAssetAccess)
async def asset_access(
    asset_id: int,
    db: DatabaseSession,
    current_user_id: CurrentUserId,
    response: Response,
) -> ContentAssetAccess:
    response.headers["Cache-Control"] = "private, no-store"
    return await _build_upload_service(db).asset_access(
        user_id=current_user_id, asset_id=asset_id,
    )


def _build_upload_service(db: AsyncSession) -> UploadService:
    content_asset_repository = ContentAssetRepository(db)
    category_repository = CategoryRepository(db)
    return UploadService(
        content_service=ContentService(
            content_repository=ContentRepository(db),
            category_repository=category_repository,
            event_repository=EventRepository(db),
            content_asset_repository=content_asset_repository,
            category_recommendation_service=CategoryRecommendationService(
                category_repository=category_repository,
                ai_client=get_ai_client(),
            ),
            tag_repository=TagRepository(db),
        ),
        content_asset_repository=content_asset_repository,
        storage_client=get_storage_client(),
        ocr_client=get_ocr_client(),
        image_storage_control=ImageUploadControl(db),
    )
