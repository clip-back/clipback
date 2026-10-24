import asyncio
import hashlib
import json
import threading

import pytest
from sqlalchemy import text, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.integrations.storage_client import StorageRouter
from app.models.content_asset import ContentAsset
from app.models.image_deletion import ImageDeletion
from tests.integration.helpers import guest
from tests.integration.test_image_deletion import committed_api as committed_api
from tests.integration.test_image_quota import upload

pytestmark = pytest.mark.asyncio


async def test_preflight_reports_original_problems_without_changing_legacy_metadata(
    api,
    database_connection,
    png_bytes,
    tmp_path,
):
    from scripts.image_migration import inspect_originals

    headers, _, _ = await guest(api)
    legacy = await upload(api, headers, png_bytes)
    broken = await upload(api, headers, png_bytes)
    await database_connection.execute(
        update(ContentAsset)
        .where(
            ContentAsset.id == legacy["assets"][0]["id"],
        )
        .values(size_bytes=None, sha256=None)
    )
    files = sorted(tmp_path.rglob("*.png"))
    # Locate the second original through its existing public bytes URL.
    async with AsyncSession(bind=database_connection) as session:
        asset = await session.get(ContentAsset, broken["assets"][0]["id"])
        (tmp_path / asset.storage_key).write_bytes(b"corrupted")
    async with AsyncSession(bind=database_connection) as session:
        result = await inspect_originals(session, StorageRouter(settings))
    assert result["passed"] is False
    assert result["results"] == [
        {"asset_id": legacy["assets"][0]["id"], "backend": "local", "status": "ready"},
        {
            "asset_id": broken["assets"][0]["id"],
            "backend": "local",
            "status": "original_metadata_mismatch",
        },
    ]
    async with AsyncSession(bind=database_connection) as session:
        asset = await session.get(ContentAsset, legacy["assets"][0]["id"])
        assert asset.size_bytes is None and asset.sha256 is None
    assert len(files) == len(list(tmp_path.rglob("*.png"))) == 2
    assert hashlib.sha256(png_bytes).hexdigest() not in str(result)
    assert (
        await api.get(legacy["assets"][0]["download_url"], headers=headers)
    ).content == png_bytes


async def prepared_backup(client, headers, contents, s3, directory):
    """A real paired dump+object set; the report is a trusted operator boundary fixture."""
    from app.db.session import engine
    from app.integrations.deletion_ledger import get_deletion_ledger
    from scripts.image_backup import BackupBucket, create_backup, materialize_backup

    s3.create_bucket(Bucket="migration-backups")
    store = BackupBucket(s3, "migration-backups")
    first = contents[0]
    await create_backup(
        store,
        backup_id="before-migration",
        sample={
            "content_id": first["id"],
            "asset_id": first["assets"][0]["id"],
        },
        app_commit="a" * 40,
        origin="synthetic",
        writers_frozen=True,
        pg_dump="/opt/homebrew/opt/postgresql@17/bin/pg_dump",
        deletion_checkpoint=get_deletion_ledger().read_verified_checkpoint(),
    )
    await engine.dispose()
    materialize_backup(store, "before-migration", directory)
    report = {
        "backup_id": "before-migration",
        "origin": "synthetic",
        "passed": True,
        "cleanup_passed": True,
        "authentication_passed": True,
        "image_bytes_passed": True,
        "live_deletion_ledger_verified": True,
        "deletions_applied": True,
        "manifest_sha256": hashlib.sha256((directory / "manifest.json").read_bytes()).hexdigest(),
    }
    path = directory / "restore-report.json"
    path.write_text(json.dumps(report))
    return path


