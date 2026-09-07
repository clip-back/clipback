from datetime import UTC, datetime
from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient

from app.api.v1.endpoints import categories as category_endpoints
from app.core.security import create_access_token
from app.repositories.auth_session_repository import AuthSessionRepository
from app.repositories.user_repository import UserRepository
from app.schemas.category import CategoryRead, CategorySummaryRead


class FakeCategoryService:
    def __init__(self) -> None:
        self.calls: list[tuple[int, int | None]] = []
        self.categories = [
            CategorySummaryRead(
                id=3,
                name="여행",
                color=None,
                is_default=False,
                content_count=5,
                last_saved_at=datetime(2026, 9, 7, 3, tzinfo=UTC),
            ),
            CategorySummaryRead(
                id=4,
                name="빈 카테고리",
                color=None,
                is_default=False,
                content_count=0,
                last_saved_at=None,
            ),
        ]

    async def list_categories(self, user_id: int):
        self.calls.append((user_id, None))
        return self.categories

    async def list_recent_categories(self, user_id: int, limit: int):
        self.calls.append((user_id, limit))
        return self.categories[:1]

    async def update_category(self, user_id, category_id, payload):
        self.calls.append((user_id, category_id))
        return CategoryRead(
            id=category_id, name=payload.name or "여행", color=payload.color, is_default=True
        )

    async def delete_category(self, user_id, category_id):
        self.calls.append((user_id, category_id))

    async def create_category(self, user_id: int, payload):
        self.calls.append((user_id, None))
        return CategoryRead(id=5, name=payload.name, color=payload.color, is_default=False)


@pytest.fixture
def category_service(monkeypatch) -> FakeCategoryService:
    service = FakeCategoryService()
    monkeypatch.setattr(
        category_endpoints,
        "CategoryService",
        lambda *, category_repository: service,
    )
    return service


@pytest.fixture
def auth_headers(monkeypatch) -> dict[str, str]:
    async def get_active(self, *, session_id: int, user_id: int):
        return SimpleNamespace(id=session_id, user_id=user_id)

    async def get_user(self, user_id: int):
        return SimpleNamespace(id=user_id)

    monkeypatch.setattr(AuthSessionRepository, "get_active", get_active)
    monkeypatch.setattr(UserRepository, "get", get_user)
    return {"Authorization": f"Bearer {create_access_token(user_id=7, session_id=3)}"}


def test_category_list_serializes_statistics(client, category_service, auth_headers) -> None:
    response = client.get("/api/v1/categories", headers=auth_headers)

    assert response.status_code == 200
    assert response.json() == [
        {
            "id": 3,
            "name": "여행",
            "color": None,
            "is_default": False,
            "content_count": 5,
            "last_saved_at": "2026-09-07T03:00:00Z",
        },
        {
            "id": 4,
            "name": "빈 카테고리",
            "color": None,
            "is_default": False,
            "content_count": 0,
            "last_saved_at": None,
        },
    ]
    assert category_service.calls == [(7, None)]


@pytest.mark.parametrize(("query", "limit"), [("", 2), ("?limit=1", 1), ("?limit=20", 20)])
def test_recent_categories_passes_limit_and_user(
    client,
    category_service,
    auth_headers,
    query,
    limit,
) -> None:
    response = client.get(f"/api/v1/categories/recent{query}", headers=auth_headers)

    assert response.status_code == 200
    assert response.json() == [category_service.categories[0].model_dump(mode="json")]
    assert category_service.calls == [(7, limit)]


@pytest.mark.parametrize("limit", ["0", "21", "-1", "invalid"])
def test_recent_categories_rejects_invalid_limit(
    client,
    category_service,
    auth_headers,
    limit,
) -> None:
    response = client.get(f"/api/v1/categories/recent?limit={limit}", headers=auth_headers)

    assert response.status_code == 422
    assert category_service.calls == []


@pytest.mark.parametrize("path", ["/api/v1/categories", "/api/v1/categories/recent"])
def test_category_lists_require_authentication(client, category_service, path) -> None:
    assert client.get(path).status_code == 401
    assert category_service.calls == []


@pytest.mark.parametrize("path", ["/api/v1/categories", "/api/v1/categories/recent"])
def test_category_lists_return_empty_array(client, category_service, auth_headers, path) -> None:
    category_service.categories = []

    response = client.get(path, headers=auth_headers)

    assert response.status_code == 200
    assert response.json() == []


