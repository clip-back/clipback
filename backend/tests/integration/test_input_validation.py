import json
from uuid import UUID, uuid4

import pytest
from sqlalchemy import func, select
from starlette import formparsers

from app.models.apple_auth import AppleAuthChallenge
from app.models.category import Category
from app.models.category_submission import CategorySubmission
from app.models.content import Content
from app.models.content_asset import ContentAsset
from app.models.content_event import ContentEvent
from app.models.share_receipt import ShareReceipt
from app.models.social_identity import SocialIdentity
from app.models.tag import Tag
from app.models.user import User
from tests.integration.helpers import guest, link, request
from tests.integration.test_apple_auth import apple_payload, apple_provider  # noqa: F401

pytestmark = pytest.mark.asyncio

NUL = "a\x00b"
SURROGATE = "a\ud83db"
LINK_URL = "https://example.com/input-validation"
SHARE_URL = "https://www.instagram.com/p/ABC123/"
TEXT_ERROR = "Value error, Text contains unsupported characters"
TAG_ERROR = "Value error, Tag name contains unsupported characters"


def json_request(headers, payload):
    return {
        "headers": {**headers, "Content-Type": "application/json"},
        "content": json.dumps(payload).encode(),
    }


def with_submission_key(headers, keyed):
    return {**headers, "Idempotency-Key": str(uuid4())} if keyed else headers


def assert_text_error(response, loc):
    assert response.status_code == 422, response.text
    error, = response.json()["detail"]
    assert error["loc"] == loc
    assert error["msg"] == TEXT_ERROR


async def count_rows(connection, model, *criteria):
    return await connection.scalar(select(func.count()).select_from(model).where(*criteria))


@pytest.mark.parametrize("keyed", [False, True], ids=["keyless", "keyed"])
@pytest.mark.parametrize(("field", "value"), [
    pytest.param("title", NUL, id="title-nul"),
    pytest.param("summary", NUL, id="summary-nul"),
    pytest.param("summary", SURROGATE, id="summary-surrogate"),
])
async def test_content_text_is_rejected_before_save(api, database_connection, keyed, field, value):
    headers, _, user = await guest(api)
    payload = {"original_url": LINK_URL, field: value}
    response = await api.post(
        "/api/v1/contents", **json_request(with_submission_key(headers, keyed), payload),
    )

    assert_text_error(response, ["body", field])
    assert await count_rows(database_connection, Content, Content.user_id == user["id"]) == 0
    assert await count_rows(
        database_connection, ShareReceipt, ShareReceipt.user_id == user["id"],
    ) == 0


@pytest.mark.parametrize("keyed", [False, True], ids=["keyless", "keyed"])
@pytest.mark.parametrize("field", ["name", "color"])
async def test_category_creation_nul_is_rejected(api, database_connection, keyed, field):
    headers, _, user = await guest(api)
    payload = {"name": "분류", "color": "#68B5FF"}
    payload[field] = NUL
    categories_before = await count_rows(
        database_connection, Category, Category.user_id == user["id"],
    )
    response = await api.post(
        "/api/v1/categories", headers=with_submission_key(headers, keyed), json=payload,
    )

    assert_text_error(response, ["body", field])
    assert await count_rows(
        database_connection, Category, Category.user_id == user["id"],
    ) == categories_before
    assert await count_rows(
        database_connection, CategorySubmission, CategorySubmission.user_id == user["id"],
    ) == 0


@pytest.mark.parametrize("keyed", [False, True], ids=["keyless", "keyed"])
@pytest.mark.parametrize("field", ["name", "color"])
async def test_category_update_nul_leaves_category_unchanged(
    api, database_connection, keyed, field,
):
    headers, _, user = await guest(api)
    before = await request(
        api, "POST", "categories", headers=headers, status=201,
        json={"name": "원래 이름", "color": "#68B5FF"},
    )
    response = await api.patch(
        f"/api/v1/categories/{before['id']}",
        headers=with_submission_key(headers, keyed),
        json={field: NUL},
    )

    assert_text_error(response, ["body", field])
    rows = (await database_connection.execute(
        select(Category.id, Category.name, Category.color).where(Category.id == before["id"]),
    )).all()
    assert rows == [(before["id"], before["name"], before["color"])]
    assert await count_rows(
        database_connection, CategorySubmission, CategorySubmission.user_id == user["id"],
    ) == 0


async def test_feed_search_rejects_nul(api):
    headers, _, _ = await guest(api)
    await link(api, headers, title="검색 대상")
    response = await api.get("/api/v1/feed", headers=headers, params={"q": NUL})
    assert_text_error(response, ["query", "q"])


