import re
from urllib.parse import parse_qs, urlsplit

from fastapi import HTTPException

HOSTS = {"youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be"}
VIDEO_ID = re.compile(r"[A-Za-z0-9_-]{11}")


def is_youtube_url(url: str) -> bool:
    try:
        host = urlsplit(url).hostname or ""
    except ValueError as exc:
        raise HTTPException(422, "Invalid video URL") from exc
    return host in HOSTS or host.endswith(".youtube.com") or host.endswith(".youtu.be")


def normalize_youtube_url(url: str) -> tuple[str, str]:
    try:
        parsed = urlsplit(url)
        if (
            parsed.scheme not in {"http", "https"}
            or parsed.hostname not in HOSTS
            or parsed.username
            or parsed.password
            or parsed.port not in {None, 80, 443}
        ):
            raise ValueError
        query = parse_qs(parsed.query)
        path = parsed.path.rstrip("/")
        if parsed.hostname == "youtu.be":
            video_id = path.removeprefix("/")
        elif path == "/watch" and len(query.get("v", [])) == 1:
            video_id = query["v"][0]
        elif re.fullmatch(r"/(shorts|live)/[^/]+", path):
            video_id = path.rsplit("/", 1)[1]
        else:
            raise ValueError
        if not VIDEO_ID.fullmatch(video_id):
            raise ValueError
    except ValueError as exc:
        raise HTTPException(422, "Invalid YouTube video URL") from exc
    canonical = f"https://www.youtube.com/watch?v={video_id}"
    start = query.get("t", query.get("start", []))
    if not start and parsed.fragment:
        start = parse_qs(parsed.fragment).get("t", [])
    if len(start) == 1:
        value = start[0]
        if value.isascii() and value.isdigit():
            seconds = int(value)
        elif re.fullmatch(r"(?=\d)(?:\d+h)?(?:\d+m)?(?:\d+s)?", value):
            seconds = sum(
                int(n) * {"h": 3600, "m": 60, "s": 1}[unit]
                for n, unit in re.findall(r"(\d+)([hms])", value)
            )
        else:
            seconds = 0
        if 0 < seconds <= 2_147_483_647:
            return canonical + f"&t={seconds}s", video_id
    return canonical, video_id
