import json
from datetime import UTC, datetime
from types import SimpleNamespace

import pytest
from fastapi import HTTPException

from app.core.exceptions import NotFoundError, SystemConfigurationError
from app.models.content_asset import AssetType
from app.models.content_event import ContentEventType
from app.schemas.content import (
    ContentCategoryUpdate,
    ContentCreate,
    ContentFavoriteUpdate,
    ContentSource,
    ContentTagUpdate,
    ContentType,
)
from app.services.category_recommendation_service import (
    CategoryAssignmentMethod,
    CategoryRecommendationResult,
)
from app.services.content_service import ContentService, PendingContentAsset


class FakeSession:
    def __init__(self) -> None:
        self.committed = False
        self.rolled_back = False

    async def commit(self) -> None:
        self.committed = True

    async def rollback(self) -> None:
        self.rolled_back = True


class FakeContentRepository:
    def __init__(self, contents: list[SimpleNamespace] | None = None) -> None:
        self.session = FakeSession()
        self.contents = {content.id: content for content in contents or []}
        self.created_categories: list[SimpleNamespace] = []
        self.created_tags: list[SimpleNamespace] = []
        self.created_assets: list[SimpleNamespace] = []
        self.deleted_content_ids: list[int] = []

    async def create(
        self,
        *,
        user_id: int,
        content_type,
        source,
        title: str,
        summary: str,
        original_url: str | None,
        is_favorite: bool,
        categories: list[SimpleNamespace],
        tags: list[SimpleNamespace],
    ) -> SimpleNamespace:
        content = SimpleNamespace(
            id=max(self.contents, default=0) + 1,
            user_id=user_id,
            content_type=content_type,
            source=source,
            title=title,
            summary=summary,
            original_url=original_url,
            is_favorite=is_favorite,
            categories=categories,
            tags=tags,
            assets=[],
            saved_at=datetime.now(UTC),
            last_viewed_at=None,
        )
        self.contents[content.id] = content
        self.created_categories = categories
        self.created_tags = tags
        return content

    async def get_owned(self, *, user_id: int, content_id: int) -> SimpleNamespace | None:
        content = self.contents.get(content_id)
        if content is None or content.user_id != user_id:
            return None
        return content

    async def mark_viewed(self, content: SimpleNamespace) -> SimpleNamespace:
        content.last_viewed_at = datetime.now(UTC)
        return content

    async def set_favorite(
        self,
        *,
        content: SimpleNamespace,
        is_favorite: bool,
    ) -> SimpleNamespace:
        content.is_favorite = is_favorite
        return content

    async def delete(self, content: SimpleNamespace) -> None:
        self.deleted_content_ids.append(content.id)
        self.contents.pop(content.id)

    async def replace_categories(
        self,
        *,
        content: SimpleNamespace,
        categories: list[SimpleNamespace],
    ) -> SimpleNamespace:
        content.categories = categories
        return content

    async def replace_tags(
        self,
        *,
        content: SimpleNamespace,
        tags: list[SimpleNamespace],
    ) -> SimpleNamespace:
        content.tags = tags
        return content


class FakeContentAssetRepository:
    def __init__(self, content_repository: FakeContentRepository) -> None:
        self.content_repository = content_repository

    async def create(
        self,
        *,
        content_id: int,
        asset_type: AssetType,
        storage_key: str,
        mime_type: str | None,
    ) -> SimpleNamespace:
        asset = SimpleNamespace(
            id=len(self.content_repository.created_assets) + 1,
            content_id=content_id,
            asset_type=asset_type,
            storage_key=storage_key,
            mime_type=mime_type,
        )
        self.content_repository.created_assets.append(asset)
        self.content_repository.contents[content_id].assets.append(asset)
        return asset


class FakeStorageClient:
    def __init__(self, *, fail_keys: set[str] | None = None) -> None:
        self.fail_keys = fail_keys or set()
        self.deleted_keys: list[str] = []

    async def delete_file(self, storage_key: str) -> None:
        self.deleted_keys.append(storage_key)
        if storage_key in self.fail_keys:
            raise OSError("storage unavailable")