@pytest.mark.parametrize("purpose", ["login", "upgrade"])
@pytest.mark.parametrize("value", [NUL, SURROGATE], ids=["nul", "surrogate"])
async def test_apple_display_name_rejection_keeps_generic_response(
    api, database_connection, apple_provider, purpose, value,  # noqa: F811
):
    headers, _, guest_user = await guest(api) if purpose == "upgrade" else ({}, None, None)
    payload = await apple_payload(api, headers=headers, purpose=purpose, name=value)
    path = "/api/v1/auth/social/apple" + ("/upgrade" if purpose == "upgrade" else "")
    users_before = await count_rows(database_connection, User)
    identities_before = await count_rows(database_connection, SocialIdentity)

    response = await api.post(path, **json_request(headers, payload))

    assert response.status_code == 422, response.text
    assert response.content == b'{"detail":"Invalid authentication request"}'
    assert response.headers["cache-control"] == "no-store"
    assert await count_rows(database_connection, User) == users_before
    assert await count_rows(database_connection, SocialIdentity) == identities_before
    consumed_at = await database_connection.scalar(
        select(AppleAuthChallenge.consumed_at).where(
            AppleAuthChallenge.id == UUID(payload["challenge_id"]),
        ),
    )
    assert consumed_at is None
    if guest_user:
        assert await request(api, "GET", "users/me", headers=headers) == guest_user


@pytest.mark.parametrize(("operation", "field", "legacy_loc"), [
    ("link", "title", ["body", "title"]),
    ("create", "name", ["body", "name"]),
    ("create", "color", ["body", "color"]),
    ("update", "name", ["body", "name", "constrained-str"]),
    ("update", "color", ["body", "color"]),
])
async def test_existing_surrogate_error_bytes_are_preserved(api, operation, field, legacy_loc):
    headers, _, _ = await guest(api)
    if operation == "link":
        response = await api.post(
            "/api/v1/contents",
            **json_request(headers, {"original_url": LINK_URL, field: SURROGATE}),
        )
    elif operation == "create":
        payload = {"name": "분류", field: SURROGATE}
        response = await api.post("/api/v1/categories", **json_request(headers, payload))
    else:
        category = await request(
            api, "POST", "categories", headers=headers, status=201, json={"name": "분류"},
        )
        response = await api.patch(
            f"/api/v1/categories/{category['id']}", **json_request(headers, {field: SURROGATE}),
        )

    assert response.status_code == 422
    details = [{
        "type": "string_unicode",
        "loc": legacy_loc,
        "msg": "Input should be a valid string, unable to parse raw data as a unicode string",
        "input": SURROGATE,
    }]
    if (operation, field) == ("update", "name"):
        details.append({
            "type": "none_required",
            "loc": ["body", "name", "none"],
            "msg": "Input should be None",
            "input": SURROGATE,
        })
    assert response.content == json.dumps({"detail": details}, separators=(",", ":")).encode()


@pytest.mark.parametrize("keyed", [False, True], ids=["keyless", "keyed"])
async def test_shared_metadata_and_urls_keep_accepting_nul(api, database_connection, keyed):
    headers, _, _ = await guest(api)
    url = LINK_URL + "/" + NUL
    direct = await request(api, "POST", "contents", headers=headers, status=201,
                           json={"original_url": url})
    assert direct["original_url"] == LINK_URL + "/a%00b"

    share = await request(
        api, "POST", "contents/share", headers=with_submission_key(headers, keyed), status=201,
        json={
            "url": SHARE_URL + NUL,
            "raw_text": "공유 " + NUL,
            "source_app": NUL,
            "platform": NUL,
            "mime_type": NUL,
            "attachments": [{"filename": NUL}],
        },
    )
    assert share["original_url"] == SHARE_URL + "a%00b/"
    metadata = await database_connection.scalar(
        select(ContentEvent.metadata_json).where(ContentEvent.content_id == share["id"]),
    )
    assert "\\u0000" in metadata
    event = json.loads(metadata)
    for field in ("source_app", "platform", "mime_type"):
        assert event[field] == NUL
    assert event["attachment_count"] == 1

    raw_text_share = await request(
        api, "POST", "contents/share", headers=with_submission_key(headers, keyed), status=201,
        json={"raw_text": f"공유 {SHARE_URL} {NUL}"},
    )
    assert raw_text_share["original_url"] == SHARE_URL


def screenshot_form(png_bytes, *tags, extra_parts=()):
    boundary = b"clipback-test"
    parts = [
        b'Content-Disposition: form-data; name="file"; filename="image.png"\r\n'
        b"Content-Type: image/png\r\n\r\n" + png_bytes,
        *(b'Content-Disposition: form-data; name="tag_names"\r\n\r\n' + tag for tag in tags),
        *extra_parts,
    ]
    separator = b"--" + boundary + b"\r\n"
    body = b"".join(separator + part + b"\r\n" for part in parts) + b"--" + boundary + b"--\r\n"
    return body, "multipart/form-data; boundary=" + boundary.decode()


