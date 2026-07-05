from pydantic import BaseModel, Field


class ScreenshotUploadResponse(BaseModel):
    content_id: int | None = None
    category_ids: list[int] = Field(default_factory=list)
    filename: str
    mime_type: str | None = None
    status: str
