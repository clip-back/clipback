"""Opt-in real DB dump, private Bucket backup and isolated Bucket restoration."""

import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

from scripts.check_backup_restore import RestoreDrill, check
from scripts.image_backup import BackupBucket, materialize_backup
from tests.deployment.test_backup_restore_docker import execute

pytestmark = pytest.mark.skipif(
    os.environ.get("RUN_DOCKER_RECOVERY_TESTS") != "1",
    reason="RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are required",
)


@pytest.fixture(scope="module")
def bucket_backup(tmp_path_factory):
    directory = tmp_path_factory.mktemp("synthetic-bucket-backup")
    image = os.environ.get("CLIPBACK_RECOVERY_TEST_IMAGE", "clipback-backup-recovery:check")
    drill = RestoreDrill()
    network, db, api, s3 = [
        drill.owner + suffix for suffix in ("-net", "-db", "-api", "-s3")
    ]
    source_images = directory / "source-images"
    source_images.mkdir(mode=0o700)
    secret = "synthetic-bucket-recovery-secret"
    environment = {
        "APP_ENVIRONMENT": "test",
        "YOUTUBE_SUMMARY_ENABLED": "false",
        "SECRET_KEY": secret,
        "STORAGE_ROOT": "/data/screenshots",
        "PORT": "8123",
        "BACKEND_CORS_ORIGINS": "[]",
        "DATABASE_URL": f"postgresql://postgres:fixture@{db}:5432/clipback",
        "STORAGE_BACKEND": "s3",
        "S3_ENDPOINT_URL": f"http://{s3}:5000",
        "S3_BUCKET": "primary-originals",
        "S3_REGION": "us-east-1",
        "S3_ADDRESSING_STYLE": "path",
        "S3_ACCESS_KEY_ID": "testing",
        "S3_SECRET_ACCESS_KEY": "testing",
        "DELETION_LEDGER_BACKEND": "s3",
        "DELETION_LEDGER_S3_ENDPOINT_URL": f"http://{s3}:5000",
        "DELETION_LEDGER_S3_BUCKET": "independent-ledger",
        "DELETION_LEDGER_S3_REGION": "us-east-1",
        "DELETION_LEDGER_S3_ADDRESSING_STYLE": "path",
        "DELETION_LEDGER_S3_ACCESS_KEY_ID": "testing",
        "DELETION_LEDGER_S3_SECRET_ACCESS_KEY": "testing",
    }
    env_args = [arg for key, value in environment.items() for arg in ("-e", f"{key}={value}")]
    try:
        # Synthetic producer exposes DB/S3 only on loopback for the host operator CLI.
        # The actual restored environment remains --internal with no published ports.
        drill.create("network", network)
        drill.container(
            db,
            "--network",
            network,
            "-p",
            "127.0.0.1::5432",
            "-e",
            "POSTGRES_PASSWORD=fixture",
            "-e",
            "POSTGRES_DB=clipback",
            "postgres:16",
        )
        drill.docker("start", db)
        drill.wait("exec", db, "pg_isready", "-U", "postgres", "-d", "clipback")
        drill.container(s3, "--network", network, "-p", "127.0.0.1::5000", "motoserver/moto:5.2.4")
        drill.docker("start", s3)
        drill.wait(
            "exec",
            s3,
            "python",
            "-c",
            "import urllib.request; urllib.request.urlopen('http://127.0.0.1:5000')",
        )
        migrate = drill.owner + "-migrate"
        drill.container(
            migrate, "--network", network, *env_args, image, "alembic", "upgrade", "head"
        )
        drill.docker("start", "-a", migrate)
        bootstrap = drill.owner + "-bootstrap"
        drill.container(
            bootstrap,
            "--network",
            network,
            *env_args,
            image,
            "python",
            "-c",
            "from app.integrations.storage_client import get_storage_client; "
            "s=get_storage_client().for_backend('s3'); "
            "s.client.create_bucket(Bucket=s.bucket); "
            "s.client.create_bucket(Bucket='private-backup'); "
            "s.client.create_bucket(Bucket='independent-ledger'); "
            "from app.integrations.deletion_ledger import get_deletion_ledger; "
            "get_deletion_ledger().initialize()",
        )
        drill.docker("start", "-a", bootstrap)
        drill.container(api, "--network", network, *env_args,
                        "-v", f"{source_images}:/data/screenshots", image)
        drill.docker("start", api)
        drill.wait(
            "exec",
            api,
            "python",
            "-c",
            "import urllib.request; "
            "urllib.request.urlopen('http://127.0.0.1:8123/api/v1/health/ready')",
        )
        seed = (
            Path(__file__).with_name("probe.py").read_text().split('if __name__ == "__main__":')[0]
        )
        seed += """
async def seed_bucket():
    import hashlib
    from app.integrations.storage_client import get_storage_client
    state = await seed()
    state["user_id"] = json.loads(request("users/me", state["token"]))["id"]
    storage = get_storage_client()
    await storage.save_file("bucket/screenshot.png", PNG)
    async with AsyncSessionLocal() as session:
        asset = ContentAsset(content_id=state["content_id"], asset_type=AssetType.SCREENSHOT,
                             storage_backend="s3", storage_key="bucket/screenshot.png",
                             mime_type="image/png", size_bytes=len(PNG),
                             sha256=hashlib.sha256(PNG).hexdigest())
        session.add(asset)
        await session.flush()
        state["asset_id"] = asset.id
        await session.commit()
    return state
print(json.dumps(asyncio.run(seed_bucket())))
"""
        state = execute(drill, api, seed)
        drill.docker("stop", api)
        metadata = json.loads(drill.docker("image", "inspect", image))[0]
        revision = metadata["Config"]["Labels"]["org.opencontainers.image.revision"]
        db_port = json.loads(drill.docker("inspect", db))[0]["NetworkSettings"]["Ports"][
            "5432/tcp"
        ][0]["HostPort"]
        s3_port = json.loads(drill.docker("inspect", s3))[0]["NetworkSettings"]["Ports"][
            "5000/tcp"
        ][0]["HostPort"]
        credentials = directory / "operator.json"
        credentials.write_text(
            json.dumps(
                {
                    "endpoint_url": f"http://127.0.0.1:{s3_port}",
                    "bucket": "private-backup",
                    "region": "us-east-1",
                    "addressing_style": "path",
                    "access_key_id": "testing",
                    "secret_access_key": "testing",
                }
            )
        )
        credentials.chmod(0o600)
        sample = directory / "sample.json"
        sample.write_text(json.dumps({k: state[k] for k in ("content_id", "asset_id")}))
        sample.chmod(0o600)
        # Use the source major's real pg_dump. The wrapper transports the private dump only.
        wrapper = directory / "pg_dump"
        wrapper.write_text(f'''#!{sys.executable}
import pathlib, subprocess, sys
a = sys.argv[1:]
if a == ["--version"]:
    subprocess.run(["docker", "exec", "{db}", "pg_dump", "--version"], check=True)
    raise SystemExit(0)
output = pathlib.Path(a[a.index("--file") + 1])
a = a[:a.index("--file")]
command = ["docker", "exec", "{db}", "pg_dump", "-U", "postgres", "-d", "clipback", *a]
data = subprocess.run(command, check=True, stdout=subprocess.PIPE,
                      stderr=subprocess.PIPE).stdout
output.write_bytes(data)
''')
        wrapper.chmod(0o700)
        process_env = {
            **os.environ,
            **environment,
            "PYTHONPATH": str(Path(__file__).parents[2]),
            "DATABASE_URL": f"postgresql://postgres:fixture@127.0.0.1:{db_port}/clipback",
            "S3_ENDPOINT_URL": f"http://127.0.0.1:{s3_port}",
            "DELETION_LEDGER_S3_ENDPOINT_URL": f"http://127.0.0.1:{s3_port}",
            "STORAGE_ROOT": str(source_images),
        }
        command = [
            sys.executable,
            "-m",
            "scripts.image_backup",
            "--backup-config-file",
            str(credentials),
            "create",
            "--backup-id",
            "first",
            "--sample-file",
            str(sample),
            "--app-commit",
            revision,
            "--origin",
            "synthetic",
            "--writers-frozen",
            "--capture-deletion-checkpoint",
            "--pg-dump",
            str(wrapper),
        ]
        result = subprocess.run(command, env=process_env, capture_output=True, timeout=180)
        report = json.loads(result.stdout)
        assert result.returncode == 0 and report["passed"], report
        command[command.index("--backup-id") + 1] = "second"
        second = subprocess.run(command, env=process_env, capture_output=True, timeout=180)
        second_report = json.loads(second.stdout)
        assert second.returncode == 0 and second_report["passed"], second_report
        store = BackupBucket.from_config_file(credentials)
        materialized = directory / "materialized"
        manifest = materialize_backup(store, "first", materialized)
        restore_credentials = directory / "restore-credentials.json"
        restore_credentials.write_text(
            json.dumps({"secret_key": secret, "access_token": state["token"]})
        )
        restore_credentials.chmod(0o600)
        store.fixture_context = {
            "drill": drill, "api": api, "state": state, "env": process_env,
            "operator": credentials, "pg_dump": wrapper, "revision": revision,
            "directory": directory, "environment": environment, "s3": s3,
            "source_images": source_images,
            "sample": sample,
        }
        yield store, materialized, manifest, restore_credentials, image
    finally:
        assert drill.cleanup(), "Synthetic source cleanup failed"


