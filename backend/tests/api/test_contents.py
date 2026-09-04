from datetime import UTC, datetime
from types import SimpleNamespace

from fastapi.testclient import TestClient

from app.api.v1.endpoints import contents as content_endpoints
from app.core.security import create_access_token
from app.integrations.metadata_client import MetadataResult
from app.repositories.auth_session_repository import AuthSessionRepository
from app.repositories.user_repository import UserRepository
from app.schemas.content import (
    ContentCategoryUpdate,
    ContentCreate,
    ContentFavoriteUpdate,
    ContentRead,
    ContentSource,
    ContentTagUpdate,
    ContentType,
)
from app.schemas.tag import TagRead
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
        self.category_update_requests: list[tuple[int, int, ContentCategoryUpdate]] = []
        self.tag_update_requests: list[tuple[int, int, ContentTagUpdate]] = []
        self.favorite_update_requests: list[tuple[int, int, ContentFavoriteUpdate]] = []
        self.delete_requests: list[tuple[int, int]] = []

    async def create_content(
        self,
        user_id: int,
        payload: ContentCreate,
        event_metadata_json: str | None = None,
        recommendation_shared_text: str | None = None,
    ) -> ContentRead:
        self.requests.append((payload, event_metadata_json))
        return ContentRead(
            id=len(self.requests),
            categories=[],
            tags=[TagRead(id=index, name=name) for index, name in enumerate(payload.tag_names, 1)],
            content_type=payload.content_type,
            source=payload.source,
            title=payload.title or "저장한 콘텐츠",
            summary=payload.summary or "요약 정보가 아직 없습니다.",
            original_url=str(payload.original_url) if payload.original_url else None,
            is_favorite=payload.is_favorite,
            saved_at=datetime.now(UTC),
        )

    async def update_tags(
        self,
        *,
        user_id: int,
        content_id: int,
        payload: ContentTagUpdate,
    ) -> ContentRead:
        self.tag_update_requests.append((user_id, content_id, payload))
        return ContentRead(
            id=content_id,
            categories=[],
            tags=[TagRead(id=index, name=name) for index, name in enumerate(payload.tag_names, 1)],
            content_type=ContentType.LINK,
            source=ContentSource.WEB,
            title="저장한 콘텐츠",
            summary="요약",
            original_url="https://example.com/original",
            saved_at=datetime.now(UTC),
        )

    async def update_categories(
        self,
        *,
        user_id: int,
        content_id: int,
        payload: ContentCategoryUpdate,
    ) -> ContentRead:
        self.category_update_requests.append((user_id, content_id, payload))
        return ContentRead(
            id=content_id,
            categories=[],
            content_type=ContentType.LINK,
            source=ContentSource.WEB,
            title="저장한 콘텐츠",
            summary="요약",
            original_url="https://example.com/original",
            saved_at=datetime.now(UTC),
        )

    async def update_favorite(
        self,
        *,
        user_id: int,
        content_id: int,
        payload: ContentFavoriteUpdate,
    ) -> ContentRead:
        self.favorite_update_requests.append((user_id, content_id, payload))
        return ContentRead(
            id=content_id,
            categories=[],
            content_type=ContentType.LINK,
            source=ContentSource.WEB,
            title="저장한 콘텐츠",
            summary="요약",
            original_url="https://example.com/original",
            is_favorite=payload.is_favorite,
            saved_at=datetime.now(UTC),
        )

    async def delete_content(self, *, user_id: int, content_id: int) -> None:
        self.delete_requests.append((user_id, content_id))


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

    direct = client.post(
        "/api/v1/contents",
        json={"original_url": url, "tag_names": ["Flutter", "#백엔드"]},
        headers=headers,
    )
    shared = client.post(
        "/api/v1/contents/share",
        json={
            "url": url,
            "mime_type": "text/plain",
            "platform": "android",
            "tag_names": ["Flutter", "#백엔드"],
        },
        headers=headers,
    )

    assert direct.status_code == 201
    assert shared.status_code == 201
    for response in (direct, shared):
        assert response.json()["title"] == "공통 추출 제목"
        assert response.json()["summary"] == "공통 추출 설명"
        assert response.json()["original_url"] == "https://www.instagram.com/reel/ABC/"
        assert response.json()["tags"] == [
            {"id": 1, "name": "Flutter"},
            {"id": 2, "name": "백엔드"},
        ]
    assert content_service.requests[0][0].tag_names == ["Flutter", "백엔드"]
    assert content_service.requests[1][0].tag_names == ["Flutter", "백엔드"]


