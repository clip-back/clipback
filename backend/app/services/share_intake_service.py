from __future__ import annotations

import json
import re
from urllib.parse import urlparse, urlunparse

from fastapi import HTTPException

from app.schemas.content import (
    ContentCreate,
    ContentRead,
    ContentShareCreate,
    ContentSource,
    ContentType,
)
from app.services.content_service import ContentService


INSTAGRAM_HOSTS = {"instagram.com", "www.instagram.com", "m.instagram.com"}
INSTAGRAM_CONTENT_PATH_PREFIXES = ("/p/", "/reel/", "/tv/", "/stories/")
URL_PATTERN = re.compile(r"https?://[^\s<>'\"]+")
URL_TRAILING_CHARS = ".,;:!?)]}>"


class ShareIntakeService:
    def __init__(self, content_service: ContentService) -> None:
        self.content_service = content_service

    async def create_instagram_content(
        self,
        *,
        user_id: int,
        payload: ContentShareCreate,
    ) -> ContentRead:
        url, url_source = self._select_url(payload)
        normalized_url = self.normalize_instagram_url(url)
        metadata_json = self._build_metadata_json(
            payload=payload,
            extracted_url=normalized_url,
            url_source=url_source,
        )

        return await self.content_service.create_content(
            user_id=user_id,
            payload=ContentCreate(
                content_type=ContentType.LINK,
                source=ContentSource.INSTAGRAM,
                original_url=normalized_url,
                category_ids=payload.category_ids,
                is_favorite=payload.is_favorite,
            ),
            event_metadata_json=metadata_json,
        )

    def _select_url(self, payload: ContentShareCreate) -> tuple[str, str]:
        if payload.url and payload.url.strip():
            return payload.url.strip(), "url"

        raw_text_url = self._extract_first_url(payload.raw_text)
        if raw_text_url is not None:
            return raw_text_url, "raw_text"

        raise HTTPException(status_code=422, detail="Instagram URL is required")

    @staticmethod
    def _extract_first_url(raw_text: str | None) -> str | None:
        if raw_text is None:
            return None

        match = URL_PATTERN.search(raw_text)
        if match is None:
            return None

        return match.group(0).rstrip(URL_TRAILING_CHARS)

    @staticmethod
    def normalize_instagram_url(url: str) -> str:
        candidate = url.strip().rstrip(URL_TRAILING_CHARS)
        if "://" not in candidate:
            candidate = f"https://{candidate}"

        parsed = urlparse(candidate)
        host = parsed.hostname.lower() if parsed.hostname else ""
        if host not in INSTAGRAM_HOSTS:
            raise HTTPException(status_code=422, detail="Only Instagram URLs are supported")

        path = ShareIntakeService._normalize_path(parsed.path)
        if not ShareIntakeService._is_supported_instagram_path(path):
            raise HTTPException(status_code=422, detail="Unsupported Instagram URL path")

        return urlunparse(("https", "www.instagram.com", path, "", "", ""))

    @staticmethod
    def _normalize_path(path: str) -> str:
        path_parts = [part for part in path.split("/") if part]
        return f"/{'/'.join(path_parts)}/"

    @staticmethod
    def _is_supported_instagram_path(path: str) -> bool:
        return any(
            path.startswith(prefix) and len(path) > len(prefix)
            for prefix in INSTAGRAM_CONTENT_PATH_PREFIXES
        )

    @staticmethod
    def _build_metadata_json(
        *,
        payload: ContentShareCreate,
        extracted_url: str,
        url_source: str,
    ) -> str:
        metadata = {
            "source_app": payload.source_app,
            "platform": payload.platform,
            "mime_type": payload.mime_type,
            "attachment_count": len(payload.attachments),
            "extracted_url": extracted_url,
            "url_source": url_source,
        }
        return json.dumps(metadata, ensure_ascii=False, separators=(",", ":"))
