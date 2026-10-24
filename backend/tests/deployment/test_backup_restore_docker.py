"""Opt-in real Docker drill using synthetic data, never an application database."""

import io
import json
import os
import subprocess
from datetime import UTC, datetime
from pathlib import Path

import pytest

from scripts.check_backup_restore import PROBE, RestoreDrill, check, sha256_file

pytestmark = pytest.mark.skipif(
    os.environ.get("RUN_DOCKER_RECOVERY_TESTS") != "1",
    reason="RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are required",
)


def execute(drill, container, code, payload=None):
    stream = io.BytesIO(json.dumps(payload or {}).encode())
    # subprocess requires a real file descriptor, not BytesIO.
    import tempfile

    with tempfile.TemporaryFile() as actual:
        actual.write(stream.getvalue())
        actual.seek(0)
        return json.loads(drill.docker("exec", "-i", container, "python", "-c", code, stdin=actual))


@pytest.fixture(scope="module", params=[16, 18])
def real_backup(tmp_path_factory, request):
    directory = tmp_path_factory.mktemp("synthetic-backup")
    image = os.environ.get("CLIPBACK_RECOVERY_TEST_IMAGE", "clipback-backup-recovery:check")
    drill = RestoreDrill()
    network, db, api, pg, files = [
        drill.owner + suffix for suffix in ("-net", "-db", "-api", "-pg", "-files")
    ]
    secret = "synthetic-recovery-fixture-secret"
    major = request.param
    mount = "/var/lib/postgresql" if major >= 18 else "/var/lib/postgresql/data"
    environment = [
        "APP_ENVIRONMENT=production",
        "YOUTUBE_SUMMARY_ENABLED=false",
        f"SECRET_KEY={secret}",
        "OPENAI_API_KEY=unused-fixture-key",
        'GOOGLE_CLIENT_IDS=["unused-fixture-id"]',
        "KAKAO_REST_API_KEY=unused-fixture-key",
        "STORAGE_ROOT=/data/screenshots",
        "PORT=8123",
        "BACKEND_CORS_ORIGINS=[]",
        f"DATABASE_URL=postgresql://postgres:fixture@{db}:5432/clipback",
    ]
    env_args = [arg for value in environment for arg in ("-e", value)]
    try:
        drill.create("network", network, "--internal")
        drill.create("volume", pg)
        drill.create("volume", files)
        drill.container(
            db,
            "--network",
            network,
            "-e",
            "POSTGRES_PASSWORD=fixture",
            "-e",
            "POSTGRES_DB=clipback",
            "-v",
            f"{pg}:{mount}",
            f"postgres:{major}",
        )
        drill.docker("start", db)
        drill.wait("exec", db, "pg_isready", "-U", "postgres", "-d", "clipback")
        migrate = drill.owner + "-migrate"
        drill.container(
            migrate, "--network", network, *env_args, image, "alembic", "upgrade", "head"
        )
        drill.docker("start", "-a", migrate)
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
        seed = Path(__file__).with_name("probe.py").read_text()
        # Existing probe's seed returns credentials privately; its one-user assertion is not reused.
        code = (
            seed.split('if __name__ == "__main__":')[0] + "\nprint(json.dumps(asyncio.run(seed())))"
        )
        state = execute(drill, api, code)
        execute(
            drill,
            api,
            "import json,urllib.request; "
            "r=urllib.request.Request('http://127.0.0.1:8123/api/v1/auth/guest', "
            "data=b'{}',headers={'Content-Type':'application/json'}); "
            "urllib.request.urlopen(r).read(); "
            "from pathlib import Path; "
            "Path('/data/screenshots/unreferenced.txt').write_text('preserve me'); "
            "print('{}')",
        )
        payload = {
            "sample": {key: state[key] for key in ("content_id", "asset_id")},
            "access_token": state["token"],
        }
        snapshot = execute(drill, api, PROBE, payload)
        assert snapshot["tables"]["users"] == 2
        assert snapshot["extra_file_count"] == 1
        # The authenticated image GET also records anonymous transfer telemetry.
        # Capture the final source state after that verification, before dumping;
        # otherwise the manifest counts precede a write contained in the dump.
        snapshot = execute(drill, api, PROBE, {**payload, "verify_api": False})
        # Worker is disabled and the only producer is now stopped: a consistent paired set.
        drill.docker("stop", api)
        dump = directory / "database.dump"
        dump.write_bytes(drill.docker("exec", db, "pg_dump", "-U", "postgres", "-Fc", "clipback"))
        pack = drill.owner + "-pack"
        drill.container(
            pack,
            "--network",
            "none",
            "-v",
            f"{files}:/data:ro",
            image,
            "tar",
            "-C",
            "/data",
            "-cf",
            "-",
            ".",
        )
        archive = directory / "images.tar"
        archive.write_bytes(drill.docker("start", "-a", pack))
        metadata = json.loads(drill.docker("image", "inspect", image))[0]
        manifest = {
            "format_version": 1,
            "backup_id": "synthetic-docker-drill",
            "origin": "synthetic",
            "captured_at": datetime.now(UTC).isoformat(),
            "app_commit": metadata["Config"]["Labels"]["org.opencontainers.image.revision"],
            "postgres_major": major,
            **snapshot,
        }
        for role, path in (("database", dump), ("images", archive)):
            manifest[role] = {
                "file": path.name,
                "size_bytes": path.stat().st_size,
                "sha256": sha256_file(path),
            }
        (directory / "manifest.json").write_text(json.dumps(manifest))
        credentials = directory / "credentials.json"
        credentials.write_text(json.dumps({"secret_key": secret, "access_token": state["token"]}))
        for path in directory.iterdir():
            path.chmod(0o600)
        yield directory, manifest, credentials, image
    finally:
        assert drill.cleanup(), "Synthetic source cleanup failed"


