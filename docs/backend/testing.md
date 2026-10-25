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
repositories, and local image storage together. Social-provider verification,
web metadata, AI recommendations, and OCR responses are replaced with deterministic
results. Unexpected external HTTP requests fail the test, even when caught by an
application fallback. No external credentials are required.

Migration API tests read actual asset rows from the same dedicated `TEST_DATABASE_URL`
session factory and use actual original bytes with the public backup publish/materialize
boundary. Their dump and trusted restore report are explicitly synthetic fixtures; they
do not use the default `DATABASE_URL` or require a host `pg_dump` executable. Actual paired
PostgreSQL dump, isolated restoration and the operator CLI gate are covered separately by
`tests/deployment/test_image_migration_docker.py` with the Docker opt-in below.

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

`tests/integration/test_category_submissions.py`는 카테고리 생성·수정의 같은 제출 결과 재사용,
계정·작업 종류·수정 대상·부분 수정 필드 구분, 거절 보존과 후속 수정·삭제 보존을 HTTP로 확인합니다.
독립 PostgreSQL 연결로 동시 제출과 commit 전 실패·commit 응답 유실을 구분합니다.
처리 기록의 삭제 보존·계정 삭제 정리도 함께 검사하며, 이는 운영 DB나 실제 앱 네트워크 검증이 아닙니다.

카테고리 제출의 현재 상태·수명 검사는 `tests/integration/test_category_submissions.py`에서 생성·수정 각각
독립 세션과 실제 commit으로 실행합니다. 원래 성공 뒤 별도 키 수정·삭제·같은 이름의 다른 ID 생성 후 원래 키를 재확인해도
원래 결과만 반환하고 최신 목록은 이후 상태를 유지해야 합니다. 삭제된 대상의 새 수정은 확정 거절이며,
카테고리 삭제 뒤 처리 기록 보존·기존 계정 삭제 계약 뒤 기록 제거를 확인합니다. 자동 TTL이나 새 회원 탈퇴 API는 추가하지 않습니다.

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

## 이미지·카테고리 migration 분기 통합

`tests/repositories/test_image_category_merge_migration.py`는 실제 Alembic CLI로 빈 DB와
기존 `202610250015`·`202610230018` 분기를 각각 `202610250019`로 업그레이드합니다.
대표 콘텐츠·local 원본 위치/무결성 정보·카테고리 제출 결과 보존, `alembic check`,
반복 업그레이드를 확인합니다. 이미 배포된 migration의 부모를 변경하지 않습니다.

이 검사는 `TEST_DATABASE_URL`의 전용 테스트 PostgreSQL 역할에 DB 생성 권한이 필요합니다.
무작위 이름의 격리 DB를 만들고 검사 종료 시 제거합니다. 운영 DB 자격증명으로 실행하지 않습니다.
기존 API 통합 검사는 초기화한 합성 삭제 기록 저장소와 local 원본을 사용하며,
실제 Railway 설정·이전 이미지 호환·삭제 기록 확인은 별도 배포 체크리스트로 남깁니다.

## Compatible local deployment handoff

The deployment CI job builds API and operator images from the same revision label and runs
`test_deletion_bootstrap_docker.py` plus `test_image_handoff_docker.py`. The handoff uses real
PostgreSQL, an isolated TLS S3 substitute, the packaged operator CLI, and the actual API upload,
read and delete routes with local original storage. OCR is intentionally unconfigured and follows
the existing fallback; no paid provider or operating database is used. A broken ledger must fail
checkpoint and image deletion even when ordinary readiness remains healthy.

To repeat locally after building both images from the same clean commit:

```bash
RUN_DOCKER_RECOVERY_TESTS=1 \
CLIPBACK_HANDOFF_API_IMAGE=clipback-compatible-api:validated \
CLIPBACK_LEDGER_OPERATOR_IMAGE=clipback-ledger-operator:validated \
CLIPBACK_HANDOFF_REVISION="$(git rev-parse HEAD)" \
pytest -q tests/deployment/test_deletion_bootstrap_docker.py tests/deployment/test_image_handoff_docker.py
```

Tests fail before creating resources if either image revision differs from the expected source.
Image IDs and revision labels are build provenance, not evidence of actual Railway configuration.
Use the [compatible deployment checklist](image-storage-compatible-deployment.md) for that evidence.

## 원본 운영자·점검·복원 통합 검사

GitHub Actions의 migration job은 PostgreSQL 18에서 기존 테스트 DB와 별도
`clipback_maintenance100`을 만들고 두 DB를 migration한다. 후자의 URL을
`MAINTENANCE_TEST_DATABASE_URL`로 제공해 다중 프로세스·취소·재시작 점검 검사가
누락되지 않게 한다. 이 DB는 다른 테스트/운영 DB와 공유하지 않는다.

기존 PostgreSQL 16 배포·삭제 기록 초기화 호환 검사는 유지한다. 별도 `operator-recovery` job은
같은 커밋 revision 라벨의 API와 PostgreSQL 18 운영자 이미지를 빌드하고, 수동 백업·비공개 원본
읽기·점검·권위 있는 복원 제어·기존 백업/다중 사용자 복원·DB 준비 검사를 실행한다.
이는 합성 Docker 환경이며 실제 Railway 성공이나 Mac SSH 연결의 증거가 아니다.

로컬에서 같은 검사를 실행할 때는 workflow의 이미지 환경변수와 PostgreSQL 16/18·Moto 이미지를
준비하고 해당 선택형 모듈을 같은 pytest 프로세스에서 순차 실행한다. 실행하지 않은 선택형 검사는
명시적으로 미실행으로 기록한다. 실제 운영 결과는 [첫 운영 체크리스트](image-operator-first-run.md)에
따라 별도로 남긴다.
