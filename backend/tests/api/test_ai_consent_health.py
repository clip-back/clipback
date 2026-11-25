import json
import logging
from contextlib import asynccontextmanager
from io import StringIO

import httpx
import pytest
from fastapi.testclient import TestClient

from app.core.config import settings
from app.db.session import get_db
from app.main import create_app
from app.services.maintenance import MaintenanceAdmissionError
from app.services.summary_worker import SummaryWorker
from tests.support.maintenance import OpenUnitGate


@pytest.mark.parametrize("required", [False, True])
@pytest.mark.parametrize("maintenance", [False, True])
def test_health_exposes_only_process_switch_without_database(monkeypatch, required, maintenance):
    class ClosedGate:
        @asynccontextmanager
        async def operation(self, kind):
            raise MaintenanceAdmissionError("service_maintenance")
            yield

    def unavailable_database():
        raise AssertionError("AI consent health must work without a database")

    monkeypatch.setattr(settings, "ai_consent_required", required)
    app = create_app(maintenance=ClosedGate() if maintenance else OpenUnitGate())
    app.dependency_overrides[get_db] = unavailable_database
    with TestClient(app) as client:
        response = client.get("/api/v1/health/ai-consent")
        assert response.status_code == httpx.codes.OK
        body = response.json()
        assert set(body) == {"ai_consent_required"}
        assert body["ai_consent_required"] is required
        assert "cache-control" not in response.headers
        if maintenance:
            assert client.get("/api/v1/users/me").status_code == httpx.codes.SERVICE_UNAVAILABLE


@pytest.mark.parametrize("required", [False, True])
@pytest.mark.parametrize("worker_running", [False, True])
def test_public_api_lifespan_logs_worker_switch_once(monkeypatch, caplog, required, worker_running):
    monkeypatch.setattr(settings, "ai_consent_required", required)
    monkeypatch.setattr(settings, "youtube_summary_enabled", worker_running)
    monkeypatch.setattr(settings, "instagram_summary_enabled", False)
    started = []

    async def run(worker):
        started.append(worker.config.ai_consent_required)

    monkeypatch.setattr(SummaryWorker, "run", run)
    app_logger = logging.getLogger("app")
    output = StringIO()
    stream = logging.StreamHandler(output)
    monkeypatch.setattr(app_logger, "handlers", [])
    app_logger.addHandler(stream)
    app_logger.addHandler(caplog.handler)
    try:
        with TestClient(create_app(maintenance=OpenUnitGate())) as client:
            app_logger.info("synthetic startup log marker")
            for _ in range(2):
                assert client.get("/api/v1/health").status_code == httpx.codes.OK
    finally:
        app_logger.removeHandler(caplog.handler)

    assert started == ([required] if worker_running else [])
    messages = output.getvalue().splitlines()
    assert messages.count("synthetic startup log marker") == 1
    assert sum(r.getMessage() == "synthetic startup log marker" for r in caplog.records) == 1
    expected = [{
        "event": "summary_worker_consent_config",
        "worker_running": worker_running,
        "ai_consent_required": required,
    }]
    assert [json.loads(line) for line in messages if "summary_worker_consent_config" in line] == (
        expected
    )
    assert [
        json.loads(record.getMessage())
        for record in caplog.records
        if "summary_worker_consent_config" in record.getMessage()
    ] == expected
