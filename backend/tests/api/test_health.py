import asyncio

import pytest
from fastapi.testclient import TestClient


def test_health_check(client: TestClient) -> None:
    response = client.get("/api/v1/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


@pytest.mark.parametrize("failure", [None, "database", "storage", "timeout"])
def test_readiness(client, monkeypatch, tmp_path, failure):
    from app.api.v1.endpoints import health
    from app.db.session import get_db
    from app.main import app

    class Database:
        async def execute(self, statement):
            assert str(statement) == "SELECT 1"
            if failure == "database":
                raise RuntimeError("private connection details")
            if failure == "timeout":
                await asyncio.sleep(10)

    async def database():
        yield Database()

    def fail_storage(root):
        raise OSError("private storage path")

    monkeypatch.setattr(health.settings, "storage_root", tmp_path)
    if failure == "timeout":
        monkeypatch.setattr(health, "READINESS_TIMEOUT_SECONDS", 0.01)
    if failure == "storage":
        monkeypatch.setattr(health, "check_storage", fail_storage)
    app.dependency_overrides[get_db] = database
    try:
        response = client.get("/api/v1/health/ready")
    finally:
        app.dependency_overrides.pop(get_db, None)
    assert response.status_code == (503 if failure else 200)
    assert response.json() == {"status": "unavailable" if failure else "ok"}
    assert list(tmp_path.iterdir()) == []
