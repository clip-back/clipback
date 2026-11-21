from collections.abc import Awaitable, Callable
from contextlib import aclosing
from uuid import UUID

from fastapi import APIRouter, File, Form, Header, Request, Response, UploadFile, status
from fastapi.exceptions import RequestValidationError
from fastapi.routing import APIRoute
from pydantic import ValidationError
from python_multipart.multipart import parse_options_header
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.exceptions import HTTPException
from starlette.formparsers import MultiPartException, MultiPartParser

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
from app.schemas.tag import UNSUPPORTED_TAG_CHARACTERS, TagNamesPayload
from app.services.category_recommendation_service import CategoryRecommendationService
from app.services.content_save_flow import ContentSaveFlow
from app.services.content_service import ContentService
from app.services.image_storage_control import ImageUploadControl
from app.services.image_upload_policy import ImageUploadPolicy
from app.services.upload_service import UploadService
from app.services.usage_limits import DailySummaryLimit


class _ScreenshotMultipartParser(MultiPartParser):
    def on_part_end(self) -> None:
        part = self._current_part
        if part.file is None and part.field_name == "tag_names":
            # Starlette falls back to Latin-1. Check the original bytes before that decode.
            self.items.append((part.field_name, part.data.decode("utf-8")))
            return
        super().on_part_end()


class _ScreenshotRoute(APIRoute):
    def get_route_handler(self) -> Callable[[Request], Awaitable[Response]]:
        handler = super().get_route_handler()

        async def handle(request: Request) -> Response:
            content_type, _ = parse_options_header(request.headers.get("content-type"))
            if content_type == b"multipart/form-data":
                try:
                    async with aclosing(request.stream()) as stream:
                        form = await _ScreenshotMultipartParser(request.headers, stream).parse()
                except UnicodeDecodeError as exc:
                    error = ValidationError.from_exception_data("TagNamesPayload", [{
                        "type": "value_error",
                        "loc": ("tag_names",),
                        "input": None,
                        "ctx": {"error": ValueError(UNSUPPORTED_TAG_CHARACTERS)},
                    }])
                    raise RequestValidationError(error.errors()) from exc
                except MultiPartException as exc:
                    raise HTTPException(status_code=400, detail=exc.message) from exc
                except HTTPException:
                    raise
                except Exception as exc:
                    raise HTTPException(
                        status_code=400, detail="There was an error parsing the body",
                    ) from exc
                # FastAPI reuses the parsed form and registers its normal UploadFile cleanup.
                request._form = form
            return await handler(request)

        return handle


router = APIRouter()


async def upload_screenshot(
    request: Request,
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
    return await _build_save_flow(
        db,
        summary_limit=request.app.state.daily_summary_limit,
    ).save_screenshot(
        **({"idempotency_key": idempotency_key} if idempotency_key else {}),
        user_id=current_user_id,
        file=file,
        category_ids=category_ids,
        tag_names=normalized_tag_names,
    )


router.add_api_route(
    "/screenshots",
    upload_screenshot,
    methods=["POST"],
    response_model=ContentRead,
    status_code=status.HTTP_201_CREATED,
    route_class_override=_ScreenshotRoute,
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
    storage = get_storage_client()
    return UploadService(
        content_asset_repository=ContentAssetRepository(db),
        storage_client=storage,
        ocr_client=get_ocr_client(),
        image_storage_control=ImageUploadControl(db),
        image_upload_policy=ImageUploadPolicy(db, storage),
    )


def _build_save_flow(db: AsyncSession, *, summary_limit: DailySummaryLimit) -> ContentSaveFlow:
    uploads = _build_upload_service(db)
    category_repository = CategoryRepository(db)
    return ContentSaveFlow(
        ContentService(
            summary_limit=summary_limit,
            content_repository=ContentRepository(db),
            category_repository=category_repository,
            event_repository=EventRepository(db),
            content_asset_repository=uploads.content_asset_repository,
            category_recommendation_service=CategoryRecommendationService(
                category_repository=category_repository,
                ai_client=get_ai_client(),
            ),
            tag_repository=TagRepository(db),
        ),
        uploads=uploads,
    )
