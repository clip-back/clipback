from pydantic import BaseModel, EmailStr


class UserRead(BaseModel):
    id: int
    email: EmailStr | None = None
    display_name: str
    is_guest: bool
