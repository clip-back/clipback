"""Current operator output for downloaded recovery point folders (#162).

The isolated restore check, `image_backup_jobs restore-check` and `restore_execution prepare` run
in-process through their real `main()`. A fake `docker` on PATH always fails, so a folder whose
manifest passes every pre-Docker check reports `docker_command_failed`. For `restore-check` only
the DB lock and deletion ledger wiring are replaced. Expected values are the outputs measured on
main 06bc24d; the structural migration (#163-#166) must keep them unchanged.
"""

import io
import json
import tarfile
from contextlib import asynccontextmanager
from pathlib import PurePosixPath

import pytest

from tests.deployment.test_recovery_point_bucket_outputs import (
    BUCKET_BYTES,
    CORRUPTIONS as PUBLISHED,
    DUMP,
    LOCAL_BYTES,
    TAR_COLLISIONS,
    asset,
    assign,
    delete,
    digest,
    run,
)

CAPTURED_AT = "2026-11-01T00:00:00+00:00"
HEALTHY_ASSETS = [
    (asset(1, "local", "a.png", LOCAL_BYTES), LOCAL_BYTES),
    (asset(2, "s3", "u/1.png", BUCKET_BYTES), BUCKET_BYTES),
]


def manifest(assets, checkpoint=None):
    return {
        "format_version": 2, "backup_id": "target", "origin": "synthetic",
        "captured_at": CAPTURED_AT, "app_commit": "a" * 40, "postgres_major": 17,
        "migration_revisions": ["202610230015"], "tables": {"content_assets": 2, "users": 1},
        "category_links_sha256": "c" * 64, "assets": [dict(item) for item, _ in assets],
        "sample": {
            "content_id": 1, "asset_id": 1, "saved_at": "2026-10-23T00:00:00+00:00",
            "category_ids": [], "content_sha256": "d" * 64,
        },
        "extra_file_count": 0,
        "database": {
            "file": "database.dump", "backup_key": "points/target/database.dump",
            "size_bytes": len(DUMP), "sha256": digest(DUMP),
        },
        "deletion_checkpoint": checkpoint,
    }


def write_archive(path, assets):
    """Store each normalized tar path once; the first asset with that path (or parent) wins.

    A real download writes every asset and fails on these collisions with `unsafe_archive`.
    This tar instead shows what the folder check does with a safe archive whose manifest
    still names colliding paths.
    """
    added = set()
    with tarfile.open(path, "w") as archive:
        for item, body in assets:
            prefix = "screenshots/" if item.get("storage_backend", "local") == "local" else "s3/"
            name = str(PurePosixPath(prefix + item["storage_key"]))
            if name in added or any(name.startswith(other + "/") for other in added):
                continue
            member = tarfile.TarInfo(name)
            member.size = len(body)
            archive.addfile(member, io.BytesIO(body))
            added.add(name)


def write_folder(directory, assets=HEALTHY_ASSETS, change=None, *, checkpoint=None):
    """A download folder: dump, tar of originals, and the manifest written last."""
    directory.mkdir(mode=0o700)
    (directory / "database.dump").write_bytes(DUMP)
    write_archive(directory / "images.tar", assets)
    archive = (directory / "images.tar").read_bytes()
    value = manifest(assets, checkpoint)
    value["images"] = {"file": "images.tar", "size_bytes": len(archive), "sha256": digest(archive)}
    if isinstance(change, bytes):
        body = change
    else:
        if change is not None:
            change(value)
        body = json.dumps(value, sort_keys=True).encode()
    (directory / "manifest.json").write_bytes(body)
    return directory


@pytest.fixture
def failing_docker(monkeypatch, tmp_path):
    """Every Docker call fails, so passing all manifest checks ends at the first Docker call."""
    bin_directory = tmp_path / "bin"
    bin_directory.mkdir()
    docker = bin_directory / "docker"
    docker.write_text("#!/bin/sh\nexit 1\n")
    docker.chmod(0o755)
    monkeypatch.setenv("PATH", f"{bin_directory}:/usr/bin:/bin")
    monkeypatch.delenv("DOCKER_HOST", raising=False)


@pytest.fixture
def credentials(tmp_path):
    path = tmp_path / "credentials.json"
    path.write_text(json.dumps({"secret_key": "private-key", "access_token": "private-token"}))
    path.chmod(0o600)
    return path


