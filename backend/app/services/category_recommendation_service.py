from __future__ import annotations

import re
from dataclasses import dataclass
from enum import StrEnum
from urllib.parse import urlsplit, urlunsplit

from app.integrations.ai_client import (
    AIClient,
    AIClientError,
    AIClientInvalidResponseError,
    AIClientTimeoutError,
)
from app.repositories.category_repository import CategoryRepository
from app.schemas.content import ContentCreate

URL_PATTERN = re.compile(r"(?:https?://|www\.)[^\s<>'\"]+", re.IGNORECASE)
WHITESPACE_PATTERN = re.compile(r"\s+")


class CategoryAssignmentMethod(StrEnum):
    USER = "user"
    AI = "ai"
    UNCATEGORIZED = "uncategorized"


class CategoryRecommendationFailureReason(StrEnum):
    NO_MATCH = "no_match"
    INSUFFICIENT_INPUT = "insufficient_input"
    TIMEOUT = "timeout"
    INVALID_RESPONSE = "invalid_response"
    ERROR = "error"


@dataclass(frozen=True)
class CategoryRecommendationResult:
    category_id: int | None
    assignment_method: CategoryAssignmentMethod
    failure_reason: CategoryRecommendationFailureReason | None


class CategoryRecommendationService:
    def __init__(
        self,
        category_repository: CategoryRepository,
        ai_client: AIClient,
    ) -> None:
        self.category_repository = category_repository
        self.ai_client = ai_client

    async def recommend(
        self,
        *,
        user_id: int,
        payload: ContentCreate,
        shared_text: str | None = None,
    ) -> CategoryRecommendationResult:
        candidates = await self.category_repository.list_recommendation_candidates(user_id)
        if not candidates:
            return self._fallback(CategoryRecommendationFailureReason.NO_MATCH)

        title = self._normalize(payload.title, 120)
        description = self._normalize(payload.summary, 500)
        normalized_shared_text = self._normalize_shared_text(shared_text)
        if not any((title, description, normalized_shared_text)):
            return self._fallback(CategoryRecommendationFailureReason.INSUFFICIENT_INPUT)

        candidate_pairs = [(category.id, category.name) for category in candidates]
        try:
            category_id = await self.ai_client.suggest_category_id(
                title=title,
                description=description,
                source=payload.source.value,
                url=self._sanitize_url(str(payload.original_url)) if payload.original_url else None,
                shared_text=normalized_shared_text,
                candidates=candidate_pairs,
            )
        except AIClientTimeoutError:
            return self._fallback(CategoryRecommendationFailureReason.TIMEOUT)
        except AIClientInvalidResponseError:
            return self._fallback(CategoryRecommendationFailureReason.INVALID_RESPONSE)
        except AIClientError:
            return self._fallback(CategoryRecommendationFailureReason.ERROR)

        if category_id is None:
            return self._fallback(CategoryRecommendationFailureReason.NO_MATCH)
        if category_id not in {candidate_id for candidate_id, _ in candidate_pairs}:
            return self._fallback(CategoryRecommendationFailureReason.INVALID_RESPONSE)
        return CategoryRecommendationResult(
            category_id=category_id,
            assignment_method=CategoryAssignmentMethod.AI,
            failure_reason=None,
        )

    @staticmethod
    def _fallback(
        reason: CategoryRecommendationFailureReason,
    ) -> CategoryRecommendationResult:
        return CategoryRecommendationResult(
            category_id=None,
            assignment_method=CategoryAssignmentMethod.UNCATEGORIZED,
            failure_reason=reason,
        )

    @staticmethod
    def _normalize(value: str | None, limit: int) -> str | None:
        if value is None:
            return None
        normalized = WHITESPACE_PATTERN.sub(" ", value).strip()
        return normalized[:limit] or None

    @classmethod
    def _normalize_shared_text(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return cls._normalize(URL_PATTERN.sub(" ", value), 1_000)

    @staticmethod
    def _sanitize_url(value: str) -> str:
        parts = urlsplit(value)
        return urlunsplit((parts.scheme, parts.netloc, parts.path, "", ""))
