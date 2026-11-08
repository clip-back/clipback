from uuid import uuid4

import pytest
from sqlalchemy import func, select

from app.integrations.metadata_client import MetadataClient
from app.models.content import Content
from app.models.content_event import ContentEvent
from app.models.summary_job import SummaryJob
from tests.integration.helpers import guest, request

pytestmark = pytest.mark.asyncio

BODY = {"original_url": "https://www.instagram.com/p/dup298/"}


async def count(connection, model, **where):
    return await connection.scalar(select(func.count()).select_from(model).filter_by(**where))


async def test_same_key_replays_one_content_without_new_work(
    api, database_connection, monkeypatch,
):
    headers, _, user = await guest(api)
    original = MetadataClient.extract_from_url
    calls = []

    async def metadata(self, url):
        calls.append(url)
        return await original(self, url)

    monkeypatch.setattr(MetadataClient, "extract_from_url", metadata)
    writes = {**headers, "Idempotency-Key": str(uuid4())}
    first = await request(api, "POST", "contents", status=201, headers=writes, json=BODY)
    assert await request(api, "POST", "contents", status=201, headers=writes, json=BODY) == first
    assert len(calls) == 1
    assert await count(database_connection, Content, user_id=user["id"]) == 1
    assert await count(database_connection, ContentEvent, user_id=user["id"]) == 1
    assert await count(database_connection, SummaryJob, content_id=first["id"]) == 1


async def test_key_conflict_delete_and_user_isolation(api):
    headers, _, _ = await guest(api)
    other, _, _ = await guest(api)
    key = str(uuid4())
    writes = {**headers, "Idempotency-Key": key}
    first = await request(api, "POST", "contents", status=201, headers=writes, json=BODY)
    await request(api, "POST", "contents", status=409, headers=writes,
                  json={**BODY, "is_favorite": True})
    await request(api, "POST", "contents", status=409, headers=writes,
                  json={"original_url": "https://www.instagram.com/p/other298/"})
    # The share route uses the same receipts; one key cannot cross request kinds.
    await request(api, "POST", "contents/share", status=409, headers=writes,
                  json={"url": BODY["original_url"]})
    separate = await request(api, "POST", "contents", status=201,
                             headers={**other, "Idempotency-Key": key}, json=BODY)
    assert separate["id"] != first["id"]
    await request(api, "DELETE", f"contents/{first['id']}", status=204, headers=headers)
    await request(api, "POST", "contents", status=410, headers=writes, json=BODY)
    new = await request(api, "POST", "contents", status=201,
                        headers={**headers, "Idempotency-Key": str(uuid4())}, json=BODY)
    assert new["id"] != first["id"]


async def test_share_key_cannot_replay_as_main_link_save(api):
    headers, _, _ = await guest(api)
    writes = {**headers, "Idempotency-Key": str(uuid4())}
    await request(api, "POST", "contents/share", status=201, headers=writes,
                  json={"url": BODY["original_url"]})
    await request(api, "POST", "contents", status=409, headers=writes, json=BODY)


async def test_invalid_key_is_rejected_and_headerless_saves_stay_separate(
    api, database_connection,
):
    headers, _, user = await guest(api)
    await request(api, "POST", "contents", status=422,
                  headers={**headers, "Idempotency-Key": "bad"}, json=BODY)
    first = await request(api, "POST", "contents", status=201, headers=headers, json=BODY)
    second = await request(api, "POST", "contents", status=201, headers=headers, json=BODY)
    assert first["id"] != second["id"]
    assert await count(database_connection, Content, user_id=user["id"]) == 2
