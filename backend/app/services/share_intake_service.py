from __future__ import annotations

import re

from fastapi import HTTPException
from pydantic import ValidationError

from app.schemas.content import (
    MAX_CONTENT_URL_LENGTH,
    ContentCreate,
    ContentRead,
    ContentShareCreate,
    ContentSource,
    ContentType,
)
from app.services.content_service import ContentService
from app.services.extraction_service import ExtractionService
from app.services.link_url import URL_TRAILING_CHARS, normalize_instagram_url
from app.services.youtube_url import is_youtube_url, normalize_youtube_url

URL_PATTERN = re.compile(r"https?://[^\s<>'\"]+")


class ShareIntakeService:
    def __init__(
        self,
        content_service: ContentService,
        extraction_service: ExtractionService,
    ) -> None:
        self.content_service = content_service
        self.extraction_service = extraction_service

    async def create_instagram_content(
        self,
        *,
        user_id: int,
        payload: ContentShareCreate,
    ) -> ContentRead:
        url, url_source = self._select_url(payload)
        youtube_url = is_youtube_url(url)
        if youtube_url:
            normalized_url, _ = normalize_youtube_url(url)
        else:
            normalized_url = normalize_instagram_url(url)
        try:
            content_payload = ContentCreate(
                content_type=ContentType.LINK,
                source=ContentSource.YOUTUBE if youtube_url else ContentSource.INSTAGRAM,
                original_url=normalized_url,
                category_ids=payload.category_ids,
                tag_names=payload.tag_names,
                is_favorite=payload.is_favorite,
            )
        except ValidationError as exc:
            if all(error["loc"] == ("original_url",) for error in exc.errors()):
                raise HTTPException(
                    status_code=422,
                    detail="original_url must be a valid HTTP(S) URL of at most "
                    f"{MAX_CONTENT_URL_LENGTH} characters after normalization",
                ) from exc
            raise
        if youtube_url:
            return await self.content_service.create_content(
                user_id=user_id,
                payload=content_payload,
            )
        extraction = await self.extraction_service.enrich_link(content_payload)
        enriched_payload = self.extraction_service.apply_to_payload(content_payload, extraction)
        metadata_json = self.extraction_service.build_event_metadata_json(
            extraction,
            base=self._build_event_metadata(
                payload=payload,
                extracted_url=normalized_url,
                url_source=url_source,
            ),
        )

        return await self.content_service.create_content(
            user_id=user_id,
            payload=enriched_payload,
            event_metadata_json=metadata_json,
            recommendation_shared_text=payload.raw_text,
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
        return normalize_instagram_url(url)

    @staticmethod
    def _build_event_metadata(
        *,
        payload: ContentShareCreate,
        extracted_url: str,
        url_source: str,
    ) -> dict[str, object]:
        return {
            "source_app": payload.source_app,
            "platform": payload.platform,
            "mime_type": payload.mime_type,
            "attachment_count": len(payload.attachments),
            "extracted_url": extracted_url,
            "url_source": url_source,
        }