async def test_verified_migration_can_stop_resume_and_keep_old_api_bytes_and_local_copies(
    committed_api,
    s3_storage,
    png_bytes,
    monkeypatch,
    tmp_path,
):
    from scripts.image_migration import migrate_originals

    client, headers, sessions = committed_api
    monkeypatch.setattr(settings, "storage_backend", "local")
    originals = [await upload(client, headers, png_bytes) for _ in range(2)]
    directory = tmp_path / "verified-backup"
    report = await prepared_backup(client, headers, originals, s3_storage, directory)
    storage = StorageRouter(settings)
    first = await migrate_originals(
        sessions.kw["bind"],
        storage,
        backup_directory=directory,
        restore_report_file=report,
        limit=1,
    )
    assert first["migrated"] == 1 and first["passed"] is True
    assert len(s3_storage.list_objects_v2(Bucket="original-images")["Contents"]) == 1
    # Reads use each row's location, so a mixed intermediate state is usable.
    for content in originals:
        assert (
            await client.get(content["assets"][0]["download_url"], headers=headers)
        ).content == png_bytes
    resumed = await migrate_originals(
        sessions.kw["bind"],
        StorageRouter(settings),
        backup_directory=directory,
        restore_report_file=report,
    )
    assert resumed["migrated"] == 1 and resumed["passed"] is True
    again = await migrate_originals(
        sessions.kw["bind"],
        StorageRouter(settings),
        backup_directory=directory,
        restore_report_file=report,
    )
    assert again["migrated"] == 0 and again["passed"] is True
    assert len(list(tmp_path.glob("screenshots/**/*.png"))) == 2
    for content in originals:
        assert (
            await client.get(content["assets"][0]["download_url"], headers=headers)
        ).content == png_bytes
    response = await client.delete(f"/api/v1/contents/{originals[0]['id']}", headers=headers)
    assert response.status_code == 204
    assert len(list(tmp_path.glob("screenshots/**/*.png"))) == 1
    assert len(s3_storage.list_objects_v2(Bucket="original-images")["Contents"]) == 1


async def test_unverified_or_replaced_backup_report_never_starts_copy(
    committed_api,
    s3_storage,
    png_bytes,
    monkeypatch,
    tmp_path,
):
    from scripts.check_backup_restore import CheckError
    from scripts.image_migration import migrate_originals

    client, headers, sessions = committed_api
    monkeypatch.setattr(settings, "storage_backend", "local")
    content = await upload(client, headers, png_bytes)
    directory = tmp_path / "verified-backup"
    report = await prepared_backup(client, headers, [content], s3_storage, directory)
    original = json.loads(report.read_text())
    for changed in ({"live_deletion_ledger_verified": False}, {"manifest_sha256": "0" * 64}):
        report.write_text(json.dumps({**original, **changed}))
        with pytest.raises(CheckError, match="verified_restore_report_required"):
            await migrate_originals(
                sessions.kw["bind"],
                StorageRouter(settings),
                backup_directory=directory,
                restore_report_file=report,
            )
        assert not s3_storage.list_objects_v2(Bucket="original-images").get("Contents")
        assert (
            await client.get(content["assets"][0]["download_url"], headers=headers)
        ).content == png_bytes


@pytest.mark.parametrize("legacy", [False, True])
async def test_interrupted_copy_is_durably_cleaned_without_removing_local_source_then_resumes(
    committed_api,
    s3_storage,
    png_bytes,
    monkeypatch,
    tmp_path,
    legacy,
):
    from botocore.client import BaseClient

    from app.services.image_deletion_service import retry_image_deletions
    from scripts.image_migration import migrate_originals

    client, headers, sessions = committed_api
    monkeypatch.setattr(settings, "storage_backend", "local")
    content = await upload(client, headers, png_bytes)
    if legacy:
        async with sessions() as session:
            await session.execute(
                update(ContentAsset)
                .where(
                    ContentAsset.id == content["assets"][0]["id"],
                )
                .values(size_bytes=None, sha256=None)
            )
            await session.commit()
    directory = tmp_path / "verified-backup"
    report = await prepared_backup(client, headers, [content], s3_storage, directory)
    original_call = BaseClient._make_api_call

    def interrupted(client, operation_name, parameters):
        result = original_call(client, operation_name, parameters)
        if operation_name == "PutObject" and parameters.get("Bucket") == "original-images":
            raise asyncio.CancelledError()
        return result

    with monkeypatch.context() as fault:
        fault.setattr(BaseClient, "_make_api_call", interrupted)
        with pytest.raises(asyncio.CancelledError):
            await migrate_originals(
                sessions.kw["bind"],
                StorageRouter(settings),
                backup_directory=directory,
                restore_report_file=report,
            )
    assert len(s3_storage.list_objects_v2(Bucket="original-images")["Contents"]) == 1
    async with sessions() as restarted_worker:
        assert (await retry_image_deletions(restarted_worker))["pending"] == 0
    assert not s3_storage.list_objects_v2(Bucket="original-images").get("Contents")
    assert len(list(tmp_path.glob("screenshots/**/*.png"))) == 1
    assert (
        await client.get(content["assets"][0]["download_url"], headers=headers)
    ).content == png_bytes
    if legacy:
        # A normal successful upload fills the old row's unknown size while a
        # migration worker was interrupted; this remains the same original.
        await upload(client, headers, png_bytes)
        access = await client.get(
            f"/api/v1/uploads/assets/{content['assets'][0]['id']}/access",
            headers=headers,
        )
        assert access.json()["size_bytes"] == len(png_bytes)
    resumed = await migrate_originals(
        sessions.kw["bind"],
        StorageRouter(settings),
        backup_directory=directory,
        restore_report_file=report,
        limit=1,
    )
    assert resumed["migrated"] == 1 and resumed["passed"]


