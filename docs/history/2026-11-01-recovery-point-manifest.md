# 복구 지점 manifest 동작 고정과 module 이전

최초 기록일: 2026-11-01 KST. 기준은 [spec #156](https://github.com/clip-back/clipback/issues/156)과
하위 티켓 #161~#166, [ADR 0004](../adr/0004-recovery-point-manifest-single-standard.md)다.
통합 브랜치 `refactor/backup-manifest`(main `06bc24d` + 용어집·ADR 커밋 `e224d11`)에서 작업했다.
#161~#166은 동작 변경이 없는 구조 이전이며, 검증 기준 통일(#167)은 이 기록의 범위가 아니다.

## #161 Bucket 쪽 현재 출력 고정

`backend/tests/deployment/test_recovery_point_bucket_outputs.py`를 추가했다. 앱·운영 스크립트 코드는 바꾸지 않았다.

- `image_backup`의 `verify`·`download`, `image_backup_jobs`의 `maintain`을 각 `main()`으로 in-process 호출해
  JSON 출력과 종료 코드를 비교한다. `download`는 실패 뒤 남은 다운로드 폴더의 파일 목록(없으면 `None`)도 비교한다.
- 백업 Bucket은 moto다. `BackupBucket.from_environment`만 moto Bucket을 돌려주도록 바꿨다.
- `maintain`은 실행 환경 조립만 대역으로 바꿨다: `MaintenanceRuntime`, `MaintenanceGate`, `source_lock`,
  `get_deletion_ledger`(로컬 삭제 기록). 보존 판단·manifest 처리·출력 매핑은 실제 코드다.
- 이후 단계(#163~#166)에서 지울 위임용 옛 이름(`load_backup`, Bucket adapter의 manifest 읽기·완료 지점 목록,
  `canonical_json`)은 이 테스트에서 쓰지 않는다. Bucket에는 boto3 client로 직접 쓰고 읽는다.

### 입력 구성

spec은 "손상 manifest 22가지"를 측정했다고 적었지만 목록은 적지 않았다. 그래서 spec의
"검증 기준 통일로 바뀌는 것" 표의 행을 모두 덮도록 아래 22가지를 구성했다.

| 분류 | 경우 |
| --- | --- |
| JSON·객체 | JSON 아님, 최상위가 배열 |
| 필수 필드 없음 | `database`, `assets`, `captured_at`, `postgres_major`, `migration_revisions`, asset `sha256` |
| 필드 값 계약 위반 | `app_commit` 형식, `origin`, 허용 밖 필드, 게시 manifest의 `images` 항목, `tables` 음수, asset `content_id` 없음, `captured_at` 시간대 없음, `backup_id` 불일치, asset `storage_backend`, asset `backup_key` |
| 크기 값이 정수 아님 | asset `size_bytes` 문자열, `database.size_bytes` 문자열 |
| 키 | `database.backup_key`가 다른 지점의 dump |
| 형식 버전 | `format_version: 1` |

- 각 경우를 신선한 지점(0.1일)과 만료 지점(8일)에 넣고, `maintain`은 정리 receipt로만 남은 지점(8일)도 확인한다.
  모든 경우에 정상 신선도용 지점 `anchor`(1시간 전)를 함께 둔다.
- tar 경로 충돌 3가지(같은 `storage_key`, `u/./1.png`와 `u/1.png`, `u/1.png`와 `u/1.png/x`) × 신선·만료.
- 오류가 겹치는 경우: verify의 계약 위반 + 원본 보관본 해시 불일치, verify가 다시 읽은 manifest가 JSON 아님
  (boto3 GetObject 두 번째 호출 직전에 객체를 바꿈), download의 계약 위반 + dump 해시 불일치,
  maintain의 receipt 충돌 + 계약 위반, maintain의 계약 위반 + dump 없음.
- 정상 지점의 성공 출력.
- 게시 결과: 같은 입력(local·Bucket 원본 각 1개, Bucket 원본 키에 한글 포함)으로 두 지점을 게시하고,
  `maintain`이 첫 지점의 정리 receipt를 쓴 뒤 manifest 삭제에서 막히게 했다. Bucket 키 목록과
  manifest·receipt 바이트(정규 JSON, `ensure_ascii`)를 리터럴로 비교한다.

### 측정 결과와 spec 표

측정값은 spec 표와 모두 일치해 표를 고치지 않았다. 표에 없던 세부 값은 다음과 같다.

- verify: `postgres_major` 없음, `app_commit`·`origin`·허용 밖 필드·`images` 항목·`tables` 음수·asset `content_id` 없음·
  `captured_at` 시간대 없음은 성공(종료 코드 0)이다. `backup_id` 불일치·`format_version`·크기 문자열·
  `database.backup_key`·asset `storage_backend`·`backup_key`는 `invalid_manifest`, JSON 아님·배열과 그 밖의 필드 없음은 `backup_operation_failed`다.
- download가 남기는 폴더: JSON 아님·배열·`format_version`·`backup_id` 불일치는 폴더 없음, `database` 없음은 빈 폴더,
  `database.size_bytes` 문자열은 `database.dump`만, asset 단계 실패는 `database.dump`·`images.tar`,
  그 밖은 세 파일 모두 남는다. 게시 manifest의 `images` 항목과 `database.backup_key` 위반은 다운로드에 성공한다.
- maintain: asset `size_bytes` 문자열은 같은 원본 보관본을 `anchor`가 먼저 확인해 신선한 지점에서도 성공한다.
  정리 receipt로만 남은 지점은 만료 지점과 같은 결과다.

### 변경 감지 확인

`scripts/image_backup.py`·`scripts/image_backup_jobs.py`를 복사해 두고 아래처럼 잠시 바꾼 뒤 복사본으로 되돌렸다.
되돌린 뒤 `git diff --stat scripts`는 비어 있었고 테스트는 다시 모두 통과했다.

| 임시 변경 | 실패한 테스트 수 |
| --- | --- |
| verify가 `app_commit` 길이를 검사 | 3 |
| 정규 JSON `ensure_ascii=False` | 1 |
| download가 폴더 생성 전에 `app_commit` 검사 | 3 |
| maintain 일반 오류 코드 변경 | 14 |
| 정리 receipt 키 경로 변경 | 1 |
| verify의 manifest 재조회 제거 | 1 |
| maintain의 원본 보관본 중복 확인 생략 제거(리뷰 반영 뒤) | 1 |

### 리뷰 반영

`/code-review` 지적 중 다음을 반영했다.

- asset `size_bytes` 문자열에서 앞선 지점이 같은 원본 보관본을 확인하지 않은 경우의 maintain `backup_hash_mismatch`를 따로 고정했다.
- verify 재조회 테스트가 manifest 읽기 횟수를 단언하지 않게 했다. manifest가 아닌 객체를 처음 읽을 때 manifest를 바꾼다.
- 손상 경우마다 세 명령의 결과를 한 번에 비교해, 한 명령의 차이가 다른 명령의 차이를 가리지 않게 했다.
- 게시 결과 테스트의 `Settings`에 `app_environment`·`storage_backend`를 지정해 셸 환경 변수에 흔들리지 않게 했다.
- 점검 게이트 대역은 `tests/support/maintenance.OpenUnitGate`를 재사용하고, 두 번째 manifest 바이트는 첫 리터럴의 세 부분 치환으로 적었다.

반영하지 않은 지적과 이유:

- 일반 오류 코드(`backup_operation_failed`·`backup_job_failed`)는 예외 종류를 구분하지 못한다. spec이 고정 대상을 CLI 출력과 종료 코드로 정했으므로 그대로 둔다.
- 게시 결과 테스트는 moto의 bucket policy Deny로 receipt를 남긴다. 기존 `test_partial_cleanup_keeps_legacy_identity_until_late_retry_is_reported`도 같은 방식에 기대고 있다.

### 검증

2026-11-01 이 worktree의 `backend/`에서 Python 3.12.7 venv(`pip install -e ".[dev]"`)로 실행했다.

- `ruff check app scripts alembic tests`: 통과. `python -m compileall app alembic tests scripts`: 통과. `git diff --check`: 통과.
- 테스트 DB: 로컬 PostgreSQL 17에 CI와 같은 이름의 `clipback_test`·`clipback_maintenance100`을 만들고
  `YOUTUBE_SUMMARY_ENABLED=false`로 `alembic upgrade head`·`alembic check`를 적용했다. 로컬 `postgres` 계정은 DB 생성 권한이 없어
  로컬 관리자 계정으로 만들었고 서버 설정은 바꾸지 않았다.
- 처음 전체 실행에서 `TEST_DATABASE_URL`을 `postgres` 계정으로 지정하자 임시 DB를 만드는
  `tests/repositories/test_image_category_merge_migration.py` 3건이 `permission denied to create database`로 실패했다.
  환경 문제라 `TEST_DATABASE_URL`·`MAINTENANCE_TEST_DATABASE_URL`을 로컬 관리자 계정으로 바꿔 다시 실행했다.
- `pytest -q -rs`(`YOUTUBE_SUMMARY_ENABLED=false`, 두 DB URL 지정): 1423 passed, 46 skipped.
  skip 45건은 `*_docker.py`이고, 1건은 `tests/integration/test_image_storage_admin_cli.py`(`CLIPBACK_IMAGE_TEST_S3_ENDPOINT` 필요)다.
  이 파일은 이번 범위 밖이며 CI에서도 같은 이유로 건너뛴다. 로컬 moto 서버는 flask가 설치되지 않아 띄우지 않았다.
- 새 테스트 파일: 80 passed.
- Docker 테스트는 로컬에서 실행하지 않았다. PR 1 CI의 operator-recovery job에서 확인한다.