def test_category_creation_keeps_original_response(client, category_service, auth_headers) -> None:
    response = client.post("/api/v1/categories", json={"name": "운동"}, headers=auth_headers)

    assert response.status_code == 201
    assert response.json() == {"id": 5, "name": "운동", "color": None, "is_default": False}


def test_openapi_limits_statistics_to_category_lists(client: TestClient) -> None:
    specification = client.get("/api/v1/openapi.json").json()
    schemas = specification["components"]["schemas"]

    assert {"content_count", "last_saved_at"} <= set(schemas["CategorySummaryRead"]["required"])
    assert set(schemas["CategoryRead"]["properties"]) == {"id", "name", "color", "is_default"}
    assert schemas["ContentRead"]["properties"]["categories"]["items"] == {
        "$ref": "#/components/schemas/CategoryRead",
    }
    operation = specification["paths"]["/api/v1/categories/recent"]["get"]
    limit = next(parameter for parameter in operation["parameters"] if parameter["name"] == "limit")
    assert limit["schema"]["default"] == 2
    assert limit["schema"]["minimum"] == 1
    assert limit["schema"]["maximum"] == 20


def test_update_and_delete_contract(client, category_service, auth_headers):
    response = client.patch(
        "/api/v1/categories/5", json={"name": "  여행 준비  "}, headers=auth_headers
    )
    assert response.status_code == 200
    assert response.json() == {
        "id": 5,
        "name": "여행 준비",
        "color": None,
        "is_default": True,
    }
    response = client.delete("/api/v1/categories/5", headers=auth_headers)
    assert response.status_code == 204
    assert response.content == b""
    assert category_service.calls == [(7, 5), (7, 5)]


@pytest.mark.parametrize(
    "payload",
    [
        {},
        {"name": None},
        {"name": ""},
        {"name": "   "},
        {"name": "x" * 41},
        {"color": "x" * 21},
        {"unknown": 1},
        {"name": "여행", "is_default": False},
    ],
)
def test_update_validation(client, category_service, auth_headers, payload):
    response = client.patch("/api/v1/categories/5", json=payload, headers=auth_headers)
    assert response.status_code == 422
    assert category_service.calls == []


@pytest.mark.parametrize("method", ["patch", "delete"])
@pytest.mark.parametrize("headers", [{}, {"Authorization": "Bearer invalid"}])
def test_mutations_require_auth(client, category_service, method, headers):
    assert (
        client.request(
            method, "/api/v1/categories/5", headers=headers, json={"color": None}
        ).status_code
        == 401
    )
    assert category_service.calls == []


def test_update_openapi(client):
    document = client.get("/api/v1/openapi.json").json()
    path = document["paths"]["/api/v1/categories/{category_id}"]
    assert "204" in path["delete"]["responses"]
    assert path["patch"]["responses"]["200"]["content"]["application/json"]["schema"] == {
        "$ref": "#/components/schemas/CategoryRead",
    }
    assert document["components"]["schemas"]["CategoryUpdate"]["additionalProperties"] is False


def test_update_openapi_name_is_optional_but_not_nullable(client):
    schema = client.get("/api/v1/openapi.json").json()["components"]["schemas"]["CategoryUpdate"]
    assert schema["minProperties"] == 1
    assert schema["properties"]["name"]["type"] == "string"
    assert "name" not in schema.get("required", [])
    assert {"type": "null"} in schema["properties"]["color"]["anyOf"]


@pytest.mark.parametrize("method", ["patch", "delete"])
def test_mutations_reject_revoked_sessions(
    client, category_service, auth_headers, monkeypatch, method
):
    async def revoked(self, **kwargs):
        return None

    monkeypatch.setattr(AuthSessionRepository, "get_active", revoked)
    response = client.request(
        method, "/api/v1/categories/5", headers=auth_headers, json={"color": None}
    )
    assert response.status_code == 401
    assert category_service.calls == []


@pytest.mark.parametrize("method", ["patch", "delete"])
@pytest.mark.parametrize("status_code", [404, 409])
def test_mutation_error_responses(client, category_service, auth_headers, method, status_code):
    from app.core.exceptions import InvalidStateError, NotFoundError

    async def fail(*args, **kwargs):
        raise (
            NotFoundError("Category not found")
            if status_code == 404
            else InvalidStateError("Conflict")
        )

    setattr(category_service, "update_category" if method == "patch" else "delete_category", fail)
    response = client.request(
        method, "/api/v1/categories/5", headers=auth_headers, json={"color": None}
    )
    assert response.status_code == status_code