class FakeCategoryRepository:
    def __init__(
        self,
        categories: list[SimpleNamespace],
        uncategorized: SimpleNamespace | None = None,
    ) -> None:
        self.categories = {category.id: category for category in categories}
        self.uncategorized = uncategorized

    async def list_available_by_ids(
        self,
        user_id: int,
        category_ids: list[int],
    ) -> list[SimpleNamespace]:
        return [
            self.categories[category_id]
            for category_id in category_ids
            if category_id in self.categories
        ]

    async def get_uncategorized(self) -> SimpleNamespace | None:
        return self.uncategorized


class FakeEventRepository:
    def __init__(self) -> None:
        self.events: list[SimpleNamespace] = []

    async def create(
        self,
        *,
        user_id: int,
        event_type: ContentEventType,
        content_id: int | None = None,
        metadata_json: str | None = None,
    ) -> SimpleNamespace:
        event = SimpleNamespace(
            user_id=user_id,
            event_type=event_type,
            content_id=content_id,
            metadata_json=metadata_json,
        )
        self.events.append(event)
        return event


class FakeTagRepository:
    def __init__(self) -> None:
        self.tags: dict[tuple[int, str], SimpleNamespace] = {}

    async def get_or_create_many(
        self,
        *,
        user_id: int,
        names: list[str],
    ) -> list[SimpleNamespace]:
        resolved: list[SimpleNamespace] = []
        for name in names:
            key = (user_id, name.casefold())
            if key not in self.tags:
                self.tags[key] = SimpleNamespace(
                    id=len(self.tags) + 1,
                    user_id=user_id,
                    name=name,
                    normalized_name=name.casefold(),
                )
            resolved.append(self.tags[key])
        return resolved


class FakeRecommendationService:
    def __init__(self, result: CategoryRecommendationResult) -> None:
        self.result = result
        self.calls = 0
        self.shared_text: str | None = None

    async def recommend(self, *, user_id: int, payload, shared_text: str | None = None):
        self.calls += 1
        self.shared_text = shared_text
        return self.result


def build_service(
    *,
    categories: list[SimpleNamespace] | None = None,
    uncategorized: SimpleNamespace | None = None,
    contents: list[SimpleNamespace] | None = None,
    recommendation_service: FakeRecommendationService | None = None,
    storage_client: FakeStorageClient | None = None,
) -> tuple[ContentService, FakeContentRepository, FakeEventRepository]:
    content_repository = FakeContentRepository(contents)
    event_repository = FakeEventRepository()
    service = ContentService(
        content_repository=content_repository,
        category_repository=FakeCategoryRepository(categories or [], uncategorized),
        event_repository=event_repository,
        content_asset_repository=FakeContentAssetRepository(content_repository),
        category_recommendation_service=recommendation_service,
        tag_repository=FakeTagRepository(),
        storage_client=storage_client,
    )
    return service, content_repository, event_repository


def category(
    category_id: int,
    name: str,
    *,
    is_default: bool = False,
) -> SimpleNamespace:
    return SimpleNamespace(id=category_id, name=name, color=None, is_default=is_default)


def content(content_id: int, *, user_id: int = 1) -> SimpleNamespace:
    return SimpleNamespace(
        id=content_id,
        user_id=user_id,
        content_type=ContentType.LINK,
        source=ContentSource.WEB,
        title="저장한 콘텐츠",
        summary="요약",
        original_url="https://example.com/original",
        is_favorite=False,
        categories=[category(1, "취업", is_default=True)],
        tags=[],
        assets=[],
        saved_at=datetime.now(UTC),
        last_viewed_at=None,
    )


@pytest.mark.asyncio
async def test_create_content_links_available_categories_and_records_event() -> None:
    service, content_repository, event_repository = build_service(
        categories=[category(1, "취업", is_default=True), category(2, "여행")]
    )

    result = await service.create_content(
        user_id=1,
        payload=ContentCreate(
            original_url="https://example.com/post",
            category_ids=[2, 1, 2],
            title="  링크 제목  ",
            summary="  링크 요약  ",
        ),
    )

    assert result.id == 1
    assert result.title == "링크 제목"
    assert result.summary == "링크 요약"
    assert [category.id for category in content_repository.created_categories] == [2, 1]
    assert [category.id for category in result.categories] == [1, 2]
    assert event_repository.events[0].event_type == ContentEventType.CONTENT_CREATED
    assert json.loads(event_repository.events[0].metadata_json) == {
        "category_assignment_method": "user",
        "recommended_category_id": None,
        "category_recommendation_failure_reason": None,
    }
    assert content_repository.session.committed is True


