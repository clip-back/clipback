# 복구 지점 manifest 검증 기준 통일

최초 기록일: 2026-11-02 KST. 기준은 [spec #156](https://github.com/clip-back/clipback/issues/156)의
"검증 기준 통일로 바뀌는 것" 표와 "오류가 겹칠 때의 판정 순서" 표, 티켓 #167과 그 댓글 두 개다.
브랜치 `fix/backend-manifest-contract`(main `f1e40f6` 기준)에서 작업했다. 구조 이전(#161~#166)은
[복구 지점 manifest 동작 고정과 module 이전](2026-11-01-recovery-point-manifest.md)에 있다.

## 사용자 결정

- #167 댓글 1(sha256 형식 검사 통일): 범위에 넣는다. 문자열이 아닌 값도 모든 명령에서 `invalid_manifest`로 바꾸고
  `verify_backup`의 `TypeError` 가드를 지운다. PR 본문 변경 목록에 "그 밖의 모든 경우" 행으로 적는다.
- #167 댓글 2(지점 ID가 `.`·`..`을 허용): 이번에 함께 막는다(2026-11-02). 지점 ID 검증을 복구 지점 module 한곳에서 한다.
- 되돌리기 기준 리비전: #166이 든 PR 1 squash 커밋 `cb6ca40` 또는 이 PR 직전 main 중에서 고른다.

## 변경 내용

`backend/scripts/recovery_point.py`

- 계약 검사 하나(`_check_manifest`)를 게시 manifest와 다운로드 폴더가 함께 쓴다.
  - 게시 manifest(`check_point_manifest(manifest, backup_id)`): `format_version == 2`, 요청한 `backup_id`와 일치,
    `images` 항목 거부, `database.backup_key`, asset의 `storage_backend`·`content_id`·`backup_key`, tar 경로 충돌.
  - 다운로드 폴더(`load_backup`): 위 기준에 `images` 항목과 파일 검사를 더한다. 지금 단계 순서를 지키고,
    `database.backup_key`는 database 항목 단계(파일 확인·해시 앞), tar 경로 충돌은 asset마다 필드 검사 뒤·archive 포함 확인 앞에 둔다.
    `format_version: 1`에는 v2 전용 검사를 하지 않는다.
  - 필드가 없거나 JSON 형식이 다른 경우를 `_field`·`is_sha256`·`_aware_time`과 형식 함수의 `isinstance` 검사로 막아,
    `KeyError`·`TypeError`·`ValueError`·`AttributeError`로 새던 경우가 `invalid_manifest`가 된다.
  - tar 경로 충돌은 정규화한 경로 집합과 상위 경로 집합으로 asset마다 상수 시간에 판정한다.
- 게시된 manifest 읽기
  - `read_point_manifest`: id 형식 → 읽기 → JSON(`invalid_manifest`) → 계약.
  - `read_point_json`: id 형식 → 읽기 → JSON. `maintain`이 receipt 충돌과 `retention_requires_v2`를 계약보다 먼저 판정하려고 쓴다.
  - `point_unchanged`: `verify`의 재조회. 계약 검사 없이 처음 manifest와 비교하고, JSON으로 읽을 수 없으면 바뀐 것으로 본다.
  - `read_retiring_points`: receipt마다 이름 → JSON → 객체를 확인한다. 내용의 계약 검사는 호출 쪽이 한다.
- 지점 ID: `is_backup_id`가 `.`·`..`을 거부한다. `require_backup_id`, `receipt_backup_id`, `completed_points`가 이 함수를 쓴다.
  `require_app_commit`도 문자열이 아니면 거부한다.

명령 쪽

- `verify_backup`: 명령 안의 검사(형식 버전·ID·dump 키·asset 키·크기·sha256 정규식)와 `TypeError` 가드를 지우고
  `read_point_manifest`의 계약 검사를 쓴다. 재조회는 `point_unchanged`다.
- `materialize_backup`(`download`): 폴더를 만들기 전에 `read_point_manifest`로 전체를 검사한다. asset 키 검사를 지웠다.
- `maintain_backups`: 완료 지점은 `read_point_json`으로 읽는다. 지점마다 객체 → `retention_requires_v2` → 계약 →
  `captured_at <= now` 순서다. asset 정규식 검사와 보존 지점의 dump 키 검사를 지웠다.
- 격리 복원 검사·`restore-check`·`restore_execution prepare`·`image_migration`은 `load_backup`을 그대로 부른다.
  `restore_execution run`이 쓰는 `read_downloaded_manifest`는 검사 없는 읽기로 남겼다(#156 표의 대상 명령이 아니다).
- `recovery_probe.py`, 게시 코드(`publish_backup`·`create_backup`), 환경 변수, 키 경로, 정규 JSON은 바꾸지 않았다.

## 구현자 판단

- **지점 ID `.`·`..`의 오류 코드**: #156 판정 순서의 "id 인자 형식"과 "receipt 이름" 단계에 넣었다.
  `verify`·`download`의 `--backup-id`는 `invalid_backup_id`(폴더를 만들지 않음), `manual`의 `--backup-id`는 지금처럼 `backup_id_required`,
  게시(`create`)는 `invalid_backup_id`다. `gc/points/..json`·`gc/points/...json`은 `invalid_gc_receipt`이고,
  다운로드 폴더 manifest의 `backup_id`가 `.`·`..`이면 `invalid_manifest`다. `points/./`·`points/../` 아래 객체는 완료 지점이 아니므로
  `maintain`이 형식 밖 ID의 다른 객체처럼 중단된 지점으로 보고 하루 뒤 지운다. `...`·`.a`처럼 점이 섞인 다른 ID는 그대로 허용한다.
  지금 운영 지점 ID는 `daily-YYYY-MM-DD`와 운영자가 정한 수동 ID뿐이다.
- **`verify` 재조회의 "읽을 수 없음"**: #156 표의 행대로 JSON이 아닐 때만 `backup_point_changed`로 바꿨다.
  재조회에서 manifest가 사라지면(`FileNotFoundError`) 표의 "객체 없음 → 변경 없음"에 따라 지금처럼 `backup_operation_failed`다.
- **`maintain`의 완료 지점이 JSON 객체가 아닐 때**: 판정 순서표는 완료 지점 읽기를 "읽기·JSON"으로만 적었다.
  객체 검사는 지점마다의 `format_version` 판정 바로 앞에서 `invalid_manifest`로 한다. 그래서 receipt 이름 오류가 함께 있으면
  `invalid_gc_receipt`가 먼저다.
- **폴더의 `u/./1.png`·`u/1.png` 충돌**: 기대값을 `missing_asset`으로 두었다. 첫 asset의 archive 포함 확인이 정규화하지 않은 키로 비교해서
  충돌을 보기 전에 첫 asset에서 실패한다(#162 고정 동작, 시작 커밋에서도 같은 결과). #156의 "계약 위반과 archive 오류가 함께 있음 → 단계 순서 유지" 행에 해당한다.
  순서를 바꾼 입력(`u/1.png`가 먼저)은 `invalid_manifest`임을 따로 확인한다.
  #156 변경표는 이 충돌의 격리 복원 검사 결과를 `invalid_manifest`로 적어 두 표가 다르게 읽힌다(티켓 리뷰 L1).
  사용자 결정(2026-11-02)으로 코드는 그대로 두고, 이 입력 순서에서는 단계 순서에 따라 `missing_asset`이 나오는 예외로 기록한다.
  Bucket 쪽 `verify`·`download`·`maintain`은 객체를 읽기 전에 전체 계약을 검사하므로 두 순서 모두 `invalid_manifest`다.
- **v1 폴더의 필드 없음**: v1에 새 검사는 더하지 않았지만, 필드가 없을 때의 `KeyError` → 일반 오류도 v1에서 `invalid_manifest`로 바뀐다.
  #156의 "`KeyError`·`ValueError`·`AttributeError`로 새던 manifest 내용 오류는 모두 `invalid_manifest`"를 형식 버전 구분 없이 적용했다.
- **게시 manifest의 필수·선택 필드**: 다운로드 폴더 검사와 같게 `extra_file_count`·`deletion_checkpoint`만 선택이며 값은 검사하지 않는다.
  asset 객체 안의 허용 밖 키도 지금처럼 검사하지 않는다(#156은 최상위 키 거부만 적었다).
- **크기 기준**: `database.size_bytes`는 폴더 검사와 같이 양의 정수다. 예전 `verify`는 0을 허용했다. 게시 코드는 빈 dump를 거부하므로(`invalid_backup_file`)
  운영 지점에는 영향이 없다.
- **되돌리기 기준 리비전**: `cb6ca40`이 아니라 **이 변경 직전 main**을 골랐다. `cb6ca40` 뒤 운영 스크립트 변경은 #169(`4b74132`)뿐인데,
  `cb6ca40`으로 되돌리면 #169가 고친 "비슷한 이름 객체 때문에 일일 백업 건너뜀·보존 정리 중단"이 돌아온다. 운영 문서에는
  `point_unchanged`를 처음 추가한 커밋의 부모를 찾는 명령으로 적었다(squash 커밋 SHA를 미리 알 수 없어서다).

## 테스트

#161·#162 고정 테스트는 입력을 바꾸지 않고 기대값만 #156 표대로 바꿨다. 게시 결과 고정 테스트
(`test_publishing_fixed_input_writes_fixed_keys_and_bytes`)는 수정 없이 통과한다.

- Bucket 쪽(`test_recovery_point_bucket_outputs.py`): 손상 22가지 × 신선·만료·receipt, tar 경로 충돌 3가지, 문자열이 아닌 sha256 5가지가
  모두 `invalid_manifest`이고 `download`는 폴더를 만들지 않는다. `maintain`의 `format_version: 1`만 `retention_requires_v2`다.
  복합 오류: verify의 계약 위반 + 객체 해시 불일치 `invalid_manifest`, 재조회 JSON 아님 `backup_point_changed`,
  download의 계약 위반 + dump 해시 불일치 `invalid_manifest`(폴더 없음), maintain의 receipt 충돌 + 계약 위반 `gc_receipt_conflict`(변경 없음),
  계약 위반 + dump 없음 `invalid_manifest`. 새로 더한 것: 재조회에서 manifest가 사라짐(`backup_operation_failed`), 지점 ID `.`·`..`의 verify·download·maintain·receipt.
- 폴더 쪽(`test_recovery_point_folder_outputs.py`): 손상 경우가 세 명령 모두 `invalid_manifest`(지점 ID `..` 추가), tar 경로 충돌,
  `database.backup_key`와 파일 오류의 순서, tar 경로 충돌과 DB 해시·archive 안전·앞선 asset 누락의 순서, v1 폴더의 충돌 허용과 필드 없음.
- module 테스트(`test_recovery_point.py`): 손상 22가지와 receipt 내용, sha256·시각·JSON 형식이 틀린 값, 요청 ID 불일치, tar 경로 충돌과
  겹치지 않는 경로, `read_point_json`·`point_unchanged`, receipt의 이름·JSON·객체 순서, 지점 ID `.`·`..`, 폴더의 JSON 아님·`images` 없음·dump 키 순서.
- 기존 테스트의 축약 manifest를 계약을 지키는 manifest로 바꿨다: `test_image_backup_retention.py`의 `point()`, `test_operator_cli.py`의 verify 테스트.
  `test_corrupt_point_does_not_destroy_other_points_or_blobs`의 `ValueError` 기대는 `CheckError("invalid_manifest")`로 바꿨다.

### 변경 감지 확인

- 새 테스트 파일 세 개를 시작 커밋(`f1e40f6`) 임시 worktree에 복사해 돌렸다: 222 failed, 82 passed. 판정 순서와 v1 폴더 테스트처럼
  바뀌지 않아야 하는 경우는 시작 커밋에서도 통과했다. worktree는 지웠다.
- 운영 스크립트를 복사해 두고 아래처럼 하나씩 바꾼 뒤 복사본으로 되돌렸다. 되돌린 뒤 `git diff`의 해시가 실험 전과 같았다.

| 임시 변경 | 실패한 테스트 수 |
| --- | --- |
| `maintain`이 계약을 `format_version`보다 먼저 검사 | 3 |
| tar 경로 충돌 검사 제거 | 12 |
| `download`가 폴더를 만든 뒤 계약 검사 | 64 |
| 재조회가 JSON이 아니면 바뀌지 않은 것으로 봄 | 2 |
| 지점 ID `.`·`..` 허용 | 12 |
| `database.backup_key` 검사 제거 | 9 |
| `verify` 출력에서 `captured_at` 삭제 | 1 |
| receipt의 객체 검사 제거 | 1 |
| 게시 manifest의 `images` 허용 | 5 |
| 폴더 manifest의 JSON 오류를 일반 오류로 | 3 |
| v1 폴더에도 tar 경로 충돌 검사 | 1 |

### 리뷰 반영

`5c07af5`의 Codex 티켓 리뷰(Standards 1건, Spec 확신 낮음 1건)를 반영했다. 구현자 판단 일곱 가지는 리뷰어가 재현해 맞다고 봤다.

- S1(전체 검증 보고 없음): 아래 검증 절에 전체 검증 결과를 기록했다. 코드는 바꾸지 않았다.
- L1(정규화 충돌의 두 표 불일치): 사용자 결정대로 코드·테스트는 그대로 두고 위 구현자 판단에 예외를 적었다. PR 본문 변경 목록에도 적는다.
  운영 문서는 폴더 쪽 검사 순서(asset마다 필드 → tar 경로 충돌 → archive 포함 여부)를 이미 적고 있어 바꾸지 않았다.
- 리뷰어의 전체 검증 FAIL(54건)은 저장소 안 `.utmp`에서 실행해 `restore_execution prepare`가 `workspace_inside_repository`로 거부한 환경 문제다.
  아래처럼 평소 위치에서 다시 실행해 통과했다.

### 검증

2026-11-02 이 worktree에서 `5c07af5` 코드로 `python3 ~/.heoturu-agents/verify.py --log-dir .utmp/ticket-167`을 한 번 실행했다
(`backend/.venv`의 Python 3.12.7, 검증용 임시 테스트 DB와 maintenance DB를 새로 만들어 `alembic upgrade head`·`alembic check` 적용).

- 결과: `VERIFY result=PASS scope=all checks=10 failed=0`.
- 백엔드: ruff·compileall·두 DB의 `alembic upgrade head`·`alembic check` 통과. `pytest -q -rs`: 1776 passed, 46 skipped.
  skip 45건은 `*_docker.py`(Docker와 빌드한 이미지 필요), 1건은 `tests/integration/test_image_storage_admin_cli.py`
  (`CLIPBACK_IMAGE_TEST_S3_ENDPOINT` 필요, 범위 밖, CI에서도 skip)다.
- 앱: `pub get`·`analyze`·테스트 2018개 통과. 앱 코드 변경은 없다.
- `git diff --check`: 통과.
- Docker 테스트는 로컬에서 실행하지 않았다. PR 2 CI의 operator-recovery job 성공과 pytest 요약의 skipped 0으로 확인한다.
- 운영 Bucket 읽기 전용 점검은 운영자가 머지 전에 한다. 이 작업에서는 운영 환경에 접속하지 않았다.

## 운영 문서와 변경 이력

- [백업·복구 운영 문서](../backend/backup-recovery.md#백업-manifest-계약)에 v2 복구 지점 manifest 필드와 검사 기준, 손상 manifest의 오류 코드,
  `maintain`이 `invalid_manifest`로 멈췄을 때의 읽기 전용 점검과 되돌리기를 적었다. 다운로드 안내에 손상 manifest에서 폴더를 만들지 않는다는 점을 더했다.
- 읽기 전용 점검 스크립트는 문서의 코드 블록을 그대로 꺼내 moto Bucket에서 실행해 정상·손상 두 경우의 출력을 확인했다.
  PR 본문의 운영자 확인 절차와 기대 출력은 이 실행 결과를 쓴다.
- `CHANGELOG.md` `미배포`의 `수정`에 [서버] 항목을 더했다.

## 범위 밖 발견

- 폴더 검사의 archive 포함 확인이 `storage_key`를 정규화하지 않는다. 그래서 `u/./1.png` 같은 키를 가진 v2 지점은 `verify`가 성공해도
  `download` 끝의 폴더 검사에서 `missing_asset`이 된다(#156 사용자 이야기 25와 어긋남). 실제 키는 `uuid4`라 가능성은 낮다.
- `format_version`이 `true`·`1.0`·`2.0`처럼 정수가 아닌 같은 값이면 지금처럼 1·2로 받아들인다(`==` 비교).
- `extra_file_count`·`deletion_checkpoint`의 값 형식은 검사하지 않는다.
- `verify`는 객체 없음을 `ClientError`로 받아 `backup_operation_failed`로 보고한다(`maintain`은 `backup_object_missing_or_unavailable`).
