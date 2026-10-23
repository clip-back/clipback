import asyncio
from uuid import uuid4

import pytest
from sqlalchemy import update

from app.models.content_asset import ContentAsset
from tests.integration.helpers import guest, request
from tests.integration.test_share_write_concurrency import independent_api  # noqa: F401

pytestmark = pytest.mark.asyncio


async def upload(api, headers, image, status=201):
    return await request(
        api, "POST", "uploads/screenshots", headers=headers, status=status,
        files={"file": ("original.png", image, "image/png")},
    )


async def test_guest_exact_30mib_aggregates_main_and_native_shares_and_replays(
    api, png_bytes,
):
    headers, _, _ = await guest(api)
    image = png_bytes + bytes(10 * 1024 * 1024 - len(png_bytes))
    first = await upload(api, headers, image)
    credential = await request(api, "POST", "auth/share-credential", headers=headers)
    native = {"Authorization": f"Bearer {credential['share_token']}",
              "Idempotency-Key": str(uuid4())}
    second = await upload(api, native, image)
    third = await upload(api, headers, image)
    assert await upload(api, native, image) == second
    rejected = await upload(api, headers, png_bytes, status=409)
    assert rejected["detail"]["code"] == "image_quota_exceeded"
    assert rejected["detail"]["limit_bytes"] == 31_457_280
    assert (await api.get(first["assets"][0]["download_url"], headers=headers)).content == image
    await request(api, "DELETE", f"contents/{third['id']}", headers=headers, status=204)
    await upload(api, headers, image)


async def test_unknown_legacy_sizes_use_original_bytes_instead_of_zero(
    api, database_connection, png_bytes, tmp_path,
):
    headers, _, _ = await guest(api)
    existing = await upload(api, headers, png_bytes)
    original = next(tmp_path.rglob("*.png"))
    # A pre-migration original has no size metadata and can exceed today's
    # per-file limit. Seed that historical state without changing the public API.
    original.write_bytes(png_bytes + bytes(31_457_280 - len(png_bytes) * 2))
    await database_connection.execute(update(ContentAsset).where(
        ContentAsset.id == existing["assets"][0]["id"],
    ).values(size_bytes=None))
    await upload(api, headers, png_bytes)
    rejected = await upload(api, headers, png_bytes, status=409)
    assert rejected["detail"]["code"] == "image_quota_exceeded"


async def test_unverifiable_legacy_size_blocks_new_save_and_keeps_existing_metadata(
    api, database_connection, png_bytes, tmp_path,
):
    headers, _, _ = await guest(api)
    existing = await upload(api, headers, png_bytes)
    next(tmp_path.rglob("*.png")).unlink()
    await database_connection.execute(update(ContentAsset).where(
        ContentAsset.id == existing["assets"][0]["id"],
    ).values(size_bytes=None))
    rejected = await upload(api, headers, png_bytes, status=503)
    assert rejected == {"detail": "Original image usage could not be verified"}
    detail = await request(api, "GET", f"contents/{existing['id']}", headers=headers)
    assert detail["id"] == existing["id"]


async def test_guest_promotion_keeps_images_and_applies_300mib_exact_boundary(
    api, database_connection, png_bytes,
):
    headers, _, user = await guest(api)
    existing = await upload(api, headers, png_bytes)
    await database_connection.execute(update(ContentAsset).where(
        ContentAsset.id == existing["assets"][0]["id"],
    ).values(size_bytes=314_572_800 - len(png_bytes)))
    rejected_guest = await upload(api, headers, png_bytes, status=409)
    assert rejected_guest["detail"]["limit_bytes"] == 31_457_280
    promoted = await request(api, "POST", "auth/social/kakao/upgrade", headers=headers,
                             json={"token": f"quota-upgrade-{uuid4()}"})
    signed_in = {"Authorization": f"Bearer {promoted['access_token']}"}
    assert (await request(api, "GET", "users/me", headers=signed_in))["id"] == user["id"]
    await upload(api, signed_in, png_bytes)
    rejected = await upload(api, signed_in, png_bytes, status=409)
    assert rejected["detail"]["limit_bytes"] == 314_572_800
    detail = await request(api, "GET", f"contents/{existing['id']}", headers=signed_in)
    assert detail["id"] == existing["id"]


