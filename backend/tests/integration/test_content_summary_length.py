import pytest
from sqlalchemy import insert

from app.models.content import Content, ContentSource, ContentType
from tests.integration.helpers import guest, request

pytestmark = pytest.mark.asyncio

LONG_SUMMARY = "가" * 1000 + "끝"


async def test_manual_summary_over_1000_characters_is_saved_and_read_in_full(api):
    headers, _, _ = await guest(api)

    created = await request(
        api, "POST", "contents", headers=headers, status=201,
        json={"original_url": "https://example.com/manual", "summary": f" {LONG_SUMMARY} "},
    )

    assert created["summary"] == LONG_SUMMARY
    detail = await request(api, "GET", f"contents/{created['id']}", headers=headers)
    assert detail["summary"] == LONG_SUMMARY


async def test_preexisting_summary_over_1000_characters_is_read_in_full(api, database_connection):
    headers, _, user = await guest(api)
    content_id = await database_connection.scalar(
        insert(Content).values(
            user_id=user["id"], content_type=ContentType.LINK, source=ContentSource.WEB,
            title="기존 제목", summary=LONG_SUMMARY, original_url="https://example.com/legacy",
        ).returning(Content.id)
    )

    detail = await request(api, "GET", f"contents/{content_id}", headers=headers)

    assert detail["summary"] == LONG_SUMMARY
