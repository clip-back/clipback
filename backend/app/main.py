import asyncio
from contextlib import asynccontextmanager, suppress

import httpx
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.router import api_router
from app.core.config import settings
from app.core.logging import configure_logging
from app.db.session import AsyncSessionLocal
from app.integrations.ai_client import close_ai_client
from app.integrations.instagram_summary_client import InstagramSummaryClient
from app.integrations.metadata_client import MetadataClient
from app.integrations.ocr_client import close_ocr_client
from app.integrations.social_auth_client import close_social_auth_client
from app.integrations.youtube_summary_client import YouTubeSummaryClient
from app.services.summary_worker import SummaryWorker


@asynccontextmanager
async def lifespan(_: FastAPI):
    configure_logging()
    async with httpx.AsyncClient() as http:
        instagram = InstagramSummaryClient(
            settings,
            MetadataClient(
                total_timeout_seconds=settings.metadata_total_timeout_seconds,
                max_redirects=settings.metadata_max_redirects,
                max_response_bytes=settings.metadata_max_response_bytes,
                user_agent=settings.metadata_user_agent,
            ),
        )
        worker = SummaryWorker(
            AsyncSessionLocal,
            YouTubeSummaryClient(settings, http),
            settings,
            instagram_client=instagram,
        )
        task = asyncio.create_task(worker.run()) if worker.enabled_kinds() else None
        try:
            yield
        finally:
            if task is not None:
                task.cancel()
                with suppress(asyncio.CancelledError):
                    await task
            await instagram.close()
            await close_ai_client()
            await close_ocr_client()
            await close_social_auth_client()


def create_app(*, maintenance=None) -> FastAPI:
    app = FastAPI(
        title=settings.project_name,
        version="0.1.0",
        openapi_url=f"{settings.api_v1_prefix}/openapi.json",
        lifespan=lifespan,
    )

    from app.middleware.maintenance import MaintenanceMiddleware
    from app.services.maintenance import default_gate

    app.state.maintenance = maintenance or default_gate()
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.backend_cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.add_middleware(MaintenanceMiddleware, state=app.state, prefix=settings.api_v1_prefix)
    app.include_router(api_router, prefix=settings.api_v1_prefix)

    @app.get("/", tags=["root"])
    async def root() -> dict[str, str]:
        return {"service": settings.project_name, "status": "ok"}

    return app


app = create_app()
