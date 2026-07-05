from pydantic import BaseModel, Field


class CategoryCreate(BaseModel):
    name: str = Field(min_length=1, max_length=40)
    color: str | None = Field(default=None, max_length=20)


class CategoryRead(BaseModel):
    id: int
    name: str
    color: str | None = None
    is_default: bool = False