@pytest.fixture
def ledger(monkeypatch, tmp_path):
    """Replace only the DB lock and the live deletion ledger wiring of restore-check."""
    import app.integrations.deletion_ledger as deletion_ledger
    import scripts.image_backup_jobs as jobs

    value = deletion_ledger.DeletionLedger(deletion_ledger.LocalLedgerStore(tmp_path / "ledger"))
    value.initialize()

    @asynccontextmanager
    async def unlocked(*args, **kwargs):
        yield

    monkeypatch.setattr(deletion_ledger, "get_deletion_ledger", lambda config=None: value)
    monkeypatch.setattr(jobs, "source_lock", unlocked)
    return value


def isolated_check(directory, credentials, monkeypatch, capsys):
    from scripts.check_backup_restore import main

    code, report = run(main, ["check_backup_restore", "--backup-dir", str(directory),
                              "--credentials-file", str(credentials), "--image", "app:check"],
                       monkeypatch, capsys)
    assert isinstance(report.pop("elapsed_seconds"), float)
    if "manifest_sha256" in report:
        assert report.pop("manifest_sha256") == digest((directory / "manifest.json").read_bytes())
    return code, report


def restore_check(directory, credentials, monkeypatch, capsys):
    from scripts.image_backup_jobs import main

    code, report = run(main, [
        "image_backup_jobs", "restore-check", "--backup-dir", str(directory),
        "--credentials-file", str(credentials), "--image", "app:check",
        "--synthetic-offline", "--writers-frozen",
    ], monkeypatch, capsys)
    report.pop("elapsed_seconds", None)
    if "manifest_sha256" in report:
        assert report.pop("manifest_sha256") == digest((directory / "manifest.json").read_bytes())
    return code, report


def prepare(directory, credentials, run_root, monkeypatch, capsys):
    """Loopback settings only; the fake Docker stops it before any network or workspace."""
    from scripts.restore_execution import main

    monkeypatch.setenv("DATABASE_URL", "postgresql://user:secret@127.0.0.1:1/clipback")
    monkeypatch.setenv("OPERATOR_CONTROL_URL", "http://127.0.0.1:1")
    monkeypatch.setenv("OPERATOR_CONTROL_KEY", "k" * 32)
    monkeypatch.setenv("DELETION_LEDGER_BACKEND", "local")
    monkeypatch.setenv("DELETION_LEDGER_ROOT", str(run_root.parent / "unused-ledger"))
    result = run(main, [
        "restore_execution", "prepare", "--backup-dir", str(directory),
        "--credentials-file", str(credentials), "--image", "app:check",
        "--run-root", str(run_root),
    ], monkeypatch, capsys)
    assert list(run_root.iterdir()) == []
    return result


def unsafe_member(directory):
    """Append a symlink to the archive and keep the manifest's images entry consistent."""
    with tarfile.open(directory / "images.tar", "a") as archive:
        member = tarfile.TarInfo("link")
        member.type, member.linkname = tarfile.SYMTYPE, "/outside"
        archive.addfile(member)
    archive = (directory / "images.tar").read_bytes()
    value = json.loads((directory / "manifest.json").read_bytes())
    value["images"].update(size_bytes=len(archive), sha256=digest(archive))
    (directory / "manifest.json").write_text(json.dumps(value))


def outputs(directory, credentials, monkeypatch, capsys, tmp_path):
    run_root = tmp_path / "runs"
    run_root.mkdir(mode=0o700)
    return {
        "check": isolated_check(directory, credentials, monkeypatch, capsys),
        "restore-check": restore_check(directory, credentials, monkeypatch, capsys),
        "prepare": prepare(directory, credentials, run_root, monkeypatch, capsys),
    }


GENERIC = "generic"
CLOSED = {"cleanup_passed": True, "live_deletion_ledger_verified": False,
          "maintenance_verified": False, "passed": False}
LOADED = {**CLOSED, "backup_id": "target", "origin": "synthetic"}


