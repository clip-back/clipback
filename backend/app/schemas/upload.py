from pydantic import BaseModel


class ScreenshotUploadResponse(BaseModel):
    content_id: int | None = None
    category_id: int
    filename: str
    mime_type: str | None = None
    status: str

