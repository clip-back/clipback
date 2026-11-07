"""콘텐츠 저장 HTTP 고정 테스트(#278).

링크 `POST /contents`, 공유 `POST /contents/share`, 스크린샷 `POST /uploads/screenshots`의
지금 동작을 #277의 상태·오류 분류 표와 동작 표 행 그대로 고정한다. 기대값은 main 901a3b1에서
측정한 값이다. 저장 진입점을 바꾸는 이후 티켓은 이 파일의 import 경로 한 줄만 고칠 수 있다.
"""

from dataclasses import dataclass, field
from datetime import datetime

import pytest
from sqlalchemy import func, select

from app.core.config import settings
from app.integrations.ai_client import AIClient, AIClientError
from app.integrations.metadata_client import MetadataClient, MetadataResult, UnsafeUrlError
from app.integrations.ocr_client import OCRClient, ScreenshotOCRResult
from app.models.content import Content
from app.models.content_event import ContentEvent
from app.models.share_receipt import ShareReceipt
from app.models.summary_job import SummaryJob
from app.repositories.category_repository import CategoryRepository
from tests.integration.helpers import guest

pytestmark = pytest.mark.asyncio

# 요청 본문의 카테고리 자리표시자. 실행 때 게스트의 실제 카테고리 id로 바꾼다.
CUSTOM = "<custom>"  # 첫 사용자 카테고리("취업")
CUSTOM_STR = "<custom-str>"  # 같은 id를 숫자 문자열로
UNCAT = "<uncat>"  # 미분류
MISSING = 99999999  # 접근 불가 id
CUSTOM_ID = "<CUSTOM_ID>"  # 기대 metadata_json 안의 "취업" id 자리

KEY = "11111111-1111-4111-8111-111111111111"
KEY2 = "22222222-2222-4222-8222-222222222222"
WEB = "https://example.com/a"
YT = "https://youtu.be/dQw4w9WgXcQ?t=30"
YT_BARE = "https://youtu.be/dQw4w9WgXcQ"
YT_CANON = "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=30s"
IG = "https://www.instagram.com/reel/XYZ789/?igsh=abc"
IG_CANON = "https://www.instagram.com/reel/XYZ789/"
SHARE = {"source_app": "com.instagram", "platform": "ios", "mime_type": "text/plain"}
DEFAULT_TITLE = "저장한 콘텐츠"
DEFAULT_SUMMARY = "요약 정보가 아직 없습니다."
OCR_TEXT = ScreenshotOCRResult(text="화면", title="t", summary="s")
OCR_EMPTY = ScreenshotOCRResult(text="", title="", summary="")
LONG_WEB = "https://example.com/" + '가"\\' + "f" * 1500
LONG_IG = "https://www.instagram.com/p/" + "g" * 900 + "/"
MID_IG = "https://www.instagram.com/p/" + "h" * 400 + "/"


@dataclass(frozen=True)
class Case:
    id: str
    path: str
    status: int
    json: dict | None = None
    data: dict | None = None
    upload: bool = False
    idempotency_key: str | None = None
    metadata: dict = field(default_factory=dict)
    ai: str = "first"
    ocr: ScreenshotOCRResult | None = None
    no_uncategorized: bool = False
    replay: bool = False
    detail: str | list | None = None
    metadata_calls: tuple[str, ...] = ()
    ai_calls: tuple[dict, ...] = ()
    body: dict | None = None
    metadata_json: object = None
    job: tuple | None = None
    receipts: tuple[str, ...] = ()


# 저장 응답의 카테고리 객체(main 901a3b1 관측값). id는 게스트의 실제 id와 같은지 단언한 뒤
# 자리표시자로 바꾸고 나머지 필드는 그대로 비교한다.
CATEGORY_OBJECTS = {
    "취업": {"id": "<id>", "name": "취업", "color": "#4F46E5", "is_default": True},
    "미분류": {"id": "<id>", "name": "미분류", "color": "#6B7280", "is_default": True},
}


def content(
    categories, *, content_type="link", source="web", title="추출 제목", summary="추출 설명",
    original_url=WEB, summary_status="not_requested", summary_error_code=None,
    is_favorite=False, tags=(), assets=0,
) -> dict:
    return {
        "id": "<id>", "saved_at": "<saved_at>", "summary_status": summary_status,
        "summary_error_code": summary_error_code,
        "categories": [CATEGORY_OBJECTS[name] for name in categories],
        "tags": [{"id": "<id>", "name": name} for name in tags],
        "assets": [
            {"id": "<id>", "asset_type": "screenshot", "mime_type": "image/png",
             "download_url": "/api/v1/uploads/assets/<id>"}
        ] * assets,
        "content_type": content_type, "source": source, "title": title, "summary": summary,
        "original_url": original_url, "is_favorite": is_favorite, "last_viewed_at": None,
    }


