# 삭제 장부 30일 파기 (#344)

2026-11-13, 브랜치 `feat/deletion-ledger-disposal`. 시작 커밋 `d3b9c97`. 스펙은 이슈 #344, 결정은 [ADR 0013](../adr/0013-deletion-ledger-30-day-disposal.md).
티켓마다 절을 더한다.

## #345 삭제 장부 시작 지점과 시작 지점부터 검증

구현 커밋 `5e44e01`, 리뷰 반영 커밋 `22fa9e3`(최종 전체 검증 기준). 이 절을 더한 커밋은 문서만 바꾼다.

### 착수 전 확인 (`d3b9c97`)

- 스펙 "현재 동작" 표의 함수 호출 행을 다시 재현했고 모두 같았다. 1번 기록 파일을 지우면 전체 검증이 실패하고, 기록 1건뿐인 장부에서 그 기록을 지우면 끝 기록 확인과 새 기록 쓰기가 실패한다.
- 코드 읽기로만 확인했던 행을 실측했다. API 삭제의 장부 쓰기는 기록 → 영수증 → head 3번이다. 복구 지점 manifest의 장부 checkpoint는 namespace·sequence·digest이고, 장부 파일은 백업 Bucket에 복사되지 않는다. `maintain`은 DB 없이 돌아 정리 작업 행을 지우지 않는다. 원본 삭제 재시도 출력은 4필드다.
- 운영자 S3 설정으로 시작 지점 객체 키를 읽으면 본문 수신이 1번 끊긴 뒤 성공하고(GET 2번), 4번 끊기면 실패한다(같은 키 GET 4번). 없는 객체는 1번만 읽는다.
- 스펙과 다른 점 1가지: 끝 기록 확인은 head·마지막 기록 파일만이 아니라 head → namespace → 마지막 기록 파일 3번을 읽는다.

### 사용자 결정

- 2026-11-13 "응": 기존 namespace 읽기를 그대로 두고 끝 기록 확인 읽기를 head → namespace → 마지막 기록 파일 3번으로 고정한다. 마지막 기록 파일이 없을 때만 시작 지점 읽기를 1번 더한다(API 경로 최대 4번). 운영자 재시도는 Q-B6 그대로다.
- 이슈 #344 본문은 고치지 않았다. 본문과 다른 점은 위 읽기 횟수 하나다.

### 구현

- `backend/app/integrations/deletion_ledger.py`
  - 시작 지점은 장부 저장소의 `start.json`(namespace·sequence·digest)이다. 객체가 없을 때만(로컬 파일 없음, S3 `NoSuchKey`·`404`·`NotFound`) 파기 전으로 보고 1번부터 검증한다. 그 밖의 읽기 오류와 손상은 검증 실패다.
  - 전체 검증(`read_verified_events`·`read_verified_checkpoint`)은 시작 지점 다음 순번부터 시작 지점 digest에 이어 검증하고, 시작 지점 뒤 기록만 돌려준다. 주어진 checkpoint가 시작 지점보다 앞서면 실패한다.
  - 끝 기록 확인(`append`·`read_checkpoint_tip`·`read_operation`)은 마지막 기록 파일이 "객체 없음"일 때만 시작 지점을 읽고, 세 필드가 head와 같아야 통과한다. 그래서 기록을 모두 파기한 장부에도 새 기록을 쓸 수 있다.
  - 파기 인터페이스: `advance_start(sequence)`는 시작 지점을 1번 쓰고 다시 읽어 확인한다. `delete_disposed()`는 시작 지점 이하 남은 영수증·기록 파일을 목록 조회 없이 오름차순으로(한 기록 안에서 영수증 먼저) 지운다. 지우기 전에 남은 기록 전부를 형식과 시작 지점 digest에서 거꾸로 이어지는 연결로 검증하고, 틀리면 아무것도 지우지 않는다. `dispose_through(sequence)`는 둘을 잇는다.
  - 로컬·S3 Store에 객체 삭제를 더했다. S3는 SDK 1번 시도, 바깥 재시도 없음, 없는 객체 삭제는 성공이다.
- 운영 코드는 아직 파기를 부르지 않는다. 시작 지점이 없는 지금 장부의 동작은 같다.

### 리뷰 반영

- Spec 중간 1건: 남은 파기 대상 기록 파일에서 operation id만 읽어 영수증 키를 만들어, 그 파일이 손상되거나 다른 정상 기록으로 바뀌면 파기 범위 밖 영수증을 지울 수 있었다. 위 "지우기 전 검증"으로 고쳤다.
- 같은 상태를 만드는 진입점은 `delete_disposed`와 그것을 부르는 `dispose_through` 둘이고, 장부 객체를 지우는 다른 호출은 없다. 로컬·S3는 같은 경로를 쓴다.

### 테스트

새 파일 3개만 더했고 기존 테스트 파일은 바꾸지 않았다.

- `tests/integrations/test_deletion_ledger_start.py`: 시작 지점 판정 표의 각 행, 시작 지점 손상 10가지, Q-B5 설계 한계(파기 이력이 없을 때 시작 지점 부재는 통과, 앞선 파기 뒤 부재는 실패), 끝 기록 확인의 읽기 순서와 부재 대체 범위, 파기 순서·쓰기 확인 실패·중단 뒤 이어 지우기, 손상된 파기 대상 기록에서 아무것도 지우지 않음, 완료 흐름, `append` 교차 실행(head를 읽은 직후 마지막 기록 파일을 지우는 경우 포함), moto S3와 로컬 HTTP S3 대역의 재시도·삭제 1번.
- `tests/integration/test_disposed_deletion_ledger.py`(PostgreSQL): 모두 파기한 장부에서 API 콘텐츠 삭제·탈퇴 기록·원본 삭제 재시도·Volume 이관, `run_job` daily·manual의 checkpoint 캡처와 검증(DB dump와 상태 조사만 대역).
- `tests/deployment/test_disposed_ledger_restore_check.py`: `restore-check`가 시작 지점 이후 지점은 장부 검사를 통과하고, 앞선 지점은 첫 Docker 호출 전에 실패한다. `image_deletions checkpoint`가 시작 지점부터 검증한다.

### 검증

- 리뷰 전 부분 검사: 새 테스트를 먼저 돌려 46개 실패를 확인했다. 구현 뒤 장부를 쓰는 기존·새 테스트 묶음 949 passed, skip 0. 끝 기록 대체를 끈 변형에서 새 테스트 14개가 실패했다.
- 리뷰 반영: 새 재현 테스트 10개가 먼저 실패(`DID NOT RAISE`)했고, 고친 뒤 `tests/integrations`와 restore-check 묶음 503 passed.
- CI(`5e44e01`, 리뷰 반영 전): workflow_dispatch [run 43384627521](https://github.com/clip-back/clipback/actions/runs/43384627521) success. deployment 15 passed, operator-recovery 32 passed, 둘 다 skip 0. 리뷰 반영 커밋 `22fa9e3`의 CI는 이 기록 시점에 아직 없다.
- 최종 전체 검증(`22fa9e3`, 깨끗한 작업 트리):

```text
pytest: 2603 passed, 48 skipped, 3 warnings in 326.21s (0:05:26)
pytest skip: 47 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=11 failed=0
```

- 미검증: Docker 검사는 로컬에서 돌리지 않았다. 파기한 장부로 실제 격리 복원하는 경우는 #347 몫이다.
