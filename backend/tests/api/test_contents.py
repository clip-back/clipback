from datetime import UTC, datetime
from types import SimpleNamespace

from fastapi.testclient import TestClient

from app.api.v1.endpoints import contents as content_endpoints
from app.core.security import create_access_token
from app.integrations.metadata_client import MetadataResult
from app.repositories.auth_session_repository import AuthSessionRepository
from app.repositories.user_repository import UserRepository
from app.schemas.content import ContentCreate, ContentRead
from app.services.extraction_service import ExtractionService


class FakeMetadataClient:
    async def extract_from_url(self, url: str) -> MetadataResult:
        return MetadataResult(
            resolved_url="https://www.instagram.com/accounts/login/",
            title="공통 추출 제목",
            description="공통 추출 설명",
            status="success",
        )


class FakeContentService:
    def __init__(self) -> None:
        self.requests: list[tuple[ContentCreate, str | None]] = []

    async def create_content(
        self,
        user_id: int,
        payload: ContentCreate,
        event_metadata_json: str | None = None,
    ) -> ContentRead:
        self.requests.append((payload, event_metadata_json))
        return ContentRead(
            id=len(self.requests),
            categories=[],
            content_type=payload.content_type,
            source=payload.source,
            title=payload.title or "저장한 콘텐츠",
            summary=payload.summary or "요약 정보가 아직 없습니다.",
            original_url=str(payload.original_url) if payload.original_url else None,
            is_favorite=payload.is_favorite,
            saved_at=datetime.now(UTC),
        )


def test_direct_and_share_routes_use_same_enrichment_pipeline(
    client: TestClient,
    monkeypatch,
) -> None:
    async def get_active(self, *, session_id: int, user_id: int):
        return SimpleNamespace(id=session_id, user_id=user_id)

    async def get_user(self, user_id: int):
        return SimpleNamespace(id=user_id)

    content_service = FakeContentService()
    extraction_service = ExtractionService(metadata_client=FakeMetadataClient())
    monkeypatch.setattr(AuthSessionRepository, "get_active", get_active)
    monkeypatch.setattr(UserRepository, "get", get_user)
    monkeypatch.setattr(content_endpoints, "_build_content_service", lambda db: content_service)
    monkeypatch.setattr(content_endpoints, "ExtractionService", lambda: extraction_service)
    token = create_access_token(user_id=1, session_id=1)
    headers = {"Authorization": f"Bearer {token}"}
    url = "https://www.instagram.com/reel/ABC/?igsh=x"

    direct = client.post("/api/v1/contents", json={"original_url": url}, headers=headers)
    shared = client.post(
        "/api/v1/contents/share",
        json={"url": url, "mime_type": "text/plain", "platform": "android"},
        headers=headers,
    )

    assert direct.status_code == 201
    assert shared.status_code == 201
    for response in (direct, shared):
        assert response.json()["title"] == "공통 추출 제목"
        assert response.json()["summary"] == "공통 추출 설명"
        assert response.json()["original_url"] == "https://www.instagram.com/reel/ABC/"