def ai_call(title="추출 제목", description="추출 설명", source="web", url=WEB, shared_text=None):
    return {"title": title, "description": description, "source": source, "url": url,
            "shared_text": shared_text}


def extraction_keys(url, status="success", reason="null") -> str:
    return (f'"metadata_status":"{status}","metadata_failure_reason":{reason},'
            f'"resolved_url":"{url}"')


def category_keys(method, rec="null", reason="null") -> str:
    return (f'"category_assignment_method":"{method}","recommended_category_id":{rec},'
            f'"category_recommendation_failure_reason":{reason}')


def share_keys(url, url_source="url") -> str:
    return ('"source_app":"com.instagram","platform":"ios","mime_type":"text/plain",'
            f'"attachment_count":0,"extracted_url":"{url}","url_source":"{url_source}"')


def bare_share_keys(url) -> str:
    return ('"source_app":null,"platform":null,"mime_type":null,"attachment_count":0,'
            f'"extracted_url":"{url}","url_source":"url"')


def obj(*parts) -> str:
    return "{" + ",".join(parts) + "}"


AI_OK = category_keys("ai", CUSTOM_ID)
USER = category_keys("user")
UNCATEGORIZED = category_keys("uncategorized")
WEB_OK = extraction_keys(WEB)
IG_OK = extraction_keys(IG_CANON)


# T1·T2는 두 단계 모두 1000자를 넘는다. 추천 id가 한 자리 늘면 가장 긴 값이 한 글자 더 잘린다.
def t1_metadata(custom_id: str) -> str:
    return ('{"metadata_status":"success","metadata_failure_reason":null,'
            '"resolved_url":"https://example.com/가\\"\\\\' + "f" * (790 - len(custom_id))
            + '",' + category_keys("ai", custom_id) + "}")


def t2_metadata(custom_id: str) -> str:
    return ('{"source_app":"앱\\"\\\\' + "s" * 100 + '","platform":"ios","mime_type":null,'
            '"attachment_count":0,"extracted_url":"","url_source":"url",'
            '"metadata_status":"success","metadata_failure_reason":null,'
            '"resolved_url":"https://www.instagram.com/p/' + "g" * (573 - len(custom_id))
            + '",' + category_keys("ai", custom_id) + "}")


T3_METADATA = (
    '{"source_app":null,"platform":null,"mime_type":null,"attachment_count":0,'
    '"extracted_url":"","url_source":"url","metadata_status":"success",'
    '"metadata_failure_reason":null,"resolved_url":"https://www.instagram.com/p/'
    + "g" * 671 + '",' + USER + "}"
)

# T4는 첫 단계에서 extracted_url만 일부 잘리고 둘째 단계에서 resolved_url이 잘린다.
# 두 단계를 한 번으로 합치면 extracted_url만 더 잘려 결과가 달라진다(#278 변형 실험으로 추가).
T4_METADATA = obj(
    bare_share_keys("https://www.instagram.com/p/" + "h" * 355),
    extraction_keys("https://www.instagram.com/p/" + "h" * 288),
    USER,
)

CATEGORY_NOT_FOUND = "Category not found"
MIXED = "Uncategorized category cannot be combined with other categories"
INVALID_YOUTUBE = "Invalid YouTube video URL"
URL_AFTER_NORMALIZATION = (
    "original_url must be a valid HTTP(S) URL of at most 2048 characters after normalization"
)
UNCATEGORIZED_MISSING = "Uncategorized category is not configured"

