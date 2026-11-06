from datetime import datetime
from typing import Literal

from pydantic import BaseModel, EmailStr, Field, field_validator

from app.models.social_identity import SocialProvider


class UserRead(BaseModel):
    id: int
    email: EmailStr | None = None
    display_name: str
    is_guest: bool
    created_at: datetime
    linked_providers: list[SocialProvider]


class UserStatsRead(BaseModel):
    saved_count: int
    reopened_count: int


AccountDeletionReasonValue = Literal["rejoin", "low_usage", "privacy_security", "other"]


class AccountDeletionRequest(BaseModel):
    # Exact values only: no trimming or case folding.
    reasons: list[AccountDeletionReasonValue] = Field(min_length=1)

    @field_validator("reasons")
    @classmethod
    def reject_repeated_reasons(cls, reasons: list[str]) -> list[str]:
        if len(set(reasons)) != len(reasons):
            raise ValueError("Reasons must not repeat")
        return reasons
