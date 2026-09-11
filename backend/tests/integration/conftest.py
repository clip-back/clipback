from io import BytesIO
from types import SimpleNamespace

import httpx
import pytest
import pytest_asyncio
from PIL import Image
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.db.session import get_db
from app.integrations.ai_client import AIClient, AIClientError
from app.integrations.metadata_client import MetadataClient, MetadataResult
from app.integrations.ocr_client import OCRClient, OCRClientTimeoutError, ScreenshotOCRResult
from app.integrations.social_auth_client import SocialAuthClient, SocialProfile
from app.main import create_app


@pytest.fixture
def external_responses(monkeypatch):
    state = SimpleNamespace(ai_fails=False, ocr_fails=False, ai_calls=0, network_calls=[])

    async def metadata(self, url):
        return MetadataResult(
            resolved_url=url, title="통합 제목", description="통합 설명", status="success"
        )

    async def recommend(self, *, candidates, **kwargs):
        state.ai_calls += 1
        if state.ai_fails:
            raise AIClientError("injected AI failure")
        return candidates[0][0] if candidates else None

    async def ocr(self, **kwargs):
        if state.ocr_fails:
            raise OCRClientTimeoutError("injected OCR timeout")
        return ScreenshotOCRResult(text="화면 텍스트", title="화면 제목", summary="화면 요약")

    async def verify(self, *, provider, token):
        return SocialProfile(
            provider=provider, subject=token, email=None, display_name="통합 사용자"
        )

    def block(self, request):
        state.network_calls.append(str(request.url))
        raise AssertionError("Unexpected external HTTP request")

    async def block_async(self, request):
        block(self, request)

    monkeypatch.setattr(MetadataClient, "extract_from_url", metadata)
    monkeypatch.setattr(AIClient, "suggest_category_id", recommend)
    monkeypatch.setattr(OCRClient, "extract", ocr)
    monkeypatch.setattr(SocialAuthClient, "verify", verify)
    monkeypatch.setattr(httpx.HTTPTransport, "handle_request", block)
    monkeypatch.setattr(httpx.AsyncHTTPTransport, "handle_async_request", block_async)
    yield state
    # Also fail when application fallback handling catches the transport exception.
    assert state.network_calls == []


@pytest_asyncio.fixture
async def api(database_connection, external_responses, monkeypatch, tmp_path):
    monkeypatch.setattr(settings, "storage_root", tmp_path)
    monkeypatch.setattr(settings, "openai_api_key", None)
    app = create_app()

    async def request_session():
        async with AsyncSession(
            bind=database_connection,
            expire_on_commit=False,
            join_transaction_mode="create_savepoint",
        ) as session:
            yield session

    app.dependency_overrides[get_db] = request_session
    try:
        async with app.router.lifespan_context(app):
            async with httpx.AsyncClient(
                transport=httpx.ASGITransport(app=app, raise_app_exceptions=False),
                base_url="http://test",
            ) as client:
                yield client
    finally:
        app.dependency_overrides.clear()


@pytest.fixture
def png_bytes():
    output = BytesIO()
    Image.new("RGB", (8, 8), "blue").save(output, format="PNG")
    return output.getvalue()
