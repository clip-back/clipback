"""Loopback-only native share harness with real PostgreSQL and deterministic providers.

Run from backend/ using the README command. This module refuses other database
names/hosts and is never imported by the production application.
"""

import os
from pathlib import Path

from sqlalchemy.engine import make_url

if os.environ.get("CLIPBACK_SHARE_TEST_SERVER") != "1":
    raise RuntimeError("Explicit CLIPBACK_SHARE_TEST_SERVER=1 is required")

url = make_url(os.environ.get("DATABASE_URL", ""))
if url.host not in {"localhost", "127.0.0.1"} or url.database != "clipback_share_preview":
    raise RuntimeError("This harness requires local disposable clipback_share_preview")

# Override before importing Settings, so .env values cannot enable paid providers.
os.environ["APP_ENVIRONMENT"] = "test"
os.environ["YOUTUBE_SUMMARY_ENABLED"] = "false"
os.environ["SECRET_KEY"] = "local-share-preview-fixture-signing-key-not-for-deployment"
os.environ["STORAGE_ROOT"] = str(Path("/private/tmp/clipback-share-preview-assets"))

import httpx  # noqa: E402

from app.integrations.ai_client import AIClient  # noqa: E402
from app.integrations.metadata_client import MetadataClient, MetadataResult  # noqa: E402
from app.integrations.ocr_client import OCRClient, ScreenshotOCRResult  # noqa: E402
from app.integrations.social_auth_client import SocialAuthClient, SocialProfile  # noqa: E402
from app.main import create_app  # noqa: E402


async def metadata(self, url):
    return MetadataResult(
        resolved_url=("https://www.instagram.com/p/native-share-fixture/"
                      if "/share/" in url else url),
        title="공유 저장 테스트", description="로컬 PostgreSQL에 저장한 테스트 콘텐츠",
        status="success",
    )


async def recommend(self, *, candidates, **kwargs):
    return candidates[0][0] if candidates else None


async def ocr(self, **kwargs):
    return ScreenshotOCRResult(
        text="공유 스크린샷 테스트", title="공유 스크린샷", summary="로컬 OCR 대역",
    )


async def verify(self, *, provider, token):
    return SocialProfile(provider=provider, subject=token, email=None, display_name="공유 테스트")


async def no_external_http(self, request):
    raise RuntimeError("External HTTP is disabled in the mobile share test harness")


MetadataClient.extract_from_url = metadata
AIClient.suggest_category_id = recommend
OCRClient.extract = ocr
SocialAuthClient.verify = verify
httpx.AsyncHTTPTransport.handle_async_request = no_external_http
app = create_app()
