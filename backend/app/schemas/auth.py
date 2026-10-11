from datetime import datetime
from enum import StrEnum
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator


class TokenSocialProvider(StrEnum):
    GOOGLE = "google"
    KAKAO = "kakao"


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str
    expires_in: int
    refresh_expires_in: int


class SocialTokenResponse(TokenResponse):
    is_new_user: bool


class SocialTokenRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    token: str


class AppleTokenRequest(SocialTokenRequest):
    authorization_code: str = Field(min_length=1, max_length=8192)
    challenge_id: UUID
    display_name: str | None = Field(default=None, max_length=80)

    @field_validator("authorization_code")
    @classmethod
    def reject_blank_code(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("Apple authorization code cannot be blank")
        return value


class AppleChallengeCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    purpose: Literal["login", "upgrade"]


class AppleChallengeRead(BaseModel):
    challenge_id: UUID
    nonce: str
    expires_at: datetime


class RefreshTokenRequest(BaseModel):
    refresh_token: str = Field(min_length=1)


class LogoutRequest(BaseModel):
    refresh_token: str = Field(min_length=1)
