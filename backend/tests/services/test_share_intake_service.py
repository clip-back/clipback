import json
from datetime import UTC, datetime

import pytest
from fastapi import HTTPException

from app.integrations.metadata_client import MetadataResult
from app.schemas.content import (
    ContentCreate,
    ContentRead,
    ContentShareCreate,
    ContentSource,
    ContentType,
    ShareAttachment,
)
from app.services.extraction_service import ExtractionService
from app.services.share_intake_service import ShareIntakeService


class FakeContentService:
    def __init__(self) -> None:
        self.user_id: int | None = None
        self.payload: ContentCreate | None = None
        self.event_metadata_json: str | None = None
        self.recommendation_shared_text: str | None = None

    async def create_content(
        self,
        user_id: int,
        payload: ContentCreate,
        event_metadata_json: str | None = None,
        recommendation_shared_text: str | None = None,
    ) -> ContentRead:
        self.user_id = user_id
        self.payload = payload
        self.event_metadata_json = event_metadata_json
        self.recommendation_shared_text = recommendation_shared_text

        return ContentRead(
            id=1,
            categories=[],
            content_type=payload.content_type,
            source=payload.source,
            title="저장한 콘텐츠",
            summary="요약 정보가 아직 없습니다.",
            original_url=str(payload.original_url) if payload.original_url else None,
            is_favorite=payload.is_favorite,
            saved_at=datetime.now(UTC),
        )


class FakeMetadataClient:
    async def extract_from_url(self, url: str) -> MetadataResult:
        return MetadataResult(
            resolved_url="https://www.instagram.com/accounts/login/",
            title="Instagram 제목",
            description="Instagram 설명",
            status="success",
        )


def build_service() -> tuple[ShareIntakeService, FakeContentService]:
    content_service = FakeContentService()
    return (
        ShareIntakeService(
            content_service=content_service,
            extraction_service=ExtractionService(metadata_client=FakeMetadataClient()),
        ),
        content_service,
    )


@pytest.mark.asyncio
async def test_create_instagram_content_normalizes_url_field_and_metadata() -> None:
    service, content_service = build_service()

    result = await service.create_instagram_content(
        user_id=1,
        payload=ContentShareCreate(
            url="https://www.instagram.com/reel/SHORTCODE/?igsh=abc#fragment",
            raw_text="raw text should not be persisted",
            mime_type="text/plain",
            source_app="com.instagram.android",
            platform="android",
            attachments=[ShareAttachment(filename="preview.jpg", mime_type="image/jpeg")],
            category_ids=[2, 3],
            is_favorite=True,
        ),
    )

    assert result.source == ContentSource.INSTAGRAM
    assert result.original_url == "https://www.instagram.com/reel/SHORTCODE/"
    assert content_service.user_id == 1
    assert content_service.payload is not None
    assert content_service.payload.content_type == ContentType.LINK
    assert content_service.payload.source == ContentSource.INSTAGRAM
    assert content_service.payload.title == "Instagram 제목"
    assert content_service.payload.summary == "Instagram 설명"
    assert str(content_service.payload.original_url) == "https://www.instagram.com/reel/SHORTCODE/"
    assert content_service.payload.category_ids == [2, 3]
    assert content_service.payload.is_favorite is True

    assert content_service.event_metadata_json is not None
    metadata = json.loads(content_service.event_metadata_json)
    assert metadata == {
        "source_app": "com.instagram.android",
        "platform": "android",
        "mime_type": "text/plain",
        "attachment_count": 1,
        "extracted_url": "https://www.instagram.com/reel/SHORTCODE/",
        "url_source": "url",
        "metadata_status": "success",
        "metadata_failure_reason": None,
        "resolved_url": "https://www.instagram.com/reel/SHORTCODE/",
    }
    assert "raw text should not be persisted" not in content_service.event_metadata_json
    assert content_service.recommendation_shared_text == "raw text should not be persisted"


@pytest.mark.asyncio
async def test_create_instagram_content_extracts_url_from_raw_text() -> None:
    service, content_service = build_service()

    await service.create_instagram_content(
        user_id=1,
        payload=ContentShareCreate(
            raw_text="나중에 보기 https://instagram.com/p/ABC123/?igsh=abc.",
        ),
    )

    assert content_service.payload is not None
    assert str(content_service.payload.original_url) == "https://www.instagram.com/p/ABC123/"
    assert content_service.event_metadata_json is not None
    assert json.loads(content_service.event_metadata_json)["url_source"] == "raw_text"


@pytest.mark.asyncio
async def test_create_instagram_content_normalizes_http_and_host() -> None:
    service, content_service = build_service()

    await service.create_instagram_content(
        user_id=1,
        payload=ContentShareCreate(url="http://instagram.com/p/ABC123"),
    )

    assert content_service.payload is not None
    assert str(content_service.payload.original_url) == "https://www.instagram.com/p/ABC123/"


@pytest.mark.asyncio
async def test_create_instagram_content_rejects_missing_url() -> None:
    service, _ = build_service()

    with pytest.raises(HTTPException) as exc_info:
        await service.create_instagram_content(user_id=1, payload=ContentShareCreate())

    assert exc_info.value.status_code == 422


@pytest.mark.asyncio
async def test_create_instagram_content_rejects_non_instagram_url() -> None:
    service, _ = build_service()

    with pytest.raises(HTTPException) as exc_info:
        await service.create_instagram_content(
            user_id=1,
            payload=ContentShareCreate(url="https://youtube.com/watch?v=abc"),
        )

    assert exc_info.value.status_code == 422


@pytest.mark.asyncio
async def test_create_instagram_content_rejects_unsupported_instagram_path() -> None:
    service, _ = build_service()

    with pytest.raises(HTTPException) as exc_info:
        await service.create_instagram_content(
            user_id=1,
            payload=ContentShareCreate(url="https://www.instagram.com/accounts/login/"),
        )

    assert exc_info.value.status_code == 422
