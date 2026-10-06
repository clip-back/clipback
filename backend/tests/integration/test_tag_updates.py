import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.tag import Tag
from tests.integration.helpers import guest, link, request

pytestmark = pytest.mark.asyncio


async def test_tags_replace_normalize_repeat_and_clear(api, database_connection):
    headers, _, user = await guest(api)
    content = await link(api, headers, tag_names=["old"])
    path = f"contents/{content['id']}/tags"
    first = await request(
        api,
        "PUT",
        path,
        headers=headers,
        json={"tag_names": [" Flutter ", "#flutter", "#백엔드"]},
    )
    assert {tag["name"] for tag in first["tags"]} == {"Flutter", "백엔드"}
    assert len(first["tags"]) == 2
    repeated = await request(
        api, "PUT", path, headers=headers, json={"tag_names": ["#flutter", "백엔드"]}
    )
    assert repeated["tags"] == first["tags"]
    cleared = await request(api, "PUT", path, headers=headers, json={"tag_names": []})
    assert cleared["tags"] == []
    detail = await request(api, "GET", f"contents/{content['id']}", headers=headers)
    assert detail["tags"] == []
    names = set(
        await database_connection.scalars(
            select(Tag.normalized_name).where(Tag.user_id == user["id"])
        )
    )
    assert names == {"old", "flutter", "백엔드"}


async def test_tags_reject_unowned_missing_and_invalid_changes(api, database_connection):
    headers, _, _ = await guest(api)
    outsider, _, other_user = await guest(api)
    content = await link(api, headers, tag_names=["old"])
    path = f"contents/{content['id']}/tags"
    await request(api, "PUT", path, headers=outsider, json={"tag_names": ["unowned"]}, status=404)
    await request(
        api,
        "PUT",
        "contents/2147483647/tags",
        headers=headers,
        json={"tag_names": ["missing"]},
        status=404,
    )
    for names in [["#"], ["x" * 41], [str(index) for index in range(11)]]:
        await request(api, "PUT", path, headers=headers, json={"tag_names": names}, status=422)
    detail = await request(api, "GET", f"contents/{content['id']}", headers=headers)
    assert [tag["name"] for tag in detail["tags"]] == ["old"]
    assert not list(
        await database_connection.scalars(select(Tag.id).where(Tag.user_id == other_user["id"]))
    )


async def test_tag_commit_failure_rolls_back_tags_and_links(api, database_connection, monkeypatch):
    headers, _, user = await guest(api)
    content = await link(api, headers, tag_names=["old"])

    async def fail_commit(self):
        raise RuntimeError("injected commit failure")

    with monkeypatch.context() as patch:
        patch.setattr(AsyncSession, "commit", fail_commit)
        response = await api.put(
            f"/api/v1/contents/{content['id']}/tags",
            headers=headers,
            json={"tag_names": ["rolled-back"]},
        )
        assert response.status_code == 500

    detail = await request(api, "GET", f"contents/{content['id']}", headers=headers)
    assert [tag["name"] for tag in detail["tags"]] == ["old"]
    names = set(
        await database_connection.scalars(select(Tag.name).where(Tag.user_id == user["id"]))
    )
    assert names == {"old"}
