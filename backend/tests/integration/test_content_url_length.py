from types import SimpleNamespace

import pytest
from pydantic import HttpUrl
from sqlalchemy import select

from app.integrations.metadata_client import MetadataClient, MetadataResult
from app.models.content import Content
from app.models.content_event import ContentEvent
from app.models.summary_job import SummaryJob
from app.models.tag import Tag
from tests.integration.helpers import guest

pytestmark = pytest.mark.asyncio


def url_of_length(length):
    prefix = "https://example.com/"
    return prefix + "a" * (length - len(prefix))


@pytest.fixture
def metadata_probe(external_responses, monkeypatch):
    state = SimpleNamespace(urls=[], resolved_url=None, status="success")

    async def extract(self, url):
        state.urls.append(url)
        return MetadataResult(
            resolved_url=state.resolved_url or url,
            title=None,
            description=None,
            status=state.status,
            failure_reason="metadata_missing" if state.status == "failed" else None,
        )

    monkeypatch.setattr(MetadataClient, "extract_from_url", extract)
    return state


async def assert_no_content_data(connection, user_id):
    for model in (Content, Tag, ContentEvent):
        rows = await connection.execute(select(model.id).where(model.user_id == user_id))
        assert rows.all() == []
    jobs = await connection.execute(
        select(SummaryJob.content_id).join(Content).where(Content.user_id == user_id)
    )
    assert jobs.all() == []


@pytest.mark.parametrize("length", [2048, 2049, 2050, 2084])
async def test_direct_url_database_boundary(
    api, database_connection, external_responses, metadata_probe, length,
):
    headers, _, user = await guest(api)
    url = url_of_length(length)

    response = await api.post(
        "/api/v1/contents", headers=headers,
        json={"original_url": url, "tag_names": ["길이 검증"]},
    )

    assert response.status_code == (201 if length == 2048 else 422), response.text
    if length == 2048:
        stored = await database_connection.scalar(
            select(Content.original_url).where(Content.id == response.json()["id"])
        )
        assert stored == response.json()["original_url"] == url
        assert metadata_probe.urls == [url]
    else:
        assert metadata_probe.urls == []
        assert external_responses.ai_calls == 0
        await assert_no_content_data(database_connection, user["id"])


async def test_direct_unicode_url_is_checked_after_encoding(
    api, database_connection, external_responses, metadata_probe,
):
    headers, _, user = await guest(api)
    url = "https://example.com/" + "가" * 230
    assert len(url) < 2048 < len(str(HttpUrl(url)))

    response = await api.post(
        "/api/v1/contents", headers=headers,
        json={"original_url": url, "tag_names": ["길이 검증"]},
    )

    assert response.status_code == 422
    assert metadata_probe.urls == []
    assert external_responses.ai_calls == 0
    await assert_no_content_data(database_connection, user["id"])


@pytest.mark.parametrize("field", ["original_url", "url", "raw_text"])
@pytest.mark.parametrize("case", ["boundary", "expanded", "unicode"])
async def test_instagram_normalized_url_length(
    api, database_connection, external_responses, metadata_probe, field, case,
):
    headers, _, user = await guest(api)
    slug = "가" * 230 if case == "unicode" else "a" * (
        (2048 if case == "boundary" else 2049) - len("https://www.instagram.com/p//")
    )
    url = f"https://instagram.com/p/{slug}"
    assert len(url) < 2048
    expected = str(HttpUrl(f"https://www.instagram.com/p/{slug}/"))
    route = "contents" if field == "original_url" else "contents/share"
    value = f"나중에 보기 {url}" if field == "raw_text" else url

    response = await api.post(
        f"/api/v1/{route}", headers=headers,
        json={field: value, "tag_names": ["길이 검증"]},
    )

    assert response.status_code == (201 if case == "boundary" else 422), response.text
    if case == "boundary":
        assert response.json()["original_url"] == expected
        assert len(expected) == 2048
        assert await database_connection.scalar(
            select(Content.original_url).where(Content.id == response.json()["id"])
        ) == expected
        assert metadata_probe.urls == [expected]
    else:
        assert metadata_probe.urls == []
        assert external_responses.ai_calls == 0
        await assert_no_content_data(database_connection, user["id"])


@pytest.mark.parametrize("status", ["success", "failed"])
@pytest.mark.parametrize("case", ["boundary", "over", "http_url_limit", "unicode"])
async def test_redirect_url_length_is_checked_before_storage(
    api, database_connection, external_responses, metadata_probe, status, case,
):
    headers, _, user = await guest(api)
    resolved = (
        "https://example.com/" + "가" * 230 if case == "unicode"
        else url_of_length({"boundary": 2048, "over": 2049, "http_url_limit": 2084}[case])
    )
    metadata_probe.resolved_url = resolved
    metadata_probe.status = status
    original = "https://example.com/short"

    response = await api.post(
        "/api/v1/contents", headers=headers,
        json={"original_url": original, "tag_names": ["길이 검증"]},
    )

    assert response.status_code == (201 if case == "boundary" else 422), response.text
    assert metadata_probe.urls == [original]
    if case == "boundary":
        assert response.json()["original_url"] == resolved
        assert await database_connection.scalar(
            select(Content.original_url).where(Content.id == response.json()["id"])
        ) == resolved
    else:
        assert "2048" in response.json()["detail"]
        assert external_responses.ai_calls == 0
        await assert_no_content_data(database_connection, user["id"])


@pytest.mark.parametrize("field", ["raw_text", "url"])
@pytest.mark.parametrize(
    ("url", "expected"),
    [
        ("https://instagram.com/p/ABC/?tracking=", "https://www.instagram.com/p/ABC/"),
        ("https://youtu.be/dQw4w9WgXcQ?tracking=", "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
    ],
)
async def test_shared_long_url_shortened_by_normalization(
    api, database_connection, external_responses, metadata_probe, field, url, expected,
):
    headers, _, user = await guest(api)
    response = await api.post(
        "/api/v1/contents/share", headers=headers,
        json={field: url + "x" * 2500, "tag_names": ["공유"]},
    )

    assert response.status_code == (201 if field == "raw_text" else 422), response.text
    if field == "raw_text":
        assert response.json()["original_url"] == expected
        assert await database_connection.scalar(
            select(Content.original_url).where(Content.id == response.json()["id"])
        ) == expected
        if "youtube" in expected:
            assert response.json()["summary_status"] == "skipped"
            assert metadata_probe.urls == []
        else:
            assert metadata_probe.urls == [expected]
    else:
        assert metadata_probe.urls == []
        assert external_responses.ai_calls == 0
        await assert_no_content_data(database_connection, user["id"])
