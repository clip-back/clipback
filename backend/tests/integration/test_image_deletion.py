import asyncio
import os
import sys
from pathlib import Path

import httpx
import pytest
import pytest_asyncio
from sqlalchemy import delete, text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.config import settings
from app.db.session import get_db
from app.integrations.deletion_ledger import get_deletion_ledger
from app.main import create_app
from app.models.category import Category
from app.models.content import Content
from app.models.content_event import ContentEvent
from app.models.image_deletion import ImageDeletion
from app.models.user import User
from tests.integration.helpers import guest, request

pytestmark = pytest.mark.asyncio


async def upload(api, headers, png_bytes):
    return await request(
        api,
        "POST",
        "uploads/screenshots",
        headers=headers,
        status=201,
        files={"file": ("original.png", png_bytes, "image/png")},
    )


async def test_original_delete_is_not_acknowledged_without_independent_ledger(
    api,
    png_bytes,
    monkeypatch,
    tmp_path,
):
    headers, _, _ = await guest(api)
    content = await upload(api, headers, png_bytes)
    monkeypatch.setattr(
        settings, "deletion_ledger_root", tmp_path / "missing-ledger", raising=False
    )
    response = await api.delete(f"/api/v1/contents/{content['id']}", headers=headers)
    assert response.status_code == 503
    downloaded = await api.get(content["assets"][0]["download_url"], headers=headers)
    assert downloaded.status_code == 200 and downloaded.content == png_bytes


async def test_original_cleanup_survives_a_new_worker_after_delete_success(
    api,
    png_bytes,
    monkeypatch,
    tmp_path,
    database_connection,
):
    from app.services.image_deletion_service import retry_image_deletions

    headers, _, _ = await guest(api)
    deleted = await upload(api, headers, png_bytes)
    survivor = await upload(api, headers, png_bytes)
    originals = list(tmp_path.rglob("*.png"))
    original_unlink = Path.unlink

    def fail_cleanup(path, *args, **kwargs):
        if path in originals:
            raise OSError("injected original storage outage")
        return original_unlink(path, *args, **kwargs)

    with monkeypatch.context() as fault:
        fault.setattr(Path, "unlink", fail_cleanup)
        await request(api, "DELETE", f"contents/{deleted['id']}", headers=headers, status=204)
    assert (await api.get(deleted["assets"][0]["download_url"], headers=headers)).status_code == 404
    assert len(list(tmp_path.rglob("*.png"))) == 2
    # A fresh ledger client and a fresh DB session represent a restarted retry worker.
    receipts = get_deletion_ledger().read_verified_events()
    assert len(receipts) == 1 and receipts[0]["content_id"] == deleted["id"]
    async with AsyncSession(
        bind=database_connection,
        expire_on_commit=False,
        join_transaction_mode="create_savepoint",
    ) as restarted_session:
        result = await retry_image_deletions(restarted_session)
    assert result["pending"] == 0
    assert len(list(tmp_path.rglob("*.png"))) == 1
    assert (
        await api.get(survivor["assets"][0]["download_url"], headers=headers)
    ).content == png_bytes
    await request(api, "DELETE", f"contents/{deleted['id']}", headers=headers, status=404)


@pytest_asyncio.fixture
async def committed_api(external_responses, monkeypatch, tmp_path):
    database_url = os.environ.get("TEST_DATABASE_URL")
    if not database_url:
        pytest.skip("TEST_DATABASE_URL is required for PostgreSQL tests")
    engine = create_async_engine(database_url)
    sessions = async_sessionmaker(engine, expire_on_commit=False)
    app = create_app()
    monkeypatch.setattr(settings, "storage_root", tmp_path)

    async def db():
        async with sessions() as session:
            yield session

    app.dependency_overrides[get_db] = db
    user_id = None
    try:
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app, raise_app_exceptions=False),
            base_url="http://test",
        ) as client:
            headers, _, user = await guest(client)
            user_id = user["id"]
            yield client, headers, sessions
    finally:
        if user_id is not None:
            async with sessions() as session:
                for model in (ImageDeletion, ContentEvent, Content, Category):
                    await session.execute(delete(model).where(model.user_id == user_id))
                await session.execute(delete(User).where(User.id == user_id))
                await session.commit()
        await engine.dispose()


