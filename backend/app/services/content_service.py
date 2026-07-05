from datetime import UTC, datetime

from app.schemas.category import CategoryRead
from app.schemas.content import ContentCreate, ContentRead


class ContentService:
    async def create_placeholder(self, payload: ContentCreate) -> ContentRead:
        title = payload.title or "저장한 콘텐츠"
        summary = payload.summary or "링크 메타데이터 추출 또는 OCR 결과가 이 영역에 저장됩니다."
        return ContentRead(
            id=1,
            categories=[
                CategoryRead(id=category_id, name="선택 카테고리", is_default=False)
                for category_id in payload.category_ids
            ],
            content_type=payload.content_type,
            source=payload.source,
            title=title,
            summary=summary,
            original_url=str(payload.original_url) if payload.original_url else None,
            is_favorite=payload.is_favorite,
            saved_at=datetime.now(UTC),
        )

    async def read_placeholder(self, content_id: int) -> ContentRead:
        return ContentRead(
            id=content_id,
            categories=[CategoryRead(id=0, name="미분류", color="#6B7280", is_default=True)],
            content_type="link",
            source="instagram",
            title="포트폴리오 문제 정의",
            summary="사용자 행동과 비즈니스 목표를 연결해 하나의 핵심 문제로 압축해야 한다.",
            original_url="https://example.com/original",
            is_favorite=False,
            saved_at=datetime.now(UTC),
        )