def test_actual_bucket_originals_and_database_restore_with_authenticated_get(bucket_backup):
    store, directory, manifest, credentials, image = bucket_backup
    assert {a["storage_backend"] for a in manifest["assets"]} == {"local", "s3"}
    assert store.completed_points() == ["first", "second"]
    assert len([x for x in store.list_objects("originals/")]) == 1
    report = check(directory, credentials, image)
    assert report["passed"], report
    assert report["authentication_passed"] and report["image_bytes_passed"]
    assert report["cleanup_passed"]
    assert report["deletions_applied"] is False


def test_bucket_backup_source_missing_or_corrupt_is_not_restorable(bucket_backup, tmp_path):
    store, _, manifest, _, _ = bucket_backup
    key = manifest["assets"][0]["backup_key"]
    original = store.read(key)
    try:
        store.client.delete_object(Bucket=store.bucket, Key=key)
        with pytest.raises(FileNotFoundError):
            materialize_backup(store, "first", tmp_path / "missing")
        store.client.put_object(Bucket=store.bucket, Key=key, Body=b"corrupted")
        with pytest.raises(Exception, match="backup_hash_mismatch"):
            materialize_backup(store, "first", tmp_path / "corrupt")
    finally:
        store.put_verified(key, original)


def test_old_point_restores_latest_deletions_before_api_and_copies_expire(bucket_backup):
    from datetime import UTC, datetime, timedelta
    from uuid import uuid4

    from app.core.config import Settings
    from app.integrations.deletion_ledger import get_deletion_ledger
    from scripts.image_backup_jobs import maintain_backups

    store, directory, manifest, credentials, image = bucket_backup
    fixture = store.fixture_context
    drill, api, state = fixture["drill"], fixture["api"], fixture["state"]
    values = {k.lower(): v for k, v in fixture["env"].items()
              if k.lower() in Settings.model_fields}
    values["backend_cors_origins"] = []
    ledger = get_deletion_ledger(Settings(_env_file=None, **values))
    command = [sys.executable, "-m", "scripts.image_backup_jobs", "restore-check",
               "--backup-dir", str(directory), "--credentials-file", str(credentials),
               "--image", image, "--writers-frozen"]
    # IDs from an old DB incarnation must not erase a replacement original.
    # The synthetic producer is stopped; there are no concurrent ledger writers.
    old_identity = {
        "operation_id": str(uuid4()), "user_id": state["user_id"],
        "content_id": state["content_id"], "saved_at": "2000-01-01T00:00:00+00:00",
        "deleted_at": datetime.now(UTC).isoformat(), "assets": [{
            "storage_backend": "s3", "storage_key": "old-incarnation.png",
            "sha256": "f" * 64, "size_bytes": 1,
        }],
    }
    ledger.append(old_identity)
    ledger.append({**old_identity, "operation_id": str(uuid4())})
    first_event = ledger.store.read("event-00000000000000000001.json")
    ledger.store.client.delete_object(Bucket=ledger.store.bucket,
                                      Key="event-00000000000000000001.json")
    corrupt_capture = [sys.executable, "-m", "scripts.image_backup", "--backup-config-file",
                       str(fixture["operator"]), "create", "--backup-id", "corrupt-prefix",
                       "--sample-file", str(fixture["sample"]), "--app-commit", fixture["revision"],
                       "--origin", "synthetic", "--capture-deletion-checkpoint",
                       "--pg-dump", str(fixture["pg_dump"])]
    failed = subprocess.run(corrupt_capture, env=fixture["env"], capture_output=True, timeout=30)
    assert failed.returncode == 1 and not json.loads(failed.stdout)["passed"]
    assert "corrupt-prefix" not in store.completed_points()
    ledger.store.write("event-00000000000000000001.json", first_event)
    replacement = subprocess.run(command, env=fixture["env"], capture_output=True, timeout=180)
    replacement_report = json.loads(replacement.stdout)
    assert replacement.returncode == 0 and replacement_report["passed"], replacement_report
    assert replacement_report["deleted_content_count"] == 0
    assert replacement_report["asset_count"] == 2 and replacement_report["image_bytes_passed"]
    drill.docker("start", api)
    drill.wait("exec", api, "python", "-c", "import urllib.request; "
               "urllib.request.urlopen('http://127.0.0.1:8123/api/v1/health/ready')")
    # The old point has legacy NULL/local metadata. A later size/hash backfill and
    # local->S3 migration preserve the immutable key, before the user deletes it.
    execute(drill, api, """
import asyncio, hashlib, json
from pathlib import Path
from sqlalchemy import select
from app.db.session import AsyncSessionLocal
from app.models.content_asset import ContentAsset
from app.integrations.storage_client import get_storage_client
async def enrich_and_move():
    storage=get_storage_client()
    async with AsyncSessionLocal() as session:
        for asset in await session.scalars(select(ContentAsset).where(
                ContentAsset.storage_backend=='local')):
            body=Path('/data/screenshots',asset.storage_key).read_bytes()
            await storage.save_file(asset.storage_key,body)
            asset.storage_backend='s3'
            asset.size_bytes=len(body)
            asset.sha256=hashlib.sha256(body).hexdigest()
        await session.commit()
asyncio.run(enrich_and_move())
print('{}')
""")
    # Pause the external pg_dump after snapshot capture. The API can accept deletion while
    # the backup keeps original bytes protected, without a manual writer-freeze flag.
    import time

    marker = fixture["directory"] / "dump-started"
    release = fixture["directory"] / "dump-release"
    paused = fixture["directory"] / "paused-pg-dump"
    paused.write_text(f'''#!{sys.executable}
import pathlib, subprocess, sys, time
if sys.argv[1:] != ["--version"]:
    pathlib.Path({str(marker)!r}).touch()
    deadline=time.monotonic()+60
    while not pathlib.Path({str(release)!r}).exists():
        if time.monotonic()>deadline: raise SystemExit(1)
        time.sleep(0.05)
raise SystemExit(subprocess.call([{str(fixture["pg_dump"])!r}, *sys.argv[1:]]))
''')
    paused.chmod(0o700)
    online_command = [sys.executable, "-m", "scripts.image_backup", "--backup-config-file",
                      str(fixture["operator"]), "create", "--backup-id", "online-before-delete",
                      "--sample-file", str(fixture["sample"]), "--app-commit", fixture["revision"],
                      "--origin", "synthetic", "--capture-deletion-checkpoint",
                      "--pg-dump", str(paused)]
    producer = subprocess.Popen(online_command, env=fixture["env"], stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE)
    try:
        deadline = time.monotonic() + 30
        while not marker.exists():
            assert producer.poll() is None, "Online backup exited before pg_dump"
            assert time.monotonic() < deadline, "Online backup did not reach pg_dump"
            time.sleep(0.05)
        result = execute(drill, api, """
import json, sys, urllib.request
p=json.load(sys.stdin)
r=urllib.request.Request('http://127.0.0.1:8123/api/v1/contents/'+str(p['content_id']),
                         method='DELETE',headers={'Authorization':'Bearer '+p['token']})
print(json.dumps({'status':urllib.request.urlopen(r,timeout=3).status}))
""", state)
    finally:
        release.touch()
        output, _ = producer.communicate(timeout=90)
    assert producer.returncode == 0 and json.loads(output)["passed"]
    assert result["status"] == 204
    drill.docker("stop", api)
    head = ledger.store.read("head.json")
    ledger.store.client.delete_object(Bucket=ledger.store.bucket, Key="head.json")
    unavailable = subprocess.run(command, env=fixture["env"], capture_output=True, timeout=30)
    assert unavailable.returncode == 1 and not json.loads(unavailable.stdout)["passed"]
    ledger.store.write("head.json", head)
    restored = subprocess.run(command, env=fixture["env"], capture_output=True, timeout=180)
    report = json.loads(restored.stdout)
    assert restored.returncode == 0 and report["passed"], report
    assert report["live_deletion_ledger_verified"] and report["deletions_applied"]
    assert report["deleted_content_count"] == 1
    assert report["asset_count"] == 0 and report["image_get_skipped"]
    # An empty service still gets a complete daily point, without a stale configured sample.
    daily = [sys.executable, "-m", "scripts.image_backup_jobs", "daily",
             "--backup-config-file", str(fixture["operator"]),
             "--app-commit", fixture["revision"], "--origin", "synthetic",
             "--pg-dump", str(fixture["pg_dump"])]
    operator_image = os.environ.get("CLIPBACK_RECOVERY_OPERATOR_IMAGE")
    if operator_image:
        config = json.loads(fixture["operator"].read_text())
        config["endpoint_url"] = "http://127.0.0.1:5000"
        mounted_config = fixture["directory"] / "container-operator.json"
        mounted_config.write_text(json.dumps(config))
        mounted_config.chmod(0o600)
        environment = {**fixture["environment"], "S3_ENDPOINT_URL": "http://127.0.0.1:5000",
                       "DELETION_LEDGER_S3_ENDPOINT_URL": "http://127.0.0.1:5000"}
        # Fresh operator image must work without AI keys or an explicit worker override.
        environment.pop("YOUTUBE_SUMMARY_ENABLED")
        envfile = fixture["directory"] / "operator.env"
        envfile.write_text("\n".join(f"{k}={v}" for k, v in environment.items()) + "\n")
        envfile.chmod(0o600)
        operator = drill.owner + "-daily-operator"
        drill.container(
            operator, "--network", f"container:{fixture['s3']}",
            "--user", f"{os.getuid()}:{os.getgid()}", "--env-file", str(envfile),
            "-v", f"{mounted_config}:/operator/backup.json:ro",
            "-v", f"{fixture['source_images']}:/data/screenshots", operator_image,
            "daily", "--backup-config-file", "/operator/backup.json",
            "--app-commit", fixture["revision"], "--origin", "synthetic",
        )
        daily_report = json.loads(drill.docker("start", "-a", operator))
    else:
        created = subprocess.run(daily, env=fixture["env"], capture_output=True, timeout=180)
        daily_report = json.loads(created.stdout)
        assert created.returncode == 0, daily_report
    assert daily_report["passed"] and daily_report["backup_created"], daily_report
    duplicate = subprocess.run(daily, env=fixture["env"], capture_output=True, timeout=180)
    assert duplicate.returncode == 0 and not json.loads(duplicate.stdout)["backup_created"]
    # A concurrent scheduler cannot publish or collect while another operator owns the job.
    import asyncio

    import asyncpg

    async def competing_job():
        connection = await asyncpg.connect(fixture["env"]["DATABASE_URL"])
        try:
            await connection.execute("SELECT pg_advisory_lock(74264003)")
            for competing in (daily, online_command):
                busy = await asyncio.to_thread(
                    subprocess.run, competing, env=fixture["env"],
                    capture_output=True, timeout=30,
                )
                assert busy.returncode == 1
                assert json.loads(busy.stdout)["error"] == "backup_job_already_running"
        finally:
            await connection.close()

    asyncio.run(competing_job())
    event = ledger.read_verified_events()[-1]
    future = datetime.fromisoformat(event["deleted_at"]) + timedelta(days=6)
    gc = maintain_backups(store, ledger, now=future)
    assert gc["freshness_met"] is False  # Simulated six-day scheduler outage is observable.
    assert store.list_objects("originals/") == []
    assert ledger.read_verified_checkpoint()["sequence"] == 3
