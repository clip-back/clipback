"""Summary result, error and result validation shared by every summary client, whatever the kind."""

import re
from dataclasses import dataclass

# The one place for both limits (#158): both prompts and the YouTube response schema take the
# title limit, validated_result() checks both.
MAX_TITLE_LENGTH = 120
MAX_SUMMARY_LENGTH = 500


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
    title, headline, points, category_id, categories: list[dict], usage: dict
) -> SummaryResult:
    """Judge a model answer each client has already parsed its own way.

    The values arrive untyped because the parsing differs: YouTube passes the decoded JSON
    as is, Instagram the Pydantic-converted values. The headline and points are cleaned and
    joined into the summary; an empty or too long title or joined summary fails; a category
    that is not an int candidate is dropped.
    """
    summary = _joined_summary(headline, points)
    title = title.strip()
    if not title or len(title) > MAX_TITLE_LENGTH or len(summary) > MAX_SUMMARY_LENGTH:
        raise SummaryError("invalid_response")
    if type(category_id) is not int or category_id not in {c["id"] for c in categories}:
        category_id = None
    return SummaryResult(title, summary, category_id, usage)


# `•`/`·` go whatever follows; `-`, `*`, `1.`, `1)` only before a space or the end, so
# `-12%`, `1.5배` and `2)내용` stay.
_LEADING_MARK = re.compile(r"\A(?:[•·]|(?:[-*]|[0-9]+[.)])(?= |\Z))")


def _one_line(text: str) -> str:
    text = text.replace("\r\n", " ").replace("\r", " ").replace("\n", " ")
    return re.sub(r" {2,}", " ", text)


def _joined_summary(headline, points) -> str:
    """Clean the model's headline and points and join them as one plain-text summary.

    The steps run in the fixed order of spec #203 "공통 정리 규칙과 결과 판정" (ADR 0005);
    changing the order changes results.
    """
    if not isinstance(headline, str):
        raise SummaryError("invalid_response")
    headline = _one_line(headline).strip()
    if not headline:
        raise SummaryError("invalid_response")
    if not isinstance(points, list) or not all(isinstance(point, str) for point in points):
        raise SummaryError("invalid_response")
    points = [_LEADING_MARK.sub("", _one_line(point).lstrip(), count=1).strip() for point in points]
    points = [point for point in points if point]
    if not points:
        raise SummaryError("invalid_response")
    return "\n".join([headline, *(f"• {point}" for point in points[:5])])
