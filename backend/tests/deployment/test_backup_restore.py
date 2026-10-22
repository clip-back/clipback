import copy
import hashlib
import io
import json
import subprocess
import tarfile
from datetime import UTC, datetime

import pytest

from scripts.check_backup_restore import (
    CheckError,
    Docker,
    RestoreDrill,
    check,
    load_backup,
    private_json,
    sha256_file,
    validate_archive,
)


def archive_file(path, entries):
    with tarfile.open(path, "w") as archive:
        for name, kind, content in entries:
            member = tarfile.TarInfo(name)
            member.type = kind
            member.size = len(content) if kind == tarfile.REGTYPE else 0
            if kind in (tarfile.SYMTYPE, tarfile.LNKTYPE):
                member.linkname = "/outside"
            archive.addfile(member, io.BytesIO(content) if member.isfile() else None)


@pytest.fixture
def backup(tmp_path):
    image = b"synthetic-image"
    (tmp_path / "database.dump").write_bytes(b"synthetic-dump")
    archive_file(tmp_path / "images.tar", [("screenshots/a.png", tarfile.REGTYPE, image)])
    manifest = {
        "format_version": 1,
        "backup_id": "synthetic-check",
        "origin": "synthetic",
        "captured_at": datetime.now(UTC).isoformat(),
        "app_commit": "a" * 40,
        "postgres_major": 16,
        "migration_revisions": ["revision"],
        "tables": {"users": 2},
        "category_links_sha256": "c" * 64,
        "assets": [
            {
                "id": 1,
                "storage_key": "a.png",
                "size_bytes": len(image),
                "sha256": hashlib.sha256(image).hexdigest(),
            }
        ],
        "sample": {
            "content_id": 1,
            "asset_id": 1,
            "saved_at": datetime.now(UTC).isoformat(),
            "category_ids": [1],
            "content_sha256": "d" * 64,
        },
    }
    for name, filename in (("database", "database.dump"), ("images", "images.tar")):
        path = tmp_path / filename
        manifest[name] = {
            "file": filename,
            "size_bytes": path.stat().st_size,
            "sha256": sha256_file(path),
        }
    (tmp_path / "manifest.json").write_text(json.dumps(manifest))
    credential_file = tmp_path / "credentials.json"
    credential_file.write_text(
        json.dumps({"secret_key": "private-key", "access_token": "private-token"})
    )
    credential_file.chmod(0o600)
    return tmp_path, manifest, credential_file


def test_valid_backup_and_private_credentials(backup):
    directory, manifest, credentials = backup
    actual, paths = load_backup(directory)
    assert actual == manifest
    assert paths["database"] == directory / "database.dump"
    assert private_json(credentials)["secret_key"] == "private-key"


@pytest.mark.parametrize("role", ["database", "images"])
def test_corrupt_or_truncated_backup_rejected_before_docker(backup, role):
    directory, manifest, credentials = backup
    (directory / manifest[role]["file"]).write_bytes(b"damaged")
    calls = []
    drill = RestoreDrill(lambda *args, **kwargs: calls.append(args))
    report = check(directory, credentials, "unused", drill)
    assert report["passed"] is False
    assert report["error"] == "backup_hash_mismatch"
    assert calls == []


@pytest.mark.parametrize(
    "name,kind",
    [
        ("../escape", tarfile.REGTYPE),
        ("/absolute", tarfile.REGTYPE),
        ("a/../../escape", tarfile.REGTYPE),
        ("a\\escape", tarfile.REGTYPE),
        ("link", tarfile.SYMTYPE),
        ("hardlink", tarfile.LNKTYPE),
        ("fifo", tarfile.FIFOTYPE),
        ("device", tarfile.CHRTYPE),
    ],
)
def test_unsafe_archive_is_rejected(tmp_path, name, kind):
    path = tmp_path / "unsafe.tar"
    archive_file(path, [(name, kind, b"data")])
    with pytest.raises(CheckError, match="unsafe_archive"):
        validate_archive(path)


@pytest.mark.parametrize("names", [["a", "a"], ["a", "a/b"], ["a/b", "a"]])
def test_duplicate_and_file_directory_archive_collisions(tmp_path, names):
    path = tmp_path / "unsafe.tar"
    archive_file(path, [(name, tarfile.REGTYPE, b"data") for name in names])
    with pytest.raises(CheckError, match="unsafe_archive"):
        validate_archive(path)


def test_root_directory_and_nested_files_allowed(tmp_path):
    path = tmp_path / "safe.tar"
    archive_file(
        path,
        [
            (".", tarfile.DIRTYPE, b""),
            ("./screenshots", tarfile.DIRTYPE, b""),
            ("./screenshots/a.png", tarfile.REGTYPE, b"image"),
        ],
    )
    assert validate_archive(path) == ({"screenshots/a.png"}, 5)