def expected(code):
    """Expected outputs when the folder check fails with `code` in every command.

    `docker_command_failed` means the folder passed every manifest and file check.
    `generic` means a non-CheckError escaped, which each CLI maps to its own code.
    """
    if code == GENERIC:
        return {
            "check": (1, {**CLOSED, "error": "invalid_input_or_check_failed"}),
            "restore-check": (1, {"error": "backup_job_failed", "passed": False}),
            "prepare": (1, {"error": "restore_preflight_failed", "passed": False}),
        }
    if code == "docker_command_failed":
        return {
            "check": (1, {**LOADED, "error": code}),
            "restore-check": (1, {**LOADED, "error": code, "synthetic_only": True}),
            "prepare": (1, {"error": code, "passed": False}),
        }
    return {
        "check": (1, {**CLOSED, "error": code}),
        "restore-check": (1, {"error": code, "passed": False}),
        "prepare": (1, {"error": code, "passed": False}),
    }


PASSED, INVALID = "docker_command_failed", "invalid_manifest"
# case: (change from #161's published-manifest table or a folder-specific one, expected code)
CORRUPTIONS = {
    "not_json": (PUBLISHED["not_json"], GENERIC),
    "not_object": (PUBLISHED["not_object"], INVALID),
    "missing_database": (PUBLISHED["missing_database"], GENERIC),
    "missing_assets": (PUBLISHED["missing_assets"], GENERIC),
    "missing_captured_at": (PUBLISHED["missing_captured_at"], GENERIC),
    "missing_postgres_major": (PUBLISHED["missing_postgres_major"], GENERIC),
    "missing_migration_revisions": (PUBLISHED["missing_migration_revisions"], GENERIC),
    "missing_asset_sha256": (PUBLISHED["missing_asset_sha256"], GENERIC),
    "app_commit_not_sha": (PUBLISHED["app_commit_not_sha"], INVALID),
    "origin_unknown": (PUBLISHED["origin_unknown"], INVALID),
    "unknown_field": (PUBLISHED["unknown_field"], INVALID),
    "missing_images": (delete("images"), GENERIC),
    "tables_negative": (PUBLISHED["tables_negative"], INVALID),
    "asset_content_id_missing": (PUBLISHED["asset_content_id_missing"], INVALID),
    "captured_at_without_timezone": (PUBLISHED["captured_at_without_timezone"], INVALID),
    "asset_size_string": (PUBLISHED["asset_size_string"], INVALID),
    "database_size_string": (PUBLISHED["database_size_string"], INVALID),
    "database_backup_key_elsewhere": (PUBLISHED["database_backup_key_elsewhere"], PASSED),
    "format_version_3": (assign("format_version", value=3), INVALID),
    "backup_id_not_identifier": (assign("backup_id", value="bad id"), INVALID),
    "asset_backend_unknown": (PUBLISHED["asset_backend_unknown"], INVALID),
    "asset_backup_key_elsewhere": (PUBLISHED["asset_backup_key_elsewhere"], INVALID),
}


def test_complete_folder_reaches_docker(failing_docker, credentials, ledger, monkeypatch, capsys,
                                        tmp_path):
    directory = write_folder(tmp_path / "backup", checkpoint=ledger.read_checkpoint_tip())
    assert outputs(directory, credentials, monkeypatch, capsys, tmp_path) == expected(PASSED)


@pytest.mark.parametrize("case", CORRUPTIONS)
def test_corrupted_manifest_outputs(case, failing_docker, credentials, ledger, monkeypatch,
                                    capsys, tmp_path):
    change, code = CORRUPTIONS[case]
    directory = write_folder(tmp_path / "backup", change=change,
                             checkpoint=ledger.read_checkpoint_tip())
    assert outputs(directory, credentials, monkeypatch, capsys, tmp_path) == expected(code)


@pytest.mark.parametrize("case,code", [
    ("same_storage_key", PASSED),
    ("same_after_normalizing", "missing_asset"),
    ("parent_and_child", "missing_asset"),
])
def test_colliding_asset_tar_path_outputs(case, code, failing_docker, credentials, ledger,
                                          monkeypatch, capsys, tmp_path):
    first, second = TAR_COLLISIONS[case]
    assets = [(asset(1, "s3", first, b"one"), b"one"), (asset(2, "s3", second, b"two"), b"two")]
    directory = write_folder(tmp_path / "backup", assets, checkpoint=ledger.read_checkpoint_tip())
    assert outputs(directory, credentials, monkeypatch, capsys, tmp_path) == expected(code)


def break_images_file(directory):
    (directory / "images.tar").unlink()


def change_images_bytes(directory):
    data = (directory / "images.tar").read_bytes()
    (directory / "images.tar").write_bytes(data[:-1] + b"x")


def change_dump_bytes(directory):
    (directory / "database.dump").write_bytes(b"changed dump!!")


