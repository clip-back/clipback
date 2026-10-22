# 백엔드 테스트와 로컬 검증

검사 명령·전용 PostgreSQL 테스트 DB·통합 테스트와 로컬 공유 서버의 실행 조건입니다. 개발 환경은 [백엔드 README](../../backend/README.md), 요청·응답 기준은 [API 계약](api-contracts.md)을 따릅니다.
별도 표기가 없는 명령은 개발 의존성을 설치하고 가상환경을 활성화한 `backend/`에서 실행합니다. `DATABASE_URL`·`TEST_DATABASE_URL`을 사용하는 명령은 아래 대상과 선행 migration을 먼저 확인합니다. 결과는 [작업 이력](../history/README.md)에 기록하며, 이 문서의 시나리오는 실행 증거가 아닙니다.

## Validation

The backend supports Python 3.11 and 3.12. Run the same checks used by CI from the
`backend` directory:

```bash
ruff check app alembic tests
pytest -q
python -m compileall app alembic tests
alembic upgrade head
alembic check
```

The migration checks require PostgreSQL and a valid `DATABASE_URL`.

PostgreSQL repository tests additionally require an explicit `TEST_DATABASE_URL` pointing
to a dedicated PostgreSQL test database with migrations applied. They roll back each
test's transaction and are skipped locally when the variable is not set. CI runs them
against its PostgreSQL service after applying migrations.

```bash
export TEST_DATABASE_URL=postgresql+asyncpg://postgres:postgres@localhost:5433/clipback_test
DATABASE_URL="$TEST_DATABASE_URL" alembic upgrade head
pytest -q tests/repositories
```

## MVP API integration tests

`tests/integration` exercises HTTP routes, real authentication, services, PostgreSQL
repositories, and local image storage together. Only social-provider verification,
web metadata, AI recommendations, and OCR responses are replaced with deterministic
results. Unexpected external HTTP requests fail the test, even when caught by an
application fallback. No external credentials are required.

Use a dedicated test database, never an application database:

```sh
DATABASE_URL="$TEST_DATABASE_URL" .venv/bin/alembic upgrade head
.venv/bin/pytest -q tests/repositories tests/integration
```

Set `TEST_DATABASE_URL` explicitly to a PostgreSQL asyncpg URL before running these
commands. Without it, DB tests skip; an invalid connection or missing migrations
fails. The CI PostgreSQL job applies migrations and runs both suites as required
checks. Existing Python 3.11/3.12 jobs continue running tests without a database.

Each integration test opens an outer transaction. Every sequential HTTP request
uses a new session and savepoint, allowing actual application commits and rollbacks
while rolling back the entire test at teardown. Dedicated mobile-share and Apple
concurrency tests instead use separate connections and real commits, and delete only
the users/data they created afterward. Each test uses a
fresh app and temporary storage directory; settings and client replacements are
restored afterward.

Scenarios cover guest/social login and promotion, token refresh/logout, direct and
shared link saving, category personalization/deletion, feed filters and pagination,
cumulative view statistics, screenshot download/deletion, cross-user isolation, and
DB failure compensation that removes an already-written image. These tests do not
validate live provider credentials, external service quality, deployment, or load.

## Native Share Local Backend Harness

`tests/support/share_live_server.py` runs the real API, authentication, receipts,
PostgreSQL and image storage while replacing external metadata, AI, OCR and social
verification with deterministic test responses. Unexpected external HTTP fails.
This is separate from the frontend HTTP fixture server and does not prove live
OAuth or provider extraction.

Use a new disposable database; run the first command from the repository root,
then the rest from `backend/`. If the database already exists, omit `createdb`.

```bash
docker compose exec -T postgres createdb -U postgres clipback_share_preview
cd backend
YOUTUBE_SUMMARY_ENABLED=false \
  DATABASE_URL=postgresql+asyncpg://postgres:postgres@localhost:5433/clipback_share_preview \
  .venv/bin/alembic upgrade head
CLIPBACK_SHARE_TEST_SERVER=1 \
  DATABASE_URL=postgresql+asyncpg://postgres:postgres@localhost:5433/clipback_share_preview \
  .venv/bin/uvicorn tests.support.share_live_server:app \
  --host 127.0.0.1 --port 18766 --no-access-log
```

The harness refuses any nonlocal database or a name other than
`clipback_share_preview`, uses a test-only signing key, disables the summary worker,
and stores images under `/private/tmp/clipback-share-preview-assets`. It must not be
deployed. Use `http://127.0.0.1:18766/api/v1` on iOS Simulator and
`http://10.0.2.2:18766/api/v1` on Android Emulator with test-only HTTP build settings.
Obtain guest/access/share credentials through the normal API; do not print tokens.
Stop the local server after validation. The database and temporary files are
explicitly disposable; they are not application backups.

과거 공유 서버 검증 결과는 [모바일 공유 작업 기록](../history/2026-10-12-mobile-share.md)을 참고합니다.

운영 배포 확인·백업·복구는 [Railway 운영 안내](../railway-deployment.md), 실제 산출물·공개 상태는 [배포 기록](../release-process.md)으로 구분합니다.

운영 백업 입력을 새 로컬 자원에만 복원하는 도구와 별도의 합성 Docker 검사는
[백업 격리 복원 검사](backup-recovery.md)를 따릅니다. 운영 dump를 일반 pytest나 테스트 DB에
넣지 않으며, 합성 검사 성공과 실제 운영 백업 복원 결과를 구분합니다.
