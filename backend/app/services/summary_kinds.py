"""What each 자동 요약 종류 (summary kind) knows: its switch, how to summarize, which provider."""

from typing import Protocol

from app.core.config import Settings
from app.integrations.summary import SummaryResult


class SummaryKind(Protocol):
    name: str  # SummaryJob.kind
    provider: str  # provider named in the success log

    def enabled(self, config: Settings) -> bool: ...

    async def summarize(
        self, target_id: str, model: str, candidates: list[dict]
    ) -> SummaryResult: ...


class YouTubeSummaryKind:
    name = "youtube"
    provider = "gemini"

    def __init__(self, client):
        self.client = client

    def enabled(self, config: Settings) -> bool:
        return config.youtube_summary_enabled

    async def summarize(self, target_id: str, model: str, candidates: list[dict]) -> SummaryResult:
        return await self.client.summarize(target_id, model, candidates)


class InstagramSummaryKind:
    name = "instagram"
    provider = "openai"

    def __init__(self, client):
        self.client = client

    def enabled(self, config: Settings) -> bool:
        return config.instagram_summary_enabled

    async def summarize(self, target_id: str, model: str, candidates: list[dict]) -> SummaryResult:
        return await self.client.summarize(target_id, model, candidates)


class SummaryKinds:
    """The kinds a worker serves; `enabled_names` keeps their order."""

    def __init__(self, kinds: list[SummaryKind]):
        self._kinds = {kind.name: kind for kind in kinds}

    def enabled_names(self, config: Settings) -> list[str]:
        return [name for name, kind in self._kinds.items() if kind.enabled(config)]

    def get(self, name: str) -> SummaryKind:
        return self._kinds[name]


def summary_kinds(*, youtube, instagram) -> SummaryKinds:
    """Every kind, each wrapping the summary client the app built for it."""
    return SummaryKinds([YouTubeSummaryKind(youtube), InstagramSummaryKind(instagram)])
