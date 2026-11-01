"""What each 자동 요약 종류 (summary kind) knows: which saved links it summarizes, the job they
start with, its switch, how to summarize and which provider."""

from dataclasses import dataclass
from typing import Protocol

from app.core.config import Settings
from app.integrations.summary import SummaryResult
from app.models.summary_job import SummaryJob
from app.services.link_url import instagram_post_type
from app.services.youtube_url import is_youtube_url, normalize_youtube_url


@dataclass(frozen=True)
class JobPlan:
    target_id: str
    status: str
    error_code: str | None
    model: str


class SummaryKind(Protocol):
    name: str  # SummaryJob.kind
    provider: str  # provider named in the success log

    def enabled(self, config: Settings) -> bool: ...

    def plan(self, url: str, config: Settings) -> JobPlan | None: ...

    async def summarize(
        self, target_id: str, model: str, candidates: list[dict]
    ) -> SummaryResult: ...


class YouTubeSummaryKind:
    name = "youtube"
    provider = "gemini"

    def __init__(self, client):
        self.client = client

    @classmethod
    def enabled(cls, config: Settings) -> bool:
        return config.youtube_summary_enabled

    @classmethod
    def plan(cls, url: str, config: Settings) -> JobPlan | None:
        if not is_youtube_url(url):
            return None
        # The saved link is already canonical; normalizing it again yields the same video id.
        _, video_id = normalize_youtube_url(url)
        if not cls.enabled(config):
            return JobPlan(video_id, "skipped", "disabled", config.gemini_model)
        return JobPlan(video_id, "queued", None, config.gemini_model)

    async def summarize(self, target_id: str, model: str, candidates: list[dict]) -> SummaryResult:
        return await self.client.summarize(target_id, model, candidates)


class InstagramSummaryKind:
    name = "instagram"
    provider = "openai"

    def __init__(self, client):
        self.client = client

    @classmethod
    def enabled(cls, config: Settings) -> bool:
        return config.instagram_summary_enabled

    @classmethod
    def plan(cls, url: str, config: Settings) -> JobPlan | None:
        post_type = instagram_post_type(url)
        if post_type is None:
            return None
        # The switch is judged before the story check.
        if not cls.enabled(config):
            return JobPlan(url, "skipped", "disabled", config.instagram_summary_model)
        if post_type == "stories":
            return JobPlan(url, "skipped", "unsupported_content", config.instagram_summary_model)
        return JobPlan(url, "queued", None, config.instagram_summary_model)

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


def new_summary_job(
    *,
    content_id: int,
    url: str,
    apply_title: bool,
    apply_summary: bool,
    apply_category: bool,
    config: Settings,
) -> SummaryJob | None:
    """The summary job a newly saved link gets, or None when no kind summarizes it."""
    # No link belongs to two kinds: their hosts differ.
    for kind in (YouTubeSummaryKind, InstagramSummaryKind):
        plan = kind.plan(url, config)
        if plan is not None:
            return SummaryJob(
                content_id=content_id,
                kind=kind.name,
                target_id=plan.target_id,
                status=plan.status,
                error_code=plan.error_code,
                model=plan.model,
                apply_title=apply_title,
                apply_summary=apply_summary,
                apply_category=apply_category,
            )
    return None
