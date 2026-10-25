"""A built operator creates a PG18 point without changing pending cleanup or retention."""

import hashlib
import json
import os
import subprocess
from uuid import uuid4

import pytest

pytestmark = pytest.mark.skipif(
    os.environ.get("RUN_DOCKER_RECOVERY_TESTS") != "1",
    reason="RUN_DOCKER_RECOVERY_TESTS=1 and built operator image required",
)


def test_synthetic_manual_backup_uses_minimal_settings_and_preserves_other_work(tmp_path):
    identifier = "backup98-" + uuid4().hex[:12]
    network, db, s3 = [identifier + x for x in ("-net", "-db", "-s3")]
    image = os.environ.get("CLIPBACK_OPERATOR_TEST_IMAGE", "clipback-operator:ticket98")
    containers = []

    def docker(*args, check=True):
        return subprocess.run(["docker", *args], check=check, capture_output=True, text=True)

    def run(*args):
        name = identifier + "-job-" + str(len(containers))
        containers.append(name)
        return docker("run", "--name", name, *args, check=False)

    originals = tmp_path / "originals"
    originals.mkdir()
    (originals / "original.png").write_bytes(b"original98")
    (originals / "pending.png").write_bytes(b"pending cleanup remains")
    ledger = tmp_path / "ledger"
    ledger.mkdir()
    config = tmp_path / "backup.json"
    config.write_text(json.dumps({"endpoint_url": "http://127.0.0.1:5000", "bucket": "backups",
                                  "access_key_id": "testing", "secret_access_key": "testing",
                                  "region": "us-east-1", "addressing_style": "path"}))
    config.chmod(0o600)
    environment = {
        "DATABASE_URL": f"postgresql+asyncpg://postgres:fixture@{db}:5432/clipback",
        "STORAGE_ROOT": "/originals", "STORAGE_BACKEND": "local",
        "DELETION_LEDGER_BACKEND": "local", "DELETION_LEDGER_ROOT": "/ledger",
        # Synthetic direct local fixtures need no API authentication/provider configuration.
        "APP_ENVIRONMENT": "test",
    }
    env = [arg for key, val in environment.items() for arg in ("-e", f"{key}={val}")]
    args = ["--network", f"container:{s3}", "-v", f"{originals}:/originals:ro",
            "-v", f"{ledger}:/ledger", "-v", f"{config}:/backup.json:ro", *env]
    try:
        docker("network", "create", network)
        for name, command in (
            (db, ["-e", "POSTGRES_PASSWORD=fixture", "-e", "POSTGRES_DB=clipback", "postgres:18"]),
            (s3, ["motoserver/moto:5.2.4"]),
        ):
            containers.append(name)
            docker("run", "-d", "--name", name, "--network", network, *command)
        import time
        for _ in range(300):
            if docker("exec", db, "psql", "-U", "postgres", "-d", "clipback", "-Atc",
                      "SELECT 1", check=False).returncode == 0:
                time.sleep(1)
                break
            time.sleep(0.1)
        seed = """
CREATE TABLE alembic_version(version_num text); INSERT INTO alembic_version VALUES('fixture98');
CREATE TABLE users(id int); INSERT INTO users VALUES(1);
CREATE TABLE contents(id int, content_type text, source text, title text, summary text,
 original_url text, is_favorite bool, saved_at timestamptz, last_viewed_at timestamptz);
INSERT INTO contents VALUES(1,'screenshot','screenshot','fixture','summary',NULL,false,
 '2026-10-26T00:00:00Z',NULL);
CREATE TABLE content_assets(id int, content_id int, storage_key text, storage_backend text,
 size_bytes bigint, sha256 text);
INSERT INTO content_assets VALUES(1,1,'original.png','local',10,'DIGEST');
CREATE TABLE content_categories(content_id int, category_id int);
CREATE TABLE image_deletions(operation_id text, completed bool, attempts int);
INSERT INTO image_deletions VALUES('pending98',false,0);
""".replace("DIGEST", hashlib.sha256(b"original98").hexdigest())
        from tests.support.maintenance import control_schema_sql
        docker("exec", db, "psql", "-U", "postgres", "-d", "clipback", "-v", "ON_ERROR_STOP=1",
               "-c", seed + control_schema_sql())
        setup = run(*args, "--entrypoint", "python", image, "-c",
                    "import boto3,time; from app.integrations.deletion_ledger import "
                    "get_deletion_ledger; from app.core.deletion_ledger_config import "
                    "DeletionLedgerSettings; "
                    "s=boto3.client('s3',endpoint_url='http://127.0.0.1:5000',"
                    "aws_access_key_id='testing',aws_secret_access_key='testing',region_name='us-east-1');"
                    "s.create_bucket(Bucket='backups');"
                    "s.put_object(Bucket='backups',Key='points/old/manifest.json',"
                    "Body=b'old point');"
                    "s.put_object(Bucket='backups',Key='originals/unreferenced',Body=b'keep');"
                    "get_deletion_ledger(DeletionLedgerSettings()).initialize()")
        assert setup.returncode == 0, setup.stdout + setup.stderr
        command = [image, "manual", "--backup-config-file", "/backup.json", "--backup-id", "first",
                   "--app-commit", "a" * 40, "--origin", "synthetic"]
        result = run(*args, *command)
        assert result.returncode == 0, result.stdout + result.stderr
        report = json.loads(result.stdout)
        assert report["passed"] and report["backup_id"] == "first"
        assert report["asset_count"] == 1 and report["restore_verified"] is False
        verify = run(*args, "--entrypoint", "python", image, "-c",
                     "from scripts.image_backup import BackupBucket;from pathlib import Path;"
                     "s=BackupBucket.from_config_file(Path('/backup.json'));"
                     "assert s.read('points/old/manifest.json')==b'old point';"
                     "assert s.read('originals/unreferenced')==b'keep';"
                     "m=s.read_manifest('first');assert m['postgres_major']==18;"
                     "assert m['tables']['image_deletions']==1;"
                     "assert s.read(m['assets'][0]['backup_key'])==b'original98';"
                     "assert len(s.read('points/first/database.dump'))>0")
        assert verify.returncode == 0, verify.stdout + verify.stderr
        assert (originals / "pending.png").read_bytes() == b"pending cleanup remains"
        status = docker("exec", db, "psql", "-U", "postgres", "-d", "clipback", "-Atc",
                        "SELECT completed,attempts FROM image_deletions")
        assert status.stdout.strip() == "f|0"
        (originals / "original.png").write_bytes(b"changed original")
        rejected = run(*args, image, "manual", "--backup-config-file", "/backup.json",
                       "--backup-id", "bad-hash", "--app-commit", "a" * 40,
                       "--origin", "synthetic")
        assert rejected.returncode == 1
        assert json.loads(rejected.stdout) == {"passed": False, "error": "original_hash_mismatch"}
        (originals / "original.png").unlink()
        missing = run(*args, image, "manual", "--backup-config-file", "/backup.json",
                      "--backup-id", "missing", "--app-commit", "a" * 40,
                      "--origin", "synthetic")
        assert missing.returncode == 1
        assert json.loads(missing.stdout) == {"passed": False, "error": "original_missing"}
        (originals / "original.png").write_bytes(b"original98")
        partial = run(*args, image, "manual", "--backup-config-file", "/backup.json",
                      "--backup-id", "partial", "--app-commit", "a" * 40,
                      "--origin", "synthetic", "--pg-dump", "/missing-pg-dump")
        assert partial.returncode == 1
        assert json.loads(partial.stdout) == {"passed": False, "error": "database_dump_failed"}
        invalid = run(*args, "-e", "DATABASE_URL=", image, "manual",
                      "--backup-config-file", "/backup.json", "--backup-id", "invalid-config",
                      "--app-commit", "a" * 40, "--origin", "synthetic")
        assert invalid.returncode == 1
        assert json.loads(invalid.stdout) == {
            "passed": False, "error": "operator_configuration_invalid"
        }
        final = run(*args, "--entrypoint", "python", image, "-c",
                    "from scripts.image_backup import BackupBucket;from pathlib import Path;"
                    "s=BackupBucket.from_config_file(Path('/backup.json'));"
                    "assert s.completed_points()==['first','old']")
        assert final.returncode == 0, final.stdout + final.stderr
        sample = tmp_path / "legacy-sample.json"
        sample.write_text(json.dumps({"content_id": 1, "asset_id": 1}))
        sample.chmod(0o600)
        legacy = run(*args, "-v", f"{sample}:/sample.json:ro", "--entrypoint", "python",
                     "-e", "APP_ENVIRONMENT=production", "-e", "STORAGE_BACKEND=s3",
                     "-e", "S3_ENDPOINT_URL=https://unused.invalid", "-e", "S3_BUCKET=primary",
                     "-e", "S3_ACCESS_KEY_ID=testing", "-e", "S3_SECRET_ACCESS_KEY=testing",
                     "-e", "DELETION_LEDGER_BACKEND=s3",
                     "-e", "DELETION_LEDGER_S3_ENDPOINT_URL=https://unused-ledger.invalid",
                     "-e", "DELETION_LEDGER_S3_BUCKET=independent-ledger",
                     "-e", "DELETION_LEDGER_S3_ACCESS_KEY_ID=testing",
                     "-e", "DELETION_LEDGER_S3_SECRET_ACCESS_KEY=testing", image,
                     "-m", "scripts.image_backup", "--backup-config-file", "/backup.json", "create",
                     "--backup-id", "unidentified-legacy", "--sample-file", "/sample.json",
                     "--app-commit", "a" * 40, "--origin", "production", "--writers-frozen")
        assert legacy.returncode == 1, (
            "Bucket mode must not read unidentified legacy local originals"
        )
        assert json.loads(legacy.stdout) == {"passed": False, "error": "original_read_failed"}
        docker("exec", db, "psql", "-U", "postgres", "-d", "clipback", "-c",
               "DELETE FROM content_assets")
        unidentified = run(*args, "-e", "APP_ENVIRONMENT=production",
                           "-e", "STORAGE_ROOT=/unmounted-empty-source", image, "manual",
                           "--backup-config-file", "/backup.json", "--backup-id", "unidentified",
                           "--app-commit", "a" * 40, "--origin", "production")
        assert unidentified.returncode == 1, (
            "Production empty backups still require source identity"
        )
        assert json.loads(unidentified.stdout) == {
            "passed": False, "error": "operator_configuration_invalid"
        }
    finally:
        for name in reversed(containers):
            docker("rm", "-f", "-v", name, check=False)
        docker("network", "rm", network, check=False)
