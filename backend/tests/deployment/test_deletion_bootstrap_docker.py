"""Opt-in CLI contract tests against a built operator image and synthetic S3."""

import json
import os
import subprocess
from uuid import uuid4

import pytest

from scripts.check_backup_restore import RestoreDrill

pytestmark = pytest.mark.skipif(
    os.environ.get("RUN_DOCKER_RECOVERY_TESTS") != "1",
    reason="Requires Docker and a built CLIPBACK_LEDGER_OPERATOR_IMAGE",
)


@pytest.fixture(scope="module")
def bootstrap(tmp_path_factory):
    drill = RestoreDrill()
    network, s3 = drill.owner + "-network", drill.owner + "-s3"
    image = os.environ.get("CLIPBACK_LEDGER_OPERATOR_IMAGE", "clipback-ledger-operator:check")
    certificates = tmp_path_factory.mktemp("ledger-tls")
    subprocess.run([
        "openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
        "-subj", f"/CN={s3}", "-addext", f"subjectAltName=DNS:{s3},DNS:localhost,IP:127.0.0.1",
        "-keyout", str(certificates / "key.pem"), "-out", str(certificates / "cert.pem"),
    ], check=True, capture_output=True, timeout=30)
    try:
        drill.create("network", network, "--internal")
        drill.container(
            s3, "--network", network, "-v", f"{certificates}:/tls:ro", "motoserver/moto:5.2.4",
            "--ssl-cert", "/tls/cert.pem", "--ssl-key", "/tls/key.pem",
        )
        drill.docker("start", s3)
        drill.wait("exec", s3, "python", "-c",
                   "import ssl,urllib.request; urllib.request.urlopen('https://127.0.0.1:5000',"
                   "context=ssl.create_default_context(cafile='/tls/cert.pem'))")

        def bucket():
            name = "ledger-" + uuid4().hex
            drill.docker("exec", s3, "python", "-c",
                         "import boto3; boto3.client('s3',endpoint_url='https://localhost:5000',verify='/tls/cert.pem',"
                         "aws_access_key_id='testing',aws_secret_access_key='testing',"
                         "region_name='us-east-1').create_bucket(Bucket=" + repr(name) + ")")
            return name

        def invoke(name, *args, overrides=None):
            environment = {
                "APP_ENVIRONMENT": "production",
                "AWS_CA_BUNDLE": "/tls/cert.pem",
                "DELETION_LEDGER_BACKEND": "s3",
                "DELETION_LEDGER_S3_ENDPOINT_URL": f"https://{s3}:5000",
                "DELETION_LEDGER_S3_BUCKET": name,
                "DELETION_LEDGER_S3_REGION": "us-east-1",
                "DELETION_LEDGER_S3_ADDRESSING_STYLE": "path",
                "DELETION_LEDGER_S3_ACCESS_KEY_ID": "testing",
                "DELETION_LEDGER_S3_SECRET_ACCESS_KEY": "synthetic-secret-not-for-logs",
                **(overrides or {}),
            }
            env_args = [item for k, v in environment.items() for item in ("-e", f"{k}={v}")]
            return subprocess.run(
                ["docker", "run", "--rm", "--network", network,
                 "-v", f"{certificates / 'cert.pem'}:/tls/cert.pem:ro", *env_args,
                 "--entrypoint", "python", image, "-m", "scripts.image_deletions", *args],
                capture_output=True, text=True, timeout=30,
            )

        def s3_call(operation, **parameters):
            result = drill.docker("exec", s3, "python", "-c",
                "import boto3,json; client=boto3.client('s3',"
                "endpoint_url='https://localhost:5000',verify='/tls/cert.pem',"
                "aws_access_key_id='testing',aws_secret_access_key='testing',"
                "region_name='us-east-1'); "
                f"result=client.{operation}(**{parameters!r}); "
                "print(json.dumps(result,default=str))")
            return json.loads(result)

        yield bucket, invoke, s3_call
    finally:
        assert drill.cleanup(), "Synthetic bootstrap cleanup failed"


def test_built_operator_initializes_and_verifies_with_ledger_settings_only(bootstrap):
    bucket, invoke, _ = bootstrap
    name = bucket()
    initialized = invoke(name, "init", "--confirm-new-namespace")
    assert initialized.returncode == 0, initialized.stderr
    checkpoint = json.loads(initialized.stdout)
    assert checkpoint["sequence"] == 0
    assert checkpoint["digest"] == "0" * 64
    verified = invoke(name, "checkpoint")
    assert verified.returncode == 0, verified.stderr
    assert json.loads(verified.stdout) == checkpoint


