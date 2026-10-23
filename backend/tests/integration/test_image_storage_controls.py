import asyncio
from uuid import uuid4

import pytest
from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.services.image_storage_control import set_uploads_paused
from scripts.image_storage_admin import usage_report
from tests.integration.helpers import guest, request
from tests.integration.test_share_write_concurrency import independent_api  # noqa: F401

pytestmark = pytest.mark.asyncio


async def test_operator_pause_blocks_only_new_images_and_resume_allows_retry(
    api,
    database_connection,
    png_bytes,
    monkeypatch,
):
    owner, _, _ = await guest(api)
    credential = await request(api, "POST", "auth/share-credential", headers=owner)
    native = {
        "Authorization": f"Bearer {credential['share_token']}",
        "Idempotency-Key": str(uuid4()),
    }
    payload = {"files": {"file": ("original.png", png_bytes, "image/png")}}
    saved = await request(api, "POST", "uploads/screenshots", headers=native, status=201, **payload)
    async with AsyncSession(
        bind=database_connection, join_transaction_mode="create_savepoint"
    ) as db:
        await set_uploads_paused(db, True)

    from app.integrations.ocr_client import OCRClient

    external_attempts = []

    async def forbidden_ocr(self, **kwargs):
        external_attempts.append("ocr")
        raise AssertionError("A paused request must not start external processing")

    with monkeypatch.context() as paused:
        paused.setattr(OCRClient, "extract", forbidden_ocr)
        refused = await api.post("/api/v1/uploads/screenshots", headers=owner, **payload)
        assert refused.status_code == 409
        assert external_attempts == []

    # The completed share keeps its original result even while new uploads are paused.
    assert (
        await request(api, "POST", "uploads/screenshots", headers=native, status=201, **payload)
        == saved
    )
    asset_id = saved["assets"][0]["id"]
    assert (await api.get(saved["assets"][0]["download_url"], headers=owner)).content == png_bytes
    await request(api, "GET", f"uploads/assets/{asset_id}/access", headers=owner)
    for headers in [owner, {**native, "Idempotency-Key": str(uuid4())}]:
        refused = await api.post("/api/v1/uploads/screenshots", headers=headers, **payload)
        assert refused.status_code == 409
        assert refused.json()["detail"]["code"] == "image_uploads_paused"
    await request(api, "DELETE", f"contents/{saved['id']}", headers=owner, status=204)
    assert (await request(api, "GET", "feed", headers=owner))["items"] == []

    async with AsyncSession(
        bind=database_connection, join_transaction_mode="create_savepoint"
    ) as db:
        await set_uploads_paused(db, False)
    await request(api, "POST", "uploads/screenshots", headers=owner, status=201, **payload)