async def test_delete_during_copy_never_reconnects_content_and_both_locations_are_cleaned(
    committed_api,
    s3_storage,
    png_bytes,
    monkeypatch,
    tmp_path,
):
    from botocore.client import BaseClient

    from app.services.image_deletion_service import retry_image_deletions
    from scripts.image_migration import migrate_originals

    client, headers, sessions = committed_api
    monkeypatch.setattr(settings, "storage_backend", "local")
    content = await upload(client, headers, png_bytes)
    directory = tmp_path / "verified-backup"
    report = await prepared_backup(client, headers, [content], s3_storage, directory)
    ready, resume = asyncio.Event(), threading.Event()
    loop = asyncio.get_running_loop()
    original_call = BaseClient._make_api_call

    def paused_put(client, operation_name, parameters):
        result = original_call(client, operation_name, parameters)
        if operation_name == "PutObject" and parameters.get("Bucket") == "original-images":
            loop.call_soon_threadsafe(ready.set)
            if not resume.wait(5):
                raise TimeoutError("synthetic copy barrier")
        return result

    with monkeypatch.context() as fault:
        fault.setattr(BaseClient, "_make_api_call", paused_put)
        migration = asyncio.create_task(
            migrate_originals(
                sessions.kw["bind"],
                StorageRouter(settings),
                backup_directory=directory,
                restore_report_file=report,
            )
        )
        try:
            await asyncio.wait_for(ready.wait(), timeout=5)
            deleted = await asyncio.wait_for(
                client.delete(
                    f"/api/v1/contents/{content['id']}",
                    headers=headers,
                ),
                timeout=2,
            )
            assert deleted.status_code == 204
        finally:
            resume.set()
        result = await asyncio.wait_for(migration, timeout=5)
    assert result["migrated"] == 0 and result["results"][0]["status"] == "content_deleted"
    async with sessions() as restarted_worker:
        assert (await retry_image_deletions(restarted_worker))["pending"] == 0
    assert not s3_storage.list_objects_v2(Bucket="original-images").get("Contents")
    assert not list(tmp_path.glob("screenshots/**/*.png"))
    assert (
        await client.get(content["assets"][0]["download_url"], headers=headers)
    ).status_code == 404


