import pytest
from sqlalchemy import event, func, select

from app.models.content import Content
from app.models.content_asset import ContentAsset
from app.models.content_category import content_categories
from app.models.content_event import ContentEvent
from app.models.content_tag import content_tags
from app.models.tag import Tag
from tests.integration.helpers import guest, link, request

pytestmark = pytest.mark.asyncio


@pytest.mark.parametrize("ocr_fails", [False, True])
async def test_image_storage_download_and_delete(
    api, external_responses, png_bytes, tmp_path, ocr_fails
):
    headers, _, _ = await guest(api)
    external_responses.ocr_fails = ocr_fails
    content = await request(
        api,
        "POST",
        "uploads/screenshots",
        headers=headers,
        status=201,
        files={"file": ("screen.png", png_bytes, "image/png")},
    )
    assert content["title"] == ("저장한 콘텐츠" if ocr_fails else "화면 제목")
    assert content["summary"] == ("요약 정보가 아직 없습니다." if ocr_fails else "화면 요약")
    if ocr_fails:
        assert [c["name"] for c in content["categories"]] == ["미분류"]
    else:
        assert content["categories"][0]["name"] != "미분류"
    asset_url = content["assets"][0]["download_url"]
    downloaded = await api.get(asset_url, headers=headers)
    assert downloaded.status_code == 200 and downloaded.content == png_bytes
    assert downloaded.headers["content-type"] == "image/png"
    files = [p for p in tmp_path.rglob("*") if p.is_file()]
    assert len(files) == 1 and files[0].read_bytes() == png_bytes
    await request(api, "DELETE", f"contents/{content['id']}", headers=headers, status=204)
    assert (await api.get(asset_url, headers=headers)).status_code == 404
    assert not any(p.is_file() for p in tmp_path.rglob("*"))


async def test_two_users_cannot_access_or_change_each_others_data(api, png_bytes):
    owner, _, _ = await guest(api)
    outsider, _, _ = await guest(api)
    content = await request(
        api,
        "POST",
        "uploads/screenshots",
        status=201,
        headers=owner,
        files={"file": ("private.png", png_bytes, "image/png")},
        data={"tag_names": "비공개"},
    )
    categories = await request(api, "GET", "categories", headers=owner)
    uncategorized = next(c for c in categories if c["name"] == "미분류")
    await link(api, owner, category_ids=[uncategorized["id"]], tag_names=["비공개"])
    cid = content["id"]
    category_id = content["categories"][0]["id"]
    for method, path, payload in [
        ("GET", f"contents/{cid}", None),
        ("POST", f"contents/{cid}/view", None),
        ("PUT", f"contents/{cid}/categories", {"category_ids": []}),
        ("PUT", f"contents/{cid}/tags", {"tag_names": ["변조"]}),
        ("PUT", f"contents/{cid}/favorite", {"is_favorite": True}),
        ("DELETE", f"contents/{cid}", None),
        ("PATCH", f"categories/{category_id}", {"name": "변조"}),
        ("DELETE", f"categories/{category_id}", None),
        (
            "POST",
            "contents",
            {"original_url": "https://example.com", "category_ids": [category_id]},
        ),
    ]:
        await request(api, method, path, headers=outsider, json=payload, status=404)
    assert (
        await api.get(content["assets"][0]["download_url"], headers=outsider)
    ).status_code == 404
    for params in [{}, {"q": "비공개"}, {"category_id": category_id}]:
        assert (await request(api, "GET", "feed", headers=outsider, params=params))["items"] == []
    categories = await request(api, "GET", "categories", headers=outsider)
    assert category_id not in [c["id"] for c in categories]
    assert all(c["content_count"] == 0 and c["last_saved_at"] is None for c in categories)
    assert await request(api, "GET", "categories/recent", headers=outsider) == []
    assert await request(api, "GET", "users/me/stats", headers=outsider) == {
        "saved_count": 0,
        "reopened_count": 0,
    }
    detail = await request(api, "GET", f"contents/{cid}", headers=owner)
    assert detail == content
    assert await request(api, "GET", "users/me/stats", headers=owner) == {
        "saved_count": 2,
        "reopened_count": 0,
    }


async def test_event_insert_failure_rolls_back_database_and_removes_image(
    api,
    database_connection,
    png_bytes,
    tmp_path,
):
    headers, _, _ = await guest(api)
    injected = []

    def fail_event_insert(connection, cursor, statement, parameters, context, executemany):
        if statement.lstrip().upper().startswith("INSERT INTO CONTENT_EVENTS"):
            injected.append(any(p.is_file() for p in tmp_path.rglob("*")))
            raise RuntimeError("Injected event insert failure")

    connection = database_connection.sync_connection
    event.listen(connection, "before_cursor_execute", fail_event_insert)
    try:
        response = await api.post(
            "/api/v1/uploads/screenshots",
            headers=headers,
            files={"file": ("screen.png", png_bytes, "image/png")},
            data={"tag_names": "rollback"},
        )
        assert response.status_code == 500
    finally:
        event.remove(connection, "before_cursor_execute", fail_event_insert)
    assert injected == [True]
    for table in [Content, ContentAsset, ContentEvent, Tag, content_categories, content_tags]:
        assert await database_connection.scalar(select(func.count()).select_from(table)) == 0
    assert not any(p.is_file() for p in tmp_path.rglob("*"))
    assert (await request(api, "GET", "feed", headers=headers))["items"] == []
    assert await request(api, "GET", "users/me/stats", headers=headers) == {
        "saved_count": 0,
        "reopened_count": 0,
    }
    # A subsequent request uses a new session and still succeeds after rollback.
    await link(api, headers)