@pytest.mark.asyncio
async def test_create_content_creates_normalized_tags_in_same_transaction() -> None:
    service, content_repository, _ = build_service(
        categories=[category(1, "취업", is_default=True)]
    )

    result = await service.create_content(
        user_id=1,
        payload=ContentCreate(
            original_url="https://example.com/post",
            category_ids=[1],
            tag_names=[" Flutter ", "#flutter", "백   엔드"],
        ),
    )

    assert [tag.name for tag in content_repository.created_tags] == ["Flutter", "백 엔드"]
    assert [tag.name for tag in result.tags] == ["Flutter", "백 엔드"]
    assert content_repository.session.committed is True


@pytest.mark.asyncio
async def test_create_content_scopes_same_tag_name_to_each_user() -> None:
    service, _, _ = build_service(categories=[category(1, "취업", is_default=True)])

    first = await service.create_content(
        user_id=1,
        payload=ContentCreate(
            original_url="https://example.com/first",
            category_ids=[1],
            tag_names=["Flutter"],
        ),
    )
    second = await service.create_content(
        user_id=2,
        payload=ContentCreate(
            original_url="https://example.com/second",
            category_ids=[1],
            tag_names=["flutter"],
        ),
    )

    assert first.tags[0].id != second.tags[0].id
    assert first.tags[0].name == "Flutter"
    assert second.tags[0].name == "flutter"


@pytest.mark.asyncio
async def test_create_content_reuses_existing_tag_and_preserves_its_name() -> None:
    service, _, _ = build_service(categories=[category(1, "취업", is_default=True)])

    first = await service.create_content(
        user_id=1,
        payload=ContentCreate(
            original_url="https://example.com/first",
            category_ids=[1],
            tag_names=["Flutter"],
        ),
    )
    second = await service.create_content(
        user_id=1,
        payload=ContentCreate(
            original_url="https://example.com/second",
            category_ids=[1],
            tag_names=["flutter"],
        ),
    )

    assert first.tags[0].id == second.tags[0].id
    assert second.tags[0].name == "Flutter"


@pytest.mark.asyncio
async def test_create_content_uses_uncategorized_when_category_ids_are_empty() -> None:
    uncategorized = category(9, "미분류", is_default=True)
    service, content_repository, _ = build_service(uncategorized=uncategorized)

    result = await service.create_content(
        user_id=1,
        payload=ContentCreate(original_url="https://example.com/post", category_ids=[]),
    )

    assert [category.name for category in result.categories] == ["미분류"]
    assert content_repository.contents[1].title == "저장한 콘텐츠"
    assert content_repository.contents[1].summary == "요약 정보가 아직 없습니다."


@pytest.mark.asyncio
async def test_create_content_records_event_metadata_json() -> None:
    service, _, event_repository = build_service(
        categories=[category(1, "취업", is_default=True)]
    )

    await service.create_content(
        user_id=1,
        payload=ContentCreate(
            original_url="https://example.com/post",
            category_ids=[1],
        ),
        event_metadata_json='{"url_source":"url"}',
    )

    assert json.loads(event_repository.events[0].metadata_json) == {
        "url_source": "url",
        "category_assignment_method": "user",
        "recommended_category_id": None,
        "category_recommendation_failure_reason": None,
    }


@pytest.mark.asyncio
async def test_create_content_uses_ai_recommendation_and_revalidates_category() -> None:
    recommended = category(2, "나만의 자료")
    recommendation_service = FakeRecommendationService(
        CategoryRecommendationResult(
            category_id=2,
            assignment_method=CategoryAssignmentMethod.AI,
            failure_reason=None,
        )
    )
    service, content_repository, event_repository = build_service(
        categories=[recommended],
        uncategorized=category(9, "미분류", is_default=True),
        recommendation_service=recommendation_service,
    )

    await service.create_content(
        user_id=1,
        payload=ContentCreate(
            original_url="https://example.com/post",
            title="개인 프로젝트 자료",
        ),
    )

    assert content_repository.created_categories == [recommended]
    assert recommendation_service.calls == 1
    assert json.loads(event_repository.events[0].metadata_json) == {
        "category_assignment_method": "ai",
        "recommended_category_id": 2,
        "category_recommendation_failure_reason": None,
    }


