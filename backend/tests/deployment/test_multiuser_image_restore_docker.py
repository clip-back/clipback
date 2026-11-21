"""A live deletion-aware restore must probe only the credential owner's images."""

import json
import os

import pytest

from scripts.check_backup_restore import RestoreDrill, check
from scripts.image_backup import materialize_backup
from tests.deployment.test_backup_restore_docker import execute
from tests.deployment.test_image_backup_docker import bucket_backup as bucket_backup
from tests.deployment.test_image_migration_docker import command

pytestmark = pytest.mark.skipif(
    os.environ.get("RUN_DOCKER_RECOVERY_TESTS") != "1",
    reason="RUN_DOCKER_RECOVERY_TESTS=1 and labelled local images are required",
)


def test_restore_keeps_living_sample_and_replaces_deleted_sample_only_with_owned_original(
    bucket_backup,
):
    store, _, _, _, image = bucket_backup
    fixture = store.fixture_context
    drill, api = fixture["drill"], fixture["api"]

    def start_api():
        drill.docker("start", api)
        drill.wait(
            "exec", api, "python", "-c", "import urllib.request; "
            "urllib.request.urlopen('http://127.0.0.1:8123/api/v1/health/ready')",
        )

    start_api()
    # The fixture already has earlier originals owned by another user. Create
    # the credential owner's two independent records after them deliberately.
    state = execute(drill, api, """
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
 records=[]
 async with AsyncSession(engine,expire_on_commit=False) as session:
  for label in ('sample','survivor'):
   content=Content(user_id=user,content_type=ContentType.SCREENSHOT,
    source=ContentSource.SCREENSHOT,title=label,summary='synthetic multiuser restore')
   session.add(content);await session.flush()
   key='multiuser/'+label+'.png';await storage.save_file(key,body)
   asset=ContentAsset(content_id=content.id,asset_type=AssetType.SCREENSHOT,
    storage_backend='s3',storage_key=key,mime_type='image/png')
   session.add(asset);await session.flush()
   records.append({'content_id':content.id,'asset_id':asset.id})
  await session.commit()
 return {'token':token,'records':records}
print(json.dumps(asyncio.run(seed())))
""")
    drill.docker("stop", api)
    sample = fixture["directory"] / "multiuser-sample.json"
    sample.write_text(json.dumps(state["records"][0]))
    sample.chmod(0o600)
    credentials = fixture["directory"] / "multiuser-credentials.json"
    credentials.write_text(json.dumps({
        "secret_key": "synthetic-bucket-recovery-secret", "access_token": state["token"],
    }))
    credentials.chmod(0o600)
    command([
        "scripts.image_backup", "--backup-config-file", str(fixture["operator"]), "create",
        "--backup-id", "multiuser", "--sample-file", str(sample), "--app-commit",
        fixture["revision"], "--origin", "synthetic", "--writers-frozen",
        "--capture-deletion-checkpoint", "--pg-dump", str(fixture["pg_dump"]),
    ], fixture["env"])
    directory = fixture["directory"] / "multiuser-materialized"
    materialize_backup(store, "multiuser", directory)
    restore = [
        "scripts.image_backup_jobs", "restore-check", "--synthetic-offline",
        "--backup-dir", str(directory),
        "--credentials-file", str(credentials), "--image", image, "--writers-frozen",
    ]
    living = command(restore, fixture["env"])
    assert living["authentication_passed"] and living["image_bytes_passed"]
    assert not living["image_get_skipped"] and living["asset_count"] == 4

    def delete_record(record):
        start_api()
        result = execute(drill, api, """
import json,sys,urllib.request
p=json.load(sys.stdin)
r=urllib.request.Request('http://127.0.0.1:8123/api/v1/contents/'+str(p['content_id']),
 method='DELETE',headers={'Authorization':'Bearer '+p['token']})
with urllib.request.urlopen(r) as response: print(json.dumps({'status':response.status}))
""", {**record, "token": state["token"]})
        assert result == {"status": 204}
        drill.docker("stop", api)

    delete_record(state["records"][0])
    surviving = command(restore, fixture["env"])
    assert surviving["image_bytes_passed"] and not surviving["image_get_skipped"]
    assert surviving["asset_count"] == 3 and surviving["deleted_content_count"] == 1

    delete_record(state["records"][1])
    empty_owner = command(restore, fixture["env"])
    assert empty_owner["authentication_passed"] and empty_owner["live_deletion_ledger_verified"]
    assert not empty_owner["image_bytes_passed"] and empty_owner["image_get_skipped"]
    assert empty_owner["asset_count"] == 2 and empty_owner["deleted_content_count"] == 2


