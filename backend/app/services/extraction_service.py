from __future__ import annotations

from dataclasses import dataclass
import json

from fastapi import HTTPException

from app.core.config import settings
from app.integrations.metadata_client import MetadataClient, UnsafeUrlError
from app.schemas.content import ContentCreate, ContentSource
from app.services.link_url import infer_content_source, is_instagram_url, normalize_instagram_url


MAX_EVENT_METADATA_LENGTH = 1000


@dataclass(frozen=True)
class ExtractionResult:
    resolved_url: str
    title: str | None
    description: str | None
    source: ContentSource
    status: str
    failure_reason: str | None


class ExtractionService:
    def __init__(self, metadata_client: MetadataClient | None = None) -> None:
        self.metadata_client = metadata_client or MetadataClient(
            total_timeout_seconds=settings.metadata_total_timeout_seconds,
            max_redirects=settings.metadata_max_redirects,
            max_response_bytes=settings.metadata_max_response_bytes,
            user_agent=settings.metadata_user_agent,
        )

    async def enrich_link(self, payload: ContentCreate) -> ExtractionResult:
        if payload.original_url is None:
            raise HTTPException(status_code=422, detail="original_url is required for link content")

        input_url = str(payload.original_url)
        instagram_url = is_instagram_url(input_url)
        request_url = normalize_instagram_url(input_url) if instagram_url else input_url

        try:
            metadata = await self.metadata_client.extract_from_url(request_url)
        except UnsafeUrlError as exc:
            raise HTTPException(status_code=422, detail=str(exc)) from exc

        resolved_url = request_url if instagram_url else metadata.resolved_url
        return ExtractionResult(
            resolved_url=resolved_url,
            title=self._prefer_user_value(payload.title, metadata.title),
            description=self._prefer_user_value(payload.summary, metadata.description),
            source=infer_content_source(resolved_url),
            status=metadata.status,
            failure_reason=metadata.failure_reason,
        )

    @staticmethod
    def apply_to_payload(payload: ContentCreate, result: ExtractionResult) -> ContentCreate:
        values = payload.model_dump()
        values.update(
            original_url=result.resolved_url,
            title=result.title,
            summary=result.description,
            source=result.source,
        )
        return ContentCreate.model_validate(values)

    @staticmethod
    def build_event_metadata_json(
        result: ExtractionResult,
        *,
        base: dict[str, object] | None = None,
    ) -> str:
        metadata = dict(base or {})
        metadata.update(
            metadata_status=result.status,
            metadata_failure_reason=result.failure_reason,
            resolved_url=result.resolved_url,
        )
        serialized = json.dumps(metadata, ensure_ascii=False, separators=(",", ":"))
        while len(serialized) > MAX_EVENT_METADATA_LENGTH:
            string_fields = {
                key: value for key, value in metadata.items() if isinstance(value, str) and value
            }
            if not string_fields:
                break
            key = max(string_fields, key=lambda item: len(string_fields[item]))
            overflow = len(serialized) - MAX_EVENT_METADATA_LENGTH
            metadata[key] = string_fields[key][: max(0, len(string_fields[key]) - overflow)]
            serialized = json.dumps(metadata, ensure_ascii=False, separators=(",", ":"))
        return serialized

    @staticmethod
    def _prefer_user_value(user_value: str | None, extracted_value: str | None) -> str | None:
        if user_value is not None and user_value.strip():
            return user_value
        return extracted_value
