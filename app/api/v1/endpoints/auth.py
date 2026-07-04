from fastapi import APIRouter, status

from app.schemas.auth import TokenResponse

router = APIRouter()


@router.post("/guest", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def create_guest_session() -> TokenResponse:
    return TokenResponse(access_token="guest-token-placeholder", token_type="bearer")

