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

## #162 내려받은 폴더 쪽 현재 출력 고정과 이관 Docker 검사 CI 편입

`backend/tests/deployment/test_recovery_point_folder_outputs.py`를 추가하고, operator-recovery job 실행 목록에
`tests/deployment/test_image_migration_docker.py`를 넣었다(#145). 앱·운영 스크립트 코드는 바꾸지 않았다.

- 격리 복원 검사(`check_backup_restore`), `image_backup_jobs restore-check`, `restore_execution prepare`를 각 `main()`으로
  in-process 호출해 JSON 출력과 종료 코드를 비교한다. 보고서의 `elapsed_seconds`는 숫자인지만, `manifest_sha256`은
  폴더의 `manifest.json` 해시와 같은지만 확인하고 비교에서 뺀다.
- PATH 앞에 항상 실패하는 가짜 `docker`를 둔다. 그래서 폴더가 Docker 전 검사를 모두 통과하면 세 명령 모두
  `docker_command_failed`로 끝난다. `restore_execution prepare`는 loopback 설정 환경 변수만 주고, 실행 폴더가 생기지 않는지도 확인한다.
- `restore-check`는 DB 잠금(`source_lock`)과 삭제 기록 연결(`get_deletion_ledger`, 로컬 삭제 기록)만 대역으로 바꿨다.
- 내려받은 폴더는 테스트가 직접 만든다(v2 manifest, `database.dump`, `images.tar`). `download`나 `load_backup`을 거치지 않는다.
  tar에는 정규화한 경로마다 처음 asset 하나만 담는다. 실제 `download`는 충돌 경로에서 `unsafe_archive`로 실패하므로,
  이 폴더는 안전한 archive에 충돌 경로를 적은 manifest가 들어왔을 때 폴더 검사가 내는 결과를 보여 준다.
- 공통 입력(손상 manifest의 변경 함수, tar 경로 충돌, 상수)은 #161 테스트 파일에서 import해 두 표가 어긋나지 않게 했다.

### 입력 구성과 측정 결과

- 손상 manifest 22가지: #161의 목록에서 게시 manifest 전용인 두 경우를 폴더에 맞게 바꿨다
  (`images` 항목 있음 → `images` 항목 없음, `format_version: 1` → `format_version: 3`, `backup_id` 불일치 → 형식 위반).
- 측정값은 spec 표의 격리 복원 검사 열과 일치했다.
  - JSON 아님과 필드 없음 7가지는 일반 오류다: 격리 복원 검사 `invalid_input_or_check_failed`,
    `restore-check` `backup_job_failed`, `prepare` `restore_preflight_failed`.
  - 최상위가 객체 아님과 값 계약 위반은 세 명령 모두 `invalid_manifest`다.
  - `database.backup_key`가 다른 지점의 dump여도 Docker 단계까지 간다.
- tar 경로 충돌: 같은 `storage_key`는 Docker 단계까지 가고, `u/./1.png`와 `u/1.png`, `u/1.png`와 `u/1.png/x`는 `missing_asset`이다.
- 파일·archive 검사: `images.tar` 없음 `invalid_backup_file`, `images.tar`·`database.dump` 해시 불일치 `backup_hash_mismatch`,
  archive의 symlink `unsafe_archive`, archive에 없는 asset `missing_asset`, `sample.asset_id`가 asset에 없음 `invalid_manifest`.
- 판정 순서: 최상위 필드 위반 + DB 해시 불일치는 `invalid_manifest`, `images.tar` 없음 + DB 해시 불일치는 `backup_hash_mismatch`
  (database 항목이 images보다 먼저), DB 해시 불일치 + asset 계약 위반은 `backup_hash_mismatch`, archive 안전 검사 실패 + asset 계약 위반은
  `unsafe_archive`, 앞선 asset의 archive 누락 + 뒤 asset 계약 위반은 `missing_asset`, archive 누락 + `sample.asset_id` 없음은 `missing_asset`이다.
  같은 asset 안에서는 필드 검사가 archive 포함 확인보다 먼저라 `invalid_manifest`다.
- `format_version: 1` 폴더는 격리 복원 검사와 `prepare`에서 Docker 단계까지 간다. `restore-check`는 삭제 기록 체크포인트가 없어
  `deletion_checkpoint_required`다.
- import 경로: `scripts.check_backup_restore`에서 `CheckError`·`require`·`sha256_file`·`load_backup`을 import할 수 있고,
  `image_backup`·`image_backup_jobs`·`restore_execution`·`recovery_probe`의 `CheckError`, `image_migration` 등의 `require`·`sha256_file`이
  같은 객체임을 확인한다.

### 변경 감지 확인

`scripts/check_backup_restore.py`·`restore_execution.py`·`image_migration.py`를 복사해 두고 잠시 바꾼 뒤 되돌렸다.
되돌린 뒤 `git diff --stat scripts`는 비어 있었다.

| 임시 변경 | 실패한 테스트 수 |
| --- | --- |
| `load_backup`이 `database.backup_key` 검사 | 2 |
| asset 필드 검사를 archive 안전 검사 앞으로 | 2 |
| 격리 복원 검사의 일반 오류 코드 변경 | 8 |
| `restore_execution`의 일반 오류 코드 변경 | 8 |
| `image_migration`이 자체 `require` 정의 | 1 |
| archive 포함 확인에서 tar 경로 정규화 | 1 |
| images 파일 검사를 database 앞으로 | 1 |
| sample 검사를 asset 검사 앞으로 | 1 |

리뷰 반영 뒤 다시 실행한 결과다(위 변경 모두 실패를 냈다).

### 리뷰 반영

`/code-review` 지적 중 다음을 반영했다.

- 판정 순서 고정에 최상위 필드 vs 파일 해시, database vs images, archive 포함 vs sample 경우를 더했다.
- #161 파일과 중복되던 helper·입력 표를 import로 바꾸고, 입력과 기대 코드를 한 표로 합쳤다.
- `write_archive` 설명을 실제 동작(충돌 경로는 처음 asset만 담음)에 맞췄다.
- 항상 참인 `CheckError` 단언을 지우고 import 경로 테스트 이름을 고쳤다.
- [백엔드 테스트 안내](../backend/testing.md)의 이관 Docker 검사 안내가 operator-recovery 절의 이미지 환경 변수를 가리키게 했다.

반영하지 않은 지적과 실행 전제:

- 폴더 검사의 마지막 단계는 `tempfile.gettempdir()`에 약 1 GiB 여유를 요구한다. 여유가 없으면 Docker 단계까지 가야 할 경우가
  `insufficient_disk_space`로 바뀐다. 운영 코드의 실제 검사이므로 대역으로 바꾸지 않았다(#161의 download도 같다).
- `restore_execution prepare`는 실행 폴더가 git 저장소 밖이어야 한다. pytest 기본 `tmp_path`는 저장소 밖이며,
  `--basetemp`를 저장소 안으로 주면 `workspace_inside_repository`가 먼저 난다.

### #145 CI 편입

`test_image_migration_docker.py`는 이미 operator-recovery 목록에 있는 `test_image_backup_docker.py`의 `bucket_backup` fixture와
같은 이미지 환경 변수(`CLIPBACK_RECOVERY_TEST_IMAGE` 등)를 쓴다. 그래서 실행 목록에 파일만 추가했다.
[백엔드 테스트 안내](../backend/testing.md)의 이관 검사 설명과 operator-recovery 설명을 실제 구성에 맞췄다.
`actionlint 1.7.12`로 workflow 오류가 없음을 확인했다. 현재 코드로 이 검사가 통과하는지는 PR 1 CI에서 확인한다.

### 검증

2026-11-01 이 worktree의 `backend/`에서 #161과 같은 환경(Python 3.12.7 venv, 로컬 PostgreSQL 17의 `clipback_test`·
`clipback_maintenance100`, 로컬 관리자 계정 URL, `YOUTUBE_SUMMARY_ENABLED=false`)으로 실행했다.

- `ruff check app scripts alembic tests`, `python -m compileall app alembic tests scripts`, `git diff --check`,
  `actionlint .github/workflows/backend-validation.yml`: 통과. `backend/scripts`·`backend/app` diff 없음.
- `pytest -q -rs`: 1464 passed, 46 skipped. skip 45건은 `*_docker.py`, 1건은 #161과 같은
  `tests/integration/test_image_storage_admin_cli.py`(범위 밖, CI에서도 skip)다.
  skip 줄 수를 세려고 같은 명령을 한 번 더 실행했고 결과는 같았다.
- 새 테스트 파일 두 개: 121 passed.
- `test_image_migration_docker.py`를 포함한 Docker 테스트는 로컬에서 실행하지 않았다. PR 1 CI의 operator-recovery job 성공과
  pytest 요약의 skipped 0으로 확인한다.

## #163 복구 지점 module과 운영 오류 module 추가(확장)

origin/main(`5f2a87c`, #147 요약 리팩터링)을 먼저 merge했다(`fc3930b`). 작업 이력 목차 충돌은 양쪽 줄을 모두 남겼다.

- `backend/scripts/operator_errors.py`: `CheckError`·`require`·`sha256_file`을 `check_backup_restore`에서 옮겼다.
  `check_backup_restore`는 셋을 import해 같은 객체로 다시 내보낸다. 과거 리비전 API 이미지의 격리 복원 probe가 이 경로를 쓰기 때문이다.
- `backend/scripts/recovery_point.py`(복구 지점 module):
  - 키 배치: `original_key`, `point_prefix`, `point_dump_key`, `point_manifest_key`, `receipt_key`, `receipt_backup_id`(형식이 틀리면 `None`)
  - 형식: `require_backup_id(value, code)`, `require_app_commit(value, code)`. 오류 코드는 호출 쪽이 넘긴다.
    지금처럼 문자열이 아닌 값은 `re.fullmatch`의 `TypeError`가 그대로 나가 각 CLI의 일반 오류가 된다.
  - 게시된 복구 지점: `completed_points(store)`, `read_point_manifest(store, backup_id)`(id 형식 검사와 JSON 읽기만),
    `read_retiring_points(store)`(정리 receipt마다 이름 검사 → JSON 읽기를 하나씩 내보내는 generator. maintain이 receipt마다
    완료 지점과의 충돌을 바로 판정하는 지금 순서를 지키기 위해서다)
  - 내려받은 복구 지점: `load_backup(directory)`와 `validate_archive`를 `check_backup_restore`에서 그대로 옮겼다.
    달라진 줄은 `backup_id`·`app_commit` 정규식 두 줄을 위 형식 함수 호출로 바꾼 것뿐이다(`diff`로 확인).
  - `canonical_json`
  - `completed_points`의 정규식 `points/<id>/manifest.json`의 `.`은 지금처럼 이스케이프하지 않은 채 옮겼다(동작 보존).
- 위임으로 남긴 기존 이름: `check_backup_restore.load_backup`·`validate_archive`(import 재수출), `image_backup.canonical_json`(import 재수출),
  `BackupBucket.completed_points`·`read_manifest`(새 module 호출). 호출하는 쪽 코드는 바꾸지 않았다.
  `validate_archive`는 #166 목록에 없지만 `load_backup`과 함께 옮긴 이름이라 #166에서 같이 지운다.
- 새 파일 2개를 API 이미지 `Dockerfile`, `Dockerfile.operator`, `.dockerignore` 허용 목록에 추가했다. Docker가 꺼져 있어 빌드는 하지 않았고,
  두 Dockerfile의 `COPY` 목록이 `.dockerignore` 허용 목록에 있고 복사한 운영 스크립트가 import하는 `scripts` module을 모두 포함하는지 스크립트로 확인했다.
- 새 테스트 `backend/tests/deployment/test_recovery_point.py`: moto와 임시 폴더로 키 배치·receipt 키 왕복, 형식 검사, 완료 지점 목록,
  지점 manifest 읽기, 정리 중인 지점 읽기, 내려받은 폴더 검사, 정규 JSON을 확인한다. module이 없을 때 import 오류로 실패하는 것을 먼저 확인했다.

### 격리 복원 검사의 실행 방법 변경

`check_backup_restore`가 `scripts.operator_errors`·`scripts.recovery_point`를 import하므로, 운영 문서가 안내하던
`python3 backend/scripts/check_backup_restore.py ...`(파일 직접 실행)는 `ModuleNotFoundError: No module named 'scripts'`로 실패한다.
사용자 결정(2026-11-01)에 따라 대비 코드를 넣지 않고 [백업·복구 운영 문서](../backend/backup-recovery.md#준비와-실행)의 명령을
`backend/`에서 `python3 -m scripts.check_backup_restore ...`로 실행하도록 바꿨다. 두 방식을 실제로 실행해 새 명령은 도움말이 나오고
옛 명령은 위 오류가 나는 것을 확인했다. 문서의 다른 직접 실행 안내(`scripts/check_deployment.py`, `scripts/image_deletions.py`)는
`scripts` 패키지를 import하지 않아 이번 변경과 무관하다. PR 1 본문에도 이 실행 방법 변경을 적는다.

### 리뷰 반영

`/code-review` 지적 중 `load_backup`이 원본 보관본 키를 직접 조립하던 곳을 같은 module의 `original_key()` 호출로 바꿨다.
다음은 반영하지 않았다.

- 파일 직접 실행 유지(`sys.path` 보정): 사용자 결정에 따라 문서 명령을 바꾸는 쪽을 택했다.
- 형식 검사의 `TypeError`, `completed_points` 정규식의 이스케이프하지 않은 `.`: 지금 동작을 그대로 옮겼다. 앞의 것은 #167의 통일 대상이다.
- `read_retiring_points`를 목록 반환으로 바꾸기: receipt마다 이름 검사와 완료 지점 충돌 판정이 번갈아 나오는 지금 순서가 달라진다.
  maintain은 삭제 전에 전체 목록을 모으므로 generator여도 중간 삭제가 생기지 않는다.
- `validate_archive`의 파일 수 제곱 시간: 범위 밖 성능 문제로 따로 보고한다.
- 명령 쪽에 남은 키 문자열·정규식, `image_backup`의 두 가지 import 방식: #164·#166 범위다.

### 검증

2026-11-01 이 worktree의 `backend/`에서 #161과 같은 환경으로 실행했다(origin/main merge 뒤).

- `ruff check app scripts alembic tests`, `python -m compileall app alembic tests scripts`, `git diff --check`: 통과.
  `recovery_probe.py`와 #161·#162 고정 테스트 파일 diff 없음.
- `pytest -q -rs`: 1615 passed, 46 skipped. skip은 Docker 45건과 `tests/integration/test_image_storage_admin_cli.py` 1건(범위 밖, CI에서도 skip)이다.
  merge로 들어온 #147 테스트가 더해져 통과 수가 늘었다.
- Docker 이미지 빌드와 Docker 테스트는 로컬에서 실행하지 않았다. 새 파일이 이미지에 들어갔는지는 PR 1 CI의 operator-recovery에서 확인한다.

## #164 백업 생성·verify·download·maintain을 복구 지점 module로(이전, Bucket 쪽)

`backend/scripts/image_backup.py`(게시·`create_backup`·`verify_backup`·`materialize_backup`)와
`backend/scripts/image_backup_jobs.py`(`maintain_backups`, `run_job`의 daily 중복 확인, CLI 인자 형식 검사)가
키 배치·식별자 형식·게시된 manifest 읽기를 복구 지점 module에서 가져온다. 명령별 검사 내용과 순서는 그대로다.

- 키: 원본 보관본·지점 dump·지점 manifest·정리 receipt 키와 지점 접두사를 module 함수로 바꿨다.
  목록 조회 접두사(`originals/`·`points/`·`gc/points/`)와 지점 키 → id 변환도 키 배치라서 module에
  `ORIGINALS_PREFIX`·`POINTS_PREFIX`·`RECEIPTS_PREFIX`·`point_id`를 더하고 썼다(테스트를 먼저 추가해 실패를 확인했다).
- 형식: `backup_id`(`invalid_backup_id`·`backup_id_required`)와 `app_commit`(`invalid_manifest`·`app_commit_required`) 검사를
  `require_backup_id`·`require_app_commit`으로 바꿨다. 오류 코드는 지금과 같다.
- 게시된 manifest 읽기: `verify`의 처음 읽기와 재조회, `download`, `maintain`의 완료 지점 읽기가 `read_point_manifest`를,
  `maintain`의 정리 receipt 읽기가 `read_retiring_points`를 쓴다. receipt마다 이름 검사 → JSON 읽기 → 완료 지점과의 충돌 판정 순서는 같다.
- `BackupBucket.completed_points`·`read_manifest`와 `image_backup.canonical_json`은 다른 호출 쪽(테스트 등)을 위해 #166까지 남긴다.
- 두 파일에서 `originals/`·`points/`·`gc/points` 문자열과 `backup_id`·`app_commit` 정규식이 남지 않았음을 `grep`으로 확인했다.
  `image_storage_admin`, `restore-check`(#165), 격리 복원 probe는 대상이 아니다.

### 리뷰 반영

`/code-review`는 동작 회귀를 찾지 못했다. 지적 중 키 함수가 접두사 상수로 키를 만들게 해 접두사 정의를 한 곳으로 모았다.
다음은 반영하지 않았다.

- `completed_points` 정규식의 이스케이프하지 않은 `.`과 `point_id`가 키 모양을 검사하지 않는 점: 지금 동작을 그대로 옮겼다
  (`manifestXjson` 같은 객체도 완료 지점으로 센다). 범위 밖 발견으로 따로 보고한다.
- `verify`·`maintain`에 남은 sha256 형식 정규식: 이 티켓 범위(키 문자열과 `backup_id`·`app_commit` 정규식) 밖이며 #167의 통일 대상이다.
- daily와 게시가 `points/` 전체 목록을 두 번 조회하는 비용: 지금 동작이며 범위 밖 발견으로 보고한다.
- 생산 코드 호출이 없어진 `BackupBucket.completed_points`·`read_manifest`: #166에서 지운다.

### 검증

2026-11-01 이 worktree의 `backend/`에서 #161과 같은 환경으로 실행했다.

- `ruff check app scripts alembic tests`, `python -m compileall app alembic tests scripts`, `git diff --check`: 통과.
  `recovery_probe.py`와 #161·#162 고정 테스트 파일 diff 없음(#161의 게시 결과 고정 테스트 포함 수정 없이 통과).
- `pytest -q -rs`: 1618 passed, 46 skipped. skip은 Docker 45건과 `tests/integration/test_image_storage_admin_cli.py` 1건(범위 밖, CI에서도 skip)이다.
- Docker 테스트는 로컬에서 실행하지 않았다. PR 1 CI의 operator-recovery에서 확인한다.

## #165 격리 복원 검사·restore-check·restore_execution·image_migration을 복구 지점 module로(이전, 폴더 쪽)

- 격리 복원 검사(`check_backup_restore.check`), `restore-check`(`check_latest_restore`), `restore_execution prepare`,
  `image_migration`의 복구 지점 확인이 내려받은 폴더 검사 `load_backup`을 복구 지점 module에서 가져온다.
  #164에서 빠졌던 `download`(`materialize_backup`) 끝의 폴더 검사도 같이 옮겼다.
- `restore_execution run`은 작업 폴더에 복사한 manifest를 검증 없이 JSON으로만 읽어 `deletion_checkpoint`를 꺼낸다.
  여기에 `load_backup`을 쓰면 파일 해시·디스크 여유 검사가 더해져 동작이 바뀐다. 그래서 module에 검증 없는 읽기
  `read_downloaded_manifest(directory)`를 더해 이 자리와 `load_backup`의 첫 줄에 같이 썼다(테스트를 먼저 추가해 실패를 확인했다).
- 명령별 규칙은 명령에 남겼다: 이관의 `migration_requires_v2_backup`, 각 CLI의 일반 오류 코드 매핑.
- `check_backup_restore`의 `load_backup`·`validate_archive` 재수출은 아직 이 이름을 쓰는 테스트를 위해 #166까지 남긴다.

### 리뷰 반영

`/code-review`는 정확성 문제를 찾지 못했다. ADR 0004 주석이 `CheckError` 재수출 줄 바로 위에 오도록 위치만 고쳤다.
`check()`가 `recovery_point.load_backup`을 module 이름으로 부르는 형태는 #166에서 `check_backup_restore.load_backup` 이름을
완전히 없애기 위해 유지한다. 다음은 지금 동작이라 반영하지 않고 범위 밖 발견으로 보고한다.

- `restore_execution run`이 작업 폴더의 manifest 사본을 다시 검사하지 않는다(prepare 이후 사본이 바뀌면 그대로 믿는다).
- `restore-check`가 같은 폴더에 `load_backup`을 두 번 실행해 dump·archive를 두 번 해시한다.
- 격리 복원 검사와 이관이 `load_backup`으로 검사한 뒤 `manifest.json`을 따로 다시 읽어 해시한다.
- 다운로드 폴더의 `manifest.json` 파일 이름이 여러 호출 쪽에 문자열로 남아 있다(파싱은 모두 module을 거친다).

### 검증

2026-11-01 이 worktree의 `backend/`에서 #161과 같은 환경으로 실행했다.

- `ruff check app scripts alembic tests`, `python -m compileall app alembic tests scripts`, `git diff --check`: 통과.
  `recovery_probe.py`와 #161·#162 고정 테스트 파일 diff 없음.
- `pytest -q -rs`: 1619 passed, 46 skipped. skip은 Docker 45건과 `tests/integration/test_image_storage_admin_cli.py` 1건(범위 밖, CI에서도 skip)이다.
  이관 경로 테스트 `tests/integration/test_image_migration.py`는 `TEST_DATABASE_URL`로 skip 없이 통과했다.
- Docker 테스트는 로컬에서 실행하지 않았다. PR 1 CI의 operator-recovery에서 확인한다.

## #166 위임용 옛 이름 제거(축소)

- 지운 이름: `check_backup_restore`의 `load_backup`·`validate_archive` 재수출, `BackupBucket.completed_points`·`read_manifest`.
  `validate_archive`는 티켓 목록에 없지만 #163에서 `load_backup`과 함께 옮긴 이름이라 같이 지웠다.
  백업 스크립트의 정규 JSON 함수는 #163에서 정의를 지우고 복구 지점 module에서 import하게 했으므로, 이를 `image_backup`에서
  import하던 테스트가 없음을 확인하는 것으로 마쳤다.
- 남긴 것: `check_backup_restore`의 `CheckError`·`require`·`sha256_file` 재수출. 과거 리비전 이미지의 격리 복원 probe가 이 경로를 쓴다(ADR 0004).
- 테스트 import를 `scripts.recovery_point`로 바꿨다. 테스트 의도와 기대값은 그대로다.
  - `test_image_backup.py`, `test_image_backup_retention.py`, `test_backup_restore.py`, `test_image_backup_docker.py`
  - `test_manual_backup_docker.py`·`test_remote_source_backup_docker.py`: operator 이미지 안에서 실행하는 코드 문자열의
    `s.read_manifest(...)`·`s.completed_points()`를 `read_point_manifest(s, ...)`·`completed_points(s)`로 바꿨다.
  - #162 고정 테스트의 import 경로 목록에서 `load_backup` 한 줄만 뺐다(사용자 허용, 2026-11-01).
- `rg`로 옛 이름(`check_backup_restore`에서의 `load_backup`·`validate_archive` import, `.read_manifest(`, `.completed_points(`,
  `image_backup`의 `canonical_json`)이 코드·테스트·현재 문서에 남지 않았음을 확인했다. 남은 일치는 module 함수 `recovery_point.completed_points` 호출뿐이다.
  Python에서도 세 위치에 옛 속성이 없고 `CheckError`가 `operator_errors`의 것과 같은 객체임을 확인했다.
- `pytest -q --collect-only tests/deployment`로 Docker 테스트 파일의 import 변경이 수집 단계에서 깨지지 않음을 확인했다(리뷰 반영 뒤 318개 수집).

### 리뷰 반영

`/code-review`는 정확성 문제를 찾지 못했다. 지적 중 두 가지를 반영했다.

- `image_backup`이 복구 지점 module 이름을 모두 직접 import하게 통일했다(`canonical_json`만 module 이름으로 부르던 것을 정리).
- 옛 이름이 돌아오지 않게 `test_recovery_point.py`에 `check_backup_restore`·`BackupBucket`에 옛 속성이 없는지 확인하는 테스트를 더했다.
  #161·#162 고정 테스트에는 더하지 않았다.

`image_backup`·`image_backup_jobs`·`image_migration`이 `CheckError`·`require`·`sha256_file`을 `check_backup_restore` 재수출로 가져오는 기존 의존은
ADR 0004가 그 재수출을 유지하므로 바꾸지 않았다.

### 검증

2026-11-01 이 worktree의 `backend/`에서 #161과 같은 환경으로 실행했다.

- `ruff check app scripts alembic tests`, `python -m compileall app alembic tests scripts`, `git diff --check`: 통과.
- `pytest -q --collect-only tests/deployment`: 318개 수집, 오류 없음.
- `recovery_probe.py`와 #161 고정 테스트 diff 없음. #162 고정 테스트 diff는 import 경로 목록의 `load_backup` 한 줄 삭제뿐이다.
- `pytest -q -rs`: 1620 passed, 46 skipped. skip은 Docker 45건과 `tests/integration/test_image_storage_admin_cli.py` 1건(범위 밖, CI에서도 skip)이다.
- Docker 테스트(코드 문자열을 바꾼 두 파일 포함)는 로컬에서 실행하지 않았다. PR 1 CI의 operator-recovery에서 확인한다.

## PR 1 본문에 적을 것(#161~#166)

- `Closes #145`. operator-recovery 실행 목록에 `tests/deployment/test_image_migration_docker.py`를 넣었다.
- 확인할 CI: operator-recovery job 성공과 pytest 요약의 skipped 0(`test_image_migration_docker.py` 포함). Docker 검사는 로컬에서 실행하지 않았다.
- 운영자에게 보이는 변경은 하나다: 격리 복원 검사를 `backend/`에서 `python3 -m scripts.check_backup_restore ...`로 실행한다.
  옛 명령 `python3 backend/scripts/check_backup_restore.py ...`는 `ModuleNotFoundError: No module named 'scripts'`로 실패한다.
  CLI 출력·오류 코드·종료 코드·백업 저장 형식·환경 변수는 #161·#162 고정 테스트로 확인한 대로 바뀌지 않았다.
- 새 파일 `scripts/operator_errors.py`·`scripts/recovery_point.py`는 API 이미지·operator 이미지·`.dockerignore`에 들어 있다.
