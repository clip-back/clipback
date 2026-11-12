# 백업·보존 정리의 삭제 장부 읽기 재시도와 실패 로그의 예외 종류 (#342)

2026-11-13, 브랜치 `fix/backup-ledger-read-retry`. 시작 커밋 `8192a2b`, 구현 커밋 `811da32`, 리뷰 반영 커밋 `a05a888`,
main의 배포 기록(`d5e12d5`)을 합친 커밋 `c3fef4d`(최종 전체 검증 기준). 이 기록을 더한 커밋은 문서만 바꾼다.

## 문제

- 운영 일일 백업이 2026-11-12부터 `{"error": "backup_job_failed", "passed": false}` 한 줄로만 실패했다. `image_backup_jobs.main()`은 고정 오류 코드가 아닌 예외를 모두 이 코드로 바꿔 원인을 알 수 없었다.
- 운영 진단(읽기 전용)에서는 실패가 삭제 장부를 읽는 단계에서 끝났다. 운영자 경로의 장부 클라이언트는 연결 1초·응답 2초에 재시도가 없었다.

## 사용자 결정

- 2026-11-12 "작은 이슈 하나로 둘 다 (Recommended)": 실패 로그에 예외 종류(클래스 이름만)를 남기고, 백업·정리의 장부 읽기에 재시도 3회와 여유 있는 시간 제한을 둔다. API 쪽 짧은 제한은 그대로 둔다.
- 2026-11-13 "총 4번 (Recommended)", "연결 3초·응답 10초 (Recommended)".
- 2026-11-13 리뷰 뒤 결정(이슈 본문보다 우선):
  - S1 "요청+본문 합쳐 총 4번 (Recommended)" 뒤 방식 "A: SDK 1번+바깥 4번 (Recommended)": SDK 설정은 연결 3초·응답 10초·`total_max_attempts=1`로 둔다. 저장 코드가 GET과 본문 수신을 한 시도로 쳐서 총 4번 시도한다.
  - S2·S3 "둘 다 권고대로 (Recommended)": 52초 전체 상한 문장을 지우고 "시도마다 연결 3초·응답 10초, 총 4번"으로 설명한다. 확정 제한값을 공개 SDK Config로 단언하는 테스트를 둔다.

이슈 #342 본문은 고치지 않았다. 본문과 다른 점은 네 가지다:

- 재시도 범위가 본문 수신 포함이다.
- SDK `total_max_attempts`가 4가 아니라 1이다.
- 52초 상한 문장이 없다.
- 확정 제한값을 공개 SDK Config로 단언하는 테스트를 허용한다. 본문의 테스트 원칙은 "출력·종료 코드·장부 읽기 결과만 본다"이다.

## 착수 전 확인 (`8192a2b`)

이슈 전제를 원래 코드에서 확인했고 모두 같았다.

- 파일·행(`deletion_ledger.py:124-140`·`361-372`, `image_backup_jobs.py:184`·`278-281`)과 그대로 둘 호출 9곳이 이슈와 같다.
- 바뀌는 기존 테스트 3곳의 위치가 이슈와 같다.
- moto에서 GetObject 전송 직전 `ReadTimeoutError`·`ConnectionClosedError` 1회를 일으켰다. `total_max_attempts=1`이면 실패하고 4면 두 번째 시도에서 성공했다.
- `maintain` 실패 사례의 예외는 `ClientError`이고 `__cause__`는 없다.

## 구현

- `backend/app/integrations/deletion_ledger.py`: `get_deletion_ledger(config=None, *, operator_reads=False)`.
  - 운영자 S3 장부는 연결 3초·응답 10초·SDK 1번 시도로 만든다.
  - `read()`는 GetObject와 `StreamingBody.read()`를 한 시도로 쳐서 최대 4번(`OPERATOR_READ_ATTEMPTS`) 시도한다.
  - 없는 객체(`NoSuchKey`·`404`·`NotFound`)는 재시도하지 않는다. 시도 사이 대기는 없다.
  - API 경로의 읽기 코드와 연결 1초·응답 2초·1번 설정은 `8192a2b`와 같다. `local` 장부는 바뀌지 않았다.
- `backend/scripts/image_backup_jobs.py`:
  - `run_job`(daily·manual·maintain)만 `operator_reads=True`로 장부를 만든다.
  - 고정 오류 코드(`CheckError`) 출력은 그대로다.
  - 그 밖의 예외는 `{"cause": <직접 원인 클래스 이름 또는 null>, "error": "backup_job_failed", "exception": <클래스 이름>, "passed": false}`로 출력한다. 메시지·URL·키는 출력하지 않는다.