def test_real_paired_restore_and_authentication(real_backup):
    directory, _, credentials, image = real_backup
    before = {p.name: sha256_file(p) for p in directory.iterdir()}
    report = check(directory, credentials, image)
    assert report["passed"], json.dumps(report)
    assert report["authentication_passed"] and report["image_bytes_passed"]
    assert report["extra_file_count"] == 1
    assert report["cleanup_passed"]
    assert before == {p.name: sha256_file(p) for p in directory.iterdir()}


@pytest.mark.parametrize(
    "failure",
    [
        "damaged_dump",
        "wrong_table_count",
        "wrong_image_hash",
        "wrong_credentials",
        "wrong_revision",
    ],
)
def test_real_failure_leaves_source_intact_and_cleans_resources(real_backup, tmp_path, failure):
    import shutil

    directory, manifest, credentials, image = real_backup
    original = {p.name: sha256_file(p) for p in directory.iterdir()}
    for path in directory.iterdir():
        shutil.copy2(path, tmp_path / path.name)
    manifest = json.loads(json.dumps(manifest))
    if failure == "damaged_dump":
        path = tmp_path / "database.dump"
        path.write_bytes(b"not a postgres dump")
        manifest["database"].update(size_bytes=path.stat().st_size, sha256=sha256_file(path))
    elif failure == "wrong_table_count":
        manifest["tables"]["users"] += 1
    elif failure == "wrong_image_hash":
        manifest["assets"][0]["sha256"] = "0" * 64
    elif failure == "wrong_revision":
        manifest["app_commit"] = "0" * 40
    else:
        value = json.loads(credentials.read_text())
        value["access_token"] = "invalid-private-token"
        (tmp_path / "credentials.json").write_text(json.dumps(value))
    (tmp_path / "manifest.json").write_text(json.dumps(manifest))
    report = check(tmp_path, tmp_path / "credentials.json", image)
    assert report["passed"] is False
    assert report["cleanup_passed"] is True
    assert "invalid-private-token" not in json.dumps(report)
    assert original == {p.name: sha256_file(p) for p in directory.iterdir()}
    # No source container, volume or other pre-existing resource can be named in the tool input.
    result = subprocess.run(
        ["docker", "ps", "--filter", "name=clipback-recovery-", "--format", "{{.Names}}"],
        capture_output=True,
        check=True,
    )
    assert "invalid-private-token" not in result.stdout.decode()
