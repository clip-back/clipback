import json
import logging
from datetime import UTC, datetime, timedelta
from types import SimpleNamespace

import pytest
from sqlalchemy import select, update

from app.core.config import settings
from app.models.content_event import ContentEvent
from app.models.summary_job import SummaryJob
from app.models.tag import Tag
from app.services import usage_limits
from tests.integration.helpers import guest, link, request
from tests.integration.test_save_ai_tags import provider as provider, save_provider as save_provider
from tests.integration.test_summary_log_contract import (
    REEL,
    YOUTUBE_LINK,
    answer,
    gemini_text,
    instagram_client,
    make_worker as make_worker,
    youtube_client,
)
from tests.integrations.test_instagram_summary_client import completion

pytestmark = pytest.mark.asyncio

MARKER = "태그표식7f3a"


def summary_client(kind, **fields):
    if kind == "instagram":
        return instagram_client(openai=lambda request: completion(category_id=None, **fields))
    answer = {"title": "제목", "headline": "핵심", "points": ["요점"], "category_id": None}
    return youtube_client(gemini=gemini_text(json.dumps({**answer, **fields}, ensure_ascii=False)))


async def detail(api, headers, content):
    return await request(api, "GET", f"contents/{content['id']}", headers=headers)


async def tag_names(connection, user):
    return set(await connection.scalars(select(Tag.name).where(Tag.user_id == user["id"])))


@pytest.mark.parametrize("kind,url", [("youtube", YOUTUBE_LINK), ("instagram", REEL)])
@pytest.mark.parametrize(
    "tags,expected",
    [
        pytest.param(
            [f"#{MARKER}", None, "요리", "김치", "레시피"], [MARKER, "요리", "김치"], id="tags"
        ),
        pytest.param(MARKER, [], id="malformed-tags"),
        pytest.param([f"#{MARKER}", "요\x00리", "김치"], [MARKER, "김치"], id="nul-item"),
    ],
)
async def test_queued_summary_adds_tags_to_detail_without_logging_them(
    api, database_connection, make_worker, save_provider, caplog, capsys, kind, url, tags, expected
):
    caplog.set_level(logging.DEBUG, logger="app")
    headers, _, user = await guest(api)
    queued = await link(api, headers, original_url=url)
    assert queued["summary_status"] == "queued"
    assert queued["tags"] == []
    assert save_provider.calls == (["recommend"] if kind == "instagram" else [])

    # The saved job predates construction of the worker that can apply tags.
    worker = make_worker(**{kind: summary_client(kind, tags=tags)})
    assert await worker.run_once()

    completed = await detail(api, headers, queued)
    assert completed["summary_status"] == "completed"
    assert completed["summary_error_code"] is None
    summary = {
        "youtube": "핵심\n• 요점",
        "instagram": "성수동 카페 신메뉴 출시\n• 대표 메뉴와 가격 안내",
    }
    assert completed["summary"] == summary[kind]
    assert [tag["name"] for tag in completed["tags"]] == expected
    ids = [tag["id"] for tag in completed["tags"]]
    assert ids == sorted(ids)
    assert await tag_names(database_connection, user) == set(expected)
    assert save_provider.calls == (["recommend"] if kind == "instagram" else [])
    event_metadata = await database_connection.scalars(
        select(ContentEvent.metadata_json).where(ContentEvent.content_id == queued["id"])
    )
    assert all(MARKER not in (value or "") for value in event_metadata)
    output = capsys.readouterr()
    assert MARKER not in caplog.text + output.out + output.err


