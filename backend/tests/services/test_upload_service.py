from datetime import UTC, datetime
from io import BytesIO
from types import SimpleNamespace

import pytest
from fastapi import HTTPException
from PIL import Image

from app.core.exceptions import NotFoundError
from app.schemas.content import (
    ContentAssetRead,
    ContentAssetType,
    ContentRead,
    ContentSource,
    ContentType,
)
from app.services.upload_service import UploadService


class FakeUploadFile:
    def __init__(self, content: bytes, content_type: str = "application/pdf") -> None:
        self.content = content
        self.content_type = content_type
        self.requested_size: int | None = None

    async def read(self, size: int = -1) -> bytes:
        self.requested_size = size
        return self.content if size < 0 else self.content[:size]


class FakeStorageClient:
    def __init__(self) -> None:
        self.files: dict[str, bytes] = {}
        self.deleted_keys: list[str] = []
        self.fail_save = False
        self.fail_delete = False

    async def save_file(self, storage_key: str, content: bytes) -> None:
        if self.fail_save:
            raise OSError("storage unavailable")
        self.files[storage_key] = content

    async def read_file(self, storage_key: str) -> bytes:
        if storage_key not in self.files:
            raise FileNotFoundError(storage_key)
        return self.files[storage_key]

    async def delete_file(self, storage_key: str) -> None:
        self.deleted_keys.append(storage_key)
        if self.fail_delete:
            raise OSError("delete unavailable")
        self.files.pop(storage_key, None)


class FakeContentService:
    def __init__(self) -> None:
        self.calls: list[tuple[int, object, object]] = []
        self.error: Exception | None = None

    async def create_content(self, *, user_id: int, payload, asset) -> ContentRead:
        self.calls.append((user_id, payload, asset))
        if self.error is not None:
            raise self.error
        return ContentRead(
            id=1,
            categories=[],
            assets=[
                ContentAssetRead(
                    id=7,
                    asset_type=ContentAssetType.SCREENSHOT,
                    mime_type=asset.mime_type,
                    download_url="/api/v1/uploads/assets/7",
                )
            ],
            content_type=payload.content_type,
            source=payload.source,
            title="저장한 콘텐츠",
            summary="요약 정보가 아직 없습니다.",
            saved_at=datetime.now(UTC),
        )


class FakeContentAssetRepository:
    def __init__(self, assets: dict[tuple[int, int], SimpleNamespace] | None = None) -> None:
        self.assets = assets or {}

    async def get_owned(self, *, user_id: int, asset_id: int):
        return self.assets.get((user_id, asset_id))


def make_image(image_format: str) -> bytes:
    output = BytesIO()
    Image.new("RGB", (2, 2), color="white").save(output, format=image_format)
    return output.getvalue()


def build_service(
    *,
    storage: FakeStorageClient | None = None,
    content_service: FakeContentService | None = None,
    asset_repository: FakeContentAssetRepository | None = None,
    max_bytes: int = 1024,
) -> tuple[UploadService, FakeStorageClient, FakeContentService]:
    storage = storage or FakeStorageClient()
    content_service = content_service or FakeContentService()
    return (
        UploadService(
            content_service=content_service,
            content_asset_repository=asset_repository or FakeContentAssetRepository(),
            storage_client=storage,
            max_bytes=max_bytes,
        ),
        storage,
        content_service,
    )


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("image_format", "expected_mime_type", "expected_extension"),
    [
        ("PNG", "image/png", ".png"),
        ("JPEG", "image/jpeg", ".jpg"),
        ("WEBP", "image/webp", ".webp"),
    ],
)
async def test_upload_screenshot_stores_supported_image_using_detected_format(
    image_format: str,
    expected_mime_type: str,
    expected_extension: str,
) -> None:
    service, storage, content_service = build_service(max_bytes=10_000)
    file = FakeUploadFile(make_image(image_format))

    result = await service.upload_screenshot(user_id=3, file=file, category_ids=[2])

    storage_key = next(iter(storage.files))
    _, payload, asset = content_service.calls[0]
    assert storage_key.startswith("screenshots/3/")
    assert storage_key.endswith(expected_extension)
    assert payload.content_type == ContentType.SCREENSHOT
    assert payload.source == ContentSource.SCREENSHOT
    assert payload.category_ids == [2]
    assert asset.mime_type == expected_mime_type
    assert file.content_type == "application/pdf"
    assert result.assets[0].mime_type == expected_mime_type
    assert file.requested_size == 10_001


