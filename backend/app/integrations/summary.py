"""Summary result and error shared by every summary client, whatever the summary kind."""

from dataclasses import dataclass


class SummaryError(Exception):
    def __init__(self, code: str, *, retryable: bool = False, skipped: bool = False):
        super().__init__(code)
        self.code = code
        self.retryable = retryable
        self.skipped = skipped
        self.usage: dict = {}
        self.provider: str | None = None
        self.http_status: int | None = None
        self.provider_status: str | None = None
        self.reason: str | None = None
        self.image: dict | None = None


@dataclass
class SummaryResult:
    title: str
    summary: str
    category_id: int | None
    usage: dict
    image: dict | None = None
