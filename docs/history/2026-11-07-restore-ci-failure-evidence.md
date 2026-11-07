# 복원 테스트 실패 때 정리 단계 결과를 안전한 artifact로 남기기 (#262)

최초 기록일: 2026-11-07 KST. 기준은 [이슈 #262](https://github.com/clip-back/clipback/issues/262) 본문이다.
브랜치 `ci/restore-ci-evidence`(main `3de9798` 기준)에서 작업했다.

## 배경

#250 최종 CI(run [42243957142](https://github.com/clip-back/clipback/actions/runs/42243957142) attempt 1)의
`operator-recovery`에서 `test_control_disconnect_stops_child_but_keeps_durable_recovery`가
`cleanup_passed=false`로 실패했고 뒤 4개 테스트가 `prepare_before_maintenance`로 실패했다(5 failed, 27 passed).
실패 job만 다시 돌리자 통과했지만, 어느 정리 단계가 실패했는지 알 수 있는 자료가 남지 않았다.

## 변경 범위

- `backend/tests/deployment/restore_evidence.py`(신규): 허용 목록 정제기.
  - 결과 불리언 7개는 bool일 때만, `error`는 `[a-z][a-z0-9_]{0,79}` 형식일 때만 남긴다(형식 검사이며 고정 코드 목록은 아니다).
  - 남은 Docker 자원은 `container`·`network`·`volume`·`unknown`만 개수로 세고 나머지는 `other`.
  - 정리 단계 3개(`docker_resource_removal`·`workspace_input_removal`·`workspace_removal`)를 결과 플래그와 작업 폴더
    상태로 추론한다. 증명할 수 없으면 `unknown`, 실패 단계를 특정하지 못하면 `unattributed=true`.
  - 자식 종료 코드: `child_returncode`와 `child_returncode_status`(`observed`·`not_spawned`·`no_child_pid_in_journal`·`unobserved`).
  - maintenance는 `phase`와 작업 개수만, 예외는 클래스 이름과 `CheckError` 코드만 남긴다.
- `backend/tests/deployment/conftest.py`(신규): 테스트 본문 실패 예외를 `item.stash`에 넣는 훅.
- `backend/tests/deployment/test_live_restore_docker.py`
  - `live_context`가 fixture 해제 전에, 본문이 실패했고 `RESTORE_EVIDENCE_DIR`이 있으면 테스트별 JSON을 쓴다.
    시작 maintenance는 기존 준비 확인 응답을, 실패 시점 maintenance는 DB `gate.status()`를 읽는다.
  - `asyncio.create_subprocess_exec`를 그대로 통과시키는 래퍼로 `run_restore`의 자식 Process를 보관해 종료 코드를 읽는다.
  - 결과 단언 20개의 실패 메시지를 안전한 요약(`item["evidence"].summary()`)으로 통일했다. 단언 조건 47개는 바꾸지 않았다.
- `.github/workflows/backend-validation.yml`: 복원 검사 단계에 `RESTORE_EVIDENCE_DIR`, 뒤에 `if: failure()`
  `actions/upload-artifact@v7`(이름 `restore-failure-evidence-<시도 번호>`, 14일 보관).
- `backend/tests/deployment/test_restore_evidence.py`(신규): Docker 없는 표적 테스트 27개.
- [백엔드 테스트 안내](../backend/testing.md#원본-운영자점검복원-통합-검사)에 수집 필드와 판정 규칙을 적었다.
- 제품 코드(`backend/scripts`, `backend/app`), timeout, 재실행, xfail은 바꾸지 않았다.
- CHANGELOG: 사용자에게 보이는 동작 변화가 없어 추가하지 않았다.

## 리뷰 반영

- 1차 리뷰(Spec 중간 3건)
  - S1: 자식 returncode 대신 PID 생존 여부만 남김 → 위 래퍼로 실제 종료 코드를 기록. CLI 실행의 부모 종료 코드는
    `command_returncode`에만 두고 자식 값으로 쓰지 않는다.
  - S2: 원본 `result`를 메시지로 찍던 단언 4곳 → 안전한 요약으로 바꾸고, 결과 단언 전체가 요약을 쓰는지 정적 테스트로 고정.
  - S3: `docker rm`이 실패했지만 자원이 남지 않은 경우 실행하지 않은 작업 폴더 삭제를 실패로 지목함(Docker 없는 재현으로 확인)
    → 증명할 수 없는 단계를 `unknown`으로.
- 재검수(낮음 1건): 문서의 Docker 오류 예시에 영수증 미완료 때 `skipped` 분기를 추가.

## 검증

코드 기준 커밋은 `fca3535`이다(이 이력 문서 커밋은 문서만 더한다).

- 로컬 전체 검증(백엔드 ruff·compileall·alembic·pytest, 앱 pub get·format·analyze·test 11개 검사)
  - `VERIFY result=PASS scope=all checks=11 failed=0`
  - backend pytest `2234 passed, 47 skipped`
  - `pytest skip: 46 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)`
  - `pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)`
  - Docker 복원 테스트는 로컬에서 실행하지 않았다(CI 전용).
- 정상 CI: run [42277138866](https://github.com/clip-back/clipback/actions/runs/42277138866), `workflow_dispatch`,
  head `fca3535ea9ee06701b4f7f9bb85c2e65041f3b3b`, 2026-11-06T19:09:29Z에서 19:19:06Z(UTC).
  - job 7개(changes, lint, migration, test 3.11·3.12, deployment, operator-recovery) 모두 success.
  - operator-recovery `32 passed in 451.12s`, skip 0. artifact 업로드 단계는 skipped, artifact 0개.
  - test job 3.11·3.12 각각 `1500 passed, 781 skipped`.
- 실패 주입 실험 CI(병합하지 않는 임시 브랜치 `ci/restore-ci-evidence-failure-262-v2`, 커밋
  `7c15a4c9564cf4ef4ce778a784c7a7bc4d0a6103`): run [42277194103](https://github.com/clip-back/clipback/actions/runs/42277194103),
  2026-11-06T19:09:52Z에서 19:22:02Z(UTC).
  - 주입: `test_control_disconnect_...`에서 private control을 끊기 전에 작업 폴더 `temporary/locked`를 `0o500`으로 만들어
    복사 입력 삭제를 실패시키는 5줄. 제품 코드·단언·timeout 변경 없음.
  - operator-recovery만 failure, `5 failed, 27 passed`. 첫 실패는 `assert (True and False)`(`source_lock_released`와
    `cleanup_passed` 단언)이고 실패 메시지에 요약이 붙었다. 뒤 4개는 `CheckError: prepare_before_maintenance`.
  - artifact `restore-failure-evidence-1`(파일 5개): 최상위 키와 하위 필드가 모두 허용 목록과 일치했다. 토큰·접속 문자열·
    credentials·경로·`run_id`·`backup_id` 패턴은 0건이었다.
  - 첫 실패 JSON: `workspace_input_removal=failed`, `workspace_inputs_left=["temporary"]`, `docker_resource_removal=unknown`,
    `workspace_removal=skipped`, `unattributed=false`, `child_returncode=-15`(`observed`), `private_control_returncode=-15`.
  - maintenance: 첫 실패 테스트는 `open`·작업 0개로 시작해 `frozen`·작업 1개로 끝났고, 뒤 4개는 모두 `frozen`·작업 1개로
    시작했다. 이 실험에서는 앞 테스트가 남긴 maintenance 상태가 후속 4개 실패를 만든다는 설명과 맞다.
- 같은 실험을 리뷰 반영 전 코드(`9aa03a7` 위 `9aec41d`, run [42264321938](https://github.com/clip-back/clipback/actions/runs/42264321938))에서도
  돌렸고 같은 5 failed, 27 passed가 나왔다. 그 결과는 위 최종 판정에 쓰지 않았다.

## 한계와 남은 일

- #250 attempt 1에서 `cleanup_passed`가 왜 false였는지는 확정하지 않았다. 다음에 같은 실패가 나면 이 artifact로 단계를 구분한다.
- 정리 단계는 `run_restore`가 내는 합친 `cleanup_passed`에서 추론한다. 복사 입력 이름 5개는 제품 목록을 복제했으므로 제품
  목록이 바뀌면 함께 고쳐야 한다. 복합 실패의 모든 원인을 보장하지 않는다.
- CLI 진입점의 자식 종료 코드는 직접 볼 수 없어 journal의 자식 pid 유무로만 구분한다. 두 실험 모두 해당 테스트가 앞 실패의
  maintenance 상태 때문에 `prepare` 단계에서 먼저 실패해, CI에서 이 값은 관측되지 않았다.
- `child_process_running`은 restore leader PID 하나의 생존 여부이며 자손 프로세스 전체 종료의 증거가 아니다.
- fixture 준비·해제 단계의 실패는 수집하지 않는다.
- #252의 CI 셸 블록 회귀 테스트는 도입하지 않았다. 추출 명령을 스크립트로 옮길 때 별도 이슈로 판단한다.
