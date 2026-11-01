"""Locks the summary job each saved link gets (spec #147 "요약 작업 생성 표")."""

import pytest
from sqlalchemy import func, select

from app.core.config import settings
from app.models.content import Content
from app.models.summary_job import SummaryJob
from tests.integration.helpers import guest, request

pytestmark = pytest.mark.asyncio

VIDEO_ID = "dQw4w9WgXcQ"
YOUTUBE_LINKS = [
    f"https://www.youtube.com/watch?v={VIDEO_ID}",
    f"https://youtu.be/{VIDEO_ID}",
    f"https://www.youtube.com/shorts/{VIDEO_ID}",
    f"https://www.youtube.com/live/{VIDEO_ID}",
]
INSTAGRAM_POSTS = [
    f"https://{host}/{path}/XYZ789/"
    for host in ("instagram.com", "www.instagram.com", "m.instagram.com")
    for path in ("reel", "p", "tv")
]
INSTAGRAM_STORY = "https://www.instagram.com/stories/someone/123456/"
# Instagram links outside the post forms are refused at save, so they never get a job.
REFUSED_INSTAGRAM_LINKS = [
    "https://www.instagram.com/reels/XYZ789/",
    "https://www.instagram.com/someone/reel/XYZ789/",
    "https://www.instagram.com/someone/",
]
JOB_COLUMNS = (
    SummaryJob.kind,
    SummaryJob.target_id,
    SummaryJob.status,
    SummaryJob.error_code,
    SummaryJob.model,
)
APPLY_COLUMNS = (SummaryJob.apply_title, SummaryJob.apply_summary, SummaryJob.apply_category)


@pytest.fixture
def switches(monkeypatch):
    monkeypatch.setattr(settings, "gemini_model", "gemini-fixed")
    monkeypatch.setattr(settings, "instagram_summary_model", "gpt-fixed")

    def turn(*, youtube, instagram):
        monkeypatch.setattr(settings, "youtube_summary_enabled", youtube)
        monkeypatch.setattr(settings, "instagram_summary_enabled", instagram)

    return turn


async def save(api, headers, url, *, shared=False, **extra):
    body = {"url" if shared else "original_url": url, **extra}
    return await request(
        api,
        "POST",
        "contents/share" if shared else "contents",
        headers=headers,
        status=201,
        json=body,
    )


async def stored_job(database_connection, content, columns=JOB_COLUMNS):
    row = (
        await database_connection.execute(
            select(*columns).where(SummaryJob.content_id == content["id"])
        )
    ).one_or_none()
    return None if row is None else tuple(row)


async def custom_category(api, headers):
    categories = await request(api, "GET", "categories", headers=headers)
    return next(c for c in categories if c["name"] != "미분류")


@pytest.mark.parametrize("enabled", [True, False])
@pytest.mark.parametrize("url", YOUTUBE_LINKS)
async def test_youtube_video_link_gets_a_youtube_job(
    api, database_connection, switches, url, enabled
):
    switches(youtube=enabled, instagram=True)
    headers, _, _ = await guest(api)

    content = await save(api, headers, url)

    assert content["original_url"] == f"https://www.youtube.com/watch?v={VIDEO_ID}"
    expected = ("queued", None) if enabled else ("skipped", "disabled")
    assert await stored_job(database_connection, content) == (
        "youtube", VIDEO_ID, *expected, "gemini-fixed",
    )
    assert (content["summary_status"], content["summary_error_code"]) == expected


@pytest.mark.parametrize("url", INSTAGRAM_POSTS)
async def test_instagram_post_links_are_queued(
    api, database_connection, switches, url
):
    switches(youtube=True, instagram=True)
    headers, _, _ = await guest(api)

    content = await save(api, headers, url)

    assert await stored_job(database_connection, content) == (
        "instagram", content["original_url"], "queued", None, "gpt-fixed",
    )
    assert (content["summary_status"], content["summary_error_code"]) == ("queued", None)


