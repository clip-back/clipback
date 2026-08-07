import json

import pytest
from fastapi import HTTPException

from app.integrations.metadata_client import MetadataResult, UnsafeUrlError
from app.schemas.content import ContentCreate, ContentSource
from app.services.extraction_service import ExtractionResult, ExtractionService


class FakeMetadataClient:
    def __init__(
        self,
        result: MetadataResult | None = None,
        error: Exception | None = None,
    ) -> None:
        self.result = result
        self.error = error
        self.requested_url: str | None = None

    async def extract_from_url(self, url: str) -> MetadataResult:
        self.requested_url = url
        if self.error is not None:
            raise self.error
        assert self.result is not None
        return self.result


@pytest.mark.asyncio
async def test_enrich_link_prefers_non_empty_user_values() -> None:
    metadata_client = FakeMetadataClient(
        MetadataResult(
            resolved_url="https://final.example.com/post",
            title="추출 제목",
            description="추출 설명",
            status="success",
        )
    )
    service = ExtractionService(metadata_client=metadata_client)
    payload = ContentCreate(
        original_url="https://short.example.com/a#fragment",
        source=ContentSource.UNKNOWN,
        title="  사용자 제목  ",
        summary="사용자 설명",
    )

    result = await service.enrich_link(payload)
    enriched = service.apply_to_payload(payload, result)

    assert result.title == "  사용자 제목  "
    assert result.description == "사용자 설명"
    assert result.resolved_url == "https://final.example.com/post"
    assert result.source == ContentSource.WEB
    assert str(enriched.original_url) == "https://final.example.com/post"
    assert enriched.source == ContentSource.WEB


@pytest.mark.asyncio
async def test_enrich_link_uses_metadata_for_blank_user_values() -> None:
    service = ExtractionService(
        metadata_client=FakeMetadataClient(
            MetadataResult(
                resolved_url="https://example.com/post",
                title="추출 제목",
                description="추출 설명",
                status="success",
            )
        )
    )

    result = await service.enrich_link(
        ContentCreate(original_url="https://example.com/post", title="  ", summary="\n")
    )

    assert result.title == "추출 제목"
    assert result.description == "추출 설명"


@pytest.mark.asyncio
async def test_enrich_instagram_preserves_normalized_original_url() -> None:
    metadata_client = FakeMetadataClient(
        MetadataResult(
            resolved_url="https://www.instagram.com/accounts/login/",
            title=None,
            description=None,
            status="failed",
            failure_reason="metadata_missing",
        )
    )
    service = ExtractionService(metadata_client=metadata_client)

    result = await service.enrich_link(
        ContentCreate(
            original_url="https://instagram.com/reel/ABC/?igsh=x#fragment",
            source=ContentSource.WEB,
        )
    )

    assert metadata_client.requested_url == "https://www.instagram.com/reel/ABC/"
    assert result.resolved_url == "https://www.instagram.com/reel/ABC/"
    assert result.source == ContentSource.INSTAGRAM
    assert result.status == "failed"


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("resolved_url", "expected_source"),
    [
        ("https://www.instagram.com/p/ABC/", ContentSource.INSTAGRAM),
        ("https://m.youtube.com/watch?v=x", ContentSource.YOUTUBE),
        ("https://youtu.be/abc", ContentSource.YOUTUBE),
        ("https://vm.tiktok.com/abc", ContentSource.TIKTOK),
        ("https://news.example.com/post", ContentSource.WEB),
    ],
)
async def test_enrich_link_infers_source_from_resolved_host(
    resolved_url: str,
    expected_source: ContentSource,
) -> None:
    service = ExtractionService(
        metadata_client=FakeMetadataClient(
            MetadataResult(
                resolved_url=resolved_url,
                title=None,
                description=None,
                status="failed",
                failure_reason="metadata_missing",
            )
        )
    )

    input_url = resolved_url
    if expected_source == ContentSource.INSTAGRAM:
        input_url = "https://www.instagram.com/p/ABC/"
    result = await service.enrich_link(ContentCreate(original_url=input_url))

    assert result.source == expected_source


@pytest.mark.asyncio
async def test_enrich_link_converts_unsafe_url_to_422() -> None:
    service = ExtractionService(
        metadata_client=FakeMetadataClient(error=UnsafeUrlError("Private URL"))
    )

    with pytest.raises(HTTPException) as exc_info:
        await service.enrich_link(ContentCreate(original_url="http://127.0.0.1"))

    assert exc_info.value.status_code == 422
    assert exc_info.value.detail == "Private URL"


def test_build_event_metadata_contains_only_enrichment_fields() -> None:
    result = ExtractionResult(
        resolved_url="https://example.com/post",
        title=None,
        description=None,
        source=ContentSource.WEB,
        status="failed",
        failure_reason="timeout",
    )
    service = ExtractionService(metadata_client=FakeMetadataClient(result))

    metadata_json = service.build_event_metadata_json(
        result,
        base={"url_source": "url"},
    )

    assert json.loads(metadata_json) == {
        "url_source": "url",
        "metadata_status": "failed",
        "metadata_failure_reason": "timeout",
        "resolved_url": "https://example.com/post",
    }


def test_build_event_metadata_respects_database_length_limit() -> None:
    result = ExtractionResult(
        resolved_url=f"https://example.com/{'a' * 1500}",
        title=None,
        description=None,
        source=ContentSource.WEB,
        status="failed",
        failure_reason="metadata_missing",
    )
    service = ExtractionService(metadata_client=FakeMetadataClient())

    metadata_json = service.build_event_metadata_json(result)

    assert len(metadata_json) <= 1000
    assert json.loads(metadata_json)["metadata_status"] == "failed"