def asset_outside_archive(index):
    def damage(directory):
        value = json.loads((directory / "manifest.json").read_bytes())
        value["assets"][index]["storage_key"] = "missing.png"
        (directory / "manifest.json").write_text(json.dumps(value))
    return damage


def images_missing_and_dump_changed(directory):
    break_images_file(directory)
    change_dump_bytes(directory)


@pytest.mark.parametrize("damage,change,code", [
    (break_images_file, None, "invalid_backup_file"),
    (change_images_bytes, None, "backup_hash_mismatch"),
    (change_dump_bytes, None, "backup_hash_mismatch"),
    (unsafe_member, None, "unsafe_archive"),
    (asset_outside_archive(0), None, "missing_asset"),
    (None, assign("sample", "asset_id", value=9), INVALID),
    # Checks keep their order: top-level fields, database then images files, archive safety,
    # each asset's fields then its archive membership, and the sample last.
    (change_dump_bytes, assign("app_commit", value="abc"), INVALID),
    (images_missing_and_dump_changed, None, "backup_hash_mismatch"),
    (change_dump_bytes, assign("assets", 1, "content_id", value=0), "backup_hash_mismatch"),
    (unsafe_member, assign("assets", 1, "content_id", value=0), "unsafe_archive"),
    (asset_outside_archive(0), assign("assets", 1, "content_id", value=0), "missing_asset"),
    (asset_outside_archive(1), assign("assets", 1, "content_id", value=0), INVALID),
    (asset_outside_archive(0), assign("sample", "asset_id", value=9), "missing_asset"),
], ids=[
    "images_file_missing", "images_hash_mismatch", "database_hash_mismatch", "archive_symlink",
    "asset_not_in_archive", "sample_asset_unknown", "top_level_violation_and_database_hash",
    "images_file_missing_and_database_hash", "database_hash_and_asset_violation",
    "unsafe_archive_and_asset_violation", "missing_asset_and_later_asset_violation",
    "asset_violation_and_its_missing_archive_entry", "missing_asset_and_sample_unknown",
])
def test_folder_check_order_outputs(damage, change, code, failing_docker, credentials, ledger,
                                    monkeypatch, capsys, tmp_path):
    directory = write_folder(tmp_path / "backup", change=change,
                             checkpoint=ledger.read_checkpoint_tip())
    if damage:
        damage(directory)
    assert outputs(directory, credentials, monkeypatch, capsys, tmp_path) == expected(code)


def test_format_version_1_folder_is_still_accepted(failing_docker, credentials, ledger,
                                                   monkeypatch, capsys, tmp_path):
    """Old folders pass the folder checks; restore-check still needs a deletion checkpoint."""
    directory = tmp_path / "backup"
    directory.mkdir(mode=0o700)
    (directory / "database.dump").write_bytes(DUMP)
    write_archive(directory / "images.tar", HEALTHY_ASSETS[:1])
    archive = (directory / "images.tar").read_bytes()
    value = manifest(HEALTHY_ASSETS[:1])
    del value["deletion_checkpoint"]
    value.update(
        format_version=1,
        assets=[{key: value["assets"][0][key] for key in ("id", "storage_key", "size_bytes",
                                                          "sha256")}],
        database={key: value["database"][key] for key in ("file", "size_bytes", "sha256")},
        images={"file": "images.tar", "size_bytes": len(archive), "sha256": digest(archive)},
    )
    (directory / "manifest.json").write_text(json.dumps(value))
    assert outputs(directory, credentials, monkeypatch, capsys, tmp_path) == {
        **expected(PASSED),
        "restore-check": (1, {"error": "deletion_checkpoint_required", "passed": False}),
    }


def test_check_backup_restore_exports_errors_shared_by_operator_scripts():
    """The probe in older API images imports CheckError from scripts.check_backup_restore."""
    from scripts import (
        image_backup,
        image_backup_jobs,
        image_migration,
        recovery_probe,
        restore_execution,
    )
    from scripts.check_backup_restore import (  # noqa: F401
        CheckError,
        require,
        sha256_file,
    )

    for module in (image_backup, image_backup_jobs, restore_execution, recovery_probe):
        assert module.CheckError is CheckError
    for module in (image_backup, image_backup_jobs, image_migration, restore_execution):
        assert module.require is require
    assert image_backup.sha256_file is image_migration.sha256_file is sha256_file
