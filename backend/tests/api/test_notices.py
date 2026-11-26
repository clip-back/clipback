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


def _example(title: str, steps: int = 1, **fields) -> dict:
    """A notice independent of what the operator's file holds now."""
    return {
        "title": title,
        "published_on": "2026-12-02",
        "pinned": False,
        "intro_title": "머리 제목",
        "intro": "머리 글",
        "steps": [{"title": f"단계 {i}", "body": "본문", "note": None} for i in range(steps)],
        "closing_title": "맺음 제목",
        "closing": "맺음 글",
        **fields,
    }


# What an operator may publish by editing the file alone (#486 decision 1).
OPERATOR_FILES = {
    "third notice added": lambda d: d["notices"].append(_example("세 번째 공지", steps=0)),
    "title edited": lambda d: d["notices"][0].update(title="바뀐 제목"),
    "order changed": lambda d: d["notices"].reverse(),
    "no-steps notice first": lambda d: d["notices"].insert(0, _example("맨 앞 공지", steps=0)),
}


@pytest.mark.parametrize(
    "change", list(OPERATOR_FILES.values()), ids=list(OPERATOR_FILES)
)
def test_an_edited_file_is_served_as_written(client, monkeypatch, change) -> None:
    from app.api.v1.endpoints import notices

    data = _file()
    change(data)
    monkeypatch.setattr(notices, "NOTICES", NoticeList.model_validate_json(json.dumps(data)))

    response = client.get("/api/v1/notices")

    assert response.status_code == 200
    assert response.json() == data


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
    NoticeList.model_validate_json(NOTICE_FILE.read_bytes())


def _valid() -> dict:
    return {"notices": [_example("첫 공지"), _example("둘째 공지", steps=0)]}


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
    ("date not leap", lambda d: _notice(d).update(published_on="2026-02-29")),
    ("date year zero", lambda d: _notice(d).update(published_on="0000-01-01")),
    ("date time", lambda d: _notice(d).update(published_on="2026-11-23T00:00:00")),
    ("date number", lambda d: _notice(d).update(published_on=20261123)),
    ("steps null", lambda d: _notice(d).update(steps=None)),
    ("steps object", lambda d: _notice(d).update(steps={})),
    ("step body empty", lambda d: _step(d).update(body="")),
    ("step title missing", lambda d: _step(d).pop("title")),
    ("step note missing", lambda d: _step(d).pop("note")),
    ("step note number", lambda d: _step(d).update(note=1)),
    ("step note array", lambda d: _step(d).update(note=["a"])),
    # The file is checked strictly; the app ignores unknown keys (api-contracts 공지).
    ("unknown field", lambda d: _notice(d).update(body="typo")),
    ("bad notice after a good one", lambda d: d["notices"][1].update(title="")),
]


@pytest.mark.parametrize("change", [c for _, c in INVALID], ids=[i for i, _ in INVALID])
def test_notice_file_rules_reject(change) -> None:
    data = _valid()
    change(data)

    with pytest.raises(ValidationError):
        NoticeList.model_validate_json(json.dumps(data))


@pytest.mark.parametrize("day", ["0001-01-01", "2024-02-29", "9999-12-31"])
def test_notice_file_rules_allow_calendar_edges(day) -> None:
    data = _valid()
    _notice(data)["published_on"] = day

    parsed = NoticeList.model_validate_json(json.dumps(data))

    assert parsed.notices[0].published_on.isoformat() == day


def test_notice_file_rules_allow_no_steps_and_text_note() -> None:
    data = _valid()
    _step(data)["note"] = "덧붙임"

    parsed = NoticeList.model_validate_json(json.dumps(data))

    assert parsed.notices[0].steps[0].note == "덧붙임"
    assert parsed.notices[1].steps == []
