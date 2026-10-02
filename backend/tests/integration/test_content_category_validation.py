import pytest
from sqlalchemy import func, select

from app.integrations.storage_client import LocalStorageClient
from app.models.category import Category
from app.models.content import Content
from app.models.content_asset import ContentAsset
from app.models.content_category import content_categories
from app.models.content_event import ContentEvent
from app.models.content_tag import content_tags
from app.models.summary_job import SummaryJob
from app.models.tag import Tag
from tests.integration.helpers import guest, link, request

pytestmark = pytest.mark.asyncio


async def content_data_counts(connection):
    return [
        await connection.scalar(select(func.count()).select_from(table))
        for table in (
            Content, Tag, ContentEvent, ContentAsset, SummaryJob, content_categories, content_tags
        )
    ]


@pytest.mark.parametrize(
    ("route", "url_field", "url"),
    [
        ("contents", "original_url", "https://example.com/article"),
        ("contents", "original_url", "https://youtu.be/dQw4w9WgXcQ"),
        ("contents/share", "url", "https://www.instagram.com/p/ABC123/"),
        ("contents/share", "url", "https://youtu.be/dQw4w9WgXcQ"),
        ("uploads/screenshots", None, None),
    ],
    ids=["direct", "direct-youtube", "shared-instagram", "shared-youtube", "screenshot"],
)
async def test_create_rejects_mixed_uncategorized_without_saved_data(
    api, database_connection, external_responses, png_bytes, tmp_path, monkeypatch,
    route, url_field, url,
):
    headers, _, _ = await guest(api)
    categories = await request(api, "GET", "categories", headers=headers)
    uncategorized_id = next(c["id"] for c in categories if c["name"] == "미분류")
    personal_id = next(c["id"] for c in categories if c["name"] != "미분류")
    category_ids = [uncategorized_id, personal_id]
    before = await content_data_counts(database_connection)
    deleted_keys = []

    if route == "uploads/screenshots":
        delete_file = LocalStorageClient.delete_file

        async def delete_existing_file(self, storage_key):
            assert (self.root / storage_key).read_bytes() == png_bytes
            deleted_keys.append(storage_key)
            await delete_file(self, storage_key)

        monkeypatch.setattr(LocalStorageClient, "delete_file", delete_existing_file)
        response = await api.post(
            f"/api/v1/{route}", headers=headers,
            files={"file": ("screen.png", png_bytes, "image/png")},
            data={"category_ids": category_ids, "tag_names": "거절 태그"},
        )
    else:
        response = await api.post(
            f"/api/v1/{route}", headers=headers,
            json={url_field: url, "category_ids": category_ids, "tag_names": ["거절 태그"]},
        )

    assert response.status_code == 422, response.text
    assert response.json()["detail"] == (
        "Uncategorized category cannot be combined with other categories"
    )
    assert await content_data_counts(database_connection) == before
    assert external_responses.ai_calls == 0
    if route == "uploads/screenshots":
        assert len(deleted_keys) == 1
        assert not any(path.is_file() for path in tmp_path.rglob("*"))


async def test_rejected_category_update_preserves_youtube_content_events_and_job(
    api, database_connection, external_responses,
):
    headers, _, _ = await guest(api)
    categories = await request(api, "GET", "categories", headers=headers)
    uncategorized_id = next(c["id"] for c in categories if c["name"] == "미분류")
    personal_id = next(c["id"] for c in categories if c["name"] != "미분류")
    content = await link(api, headers, original_url="https://youtu.be/dQw4w9WgXcQ")
    assert [c["id"] for c in content["categories"]] == [uncategorized_id]
    job_flag = select(SummaryJob.apply_category).where(SummaryJob.content_id == content["id"])
    assert await database_connection.scalar(job_flag) is True
    before_counts = await content_data_counts(database_connection)
    events = select(
        ContentEvent.id, ContentEvent.event_type,
        ContentEvent.metadata_json, ContentEvent.category_ids_at_event,
    ).where(ContentEvent.content_id == content["id"]).order_by(ContentEvent.id)
    before_events = (await database_connection.execute(events)).all()

    response = await api.put(
        f"/api/v1/contents/{content['id']}/categories", headers=headers,
        json={"category_ids": [uncategorized_id, personal_id]},
    )

    assert response.status_code == 422, response.text
    assert response.json()["detail"] == (
        "Uncategorized category cannot be combined with other categories"
    )
    assert await request(api, "GET", f"contents/{content['id']}", headers=headers) == content
    assert await content_data_counts(database_connection) == before_counts
    assert (await database_connection.execute(events)).all() == before_events
    assert await database_connection.scalar(job_flag) is True
    assert external_responses.ai_calls == 0


@pytest.mark.parametrize("operation", ["create", "update"])
@pytest.mark.parametrize("unavailable", ["missing", "foreign"])
async def test_unavailable_category_takes_priority_over_mixed_uncategorized(
    api, database_connection, external_responses, operation, unavailable,
):
    headers, _, _ = await guest(api)
    categories = await request(api, "GET", "categories", headers=headers)
    uncategorized_id = next(c["id"] for c in categories if c["name"] == "미분류")
    personal_id = next(c["id"] for c in categories if c["name"] != "미분류")
    if unavailable == "foreign":
        outsider, _, _ = await guest(api)
        foreign_categories = await request(api, "GET", "categories", headers=outsider)
        unavailable_id = next(c["id"] for c in foreign_categories if c["name"] != "미분류")
    else:
        unavailable_id = await database_connection.scalar(select(func.max(Category.id))) + 1
    content = None
    if operation == "update":
        content = await link(api, headers, category_ids=[personal_id])
    before = await content_data_counts(database_connection)
    category_ids = [uncategorized_id, personal_id, unavailable_id]

    if operation == "create":
        response = await api.post(
            "/api/v1/contents", headers=headers,
            json={
                "original_url": "https://example.com/article",
                "category_ids": category_ids,
                "tag_names": ["거절 태그"],
            },
        )
    else:
        response = await api.put(
            f"/api/v1/contents/{content['id']}/categories", headers=headers,
            json={"category_ids": category_ids},
        )

    assert response.status_code == 404, response.text
    assert response.json()["detail"] == "Category not found"
    assert await content_data_counts(database_connection) == before
    assert external_responses.ai_calls == 0
    if content is not None:
        assert await request(api, "GET", f"contents/{content['id']}", headers=headers) == content