- 문서: `docs/backend/backup-recovery.md` 실패 설명 문단, `CHANGELOG.md` 미배포.

## 테스트

- `tests/integrations/test_deletion_ledger.py`:
  - moto 실패 주입: 운영자 장부는 1회 실패 뒤 성공하고, API 장부는 `LedgerUnavailableError`로 끝난다.
  - 제한값: 운영자 `(3, 10, 1)`, API `(1, 2, 1)`.
  - 로컬 HTTP 대역의 세 실패: 응답 전 끊김, HTTP 200 뒤 본문 중 끊김, 본문 시간 초과.
    - 운영자 경로는 1회 실패 뒤 성공하고, 3번 실패해도 성공한다.
    - 4번 실패하면 `LedgerUnavailableError`로 끝나고, 같은 키 GET이 정확히 4번이다.
    - API 경로는 첫 실패로 끝나고 GET은 1번이다.
- `tests/deployment/test_recovery_point_bucket_outputs.py`:
  - 실제 `main()`의 `maintain`이 장부 시간 초과 1회 뒤 정상 보존 결과를 낸다.
  - 장부가 계속 시간 초과되면 `exception=LedgerUnavailableError`·`cause=ReadTimeoutError`로 끝난다. stdout에는 endpoint·버킷·키·메시지가 없다.
  - 기존 `ClientError` 실패 사례의 기대값을 `cause=null`로 바꿨다(허용 범위).
- 기존 fixture lambda 2곳(`test_recovery_point_bucket_outputs.py`, `test_image_backup.py`)은 새 keyword 인자를 받도록 연결만 고쳤다.
- red 확인:
  - 첫 구현 전 6건이 실패했다.
  - 리뷰 반영 테스트를 `811da32` 구현에 돌리면 4건이 실패했다.
  - SDK 4번에 바깥 4번을 겹친 변형에서는 총 4번 테스트가 실패했다.

## 검수

- 1차 Codex 검수(`811da32`): Standards 0건, Spec 중간 2·낮음 1건. 지적은 본문 수신 실패 미재시도, 52초 상한 부정확, Config 단언 계약이다. 모두 위 결정대로 반영했다.
- 재검수(`c3fef4d`): Standards 0건, Spec 0건.

## 검증

`c3fef4d`(작업 트리 깨끗함)에서 2026-11-13 04:40–04:49 KST 로컬 전체 검증:

```text
pytest: 2532 passed, 48 skipped, 3 warnings in 312.95s (0:05:12)
pytest skip: 47 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=11 failed=0
```

- 위 검증에 `ruff check app scripts alembic tests`, `python -m compileall -q app scripts alembic tests`, `pytest -q`가 들어 있다.
- verify에 없는 `deptry .`는 같은 커밋에서 따로 실행해 통과했다(`Success! No dependency issues found.`).
- Docker가 필요한 `deployment`·`operator-recovery` job은 로컬에서 돌리지 않았고 원격 CI로만 확인했다.
  - 이전 수동 CI 43287389040은 `811da32` 대상이라 리뷰 반영 뒤 코드의 근거가 아니다.
  - 리뷰 반영 뒤 원격 CI: Backend Validation 수동 실행(workflow_dispatch) [43294414444](https://github.com/clip-back/clipback/actions/runs/43294414444).
    대상은 `84747db`이고 `c3fef4d`에 이 기록만 더한 커밋이라 코드가 같다.
    2026-11-12T19:51:24Z–20:01:20Z(UTC)에 `success`로 끝났다.
    `changes`·`lint`·`test (3.11)`·`test (3.12)`·`migration`·`deployment`·`operator-recovery`가 모두 성공했다.
  - **미검증**: PR 이벤트의 경로 필터로 Docker job이 도는지는 PR을 만들기 전이라 확인하지 않았다.
- 운영 Railway·운영 DB에는 접속하지 않았다. 병합 뒤 배포·백업 수동 실행은 이 작업의 완료 조건이 아니다. #342 본문의 "병합 뒤 운영 순서표"로 따로 기록한다.

## 범위 밖 발견

- API 경로(콘텐츠·계정 삭제와 다른 운영 명령)에서 장부 본문 수신 중 시간 초과·끊김이 나면, 오류가 `LedgerUnavailableError`가 아니라 urllib3 원시 예외로 나간다.
  - 원인: `with response["Body"] as stream:`이 urllib3 원시 스트림을 돌려준다.
  - `8192a2b`부터 있던 동작이고, 사용자 결정으로 이번에는 바꾸지 않았다.