@pytest.mark.asyncio
async def test_create_content_falls_back_when_recommended_category_disappears() -> None:
    uncategorized = category(9, "미분류", is_default=True)
    recommendation_service = FakeRecommendationService(
        CategoryRecommendationResult(
            category_id=2,
            assignment_method=CategoryAssignmentMethod.AI,
            failure_reason=None,
        )
    )
    service, content_repository, event_repository = build_service(
        uncategorized=uncategorized,
        recommendation_service=recommendation_service,
    )

    await service.create_content(
        user_id=1,
        payload=ContentCreate(original_url="https://example.com/post", title="제목"),
    )

    assert content_repository.created_categories == [uncategorized]
    metadata = json.loads(event_repository.events[0].metadata_json)
    assert metadata["category_assignment_method"] == "uncategorized"
    assert metadata["recommended_category_id"] == 2
    assert metadata["category_recommendation_failure_reason"] == "error"


@pytest.mark.asyncio
async def test_create_content_skips_ai_for_user_categories() -> None:
    recommendation_service = FakeRecommendationService(
        CategoryRecommendationResult(
            category_id=2,
            assignment_method=CategoryAssignmentMethod.AI,
            failure_reason=None,
        )
    )
    service, content_repository, _ = build_service(
        categories=[category(1, "취업"), category(3, "공부")],
        recommendation_service=recommendation_service,
    )

    await service.create_content(
        user_id=1,
        payload=ContentCreate(
            original_url="https://example.com/post",
            category_ids=[3, 1],
        ),
    )

    assert [item.id for item in content_repository.created_categories] == [3, 1]
    assert recommendation_service.calls == 0


@pytest.mark.asyncio
async def test_create_screenshot_skips_ai_and_uses_uncategorized() -> None:
    uncategorized = category(9, "미분류", is_default=True)
    recommendation_service = FakeRecommendationService(
        CategoryRecommendationResult(
            category_id=2,
            assignment_method=CategoryAssignmentMethod.AI,
            failure_reason=None,
        )
    )
    service, content_repository, event_repository = build_service(
        uncategorized=uncategorized,
        recommendation_service=recommendation_service,
    )

    await service.create_content(
        user_id=1,
        payload=ContentCreate(content_type=ContentType.SCREENSHOT),
    )

    assert content_repository.created_categories == [uncategorized]
    assert recommendation_service.calls == 0
    metadata = json.loads(event_repository.events[0].metadata_json)
    assert metadata["category_assignment_method"] == "uncategorized"
    assert metadata["category_recommendation_failure_reason"] is None


@pytest.mark.asyncio
async def test_create_screenshot_uses_ai_recommendation_when_ocr_text_is_available() -> None:
    recommended = category(2, "취업")
    recommendation_service = FakeRecommendationService(
        CategoryRecommendationResult(
            category_id=2,
            assignment_method=CategoryAssignmentMethod.AI,
            failure_reason=None,
        )
    )
    service, content_repository, event_repository = build_service(
        categories=[recommended],
        uncategorized=category(9, "미분류", is_default=True),
        recommendation_service=recommendation_service,
    )

    await service.create_content(
        user_id=1,
        payload=ContentCreate(
            content_type=ContentType.SCREENSHOT,
            source=ContentSource.SCREENSHOT,
            title="백엔드 채용 공고",
            summary="백엔드 개발자를 모집합니다.",
        ),
        event_metadata_json='{"ocr_status":"success","ocr_failure_reason":null}',
        recommendation_shared_text="채용 공고\n백엔드 엔지니어",
    )

    assert content_repository.created_categories == [recommended]
    assert recommendation_service.calls == 1
    assert recommendation_service.shared_text == "채용 공고\n백엔드 엔지니어"
    metadata = json.loads(event_repository.events[0].metadata_json)
    assert metadata["ocr_status"] == "success"
    assert metadata["ocr_failure_reason"] is None
    assert metadata["category_assignment_method"] == "ai"
    assert metadata["recommended_category_id"] == 2
    assert "채용 공고" not in event_repository.events[0].metadata_json


