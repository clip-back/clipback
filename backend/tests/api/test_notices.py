import copy
import json
from contextlib import asynccontextmanager
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app.main import create_app
from app.schemas.notice import NoticeList
from app.services.maintenance import MaintenanceAdmissionError

NOTICE_FILE = Path(__file__).parents[2] / "app" / "notices.json"


def _file() -> dict:
    return json.loads(NOTICE_FILE.read_text(encoding="utf-8"))


def test_notices_are_public_and_match_the_file_in_order(client: TestClient) -> None:
    response = client.get("/api/v1/notices")

    assert response.status_code == 200
    assert response.json() == _file()
    assert [notice["title"] for notice in response.json()["notices"]] == [
        "허투루 100% 활용법",
        "허투루 사용이 처음이라면?",
    ]


def test_notices_are_closed_during_maintenance() -> None:
    class ClosedGate:
        @asynccontextmanager
        async def operation(self, kind):
            raise MaintenanceAdmissionError("service_maintenance")
            yield

    with TestClient(create_app(maintenance=ClosedGate())) as client:
        response = client.get("/api/v1/notices")

    assert response.status_code == 503
    assert response.json() == {"detail": {"code": "service_maintenance"}}


def test_openapi_lists_the_notice_path(client: TestClient) -> None:
    paths = client.get("/api/v1/openapi.json").json()["paths"]

    assert set(paths["/api/v1/notices"]) == {"get"}


def test_notice_file_passes_validation() -> None:
    assert len(NoticeList.model_validate_json(NOTICE_FILE.read_bytes()).notices) == 2


def _notice(data: dict) -> dict:
    return data["notices"][0]


def _step(data: dict) -> dict:
    return data["notices"][0]["steps"][0]


INVALID = [
    ("empty list", lambda d: d.update(notices=[])),
    ("notices null", lambda d: d.update(notices=None)),
    ("notices missing", lambda d: d.pop("notices")),
    ("title missing", lambda d: _notice(d).pop("title")),
    ("title empty", lambda d: _notice(d).update(title="")),
    ("title null", lambda d: _notice(d).update(title=None)),
    ("title number", lambda d: _notice(d).update(title=1)),
    ("title array", lambda d: _notice(d).update(title=["a"])),
    ("intro empty", lambda d: _notice(d).update(intro="")),
    ("closing missing", lambda d: _notice(d).pop("closing")),
    ("closing_title empty", lambda d: _notice(d).update(closing_title="")),
    ("intro_title number", lambda d: _notice(d).update(intro_title=3)),
    ("pinned string", lambda d: _notice(d).update(pinned="true")),
    ("pinned number", lambda d: _notice(d).update(pinned=1)),
    ("pinned null", lambda d: _notice(d).update(pinned=None)),
    ("date missing", lambda d: _notice(d).pop("published_on")),
    ("date text", lambda d: _notice(d).update(published_on="2026. 11. 23")),
    ("date impossible", lambda d: _notice(d).update(published_on="2026-02-30")),
    ("date time", lambda d: _notice(d).update(published_on="2026-11-23T00:00:00")),
    ("date number", lambda d: _notice(d).update(published_on=20261123)),
    ("steps null", lambda d: _notice(d).update(steps=None)),
    ("steps object", lambda d: _notice(d).update(steps={})),
    ("step body empty", lambda d: _step(d).update(body="")),
    ("step title missing", lambda d: _step(d).pop("title")),
    ("step note number", lambda d: _step(d).update(note=1)),
    ("step note array", lambda d: _step(d).update(note=["a"])),
    ("unknown field", lambda d: _notice(d).update(body="typo")),
]


@pytest.mark.parametrize("change", [c for _, c in INVALID], ids=[i for i, _ in INVALID])
def test_notice_file_rules_reject(change) -> None:
    data = copy.deepcopy(_file())
    change(data)

    with pytest.raises(ValidationError):
        NoticeList.model_validate_json(json.dumps(data))


def test_notice_file_rules_allow_no_steps_and_null_note() -> None:
    data = copy.deepcopy(_file())
    _notice(data)["steps"] = []
    data["notices"][1]["steps"][0]["note"] = None

    parsed = NoticeList.model_validate_json(json.dumps(data))

    assert parsed.notices[0].steps == []
