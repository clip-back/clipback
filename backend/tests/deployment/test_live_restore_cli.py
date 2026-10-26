"""Public host CLI contracts; no source environment or Docker is needed for this failure."""

import json
import os
import subprocess
import sys
from pathlib import Path


def test_private_credentials_are_checked_before_preparation_or_maintenance(tmp_path):
    credentials = tmp_path / "credentials.json"
    credentials.write_text(json.dumps({"secret_key": "private", "access_token": "private"}))
    credentials.chmod(0o644)
    root = tmp_path / "runs"
    root.mkdir(mode=0o700)
    result = subprocess.run(
        [
            sys.executable,
            "-m",
            "scripts.restore_execution",
            "prepare",
            "--backup-dir",
            str(tmp_path),
            "--credentials-file",
            str(credentials),
            "--image",
            "unused",
            "--run-root",
            str(root),
        ],
        capture_output=True,
        text=True,
        env={**os.environ, "PYTHONPATH": str(Path(__file__).parents[2])},
    )
    assert result.returncode == 1
    assert json.loads(result.stdout)["error"] == "credentials_not_private"
    assert not list(root.iterdir())


def test_boolean_assertion_alone_cannot_start_operational_restore(tmp_path):
    result = subprocess.run(
        [
            sys.executable,
            "-m",
            "scripts.image_backup_jobs",
            "restore-check",
            "--backup-dir",
            str(tmp_path),
            "--credentials-file",
            str(tmp_path / "missing"),
            "--image",
            "unused",
            "--writers-frozen",
        ],
        capture_output=True,
        text=True,
        env={**os.environ, "PYTHONPATH": str(Path(__file__).parents[2])},
    )
    assert result.returncode == 1
    assert json.loads(result.stdout)["error"] == "authoritative_restore_required"


def test_preparation_refuses_a_private_directory_inside_a_repository(tmp_path):
    repository = tmp_path / "repository"
    repository.mkdir()
    (repository / ".git").write_text("gitdir: synthetic")
    root = repository / "private-runs"
    root.mkdir(mode=0o700)
    credentials = tmp_path / "credentials.json"
    credentials.write_text(json.dumps({"secret_key": "private", "access_token": "private"}))
    credentials.chmod(0o600)
    result = subprocess.run(
        [
            sys.executable,
            "-m",
            "scripts.restore_execution",
            "prepare",
            "--backup-dir",
            str(tmp_path),
            "--credentials-file",
            str(credentials),
            "--image",
            "unused",
            "--run-root",
            str(root),
        ],
        capture_output=True,
        text=True,
        env={**os.environ, "PYTHONPATH": str(Path(__file__).parents[2])},
    )
    assert result.returncode == 1
    assert json.loads(result.stdout)["error"] == "workspace_inside_repository"
    assert not list(root.iterdir())