CASES = [
    # 링크 POST /contents
    Case("L01", "contents", 201, json={"original_url": WEB}, metadata_calls=(WEB,),
         ai_calls=(ai_call(),), body=content(["취업"]), metadata_json=obj(WEB_OK, AI_OK)),
    Case("L02", "contents", 201,
         json={"original_url": WEB, "title": "내 제목", "summary": "내 요약"},
         metadata_calls=(WEB,), ai_calls=(ai_call("내 제목", "내 요약"),),
         body=content(["취업"], title="내 제목", summary="내 요약"),
         metadata_json=obj(WEB_OK, AI_OK)),
    Case("L03", "contents", 201, json={"original_url": WEB, "category_ids": [CUSTOM]},
         metadata_calls=(WEB,), body=content(["취업"]), metadata_json=obj(WEB_OK, USER)),
    Case("L04", "contents", 201, json={"original_url": WEB}, ai="fail", metadata_calls=(WEB,),
         ai_calls=(ai_call(),), body=content(["미분류"]),
         metadata_json=obj(WEB_OK, category_keys("uncategorized", reason='"error"'))),
    Case("L05", "contents", 201, json={"original_url": WEB}, ai="outside", metadata_calls=(WEB,),
         ai_calls=(ai_call(),), body=content(["미분류"]),
         metadata_json=obj(WEB_OK, category_keys("uncategorized", reason='"invalid_response"'))),
    Case("L06", "contents", 201, json={"original_url": WEB},
         metadata={"status": "failed", "reason": "timeout", "title": None, "desc": None},
         metadata_calls=(WEB,),
         body=content(["미분류"], title=DEFAULT_TITLE, summary=DEFAULT_SUMMARY),
         metadata_json=obj(extraction_keys(WEB, "failed", '"timeout"'),
                           category_keys("uncategorized", reason='"insufficient_input"'))),
    Case("L07", "contents", 201, json={"original_url": WEB},
         metadata={"status": "failed", "reason": "metadata_missing", "title": None, "desc": None},
         metadata_calls=(WEB,),
         body=content(["미분류"], title=DEFAULT_TITLE, summary=DEFAULT_SUMMARY),
         metadata_json=obj(extraction_keys(WEB, "failed", '"metadata_missing"'),
                           category_keys("uncategorized", reason='"insufficient_input"'))),
    Case("L08", "contents", 422, json={"original_url": WEB}, metadata={"unsafe": True},
         detail="Unsafe URL", metadata_calls=(WEB,)),
    Case("L09", "contents", 201, json={"original_url": YT},
         body=content(["미분류"], source="youtube", title=DEFAULT_TITLE, summary=DEFAULT_SUMMARY,
                      original_url=YT_CANON, summary_status="queued"),
         metadata_json=obj(UNCATEGORIZED), job=("youtube", True, True, True)),
    Case("L10", "contents", 201, json={"original_url": YT, "title": "내 제목"},
         body=content(["미분류"], source="youtube", title="내 제목", summary=DEFAULT_SUMMARY,
                      original_url=YT_CANON, summary_status="queued"),
         metadata_json=obj(UNCATEGORIZED), job=("youtube", False, True, True)),
    Case("L11", "contents", 201, json={"original_url": "https://bit.ly/abc"},
         metadata={"resolved": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"},
         metadata_calls=("https://bit.ly/abc",),
         body=content(["미분류"], source="youtube",
                      original_url="https://www.youtube.com/watch?v=dQw4w9WgXcQ",
                      summary_status="queued"),
         metadata_json=obj(extraction_keys("https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
                           UNCATEGORIZED),
         job=("youtube", True, True, True)),
    Case("L11b", "contents", 201, json={"original_url": "https://bit.ly/abc", "title": "내 제목"},
         metadata={"resolved": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"},
         metadata_calls=("https://bit.ly/abc",),
         body=content(["미분류"], source="youtube", title="내 제목",
                      original_url="https://www.youtube.com/watch?v=dQw4w9WgXcQ",
                      summary_status="queued"),
         metadata_json=obj(extraction_keys("https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
                           UNCATEGORIZED),
         job=("youtube", False, True, True)),
    Case("L12", "contents", 422, json={"original_url": "https://bit.ly/chan"},
         metadata={"resolved": "https://www.youtube.com/@someone"}, detail=INVALID_YOUTUBE,
         metadata_calls=("https://bit.ly/chan",)),
    Case("L13", "contents", 201, json={"original_url": IG}, metadata_calls=(IG_CANON,),
         ai_calls=(ai_call(source="instagram", url=IG_CANON),),
         body=content(["취업"], source="instagram", original_url=IG_CANON,
                      summary_status="queued"),
         metadata_json=obj(IG_OK, AI_OK), job=("instagram", True, True, True)),
    Case("L14", "contents", 201, json={"original_url": IG, "title": "내 제목"},
         metadata_calls=(IG_CANON,),
         ai_calls=(ai_call("내 제목", source="instagram", url=IG_CANON),),
         body=content(["취업"], source="instagram", title="내 제목", original_url=IG_CANON,
                      summary_status="queued"),
         metadata_json=obj(IG_OK, AI_OK), job=("instagram", False, True, True)),
    Case("L15", "contents", 201, json={"content_type": "screenshot", "title": "t"},
         body=content(["미분류"], content_type="screenshot", source="unknown", title="t",
                      summary=DEFAULT_SUMMARY, original_url=None),
         metadata_json=obj(UNCATEGORIZED)),
    Case("L16", "contents", 422, json={"content_type": "link"},
         detail="original_url is required for link content"),
    Case("L17", "contents", 422, json={"original_url": WEB, "category_ids": [CUSTOM, UNCAT]},
         detail=MIXED, metadata_calls=(WEB,)),
    Case("L18", "contents", 404, json={"original_url": WEB, "category_ids": [MISSING]},
         detail=CATEGORY_NOT_FOUND, metadata_calls=(WEB,)),
    Case("L19", "contents", 422, json={"original_url": "https://www.youtube.com/@someone"},
         detail=INVALID_YOUTUBE),
    # 공유 POST /contents/share
    Case("S01", "contents/share", 201, json={"url": IG, "raw_text": "공유 글 " + IG, **SHARE},
         metadata_calls=(IG_CANON,),
         ai_calls=(ai_call(source="instagram", url=IG_CANON, shared_text="공유 글"),),
         body=content(["취업"], source="instagram", original_url=IG_CANON,
                      summary_status="queued"),
         metadata_json=obj(share_keys(IG_CANON), IG_OK, AI_OK),
         job=("instagram", True, True, True)),
    Case("S02", "contents/share", 201, json={"raw_text": "보세요 " + IG + ").", **SHARE},
         metadata_calls=(IG_CANON,),
         ai_calls=(ai_call(source="instagram", url=IG_CANON, shared_text="보세요"),),
         body=content(["취업"], source="instagram", original_url=IG_CANON,
                      summary_status="queued"),
         metadata_json=obj(share_keys(IG_CANON, "raw_text"), IG_OK, AI_OK),
         job=("instagram", True, True, True)),
    Case("S03", "contents/share", 201, json={"url": YT, "raw_text": "영상", **SHARE},
         body=content(["미분류"], source="youtube", title=DEFAULT_TITLE, summary=DEFAULT_SUMMARY,
                      original_url=YT_CANON, summary_status="queued"),
         metadata_json=obj(UNCATEGORIZED), job=("youtube", True, True, True)),
    Case("S04", "contents/share", 201, json={"url": "https://www.instagram.com/share/AbC", **SHARE},
         metadata={"resolved": "https://www.instagram.com/reel/RESOLV1/"},
         metadata_calls=("https://www.instagram.com/share/AbC",
                         "https://www.instagram.com/reel/RESOLV1/"),
         ai_calls=(ai_call(source="instagram", url="https://www.instagram.com/reel/RESOLV1/"),),
         body=content(["취업"], source="instagram",
                      original_url="https://www.instagram.com/reel/RESOLV1/",
                      summary_status="queued"),
         metadata_json=obj(share_keys("https://www.instagram.com/reel/RESOLV1/"),
                           extraction_keys("https://www.instagram.com/reel/RESOLV1/"), AI_OK),
         job=("instagram", True, True, True)),
    Case("S05", "contents/share", 201, json={"url": IG, "category_ids": [CUSTOM], **SHARE},
         metadata_calls=(IG_CANON,),
         body=content(["취업"], source="instagram", original_url=IG_CANON,
                      summary_status="queued"),
         metadata_json=obj(share_keys(IG_CANON), IG_OK, USER),
         job=("instagram", True, True, False)),
    Case("S06", "contents/share", 422, json={"raw_text": "없음"},
         detail="Instagram URL is required"),
    Case("S07", "contents/share", 201, json={"url": IG, **SHARE}, idempotency_key=KEY,
         metadata_calls=(IG_CANON,), ai_calls=(ai_call(source="instagram", url=IG_CANON),),
         body=content(["취업"], source="instagram", original_url=IG_CANON,
                      summary_status="queued"),
         metadata_json=obj(share_keys(IG_CANON), IG_OK, AI_OK),
         job=("instagram", True, True, True), receipts=("link",)),
    Case("S08", "contents/share", 201, json={"url": IG, **SHARE}, idempotency_key=KEY,
         replay=True,
         body=content(["취업"], source="instagram", original_url=IG_CANON,
                      summary_status="queued"),
         metadata_json=obj(share_keys(IG_CANON), IG_OK, AI_OK),
         job=("instagram", True, True, True), receipts=("link",)),
    # 스크린샷 POST /uploads/screenshots
    Case("U01", "uploads/screenshots", 201, upload=True, ocr=OCR_TEXT,
         ai_calls=(ai_call("t", "s", "screenshot", None, "화면"),),
         body=content(["취업"], content_type="screenshot", source="screenshot", title="t",
                      summary="s", original_url=None, assets=1),
         metadata_json=obj('"ocr_status":"success","ocr_failure_reason":null', AI_OK)),
    Case("U02", "uploads/screenshots", 201, upload=True, ocr=OCR_EMPTY,
         body=content(["미분류"], content_type="screenshot", source="screenshot",
                      title=DEFAULT_TITLE, summary=DEFAULT_SUMMARY, original_url=None, assets=1),
         metadata_json=obj('"ocr_status":"no_text","ocr_failure_reason":null', UNCATEGORIZED)),
    Case("U03", "uploads/screenshots", 201, upload=True, ocr=OCR_TEXT,
         data={"category_ids": [CUSTOM]},
         body=content(["취업"], content_type="screenshot", source="screenshot", title="t",
                      summary="s", original_url=None, assets=1),
         metadata_json=obj('"ocr_status":"success","ocr_failure_reason":null', USER)),
    Case("U04", "uploads/screenshots", 201, upload=True, ocr=OCR_TEXT, idempotency_key=KEY2,
         ai_calls=(ai_call("t", "s", "screenshot", None, "화면"),),
         body=content(["취업"], content_type="screenshot", source="screenshot", title="t",
                      summary="s", original_url=None, assets=1),
         metadata_json=obj('"ocr_status":"success","ocr_failure_reason":null', AI_OK),
         receipts=("screenshot",)),
    # JSON 스크린샷 POST /contents content_type=screenshot
    Case("J1", "contents", 201,
         json={"content_type": "screenshot", "title": "t", "category_ids": [CUSTOM]},
         body=content(["취업"], content_type="screenshot", source="unknown", title="t",
                      summary=DEFAULT_SUMMARY, original_url=None),
         metadata_json=obj(USER)),
    Case("J2", "contents", 404,
         json={"content_type": "screenshot", "title": "t", "category_ids": [MISSING]},
         detail=CATEGORY_NOT_FOUND),
    Case("J3", "contents", 422,
         json={"content_type": "screenshot", "title": "t", "category_ids": [CUSTOM, UNCAT]},
         detail=MIXED),
    Case("J4", "contents", 201,
         json={"content_type": "screenshot", "title": "t", "source": "web", "original_url": WEB,
               "is_favorite": True, "tag_names": ["태그"], "summary": "s"},
         body=content(["미분류"], content_type="screenshot", title="t", summary="s",
                      is_favorite=True, tags=("태그",)),
         metadata_json=obj(UNCATEGORIZED)),
    Case("J5", "contents", 201,
         json={"content_type": "screenshot", "title": "t", "original_url": YT_BARE},
         body=content(["미분류"], content_type="screenshot", source="unknown", title="t",
                      summary=DEFAULT_SUMMARY, original_url=YT_BARE),
         metadata_json=obj(UNCATEGORIZED)),
    # 카테고리 혼합·순서
    Case("M1", "contents", 404, json={"original_url": WEB, "category_ids": [UNCAT, MISSING]},
         detail=CATEGORY_NOT_FOUND, metadata_calls=(WEB,)),
    Case("M2", "contents", 404, json={"original_url": WEB, "category_ids": [MISSING, UNCAT]},
         detail=CATEGORY_NOT_FOUND, metadata_calls=(WEB,)),
    Case("M3", "contents", 422, json={"original_url": WEB, "category_ids": [UNCAT, CUSTOM]},
         detail=MIXED, metadata_calls=(WEB,)),
    Case("M4", "contents", 422, json={"original_url": YT_BARE, "category_ids": [CUSTOM, UNCAT]},
         detail=MIXED),
    Case("M5", "contents", 422, json={"original_url": WEB, "category_ids": [MISSING]},
         metadata={"unsafe": True}, detail="Unsafe URL", metadata_calls=(WEB,)),
    Case("M6", "contents", 201, json={"original_url": WEB, "category_ids": [CUSTOM, CUSTOM]},
         metadata_calls=(WEB,), body=content(["취업"]), metadata_json=obj(WEB_OK, USER)),
    Case("M7", "contents", 201, json={"original_url": WEB, "category_ids": [UNCAT]},
         metadata_calls=(WEB,), body=content(["미분류"]), metadata_json=obj(WEB_OK, USER)),
    # M8은 접근 가능한 카테고리만으로도 혼합이 되는 입력이다. 존재 검사가 먼저라 404다
    # (#278 변형 실험으로 추가).
    Case("M8", "contents", 404,
         json={"original_url": WEB, "category_ids": [CUSTOM, UNCAT, MISSING]},
         detail=CATEGORY_NOT_FOUND, metadata_calls=(WEB,)),
    # 공유 URL 허용 범위
    Case("SH1", "contents/share", 422, json={"url": WEB},
         detail="Only Instagram URLs are supported"),
    Case("SH2", "contents/share", 422, json={"url": "https://www.instagram.com/someone/"},
         detail="Unsupported Instagram URL path"),
    Case("SH3", "contents/share", 422, json={"url": "https://www.instagram.com/share/AbC"},
         metadata={"status": "failed", "reason": "timeout", "title": None, "desc": None},
         detail="Instagram share URL could not be resolved",
         metadata_calls=("https://www.instagram.com/share/AbC",)),
    Case("SH4", "contents/share", 201, json={"url": "https://www.instagram.com/share/AbD"},
         metadata={"resolved": "https://www.instagram.com/p/MISS1/", "status": "failed",
                   "reason": "metadata_missing", "title": None, "desc": None},
         metadata_calls=("https://www.instagram.com/share/AbD",
                         "https://www.instagram.com/p/MISS1/"),
         body=content(["미분류"], source="instagram", title=DEFAULT_TITLE, summary=DEFAULT_SUMMARY,
                      original_url="https://www.instagram.com/p/MISS1/", summary_status="queued"),
         metadata_json=obj(bare_share_keys("https://www.instagram.com/p/MISS1/"),
                           extraction_keys("https://www.instagram.com/p/MISS1/", "failed",
                                           '"metadata_missing"'),
                           category_keys("uncategorized", reason='"insufficient_input"')),
         job=("instagram", True, True, True)),
    Case("SH5", "contents/share", 422, json={"url": "https://www.instagram.com/share/AbE"},
         metadata={"unsafe": True}, detail="Unsafe URL",
         metadata_calls=("https://www.instagram.com/share/AbE",)),
    Case("SH6", "contents/share", 201,
         json={"url": IG_CANON, "raw_text": "https://www.instagram.com/p/OTHER1/"},
         metadata_calls=(IG_CANON,), ai_calls=(ai_call(source="instagram", url=IG_CANON),),
         body=content(["취업"], source="instagram", original_url=IG_CANON,
                      summary_status="queued"),
         metadata_json=obj(bare_share_keys(IG_CANON), IG_OK, AI_OK),
         job=("instagram", True, True, True)),
    Case("SH7", "contents/share", 201,
         json={"url": "https://www.instagram.com/stories/someone/123/"},
         metadata_calls=("https://www.instagram.com/stories/someone/123/",),
         ai_calls=(ai_call(source="instagram",
                           url="https://www.instagram.com/stories/someone/123/"),),
         body=content(["취업"], source="instagram",
                      original_url="https://www.instagram.com/stories/someone/123/",
                      summary_status="skipped", summary_error_code="unsupported_content"),
         metadata_json=obj(bare_share_keys("https://www.instagram.com/stories/someone/123/"),
                           extraction_keys("https://www.instagram.com/stories/someone/123/"),
                           AI_OK),
         job=("instagram", True, True, True)),
    Case("SH8", "contents/share", 422, json={"url": "https://www.youtube.com/@someone"},
         detail=INVALID_YOUTUBE),
    Case("SH9", "contents/share", 422, json={"url": "https://www.instagram.com/share/AbF"},
         metadata={"resolved": "https://example.com/x"},
         detail="Only Instagram URLs are supported",
         metadata_calls=("https://www.instagram.com/share/AbF",)),
    # URL 길이
    Case("LEN1", "contents", 422, json={"original_url": WEB},
         metadata={"resolved": "https://example.com/" + "a" * 2100},
         detail=URL_AFTER_NORMALIZATION, metadata_calls=(WEB,)),
    Case("LEN2", "contents", 422,
         json={"original_url": "https://instagram.com/p/" + "c" * 2024},
         detail="original_url must not exceed 2048 characters after normalization"),
    Case("LEN3", "contents", 422, json={"original_url": "https://example.com/" + "b" * 2029},
         detail=[("too_long", ["body", "original_url"])]),
    Case("LEN4", "contents/share", 422,
         json={"raw_text": "https://www.instagram.com/share/" + "d" * 2100},
         detail="Shared URL is too long"),
    Case("LEN5", "contents/share", 422,
         json={"raw_text": "https://www.instagram.com/p/" + "e" * 2100},
         detail=URL_AFTER_NORMALIZATION),
    # metadata 1000자 자르기
    Case("T1", "contents", 201, json={"original_url": WEB}, metadata={"resolved": LONG_WEB},
         metadata_calls=(WEB,),
         ai_calls=(ai_call(url="https://example.com/%EA%B0%80%22/" + "f" * 1500),),
         body=content(["취업"], original_url="https://example.com/%EA%B0%80%22/" + "f" * 1500),
         metadata_json=t1_metadata),
    Case("T2", "contents/share", 201,
         json={"url": LONG_IG, "source_app": '앱"\\' + "s" * 100, "platform": "ios"},
         metadata_calls=(LONG_IG,), ai_calls=(ai_call(source="instagram", url=LONG_IG),),
         body=content(["취업"], source="instagram", original_url=LONG_IG,
                      summary_status="queued"),
         metadata_json=t2_metadata, job=("instagram", True, True, True)),
    Case("T3", "contents/share", 201, json={"url": LONG_IG, "category_ids": [CUSTOM]},
         metadata_calls=(LONG_IG,),
         body=content(["취업"], source="instagram", original_url=LONG_IG,
                      summary_status="queued"),
         metadata_json=T3_METADATA, job=("instagram", True, True, False)),
    Case("T4", "contents/share", 201, json={"url": MID_IG, "category_ids": [CUSTOM]},
         metadata_calls=(MID_IG,),
         body=content(["취업"], source="instagram", original_url=MID_IG,
                      summary_status="queued"),
         metadata_json=T4_METADATA, job=("instagram", True, True, False)),
    # 미분류 카테고리 없음
    Case("U-1", "contents", 500, json={"original_url": YT_BARE}, no_uncategorized=True,
         detail=UNCATEGORIZED_MISSING),
    Case("U-2", "contents", 500, json={"content_type": "screenshot", "title": "t"},
         no_uncategorized=True, detail=UNCATEGORIZED_MISSING),
    # 타입이 틀린 입력
    Case("TY1", "contents", 422, json={"original_url": WEB, "category_ids": ["a"]},
         detail=[("int_parsing", ["body", "category_ids", 0])]),
    Case("TY2", "contents", 201, json={"original_url": WEB, "category_ids": [CUSTOM_STR]},
         metadata_calls=(WEB,), body=content(["취업"]), metadata_json=obj(WEB_OK, USER)),
    Case("TY3", "contents", 422, json={"original_url": WEB, "category_ids": None},
         detail=[("list_type", ["body", "category_ids"])]),
    Case("TY4", "contents", 422, json={"original_url": WEB, "category_ids": 3},
         detail=[("list_type", ["body", "category_ids"])]),
    Case("TY5", "contents", 422, json={"original_url": 123},
         detail=[("url_type", ["body", "original_url"])]),
    Case("TY6", "contents", 422, json={"original_url": WEB, "title": ["x"]},
         detail=[("string_type", ["body", "title"])]),
    Case("TY7", "contents", 201, json={"original_url": WEB, "title": None},
         metadata_calls=(WEB,), ai_calls=(ai_call(),), body=content(["취업"]),
         metadata_json=obj(WEB_OK, AI_OK)),
    Case("TY8", "contents", 201, json={"original_url": WEB, "is_favorite": "yes"},
         metadata_calls=(WEB,), ai_calls=(ai_call(),), body=content(["취업"], is_favorite=True),
         metadata_json=obj(WEB_OK, AI_OK)),
    Case("TY9", "contents", 422, json={"original_url": WEB, "tag_names": None},
         detail=[("list_type", ["body", "tag_names"])]),
    Case("TY10", "contents", 422, json={"original_url": WEB, "content_type": "video"},
         detail=[("enum", ["body", "content_type"])]),
    Case("TY11", "contents", 422, json={"original_url": WEB, "category_ids": [1.5]},
         detail=[("int_from_float", ["body", "category_ids", 0])]),
    Case("TS1", "contents/share", 422, json={"url": 123},
         detail=[("string_type", ["body", "url"])]),
    Case("TS2", "contents/share", 422, json={"url": IG_CANON, "category_ids": ["a"]},
         detail=[("int_parsing", ["body", "category_ids", 0])]),
    Case("TS3", "contents/share", 422, json={"raw_text": ["x"]},
         detail=[("string_type", ["body", "raw_text"])]),
]


class Recorder:
    def __init__(self) -> None:
        self.metadata: list[str] = []
        self.ai: list[dict] = []

    def clear(self) -> None:
        self.metadata.clear()
        self.ai.clear()


def install_fakes(monkeypatch, recorder: Recorder, case: Case) -> None:
    spec = case.metadata

    async def metadata(self, url):
        recorder.metadata.append(url)
        if spec.get("unsafe"):
            raise UnsafeUrlError("Unsafe URL")
        return MetadataResult(
            resolved_url=spec.get("resolved") or url,
            title=spec.get("title", "추출 제목"),
            description=spec.get("desc", "추출 설명"),
            status=spec.get("status", "success"),
            failure_reason=spec.get("reason"),
        )

    async def suggest(self, **kwargs):
        recorder.ai.append({key: value for key, value in kwargs.items() if key != "candidates"})
        if case.ai == "fail":
            raise AIClientError("injected AI failure")
        if case.ai == "outside":
            return MISSING
        return kwargs["candidates"][0][0] if kwargs["candidates"] else None

    monkeypatch.setattr(MetadataClient, "extract_from_url", metadata)
    monkeypatch.setattr(AIClient, "suggest_category_id", suggest)
    if case.ocr is not None:
        async def ocr(self, **_):
            return case.ocr

        monkeypatch.setattr(OCRClient, "extract", ocr)
    if case.no_uncategorized:
        async def no_uncategorized(self):
            return None

        monkeypatch.setattr(CategoryRepository, "get_uncategorized", no_uncategorized)


def resolve(value, ids: dict):
    if isinstance(value, dict):
        return {key: resolve(item, ids) for key, item in value.items()}
    if isinstance(value, list):
        return [resolve(item, ids) for item in value]
    return ids.get(value, value) if isinstance(value, str) else value


async def row_counts(db) -> list[int]:
    return [
        (await db.execute(select(func.count()).select_from(model))).scalar_one()
        for model in (Content, ContentEvent, SummaryJob, ShareReceipt)
    ]


def placeholder_body(body: dict, category_ids: dict[str, int]) -> dict:
    body = dict(body)
    assert isinstance(body["id"], int)
    datetime.fromisoformat(body["saved_at"])
    body["id"], body["saved_at"] = "<id>", "<saved_at>"
    categories = []
    for category in body["categories"]:
        assert category["id"] == category_ids[category["name"]]
        categories.append({**category, "id": "<id>"})
    body["categories"] = categories
    tags = []
    for tag in body["tags"]:
        assert isinstance(tag["id"], int)
        tags.append({**tag, "id": "<id>"})
    body["tags"] = tags
    assets = []
    for asset in body["assets"]:
        assert isinstance(asset["id"], int)
        assert asset["download_url"] == f"/api/v1/uploads/assets/{asset['id']}"
        assets.append({**asset, "id": "<id>", "download_url": "/api/v1/uploads/assets/<id>"})
    body["assets"] = assets
    return body


async def post(api, case: Case, headers: dict, ids: dict, png_bytes: bytes):
    extra = {"Idempotency-Key": case.idempotency_key} if case.idempotency_key else {}
    kwargs = {}
    if case.json is not None:
        kwargs["json"] = resolve(case.json, ids)
    if case.data is not None:
        kwargs["data"] = resolve(case.data, ids)
    if case.upload:
        kwargs["files"] = {"file": ("s.png", png_bytes, "image/png")}
    return await api.post(f"/api/v1/{case.path}", headers={**headers, **extra}, **kwargs)


@pytest.mark.parametrize("case", CASES, ids=[case.id for case in CASES])
async def test_content_save_contract(api, database_connection, monkeypatch, png_bytes, case):
    monkeypatch.setattr(settings, "youtube_summary_enabled", True)
    monkeypatch.setattr(settings, "instagram_summary_enabled", True)
    headers, _, _ = await guest(api)
    categories = (await api.get("/api/v1/categories", headers=headers)).json()
    custom = next(category for category in categories if category["name"] != "미분류")
    uncategorized = next(category for category in categories if category["name"] == "미분류")
    assert custom["name"] == "취업"
    ids = {CUSTOM: custom["id"], CUSTOM_STR: str(custom["id"]), UNCAT: uncategorized["id"]}
    category_ids = {"취업": custom["id"], "미분류": uncategorized["id"]}
    recorder = Recorder()
    install_fakes(monkeypatch, recorder, case)
    db = database_connection

    first = None
    if case.replay:
        first = await post(api, case, headers, ids, png_bytes)
        assert first.status_code == 201, first.text
        recorder.clear()

    before = await row_counts(db)
    response = await post(api, case, headers, ids, png_bytes)
    delta = [after - prior for after, prior in zip(await row_counts(db), before, strict=True)]

    assert response.status_code == case.status, response.text
    assert recorder.metadata == list(case.metadata_calls)
    assert recorder.ai == list(case.ai_calls)
    body = response.json()
    if case.status != 201:
        if isinstance(case.detail, list):
            assert [(error["type"], error["loc"]) for error in body["detail"]] == case.detail
        else:
            assert body == {"detail": case.detail}
        assert delta == [0, 0, 0, 0]
        return

    if case.replay:
        assert body == first.json()
        assert delta == [0, 0, 0, 0]
    else:
        assert delta == [1, 1, int(case.job is not None), len(case.receipts)]
    assert placeholder_body(body, category_ids) == case.body

    content_id = body["id"]
    events = (await db.execute(
        select(ContentEvent.event_type, ContentEvent.metadata_json)
        .where(ContentEvent.content_id == content_id)
    )).all()
    assert [event.event_type.value for event in events] == ["content_created"]
    expected_metadata = (
        case.metadata_json(str(custom["id"])) if callable(case.metadata_json)
        else case.metadata_json.replace(CUSTOM_ID, str(custom["id"]))
    )
    assert events[0].metadata_json == expected_metadata

    job = (await db.execute(
        select(SummaryJob.kind, SummaryJob.apply_title, SummaryJob.apply_summary,
               SummaryJob.apply_category).where(SummaryJob.content_id == content_id)
    )).one_or_none()
    assert (None if job is None else tuple(job)) == case.job
    receipts = (await db.execute(
        select(ShareReceipt.kind).where(ShareReceipt.content_id == content_id)
    )).scalars().all()
    assert receipts == list(case.receipts)