def test_repeat_init_preserves_existing_namespace_and_checkpoint(bootstrap):
    bucket, invoke, _ = bootstrap
    name = bucket()
    first = invoke(name, "init", "--confirm-new-namespace")
    assert first.returncode == 0, first.stderr
    repeated = invoke(name, "init", "--confirm-new-namespace")
    assert repeated.returncode == 0, repeated.stderr
    assert json.loads(first.stdout) == json.loads(repeated.stdout)


@pytest.mark.parametrize("damage", ["missing-head", "missing-namespace", "corrupt-head"])
def test_damaged_ledger_is_not_reset_by_init(bootstrap, damage):
    bucket, invoke, s3_call = bootstrap
    name = bucket()
    assert invoke(name, "init", "--confirm-new-namespace").returncode == 0
    if damage.startswith("missing"):
        key = "head.json" if damage == "missing-head" else "namespace.json"
        s3_call("delete_object", Bucket=name, Key=key)
    else:
        s3_call("put_object", Bucket=name, Key="head.json", Body="broken")
    before = s3_call("list_objects_v2", Bucket=name)["Contents"]
    for command in [("init", "--confirm-new-namespace"), ("checkpoint",)]:
        failed = invoke(name, *command)
        assert failed.returncode == 1
        assert failed.stdout == ""
        assert failed.stderr == (
            "Image deletion operation failed; no successful completion is confirmed\n"
        )
    assert s3_call("list_objects_v2", Bucket=name)["Contents"] == before


def test_missing_checkpoint_does_not_initialize(bootstrap):
    bucket, invoke, s3_call = bootstrap
    name = bucket()
    assert invoke(name, "checkpoint").returncode == 1
    assert s3_call("list_objects_v2", Bucket=name)["KeyCount"] == 0


def test_access_denied_does_not_initialize_or_expose_secrets(bootstrap):
    bucket, invoke, s3_call = bootstrap
    name = bucket()
    policy = {"Version": "2012-10-17", "Statement": [{
        "Effect": "Deny", "Principal": "*", "Action": ["s3:GetObject", "s3:PutObject"],
        "Resource": f"arn:aws:s3:::{name}/*",
    }]}
    s3_call("put_bucket_policy", Bucket=name, Policy=json.dumps(policy))
    result = invoke(name, "init", "--confirm-new-namespace")
    assert result.returncode == 1
    assert result.stdout == ""
    assert "synthetic-secret-not-for-logs" not in result.stderr
    assert s3_call("list_objects_v2", Bucket=name)["KeyCount"] == 0


@pytest.mark.parametrize("overrides", [
    {"DELETION_LEDGER_S3_SECRET_ACCESS_KEY": ""},
    {"DELETION_LEDGER_S3_ENDPOINT_URL": "https://127.0.0.1:1"},
    {"DELETION_LEDGER_S3_ENDPOINT_URL": "http://127.0.0.1:1"},
])
def test_invalid_configuration_or_connection_exits_without_success(bootstrap, overrides):
    bucket, invoke, _ = bootstrap
    result = invoke(bucket(), "init", "--confirm-new-namespace", overrides=overrides)
    assert result.returncode == 1
    assert result.stdout == ""
    assert result.stderr == (
        "Image deletion operation failed; no successful completion is confirmed\n"
    )


def test_ledger_commands_ignore_unrelated_api_settings_but_retry_requires_them(bootstrap):
    bucket, invoke, _ = bootstrap
    name = bucket()
    invalid_api = {"DATABASE_URL": "not-a-db-url", "YOUTUBE_SUMMARY_ENABLED": "invalid-bool"}
    result = invoke(name, "init", "--confirm-new-namespace", overrides=invalid_api)
    assert result.returncode == 0, result.stderr
    assert invoke(name, "checkpoint", overrides=invalid_api).returncode == 0
    retry = invoke(name, "retry", "--limit", "1")
    assert retry.returncode == 1
    assert retry.stdout == ""
    assert retry.stderr == (
        "Image deletion operation failed; no successful completion is confirmed\n"
    )


def test_operator_default_entrypoint_remains_backup_jobs():
    image = os.environ.get("CLIPBACK_LEDGER_OPERATOR_IMAGE", "clipback-ledger-operator:check")
    result = subprocess.run(
        ["docker", "run", "--rm", "--network", "none", "-e", "APP_ENVIRONMENT=test",
         image, "--help"], capture_output=True, text=True, timeout=30,
    )
    assert result.returncode == 0, result.stderr
    assert "daily" in result.stdout and "maintain" in result.stdout
    assert "restore-check" in result.stdout
