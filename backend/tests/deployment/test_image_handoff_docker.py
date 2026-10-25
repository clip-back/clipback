"""Built operator -> independent ledger -> actual local-storage API, synthetic only."""

import json
import os
import subprocess

import pytest

from scripts.check_backup_restore import REVISION_LABEL, RestoreDrill
from tests.deployment.test_backup_restore_docker import execute

pytestmark = pytest.mark.skipif(
    os.environ.get("RUN_DOCKER_RECOVERY_TESTS") != "1",
    reason="Requires built API/operator images from the same identified revision",
)


@pytest.fixture
def handoff(tmp_path_factory):
    drill = RestoreDrill()
    api_image = os.environ["CLIPBACK_HANDOFF_API_IMAGE"]
    operator_image = os.environ["CLIPBACK_LEDGER_OPERATOR_IMAGE"]
    expected_revision = os.environ["CLIPBACK_HANDOFF_REVISION"]
    # A stale or mixed image must fail before creating any resources or reporting readiness.
    image_ids = {}
    for role, image in (("api", api_image), ("operator", operator_image)):
        metadata = json.loads(drill.docker("image", "inspect", image))[0]
        assert metadata["Config"].get("Labels", {}).get(REVISION_LABEL) == expected_revision
        image_ids[role] = metadata["Id"]
    network, db, api, s3 = [drill.owner + suffix for suffix in ("-net", "-db", "-api", "-s3")]
    root = tmp_path_factory.mktemp("handoff")
    files, certificates = root / "images", root / "tls"
    files.mkdir()
    certificates.mkdir()
    subprocess.run([
        "openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
        "-subj", f"/CN={s3}", "-addext", f"subjectAltName=DNS:{s3},DNS:localhost,IP:127.0.0.1",
        "-keyout", str(certificates / "key.pem"), "-out", str(certificates / "cert.pem"),
    ], check=True, capture_output=True, timeout=30)
    ledger_env = {
        "APP_ENVIRONMENT": "production", "AWS_CA_BUNDLE": "/tls/cert.pem",
        "DELETION_LEDGER_BACKEND": "s3",
        "DELETION_LEDGER_S3_ENDPOINT_URL": f"https://{s3}:5000",
        "DELETION_LEDGER_S3_BUCKET": "handoff-ledger",
        "DELETION_LEDGER_S3_REGION": "us-east-1",
        "DELETION_LEDGER_S3_ADDRESSING_STYLE": "path",
        "DELETION_LEDGER_S3_ACCESS_KEY_ID": "testing",
        "DELETION_LEDGER_S3_SECRET_ACCESS_KEY": "testing",
    }
    tls_args = ["-v", f"{certificates / 'cert.pem'}:/tls/cert.pem:ro"]

    def env_args(environment):
        return [item for key, value in environment.items() for item in ("-e", f"{key}={value}")]

    def cli(*arguments, overrides=None):
        return subprocess.run([
            "docker", "run", "--rm", "--network", network, *tls_args,
            *env_args({**ledger_env, **(overrides or {})}), "--entrypoint", "python",
            image_ids["operator"], "-m", "scripts.image_deletions", *arguments,
        ], capture_output=True, text=True, timeout=40)

    def s3_call(operation, **parameters):
        return drill.docker("exec", s3, "python", "-c",
            "import boto3; client=boto3.client('s3',endpoint_url='https://localhost:5000',"
            "verify='/tls/cert.pem',aws_access_key_id='testing',aws_secret_access_key='testing',"
            f"region_name='us-east-1'); client.{operation}(**{parameters!r})")

    try:
        drill.create("network", network, "--internal")
        drill.container(s3, "--network", network, "-v", f"{certificates}:/tls:ro",
                        "motoserver/moto:5.2.4", "--ssl-cert", "/tls/cert.pem",
                        "--ssl-key", "/tls/key.pem")
        drill.docker("start", s3)
        drill.wait("exec", s3, "python", "-c",
                   "import ssl,urllib.request; urllib.request.urlopen('https://localhost:5000',"
                   "context=ssl.create_default_context(cafile='/tls/cert.pem'))")
        s3_call("create_bucket", Bucket="handoff-ledger")
        initialized = cli("init", "--confirm-new-namespace")
        assert initialized.returncode == 0, initialized.stderr
        checkpoint = json.loads(initialized.stdout)
        checked = cli("checkpoint")
        assert checked.returncode == 0, checked.stderr
        assert json.loads(checked.stdout) == checkpoint
        drill.container(db, "--network", network, "-e", "POSTGRES_PASSWORD=fixture",
                        "-e", "POSTGRES_DB=clipback", "postgres:16")
        drill.docker("start", db)
        drill.wait("exec", db, "pg_isready", "-h", "127.0.0.1", "-U", "postgres", "-d", "clipback")
        api_env = {**ledger_env, "APP_ENVIRONMENT": "test", "YOUTUBE_SUMMARY_ENABLED": "false",
                   "DATABASE_URL": f"postgresql://postgres:fixture@{db}:5432/clipback",
                   "SECRET_KEY": "synthetic-handoff-secret", "STORAGE_BACKEND": "local",
                   "STORAGE_ROOT": "/data/screenshots", "PORT": "8123"}
        migration = drill.owner + "-migration"
        drill.container(migration, "--network", network, *tls_args, *env_args(api_env),
                        image_ids["api"], "alembic", "upgrade", "head")
        drill.docker("start", "-a", migration)
        drill.container(api, "--network", network, *tls_args, *env_args(api_env),
                        "-v", f"{files}:/data/screenshots", image_ids["api"])
        drill.docker("start", api)
        drill.wait("exec", api, "python", "-c",
                   "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8123/api/v1/health/ready')")
        yield drill, api, cli, s3_call, checkpoint, image_ids
    finally:
        assert drill.cleanup(), "Synthetic handoff cleanup failed"


