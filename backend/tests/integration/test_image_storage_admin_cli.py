import asyncio
import json
import os
import subprocess
import sys
from urllib.parse import urlsplit
from uuid import uuid4

import boto3
import pytest

pytestmark = pytest.mark.asyncio


async def test_operator_cli_pause_resume_and_private_usage_report(tmp_path):
    if not os.environ.get("TEST_DATABASE_URL"):
        pytest.skip("TEST_DATABASE_URL is required for PostgreSQL tests")
    endpoint = os.environ.get("CLIPBACK_IMAGE_TEST_S3_ENDPOINT")
    if not endpoint:
        pytest.skip("CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local synthetic CLI test")
    parsed = urlsplit(endpoint)
    assert parsed.scheme == "http" and parsed.hostname in {"127.0.0.1", "localhost"}
    originals, backups = f"clipback72-originals-{uuid4().hex}", f"clipback72-backups-{uuid4().hex}"
    client = boto3.client(
        "s3",
        endpoint_url=endpoint,
        region_name="us-east-1",
        aws_access_key_id="operator-test-key",
        aws_secret_access_key="operator-test-secret",
    )
    original_root = tmp_path / "originals"
    original_root.mkdir()
    (original_root / "private-file.png").write_bytes(b"12345")
    config = tmp_path / "backup.json"
    config.write_text(
        json.dumps(
            {
                "endpoint_url": endpoint,
                "bucket": backups,
                "region": "us-east-1",
                "addressing_style": "path",
                "access_key_id": "operator-test-key",
                "secret_access_key": "operator-test-secret",
            }
        )
    )
    config.chmod(0o600)
    environment = {
        **os.environ,
        "DATABASE_URL": os.environ["TEST_DATABASE_URL"],
        "YOUTUBE_SUMMARY_ENABLED": "false",
        "STORAGE_BACKEND": "s3",
        "STORAGE_ROOT": str(original_root),
        "S3_ENDPOINT_URL": endpoint,
        "S3_BUCKET": originals,
        "S3_REGION": "us-east-1",
        "S3_ADDRESSING_STYLE": "path",
        "S3_ACCESS_KEY_ID": "operator-test-key",
        "S3_SECRET_ACCESS_KEY": "operator-test-secret",
    }

    async def cli(*arguments):
        return await asyncio.to_thread(
            subprocess.run,
            [
                sys.executable,
                "-m",
                "scripts.image_storage_admin",
                *arguments,
            ],
            env=environment,
            capture_output=True,
            text=True,
            timeout=15,
        )

    try:
        client.create_bucket(Bucket=originals)
        client.create_bucket(Bucket=backups)
        client.put_object(Bucket=originals, Key="private-original", Body=b"abc")
        client.put_object(Bucket=backups, Key="private-backup", Body=b"1234567")
        paused = await cli("pause")
        assert paused.returncode == 0
        assert json.loads(paused.stdout) == {"uploads_paused": True}
        result = await cli("report", "--backup-config", str(config))
        assert result.returncode == 0, result.stdout + result.stderr
        report = json.loads(result.stdout)
        assert report["uploads_paused"] is True
        assert report["physical_storage"] == {
            "local_originals": {"size_bytes": 5, "objects": 1},
            "bucket_originals": {"size_bytes": 3, "objects": 1},
            "backup": {"size_bytes": 7, "objects": 1},
        }
        for private in (
            "private-original",
            "private-backup",
            "private-file",
            "operator-test-secret",
        ):
            assert private not in result.stdout + result.stderr
        config.chmod(0o644)
        failed = await cli("report", "--backup-config", str(config))
        assert failed.returncode == 1
        assert json.loads(failed.stdout) == {
            "passed": False,
            "error": "image_storage_operation_failed",
        }
        assert not failed.stderr
    finally:
        resumed = await cli("resume")
        for bucket, key in ((originals, "private-original"), (backups, "private-backup")):
            client.delete_object(Bucket=bucket, Key=key)
            client.delete_bucket(Bucket=bucket)
    assert resumed.returncode == 0
    assert json.loads(resumed.stdout) == {"uploads_paused": False}