@pytest.mark.asyncio
async def test_create_screenshot_user_category_wins_over_ocr_recommendation() -> None:
    recommendation_service = FakeRecommendationService(
        CategoryRecommendationResult(
            category_id=2,
            assignment_method=CategoryAssignmentMethod.AI,
            failure_reason=None,
        )
    )
    selected = category(3, "공부")
    service, content_repository, _ = build_service(
        categories=[selected],
        recommendation_service=recommendation_service,
    )

    await service.create_content(
        user_id=1,
        payload=ContentCreate(
            content_type=ContentType.SCREENSHOT,
            category_ids=[3],
        ),
        recommendation_shared_text="OCR 원문",
    )

    assert content_repository.created_categories == [selected]
    assert recommendation_service.calls == 0


@pytest.mark.asyncio
async def test_create_screenshot_persists_asset_in_same_transaction() -> None:
    service, content_repository, event_repository = build_service(
        categories=[category(2, "여행")]
    )

    result = await service.create_content(
        user_id=1,
        payload=ContentCreate(
            content_type=ContentType.SCREENSHOT,
            source=ContentSource.SCREENSHOT,
            category_ids=[2],
        ),
        asset=PendingContentAsset(
            asset_type=AssetType.SCREENSHOT,
            storage_key="screenshots/1/image.png",
            mime_type="image/png",
        ),
    )

    assert result.assets[0].download_url == "/api/v1/uploads/assets/1"
    assert result.assets[0].mime_type == "image/png"
    assert content_repository.created_assets[0].storage_key == "screenshots/1/image.png"
    assert event_repository.events[0].event_type == ContentEventType.CONTENT_CREATED
    assert content_repository.session.committed is True


@pytest.mark.asyncio
async def test_create_content_fails_when_uncategorized_is_missing() -> None:
    service, content_repository, _ = build_service()

    with pytest.raises(SystemConfigurationError) as exc_info:
        await service.create_content(
            user_id=1,
            payload=ContentCreate(original_url="https://example.com/post"),
        )

    assert exc_info.value.status_code == 500
    assert content_repository.contents == {}


@pytest.mark.asyncio
async def test_create_content_rejects_inaccessible_categories() -> None:
    service, content_repository, _ = build_service(
        categories=[category(1, "취업", is_default=True)]
    )

    with pytest.raises(NotFoundError):
        await service.create_content(
            user_id=1,
            payload=ContentCreate(
                original_url="https://example.com/post",
                category_ids=[1, 99],
            ),
        )

    assert content_repository.contents == {}


@pytest.mark.asyncio
async def test_create_link_content_requires_original_url() -> None:
    service, _, _ = build_service(uncategorized=category(9, "미분류", is_default=True))

    with pytest.raises(HTTPException) as exc_info:
        await service.create_content(
            user_id=1,
            payload=ContentCreate(content_type=ContentType.LINK, category_ids=[]),
        )

    assert exc_info.value.status_code == 422


@pytest.mark.asyncio
async def test_read_content_rejects_other_user_content() -> None:
    service, _, _ = build_service(contents=[content(1, user_id=2)])

    with pytest.raises(NotFoundError):
        await service.read_content(user_id=1, content_id=1)


@pytest.mark.asyncio
async def test_update_categories_replaces_categories_and_records_event() -> None:
    service, content_repository, event_repository = build_service(
        categories=[category(2, "여행"), category(3, "공부")],
        contents=[content(1)],
    )

    result = await service.update_categories(
        user_id=1,
        content_id=1,
        payload=ContentCategoryUpdate(category_ids=[3, 2, 3]),
    )

    assert [item.id for item in result.categories] == [2, 3]
    assert [item.id for item in content_repository.contents[1].categories] == [3, 2]
    assert event_repository.events[0].event_type == ContentEventType.CATEGORY_CHANGED
    assert json.loads(event_repository.events[0].metadata_json) == {
        "before_category_ids": [1],
        "after_category_ids": [2, 3],
    }
    assert content_repository.session.committed is True