def test_missing_image_is_not_a_successful_restore(backup):
    directory, manifest, _ = backup
    manifest["assets"][0]["storage_key"] = "missing.png"
    (directory / "manifest.json").write_text(json.dumps(manifest))
    with pytest.raises(CheckError, match="missing_asset"):
        load_backup(directory)


@pytest.mark.parametrize("mode", [0o644, 0o666, 0o400])
def test_credentials_require_private_mode(backup, mode):
    _, _, credentials = backup
    credentials.chmod(mode)
    with pytest.raises(CheckError, match="credentials_not_private"):
        private_json(credentials)


def test_credential_symlink_and_newline_injection_rejected(backup):
    directory, _, credentials = backup
    link = directory / "link.json"
    link.symlink_to(credentials)
    with pytest.raises(CheckError, match="credentials_not_private"):
        private_json(link)
    credentials.write_text(
        json.dumps({"secret_key": "secret\nDATABASE_URL=elsewhere", "access_token": "token"})
    )
    with pytest.raises(CheckError, match="invalid_credentials"):
        private_json(credentials)


def test_input_backup_symlink_rejected(backup):
    directory, _, _ = backup
    data = directory / "database.dump"
    original = directory / "original.dump"
    data.rename(original)
    data.symlink_to(original)
    with pytest.raises(CheckError, match="invalid_backup_file"):
        load_backup(directory)


class FakeDrill:
    def __init__(self, *, error=None, clean=True):
        self.error, self.clean, self.cleaned = error, clean, False

    def run(self, *args):
        if self.error:
            raise self.error
        return {"table_count": 2, "asset_count": 1}

    def cleanup(self):
        self.cleaned = True
        return self.clean


@pytest.mark.parametrize(
    "error", [None, CheckError("restored_data_mismatch"), ValueError("SECRET KEY private-token")]
)
def test_cleanup_and_redacted_report_on_every_outcome(backup, error):
    directory, _, credentials = backup
    drill = FakeDrill(error=error)
    before = {p.name: sha256_file(p) for p in directory.iterdir()}
    report = check(directory, credentials, "unused", drill)
    assert drill.cleaned
    assert report["passed"] is (error is None)
    assert "private-token" not in json.dumps(report)
    assert "private-key" not in json.dumps(report)
    assert before == {p.name: sha256_file(p) for p in directory.iterdir()}


def test_cleanup_failure_does_not_report_success(backup):
    directory, _, credentials = backup
    assert check(directory, credentials, "unused", FakeDrill(clean=False))["passed"] is False


def test_existing_or_unowned_resource_is_never_removed():
    calls = []

    def docker(*args, **kwargs):
        calls.append(args)
        return json.dumps([{"Labels": {"clipback.recovery.owner": "another-run"}}]).encode()

    drill = RestoreDrill(docker)
    drill.created = [("volume", "existing-volume")]
    assert drill.cleanup() is False
    assert calls == [("volume", "inspect", "existing-volume")]


def test_failed_creation_is_not_adopted_or_deleted():
    calls = []

    def docker(*args, **kwargs):
        calls.append(args)
        raise CheckError("docker_command_failed")

    drill = RestoreDrill(docker)
    with pytest.raises(CheckError):
        drill.create("volume", "existing-volume")
    assert drill.created == []
    assert drill.cleanup() is True
    assert len(calls) == 1


def test_docker_exception_never_exposes_stderr(monkeypatch):
    def fail(*args, **kwargs):
        raise subprocess.CalledProcessError(1, args[0], stderr=b"private-token")

    monkeypatch.setattr(subprocess, "run", fail)
    with pytest.raises(CheckError) as error:
        Docker()("info")
    assert str(error.value) == "docker_command_failed"


def test_remote_docker_is_rejected_before_any_call(backup, monkeypatch):
    directory, manifest, credentials = backup
    _, paths = load_backup(directory)
    monkeypatch.setenv("DOCKER_HOST", "tcp://remote:2375")
    calls = []
    with pytest.raises(CheckError, match="docker_must_be_local"):
        RestoreDrill(lambda *args: calls.append(args)).run(
            manifest, paths, private_json(credentials), "app:image"
        )
    assert calls == []


@pytest.mark.parametrize(
    "change",
    [
        {"postgres_major": "16"},
        {"postgres_major": True},
        {"app_commit": "main"},
        {"captured_at": "2026-10-22T10:00:00"},
        {"origin": "unknown"},
        {"tables": {"users": -1}},
        {"migration_revisions": []},
        {"secret_key": "must-not-be-in-a-manifest"},
    ],
)
def test_invalid_manifest_fields(backup, change):
    directory, manifest, _ = backup
    manifest = copy.deepcopy(manifest)
    manifest.update(change)
    (directory / "manifest.json").write_text(json.dumps(manifest))
    with pytest.raises(CheckError, match="invalid_manifest"):
        load_backup(directory)
