import re
import unicodedata
from collections.abc import Iterable

from pydantic import BaseModel, ConfigDict, Field, field_validator

MAX_TAGS_PER_CONTENT = 10
MAX_AI_TAGS = 3
MAX_TAG_NAME_LENGTH = 40
WHITESPACE_PATTERN = re.compile(r"\s+")
LEADING_HASH_PATTERN = re.compile(r"^(?:#\s*)+")


def normalize_tag_name(value: str) -> str:
    normalized = unicodedata.normalize("NFKC", value)
    normalized = "".join(char for char in normalized if unicodedata.category(char) != "Cf")
    normalized = WHITESPACE_PATTERN.sub(" ", normalized).strip()
    normalized = LEADING_HASH_PATTERN.sub("", normalized).strip()
    if not normalized:
        raise ValueError("Tag name cannot be blank")
    if len(normalized) > MAX_TAG_NAME_LENGTH:
        raise ValueError(f"Tag name cannot exceed {MAX_TAG_NAME_LENGTH} characters")
    if len(normalized.casefold()) > MAX_TAG_NAME_LENGTH:
        raise ValueError(f"Tag name cannot exceed {MAX_TAG_NAME_LENGTH} characters")
    return normalized


def normalize_tag_names(values: list[str]) -> list[str]:
    return _unique_tag_names(normalize_tag_name(value) for value in values)


def clean_ai_tag_names(value: object) -> list[str]:
    """Return up to three usable tag names from an optional AI response field."""
    if not isinstance(value, list):
        return []

    normalized_names: list[str] = []
    for item in value:
        if not isinstance(item, str):
            continue
        try:
            normalized_names.append(normalize_tag_name(item))
        except ValueError:
            continue

    return _unique_tag_names(normalized_names)[:MAX_AI_TAGS]


def _unique_tag_names(display_names: Iterable[str]) -> list[str]:
    normalized_names: list[str] = []
    seen: set[str] = set()
    for display_name in display_names:
        normalized_name = display_name.casefold()
        if normalized_name in seen:
            continue
        seen.add(normalized_name)
        normalized_names.append(display_name)
    return normalized_names


class TagNamesPayload(BaseModel):
    tag_names: list[str] = Field(default_factory=list, max_length=MAX_TAGS_PER_CONTENT)

    @field_validator("tag_names")
    @classmethod
    def validate_tag_names(cls, values: list[str]) -> list[str]:
        return normalize_tag_names(values)


class TagRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
