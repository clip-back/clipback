# 자동 요약 종류별 처리 모으기와 요약 결과 이름 정리

최초 기록일: 2026-11-01 KST. 기준은 [spec #147](https://github.com/clip-back/clipback/issues/147)과
하위 티켓 #148~#155다. 경계와 채택하지 않은 대안은 [ADR 0003](../adr/0003-summary-kind-module-boundary.md)을 따른다.
통합 브랜치 `refactor/summary-kind`(main `06bc24d` + 용어집·ADR 커밋 `3ecac5f`)에서 티켓마다 커밋했다.
동작 변경이 없는 백엔드 리팩터링이라 CHANGELOG에는 넣지 않았다.

## 공통 검증 환경

- 이 worktree의 `backend/`에서 Python 3.12 새 `.venv`로 실행했다. Docker는 사용하지 않았다.
- 로컬 PostgreSQL(5432)에 CI와 같은 이름의 `clipback_test`·`clipback_maintenance100`을 만들고
  두 DB에 `alembic upgrade head`·`alembic check`를 적용했다(`YOUTUBE_SUMMARY_ENABLED=false`).
- 로컬 `postgres` role에는 CREATEDB 권한이 없어 `tests/repositories/test_image_category_merge_migration.py` 3건이
  임시 DB를 만들지 못했다. 서버 role은 바꾸지 않고 `TEST_DATABASE_URL`·`MAINTENANCE_TEST_DATABASE_URL`을
  로컬 superuser 접속(`postgresql+asyncpg://<로컬 superuser>@localhost:5432/<DB>`)으로 지정해 전체 `pytest -rs`를 실행했다.
  DB 이름과 migration 적용 조건은 CI와 같고 접속 role만 다르다.
- 원격 CI·운영 서버 검증은 하지 않았다. 앱 화면 변경이 없어 시뮬레이터·에뮬레이터는 실행하지 않았다.

## #148 현재 동작 고정 테스트

spec의 표 4개를 앱 코드 변경 없이 테스트로 고정했다. spec은 이후 티켓이 이 테스트를 고치지 않고 통과하도록 정했다.
테스트는 API 응답, DB에 저장된 작업 값, 로그 JSON, 요약 client의 반환값만 본다. worker의 `claim()` 반환값,
내부 client 사전, 요약 결과 클래스 이름(`VideoSummary`)·오류 클래스 import 위치에는 기대지 않는다.

- `tests/integration/test_summary_job_creation.py`: 요약 작업 생성 표와 덮어쓰기 허용값(`apply_*`).
- `tests/integration/test_summary_log_contract.py`: 이벤트별 키의 존재·부재, 종류·단계별 provider와 usage,
  로그가 남지 않는 경우. 작업은 API로 저장하고 PostgreSQL에서 실제로 점유한다. client는 가짜 HTTP만 받는다.
  로그는 `app` logger 아래 어디서 남든 `youtube_summary_*` 이벤트를 모은다.
- `tests/integrations/test_summary_result_validation.py`: 제목 120자·요약 500자 경계, 공백만 있는 값, 카테고리 값 처리 표.

spec 표에 값이 없던 현재 동작도 함께 고정했다. 인스타그램 페이지 요청의 `httpx.ReadTimeout`은 페이지 전체 시간 상한(5초)과 달리
`timeout`이 아닌 `provider_error`(provider `"instagram"`)다. 메타데이터 client가 httpx 오류를 `request_failure`로 분류하기 때문이다.

spec 표와 다른 실제 동작 1건을 확인했고, 사용자 확인(2026-11-01)에 따라 테스트를 실제 동작에 맞췄다.

- 인스타그램 `/reels/<code>`·사용자 경로(`/<user>/reel/<code>`)·프로필(`/<user>/`)은 일반 저장과 공유 저장 모두
  422 `Unsupported Instagram URL path`로 거절되어 콘텐츠와 작업이 만들어지지 않는다. spec 표는 이 링크들을
  "저장되지만 작업 없음"의 예로 들었다. 작업이 없다는 결과는 같다.

변경 감지 확인: 앱 코드를 잠시 바꿔 해당 테스트가 실패하는지 본 뒤 되돌렸다. 스위치와 스토리 판정 순서 바꾸기,
`youtube_summary_stale_result`에 `kind` 추가, 유튜브 `category_id` 검사를 `isinstance`로 바꾸기가 모두 실패로 드러났다.

알려진 결합: 인스타그램 시도 시간 상한(90초) 테스트는 `instagram_summary_client.ATTEMPT_TIMEOUT_SECONDS`를 줄여 실행한다.
실제 90초를 기다리지 않기 위한 것이며, 이 상수는 종류 고유 처리로 client에 남는다.

리뷰(Standards·Spec 두 축) 반영: 유튜브 지역·연령 제한과 인스타그램 페이지 전송 오류·시간 초과 행 추가,
worker 반복 오류 테스트에 가짜 client를 넘기고 단위 테스트용 `OpenUnitGate` 대신 테스트 안의 열린 gate 사용,
로그 수집 범위를 `app` logger로 넓힘, 이름 정리.

| 검사 | 결과 |
| --- | --- |
| 새 고정 테스트 3개 파일 | 123개 통과 |
| `ruff check app scripts alembic tests` | 통과 |
| `python -m compileall app scripts alembic tests` | 통과 |
| 전체 `pytest -q -rs` (PostgreSQL 포함) | 1466개 통과, 46개 skip(Docker·빌드 이미지가 필요한 `tests/deployment` 45개, `CLIPBACK_IMAGE_TEST_S3_ENDPOINT`가 필요한 로컬 S3 CLI 1개). 요약 관련 대상 테스트 skip 없음 |
| `git diff --check` | 통과 |
| "바뀌지 않는 것" 확인 | `backend/app`·`backend/alembic`·`.github` diff 없음, 변경 경로가 `operator_recovery` 필터와 겹치지 않음 |