async def test_over_quota_rejects_before_ocr_without_affecting_other_users(
    api, database_connection, png_bytes, monkeypatch,
):
    from app.integrations.ocr_client import OCRClient, ScreenshotOCRResult

    headers, _, _ = await guest(api)
    existing = await upload(api, headers, png_bytes)
    await database_connection.execute(update(ContentAsset).where(
        ContentAsset.id == existing["assets"][0]["id"],
    ).values(size_bytes=31_457_281))
    observed = []

    async def ocr(self, **kwargs):
        observed.append(kwargs["image_bytes"])
        return ScreenshotOCRResult(text="", title="", summary="")

    monkeypatch.setattr(OCRClient, "extract", ocr)
    await upload(api, headers, png_bytes, status=409)
    assert observed == []
    other, _, _ = await guest(api)
    await upload(api, other, png_bytes)
    assert observed == [png_bytes]


async def test_main_and_native_concurrent_writes_cannot_overrun_remaining_space(
    independent_api, png_bytes, monkeypatch,  # noqa: F811
):
    from app.integrations.ocr_client import OCRClient

    api, headers, _, sessions, _, _ = independent_api
    existing = await upload(api, headers, png_bytes)
    async with sessions() as session:
        await session.execute(update(ContentAsset).where(
            ContentAsset.id == existing["assets"][0]["id"],
        ).values(size_bytes=31_457_280 - len(png_bytes)))
        await session.commit()
    credential = await request(api, "POST", "auth/share-credential", headers=headers)
    native = {"Authorization": f"Bearer {credential['share_token']}",
              "Idempotency-Key": str(uuid4())}
    entered, release = asyncio.Event(), asyncio.Event()
    original = OCRClient.extract
    observed = []

    async def ocr(self, **kwargs):
        observed.append(kwargs["image_bytes"])
        entered.set()
        await asyncio.wait_for(release.wait(), 10)
        return await original(self, **kwargs)

    monkeypatch.setattr(OCRClient, "extract", ocr)
    first = asyncio.create_task(upload(api, headers, png_bytes))
    try:
        await asyncio.wait_for(entered.wait(), 10)
        second = asyncio.create_task(upload(api, native, png_bytes, status=409))
        release.set()
        await asyncio.wait_for(asyncio.gather(first, second), 10)
        assert observed == [png_bytes]
        assert len((await request(api, "GET", "feed", headers=headers))["items"]) == 2
    finally:
        release.set()
        await asyncio.gather(first, return_exceptions=True)


async def test_failed_storage_write_does_not_consume_last_available_space(
    api, database_connection, png_bytes, monkeypatch,
):
    from app.integrations.storage_client import LocalStorageClient, StorageUnavailableError

    headers, _, _ = await guest(api)
    existing = await upload(api, headers, png_bytes)
    await database_connection.execute(update(ContentAsset).where(
        ContentAsset.id == existing["assets"][0]["id"],
    ).values(size_bytes=31_457_280 - len(png_bytes)))
    original = LocalStorageClient.save_file

    async def unavailable(self, key, data):
        raise StorageUnavailableError("Injected storage outage")

    monkeypatch.setattr(LocalStorageClient, "save_file", unavailable)
    await upload(api, headers, png_bytes, status=503)
    monkeypatch.setattr(LocalStorageClient, "save_file", original)
    await upload(api, headers, png_bytes)
    await upload(api, headers, png_bytes, status=409)


async def test_one_file_limit_is_distinct_from_account_quota(api, png_bytes):
    headers, _, _ = await guest(api)
    too_large = png_bytes + bytes(10 * 1024 * 1024 + 1 - len(png_bytes))
    rejected = await upload(api, headers, too_large, status=413)
    assert rejected["detail"] == {
        "code": "image_file_too_large", "limit_bytes": 10_485_760,
    }
