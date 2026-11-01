# 완료 지점 목록의 manifest 키 판정 수정

최초 기록일: 2026-11-01 KST. 기준은 [이슈 #169](https://github.com/clip-back/clipback/issues/169) 본문이다.
브랜치 `fix/completed-point-pattern`(main `cb6ca40` 기준)에서 작업했다.

## 결정 (사용자 확인 2026-11-01)

- `completed_points` 정규식의 `.`을 이스케이프해 이름이 정확히 `points/<id>/manifest.json`인 객체만 완료 지점으로 센다.
- 그 결과 `manifest.json` 없이 비슷한 이름의 객체만 있는 지점은 `maintain`의 미완성 지점 정리(1일 경과) 대상이 된다.
  이 동작 변경을 받아들인다.
- #167(검증 기준 통일)과 섞지 않고 따로 고친다.

## 변경 범위

- `backend/scripts/recovery_point.py`: `completed_points`의 패턴을 `manifest\.json`으로 바꾸고, 이스케이프하지 않은 채
  옮겼다는 주석을 지웠다. `daily`의 건너뜀 판정, `maintain`의 완료 지점 목록, 게시의 `backup_id_exists` 판정이
  모두 이 함수를 쓰므로 세 곳이 함께 바뀐다.
- `docs/backend/backup-recovery.md`: 백업 Bucket 배치 설명에 완료 지점 판정 기준과 비슷한 이름 객체의 정리를 적었다.
- 같은 이스케이프 누락을 백업·복구 코드(`backend/scripts/*.py`, `app/integrations/operator_source.py`)의 다른 정규식에서
  찾았다. 나머지 `.`은 모두 문자 클래스 안(`[A-Za-z0-9._-]` 등)이거나 이미 이스케이프되어 있어(`\.json`, `\(PostgreSQL\)`)
  고칠 곳이 없었다.
- CHANGELOG: 넣지 않았다. 백업 도구 자체가 `미배포`의 [서버] 추가 항목으로 아직 배포되지 않았고, 이 도구의 배포 전
  `fix` 커밋(`6cb9642`, `1e97d0d` 등)도 CHANGELOG를 바꾸지 않았다. 저장소에 [운영] 태그는 없다.

## 재현 테스트

moto Bucket에 `points/<id>/manifestXjson` 하나만 둔 입력이다.

| 시드 | 테스트 | 수정 전 | 수정 후 |
| --- | --- | --- | --- |
| `completed_points` | `test_recovery_point.py::test_completed_points_need_the_exact_manifest_key` | `['published', 'stray']` | `['published']` |
| 게시(`backup_id_exists`) | `test_image_backup.py::test_lookalike_manifest_does_not_take_the_backup_id` | `backup_id_exists` | 게시 성공 |
| `run_job daily` | `test_image_backup.py::test_daily_job_skips_only_a_completed_point_for_today[manifestXjson-True]` | `backup_created: false` | `backup_created: true` |
| `maintain_backups` | `test_image_backup_retention.py::test_lookalike_manifest_point_is_cleaned_up_as_incomplete_after_a_day` | `FileNotFoundError` | 1일 전에는 남고 1일 뒤 정리 |

- 정상 `manifest.json`이 있는 날의 `daily`는 지금처럼 건너뛴다(`[manifest.json-False]`). 완료 지점 목록의 기존 회귀
  테스트(`test_completed_points_are_ids_with_a_published_manifest`)도 그대로 통과한다.
- `daily` 테스트는 런타임 조립(DB lock·점검 gate·삭제 원장)과 지점 생성(`create_backup`)만 대체하고 건너뜀 판정은
  실제 코드로 실행한다. 지점 생성은 PostgreSQL·`pg_dump`가 필요해 비Docker 테스트에서 대체했다.
- 변경 감지: `recovery_point.py`를 작업 디렉터리 밖 복사본에 보관한 뒤 `git show HEAD:`로 원래 코드로 되돌리고
  (`git diff`가 비어 있음을 확인) 새 테스트를 돌렸다. 버그 재현 4개는 실패했고 회귀 경우 1개만 통과했다. 복사본으로
  되돌린 뒤 `git diff`에 이번 수정만 남은 것을 확인했다.
- #161·#162 고정 테스트(`test_recovery_point_bucket_outputs.py`·`test_recovery_point_folder_outputs.py`)는 이 입력을
  다루지 않아 기대값을 바꾸지 않았다.

## 리뷰 반영

`/code-review`(diff 대상) 지적 7건이다.

- 반영: 운영 문서 문장이 완료 지점 아래의 비슷한 이름 객체도 하루 뒤 지워지는 것처럼 읽혔다. `manifest.json` 없이
  그 객체만 있는 지점으로 한정했다. 같은 문단의 긴 줄을 나누고, 바로 위 목록의 완료 표식 정의를 반복하지 않게 고쳤다.
  정상 `manifest.json`이 있는 지점 아래의 비슷한 이름 객체는 지점이 만료될 때 지점 접두사와 함께 지워진다.
- 반영하지 않음(최소 수정 범위 밖):
  - 정규식 대신 `point_manifest_key()`와 비교하기, `POINTS_PREFIX`에도 `re.escape` 적용하기: 동작이 같은 구조 정리다.
    지금 `points/`에는 정규식 특수 문자가 없다.
  - `daily` 테스트의 런타임 대체가 #161 고정 테스트의 `maintenance_runtime` fixture와 겹치고 파일 위치가 다르다:
    공용 fixture로 옮기면 #161 고정 테스트를 함께 바꿔야 한다.
  - `BACKUP_ID` 형식이 `.`·`..`을 허용한다: 이번 변경 전부터 있던 동작이며 식별자 형식 변경이다.

## 검증

로컬 macOS, Python 3.12 가상환경, Homebrew PostgreSQL 17에서 리뷰 반영 뒤 실행했다. Docker는 꺼져 있었다.

- `ruff check app scripts alembic tests`: 통과. `python -m compileall app scripts alembic tests`: 통과.
- `git diff --check`: 통과.
- CI와 같은 이름의 `clipback_test`·`clipback_maintenance100`을 만들고 `YOUTUBE_SUMMARY_ENABLED=false`로
  `alembic upgrade head`·`alembic check`를 둘 다 통과한 뒤 `TEST_DATABASE_URL`·`MAINTENANCE_TEST_DATABASE_URL`을 지정해
  전체 `pytest -rfEs`: 1650 passed, 46 skipped.
  - 첫 실행은 `postgres` 계정으로 했다. 이 계정에 DB 생성 권한이 없어
    `test_upgrade_head_preserves_both_deployed_branches` 3건이 `permission denied to create database`로 실패했다.
    로컬 관리자 계정으로 DB를 다시 만들고 다시 실행해 통과했다. 끝난 뒤 테스트 DB를 지웠다.
  - skip 46건 중 45건은 Docker·빌드 이미지가 필요한 `*_docker.py`이고, 1건은 S3 endpoint가 필요한
    `test_image_storage_admin_cli.py`다. 이번 변경과 무관하다. Docker 검사는 PR CI에서 확인한다.
- 미검증: Docker 검사(`operator-recovery`·`deployment`), 실제 운영 Bucket.
