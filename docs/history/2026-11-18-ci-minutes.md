# CI 사용 시간 줄이기 — 서버 검사 경로 필터·주 1회 예약·main push 중복 검사 빼기

최초 기록일: 2026-11-18 KST. 기준은 [이슈 #426](https://github.com/clip-back/clipback/issues/426) 본문(사용자 결정 1–4)이다.
브랜치 `chore/ci-minutes`(main `c62ac1e` 기준).

## 배경과 측정 요약

저장소를 비공개로 바꾸면 Free 조직의 Actions 포함량이 월 2,000분(표준 Linux)이 된다. 11월 1–18일 청구는 5,786분이었다.
최근 30일(10-19–11-18) 계산값은 실행 465건, job 2,439개, 6,443분(job마다 올림)이다.

| workflow | 이벤트 | run 수 | 분 |
| --- | --- | ---: | ---: |
| Backend Validation | pull_request | 170 | 2,482 |
| Backend Validation | push main | 128 | 1,866 |
| Backend Validation | workflow_dispatch | 23 | 689 |
| App Validation | pull_request | 67 | 497 |
| Backend Validation | schedule | 17 | 461 |
| App Validation | push main | 54 | 409 |
| App Validation | workflow_dispatch | 6 | 39 |

같은 30일 자료로 다시 계산한 예상 절감(이슈 본문 표와 같다): 경로 필터 -2,293, push의 Docker 두 job -431,
주 1회 예약 -345, 3.11 조건·lint 합치기 -281, 앱 push -409. 남는 양은 약 2,680분으로 목표 약 1,500분보다 많다.
넘는 분은 사용자 결정 2대로 병합 뒤 1주 재측정으로 판단한다.

## 변경 범위

- `.github/workflows/backend-validation.yml`
  - `pull_request`·`push`(main)에 `paths: backend/**, .github/workflows/backend-validation.yml`.
  - 예약 실행을 매일 `0 19 * * *`에서 매주 월요일 04:23 KST(`23 19 * * 0` UTC)로. 정각은 예약 실행이 늦어지거나 빠지기 쉬워 피했다.
  - `deployment`·`operator-recovery`의 `if`에 `github.event_name != 'push' &&`를 더했다. PR 경로 판정·예약·수동 조건은 그대로다.
  - `test`는 `name: test (3.12)`, Python 3.12 고정 job이 되고, 설치 뒤·`Test` 앞에 `Lint`(ruff)·`Check dependencies`(deptry) 단계를 옮겼다. `lint` job은 지웠다.
  - 새 job `test-py311`(`name: test (3.11)`, `needs: changes`)은 schedule·workflow_dispatch와,
    `changes`의 `operator_recovery`가 참인 pull_request에서만 돈다. 3.11은 운영자 이미지의 Python이다.
  - 체크 이름 `test (3.12)`·`test (3.11)`은 이전 매트릭스 이름과 같게 두어 재측정 스크립트의 job 이름 묶음이 그대로 맞는다. main에는 브랜치 보호·ruleset이 없다(2026-11-18 조회).
- `.github/workflows/app-validation.yml`: main `push` 트리거를 지웠다. pull_request·workflow_dispatch는 그대로다.
- 문서: [백엔드 테스트 안내](../backend/testing.md#원본-운영자점검복원-통합-검사)의 실행 조건, [프론트 README](../../frontend/README.md)의 App Validation 실행 조건,
  [Railway 배포](../railway-deployment.md)와 [운영자 첫 실행 체크리스트](../backend/image-operator-first-run.md)에 네 서비스(`clipback`·`clipback-backup`·`clipback-maintain`·`clipback-retry`)의 Watch Paths `/backend/**`.
  Watch Paths 설정은 사용자가 Railway에서 직접 한다.
- 리뷰 반영(`99f2e8b`): 처음 커밋(`3d80ac1`)은 `test`를 값 하나짜리 매트릭스로 남겼는데, 매트릭스에 3.11을 다시 넣으면 3.11이 모든 실행으로 돌아가는 자리처럼 보여 단일 job으로 바꿨다. 같은 커밋에서 testing.md의 조건 문장을 고쳤다.

## 검증

- 로컬: `actionlint .github/workflows/*.yml` 통과(`3d80ac1`, `99f2e8b`). 3.11 job에서 `needs: changes`를 뺀 변형은 actionlint가 실패시켰다.
  `git diff --check` 통과.
- 로컬 전체 검사(`99f2e8b`): `VERIFY result=PASS scope=all checks=12 failed=0`. 서버 pytest `2751 passed, 49 skipped`.
  skip은 Docker 복구 검사 48건(`RUN_DOCKER_RECOVERY_TESTS=1`과 로컬 이미지 필요)과 S3 대역 1건(`CLIPBACK_IMAGE_TEST_S3_ENDPOINT` 필요)이다. 검사 명령·테스트는 바꾸지 않았다.
- 원격 수동 실행(`gh workflow run backend-validation.yml --ref chore/ci-minutes`, 커밋 `3d80ac1`, 시간은 UTC):
  [44254772746](https://github.com/clip-back/clipback/actions/runs/44254772746). 리뷰 반영 전 커밋이라 `test (3.12)`는 값 하나짜리 매트릭스였다(체크 이름은 같음).

| job | attempt 1 | attempt 2(실패 job만 재실행) |
| --- | --- | --- |
| changes | 성공 06:54:15–06:54:19 | — |
| test (3.12)(Lint·Check dependencies 포함) | 성공 06:54:15–06:56:32 | — |
| test (3.11) | 성공 06:54:22–06:56:46 | — |
| deployment | 성공 06:54:21–06:57:38 | — |
| operator-recovery | 성공 06:54:21–07:03:31 | — |
| migration | 실패 06:54:14–07:00:10. `tests/integration/test_content_save_flow_contract.py::test_rollback_failure_keeping_transaction_open_does_not_finish_within_time_limit` 1건(1 failed, 1064 passed, 1 skipped) | 성공 07:04:16–07:09:27 |

  migration 실패는 시트 131로 따로 조사하는 불안정 실패이고, migration job 정의는 이번 변경에서 바뀌지 않았다. 별도 lint job은 없다.

## 미검증

- 문서만·앱만·서버만 바뀐 PR과 병합 커밋에서의 건너뜀, 이 이슈 병합 커밋의 push 실행, 월요일 예약 실행, Railway Watch Paths의 배포 생략은
  병합 전 같은 브랜치로 만들 수 없어(PR diff에 workflow 파일이 늘 들어감) 병합 뒤 이슈 완료 조건 5–9로 확인한다.
- 비공개 전환 뒤 2코어 실행기에서의 job 시간 변화와 1주 재측정 결과는 아직 없다.
