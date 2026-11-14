# migration CI 테스트 이름과 60초 대기 스택 출력 (#374)

2026-11-15 최초 기록(KST). 브랜치 `test/backup-seed-ci-diag`, 단일 스펙 [#374](https://github.com/clip-back/clipback/issues/374).
시작 커밋 `c00a2b31896712075e9229b7616ceeed503bd02d`, 구현 및 전체 VERIFY 코드 근거는
`408ae3d0699360880f564883a6a3f8879d9af7f7`이다. 이 기록과 목차를 추가하는 후속 커밋은 문서만 바꾼다.

## 변경과 검수

[backend-validation workflow](../../.github/workflows/backend-validation.yml)의 migration 명령 한 줄만 다음과 같이 교체했다.

```sh
pytest -vv -o faulthandler_timeout=60 tests/repositories tests/integration
```

기존 `-q` 대신 승인된 두 옵션을 사용한다. 기존 테스트·수집 폴더·10분 job 제한·다른 job·재시도 정책·의존성은 그대로다.
#383의 `-rs`는 workflow에 추가하지 않았다. 전체 검증 도구 자체의 기존 `pytest -q -rs`와 구분한다.
pytest 내장 스택 출력은 테스트를 60초에 종료하거나 성공 처리하지 않는다. Python 스택만으로 비동기 task·DB blocker 또는 과거 CI 정지 원인을 확정하지 않는다.
제품 동작 변화가 없어 CHANGELOG 항목을 추가하지 않았다.

고정 범위 `c00a2b3...408ae3d` 검수는 Standards 0건 / Spec 0건, REVIEW-DONE이다.
리뷰어의 diff-check는 busy 선행 차단으로 미실행이었으며 작업자가 최종 범위 diff-check를 실행했다.

## 구현 첫 단계의 의도적 대기 표본

workflow를 수정하기 전에 임시 `.utmp/ci-wait-sample/test_wait_sample.py`에 명세 그대로 `time.sleep(65)` 한 테스트를 만들고 backend 개발 venv에서 실행했다.

```sh
.venv/bin/python -m pytest -vv -o faulthandler_timeout=60 ../.utmp/ci-wait-sample/test_wait_sample.py
```

로컬 macOS 26.6.2 arm64, Python 3.12.7, pytest 9.2.0이다. 실행 HEAD는 시작 커밋 c00a2b3, dirty=false이다.
외부 제한으로 중단하지 않았으며 원 실행 session 73091의 exit 0을 회수했다.

```text
../.utmp/ci-wait-sample/test_wait_sample.py::test_wait_sample Timeout (0:01:00)!
  File "…/.utmp/ci-wait-sample/test_wait_sample.py", line 5 in test_wait_sample
1 passed in 65.02s (0:01:05)
# exit: 0
```

스택의 경로는 위 인용에서만 축약했으며 원 stdout/stderr와 종료 코드는 `.utmp/ticket-374/partial-wait-sample/run.log`에 그대로 보존했다(node ID·timeout 20행, 대기 줄 22행, 최종 요약 57행, exit 59행).
플랫폼 원문은 `.utmp/ticket-374/platform.txt`에 있다. 확인 후 표본 디렉터리를 제거했고 커밋·정상 CI 수집에 포함하지 않았다.
이 표본은 로컬 진단 출력 확인이며 기존 CI 정지 원인 재현이 아니다.

## 정확한 새 명령의 정상 PostgreSQL 실행

표본 확인 뒤 한 줄을 수정하고 로컬 PostgreSQL 17.7에서 새 전용 DB 두 개를 만들어 각각 Alembic upgrade/check를 통과시켰다.
TEST_DATABASE_URL 및 MAINTENANCE_TEST_DATABASE_URL을 제공한 backend venv에서 위 workflow와 정확히 같은 명령을 실행했다.

```text
1046 passed, 1 skipped, 3 warnings in 249.20s (0:04:09)
# exit: 0
```

실행 HEAD c00a2b31896712075e9229b7616ceeed503bd02d, dirty=true(workflow 한 파일)이다.
원 실행 session 92098의 exit 0을 회수했다. 새 PostgreSQL seed 검사 6개는 모두 PASSED였다(로그 804–809행).
한 skip은 기존 `test_image_storage_admin_cli.py::test_operator_cli_pause_resume_and_private_usage_report`이다.
명령에 -rs가 없으므로 이 실행의 사유는 pytest 사유 요약이 아닌 endpoint 미설정 환경과 변경 없는 테스트 20행 guard를 대조했다:
`CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local synthetic CLI test`.
로컬 증거는 `.utmp/ticket-374/partial-postgresql/run.log`, `skip-context.txt`, DB 준비·정리의 `partial-db-prepare/run.log` 및 `partial-db-cleanup/run.log`다.
직접 만든 전용 DB 두 개만 정리했다. 이 명령과 표본은 후속 검증에서 반복하지 않았다.

## 검수 후 전체 VERIFY

clean HEAD 408ae3d에서 busy 차례를 지켜 다음을 한 번 실행했다.

```sh
python3 ~/.heoturu-agents/verify.py --log-dir .utmp/ticket-374
```

원 실행 session 11005 종료 코드 0을 회수했다. run ID `20261115T002309-14e8a42a7393`의 결과 파일과 상위 `verify-result.txt`가 바이트 단위로 일치했다.
모든 progress event의 HEAD는 `408ae3d0699360880f564883a6a3f8879d9af7f7`, dirty=false이다. 아래 12개 단계 및 verify end의 exit_code는 모두 0이다.

```text
VERIFY result=PASS scope=all checks=12 failed=0
2667 passed, 49 skipped, 3 warnings in 325.10s (0:05:25)
app:test: 03:08 +3663: All tests passed!
pytest skip: 48 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
```

| VERIFY 단계 | 결과 | exit | 로그 |
| --- | --- | --- | --- |
| `backend:ruff` | PASS | 0 | `backend-ruff.log` |
| `backend:compileall` | PASS | 0 | `backend-compileall.log` |
| `backend:deptry` | PASS | 0 | `backend-deptry.log` |
| `app:pub-get` | PASS | 0 | `app-pub-get.log` |
| `app:format` | PASS | 0 | `app-format.log` |
| `app:analyze` | PASS | 0 | `app-analyze.log` |
| `backend:alembic-upgrade-test` | PASS | 0 | `backend-alembic-upgrade-test.log` |
| `backend:alembic-check-test` | PASS | 0 | `backend-alembic-check-test.log` |
| `backend:alembic-upgrade-maint` | PASS | 0 | `backend-alembic-upgrade-maint.log` |
| `backend:alembic-check-maint` | PASS | 0 | `backend-alembic-check-maint.log` |
| `backend:pytest` | PASS | 0 | `backend-pytest.log` |
| `app:test` | PASS | 0 | `app-test.log` |

backend ruff/deptry/compileall은 각 VERIFY 단계로 확인했다. backend 전체 `pytest -q -rs`는 두 전용 DB를 migration한 뒤 TEST_DATABASE_URL/MAINTENANCE_TEST_DATABASE_URL을 제공하므로 repositories/integration도 포함한다.
해당 범위와 정적 검사를 따로 재실행하지 않았다. 신규 PostgreSQL seed 검사 6개는 전체 수집에 포함되며 skip 목록에 없다.
workflow와 옵션이 다른 정확한 새 명령의 증거는 앞선 부분 실행으로 별도 유지한다.

전체 실행 증거는 로컬 `.utmp/ticket-374/20261115T002309-14e8a42a7393/`의 `verify-result.txt`, `verify-progress.json`, `backend-pytest.log` 및 단계별 로그에 있다.
원 실행 회수 및 결과 파일 대조는 `.utmp/ticket-374/verify-execution-receipt.json`에 기록했다. 로컬 증거는 커밋하지 않는다.

## skip와 남은 미검증

skip을 통과로 세지 않는다. 원 SKIPPED 줄과 현재 workflow 수집 명령의 대응은 다음과 같다.

| 로컬 skip 범위 | 수 | 대응 원격 job / 후속 |
| --- | --- | --- |
| deletion_bootstrap_docker, image_handoff_docker | 15 | deployment에서 동일 revision Docker 이미지로 확인 필요 |
| 나머지 Docker 복구 검사 | 33 | operator-recovery에서 실제 이미지로 확인 필요 |
| 기존 image_storage_admin_cli | 1 | 현재 모든 workflow job에 endpoint 제공 설정 없음; 기존 synthetic CLI 표본 미검증 |

이번 전체 실행에서 출력한 skip 원문은 다음과 같다.

```text
SKIPPED [2] tests/deployment/test_backup_restore_docker.py:165: RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are required
SKIPPED [10] tests/deployment/test_backup_restore_docker.py:176: RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are required
SKIPPED [1] tests/deployment/test_deletion_bootstrap_docker.py:84: Requires Docker and a built CLIPBACK_LEDGER_OPERATOR_IMAGE
SKIPPED [1] tests/deployment/test_deletion_bootstrap_docker.py:97: Requires Docker and a built CLIPBACK_LEDGER_OPERATOR_IMAGE
SKIPPED [3] tests/deployment/test_deletion_bootstrap_docker.py:107: Requires Docker and a built CLIPBACK_LEDGER_OPERATOR_IMAGE
SKIPPED [1] tests/deployment/test_deletion_bootstrap_docker.py:128: Requires Docker and a built CLIPBACK_LEDGER_OPERATOR_IMAGE
SKIPPED [1] tests/deployment/test_deletion_bootstrap_docker.py:135: Requires Docker and a built CLIPBACK_LEDGER_OPERATOR_IMAGE
SKIPPED [3] tests/deployment/test_deletion_bootstrap_docker.py:150: Requires Docker and a built CLIPBACK_LEDGER_OPERATOR_IMAGE
SKIPPED [1] tests/deployment/test_deletion_bootstrap_docker.py:165: Requires Docker and a built CLIPBACK_LEDGER_OPERATOR_IMAGE
SKIPPED [1] tests/deployment/test_deletion_bootstrap_docker.py:180: Requires Docker and a built CLIPBACK_LEDGER_OPERATOR_IMAGE
SKIPPED [1] tests/deployment/test_deletion_bootstrap_docker.py:191: Requires Docker and a built CLIPBACK_LEDGER_OPERATOR_IMAGE
SKIPPED [1] tests/deployment/test_image_backup_docker.py:247: RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are required
SKIPPED [1] tests/deployment/test_image_backup_docker.py:259: RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are required
SKIPPED [1] tests/deployment/test_image_backup_docker.py:274: RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are required
SKIPPED [1] tests/deployment/test_image_backup_docker.py:467: RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are required
SKIPPED [1] tests/deployment/test_image_handoff_docker.py:144: Requires built API/operator images from the same identified revision
SKIPPED [1] tests/deployment/test_image_handoff_docker.py:157: Requires built API/operator images from the same identified revision
SKIPPED [1] tests/deployment/test_image_migration_docker.py:42: RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are required
SKIPPED [1] tests/deployment/test_legacy_account_deletion_restore_docker.py:73: RUN_DOCKER_RECOVERY_TESTS=1 and labelled local images are required
SKIPPED [1] tests/deployment/test_live_restore_docker.py:132: RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local API image are required
SKIPPED [1] tests/deployment/test_live_restore_docker.py:198: RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local API image are required
SKIPPED [1] tests/deployment/test_live_restore_docker.py:240: RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local API image are required
SKIPPED [1] tests/deployment/test_live_restore_docker.py:288: RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local API image are required
SKIPPED [1] tests/deployment/test_live_restore_docker.py:339: RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local API image are required
SKIPPED [1] tests/deployment/test_live_restore_docker.py:442: RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local API image are required
SKIPPED [1] tests/deployment/test_live_restore_docker.py:509: RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local API image are required
SKIPPED [1] tests/deployment/test_live_restore_docker.py:570: RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local API image are required
SKIPPED [1] tests/deployment/test_maintenance_docker.py:17: Opt-in real Docker/PG18 and built images required
SKIPPED [1] tests/deployment/test_manual_backup_docker.py:18: RUN_DOCKER_RECOVERY_TESTS=1 and built operator image required
SKIPPED [1] tests/deployment/test_multiuser_image_restore_docker.py:19: RUN_DOCKER_RECOVERY_TESTS=1 and labelled local images are required
SKIPPED [2] tests/deployment/test_postgres_restore_ready_docker.py:41: RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are required
SKIPPED [1] tests/deployment/test_remote_source_backup_docker.py:17: RUN_DOCKER_RECOVERY_TESTS=1 and built operator image required
SKIPPED [1] tests/deployment/test_remote_source_backup_docker.py:221: RUN_DOCKER_RECOVERY_TESTS=1 and built operator image required
SKIPPED [1] tests/integration/test_image_storage_admin_cli.py:20: CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local synthetic CLI test
```

원격 migration·deployment·operator-recovery CI는 PR 이후 확인할 미검증이다. 로컬 Docker·운영 DB/Bucket·실제 모델·기기·화면 실행은 하지 않았다.
화면 변경은 없으며 자동 앱 검사는 VERIFY 범위로만 실행했다. 기존 pytest-asyncio loop scope 및 Alembic path_separator 경고는 범위 밖으로 수정하지 않았다.
#373/#374는 PR Closes 대상이므로 닫지 않았고 외부 댓글·push·PR·원격 CI는 실행하지 않았다. 다음 main 합치기·최종 리뷰·PR 초안은 감독 단계다.
