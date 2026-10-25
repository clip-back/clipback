# 비공개 Bucket 원본 보관과 기존 API 호환

- 기록일: 2026-10-23
- 대상: 명세 #64의 하위 이슈 #65
- 기준: `5671e79` main과 보관 정책 문서 커밋 `05a0257`
- 범위: backend 저장소 선택·추가형 migration·기존 인증 API·설정·준비 상태

## 완료 조건과 결과

1. 새 원본과 기존 로컬 원본의 혼합 저장·조회·정상 삭제 → 기존 인증 API 통합 테스트로 동일 바이트·타 계정 404·삭제 후 404 확인.
2. 원본 보존·OCR·공유 재전송 유지 → 기존 서비스 검사와 실제 PostgreSQL 공유 커밋 실패·응답 유실·재전송 검사 확인.
3. 자산별 저장소·크기·SHA-256 기록 → 신규 저장에 메타데이터 전달, 추가형 migration과 모델 일치 확인. 기존 합성 자산의 경로 보존·local 기본값·nullable 무결성 필드 확인.
4. 선택 저장소의 준비 상태 → S3 목록 조회와 장애 시 503, 로컬 볼륨 쓰기 없이 Bucket readiness 동작 확인.

## 실제 실행

독립 작업트리에서 메인 checkout의 Python 3.12 가상환경을 사용했다.
테스트는 localhost의 작업 전용 PostgreSQL 17 DB와 moto 5.2.4 S3 대역을 사용했다.
운영 사용자 데이터·실제 공급자 키·기존 앱 DB는 사용하지 않았다.

- Red: 혼합 원본 API 테스트에서 `STORAGE_BACKEND=s3`를 선택해도 Bucket 객체 수가 0이어서 실패했다.
- Green: 혼합 원본 API 테스트 1개 통과.
- 관련 서비스·API·설정 검사: 107개 통과.
- 원본 API·공유 실패 및 재전송 검사: 21개 통과.
- 전체 `pytest -q`: **1034 passed, 12 skipped**, 167.85초.
- 최종 Bucket 목록 readiness·설정 변경 후 관련 원본 API·설정 검사: **34 passed**.
- `ruff check backend`: 통과.
- `alembic upgrade head`, `alembic check`: 통과, 추가 upgrade 차이 없음.
- 기존 revision에 합성 자산을 삽입한 DB에서 upgrade → 기존 경로 보존, backend=local, size/hash=NULL 확인.
- 해당 local-only 합성 DB에서 downgrade → upgrade 왕복 확인.
- `git diff --check`: 통과.

기존 Starlette의 httpx TestClient 사용 중단 예정 경고 1개가 남는다.
생략된 12개는 `RUN_DOCKER_RECOVERY_TESTS=1`과 작업 라벨이 있는 로컬 이미지가 필요한
기존 Docker 복원 검사다. Bucket 백업·격리 복원은 후속 티켓 범위이며 이 결과로 대체하지 않는다.

## 운영 한계와 후속 작업

실제 Railway Bucket의 저장·읽기·삭제와 배포 SHA는 확인하지 않았다.
서명 다운로드·앱 캐시·계정 한도·영속 삭제 재시도·백업·이관은 별도 티켓에서 구현한다.
프론트엔드 코드를 변경하지 않았으므로 모바일 실행·화면 검증은 이번 범위에 없다.
Bucket 신규 저장 이후의 롤백은 자산 위치를 이해하는 호환 백엔드를 유지해야 하며,
구형 백엔드나 위치 컬럼을 제거하는 downgrade로 원본 접근을 보장하지 않는다.

현재 설정과 배포 순서는 [Railway 안내](../railway-deployment.md#bucket-원본-보관),
기존 API 계약은 [백엔드 API](../backend/api-contracts.md#screenshot-storage)를 따른다.