@pytest.mark.parametrize(
    "bucket_backup", [os.environ.get("CLIPBACK_LEGACY_API_IMAGE")], indirect=True,
)
def test_historical_image_replays_image_deletion_and_cleans_only_exclusive_tag(bucket_backup):
    store, _, _, credentials, image = bucket_backup
    assert image == os.environ["CLIPBACK_LEGACY_API_IMAGE"]
    fixture = store.fixture_context
    source_drill, source_api, state = fixture["drill"], fixture["api"], fixture["state"]

    def start_source():
        source_drill.docker("start", source_api)
        source_drill.wait(
            "exec", source_api, "python", "-c", "import urllib.request; "
            "urllib.request.urlopen('http://127.0.0.1:8123/api/v1/health/ready')",
        )

    start_source()
    survivor = execute(source_drill, source_api, """
import asyncio, json, sys
from app.db.session import AsyncSessionLocal
from app.models.content import Content, ContentSource, ContentType
from app.models.tag import Tag
from app.repositories.content_repository import ContentRepository

async def seed(data):
    user_id = data["user_id"]
    exclusive = Tag(user_id=user_id, name="exclusive", normalized_name="exclusive")
    shared = Tag(user_id=user_id, name="shared", normalized_name="shared")
    async with AsyncSessionLocal() as session:
        repository = ContentRepository(session)
        target = await repository.get_owned(user_id=user_id, content_id=data["content_id"])
        await repository.replace_tags(content=target, tags=[exclusive, shared])
        survivor = Content(
            user_id=user_id, content_type=ContentType.LINK, source=ContentSource.WEB,
            title="shared tag survivor", summary="", original_url="https://example.com/shared",
            tags=[shared],
        )
        session.add(survivor)
        await session.commit()
        return survivor.id

print(json.dumps(asyncio.run(seed(json.load(sys.stdin)))))
""", {"content_id": state["content_id"], "user_id": state["user_id"]})
    source_drill.docker("stop", source_api)
    command([
        "scripts.image_backup", "--backup-config-file", str(fixture["operator"]), "create",
        "--backup-id", "legacy-tags", "--sample-file", str(fixture["sample"]),
        "--app-commit", fixture["revision"], "--origin", "synthetic", "--writers-frozen",
        "--capture-deletion-checkpoint", "--pg-dump", str(fixture["pg_dump"]),
    ], fixture["env"])
    directory = fixture["directory"] / "legacy-tags"
    materialize_backup(store, "legacy-tags", directory)

    start_source()
    events = execute(source_drill, source_api, """
import json, sys, urllib.request
from app.integrations.deletion_ledger import get_deletion_ledger

data = json.load(sys.stdin)
request = urllib.request.Request(
    "http://127.0.0.1:8123/api/v1/contents/" + str(data["content_id"]),
    method="DELETE", headers={"Authorization": "Bearer " + data["token"]},
)
with urllib.request.urlopen(request) as response:
    assert response.status == 204
print(json.dumps(get_deletion_ledger().read_verified_events()))
""", {"content_id": state["content_id"], "token": state["token"]})
    source_drill.docker("stop", source_api)
    assert [event["content_id"] for event in events] == [state["content_id"]]

    class InspectRestoredTags(RestoreDrill):
        def run(self, manifest, paths, credentials, image):
            report = super().run(manifest, paths, credentials, image)
            self.tag_links = self.docker(
                "exec", self.owner + "-db", "psql", "-U", "postgres", "-d", "clipback",
                "-At", "-c", "SELECT t.name, ct.content_id FROM tags t "
                "LEFT JOIN content_tags ct ON ct.tag_id = t.id ORDER BY t.name",
            ).decode("utf-8").splitlines()
            return report

    restore = InspectRestoredTags(deletion_events=events)
    report = check(directory, credentials, image, restore)
    assert report["passed"], report
    assert report["deleted_content_count"] == 1
    assert restore.tag_links == [f"shared|{survivor}"]
