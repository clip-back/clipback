# Clipback Backend

이미지 저장소의 운영 전환 순서와 확인 기준은 [이미지 보관 운영 전환](../docs/backend/image-storage-rollout.md)을 따릅니다.

FastAPI backend for the Clipback MVP.

Implementation status and remaining scope decisions are tracked in the
[MVP status document](../docs/backend-mvp-plan.md).

사용자에게 보이는 서버 변경은 같은 PR에서 [업데이트 내역](../CHANGELOG.md)에 작성합니다.
서버 단독 배포와 앱 동반 배포의 SHA·마이그레이션·실제 검증은
[배포 절차](../docs/release-process.md)에 따라 기록합니다.

이미지 보관량·관측 전송량과 운영자의 신규 저장 중단·재개 명령은
[이미지 운영 안내](../docs/backend/image-storage-operations.md)를 따릅니다.

## 준비 사항

Python 3.11 또는 3.12, Docker Compose의 PostgreSQL을 준비합니다. 아래 설치는 저장소 루트에서 시작하고, 서버·migration·검사는 가상환경이 준비된 `backend/`에서 실행합니다.
`.env`는 로컬에서만 관리합니다. 기본 활성 상태인 YouTube 요약에는 공급자 키가 필요하며, 키 없이 로컬 실행할 때는 `.env`에 `YOUTUBE_SUMMARY_ENABLED=false`를 명시합니다. [YouTube 실행 조건](../docs/youtube-summary.md#작업운영)을 따르고 실제 비밀키를 문서나 로그에 넣지 않습니다.

## 빠른 실행

처음 한 번 개발 의존성과 로컬 설정을 준비합니다. 기존 `.env`가 있으면 유지합니다.

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
test -f .env || cp .env.example .env
```

로컬 설정을 확인한 뒤 다음 DB 준비·마이그레이션을 완료하고 API 서버를 실행합니다. DB 준비 블록은 저장소 루트의 별도 터미널에서 시작합니다.

## Database Migrations

Set `DATABASE_URL` to your PostgreSQL database before running migrations.

Example:

```env
DATABASE_URL=postgresql+asyncpg://postgres:postgres@localhost:5433/clipback
```

Start the local PostgreSQL service from the repository root:

```bash
docker compose up -d postgres
```

The Compose service exposes PostgreSQL on host port `5433` to avoid conflicts with
an existing local PostgreSQL running on `5432`.

```bash
cd backend
source .venv/bin/activate
alembic upgrade head
```

API docs will be available at:

```text
http://127.0.0.1:8000/docs
```

마이그레이션 완료 후 `backend/`의 가상환경에서 실행합니다.

```bash
uvicorn app.main:app --reload
```

## 기본 검증

개발 의존성이 준비된 `backend/` 가상환경에서 실행합니다.

```bash
ruff check app alembic tests
pytest -q
python -m compileall app alembic tests
```

DB 검사에는 별도 설정·마이그레이션이 필요합니다. [검증 조건과 전용 테스트 DB](../docs/backend/testing.md#validation)를 먼저 확인하며, DB 테스트의 skip을 통과로 보고하지 않습니다.

## Structure

```text
app/api          HTTP routes grouped by API version.
app/core         Settings, security, logging, shared exceptions.
app/db           SQLAlchemy session and database bootstrap.
app/models       Database models.
app/schemas      Pydantic request/response schemas.
app/repositories Data access layer.
app/services     Business logic layer.
app/integrations External systems such as AI, OCR, metadata, and storage.
tests            API, service, and repository tests.
scripts          Deployment checks and operator-only backup/recovery commands.
Dockerfile.operator  Manual/daily backup and separate retention image (PostgreSQL 18 default).
```

## 상세 문서

- [API 목록·요청·응답·권한·재시도 계약](../docs/backend/api-contracts.md)
- [검사·전용 테스트 DB·통합 테스트·공유 서버](../docs/backend/testing.md)
- [일일 이미지 백업·7일 보존·최신 삭제 상태의 격리 복원](../docs/backend/backup-recovery.md)
- [MVP 범위와 남은 결정](../docs/backend-mvp-plan.md)
- [카테고리·AI 분류 정책](../docs/category-recommendation-policy.md) · [콘텐츠 재발견 정책](../docs/content-recommendation-plan.md)
- [YouTube 비동기 요약](../docs/youtube-summary.md) · [제품 이벤트·지표](../docs/product-metrics-queries.md)
- [작업·검증 이력](../docs/history/README.md) · [배포 절차](../docs/release-process.md)

### Railway deployment

The runtime image uses Python 3.12, one Uvicorn worker, and `${PORT:-8000}`.
Set the Railway service root to `/backend`, attach a volume at `/data`, set
`STORAGE_ROOT=/data/screenshots`, and run `alembic upgrade head` as the pre-deploy
command. New originals can use a private S3-compatible Bucket by selecting
`STORAGE_BACKEND=s3` and setting the Bucket variables in `.env.example`; existing
local assets keep using the mounted volume. `/api/v1/health/ready` checks PostgreSQL
and the selected writer (temporary local write or read-only Bucket listing) with a
three-second timeout; `/api/v1/health` retains its existing liveness contract.
Initialize the separate deletion ledger before accepting image deletion requests;
production Bucket originals require independent S3 ledger settings. See
[durable deletion and cleanup retry](../docs/backend/image-deletion.md) for setup,
the bounded retry command, and the recovery checkpoint contract.

See [Railway deployment and paired backup/restore](../docs/railway-deployment.md)
for all required variables, dashboard settings, Docker persistence checks, and
recovery instructions. Record deployment status and verification evidence using the
[release process](../docs/release-process.md); code and local checks alone do not confirm the deployed environment.

<details>
<summary>이전 문서 링크와 제목 호환</summary>

- <a id="verification-on-2026-10-12"></a>[Verification on 2026-10-12](../docs/history/2026-10-12-mobile-share.md#b-bd065ba1319d232b)

</details>

<details>
<summary>상세 설명 이동과 이전 제목 안내</summary>

- <a id="mvp-scope"></a>[MVP Scope](../docs/backend/api-contracts.md#mvp-scope)
- <a id="local-development"></a>[Local Development](README.md#빠른-실행)
- <a id="validation"></a>[Validation](../docs/backend/testing.md#validation)
- <a id="guest-authentication"></a>[Guest Authentication](../docs/backend/api-contracts.md#guest-authentication)
- <a id="mobile-social-authentication"></a>[Mobile Social Authentication](../docs/backend/api-contracts.md#mobile-social-authentication)
- <a id="apple-ios-authentication"></a>[Apple iOS authentication](../docs/backend/api-contracts.md#apple-ios-authentication)
- <a id="native-mobile-share-authentication-and-retries"></a>[Native Mobile Share Authentication and Retries](../docs/backend/api-contracts.md#native-mobile-share-authentication-and-retries)
- <a id="my-page-account-and-statistics"></a>[My Page Account and Statistics](../docs/backend/api-contracts.md#my-page-account-and-statistics)
- <a id="content-view-events"></a>[Content View Events](../docs/backend/api-contracts.md#content-view-events)
- <a id="today-recommendations"></a>[Today Recommendations](../docs/backend/api-contracts.md#today-recommendations)
- <a id="weekly-recommendations"></a>[Weekly Recommendations](../docs/backend/api-contracts.md#weekly-recommendations)
- <a id="recommendation-exposures"></a>[Recommendation Exposures](../docs/backend/api-contracts.md#recommendation-exposures)
- <a id="category-summaries"></a>[Category Summaries](../docs/backend/api-contracts.md#category-summaries)
- <a id="personal-categories-update-and-delete"></a>[Personal Categories: Update and Delete](../docs/backend/api-contracts.md#personal-categories-update-and-delete)
- <a id="deploying-existing-data"></a>[Deploying existing data](../docs/backend/api-contracts.md#deploying-existing-data)
- <a id="content-category-validation"></a>[Content Category Validation](../docs/backend/api-contracts.md#content-category-validation)
- <a id="content-url-length"></a>[Content URL Length](../docs/backend/api-contracts.md#content-url-length)
- <a id="tag-replacement"></a>[Tag Replacement](../docs/backend/api-contracts.md#tag-replacement)
- <a id="feed-pagination"></a>[Feed Pagination](../docs/backend/api-contracts.md#feed-pagination)
- <a id="screenshot-storage"></a>[Screenshot Storage](../docs/backend/api-contracts.md#screenshot-storage)
- <a id="mvp-api-integration-tests"></a>[MVP API integration tests](../docs/backend/testing.md#mvp-api-integration-tests)
- <a id="native-share-local-backend-harness"></a>[Native Share Local Backend Harness](../docs/backend/testing.md#native-share-local-backend-harness)

</details>

기존 Volume의 별도 운영자 백업과 비공개 리스너 준비는 [운영 원본의 비공개 읽기](../docs/backend/image-operator-source.md)를 따릅니다. 실제 공급자 검증과 로컬 실행 증거를 구분합니다.

운영 복원을 위한 전체 업무 쓰기 중단과 서버 측 명시적 재개는 [점검 제어 안내](../docs/backend/image-maintenance.md)를 따릅니다.

실제 점검을 확인한 Mac Docker 복원은 [격리 복원 실행](../docs/backend/isolated-restore-execution.md)의 준비·실행·연결 상실 복구·명시적 재개 절차를 따릅니다.

첫 실제 원본 백업·점검·Mac 격리 복원·재개는 [운영 실행 체크리스트](../docs/backend/image-operator-first-run.md)를 따른다. 코드·합성 검증과 실제 운영 완료는 별도로 기록한다.
