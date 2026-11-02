"""Operator output of the read-only recovery point audit and its documented command (#177).

The audit runs in-process through its real `main()` against the moto Bucket of the Bucket output
tests. Every run refuses S3 requests other than the allowed reads. The expected values keep what
the audit printed while it was a code block in the operations document; only the exit code, a
receipt read failure that is not a CheckError, and the top-level error JSON were added in #177.
"""

import json
import os
import re
import runpy
import shlex
import subprocess
import sys
from datetime import UTC, datetime, timedelta
from pathlib import Path

import boto3
import pytest
from botocore.exceptions import ClientError, ReadTimeoutError

from tests.deployment.test_recovery_point_bucket_outputs import (
    BUCKET,
    BUCKET_BYTES,
    EXPIRED,
    FRESH,
    HEALTHY_ASSETS,
    LOCAL_BYTES,
    asset,
    bucket as bucket,
    canonical,
    manifest,
)

READS = {"ListObjectsV2", "GetObject", "HeadObject"}
ROOT = Path(__file__).resolve().parents[3]
DOC = ROOT / "docs/backend/backup-recovery.md"
SECTION = "### `maintain`이 `invalid_manifest`로 멈췄을 때"
PLACEHOLDER = "/absolute/private/backup-bucket.json"
ENDPOINT = "http://127.0.0.1:9000"
CHECKED_AT = re.compile(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\+00:00\Z")
DUMP_KEY = "points/target/database.dump"
EARLY, RETIRED = "gc/points/early.json", "gc/points/retired.json"


def refuse_writes(client):
    """Fail any S3 request other than the allowed reads; returns the refused operation names."""
    refused = []

    def refuse(model, **kwargs):
        if model.name not in READS:
            refused.append(model.name)
            raise AssertionError(f"audit sent {model.name}")

    client.meta.events.register("before-call.s3", refuse)
    return refused


def report_of(code, out):
    assert BUCKET not in out
    report = json.loads(out)
    if "checked_at" in report:
        assert CHECKED_AT.fullmatch(report["checked_at"])
        report["checked_at"] = "<checked_at>"
    return code, report


def audit(bucket, monkeypatch, capsys, *args):
    from scripts.recovery_point_audit import main

    refused = refuse_writes(bucket.client)
    monkeypatch.setattr(sys, "argv", ["recovery_point_audit", *args])
    code = main()
    assert refused == []
    return report_of(code, capsys.readouterr().out)


def outside():
    """A client the write guard does not watch, for damage done while the audit runs."""
    return boto3.client("s3", region_name="us-east-1")


def deny(bucket, operation, **match):
    def handler(params, **kwargs):
        if all(params.get(name) == value for name, value in match.items()):
            raise ClientError({"Error": {"Code": "AccessDenied", "Message": "denied"}}, operation)

    bucket.client.meta.events.register(f"before-parameter-build.s3.{operation}", handler)


def remove_when_read(bucket, key):
    def handler(params, **kwargs):
        if params.get("Key") == key:
            outside().delete_object(Bucket=BUCKET, Key=key)

    bucket.client.meta.events.register("before-parameter-build.s3.GetObject", handler)


class InterruptedBody:
    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False

    def read(self, *args):
        raise ReadTimeoutError(endpoint_url=ENDPOINT)


def interrupt_body(bucket, key):
    requested = []

    def remember(params, **kwargs):
        requested.append(params.get("Key"))

    def interrupt(parsed, **kwargs):
        if requested[-1] == key:
            parsed["Body"] = InterruptedBody()

    bucket.client.meta.events.register("before-parameter-build.s3.GetObject", remember)
    bucket.client.meta.events.register("after-call.s3.GetObject", interrupt)


def points_and_receipt(bucket, assets=HEALTHY_ASSETS):
    """Fresh anchor and target points plus one valid cleanup receipt of an expired point."""
    now = datetime.now(UTC)
    bucket.point("anchor", manifest("anchor", (now - timedelta(hours=1)).isoformat()))
    bucket.point("target", manifest("target", (now - FRESH).isoformat(), assets))
    bucket.point("retired", manifest("retired", (now - EXPIRED).isoformat()), receipt=True)


def early_receipt(bucket, **changes):
    value = {**manifest("early", (datetime.now(UTC) - EXPIRED).isoformat()), **changes}
    bucket.put(EARLY, canonical(value))


def contract_violation(bucket):
    bucket.put("points/target/manifest.json", canonical(
        {**manifest("target", (datetime.now(UTC) - FRESH).isoformat()), "app_commit": "abc"}
    ))


def receipt_conflict(bucket):
    value = json.loads(bucket.client.get_object(
        Bucket=BUCKET, Key="points/target/manifest.json")["Body"].read())
    bucket.put("gc/points/target.json", canonical({**value, "app_commit": "b" * 40}))


DAMAGES = {
    "healthy": lambda bucket: None,
    "contract_violation": contract_violation,
    "dump_missing": lambda bucket: bucket.delete(DUMP_KEY),
    "dump_denied": lambda bucket: (deny(bucket, "GetObject", Key=DUMP_KEY),
                                   deny(bucket, "HeadObject", Key=DUMP_KEY)),
    "receipt_bad_name": lambda bucket: bucket.put("gc/points/bad id.json", b"{}"),
    "receipt_denied": lambda bucket: (early_receipt(bucket),
                                      deny(bucket, "GetObject", Key=EARLY)),
    "receipt_removed": lambda bucket: (early_receipt(bucket), remove_when_read(bucket, EARLY)),
    "receipt_body_interrupted": lambda bucket: (early_receipt(bucket),
                                                interrupt_body(bucket, EARLY)),
    "receipt_conflict": receipt_conflict,
    "receipt_v1": lambda bucket: early_receipt(bucket, format_version=1),
    "point_list_denied": lambda bucket: deny(bucket, "ListObjectsV2", Prefix="points/"),
    "receipt_list_denied": lambda bucket: deny(bucket, "ListObjectsV2", Prefix="gc/points/"),
}


def report(points=None, receipts=None):
    points = {"anchor": "passed", "target": "passed", **(points or {})}
    receipts = {RETIRED: "passed", **(receipts or {})}
    passed = all(value == "passed" for value in [*points.values(), *receipts.values()])
    return (0 if passed else 1), {
        "checked_at": "<checked_at>", "passed": passed, "points": points, "receipts": receipts,
    }


def failure(error):
    return 1, {"error": error, "passed": False}


# Missing and unreadable objects keep their exception names until #179.
OUTPUTS = {
    "healthy": report(),
    "contract_violation": report(points={"target": "invalid_manifest"}),
    "dump_missing": report(points={"target": "NoSuchKey"}),
    "dump_denied": report(points={"target": "ClientError"}),
    "receipt_bad_name": report(receipts={"gc/points/bad id.json": "invalid_gc_receipt",
                                         RETIRED: "not_checked"}),
    "receipt_denied": report(receipts={EARLY: "backup_store_unavailable",
                                       RETIRED: "not_checked"}),
    "receipt_removed": report(receipts={EARLY: "FileNotFoundError", RETIRED: "not_checked"}),
    "receipt_body_interrupted": report(receipts={EARLY: "ReadTimeoutError",
                                                 RETIRED: "not_checked"}),
    "receipt_conflict": report(receipts={"gc/points/target.json": "gc_receipt_conflict"}),
    "receipt_v1": report(receipts={EARLY: "retention_requires_v2"}),
    "point_list_denied": failure("ClientError"),
    "receipt_list_denied": failure("ClientError"),
}


@pytest.mark.parametrize("damage", DAMAGES)
def test_audit_outputs(damage, bucket, monkeypatch, capsys):
    points_and_receipt(bucket)
    DAMAGES[damage](bucket)
    assert audit(bucket, monkeypatch, capsys) == OUTPUTS[damage]


UNNORMALIZED_KEYS = ["u/./1.png", "./u/1.png", "u//1.png", "u/1.png/", "."]


@pytest.mark.parametrize("backend", ["local", "s3"])
@pytest.mark.parametrize("storage_key", UNNORMALIZED_KEYS)
def test_audit_passes_an_unnormalized_storage_key(storage_key, backend, bucket, monkeypatch,
                                                   capsys):
    """Still accepted until the storage_key rule of #178."""
    assets = [asset(1, "local", storage_key if backend == "local" else "a.png", LOCAL_BYTES),
              asset(2, "s3", storage_key if backend == "s3" else "u/1.png", BUCKET_BYTES)]
    points_and_receipt(bucket, assets)
    assert audit(bucket, monkeypatch, capsys) == report()


def private_config(path, mode=0o600):
    path.write_text(json.dumps({
        "endpoint_url": ENDPOINT, "bucket": BUCKET, "region": "us-east-1",
        "addressing_style": "path", "access_key_id": "testing", "secret_access_key": "testing",
    }))
    path.chmod(mode)
    return path


def test_audit_reports_a_missing_config_file(bucket, monkeypatch, capsys, tmp_path):
    points_and_receipt(bucket)
    assert audit(bucket, monkeypatch, capsys, "--backup-config-file",
                 str(tmp_path / "missing.json")) == failure("FileNotFoundError")


def test_audit_reports_a_config_file_others_can_read(bucket, monkeypatch, capsys, tmp_path):
    points_and_receipt(bucket)
    config = private_config(tmp_path / "backup-bucket.json", 0o644)
    assert audit(bucket, monkeypatch, capsys, "--backup-config-file",
                 str(config)) == failure("credentials_not_private")


def test_audit_reports_an_unreadable_config_directory(bucket, monkeypatch, capsys, tmp_path):
    points_and_receipt(bucket)
    directory = tmp_path / "private"
    directory.mkdir()
    config = private_config(directory / "backup-bucket.json")
    directory.chmod(0)
    try:
        result = audit(bucket, monkeypatch, capsys, "--backup-config-file", str(config))
    finally:
        directory.chmod(0o700)
    assert result == failure("PermissionError")


def documented_command():
    """(working directory, environment, module, arguments) of the one documented audit command."""
    text = DOC.read_text()
    assert text.count(SECTION) == 1
    section = re.split(r"\n#{1,3} ", text.split(SECTION, 1)[1], maxsplit=1)[0]
    blocks = [block for block in re.findall(r"```\w*\n(.*?)```", section, re.S)
              if " -m " in block]
    assert len(blocks) == 1, "the section must hold exactly one audit command block"
    lines = blocks[0].strip().splitlines()
    assert len(lines) == 2, "the block is `cd <directory>` and one command line"
    cd = shlex.split(lines[0])
    assert len(cd) == 2 and cd[0] == "cd"
    words = shlex.split(lines[1])
    environment = {}
    while re.fullmatch(r"[A-Z_]+=.*", words[0]):
        name, value = words.pop(0).split("=", 1)
        environment[name] = value
    assert len(words) >= 3 and words[1] == "-m"
    module, arguments = words[2], words[3:]
    assert arguments.count(PLACEHOLDER) == 1
    return ROOT / cd[1], environment, module, arguments


def with_config(arguments, config):
    return [str(config) if value == PLACEHOLDER else value for value in arguments]


@pytest.mark.parametrize("damage", ["healthy", "dump_missing"])
def test_documented_command_outputs(damage, bucket, monkeypatch, capsys, tmp_path):
    """The documented argv and environment, with only the config placeholder replaced."""
    from scripts.image_backup import BackupBucket

    directory, environment, module, arguments = documented_command()
    points_and_receipt(bucket)
    DAMAGES[damage](bucket)
    config = private_config(tmp_path / "backup-bucket.json")
    refused = []
    from_config = BackupBucket.from_config.__func__

    def guarded(cls, value):
        store = from_config(cls, value)
        refused.append(refuse_writes(store.client))
        return store

    def no_environment(cls):
        raise AssertionError("the documented command must use its config file")

    monkeypatch.setattr(BackupBucket, "from_config", classmethod(guarded))
    monkeypatch.setattr(BackupBucket, "from_environment", classmethod(no_environment))
    monkeypatch.setenv("MOTO_S3_CUSTOM_ENDPOINTS", ENDPOINT)
    monkeypatch.delenv("BACKUP_BUCKET_CONFIG_JSON", raising=False)
    for name, value in environment.items():
        monkeypatch.setenv(name, value)
    monkeypatch.chdir(directory)
    monkeypatch.delitem(sys.modules, module, raising=False)
    monkeypatch.setattr(sys, "argv", [module, *with_config(arguments, config)])
    with pytest.raises(SystemExit) as exit_:
        runpy.run_module(module, run_name="__main__", alter_sys=True)
    out = capsys.readouterr().out
    assert refused == [[]]
    assert str(config) not in out
    assert report_of(exit_.value.code, out) == OUTPUTS[damage]


def test_documented_command_starts_from_the_documented_directory(tmp_path):
    """The real `python -m` entry from the documented directory, without the moto Bucket."""
    directory, environment, module, arguments = documented_command()
    missing = tmp_path / "missing.json"
    result = subprocess.run(
        [sys.executable, "-m", module, *with_config(arguments, missing)],
        cwd=directory,
        env={name: value for name, value in os.environ.items()
             if name != "BACKUP_BUCKET_CONFIG_JSON"} | environment,
        capture_output=True,
        text=True,
        timeout=60,
    )
    assert (result.returncode, json.loads(result.stdout or "null")) == failure("FileNotFoundError")
