from datetime import datetime

from pydantic import BaseModel, EmailStr

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
