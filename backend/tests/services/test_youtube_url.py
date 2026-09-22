import pytest
from fastapi import HTTPException

from app.services.youtube_url import normalize_youtube_url

VIDEO = "dQw4w9WgXcQ"


@pytest.mark.parametrize(
    "url, suffix",
    [
        (f"https://youtu.be/{VIDEO}?si=tracking&t=1m2s", "&t=62s"),
        (f"http://m.youtube.com/watch?v={VIDEO}&list=abc&start=30", "&t=30s"),
        (f"https://youtube.com/shorts/{VIDEO}", ""),
        (f"https://www.youtube.com/live/{VIDEO}#t=12", "&t=12s"),
        (f"https://youtube.com/watch?v={VIDEO}&t=-1", ""),
    ],
)
def test_normalization(url, suffix):
    assert normalize_youtube_url(url) == (f"https://www.youtube.com/watch?v={VIDEO}{suffix}", VIDEO)


@pytest.mark.parametrize(
    "url",
    [
        "https://youtube.com/playlist?list=x",
        "https://youtube.com/@channel",
        "https://youtube.com/clip/abcdefghijk",
        "https://youtube.com/watch?v=short",
        f"https://youtube.com.evil.test/watch?v={VIDEO}",
        f"https://evil.youtube.com/watch?v={VIDEO}",
        f"https://youtube.com@evil.test/watch?v={VIDEO}",
        f"https://youtube.com:444/watch?v={VIDEO}",
        f"https://youtu.be/{VIDEO}/extra",
        f"https://youtube.com/watch?v={VIDEO}&v={VIDEO}",
    ],
)
def test_invalid(url):
    with pytest.raises(HTTPException) as exc:
        normalize_youtube_url(url)
    assert exc.value.status_code == 422


def test_openapi_summary_contract():
    from app.main import create_app

    schema = create_app().openapi()["components"]["schemas"]["ContentRead"]["properties"]
    assert schema["summary_status"]["enum"] == [
        "not_requested",
        "queued",
        "processing",
        "completed",
        "failed",
        "skipped",
    ]
    assert {"type": "null"} in schema["summary_error_code"]["anyOf"]
