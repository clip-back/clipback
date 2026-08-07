from datetime import UTC, datetime
from types import SimpleNamespace

from fastapi.testclient import TestClient

from app.api.v1.endpoints import uploads as upload_endpoints
from app.core.exceptions import NotFoundError
from app.core.security import create_access_token
from app.repositories.auth_session_repository import AuthSessionRepository
from app.repositories.user_repository import UserRepository
from app.schemas.content import (
    ContentAssetRead,
    ContentAssetType,
    ContentRead,
    ContentSource,
    ContentType,
)
from app.services.upload_service import StoredAssetFile


class FakeUploadService:
    def __init__(self) -> None:
        self.uploads: list[tuple[int, list[int]]] = []

    async def upload_screenshot(self, *, user_id: int, file, category_ids: list[int]):
        self.uploads.append((user_id, category_ids))
        return ContentRead(
            id=11,
            categories=[],
            assets=[
                ContentAssetRead(
                    id=7,
                    asset_type=ContentAssetType.SCREENSHOT,
                    mime_type="image/png",
                    download_url="/api/v1/uploads/assets/7",
                )
            ],
            content_type=ContentType.SCREENSHOT,
            source=ContentSource.SCREENSHOT,
            title="저장한 콘텐츠",
            summary="요약 정보가 아직 없습니다.",
            saved_at=datetime.now(UTC),
        )

    async def read_asset(self, *, user_id: int, asset_id: int) -> StoredAssetFile:
        if user_id != 3 or asset_id != 7:
            raise NotFoundError("Content asset not found")
        return StoredAssetFile(content=b"image", mime_type="image/png")


def authenticate(monkeypatch) -> dict[str, str]:
    async def get_active(self, *, session_id: int, user_id: int):
        return SimpleNamespace(id=session_id, user_id=user_id)

    async def get_user(self, user_id: int):
        return SimpleNamespace(id=user_id)

    monkeypatch.setattr(AuthSessionRepository, "get_active", get_active)
    monkeypatch.setattr(UserRepository, "get", get_user)
    token = create_access_token(user_id=3, session_id=5)
    return {"Authorization": f"Bearer {token}"}


def test_upload_screenshot_returns_content_with_private_asset_url(
    client: TestClient,
    monkeypatch,
) -> None:
    service = FakeUploadService()
    monkeypatch.setattr(upload_endpoints, "_build_upload_service", lambda db: service)

    response = client.post(
        "/api/v1/uploads/screenshots",
        headers=authenticate(monkeypatch),
        files={"file": ("screenshot.png", b"image", "application/octet-stream")},
        data={"category_ids": "2"},
    )

    assert response.status_code == 201
    assert response.json()["content_type"] == "screenshot"
    assert response.json()["assets"] == [
        {
            "id": 7,
            "asset_type": "screenshot",
            "mime_type": "image/png",
            "download_url": "/api/v1/uploads/assets/7",
        }
    ]
    assert "storage_key" not in response.text
    assert service.uploads == [(3, [2])]


def test_read_asset_returns_inline_image(client: TestClient, monkeypatch) -> None:
    service = FakeUploadService()
    monkeypatch.setattr(upload_endpoints, "_build_upload_service", lambda db: service)

    response = client.get(
        "/api/v1/uploads/assets/7",
        headers=authenticate(monkeypatch),
    )

    assert response.status_code == 200
    assert response.content == b"image"
    assert response.headers["content-type"] == "image/png"
    assert response.headers["content-disposition"] == "inline"
    assert response.headers["x-content-type-options"] == "nosniff"


def test_read_asset_hides_unowned_asset(client: TestClient, monkeypatch) -> None:
    service = FakeUploadService()
    monkeypatch.setattr(upload_endpoints, "_build_upload_service", lambda db: service)

    response = client.get(
        "/api/v1/uploads/assets/99",
        headers=authenticate(monkeypatch),
    )

    assert response.status_code == 404


def test_read_asset_requires_authentication(client: TestClient) -> None:
    response = client.get("/api/v1/uploads/assets/7")

    assert response.status_code == 401
