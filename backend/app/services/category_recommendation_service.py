from __future__ import annotations

import logging
import re
import time
from dataclasses import dataclass, field, replace
from enum import StrEnum
from urllib.parse import urlsplit, urlunsplit

from app.integrations.ai_client import (
    AIClient,
    AIClientError,
    AIClientInvalidResponseError,
    AIClientTimeoutError,
)
from app.repositories.category_repository import CategoryRepository
from app.schemas.content import ContentSaveInput
from app.services.ai_consent import AI_CONSENT_REQUIRED, SaveAIConsent
from app.services.save_step_log import log_save_step
from app.services.usage_limits import DailyRecommendationLimit

URL_PATTERN = re.compile(r"(?:https?://|www\.)[^\s<>'\"]+", re.IGNORECASE)
WHITESPACE_PATTERN = re.compile(r"\s+")
logger = logging.getLogger(__name__)


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
    DAILY_LIMIT_EXCEEDED = "daily_limit_exceeded"
    AI_CONSENT_REQUIRED = AI_CONSENT_REQUIRED


@dataclass(frozen=True)
class CategoryRecommendationResult:
    category_id: int | None
    assignment_method: CategoryAssignmentMethod
    failure_reason: CategoryRecommendationFailureReason | None
    tag_names: list[str] = field(default_factory=list)
    elapsed_seconds: float | None = field(default=None, compare=False, repr=False)


def log_category_recommendation(result: CategoryRecommendationResult) -> None:
    if result.elapsed_seconds is not None:
        log_save_step(
            logger, "category_recommendation", result.elapsed_seconds,
            result.assignment_method, result.failure_reason,
        )


class CategoryRecommendationService:
    def __init__(
        self,
        category_repository: CategoryRepository,
        ai_client: AIClient,
        *,
        daily_limit: DailyRecommendationLimit | None = None,
        ai_consent: SaveAIConsent | None = None,
    ) -> None:
        self.category_repository = category_repository
        self.ai_client = ai_client
        self.daily_limit = daily_limit
        self.ai_consent = ai_consent

    async def recommend(
        self,
        *,
        user_id: int,
        payload: ContentSaveInput,
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
        url = self._sanitize_url(str(payload.original_url)) if payload.original_url else None
        # G1a: before the attempt is counted.
        if self.ai_consent is not None and not await self.ai_consent.allows(user_id):
            return self._fallback(CategoryRecommendationFailureReason.AI_CONSENT_REQUIRED)
        attempt = None
        if self.daily_limit is not None:
            if not self.ai_client.is_configured:
                return self._fallback(CategoryRecommendationFailureReason.ERROR)
            try:
                attempt = await self.daily_limit.admit(user_id)
            except Exception as exc:
                logger.warning(
                    "Unable to record category recommendation attempt (%s)", type(exc).__name__,
                )
                return self._fallback(CategoryRecommendationFailureReason.ERROR)
            if attempt is None:
                return self._fallback(CategoryRecommendationFailureReason.DAILY_LIMIT_EXCEEDED)
        # G1b: right before the OpenAI call; an unsent attempt does not count.
        if self.ai_consent is not None and not await self.ai_consent.allows(user_id):
            if attempt is not None:
                await self.daily_limit.release(attempt)
            return self._fallback(CategoryRecommendationFailureReason.AI_CONSENT_REQUIRED)

        started_at = time.monotonic()
        try:
            try:
                suggestion = await self.ai_client.suggest_category_id(
                    title=title,
                    description=description,
                    source=payload.source.value,
                    url=url,
                    shared_text=normalized_shared_text,
                    candidates=candidate_pairs,
                )
            finally:
                elapsed_seconds = time.monotonic() - started_at
        except AIClientTimeoutError:
            result = self._fallback(CategoryRecommendationFailureReason.TIMEOUT)
        except AIClientInvalidResponseError:
            result = self._fallback(CategoryRecommendationFailureReason.INVALID_RESPONSE)
        except AIClientError:
            result = self._fallback(CategoryRecommendationFailureReason.ERROR)
        else:
            category_id = suggestion.category_id
            tag_names = suggestion.tag_names
            if category_id is None:
                result = self._fallback(CategoryRecommendationFailureReason.NO_MATCH, tag_names)
            elif category_id not in {candidate_id for candidate_id, _ in candidate_pairs}:
                result = self._fallback(
                    CategoryRecommendationFailureReason.INVALID_RESPONSE, tag_names,
                )
            else:
                result = CategoryRecommendationResult(
                    category_id=category_id,
                    assignment_method=CategoryAssignmentMethod.AI,
                    failure_reason=None,
                    tag_names=tag_names,
                )
        return replace(result, elapsed_seconds=elapsed_seconds)

    @staticmethod
    def _fallback(
        reason: CategoryRecommendationFailureReason,
        tag_names: list[str] | None = None,
    ) -> CategoryRecommendationResult:
        return CategoryRecommendationResult(
            category_id=None,
            assignment_method=CategoryAssignmentMethod.UNCATEGORIZED,
            failure_reason=reason,
            tag_names=tag_names or [],
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
