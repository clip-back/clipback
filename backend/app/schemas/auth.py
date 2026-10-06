from pydantic import BaseModel, ConfigDict, Field


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


class RefreshTokenRequest(BaseModel):
    refresh_token: str = Field(min_length=1)


class LogoutRequest(BaseModel):
    refresh_token: str = Field(min_length=1)
