from fastapi import UploadFile

from app.schemas.upload import ScreenshotUploadResponse


class UploadService:
    async def upload_screenshot_placeholder(
        self,
        file: UploadFile,
        category_id: int,
    ) -> ScreenshotUploadResponse:
        return ScreenshotUploadResponse(
            category_id=category_id,
            filename=file.filename or "screenshot",
            mime_type=file.content_type,
            status="received",
        )