UPLOAD = r"""
import httpx,json
from io import BytesIO
from PIL import Image
buffer=BytesIO()
Image.new('RGB',(4,4),(35,70,110)).save(buffer,format='PNG')
PNG=buffer.getvalue()
with httpx.Client(base_url='http://127.0.0.1:8123/api/v1', timeout=20) as client:
    token = client.post('/auth/guest', json={}).json()['access_token']
    headers = {'Authorization': 'Bearer ' + token}
    response = client.post('/uploads/screenshots', headers=headers,
                           files={'file': ('original.png', PNG, 'image/png')})
    assert response.status_code == 201, response.text
    content = response.json()
    asset_id = content['assets'][0]['id']
    path = '/uploads/assets/' + str(asset_id)
    assert client.get(path, headers=headers).content == PNG
    other = client.post('/auth/guest', json={}).json()['access_token']
    assert client.get(path, headers={'Authorization':'Bearer '+other}).status_code == 404
    print(json.dumps({'token': token, 'content_id':content['id'], 'asset_id':asset_id}))
"""


def delete(drill, api, state, expected):
    return execute(drill, api, r"""
import httpx,json,sys
state=json.load(sys.stdin)
with httpx.Client(base_url='http://127.0.0.1:8123/api/v1', timeout=20) as client:
    headers={'Authorization':'Bearer '+state['token']}
    response=client.delete('/contents/'+str(state['content_id']), headers=headers)
    assert response.status_code == state['expected'], response.text
    original=client.get('/uploads/assets/'+str(state['asset_id']), headers=headers)
    assert original.status_code == (404 if state['expected']==204 else 200)
    assert client.get('/health/ready').status_code == 200
print(json.dumps({'verified':True}))
""", {**state, "expected": expected})


def test_cli_initialized_ledger_supports_local_api_image_lifecycle(handoff):
    drill, api, cli, _, checkpoint, image_ids = handoff
    state = execute(drill, api, UPLOAD)
    assert delete(drill, api, state, 204) == {"verified": True}
    verified = cli("checkpoint")
    assert verified.returncode == 0, verified.stderr
    after = json.loads(verified.stdout)
    assert after["namespace"] == checkpoint["namespace"]
    assert after["sequence"] == checkpoint["sequence"] + 1
    assert after["digest"] != checkpoint["digest"]
    print(json.dumps({"images": image_ids, "local_lifecycle": "passed"}))


def test_readiness_does_not_hide_broken_ledger_or_successfully_delete(handoff):
    drill, api, cli, s3_call, _, _ = handoff
    state = execute(drill, api, UPLOAD)
    s3_call("put_object", Bucket="handoff-ledger", Key="head.json", Body="broken")
    assert cli("checkpoint").returncode == 1
    assert delete(drill, api, state, 503) == {"verified": True}
