from pydantic import BaseModel, Field


class CursorParams(BaseModel):
    limit: int = Field(default=20, ge=1, le=100)
    cursor: str | None = None

