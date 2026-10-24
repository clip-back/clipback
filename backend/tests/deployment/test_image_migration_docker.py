"""Real operator CLI, PostgreSQL dump, HTTP S3 and deletion-aware isolated restore."""

import json
import os
import subprocess
import sys

import pytest

from scripts.image_backup import materialize_backup
from tests.deployment.test_backup_restore_docker import execute
from tests.deployment.test_image_backup_docker import bucket_backup as bucket_backup

pytestmark = pytest.mark.skipif(
    os.environ.get("RUN_DOCKER_RECOVERY_TESTS") != "1",
    reason="RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are required",
)


def command(arguments, environment, timeout=180):
    __tracebackhide__ = True  # Environment and private fixture paths are not diagnostics.
    result = subprocess.run(
        [sys.executable, "-m", *arguments],
        env=environment,
        capture_output=True,
        timeout=timeout,
    )
    report = json.loads(result.stdout)
    assert result.returncode == 0 and report["passed"], report
    return report


def admission_control(operation, environment):
    result = subprocess.run(
        [sys.executable, "-m", "scripts.image_storage_admin", operation],
        env=environment, capture_output=True, timeout=30,
    )
    assert result.returncode == 0
    assert json.loads(result.stdout) == {"uploads_paused": operation == "pause"}