def test_update_content_categories_route_uses_authenticated_user(
    client: TestClient,
    monkeypatch,
) -> None:
    async def get_active(self, *, session_id: int, user_id: int):
        return SimpleNamespace(id=session_id, user_id=user_id)

    async def get_user(self, user_id: int):
        return SimpleNamespace(id=user_id)

    content_service = FakeContentService()
    monkeypatch.setattr(AuthSessionRepository, "get_active", get_active)
    monkeypatch.setattr(UserRepository, "get", get_user)
    monkeypatch.setattr(content_endpoints, "_build_content_service", lambda db: content_service)
    token = create_access_token(user_id=7, session_id=3)

    response = client.put(
        "/api/v1/contents/42/categories",
        json={"category_ids": [3, 2, 3]},
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 200
    assert response.json()["id"] == 42
    request = content_service.category_update_requests[0]
    assert request[0] == 7
    assert request[1] == 42
    assert request[2].category_ids == [3, 2, 3]


def test_update_content_tags_route_uses_authenticated_user(
    client: TestClient,
    monkeypatch,
) -> None:
    async def get_active(self, *, session_id: int, user_id: int):
        return SimpleNamespace(id=session_id, user_id=user_id)

    async def get_user(self, user_id: int):
        return SimpleNamespace(id=user_id)

    content_service = FakeContentService()
    monkeypatch.setattr(AuthSessionRepository, "get_active", get_active)
    monkeypatch.setattr(UserRepository, "get", get_user)
    monkeypatch.setattr(content_endpoints, "_build_content_service", lambda db: content_service)
    token = create_access_token(user_id=7, session_id=3)

    response = client.put(
        "/api/v1/contents/42/tags",
        json={"tag_names": [" Flutter ", "#flutter", "백엔드"]},
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 200
    assert response.json()["tags"] == [
        {"id": 1, "name": "Flutter"},
        {"id": 2, "name": "백엔드"},
    ]
    request = content_service.tag_update_requests[0]
    assert request[0] == 7
    assert request[1] == 42
    assert request[2].tag_names == ["Flutter", "백엔드"]


def test_update_content_favorite_route_uses_authenticated_user(
    client: TestClient,
    monkeypatch,
) -> None:
    async def get_active(self, *, session_id: int, user_id: int):
        return SimpleNamespace(id=session_id, user_id=user_id)

    async def get_user(self, user_id: int):
        return SimpleNamespace(id=user_id)

    content_service = FakeContentService()
    monkeypatch.setattr(AuthSessionRepository, "get_active", get_active)
    monkeypatch.setattr(UserRepository, "get", get_user)
    monkeypatch.setattr(content_endpoints, "_build_content_service", lambda db: content_service)
    token = create_access_token(user_id=7, session_id=3)

    response = client.put(
        "/api/v1/contents/42/favorite",
        json={"is_favorite": True},
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 200
    assert response.json()["is_favorite"] is True
    request = content_service.favorite_update_requests[0]
    assert request[0] == 7
    assert request[1] == 42
    assert request[2].is_favorite is True


def test_update_content_favorite_rejects_missing_state(
    client: TestClient,
    monkeypatch,
) -> None:
    async def get_active(self, *, session_id: int, user_id: int):
        return SimpleNamespace(id=session_id, user_id=user_id)

    async def get_user(self, user_id: int):
        return SimpleNamespace(id=user_id)

    monkeypatch.setattr(AuthSessionRepository, "get_active", get_active)
    monkeypatch.setattr(UserRepository, "get", get_user)
    token = create_access_token(user_id=7, session_id=3)

    response = client.put(
        "/api/v1/contents/42/favorite",
        json={},
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 422


def test_delete_content_route_uses_authenticated_user(
    client: TestClient,
    monkeypatch,
) -> None:
    async def get_active(self, *, session_id: int, user_id: int):
        return SimpleNamespace(id=session_id, user_id=user_id)

    async def get_user(self, user_id: int):
        return SimpleNamespace(id=user_id)

    content_service = FakeContentService()
    monkeypatch.setattr(AuthSessionRepository, "get_active", get_active)
    monkeypatch.setattr(UserRepository, "get", get_user)
    monkeypatch.setattr(content_endpoints, "_build_content_service", lambda db: content_service)
    token = create_access_token(user_id=7, session_id=3)

    response = client.delete(
        "/api/v1/contents/42",
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 204
    assert response.content == b""
    assert content_service.delete_requests == [(7, 42)]


def test_create_content_rejects_invalid_tag_names(client: TestClient, monkeypatch) -> None:
    async def get_active(self, *, session_id: int, user_id: int):
        return SimpleNamespace(id=session_id, user_id=user_id)

    async def get_user(self, user_id: int):
        return SimpleNamespace(id=user_id)

    monkeypatch.setattr(AuthSessionRepository, "get_active", get_active)
    monkeypatch.setattr(UserRepository, "get", get_user)
    token = create_access_token(user_id=1, session_id=1)
    headers = {"Authorization": f"Bearer {token}"}

    invalid_tag_names = [
        ["#"],
        ["x" * 41],
        [str(index) for index in range(11)],
    ]
    for tag_names in invalid_tag_names:
        response = client.post(
            "/api/v1/contents",
            json={"original_url": "https://example.com", "tag_names": tag_names},
            headers=headers,
        )

        assert response.status_code == 422