@pytest.mark.asyncio
async def test_upload_screenshot_rejects_empty_file() -> None:
    service, storage, content_service = build_service()

    with pytest.raises(HTTPException) as exc_info:
        await service.upload_screenshot(user_id=1, file=FakeUploadFile(b""), category_ids=[])

    assert exc_info.value.status_code == 422
    assert storage.files == {}
    assert content_service.calls == []


@pytest.mark.asyncio
async def test_upload_screenshot_rejects_file_over_limit() -> None:
    service, storage, content_service = build_service(max_bytes=3)

    with pytest.raises(HTTPException) as exc_info:
        await service.upload_screenshot(user_id=1, file=FakeUploadFile(b"1234"), category_ids=[])

    assert exc_info.value.status_code == 413
    assert storage.files == {}
    assert content_service.calls == []


@pytest.mark.asyncio
@pytest.mark.parametrize("content", [b"not-an-image", make_image("BMP")])
async def test_upload_screenshot_rejects_invalid_or_unsupported_image(content: bytes) -> None:
    service, storage, content_service = build_service(max_bytes=10_000)

    with pytest.raises(HTTPException) as exc_info:
        await service.upload_screenshot(user_id=1, file=FakeUploadFile(content), category_ids=[])

    assert exc_info.value.status_code == 415
    assert storage.files == {}
    assert content_service.calls == []


@pytest.mark.asyncio
async def test_upload_screenshot_deletes_file_when_database_write_fails() -> None:
    content_service = FakeContentService()
    content_service.error = RuntimeError("database unavailable")
    service, storage, _ = build_service(content_service=content_service, max_bytes=10_000)

    with pytest.raises(RuntimeError, match="database unavailable"):
        await service.upload_screenshot(
            user_id=1,
            file=FakeUploadFile(make_image("PNG")),
            category_ids=[],
        )

    assert storage.files == {}
    assert len(storage.deleted_keys) == 1


@pytest.mark.asyncio
async def test_upload_screenshot_preserves_database_error_when_cleanup_fails() -> None:
    content_service = FakeContentService()
    content_service.error = RuntimeError("database unavailable")
    storage = FakeStorageClient()
    storage.fail_delete = True
    service, _, _ = build_service(
        storage=storage,
        content_service=content_service,
        max_bytes=10_000,
    )

    with pytest.raises(RuntimeError, match="database unavailable"):
        await service.upload_screenshot(
            user_id=1,
            file=FakeUploadFile(make_image("PNG")),
            category_ids=[],
        )


@pytest.mark.asyncio
async def test_upload_screenshot_does_not_create_content_when_storage_fails() -> None:
    storage = FakeStorageClient()
    storage.fail_save = True
    service, _, content_service = build_service(storage=storage, max_bytes=10_000)

    with pytest.raises(OSError, match="storage unavailable"):
        await service.upload_screenshot(
            user_id=1,
            file=FakeUploadFile(make_image("PNG")),
            category_ids=[],
        )

    assert content_service.calls == []


@pytest.mark.asyncio
async def test_read_asset_returns_owned_file() -> None:
    asset = SimpleNamespace(id=7, storage_key="screenshots/1/image.png", mime_type="image/png")
    repository = FakeContentAssetRepository({(1, 7): asset})
    storage = FakeStorageClient()
    storage.files[asset.storage_key] = b"image"
    service, _, _ = build_service(storage=storage, asset_repository=repository)

    result = await service.read_asset(user_id=1, asset_id=7)

    assert result.content == b"image"
    assert result.mime_type == "image/png"


@pytest.mark.asyncio
async def test_read_asset_hides_missing_or_unowned_asset() -> None:
    asset = SimpleNamespace(id=7, storage_key="screenshots/1/image.png", mime_type="image/png")
    repository = FakeContentAssetRepository({(1, 7): asset})
    service, _, _ = build_service(asset_repository=repository)

    with pytest.raises(NotFoundError) as exc_info:
        await service.read_asset(user_id=2, asset_id=7)

    assert exc_info.value.status_code == 404


@pytest.mark.asyncio
async def test_read_asset_returns_not_found_when_stored_file_is_missing() -> None:
    asset = SimpleNamespace(id=7, storage_key="screenshots/1/missing.png", mime_type="image/png")
    repository = FakeContentAssetRepository({(1, 7): asset})
    service, _, _ = build_service(asset_repository=repository)

    with pytest.raises(NotFoundError) as exc_info:
        await service.read_asset(user_id=1, asset_id=7)

    assert exc_info.value.status_code == 404