async def test_operator_report_separates_logical_physical_backup_and_observed_transfers(
    api,
    database_connection,
    png_bytes,
    tmp_path,
    s3_storage,
):
    from datetime import UTC, datetime

    from app.integrations.storage_client import get_storage_client
    from app.models.image_storage_control import ImageTransferCounter
    from scripts.image_backup import BackupBucket

    await database_connection.execute(delete(ImageTransferCounter))
    owner, _, user = await guest(api)
    other, _, other_user = await guest(api)
    payload = {"files": {"file": ("private-screen.png", png_bytes, "image/png")}}
    saved = await request(api, "POST", "uploads/screenshots", headers=owner, status=201, **payload)
    await request(api, "POST", "uploads/screenshots", headers=other, status=201, **payload)
    await request(api, "GET", f"uploads/assets/{saved['assets'][0]['id']}/access", headers=owner)
    await api.get(saved["assets"][0]["download_url"], headers=owner)
    # Retired files, incomplete points and dump/manifest bytes still incur physical storage.
    (tmp_path / "retired-original.png").write_bytes(b"12345")
    s3_storage.put_object(Bucket="original-images", Key="orphaned-original", Body=b"abc")
    s3_storage.create_bucket(Bucket="backup-images")
    s3_storage.put_object(Bucket="backup-images", Key="originals/deduplicated", Body=b"1234567")
    s3_storage.put_object(
        Bucket="backup-images", Key="points/incomplete/database.dump", Body=b"12345678901"
    )
    async with AsyncSession(bind=database_connection) as db:
        report = await usage_report(
            db,
            get_storage_client(),
            BackupBucket(s3_storage, "backup-images"),
            month=datetime.now(UTC).date().replace(day=1),
        )
    assert report["accounts"] == [
        {"user_id": user["id"], "original_bytes": 77, "original_count": 1},
        {"user_id": other_user["id"], "original_bytes": 77, "original_count": 1},
    ]
    assert report["logical_originals"] == {"size_bytes": 154, "count": 2}
    assert report["physical_storage"] == {
        "local_originals": {"size_bytes": 5, "objects": 1},
        "bucket_originals": {"size_bytes": 157, "objects": 3},
        "backup": {"size_bytes": 18, "objects": 2},
    }
    assert report["observed_transfers"]["original_upload_s3"] == {
        "operations": 2,
        "payload_bytes": 154,
    }
    assert report["observed_transfers"]["proxy_download"] == {"operations": 1, "payload_bytes": 77}
    assert report["observed_transfers"]["direct_access_grant"] == {
        "operations": 1,
        "payload_bytes": 0,
    }
    assert report["provider_transfer_bytes"] is None
    assert report["actual_cost_krw"] is None
    assert report["monthly_design_goal_krw"] == 10_000
    import json

    output = json.dumps(report)
    for private_value in (
        "private-screen",
        "orphaned-original",
        "deduplicated",
        "Authorization",
        "Signature",
        "secret",
    ):
        assert private_value not in output


async def test_pause_waits_for_admitted_save_then_retry_after_resume_has_one_original(
    independent_api,  # noqa: F811 - reused PostgreSQL fixture
    png_bytes,
    monkeypatch,
):
    from app.integrations.ocr_client import OCRClient

    api, owner, _, sessions, _, root = independent_api
    headers = {**owner, "Idempotency-Key": str(uuid4())}
    payload = {"files": {"file": ("original.png", png_bytes, "image/png")}}
    entered, release, pause_started = asyncio.Event(), asyncio.Event(), asyncio.Event()
    original = OCRClient.extract

    async def delayed_ocr(self, **kwargs):
        entered.set()
        await asyncio.wait_for(release.wait(), 10)
        return await original(self, **kwargs)

    async def pause():
        async with sessions() as db:
            pause_started.set()
            await set_uploads_paused(db, True)

    tasks = []
    try:
        monkeypatch.setattr(OCRClient, "extract", delayed_ocr)
        tasks.append(
            asyncio.create_task(
                request(api, "POST", "uploads/screenshots", headers=headers, status=201, **payload)
            )
        )
        await asyncio.wait_for(entered.wait(), 10)
        tasks.append(asyncio.create_task(pause()))
        await asyncio.wait_for(pause_started.wait(), 10)
        await asyncio.sleep(0.05)
        assert not tasks[1].done()
        release.set()
        saved, _ = await asyncio.wait_for(asyncio.gather(*tasks), 10)
        assert (
            await request(
                api, "POST", "uploads/screenshots", headers=headers, status=201, **payload
            )
            == saved
        )
        next_headers = {**owner, "Idempotency-Key": str(uuid4())}
        await request(
            api, "POST", "uploads/screenshots", headers=next_headers, status=409, **payload
        )
        assert len(list(root.rglob("*.png"))) == 1
        async with sessions() as db:
            await set_uploads_paused(db, False)
        first, second = await asyncio.wait_for(
            asyncio.gather(
                *[
                    request(
                        api,
                        "POST",
                        "uploads/screenshots",
                        headers=next_headers,
                        status=201,
                        **payload,
                    )
                    for _ in range(2)
                ]
            ),
            10,
        )
        assert first == second
        assert len(list(root.rglob("*.png"))) == 2
        assert len((await request(api, "GET", "feed", headers=owner))["items"]) == 2
    finally:
        release.set()
        await asyncio.gather(*tasks, return_exceptions=True)
        async with sessions() as db:
            await set_uploads_paused(db, False)
