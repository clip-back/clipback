from datetime import datetime
from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator
from pydantic.json_schema import SkipJsonSchema


class CategoryCreate(BaseModel):
    name: str = Field(min_length=1, max_length=40)
    color: str | None = Field(default=None, max_length=20)

    @field_validator("name")
    @classmethod
    def normalize_name(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise ValueError("Category name cannot be blank")
        return normalized


class CategoryRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    color: str | None = None
    is_default: bool = False


class CategorySummaryRead(CategoryRead):
    content_count: int
    last_saved_at: datetime | None


class CategoryUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid", json_schema_extra={"minProperties": 1})

    name: Annotated[str, Field(min_length=1, max_length=40)] | SkipJsonSchema[None] = Field(
        default=None,
        json_schema_extra=lambda schema: schema.pop("default", None),
    )
    color: str | None = Field(default=None, max_length=20)

    @field_validator("name")
    @classmethod
    def normalize_name(cls, value: str | None) -> str:
        if value is None:
            raise ValueError("Category name cannot be null")
        return CategoryCreate.normalize_name(value)

    @model_validator(mode="after")
    def require_changes(self) -> "CategoryUpdate":
        if not self.model_fields_set:
            raise ValueError("At least one field is required")
        return self
