import asyncio

from fastapi import APIRouter
from fastapi.responses import JSONResponse
from sqlalchemy import text

from app.api.deps import DatabaseSession
from app.core.config import settings
from app.core.storage_health import check_storage

READINESS_TIMEOUT_SECONDS = 3

router = APIRouter()


@router.get("/health")
async def health_check() -> dict[str, str]:
    return {"status": "ok"}


@router.get(
    "/health/ready",
    response_model=dict[str, str],
    responses={503: {"description": "Database or storage unavailable"}},
)
async def readiness(db: DatabaseSession) -> JSONResponse:
    try:
        async with asyncio.timeout(READINESS_TIMEOUT_SECONDS):
            await db.execute(text("SELECT 1"))
            await asyncio.to_thread(check_storage, settings.storage_root)
    except Exception:
        return JSONResponse(status_code=503, content={"status": "unavailable"})
    return JSONResponse(content={"status": "ok"})