@pytest.mark.asyncio
async def test_update_categories_uses_uncategorized_for_empty_ids() -> None:
    uncategorized = category(9, "미분류", is_default=True)
    service, content_repository, event_repository = build_service(
        uncategorized=uncategorized,
        contents=[content(1)],
    )

    result = await service.update_categories(
        user_id=1,
        content_id=1,
        payload=ContentCategoryUpdate(category_ids=[]),
    )

    assert [item.id for item in result.categories] == [9]
    assert content_repository.session.committed is True
    assert event_repository.events[0].event_type == ContentEventType.CATEGORY_CHANGED


@pytest.mark.asyncio
async def test_update_categories_skips_unchanged_set() -> None:
    existing_content = content(1)
    existing_content.categories = [category(2, "여행"), category(3, "공부")]
    service, content_repository, event_repository = build_service(
        categories=[category(2, "여행"), category(3, "공부")],
        contents=[existing_content],
    )

    result = await service.update_categories(
        user_id=1,
        content_id=1,
        payload=ContentCategoryUpdate(category_ids=[3, 2, 3]),
    )

    assert [item.id for item in result.categories] == [2, 3]
    assert event_repository.events == []
    assert content_repository.session.committed is False


@pytest.mark.asyncio
async def test_update_categories_rejects_uncategorized_with_other_categories() -> None:
    service, content_repository, event_repository = build_service(
        categories=[
            category(2, "여행"),
            category(9, "미분류", is_default=True),
        ],
        contents=[content(1)],
    )

    with pytest.raises(HTTPException) as exc_info:
        await service.update_categories(
            user_id=1,
            content_id=1,
            payload=ContentCategoryUpdate(category_ids=[9, 2]),
        )

    assert exc_info.value.status_code == 422
    assert content_repository.session.committed is False
    assert event_repository.events == []


@pytest.mark.asyncio
async def test_update_categories_rejects_inaccessible_category() -> None:
    service, content_repository, event_repository = build_service(
        categories=[category(2, "여행")],
        contents=[content(1)],
    )

    with pytest.raises(NotFoundError):
        await service.update_categories(
            user_id=1,
            content_id=1,
            payload=ContentCategoryUpdate(category_ids=[2, 99]),
        )

    assert content_repository.session.committed is False
    assert event_repository.events == []


@pytest.mark.asyncio
async def test_update_categories_rejects_other_user_content() -> None:
    service, _, _ = build_service(
        categories=[category(2, "여행")],
        contents=[content(1, user_id=2)],
    )

    with pytest.raises(NotFoundError):
        await service.update_categories(
            user_id=1,
            content_id=1,
            payload=ContentCategoryUpdate(category_ids=[2]),
        )


@pytest.mark.asyncio
async def test_update_categories_rolls_back_when_replacement_fails() -> None:
    service, content_repository, event_repository = build_service(
        categories=[category(2, "여행")],
        contents=[content(1)],
    )

    async def fail_replacement(*, content, categories):
        raise RuntimeError("replacement failed")

    content_repository.replace_categories = fail_replacement

    with pytest.raises(RuntimeError):
        await service.update_categories(
            user_id=1,
            content_id=1,
            payload=ContentCategoryUpdate(category_ids=[2]),
        )

    assert content_repository.session.rolled_back is True
    assert content_repository.session.committed is False
    assert event_repository.events == []


@pytest.mark.asyncio
async def test_update_categories_rolls_back_when_event_creation_fails() -> None:
    service, content_repository, event_repository = build_service(
        categories=[category(2, "여행")],
        contents=[content(1)],
    )

    async def fail_event_creation(**kwargs):
        raise RuntimeError("event creation failed")

    event_repository.create = fail_event_creation

    with pytest.raises(RuntimeError):
        await service.update_categories(
            user_id=1,
            content_id=1,
            payload=ContentCategoryUpdate(category_ids=[2]),
        )

    assert content_repository.session.rolled_back is True
    assert content_repository.session.committed is False


@pytest.mark.asyncio
async def test_update_tags_replaces_tags() -> None:
    existing_content = content(1)
    existing_content.tags = [SimpleNamespace(id=9, name="기존", normalized_name="기존")]
    service, content_repository, _ = build_service(contents=[existing_content])

    result = await service.update_tags(
        user_id=1,
        content_id=1,
        payload=ContentTagUpdate(tag_names=[" Flutter ", "#백엔드"]),
    )

    assert [tag.name for tag in result.tags] == ["Flutter", "백엔드"]
    assert [tag.name for tag in content_repository.contents[1].tags] == ["Flutter", "백엔드"]
    assert content_repository.session.committed is True


