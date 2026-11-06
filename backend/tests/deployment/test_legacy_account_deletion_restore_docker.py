"""A recovery point made by an API image predating account deletion (ADR 0004, 0008).

Its restore runs the current replay source and probe inside that historical image, then
checks the deleted token account (401), a living token account and the DB rows (#252).
"""

import json
import os
import subprocess
import sys

import pytest

from scripts.check_backup_restore import PROBE, CheckError
from scripts.image_backup import materialize_backup
from tests.deployment.test_backup_restore_docker import execute
from tests.deployment.test_image_backup_docker import bucket_backup as bucket_backup
from tests.deployment.test_image_migration_docker import command

pytestmark = pytest.mark.skipif(
    os.environ.get("RUN_DOCKER_RECOVERY_TESTS") != "1",
    reason="RUN_DOCKER_RECOVERY_TESTS=1 and labelled local images are required",
)
# Built in CI from a revision before account deletion, labelled with that revision.
LEGACY_IMAGE = os.environ.get("CLIPBACK_LEGACY_API_IMAGE")
# The current server deletes the account after the recovery point was made.
DELETE_ACCOUNT = """
import asyncio, sys
from app.db.session import AsyncSessionLocal
from app.services.account_deletion_service import apply_account_deletion, record_account_deletion
async def delete(user_id):
    async with AsyncSessionLocal() as session:
        await apply_account_deletion(session, await record_account_deletion(session, user_id))
        await session.commit()
asyncio.run(delete(int(sys.argv[1])))
"""
SEED_USER = """
import asyncio,json,urllib.request
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import engine
from app.integrations.storage_client import get_storage_client
from app.models.content import Content,ContentType,ContentSource
from app.models.content_asset import ContentAsset,AssetType
def request(path,token=None,data=None):
 r=urllib.request.Request('http://127.0.0.1:8123/api/v1/'+path,
  data=json.dumps(data).encode() if data is not None else None,
  headers={'Content-Type':'application/json',
           **({'Authorization':'Bearer '+token} if token else {})})
 return json.load(urllib.request.urlopen(r))
token=request('auth/guest',data={})['access_token']
user=request('users/me',token)['id']
async def seed():
 storage=get_storage_client()
 body=await storage.read_file('bucket/screenshot.png',backend='s3')
 async with AsyncSession(engine,expire_on_commit=False) as session:
  content=Content(user_id=user,content_type=ContentType.SCREENSHOT,
   source=ContentSource.SCREENSHOT,title='living',summary='synthetic legacy restore')
  session.add(content);await session.flush()
  await storage.save_file('legacy/living.png',body)
  session.add(ContentAsset(content_id=content.id,asset_type=AssetType.SCREENSHOT,
   storage_backend='s3',storage_key='legacy/living.png',mime_type='image/png'))
  await session.commit()
asyncio.run(seed())
print(json.dumps({'token':token,'user_id':user}))
"""
HAS_ACCOUNT_DELETION = (
    "import importlib.util,json;"
    "print(json.dumps(importlib.util.find_spec('app.services.account_deletion_service')"
    " is not None))"
)


@pytest.mark.parametrize("bucket_backup", [LEGACY_IMAGE], indirect=True)
def test_legacy_image_restore_applies_account_deletions_with_current_probe(bucket_backup):
    store, _, _, deleted_credentials, image = bucket_backup
    fixture = store.fixture_context
    drill, api, deleted = fixture["drill"], fixture["api"], fixture["state"]

    def start_api():
        drill.docker("start", api)
        drill.wait(
            "exec", api, "python", "-c", "import urllib.request; "
            "urllib.request.urlopen('http://127.0.0.1:8123/api/v1/health/ready')",
        )

    def delete_account(user_id):
        subprocess.run([sys.executable, "-c", DELETE_ACCOUNT, str(user_id)],
                       env=fixture["env"], check=True, capture_output=True, timeout=60)

    def source_probe(deleted_accounts):
        return execute(drill, api, PROBE, {"format_version": 2, "verify_api": False,
                                           "deleted_accounts": deleted_accounts})

    start_api()
    # A real historical image, not the current one with a module hidden.
    assert execute(drill, api, HAS_ACCOUNT_DELETION) is False
    living = execute(drill, api, SEED_USER)
    drill.docker("stop", api)
    living_credentials = fixture["directory"] / "legacy-living-credentials.json"
    living_credentials.write_text(json.dumps({
        "secret_key": "synthetic-bucket-recovery-secret", "access_token": living["token"],
    }))
    living_credentials.chmod(0o600)
    command([
        "scripts.image_backup", "--backup-config-file", str(fixture["operator"]), "create",
        "--backup-id", "legacy-accounts", "--sample-file", str(fixture["sample"]),
        "--app-commit", fixture["revision"], "--origin", "synthetic", "--writers-frozen",
        "--capture-deletion-checkpoint", "--pg-dump", str(fixture["pg_dump"]),
    ], fixture["env"])
    directory = fixture["directory"] / "legacy-accounts"
    materialize_backup(store, "legacy-accounts", directory)

    def restore(credentials):
        return command([
            "scripts.image_backup_jobs", "restore-check",
            "--synthetic-offline", "--backup-dir", str(directory),
            "--credentials-file", str(credentials), "--image", image, "--writers-frozen",
        ], fixture["env"])

    delete_account(deleted["user_id"])
    # The current probe in the historical image fails while an account's rows remain.
    start_api()
    assert source_probe([deleted["user_id"]])["tables"]["users"] == 1
    with pytest.raises(CheckError):
        source_probe([living["user_id"]])
    drill.docker("stop", api)

    # The token's account was deleted by the replayed record: 401 and no image GET.
    report = restore(deleted_credentials)
    assert report["authentication_passed"] and report["token_account_deleted"]
    assert report["image_get_skipped"] and not report["image_bytes_passed"]
    assert report["deleted_account_count"] == 1 and report["deleted_content_count"] == 1

    # A living account's token keeps the usual authentication and original checks.
    report = restore(living_credentials)
    assert report["authentication_passed"] and not report["token_account_deleted"]
    assert report["image_bytes_passed"] and not report["image_get_skipped"]
    assert report["deleted_account_count"] == 1

    # Every account deleted: the deleted token account's 401 and zero rows still pass.
    delete_account(living["user_id"])
    report = restore(deleted_credentials)
    assert report["authentication_passed"] and report["token_account_deleted"]
    assert report["image_get_skipped"] and report["asset_count"] == 0
    assert report["deleted_account_count"] == 2 and report["deleted_content_count"] == 2
