"""Private source commands and HTTP expose only identified, bounded original reads."""

import hashlib
import os
import subprocess
import sys
from pathlib import Path

from fastapi.testclient import TestClient


def register(root, identifier="source99"):
    return subprocess.run(
        [sys.executable, "-m", "scripts.image_source", "register", "--root", str(root),
         "--source-id", identifier, "--confirm-volume"], capture_output=True, text=True,
        env={**os.environ, "PYTHONPATH": str(Path(__file__).parents[2])},
    )


def test_explicit_registration_and_private_original_read(tmp_path):
    from app.core.operator_source_config import SourceSettings
    from app.operator import create_operator_app

    original = b"known original99"
    (tmp_path / "original.png").write_bytes(original)
    settings = SourceSettings(storage_root=tmp_path, operator_source_id="source99",
                              operator_read_key="reader99-safe-token")
    client = TestClient(create_operator_app(settings))
    headers = {"Authorization": "Bearer reader99-safe-token", "X-Source-ID": "source99"}
    assert client.get("/source", headers=headers).status_code == 503
    assert register(tmp_path).returncode == 0
    assert register(tmp_path).returncode == 1
    assert client.get("/source", headers=headers).json() == {"source_id": "source99"}
    response = client.post("/source/read", headers=headers, json={"storage_key": "original.png"})
    assert response.status_code == 200
    assert response.content == original
    assert response.headers["X-Source-ID"] == "source99"
    assert response.headers["X-Content-SHA256"] == hashlib.sha256(original).hexdigest()
    assert response.headers["X-Content-Size"] == str(len(original))


def test_unidentified_wrong_source_and_unsafe_reads_are_rejected(tmp_path):
    from app.core.operator_source_config import SourceSettings
    from app.operator import create_operator_app

    settings = SourceSettings(storage_root=tmp_path, operator_source_id="source99",
                              operator_read_key="reader99-safe-token", screenshot_max_bytes=16)
    client = TestClient(create_operator_app(settings))
    headers = {"Authorization": "Bearer reader99-safe-token", "X-Source-ID": "source99"}
    assert register(tmp_path).returncode == 0
    for token in ["", "Bearer app-login-token", "Bearer wrong"]:
        assert client.get("/source", headers={"Authorization": token}).status_code == 403
    assert client.get("/source", headers={**headers, "X-Source-ID": "other"}).status_code == 409
    (tmp_path / "large").write_bytes(b"x" * 17)
    (tmp_path / "link").symlink_to("/etc/passwd")
    (tmp_path / "directory").mkdir()
    for key in ["../file", "/etc/passwd", "a//b", ".clipback-source-id", "link", "directory"]:
        response = client.post("/source/read", headers=headers, json={"storage_key": key})
        assert response.status_code >= 400
    assert client.post("/source/read", headers=headers,
                       json={"storage_key": "missing"}).status_code == 404
    assert client.post("/source/read", headers=headers,
                       json={"storage_key": "large"}).status_code == 503
    assert client.delete("/source/read", headers=headers).status_code == 405
    (tmp_path / ".clipback-source-id").write_text("other\n")
    assert client.get("/source", headers=headers).status_code == 503
    missing = tmp_path / "not-a-volume"
    assert register(missing).returncode == 1
    assert not missing.exists()
