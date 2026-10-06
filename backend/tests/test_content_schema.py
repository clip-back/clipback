import pytest
from pydantic import ValidationError

from app.main import create_app
from app.schemas.content import ContentCreate, ContentShareCreate, ContentType


def test_content_url_openapi_length_matches_storage_limit():
    schemas = create_app().openapi()["components"]["schemas"]
    url = schemas["ContentCreate"]["properties"]["original_url"]
    assert next(item for item in url["anyOf"] if item["type"] == "string")["maxLength"] == 2048


def test_optional_url_and_shared_text_limits_are_preserved():
    assert ContentCreate(content_type=ContentType.SCREENSHOT).original_url is None
    assert ContentShareCreate(raw_text="x" * 5000).raw_text == "x" * 5000
    with pytest.raises(ValidationError):
        ContentShareCreate(raw_text="x" * 5001)


@pytest.mark.parametrize("url", ["ftp://example.com/a", "not a URL"])
def test_original_url_still_requires_http_url(url):
    with pytest.raises(ValidationError):
        ContentCreate(original_url=url)
