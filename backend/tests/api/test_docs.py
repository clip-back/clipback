import pytest
from fastapi.testclient import TestClient

from app.core.config import settings
from app.main import create_app
from tests.support.maintenance import OpenUnitGate


@pytest.mark.parametrize("environment", ["production", "test", "local"])
def test_documentation_access_depends_on_environment(monkeypatch, environment: str) -> None:
    monkeypatch.setattr(settings, "app_environment", environment)
    app = create_app(maintenance=OpenUnitGate())
    with TestClient(app) as client:
        for path in ("/docs", "/redoc", "/api/v1/openapi.json", "/docs/oauth2-redirect"):
            response = client.get(path)
            assert response.status_code == (404 if environment == "production" else 200), path

        response = client.get("/")
        assert response.status_code == 200
        assert response.json() == {"service": settings.project_name, "status": "ok"}
        response = client.get("/api/v1/health")
        assert response.status_code == 200
        assert response.json() == {"status": "ok"}
