# 수동 백업 축약 seed 공유와 PostgreSQL 회귀 검사 (#373)

2026-11-15 최초 기록. 구현·검수 및 전체 검증은 2026-11-14에 시작했고 검증은 2026-11-15에 종료했다(KST).
브랜치 `test/backup-seed-ci-diag`, 단일 스펙 [#373](https://github.com/clip-back/clipback/issues/373).
시작 커밋 `6e2681fbf23612eb52a149b4dfe57dbb4ce150c8`, 구현·전체 VERIFY 코드 근거 커밋
`f8dfeba2886fa5fa7288f82f6d1432543b309d04`이다. 이 기록과 목차를 더한 후속 커밋은 문서만 바꾼다.

## 변경과 보존 범위

- [공유 seed helper](../../backend/tests/support/manual_backup_seed.py)의 `manual_backup_seed_sql()`에 기존 수동 백업 Docker 테스트의 SQL을 그대로 옮겼다.
- [기존 Docker 테스트](../../backend/tests/deployment/test_manual_backup_docker.py)는 seed import·호출만 연결했다. 이름·docstring·기대값·단언·시나리오는 같다.
- [새 PostgreSQL 검사](../../backend/tests/integration/test_manual_backup_seed.py)는 실제 `reflected_prefix(connection, [])`와 `prune_cleanup_rows`를 실행한다. 기록 없는 실제 로컬 장부를 사용하며 제품 함수나 SQL을 대역으로 바꾸지 않는다.
- 테스트마다 UUID 전용 스키마를 만들고 모든 엔진 연결에 그 스키마만 `server_settings.search_path`로 지정한다. public의 실제 스키마로 fallback하지 않는다. 원 SQL을 asyncpg로 적용하고, 종료 시 생성한 스키마만 지운다. Alembic 스키마로 seed를 대체하지 않는다.
- 실제 DELETE·commit 이후 별도 연결 checkout으로 전체 행을 읽어 `[('pending98', False, 0)]` 보존을 단언한다. 물리 연결을 반드시 새로 생성한다는 의미는 아니다.
- 제품 SQL·API·Alembic·CI job 및 다른 Docker seed는 바꾸지 않았다. 제품 동작 변화가 없어 CHANGELOG 항목을 추가하지 않았다.

## 추출 동등성과 열 누락 재현

구현 전에 격리 PostgreSQL에서 원 seed의 정상 동작을 확인했다. 조건 조회·행 삭제 결과는 각각 0이고 pending98의 completed=false·attempts=0은 보존됐다.
공유 seed를 적용한 별도 격리 상태에서 열 하나씩 제거했으며 정상 seed의 두 번째 SQL 복사본은 만들지 않았다.

| 제거한 열 | 실제 실패 경로 | SQLSTATE / 원 exit |
| --- | --- | --- |
| users.created_at | reflected_prefix의 users SELECT | 42703 / 1 |
| image_deletions.user_id | prune_cleanup_rows의 account_rows SELECT | 42703 / 1 |
| image_deletions.content_id | 같은 실제 SELECT | 42703 / 1 |
| image_deletions.intent | 같은 실제 SELECT | 42703 / 1 |
| image_deletions.deleted_at | prune_cleanup_rows의 실제 DELETE | 42703 / 1 |

원 명령·HEAD/dirty·시각·원 exit·traceback은 로컬 `.utmp/ticket-373/partial-baseline-*/run.log`에 보관했다.
구현 뒤 새 검사 6개는 현재 seed 1개와 위 변형 5개를 실행하며, 예외의 `orig.sqlstate`를 검사해 연결 오류와 구분한다.

기준 커밋과 helper 반환 표현식 AST가 같다. SQL·INSERT 값·`hashlib.sha256(b"original98").hexdigest()` 치환은 동일하고,
치환 digest는 `36f915df24923dbf94039536e3dcd594fde30652a312e233f72680342ec84b8b`이다.
추출 전후 SQL은 1003 bytes, SHA256 `7f46d4b3597bd87dcfe5a3463cc18985278de4ab7610939564cc4b576810c682`로 같다.
seed 할당과 관련 import만 제외한 Docker 파일 전체 AST도 동일하다.
로컬 `partial-extraction-equivalence/`에 비교 결과와 양쪽 SQL을 보관했다.
기준 checkout의 Docker 실행은 로컬 Docker 실행 금지로 수행하지 않았다.

## 검수와 부분 검사

커밋된 `6e2681f...f8dfeba` 범위 검수는 Standards 0건 / Spec 0건이었다. 추가 코드 수정은 없었다.
리뷰 전 부분 검사에서 새 PostgreSQL 6개는 skip 없이 통과했고 기존 Docker 1개는 실행 조건 미충족으로 skip됐다.
추출 동등성, 바꾼 3파일 ruff·compileall, 새 검사와 기존 Docker 합계 7개 수집 확인 모두 exit 0이었다.
초기 helper 미생성 단계의 수집 실패(exit 2)는 SQLSTATE 재현 증거와 구분한다.

## 전체 검증

실행 명령은 `python3 ~/.heoturu-agents/verify.py --log-dir .utmp/ticket-373`이며 busy 대기 종료 후 한 번 실행했다.
원 실행 종료 코드 0을 회수했고, run ID는 `20261114T235035-e70daabdfcec`이다.
시작부터 최종 결과까지 모든 progress event의 HEAD는 위 코드 근거 커밋이며 dirty=false이다.
12개 검사 및 최종 verify end event의 exit는 모두 0이다.

| verify 단계 | 원 exit |
| --- | --- |
| backend:ruff | 0 |
| backend:compileall | 0 |
| backend:deptry | 0 |
| app:pub-get | 0 |
| app:format | 0 |
| app:analyze | 0 |
| backend:alembic-upgrade-test | 0 |
| backend:alembic-check-test | 0 |
| backend:alembic-upgrade-maint | 0 |
| backend:alembic-check-maint | 0 |
| backend:pytest | 0 |
| app:test | 0 |

```text
pytest: 2667 passed, 49 skipped, 3 warnings in 332.10s (0:05:32)
pytest skip: 48 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
app:test 03:38 +3663: All tests passed!
VERIFY result=PASS scope=all checks=12 failed=0
```

백엔드 ruff·deptry·compileall은 이슈 완료 조건과 동일 대상을 검사했다(compileall은 출력만 줄이는 `-q` 사용).
`backend:pytest`는 TEST_DATABASE_URL과 MAINTENANCE_TEST_DATABASE_URL을 제공하고 임시 DB를 준비해
`pytest -q -rs`로 전체를 실행했다. 이는 `pytest -q`와 `pytest -q tests/repositories tests/integration`의 수집 범위를 함께 덮으며 `-rs`는 skip 사유만 더 출력한다.
두 DB의 Alembic upgrade/check도 통과했다. 같은 범위를 별도 명령으로 재실행하지 않았다.
새 PostgreSQL 6개는 전체 수집에 포함되며 skip 목록에 없다. integration의 skip 1개는 아래 기존 S3 CLI 표본 검사뿐이다.

로컬 증거 경로는 `.utmp/ticket-373/20261114T235035-e70daabdfcec/`의 `verify-result.txt`, `verify-progress.json`, `backend-pytest.log` 및 단계별 로그다.
상위 `.utmp/ticket-373/verify-result.txt`와 해당 run 결과 파일의 바이트 일치를 확인했다.
원 프로세스 회수 정보는 `.utmp/ticket-373/verify-execution-receipt.json`에 남겼다. 로컬 파일은 저장소에 커밋하지 않는다.

## skip와 남은 미검증

skip을 통과로 세지 않는다. backend-pytest 원 SKIPPED 줄을 CI 수집 명령과 대조한 결과는 다음과 같다.

| 로컬 skip 범위 | 수 | 대응·후속 |
| --- | --- | --- |
| deletion_bootstrap_docker, image_handoff_docker | 15 | 원격 deployment job에서 Docker·동일 revision 이미지로 실행 필요 |
| manual_backup_docker 및 나머지 Docker 복구 검사 | 33 | 원격 operator-recovery job에서 실제 이미지로 실행 필요 |
| 기존 test_image_storage_admin_cli | 1 | CLIPBACK_IMAGE_TEST_S3_ENDPOINT 미설정; 현재 workflow의 endpoint 제공 설정 없음, 기존 synthetic CLI 표본 미검증 |

이번에 연결한 기존 Docker 테스트의 원문은 다음과 같다.

```text
SKIPPED [1] tests/deployment/test_manual_backup_docker.py:18: RUN_DOCKER_RECOVERY_TESTS=1 and built operator image required
SKIPPED [1] tests/integration/test_image_storage_admin_cli.py:20: CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local synthetic CLI test
```

원격 migration·operator-recovery·deployment CI는 아직 실행·확인하지 않았다. 이슈 #373/#374는 같은 PR의 Closes 대상이므로 이 기록 단계에서 닫지 않는다.
로컬 Docker, 운영 DB/Bucket, 실제 모델 표본, 기기·화면 검증은 수행하지 않았다. 화면 변경은 없다.
외부 댓글 게시·push·PR 생성·#374 구현도 수행하지 않았다.
기존 pytest-asyncio loop scope 및 Alembic path_separator 경고는 범위 밖이므로 변경하지 않았다.
