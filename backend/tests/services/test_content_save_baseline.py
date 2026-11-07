"""콘텐츠 저장 서비스 기준선 테스트(#278).

HTTP 라우트로는 닿지 않는 두 경우를 지금의 생성 함수 기준으로 고정한다(main 901a3b1).
- 추천 서비스 없음: 링크, 그리고 공유 텍스트가 있는 공유 링크 저장
- 정규화 뒤 URL 길이 재검사: 검증을 거치지 않은 복사본에 2048자를 넘는 URL

호출부와 같은 결과가 되도록, 지금 호출에는 실제 호출부가 만드는 이벤트 metadata
(링크: 추출 3키, 공유: 공유 6키 + 추출 3키)를 넘긴다. 메타데이터 요청은 가짜로 바꿔 둔다.
저장 진입점을 바꾸는 이후 티켓은 생성 함수를 부르는 줄만 새 진입점 호출로 바꿀 수 있다.
입력·기대값·단언은 바꾸지 않는다.
"""

from datetime import UTC, datetime
from types import SimpleNamespace

import pytest
from fastapi import HTTPException

from app.core.config import settings
from app.integrations.metadata_client import MetadataClient, MetadataResult
from app.schemas.content import ContentCreate
from app.services.category_recommendation_service import (
    CategoryAssignmentMethod,
    CategoryRecommendationResult,
)
from app.services.content_service import ContentService, SharedLinkContext

pytestmark = pytest.mark.asyncio

UNCATEGORIZED = SimpleNamespace(id=9, name="미분류", color=None, is_default=True)


class FakeSession:
    def __init__(self) -> None:
        self.committed = False
        self.added: list[object] = []

    def add(self, item) -> None:
        self.added.append(item)

    async def commit(self) -> None:
        self.committed = True

    async def rollback(self) -> None:
        pass


class FakeContentRepository:
    def __init__(self) -> None:
        self.session = FakeSession()
        self.contents: dict[int, SimpleNamespace] = {}

    async def create(self, *, user_id, categories, tags, **values) -> SimpleNamespace:
        content = SimpleNamespace(
            id=len(self.contents) + 1, user_id=user_id, categories=categories, tags=tags,
            assets=[], saved_at=datetime.now(UTC), last_viewed_at=None, **values,
        )
        self.contents[content.id] = content
        return content

    async def get_owned(self, *, user_id, content_id, for_update=False):
        return self.contents.get(content_id)


class FakeCategoryRepository:
    async def list_available_by_ids(self, user_id, category_ids):
        return []

    async def get_uncategorized(self):
        return UNCATEGORIZED


class FakeEventRepository:
    def __init__(self) -> None:
        self.events: list[dict] = []

    async def create(self, **values) -> None:
        self.events.append(values)


class FakeTagRepository:
    def __init__(self) -> None:
        self.created: list[str] = []

    async def get_or_create_many(self, *, user_id, names):
        self.created.extend(names)
        return [SimpleNamespace(id=index, name=name) for index, name in enumerate(names, 1)]


class FakeRecommendationService:
    def __init__(self) -> None:
        self.calls = 0

    async def recommend(self, **_):
        self.calls += 1
        return CategoryRecommendationResult(
            category_id=None,
            assignment_method=CategoryAssignmentMethod.UNCATEGORIZED,
            failure_reason=None,
        )


@pytest.fixture
def metadata_calls(monkeypatch) -> list[str]:
    calls: list[str] = []

    async def extract(self, url):
        calls.append(url)
        return MetadataResult(
            resolved_url=url, title="추출 제목", description="추출 설명", status="success",
        )

    monkeypatch.setattr(MetadataClient, "extract_from_url", extract)
    monkeypatch.setattr(settings, "youtube_summary_enabled", False)
    monkeypatch.setattr(settings, "instagram_summary_enabled", False)
    return calls


def build_service(recommendation_service=None):
    contents = FakeContentRepository()
    events = FakeEventRepository()
    tags = FakeTagRepository()
    service = ContentService(
        content_repository=contents,
        category_repository=FakeCategoryRepository(),
        event_repository=events,
        category_recommendation_service=recommendation_service,
        tag_repository=tags,
    )
    return service, contents, events, tags


async def test_link_without_recommendation_service_is_uncategorized(metadata_calls):
    service, contents, events, _ = build_service()
    payload = ContentCreate(
        original_url="https://example.com/a", title="내 제목", summary="내 요약", source="web",
    )

    created = await service.save_link(user_id=1, payload=payload)

    assert [category.name for category in created.categories] == ["미분류"]
    assert [event["metadata_json"] for event in events.events] == [
        '{"metadata_status":"success","metadata_failure_reason":null,'
        '"resolved_url":"https://example.com/a","category_assignment_method":"uncategorized",'
        '"recommended_category_id":null,"category_recommendation_failure_reason":"error"}'
    ]
    assert contents.session.committed


async def test_shared_link_without_recommendation_service_is_uncategorized(metadata_calls):
    service, contents, events, _ = build_service()
    payload = ContentCreate(
        original_url="https://www.instagram.com/reel/XYZ789/", title="내 제목", summary="내 요약",
        source="instagram",
    )

    created = await service.save_link(user_id=1, payload=payload, share=SharedLinkContext(shared_text="공유 글 https://www.instagram.com/reel/XYZ789/", source_app="com.instagram", platform="ios", mime_type="text/plain", attachment_count=0, extracted_url="https://www.instagram.com/reel/XYZ789/", url_source="url"))  # noqa: E501

    assert [category.name for category in created.categories] == ["미분류"]
    assert [event["metadata_json"] for event in events.events] == [
        '{"source_app":"com.instagram","platform":"ios","mime_type":"text/plain",'
        '"attachment_count":0,"extracted_url":"https://www.instagram.com/reel/XYZ789/",'
        '"url_source":"url","metadata_status":"success","metadata_failure_reason":null,'
        '"resolved_url":"https://www.instagram.com/reel/XYZ789/",'
        '"category_assignment_method":"uncategorized","recommended_category_id":null,'
        '"category_recommendation_failure_reason":"error"}'
    ]
    assert contents.session.committed


async def test_url_from_unvalidated_copy_is_rechecked_after_normalization(metadata_calls):
    recommendation = FakeRecommendationService()
    service, contents, events, tags = build_service(recommendation)
    payload = ContentCreate(original_url="https://example.com/", tag_names=["새 태그"]).model_copy(
        update={"original_url": "https://example.com/" + "a" * 2050},
    )

    with pytest.raises(HTTPException) as exc_info:
        await service.save_link(user_id=1, payload=payload)

    assert exc_info.value.status_code == 422
    assert exc_info.value.detail == (
        "original_url must not exceed 2048 characters after normalization"
    )
    assert metadata_calls == []
    assert recommendation.calls == 0
    assert contents.contents == {}
    assert events.events == []
    assert tags.created == []
    assert not contents.session.committed