async def test_uncertain_flip_commit_never_cleans_a_committed_original(
    committed_api,
    s3_storage,
    png_bytes,
    monkeypatch,
    tmp_path,
):
    from app.services.image_deletion_service import retry_image_deletions
    from scripts.image_migration import migrate_originals

    client, headers, sessions = committed_api
    monkeypatch.setattr(settings, "storage_backend", "local")
    content = await upload(client, headers, png_bytes)
    directory = tmp_path / "verified-backup"
    report = await prepared_backup(client, headers, [content], s3_storage, directory)
    original_commit = AsyncSession.commit

    async def acknowledgement_lost(session):
        flipping = any(
            isinstance(item, ImageDeletion) and item.completed and "source_identity" in item.intent
            for item in session.dirty
        )
        await original_commit(session)
        if flipping:
            raise ConnectionError("synthetic committed flip acknowledgement loss")

    with monkeypatch.context() as fault:
        fault.setattr(AsyncSession, "commit", acknowledgement_lost)
        result = await migrate_originals(
            sessions.kw["bind"],
            StorageRouter(settings),
            backup_directory=directory,
            restore_report_file=report,
        )
    assert result["passed"] is False and result["migrated"] == 0
    async with sessions() as restarted_worker:
        assert (await retry_image_deletions(restarted_worker))["pending"] == 0
    assert (
        await client.get(content["assets"][0]["download_url"], headers=headers)
    ).content == png_bytes
    assert len(s3_storage.list_objects_v2(Bucket="original-images")["Contents"]) == 1
    result = await migrate_originals(
        sessions.kw["bind"],
        StorageRouter(settings),
        backup_directory=directory,
        restore_report_file=report,
    )
    assert result["passed"] and result["migrated"] == 0


async def test_active_backup_defers_migration_flip_without_holding_the_global_deletion_lock(
    committed_api,
    s3_storage,
    png_bytes,
    monkeypatch,
    tmp_path,
):
    from app.integrations.deletion_ledger import IMAGE_CLEANUP_LOCK
    from scripts.image_migration import migrate_originals

    client, headers, sessions = committed_api
    monkeypatch.setattr(settings, "storage_backend", "local")
    content = await upload(client, headers, png_bytes)
    directory = tmp_path / "verified-backup"
    report = await prepared_backup(client, headers, [content], s3_storage, directory)
    async with sessions.kw["bind"].connect() as backup:
        await backup.execute(
            text("SELECT pg_advisory_lock_shared(:key)"),
            {"key": IMAGE_CLEANUP_LOCK},
        )
        try:
            result = await asyncio.wait_for(
                migrate_originals(
                    sessions.kw["bind"],
                    StorageRouter(settings),
                    backup_directory=directory,
                    restore_report_file=report,
                ),
                timeout=3,
            )
            assert result["results"][0]["status"] == "backup_or_cleanup_busy"
            assert result["migrated"] == 0 and not result["passed"]
            response = await asyncio.wait_for(
                client.delete(
                    f"/api/v1/contents/{content['id']}",
                    headers=headers,
                ),
                timeout=2,
            )
            assert response.status_code == 204
        finally:
            await backup.execute(
                text("SELECT pg_advisory_unlock_shared(:key)"),
                {"key": IMAGE_CLEANUP_LOCK},
            )


async def test_durable_delete_with_failed_database_commit_is_not_reconnected_by_migration(
    committed_api,
    s3_storage,
    png_bytes,
    monkeypatch,
    tmp_path,
):
    from app.services.image_deletion_service import retry_image_deletions
    from scripts.image_migration import migrate_originals

    client, headers, sessions = committed_api
    monkeypatch.setattr(settings, "storage_backend", "local")
    content = await upload(client, headers, png_bytes)
    directory = tmp_path / "verified-backup"
    report = await prepared_backup(client, headers, [content], s3_storage, directory)
    async def reject_delete_commit(session):
        raise ConnectionError("synthetic rejected deletion transaction")

    with monkeypatch.context() as fault:
        fault.setattr(AsyncSession, "commit", reject_delete_commit)
        response = await client.delete(f"/api/v1/contents/{content['id']}", headers=headers)
    assert response.status_code == 500
    result = await migrate_originals(
        sessions.kw["bind"],
        StorageRouter(settings),
        backup_directory=directory,
        restore_report_file=report,
    )
    assert not result["passed"] and result["migrated"] == 0
    assert result["results"][0]["status"] == "deletion_pending"
    async with sessions() as restarted_worker:
        assert (await retry_image_deletions(restarted_worker))["pending"] == 0
    assert not list(tmp_path.glob("screenshots/**/*.png"))
    assert not s3_storage.list_objects_v2(Bucket="original-images").get("Contents")
    downloaded = await client.get(content["assets"][0]["download_url"], headers=headers)
    assert downloaded.status_code == 404