def test_actual_migration_cli_stops_resumes_preserves_bytes_and_old_restore_keeps_user_deletion(
    bucket_backup,
):
    store, _, _, credentials, image = bucket_backup
    fixture = store.fixture_context
    drill, api, state = fixture["drill"], fixture["api"], fixture["state"]
    drill.docker("start", api)
    drill.wait(
        "exec",
        api,
        "python",
        "-c",
        "import urllib.request; "
        "urllib.request.urlopen('http://127.0.0.1:8123/api/v1/health/ready')",
    )
    execute(
        drill,
        api,
        """
import asyncio,json
from sqlalchemy import select
from app.core.config import settings
from app.db.session import AsyncSessionLocal
from app.integrations.storage_client import LocalStorageClient
from app.models.content_asset import ContentAsset,AssetType
async def add():
    async with AsyncSessionLocal() as session:
        first=await session.scalar(select(ContentAsset).where(
            ContentAsset.storage_backend=='local'))
        storage=LocalStorageClient(settings.storage_root)
        await storage.save_file('migration/second.png',await storage.read_file(first.storage_key))
        session.add(ContentAsset(content_id=first.content_id,asset_type=AssetType.SCREENSHOT,
                    storage_key='migration/second.png',storage_backend='local',mime_type='image/png'))
        await session.commit()
asyncio.run(add())
print('{}')
""",
    )
    probe = """
import hashlib,json,sys,urllib.request
p=json.load(sys.stdin)
def get(path):
    r=urllib.request.Request('http://127.0.0.1:8123/api/v1/'+path,
                            headers={'Authorization':'Bearer '+p['token']})
    with urllib.request.urlopen(r,timeout=5) as response: return response.read()
detail=json.loads(get('contents/'+str(p['content_id'])))
print(json.dumps({'content_id':detail['id'],'saved_at':detail['saved_at'],
 'assets':[{'id':a['id'],'sha256':hashlib.sha256(get('uploads/assets/'+str(a['id']))).hexdigest()}
           for a in detail['assets']]}))
"""
    before = execute(drill, api, probe, state)
    assert len(before["assets"]) == 3
    # Exercise the same DB/S3 environment's operator admission gate before the
    # paired backup, migration, user deletion and old-point restoration below.
    admission_control("pause", fixture["env"])
    paused = execute(drill, api, """
import io,json,sys,urllib.request,urllib.error
from PIL import Image
p=json.load(sys.stdin)
boundary='clipback74'
output=io.BytesIO()
Image.new('RGB',(8,8),'blue').save(output,format='PNG')
png=output.getvalue()
body=(b'--clipback74\\r\\nContent-Disposition: form-data; name="file"; filename="probe.png"'
      b'\\r\\nContent-Type: image/png\\r\\n\\r\\n'+png+b'\\r\\n--clipback74--\\r\\n')
r=urllib.request.Request('http://127.0.0.1:8123/api/v1/uploads/screenshots',data=body,
 headers={'Authorization':'Bearer '+p['token'],
          'Content-Type':'multipart/form-data; boundary='+boundary})
try:
 urllib.request.urlopen(r,timeout=10)
 raise AssertionError('Paused upload was accepted')
except urllib.error.HTTPError as error:
 print(json.dumps({'status':error.code,'detail':json.load(error)['detail']}))
""", state)
    assert paused["status"] == 409
    assert paused["detail"]["code"] == "image_uploads_paused"
    assert execute(drill, api, probe, state) == before
    admission_control("resume", fixture["env"])
    drill.docker("stop", api)
    command(
        [
            "scripts.image_backup",
            "--backup-config-file",
            str(fixture["operator"]),
            "create",
            "--backup-id",
            "migration-before",
            "--sample-file",
            str(fixture["sample"]),
            "--app-commit",
            fixture["revision"],
            "--origin",
            "synthetic",
            "--writers-frozen",
            "--capture-deletion-checkpoint",
            "--pg-dump",
            str(fixture["pg_dump"]),
        ],
        fixture["env"],
    )
    directory = fixture["directory"] / "migration-materialized"
    materialize_backup(store, "migration-before", directory)
    restore = [
        "scripts.image_backup_jobs",
        "restore-check",
        "--backup-dir",
        str(directory),
        "--credentials-file",
        str(credentials),
        "--image",
        image,
        "--writers-frozen",
    ]
    verified = command(restore, fixture["env"])
    assert verified["image_bytes_passed"] and verified["live_deletion_ledger_verified"]
    report_file = directory / "restore-report.json"
    report_file.write_text(json.dumps(verified))
    report_file.chmod(0o600)
    inspect = command(["scripts.image_migration", "inspect"], fixture["env"])
    assert [item["status"] for item in inspect["results"]].count("ready") == 2
    migrate = [
        "scripts.image_migration",
        "apply",
        "--backup-directory",
        str(directory),
        "--restore-report-file",
        str(report_file),
        "--limit",
        "1",
    ]
    first = command(migrate, fixture["env"])
    assert first["migrated"] == 1
    partial = command(["scripts.image_migration", "inspect"], fixture["env"])
    assert [item["status"] for item in partial["results"]].count("ready") == 1
    drill.docker("start", api)
    drill.wait(
        "exec",
        api,
        "python",
        "-c",
        "import urllib.request; "
        "urllib.request.urlopen('http://127.0.0.1:8123/api/v1/health/ready')",
    )
    assert execute(drill, api, probe, state) == before
    second = command(migrate, fixture["env"])
    assert second["migrated"] == 1
    assert command(migrate, fixture["env"])["migrated"] == 0
    assert execute(drill, api, probe, state) == before
    assert len(list(fixture["source_images"].rglob("*.png"))) == 2
    deletion = execute(
        drill,
        api,
        """
import json,sys,urllib.request
p=json.load(sys.stdin)
r=urllib.request.Request('http://127.0.0.1:8123/api/v1/contents/'+str(p['content_id']),
                         method='DELETE',headers={'Authorization':'Bearer '+p['token']})
print(json.dumps({'status':urllib.request.urlopen(r,timeout=3).status}))
""",
        state,
    )
    assert deletion["status"] == 204
    assert not list(fixture["source_images"].rglob("*.png"))
    assert not store.client.list_objects_v2(Bucket="primary-originals").get("Contents")
    drill.docker("stop", api)
    latest = command(restore, fixture["env"])
    assert latest["live_deletion_ledger_verified"] and latest["deletions_applied"]
    assert latest["deleted_content_count"] == 1 and latest["asset_count"] == 0
    assert latest["image_get_skipped"] and not latest["image_bytes_passed"]
