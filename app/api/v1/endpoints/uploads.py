from fastapi import APIRouter, File, Form, UploadFile, status

from app.schemas.upload import ScreenshotUploadResponse
from app.services.upload_service import UploadService

router = APIRouter()


@router.post("/screenshots", response_model=ScreenshotUploadResponse, status_code=status.HTTP_201_CREATED)
async def upload_screenshot(
    file: UploadFile = File(...),
    category_id: int = Form(...),
) -> ScreenshotUploadResponse:
    return await UploadService().upload_screenshot_placeholder(file=file, category_id=category_id)