async def test_retry_command_in_new_process_cleans_only_acknowledged_deleted_original(
    committed_api,
    png_bytes,
    tmp_path,
    monkeypatch,
):
    client, headers, _ = committed_api
    content = await upload(client, headers, png_bytes)
    survivor = await upload(client, headers, png_bytes)
    originals = list(tmp_path.rglob("*.png"))
    original_unlink = Path.unlink

    def fail_cleanup(path, *args, **kwargs):
        if path in originals:
            raise OSError("injected original storage outage")
        return original_unlink(path, *args, **kwargs)

    with monkeypatch.context() as fault:
        fault.setattr(Path, "unlink", fail_cleanup)
        await request(client, "DELETE", f"contents/{content['id']}", headers=headers, status=204)
    process = await asyncio.create_subprocess_exec(
        sys.executable,
        "scripts/image_deletions.py",
        "retry",
        "--limit",
        "100",
        env={
            **os.environ,
            "DATABASE_URL": os.environ["TEST_DATABASE_URL"],
            "STORAGE_ROOT": str(tmp_path),
            "DELETION_LEDGER_ROOT": str(settings.deletion_ledger_root),
            "YOUTUBE_SUMMARY_ENABLED": "false",
        },
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    output, error = await asyncio.wait_for(process.communicate(), timeout=30)
    assert process.returncode == 0, error.decode()
    assert b'"pending": 0' in output
    assert len(list(tmp_path.rglob("*.png"))) == 1
    assert (
        await client.get(content["assets"][0]["download_url"], headers=headers)
    ).status_code == 404
    assert (
        await client.get(survivor["assets"][0]["download_url"], headers=headers)
    ).content == png_bytes


@pytest.mark.parametrize("ack_lost", [False, True])
async def test_database_commit_uncertainty_reconciles_from_independent_deletion_intent(
    committed_api,
    png_bytes,
    monkeypatch,
    tmp_path,
    ack_lost,
):
    from app.services.image_deletion_service import retry_image_deletions

    client, headers, sessions = committed_api
    content = await upload(client, headers, png_bytes)
    survivor = await upload(client, headers, png_bytes)
    original_commit = AsyncSession.commit
    failed = False

    async def uncertain_commit(session):
        nonlocal failed
        if not failed:
            failed = True
            if ack_lost:
                await original_commit(session)
            raise ConnectionError("injected database commit uncertainty")
        await original_commit(session)

    with monkeypatch.context() as fault:
        fault.setattr(AsyncSession, "commit", uncertain_commit)
        response = await client.delete(f"/api/v1/contents/{content['id']}", headers=headers)
    assert response.status_code == 500
    assert get_deletion_ledger().read_verified_checkpoint()["sequence"] == 1
    url = content["assets"][0]["download_url"]
    assert (await client.get(url, headers=headers)).status_code == (404 if ack_lost else 200)
    async with sessions() as restarted:
        result = await retry_image_deletions(restarted)
    assert result["pending"] == 0
    assert (await client.get(url, headers=headers)).status_code == 404
    assert len(list(tmp_path.rglob("*.png"))) == 1
    assert (
        await client.get(survivor["assets"][0]["download_url"], headers=headers)
    ).content == png_bytes


async def test_backup_snapshot_lock_defers_physical_cleanup_without_delaying_delete_acknowledgement(
    committed_api,
    png_bytes,
    tmp_path,
):
    from app.integrations.deletion_ledger import IMAGE_CLEANUP_LOCK
    from app.services.image_deletion_service import retry_image_deletions

    client, headers, sessions = committed_api
    content = await upload(client, headers, png_bytes)
    async with sessions() as backup:
        await backup.execute(
            text("SELECT pg_advisory_lock_shared(:key)"),
            {"key": IMAGE_CLEANUP_LOCK},
        )
        try:
            response = await asyncio.wait_for(
                client.delete(f"/api/v1/contents/{content['id']}", headers=headers),
                timeout=2,
            )
            assert response.status_code == 204
            assert len(list(tmp_path.rglob("*.png"))) == 1
            assert (
                await client.get(content["assets"][0]["download_url"], headers=headers)
            ).status_code == 404
        finally:
            await backup.execute(
                text("SELECT pg_advisory_unlock_shared(:key)"),
                {"key": IMAGE_CLEANUP_LOCK},
            )
    async with sessions() as restarted:
        assert (await retry_image_deletions(restarted))["pending"] == 0
    assert not list(tmp_path.rglob("*.png"))


@pytest.mark.parametrize(
    "missing", ["head.json", "namespace.json", "event-00000000000000000001.json"]
)
async def test_missing_ledger_record_never_becomes_an_empty_deletion_history(
    api,
    png_bytes,
    missing,
):
    headers, _, _ = await guest(api)
    first = await upload(api, headers, png_bytes)
    survivor = await upload(api, headers, png_bytes)
    await request(api, "DELETE", f"contents/{first['id']}", headers=headers, status=204)
    (settings.deletion_ledger_root / missing).unlink()
    await request(api, "DELETE", f"contents/{survivor['id']}", headers=headers, status=503)
    assert (
        await api.get(survivor["assets"][0]["download_url"], headers=headers)
    ).content == png_bytes


@pytest.mark.parametrize("ack_lost", [False, True])
async def test_bucket_ledger_write_uncertainty_is_verified_before_delete_acknowledgement(
    api,
    png_bytes,
    s3_storage,
    monkeypatch,
    ack_lost,
):
    from botocore.client import BaseClient
    from botocore.exceptions import EndpointConnectionError
    from pydantic import SecretStr

    s3_storage.create_bucket(Bucket="independent-deletions")
    for name, value in {
        "deletion_ledger_backend": "s3",
        "deletion_ledger_s3_bucket": "independent-deletions",
        "deletion_ledger_s3_region": "us-east-1",
        "deletion_ledger_s3_endpoint_url": "https://s3.amazonaws.com",
        "deletion_ledger_s3_access_key_id": SecretStr("testing"),
        "deletion_ledger_s3_secret_access_key": SecretStr("testing"),
    }.items():
        monkeypatch.setattr(settings, name, value)
    get_deletion_ledger().initialize()
    headers, _, _ = await guest(api)
    content = await upload(api, headers, png_bytes)
    original_call = BaseClient._make_api_call

    def uncertain_put(client, operation_name, parameters):
        if (
            operation_name == "PutObject"
            and parameters.get("Bucket") == "independent-deletions"
            and parameters.get("Key") == "head.json"
        ):
            if ack_lost:
                original_call(client, operation_name, parameters)
            raise EndpointConnectionError(endpoint_url="https://synthetic.invalid")
        return original_call(client, operation_name, parameters)

    with monkeypatch.context() as fault:
        fault.setattr(BaseClient, "_make_api_call", uncertain_put)
        await request(
            api,
            "DELETE",
            f"contents/{content['id']}",
            headers=headers,
            status=204 if ack_lost else 503,
        )
    checkpoint = get_deletion_ledger().read_verified_checkpoint()
    assert checkpoint["sequence"] == (1 if ack_lost else 0)
    assert (await api.get(content["assets"][0]["download_url"], headers=headers)).status_code == (
        404 if ack_lost else 200
    )
    if not ack_lost:
        await request(api, "DELETE", f"contents/{content['id']}", headers=headers, status=204)
    assert get_deletion_ledger().read_verified_checkpoint()["sequence"] == 1


async def test_failed_upload_original_cleanup_is_retried_after_storage_recovers(
    committed_api,
    png_bytes,
    monkeypatch,
    tmp_path,
):
    from app.services.image_deletion_service import retry_image_deletions

    client, headers, sessions = committed_api
    original_commit = AsyncSession.commit
    original_unlink = Path.unlink
    failed = False

    async def reject_once(session):
        nonlocal failed
        if not failed:
            failed = True
            raise ConnectionError("injected rejected content transaction")
        await original_commit(session)

    def unavailable_original(path, *args, **kwargs):
        if path.suffix == ".png" and path.is_relative_to(tmp_path):
            raise OSError("injected original storage outage")
        return original_unlink(path, *args, **kwargs)

    with monkeypatch.context() as fault:
        fault.setattr(AsyncSession, "commit", reject_once)
        fault.setattr(Path, "unlink", unavailable_original)
        response = await client.post(
            "/api/v1/uploads/screenshots",
            headers=headers,
            files={"file": ("original.png", png_bytes, "image/png")},
        )
    assert response.status_code == 500
    assert len(list(tmp_path.rglob("*.png"))) == 1
    assert (await request(client, "GET", "feed", headers=headers))["items"] == []
    async with sessions() as restarted:
        assert (await retry_image_deletions(restarted))["pending"] == 0
    assert not list(tmp_path.rglob("*.png"))
    assert get_deletion_ledger().read_verified_checkpoint()["sequence"] == 0


async def test_upload_without_idempotency_key_never_cleans_a_committed_original_after_lost_ack(
    committed_api,
    png_bytes,
    monkeypatch,
):
    client, headers, _ = committed_api
    original_commit = AsyncSession.commit
    failed = False

    async def committed_ack_lost(session):
        nonlocal failed
        await original_commit(session)
        if not failed:
            failed = True
            raise ConnectionError("injected committed upload acknowledgement loss")

    with monkeypatch.context() as fault:
        fault.setattr(AsyncSession, "commit", committed_ack_lost)
        response = await client.post(
            "/api/v1/uploads/screenshots",
            headers=headers,
            files={"file": ("original.png", png_bytes, "image/png")},
        )
    assert response.status_code == 500
    content = (await request(client, "GET", "feed", headers=headers))["items"][0]
    detail = await request(client, "GET", f"contents/{content['id']}", headers=headers)
    downloaded = await client.get(detail["assets"][0]["download_url"], headers=headers)
    assert downloaded.status_code == 200 and downloaded.content == png_bytes


async def test_uncertain_bucket_upload_is_journaled_and_cleaned_without_a_content_reference(
    api,
    png_bytes,
    s3_storage,
    monkeypatch,
    database_connection,
):
    from botocore.client import BaseClient
    from botocore.exceptions import EndpointConnectionError

    from app.services.image_deletion_service import retry_image_deletions

    headers, _, _ = await guest(api)
    original_call = BaseClient._make_api_call

    def uncertain_upload(client, operation_name, parameters):
        if parameters.get("Bucket") == "original-images":
            if operation_name == "PutObject":
                original_call(client, operation_name, parameters)
                raise EndpointConnectionError(endpoint_url="https://synthetic.invalid")
            if operation_name == "DeleteObject":
                raise EndpointConnectionError(endpoint_url="https://synthetic.invalid")
        return original_call(client, operation_name, parameters)

    with monkeypatch.context() as fault:
        fault.setattr(BaseClient, "_make_api_call", uncertain_upload)
        response = await api.post(
            "/api/v1/uploads/screenshots",
            headers=headers,
            files={"file": ("original.png", png_bytes, "image/png")},
        )
    assert response.status_code == 503
    assert len(s3_storage.list_objects_v2(Bucket="original-images")["Contents"]) == 1
    assert (await request(api, "GET", "feed", headers=headers))["items"] == []
    async with AsyncSession(
        bind=database_connection,
        expire_on_commit=False,
        join_transaction_mode="create_savepoint",
    ) as restarted:
        assert (await retry_image_deletions(restarted))["pending"] == 0
    assert not s3_storage.list_objects_v2(Bucket="original-images").get("Contents")


async def test_reconciliation_does_not_delete_reused_content_id_with_another_original(
    api,
    png_bytes,
    database_connection,
):
    from datetime import UTC, datetime
    from uuid import uuid4

    from app.services.image_deletion_service import retry_image_deletions

    headers, _, user = await guest(api)
    survivor = await upload(api, headers, png_bytes)
    # Fixture for a receipt from before DB restoration and numeric-ID reuse.
    get_deletion_ledger().append(
        {
            "operation_id": str(uuid4()),
            "user_id": user["id"],
            "content_id": survivor["id"],
            "saved_at": "2026-01-01T00:00:00+00:00",
            "deleted_at": datetime.now(UTC).isoformat(),
            "assets": [
                {
                    "storage_backend": "local",
                    "storage_key": "screenshots/old/removed.png",
                    "sha256": None,
                    "size_bytes": None,
                }
            ],
        }
    )
    async with AsyncSession(
        bind=database_connection,
        expire_on_commit=False,
        join_transaction_mode="create_savepoint",
    ) as restarted:
        assert (await retry_image_deletions(restarted))["pending"] == 0
    downloaded = await api.get(survivor["assets"][0]["download_url"], headers=headers)
    assert downloaded.status_code == 200 and downloaded.content == png_bytes


async def test_new_deletion_uses_bounded_ledger_reads_as_historical_deletions_grow(
    api,
    png_bytes,
    s3_storage,
    monkeypatch,
):
    from botocore.client import BaseClient
    from pydantic import SecretStr

    s3_storage.create_bucket(Bucket="independent-deletions")
    for name, value in {
        "deletion_ledger_backend": "s3",
        "deletion_ledger_s3_bucket": "independent-deletions",
        "deletion_ledger_s3_region": "us-east-1",
        "deletion_ledger_s3_endpoint_url": "https://s3.amazonaws.com",
        "deletion_ledger_s3_access_key_id": SecretStr("testing"),
        "deletion_ledger_s3_secret_access_key": SecretStr("testing"),
    }.items():
        monkeypatch.setattr(settings, name, value)
    get_deletion_ledger().initialize()
    headers, _, _ = await guest(api)
    original_call = BaseClient._make_api_call
    reads = []

    def count_external_reads(client, operation_name, parameters):
        if operation_name == "GetObject" and parameters.get("Bucket") == "independent-deletions":
            reads[-1] += 1
        return original_call(client, operation_name, parameters)

    with monkeypatch.context() as count:
        count.setattr(BaseClient, "_make_api_call", count_external_reads)
        for _ in range(12):
            content = await upload(api, headers, png_bytes)
            reads.append(0)
            await request(api, "DELETE", f"contents/{content['id']}", headers=headers, status=204)
    # Count the external storage boundary, not internal class calls. Historical volume must
    # not make a foreground deletion walk all prior receipts.
    assert max(reads) <= 20
    assert reads[-1] <= reads[0] + 4