@pytest.mark.parametrize(
    "reason,status", [("disabled", "skipped"), ("monthly_limit_exceeded", "skipped"),
                      ("video_unavailable", "skipped"), ("invalid_response", "failed")],
)
async def test_skipped_and_failed_summaries_do_not_add_tags(
    api, database_connection, make_worker, save_provider, monkeypatch, reason, status
):
    if reason == "video_unavailable":
        client = youtube_client(preflight=answer(json={"items": []}))
    else:
        client = summary_client("youtube", headline="", tags=[MARKER])
    worker = make_worker(youtube=client)
    headers, _, user = await guest(api)
    if reason == "disabled":
        monkeypatch.setattr(settings, "youtube_summary_enabled", False)
    elif reason == "monthly_limit_exceeded":
        monkeypatch.setattr(usage_limits, "GUEST_SUMMARY_MONTHLY_LIMIT", 1)
        await link(api, headers, original_url=REEL)
        monkeypatch.setattr(settings, "instagram_summary_enabled", False)
    content = await link(api, headers, original_url=YOUTUBE_LINK)
    monkeypatch.setattr(settings, "youtube_summary_enabled", True)

    assert await worker.run_once() == (reason in {"video_unavailable", "invalid_response"})
    completed = await detail(api, headers, content)
    assert (completed["summary_status"], completed["summary_error_code"]) == (status, reason)
    assert completed["tags"] == []
    assert await tag_names(database_connection, user) == set()


@pytest.mark.parametrize("action", ["replace-tags", "delete-content"])
async def test_summary_does_not_write_tags_over_an_edit_or_after_deletion(
    api, database_connection, make_worker, action
):
    headers, _, user = await guest(api)
    client = summary_client("instagram", tags=[MARKER])
    manual_tags = []

    async def summarize(*args):
        result = await client.summarize(*args)
        if action == "replace-tags":
            updated = await request(
                api, "PUT", f"{path}/tags", headers=headers, json={"tag_names": ["직접 선택"]}
            )
            manual_tags.extend(updated["tags"])
        else:
            await request(api, "DELETE", path, headers=headers, status=204)
        return result

    worker = make_worker(instagram=SimpleNamespace(summarize=summarize))
    content = await link(api, headers, original_url=REEL)
    path = f"contents/{content['id']}"
    assert await worker.run_once()

    if action == "replace-tags":
        completed = await detail(api, headers, content)
        assert completed["summary_status"] == "completed"
        assert [tag["name"] for tag in manual_tags] == ["직접 선택"]
        assert completed["tags"] == manual_tags
        assert await tag_names(database_connection, user) == {"직접 선택"}
    else:
        await request(api, "GET", path, headers=headers, status=404)
        assert await tag_names(database_connection, user) == set()


async def test_expired_lease_cannot_write_tags_after_another_worker_claims(
    api, database_connection, make_worker
):
    headers, _, user = await guest(api)
    fresh_client = summary_client("instagram", tags=["재점유 태그"])
    next_worker = make_worker(instagram=fresh_client)
    stale_client = summary_client("instagram", tags=[MARKER])

    async def summarize(*args):
        result = await stale_client.summarize(*args)
        await database_connection.execute(
            update(SummaryJob).where(SummaryJob.content_id == content["id"])
            .values(lease_expires_at=datetime.now(UTC) - timedelta(seconds=1))
        )
        recovered = await next_worker.claim()
        assert recovered.content_id == content["id"]
        reclaimed.append(recovered)
        return result

    reclaimed = []
    first_worker = make_worker(instagram=SimpleNamespace(summarize=summarize))
    content = await link(api, headers, original_url=REEL)
    assert await first_worker.run_once()

    (claimed,) = reclaimed
    processing = await detail(api, headers, content)
    assert processing["summary_status"] == "processing"
    assert processing["tags"] == []
    assert await tag_names(database_connection, user) == set()

    result = await fresh_client.summarize(claimed.target_id, claimed.model, claimed.candidates)
    await next_worker.finish(claimed.content_id, user["id"], claimed.lease_token, result, None)
    completed = await detail(api, headers, content)
    assert completed["summary_status"] == "completed"
    assert [tag["name"] for tag in completed["tags"]] == ["재점유 태그"]
    assert await tag_names(database_connection, user) == {"재점유 태그"}
