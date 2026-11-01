"""Summary result, error and result validation shared by every summary client, whatever the kind."""

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


def validated_result(
    title, summary, category_id, categories: list[dict], usage: dict
) -> SummaryResult:
    """Judge a model answer each client has already parsed its own way.

    The values arrive untyped because the parsing differs: YouTube passes the decoded JSON
    as is, Instagram the Pydantic-converted values. An empty or too long title or summary
    fails; a category that is not an int candidate is dropped.
    """
    title, summary = title.strip(), summary.strip()
    if not title or len(title) > 120 or not summary or len(summary) > 500:
        raise SummaryError("invalid_response")
    if type(category_id) is not int or category_id not in {c["id"] for c in categories}:
        category_id = None
    return SummaryResult(title, summary, category_id, usage)