@pytest.mark.asyncio
async def test_update_tags_removes_all_links_but_keeps_tags() -> None:
    existing_content = content(1)
    existing_content.tags = [SimpleNamespace(id=9, name="기존", normalized_name="기존")]
    service, content_repository, _ = build_service(contents=[existing_content])

    result = await service.update_tags(
        user_id=1,
        content_id=1,
        payload=ContentTagUpdate(tag_names=[]),
    )

    assert result.tags == []
    assert content_repository.contents[1].tags == []
    assert content_repository.session.committed is True


@pytest.mark.asyncio
async def test_update_tags_skips_unchanged_set() -> None:
    existing_content = content(1)
    existing_content.tags = [SimpleNamespace(id=1, name="Flutter", normalized_name="flutter")]
    service, content_repository, _ = build_service(contents=[existing_content])

    result = await service.update_tags(
        user_id=1,
        content_id=1,
        payload=ContentTagUpdate(tag_names=["#flutter"]),
    )

    assert [tag.name for tag in result.tags] == ["Flutter"]
    assert content_repository.session.committed is False


@pytest.mark.asyncio
async def test_update_tags_rejects_other_user_content() -> None:
    service, _, _ = build_service(contents=[content(1, user_id=2)])

    with pytest.raises(NotFoundError):
        await service.update_tags(
            user_id=1,
            content_id=1,
            payload=ContentTagUpdate(tag_names=["Flutter"]),
        )


@pytest.mark.asyncio
async def test_update_tags_rolls_back_when_replacement_fails() -> None:
    service, content_repository, _ = build_service(contents=[content(1)])

    async def fail_replacement(*, content, tags):
        raise RuntimeError("replacement failed")

    content_repository.replace_tags = fail_replacement

    with pytest.raises(RuntimeError, match="replacement failed"):
        await service.update_tags(
            user_id=1,
            content_id=1,
            payload=ContentTagUpdate(tag_names=["Flutter"]),
        )

    assert content_repository.session.rolled_back is True
    assert content_repository.session.committed is False


@pytest.mark.asyncio
async def test_create_content_rolls_back_when_write_fails_after_resolving_tags() -> None:
    service, content_repository, _ = build_service(
        categories=[category(1, "취업", is_default=True)]
    )

    async def fail_create(**kwargs):
        raise RuntimeError("database unavailable")

    content_repository.create = fail_create

    with pytest.raises(RuntimeError, match="database unavailable"):
        await service.create_content(
            user_id=1,
            payload=ContentCreate(
                original_url="https://example.com/post",
                category_ids=[1],
                tag_names=["Flutter"],
            ),
        )

    assert content_repository.session.rolled_back is True
    assert content_repository.session.committed is False


@pytest.mark.asyncio
async def test_update_favorite_sets_requested_state() -> None:
    service, content_repository, event_repository = build_service(contents=[content(1)])

    result = await service.update_favorite(
        user_id=1,
        content_id=1,
        payload=ContentFavoriteUpdate(is_favorite=True),
    )

    assert result.is_favorite is True
    assert content_repository.contents[1].is_favorite is True
    assert content_repository.session.committed is True
    assert event_repository.events == []


@pytest.mark.asyncio
async def test_update_favorite_skips_unchanged_state() -> None:
    existing_content = content(1)
    existing_content.is_favorite = True
    service, content_repository, event_repository = build_service(contents=[existing_content])

    result = await service.update_favorite(
        user_id=1,
        content_id=1,
        payload=ContentFavoriteUpdate(is_favorite=True),
    )

    assert result.is_favorite is True
    assert content_repository.session.committed is False
    assert event_repository.events == []


@pytest.mark.asyncio
async def test_update_favorite_rejects_other_user_content() -> None:
    service, content_repository, _ = build_service(contents=[content(1, user_id=2)])

    with pytest.raises(NotFoundError):
        await service.update_favorite(
            user_id=1,
            content_id=1,
            payload=ContentFavoriteUpdate(is_favorite=True),
        )

    assert content_repository.session.committed is False


