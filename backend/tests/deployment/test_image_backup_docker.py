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
    network, db, api, s3, files = [
        drill.owner + suffix for suffix in ("-net", "-db", "-api", "-s3", "-files")
    ]
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
    }
    env_args = [arg for key, value in environment.items() for arg in ("-e", f"{key}={value}")]
    try:
        # Synthetic producer exposes DB/S3 only on loopback for the host operator CLI.
        # The actual restored environment remains --internal with no published ports.
        drill.create("network", network)
        drill.create("volume", files)
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
            "s.client.create_bucket(Bucket='private-backup')",
        )
        drill.docker("start", "-a", bootstrap)
        drill.container(api, "--network", network, *env_args, "-v", f"{files}:/data", image)
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
        source_images = directory / "source-images"
        drill.docker("cp", f"{api}:/data/screenshots", str(source_images))
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
