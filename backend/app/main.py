import asyncio
import json
import logging
from contextlib import AsyncExitStack, asynccontextmanager, suppress

import httpx
from fastapi import FastAPI, Request, Response
from fastapi.encoders import jsonable_encoder
from fastapi.exception_handlers import request_validation_exception_handler
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.router import api_router
from app.core.config import settings
from app.core.logging import configure_logging
from app.db.session import AsyncSessionLocal, recommendation_engine
from app.integrations.ai_client import close_ai_client
from app.integrations.instagram_summary_client import InstagramSummaryClient
from app.integrations.metadata_client import MetadataClient
from app.integrations.ocr_client import close_ocr_client
from app.integrations.social_auth_client import close_social_auth_client
from app.integrations.youtube_summary_client import YouTubeSummaryClient
from app.services.summary_worker import SummaryWorker

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(_: FastAPI):
    configure_logging()
    async with AsyncExitStack() as resources:
        resources.push_async_callback(recommendation_engine.dispose)
        http = await resources.enter_async_context(httpx.AsyncClient())
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
            logger.info(json.dumps({
                "event": "summary_worker_consent_config",
                "worker_running": task is not None,
                "ai_consent_required": worker.config.ai_consent_required,
            }))
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


async def _render_request_validation_error(
    request: Request, exc: RequestValidationError,
) -> Response:
    try:
        return await request_validation_exception_handler(request, exc)
    except UnicodeEncodeError:
        # A validation error can echo input that cannot be encoded as UTF-8.
        content = {"detail": jsonable_encoder(exc.errors())}
        return Response(
            json.dumps(content, ensure_ascii=True, separators=(",", ":"), allow_nan=False),
            status_code=422,
            media_type="application/json",
        )


def create_app(*, maintenance=None) -> FastAPI:
    docs_enabled = settings.app_environment != "production"
    app = FastAPI(
        title=settings.project_name,
        version="0.1.0",
        docs_url="/docs" if docs_enabled else None,
        redoc_url="/redoc" if docs_enabled else None,
        openapi_url=f"{settings.api_v1_prefix}/openapi.json" if docs_enabled else None,
        lifespan=lifespan,
    )
    app.add_exception_handler(RequestValidationError, _render_request_validation_error)

    from app.middleware.body_size_limit import BodySizeLimitMiddleware
    from app.middleware.maintenance import MaintenanceMiddleware
    from app.services.maintenance import default_gate
    from app.services.usage_limits import GuestIssuanceLimit

    app.state.guest_issuance_limit = GuestIssuanceLimit()
    app.state.maintenance = maintenance or default_gate()
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.backend_cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.add_middleware(MaintenanceMiddleware, state=app.state, prefix=settings.api_v1_prefix)
    # Outermost, so oversized requests are refused before maintenance admission touches the DB.
    app.add_middleware(
        BodySizeLimitMiddleware,
        upload_path=f"{settings.api_v1_prefix}/uploads/screenshots",
        screenshot_max_bytes=settings.screenshot_max_bytes,
    )
    app.include_router(api_router, prefix=settings.api_v1_prefix)

    @app.get("/", tags=["root"])
    async def root() -> dict[str, str]:
        return {"service": settings.project_name, "status": "ok"}

    return app


app = create_app()
