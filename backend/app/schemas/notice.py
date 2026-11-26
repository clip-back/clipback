from datetime import date

from pydantic import BaseModel, ConfigDict, Field

Text = Field(min_length=1)


class _Strict(BaseModel):
    # The operator's file is checked as strictly as the app reads it (#486).
    model_config = ConfigDict(strict=True, extra="forbid")


class NoticeStep(_Strict):
    title: str = Text
    body: str = Text
    note: str | None


class Notice(_Strict):
    title: str = Text
    published_on: date
    pinned: bool
    intro_title: str = Text
    intro: str = Text
    steps: list[NoticeStep]
    closing_title: str = Text
    closing: str = Text


class NoticeList(_Strict):
    notices: list[Notice] = Field(min_length=1)
