from datetime import UTC, datetime, timedelta
from urllib.parse import parse_qs, urlparse

import pytest

from tests.integration.helpers import guest, request

pytestmark = pytest.mark.asyncio


async def _upload(api, owner, png_bytes):
    return await request(
        api, "POST", "uploads/screenshots", headers=owner, status=201,
        files={"file": ("original.png", png_bytes, "image/png")},
    )


async def test_owner_gets_private_verified_local_original_access(api, png_bytes):
    owner, _, _ = await guest(api)
    content = await _upload(api, owner, png_bytes)
    asset = content["assets"][0]
    response = await api.get(f"{asset['download_url']}/access", headers=owner)
    assert response.status_code == 200
    assert response.headers["cache-control"] == "private, no-store"
    assert response.json() == {
        "asset_id": asset["id"], "mode": "proxy", "url": asset["download_url"],
        "expires_at": None, "mime_type": "image/png", "size_bytes": 77,
        "sha256": "36fe6ab71ec56fa1fc84326e4673fbf028c6ad2eb5051ce5a9e6cb0d07c85f4c",
    }
    original = await api.get(response.json()["url"], headers=owner)
    assert original.status_code == 200 and original.content == png_bytes


async def test_owner_gets_short_lived_bucket_access_and_old_app_still_reads(
    api, png_bytes, s3_storage,
):
    owner, _, _ = await guest(api)
    content = await _upload(api, owner, png_bytes)
    asset = content["assets"][0]
    before = datetime.now(UTC)
    response = await api.get(f"{asset['download_url']}/access", headers=owner)
    assert response.status_code == 200
    access = response.json()
    assert access["mode"] == "direct"
    assert access["mime_type"] == "image/png" and access["size_bytes"] == 77
    assert access["sha256"] == "36fe6ab71ec56fa1fc84326e4673fbf028c6ad2eb5051ce5a9e6cb0d07c85f4c"
    assert before + timedelta(seconds=119) <= datetime.fromisoformat(
        access["expires_at"].replace("Z", "+00:00")
    ) <= datetime.now(UTC) + timedelta(seconds=120)
    url = urlparse(access["url"])
    query = parse_qs(url.query)
    assert url.scheme == "https"
    assert query["X-Amz-Expires"] == ["120"]
    assert query["response-content-type"] == ["image/png"]
    assert "X-Amz-Signature" in query
    original = await api.get(asset["download_url"], headers=owner)
    assert original.status_code == 200 and original.content == png_bytes


@pytest.mark.parametrize("backend", ["local", "s3"])
async def test_access_needs_current_owner_and_live_original(
    api, png_bytes, tmp_path, s3_storage, monkeypatch, backend,
):
    from app.core.config import settings

    monkeypatch.setattr(settings, "storage_backend", backend)
    owner, _, _ = await guest(api)
    outsider, _, _ = await guest(api)
    content = await _upload(api, owner, png_bytes)
    access_url = content["assets"][0]["download_url"] + "/access"
    assert (await api.get(access_url)).status_code == 401
    assert (await api.get(access_url, headers=outsider)).status_code == 404
    assert (await api.get(access_url, headers=owner)).status_code == 200
    await request(api, "DELETE", f"contents/{content['id']}", headers=owner, status=204)
    assert (await api.get(access_url, headers=owner)).status_code == 404
    content = await _upload(api, owner, png_bytes)
    access_url = content["assets"][0]["download_url"] + "/access"
    if backend == "s3":
        key = s3_storage.list_objects_v2(Bucket="original-images")["Contents"][0]["Key"]
        s3_storage.delete_object(Bucket="original-images", Key=key)
    else:
        next(p for p in tmp_path.rglob("*") if p.is_file()).unlink()
    assert (await api.get(access_url, headers=owner)).status_code == 404
    if backend == "s3":
        s3_storage.delete_bucket(Bucket="original-images")
        failed = await api.get(access_url, headers=owner)
        assert failed.status_code == 503
        assert failed.json() == {"detail": "Image storage is temporarily unavailable"}


async def test_legacy_original_access_derives_unknown_integrity_from_real_bytes(
    api, png_bytes, database_connection,
):
    from sqlalchemy import update

    from app.models.content_asset import ContentAsset

    owner, _, _ = await guest(api)
    content = await _upload(api, owner, png_bytes)
    asset = content["assets"][0]
    await database_connection.execute(
        update(ContentAsset).where(ContentAsset.id == asset["id"]).values(
            size_bytes=None, sha256=None,
        )
    )
    access = await request(api, "GET", f"uploads/assets/{asset['id']}/access", headers=owner)
    assert access["size_bytes"] == 77
    assert access["sha256"] == "36fe6ab71ec56fa1fc84326e4673fbf028c6ad2eb5051ce5a9e6cb0d07c85f4c"
