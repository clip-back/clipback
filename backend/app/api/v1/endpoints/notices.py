from pathlib import Path

from fastapi import APIRouter

from app.schemas.notice import NoticeList

# Read once at import: an invalid file stops the server from starting (#486).
NOTICES = NoticeList.model_validate_json(
    (Path(__file__).parents[3] / "notices.json").read_bytes()
)

router = APIRouter()


@router.get("", response_model=NoticeList)
async def list_notices() -> NoticeList:
    return NOTICES