async def test_instagram_story_link_is_skipped_as_unsupported(api, database_connection, switches):
    switches(youtube=True, instagram=True)
    headers, _, _ = await guest(api)

    content = await save(api, headers, INSTAGRAM_STORY)

    assert await stored_job(database_connection, content) == (
        "instagram", content["original_url"], "skipped", "unsupported_content", "gpt-fixed",
    )


@pytest.mark.parametrize("url", [*INSTAGRAM_POSTS, INSTAGRAM_STORY])
async def test_instagram_link_is_disabled_while_its_switch_is_off(
    api, database_connection, switches, url
):
    # The switch is judged before the story check.
    switches(youtube=True, instagram=False)
    headers, _, _ = await guest(api)

    content = await save(api, headers, url)

    assert await stored_job(database_connection, content) == (
        "instagram", content["original_url"], "skipped", "disabled", "gpt-fixed",
    )


async def test_web_link_gets_no_job(api, database_connection, switches):
    switches(youtube=True, instagram=True)
    headers, _, _ = await guest(api)

    content = await save(api, headers, "https://example.com/article")

    assert await stored_job(database_connection, content) is None
    assert (content["summary_status"], content["summary_error_code"]) == ("not_requested", None)


@pytest.mark.parametrize("shared", [False, True])
@pytest.mark.parametrize("url", REFUSED_INSTAGRAM_LINKS)
async def test_instagram_link_that_is_not_a_post_gets_no_job(
    api, database_connection, switches, url, shared
):
    switches(youtube=True, instagram=True)
    headers, _, _ = await guest(api)

    await request(
        api,
        "POST",
        "contents/share" if shared else "contents",
        headers=headers,
        status=422,
        json={"url" if shared else "original_url": url},
    )

    for model in (Content, SummaryJob):
        assert await database_connection.scalar(select(func.count()).select_from(model)) == 0


async def test_screenshot_gets_no_job(api, database_connection, switches, png_bytes):
    switches(youtube=True, instagram=True)
    headers, _, _ = await guest(api)

    content = await request(
        api,
        "POST",
        "uploads/screenshots",
        headers=headers,
        status=201,
        files={"file": ("screen.png", png_bytes, "image/png")},
    )

    assert await stored_job(database_connection, content) is None
    assert content["summary_status"] == "not_requested"


@pytest.mark.parametrize(
    "fields,expected",
    [
        ({}, (True, True, True)),
        ({"title": "직접 제목"}, (False, True, True)),
        ({"title": "   "}, (True, True, True)),
        ({"summary": "직접 요약"}, (True, False, True)),
        ({"summary": "   "}, (True, True, True)),
    ],
)
@pytest.mark.parametrize("url", [YOUTUBE_LINKS[0], INSTAGRAM_POSTS[0]])
async def test_user_input_decides_what_the_summary_may_overwrite(
    api, database_connection, switches, url, fields, expected
):
    # Instagram payloads already hold the metadata title and summary, so only the
    # caller's report of typed input matters; YouTube reads the payload itself.
    switches(youtube=True, instagram=True)
    headers, _, _ = await guest(api)

    content = await save(api, headers, url, **fields)

    assert await stored_job(database_connection, content, APPLY_COLUMNS) == expected


@pytest.mark.parametrize("url", [YOUTUBE_LINKS[0], INSTAGRAM_POSTS[0]])
async def test_selected_category_is_never_overwritten(api, database_connection, switches, url):
    switches(youtube=True, instagram=True)
    headers, _, _ = await guest(api)
    category = await custom_category(api, headers)

    content = await save(api, headers, url, category_ids=[category["id"]])

    assert await stored_job(database_connection, content, APPLY_COLUMNS) == (True, True, False)


@pytest.mark.parametrize("url", [YOUTUBE_LINKS[0], INSTAGRAM_POSTS[0]])
async def test_shared_link_lets_the_summary_fill_every_field(
    api, database_connection, switches, url
):
    switches(youtube=True, instagram=True)
    headers, _, _ = await guest(api)

    content = await save(api, headers, url, shared=True)

    assert await stored_job(database_connection, content, APPLY_COLUMNS) == (True, True, True)