@pytest.fixture
def multipart_tempfiles(monkeypatch):
    files = []
    open_file = formparsers.SpooledTemporaryFile

    def record_file(*args, **kwargs):
        file = open_file(*args, **kwargs)
        files.append(file)
        return file

    monkeypatch.setattr(formparsers, "SpooledTemporaryFile", record_file)
    return files


@pytest.mark.parametrize(
    "authorization", [None, "Bearer invalid-token"], ids=["missing", "invalid"],
)
async def test_screenshot_invalid_utf8_preserves_authentication_failure(
    api, png_bytes, multipart_tempfiles, authorization,
):
    body, content_type = screenshot_form(png_bytes, b"\xff")
    headers = {"Content-Type": content_type}
    if authorization is not None:
        headers["Authorization"] = authorization

    response = await api.post("/api/v1/uploads/screenshots", headers=headers, content=body)

    assert response.status_code == 401, response.text
    assert response.content == b'{"detail":"Invalid authentication credentials"}'
    file, = multipart_tempfiles
    assert file.closed


async def test_screenshot_invalid_utf8_preserves_multipart_structure_error(
    api, png_bytes, multipart_tempfiles,
):
    body, content_type = screenshot_form(
        png_bytes, b"\xff", extra_parts=(b"Content-Disposition: form-data\r\n\r\ninvalid",),
    )
    response = await api.post(
        "/api/v1/uploads/screenshots", headers={"Content-Type": content_type}, content=body,
    )

    assert response.status_code == 400, response.text
    assert response.json() == {
        "detail": 'The Content-Disposition header field "name" must be provided.',
    }
    file, = multipart_tempfiles
    assert file.closed


async def test_screenshot_category_ids_uses_declared_multipart_charset(api, png_bytes):
    headers, _, _ = await guest(api)
    body, content_type = screenshot_form(
        png_bytes, b"valid",
        extra_parts=(b'Content-Disposition: form-data; name="category_ids"\r\n\r\n1\xc3\xbf',),
    )
    headers["Content-Type"] = content_type + "; charset=iso-8859-1"

    response = await api.post("/api/v1/uploads/screenshots", headers=headers, content=body)

    assert response.status_code == 422
    error, = response.json()["detail"]
    assert error["type"] == "int_parsing"
    assert error["loc"] == ["body", "category_ids", 0]
    assert error["input"] == "1Ã¿"


@pytest.mark.parametrize("keyed", [False, True], ids=["keyless", "keyed"])
@pytest.mark.parametrize(("tag", "charset"), [
    pytest.param(b"\xed\xa0\xbd", "", id="surrogate-encoding"),
    pytest.param(b"\xff", "", id="invalid-byte"),
    pytest.param(b"\xff", "; charset=iso-8859-1", id="invalid-byte-with-charset"),
    pytest.param(b"\xe2\x82", "", id="truncated"),
    pytest.param(b"a\x00b", "", id="nul"),
])
async def test_screenshot_invalid_tag_leaves_no_rows_or_original(
    api, database_connection, png_bytes, tmp_path, multipart_tempfiles, keyed, tag, charset,
):
    headers, _, user = await guest(api)
    body, content_type = screenshot_form(png_bytes, b"valid", tag)
    headers = with_submission_key({**headers, "Content-Type": content_type + charset}, keyed)

    assets_before = await count_rows(database_connection, ContentAsset)

    response = await api.post("/api/v1/uploads/screenshots", headers=headers, content=body)

    assert response.status_code == 422, response.text
    assert response.headers["content-type"] == "application/json"
    error, = response.json()["detail"]
    assert error["type"] == "value_error"
    assert error["loc"] == ["tag_names"]
    assert error["msg"] == TAG_ERROR
    assert error["input"] == (["valid", NUL] if tag == b"a\x00b" else None)
    for model in (Content, Tag, ShareReceipt):
        assert await count_rows(database_connection, model, model.user_id == user["id"]) == 0
    assert await count_rows(database_connection, ContentAsset) == assets_before
    assert not any(path.is_file() for path in tmp_path.rglob("*"))
    file, = multipart_tempfiles
    assert file.closed


@pytest.mark.parametrize("keyed", [False, True], ids=["keyless", "keyed"])
@pytest.mark.parametrize("charset", ["", "; charset=iso-8859-1"], ids=["default", "declared"])
async def test_screenshot_valid_utf8_tags_are_saved_as_sent(
    api, database_connection, png_bytes, keyed, charset,
):
    headers, _, user = await guest(api)
    tags = ["ÿ", "😀", "한글"]
    body, content_type = screenshot_form(png_bytes, *(tag.encode() for tag in tags))
    headers = with_submission_key({**headers, "Content-Type": content_type + charset}, keyed)

    response = await api.post("/api/v1/uploads/screenshots", headers=headers, content=body)

    assert response.status_code == 201, response.text
    assert {item["name"] for item in response.json()["tags"]} == set(tags)
    assert set(await database_connection.scalars(
        select(Tag.name).where(Tag.user_id == user["id"]),
    )) == set(tags)
