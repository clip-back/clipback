from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from app.models.social_identity import SocialProvider


class UserRead(BaseModel):
    id: int
    email: EmailStr | None = None
    display_name: str
    is_guest: bool
    created_at: datetime
    linked_providers: list[SocialProvider]
    ai_consent_status: Literal["undecided", "granted", "denied"]


class AIConsentUpdate(BaseModel):
    model_config = ConfigDict(strict=True)

    status: Literal["granted", "denied"]
    # Only notice version 1 exists (#474 결정 3); 1.0 and true are type errors.
    notice_version: int = Field(ge=1, le=1)


class AIConsentRead(BaseModel):
    status: Literal["granted", "denied"]
    notice_version: Literal[1]
    decided_at: datetime


class UserStatsRead(BaseModel):
    saved_count: int
    reopened_count: int
    recent_reopened_count: int


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
