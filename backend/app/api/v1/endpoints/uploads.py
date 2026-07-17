from fastapi import APIRouter, File, Form, UploadFile, status

from app.api.deps import CurrentUserId
from app.schemas.upload import ScreenshotUploadResponse
from app.services.upload_service import UploadService

router = APIRouter()


@router.post("/screenshots", response_model=ScreenshotUploadResponse, status_code=status.HTTP_201_CREATED)
async def upload_screenshot(
    _current_user_id: CurrentUserId,
    file: UploadFile = File(...),
    category_ids: list[int] = Form(default_factory=list),
) -> ScreenshotUploadResponse:
    return await UploadService().upload_screenshot_placeholder(file=file, category_ids=category_ids)