@pytest.mark.asyncio
async def test_update_favorite_rolls_back_when_write_fails() -> None:
    service, content_repository, _ = build_service(contents=[content(1)])

    async def fail_update(*, content, is_favorite):
        raise RuntimeError("favorite update failed")

    content_repository.set_favorite = fail_update

    with pytest.raises(RuntimeError, match="favorite update failed"):
        await service.update_favorite(
            user_id=1,
            content_id=1,
            payload=ContentFavoriteUpdate(is_favorite=True),
        )

    assert content_repository.session.rolled_back is True
    assert content_repository.session.committed is False


@pytest.mark.asyncio
async def test_delete_content_removes_link_content_without_storage_access() -> None:
    service, content_repository, event_repository = build_service(contents=[content(1)])

    await service.delete_content(user_id=1, content_id=1)

    assert content_repository.deleted_content_ids == [1]
    assert content_repository.contents == {}
    assert content_repository.session.committed is True
    assert event_repository.events == []


@pytest.mark.asyncio
async def test_delete_content_removes_all_asset_files_after_database_commit() -> None:
    existing_content = content(1)
    existing_content.assets = [
        SimpleNamespace(id=10, storage_key="screenshots/1/first.png"),
        SimpleNamespace(id=11, storage_key="screenshots/1/second.png"),
    ]
    storage_client = FakeStorageClient()
    service, content_repository, _ = build_service(
        contents=[existing_content],
        storage_client=storage_client,
    )

    await service.delete_content(user_id=1, content_id=1)

    assert content_repository.session.committed is True
    assert storage_client.deleted_keys == [
        "screenshots/1/first.png",
        "screenshots/1/second.png",
    ]


@pytest.mark.asyncio
async def test_delete_content_rolls_back_without_deleting_files_when_database_fails() -> None:
    existing_content = content(1)
    existing_content.assets = [
        SimpleNamespace(id=10, storage_key="screenshots/1/image.png"),
    ]
    storage_client = FakeStorageClient()
    service, content_repository, _ = build_service(
        contents=[existing_content],
        storage_client=storage_client,
    )

    async def fail_delete(content):
        raise RuntimeError("content delete failed")

    content_repository.delete = fail_delete

    with pytest.raises(RuntimeError, match="content delete failed"):
        await service.delete_content(user_id=1, content_id=1)

    assert content_repository.session.rolled_back is True
    assert content_repository.session.committed is False
    assert storage_client.deleted_keys == []


@pytest.mark.asyncio
async def test_delete_content_logs_file_failure_and_keeps_successful_response(caplog) -> None:
    existing_content = content(1)
    existing_content.assets = [
        SimpleNamespace(id=10, storage_key="screenshots/1/image.png"),
    ]
    storage_client = FakeStorageClient(fail_keys={"screenshots/1/image.png"})
    service, content_repository, _ = build_service(
        contents=[existing_content],
        storage_client=storage_client,
    )

    await service.delete_content(user_id=1, content_id=1)

    assert content_repository.session.committed is True
    assert storage_client.deleted_keys == ["screenshots/1/image.png"]
    assert "Failed to delete content asset file" in caplog.text


@pytest.mark.asyncio
async def test_delete_content_rejects_other_user_content() -> None:
    storage_client = FakeStorageClient()
    service, content_repository, _ = build_service(
        contents=[content(1, user_id=2)],
        storage_client=storage_client,
    )

    with pytest.raises(NotFoundError):
        await service.delete_content(user_id=1, content_id=1)

    assert content_repository.deleted_content_ids == []
    assert content_repository.session.committed is False
    assert storage_client.deleted_keys == []


@pytest.mark.asyncio
async def test_record_view_updates_content_and_records_event() -> None:
    service, content_repository, event_repository = build_service(contents=[content(1)])

    result = await service.record_view(user_id=1, content_id=1)

    assert result.content_id == 1
    assert result.event_type == ContentEventType.CONTENT_REOPENED.value
    assert content_repository.contents[1].last_viewed_at is not None
    assert event_repository.events[0].event_type == ContentEventType.CONTENT_REOPENED
    assert content_repository.session.committed is True


@pytest.mark.asyncio
async def test_record_view_rejects_other_user_content() -> None:
    service, _, _ = build_service(contents=[content(1, user_id=2)])

    with pytest.raises(NotFoundError):
        await service.record_view(user_id=1, content_id=1)
