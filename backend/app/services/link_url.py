import re
from urllib.parse import urlparse, urlunparse

from fastapi import HTTPException

from app.schemas.content import ContentSource

INSTAGRAM_HOSTS = {"instagram.com", "www.instagram.com", "m.instagram.com"}
INSTAGRAM_CONTENT_PATH_PREFIXES = ("/p/", "/reel/", "/tv/", "/stories/")
URL_TRAILING_CHARS = ".,;:!?)]}>"
# `/p/<code>/`, `/reel/<code>/`, `/tv/<code>/`, also behind a username (`/<user>/reel/<code>/`).
POST_PATH_PATTERN = re.compile(r"/(?:[^/]+/)?(?:p|reels?|tv)/([^/]+)")


def is_instagram_url(url: str) -> bool:
    candidate = _with_default_scheme(url.strip().rstrip(URL_TRAILING_CHARS))
    host = urlparse(candidate).hostname
    return host is not None and _matches_domain(host, "instagram.com")


def normalize_instagram_url(url: str) -> str:
    candidate = _with_default_scheme(url.strip().rstrip(URL_TRAILING_CHARS))
    parsed = urlparse(candidate)
    host = parsed.hostname.lower() if parsed.hostname else ""
    if host not in INSTAGRAM_HOSTS:
        raise HTTPException(status_code=422, detail="Only Instagram URLs are supported")

    path = _normalize_path(parsed.path)
    if not _is_supported_instagram_path(path):
        raise HTTPException(status_code=422, detail="Unsupported Instagram URL path")

    return urlunparse(("https", "www.instagram.com", path, "", "", ""))


def instagram_post_type(url: str) -> str | None:
    """Return `reel`, `p`, `tv` or `stories` for a normalized Instagram content link."""
    parsed = urlparse(url)
    if (parsed.hostname or "").lower() not in INSTAGRAM_HOSTS:
        return None
    parts = [part for part in parsed.path.split("/") if part]
    if len(parts) >= 2 and f"/{parts[0]}/" in INSTAGRAM_CONTENT_PATH_PREFIXES:
        return parts[0]
    return None


def instagram_post_code(url: str) -> str | None:
    """Return the shortcode of an Instagram post link, or None when it is not one."""
    parsed = urlparse(url)
    if (parsed.hostname or "").lower() not in INSTAGRAM_HOSTS:
        return None
    match = POST_PATH_PATTERN.match(parsed.path)
    return match.group(1) if match else None


def infer_content_source(url: str) -> ContentSource:
    host = (urlparse(url).hostname or "").lower()
    if _matches_domain(host, "instagram.com"):
        return ContentSource.INSTAGRAM
    if _matches_domain(host, "youtube.com") or host == "youtu.be":
        return ContentSource.YOUTUBE
    if _matches_domain(host, "tiktok.com"):
        return ContentSource.TIKTOK
    return ContentSource.WEB


def _with_default_scheme(url: str) -> str:
    return url if "://" in url else f"https://{url}"


def _normalize_path(path: str) -> str:
    path_parts = [part for part in path.split("/") if part]
    return f"/{'/'.join(path_parts)}/"


def _is_supported_instagram_path(path: str) -> bool:
    return any(
        path.startswith(prefix) and len(path) > len(prefix)
        for prefix in INSTAGRAM_CONTENT_PATH_PREFIXES
    )


def _matches_domain(host: str, domain: str) -> bool:
    return host == domain or host.endswith(f".{domain}")
