from types import SimpleNamespace

import pytest

from app.integrations.ai_client import (
    AIClientError,
    AIClientInvalidResponseError,
    AIClientTimeoutError,
)
from app.schemas.content import ContentCreate, ContentSource
from app.services.category_recommendation_service import CategoryRecommendationService


class FakeCategoryRepository:
    def __init__(self, candidates: list[SimpleNamespace]) -> None:
        self.candidates = candidates
        self.user_ids: list[int] = []

    async def list_recommendation_candidates(self, user_id: int):
        self.user_ids.append(user_id)
        return self.candidates


class FakeAIClient:
    def __init__(self, result: int | None = None, error: Exception | None = None) -> None:
        self.result = result
        self.error = error
        self.calls: list[dict[str, object]] = []

    async def suggest_category_id(self, **kwargs):
        self.calls.append(kwargs)
        if self.error is not None:
            raise self.error
        return self.result


def candidate(category_id: int, name: str) -> SimpleNamespace:
    return SimpleNamespace(id=category_id, name=name)


def build_service(
    *,
    candidates: list[SimpleNamespace],
    result: int | None = None,
    error: Exception | None = None,
) -> tuple[CategoryRecommendationService, FakeAIClient, FakeCategoryRepository]:
    repository = FakeCategoryRepository(candidates)
    ai_client = FakeAIClient(result=result, error=error)
    return CategoryRecommendationService(repository, ai_client), ai_client, repository


@pytest.mark.asyncio
@pytest.mark.parametrize("selected_id", [1, 7])
async def test_recommends_default_or_current_user_candidate(selected_id: int) -> None:
    service, ai_client, repository = build_service(
        candidates=[candidate(1, "공부"), candidate(7, "내 프로젝트")],
        result=selected_id,
    )

    result = await service.recommend(
        user_id=10,
        payload=ContentCreate(
            original_url="https://example.com/post?token=secret#part",
            source=ContentSource.WEB,
            title="  프로젝트\n회고  ",
            summary="개발 기록",
        ),
        shared_text="함께 보기 https://example.com/post?token=secret 추가 설명",
    )

    assert result.category_id == selected_id
    assert result.assignment_method == "ai"
    assert result.failure_reason is None
    assert repository.user_ids == [10]
    assert ai_client.calls[0] == {
        "title": "프로젝트 회고",
        "description": "개발 기록",
        "source": "web",
        "url": "https://example.com/post",
        "shared_text": "함께 보기 추가 설명",
        "candidates": [(1, "공부"), (7, "내 프로젝트")],
    }


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("result", "error", "expected_reason"),
    [
        (None, None, "no_match"),
        (None, AIClientTimeoutError(), "timeout"),
        (None, AIClientInvalidResponseError(), "invalid_response"),
        (None, AIClientError(), "error"),
        (999, None, "invalid_response"),
    ],
)
async def test_recommendation_failures_fall_back(
    result: int | None,
    error: Exception | None,
    expected_reason: str,
) -> None:
    service, _, _ = build_service(
        candidates=[candidate(1, "공부")],
        result=result,
        error=error,
    )

    recommendation = await service.recommend(
        user_id=1,
        payload=ContentCreate(original_url="https://example.com", title="분류할 제목"),
    )

    assert recommendation.category_id is None
    assert recommendation.assignment_method == "uncategorized"
    assert recommendation.failure_reason == expected_reason


@pytest.mark.asyncio
async def test_no_candidates_skips_ai() -> None:
    service, ai_client, _ = build_service(candidates=[])

    result = await service.recommend(
        user_id=1,
        payload=ContentCreate(original_url="https://example.com", title="제목"),
    )

    assert result.failure_reason == "no_match"
    assert ai_client.calls == []


@pytest.mark.asyncio
async def test_insufficient_input_skips_ai() -> None:
    service, ai_client, _ = build_service(candidates=[candidate(1, "공부")])

    result = await service.recommend(
        user_id=1,
        payload=ContentCreate(original_url="https://example.com?secret=1"),
        shared_text="https://example.com?secret=1",
    )

    assert result.failure_reason == "insufficient_input"
    assert ai_client.calls == []


@pytest.mark.asyncio
async def test_shared_text_is_normalized_and_limited_to_1000_characters() -> None:
    service, ai_client, _ = build_service(
        candidates=[candidate(1, "공부")],
        result=1,
    )

    await service.recommend(
        user_id=1,
        payload=ContentCreate(original_url="https://example.com"),
        shared_text="https://example.com " + ("가\n" * 800),
    )

    shared_text = ai_client.calls[0]["shared_text"]
    assert isinstance(shared_text, str)
    assert "https://" not in shared_text
    assert "\n" not in shared_text
    assert len(shared_text) == 1000
