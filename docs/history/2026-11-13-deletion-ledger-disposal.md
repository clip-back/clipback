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

## #346 백업 보존 정리에서 삭제 장부 30일 파기와 원본 정리 작업 행 정리

구현 커밋 `4a389ca`, 보장 범위 테스트 `099ef99`, Docker 테스트 고정물 수정 `6eadf5a`(최종 전체 검증·CI 기준). 이 절을 더한 커밋은 문서만 바꾼다.

### 착수 전 확인 (`73d489e`)

- 실제 `maintain` 명령을 로컬 PostgreSQL·moto 백업 Bucket·로컬 장부로 돌렸다. 출력은 7필드였고 `deletion_records_pruned`는 0, 40일 전 `image_deletions` 행 3개는 그대로 남았다. 기존 `maintain` 출력 고정 테스트 172개가 통과했다. 스펙의 현재 동작과 같았다.

### 사용자 결정

- 2026-11-13 "추천대로"(A1): DB 없이 `maintain` 출력을 고정하는 `test_recovery_point_bucket_outputs.py` fixture에 파기 단계 결과 대역 연결 한 줄만 더한다.
- 2026-11-13 "추천대로"(A2): intent에 `source_identity`가 있는 이관 정리 행은 행 삭제에서 뺀다. 사용자가 이관된 사진을 나중에 지울 때 이 행으로 일부러 남겨 둔 Volume 원본 별칭을 찾아 지우기 때문이다. 스펙 Q-B3("완료됐고, 삭제 시각이 29일 지났고, 남아 있는 장부 기록에 묶이지 않은 행")를 좁힌다.
- 2026-11-13 "추천대로"·"좋아"(보장 범위): 행 삭제의 장부 재읽기는 잠금 밖(Q-B4 그대로)에 둔다. 승인 문구는 다음과 같다. "재읽기와 DELETE 사이에 같은 operation_id의 새 기록이 생기면 행이 지워질 수 있으나 기록은 남고, retry가 행을 다시 만들어 정리에 성공하면 deleted_at+29일에 정상 파기된다. 완료하지 못하면 deleted_at+30일 초과에 overdue로 드러난다."
- 2026-11-13 "1. 승인": 수동 백업 Docker 테스트의 축약 스키마에 새 SQL이 읽는 열만 더한다.
- 이슈 #344·#346 본문은 고치지 않았다. 본문과 다른 점은 A2와 위 보장 범위다.

### 구현

- `backend/scripts/image_backup_jobs.py`
  - `maintain`은 보존 정리(`maintain_backups`, 바뀌지 않음)를 예외 없이 마친 뒤 같은 시각 기준으로 파기한다. 보존 정리가 예외로 끝나면 파기하지 않는다. `passed`는 보존 정리 결과 AND `deletion_records_overdue == 0`이다.
  - (c)는 보존 정리 뒤 백업 Bucket에 남은 완료 지점 manifest를 다시 읽어, 장부 checkpoint가 있는 지점들의 순번 최솟값으로 본다.
  - 장부 쓰기 잠금 `74264002`(단독 session lock, 기존 `source_lock`) 안에서 남은 기록을 읽는다. (a)(c)를 통과한 앞부분만 읽기 전용 트랜잭션 하나로 (b)를 확인한 뒤, 시작 지점을 쓰고 확인하고 잠금을 푼다. (b)는 이미지 기록이면 같은 operation_id 행이 완료, 탈퇴 기록이면 같은 번호·생성 시각의 계정이 없고 그 기록으로 만든 행이 모두 완료다.
  - 잠금을 푼 뒤 남은 파일을 지우고, 장부를 다시 읽어 묶임 집합을 만든다. 정리 행은 DELETE 조건(완료, 삭제 시각 29일 지남, 묶이지 않음, 이관 행 아님) 한 문장으로 지우고 commit은 한 번이다. 작업 잠금 `74264003`은 끝까지 유지한다.
  - 출력에 `deletion_records_overdue`·`image_deletion_rows_pruned`를 더하고 `deletion_records_pruned`를 실제 값으로 채웠다. 기존 필드의 뜻은 그대로다.
- `backend/app/integrations/deletion_ledger.py`: `read_verified_remainder()`를 더했다. 탈퇴 정리 행 ID 공식(`account_content_operation_id`)을 여기로 옮겼다(운영자 `maintain` 이미지는 API 설정을 읽지 않음). 계정 삭제 서비스는 같은 이름으로 가져다 쓴다.
- [ADR 0013](../adr/0013-deletion-ledger-30-day-disposal.md) (b)에 Q-B2 한 줄을 더했다.

### 테스트

- 새 `tests/integration/test_deletion_ledger_disposal.py`(PostgreSQL) 37개:
  - 파기 판정 표 8행과 (b)의 행 없음·계정 남음
  - 행 삭제: 묶임, 업로드 실패 행, 이관 행 보존, 복원으로 되살아난 행, 완료가 늦어진 행, 판정 뒤 묶임·완료 되돌림
  - 잠금 대기와 단계별 잠금 보유(`pg_locks`), 읽기 전용 트랜잭션
  - 실제 `maintain` 명령의 상태·오류 분류 표 각 행: 행 삭제 commit 전 오류는 실제 트리거, commit 뒤 오류는 대역
  - 신선도 부족·`retention_overdue`에서 파기 제한과 `passed=false`, 파기 뒤 `retry`
  - 승인된 보장 범위의 관찰값 4개: 재읽기 전에 묶이면 행 보존, 재읽기 뒤에 묶이면 행 삭제·기록 보존, `retry` 없으면 30일 넘김, `retry`가 행을 다시 만들면 29일에 파기
- 바꾼 기존 테스트:
  - `test_recovery_point_bucket_outputs.py`: A1 연결과 `retention()`의 새 필드 기대값 2개
  - `test_manual_backup_docker.py`: 축약 seed의 `users`·`image_deletions`에 열만 추가
  - 나머지 기대값·이름은 그대로다.

### 리뷰

- 감독 Codex 검수: Standards·Spec 지적 0건.
- 검수자가 정적 대조로 제품 경로의 경쟁 조건을 찾지 못했다. 대상은 29일 지난 완료 행과 같은 operation_id의 새 기록이 생기는 경로이고, 복원·`retry`·계정 번호 재사용·이관을 포함한다. 운영 교차 실행을 재현한 증거는 아니다.

### 검증

- 리뷰 전 부분 검사:
  - 새 테스트와 장부·탈퇴·이관·출력 고정 테스트 묶음 945 passed, skip 0
  - 구현 변형 9개가 각각 해당 테스트로 잡혔다.
- CI(`099ef99`): workflow_dispatch [run 43398354120](https://github.com/clip-back/clipback/actions/runs/43398354120) failure.
  - operator-recovery 1 failed: `test_manual_backup_docker.py`의 `maintain`이 `ProgrammingError`로 끝났다.
  - 원인은 테스트의 축약 스키마에 새 SQL이 읽는 열이 없던 것이다. 로컬 PostgreSQL에서 같은 SQL이 축약 스키마에서만 42703으로 실패함을 재현했다.
  - `6eadf5a`에서 seed에 열을 더했다.
- 최종 CI(`6eadf5a`): workflow_dispatch [run 43409311290](https://github.com/clip-back/clipback/actions/runs/43409311290) success.
  - operator-recovery 32 passed, 앞 실패 테스트 포함
  - deployment 15 passed, 둘 다 skip 0
  - migration 1040 passed, 1 skipped
- 운영 `maintain` DB 역할 권한: 확인됨(사용자 운영 콘솔 확인, 2026-11-13). `current_user=postgres`, `image_deletions` SELECT·DELETE와 `users` SELECT 가능. `maintain`은 API와 같은 `DATABASE_URL`을 쓴다. 로컬 테스트와 CI는 이 권한을 증명하지 않는다.
- 최종 전체 검증(`6eadf5a`, 깨끗한 작업 트리):

```text
pytest: 2640 passed, 48 skipped, 3 warnings in 337.69s (0:05:37)
pytest skip: 47 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=11 failed=0
```

- 미검증:
  - Docker 검사는 로컬에서 돌리지 않았고 CI로만 확인했다.
  - `source_lock`의 unlock 실패 → 연결 무효화 경로는 기존 코드라 새 테스트가 없다.
  - 운영에서의 실제 파기는 첫 대상 기록이 29일 되는 날 이후 운영 확인 항목으로 따로 확인한다.

## #347 운영 문서와 파기한 장부 격리 복원 Docker 경우

구현 커밋 `bde063b`, 리뷰 반영 커밋 `1ab08b3`·`7ed13c8`(문서만, 최종 전체 검증 기준 `7ed13c8`). 이 절을 더한 커밋은 문서만 바꾼다.

### 착수 전 확인 (`a6249f7`)

- 없앨 문구 5개는 각 1건, `image-operator-first-run.md`의 "확인하기 전"은 5건, ADR 0007 "계속 보관"은 1건이었다. 티켓 원문과 같다.

### 사용자 결정

- 2026-11-13 "이 티켓에 포함"·"다섯 곳 모두": #339 상태 줄 다섯 곳과 이어지는 자동 운영 문장을 #339 운영 적용 결과(네 서비스 main 자동 배포, `maintain` 매시간 `passed`, `retry` 첫 실행 `pending` 0 — 사용자 확인)로 맞춘다. #344 파기의 운영 완료로 쓰지 않는다.
- 2026-11-13 "추천대로"(Q16-B2 확인 기준): 첫 실제 파기 확인 SQL의 전체 `count`·`min`은 관측값으로 두고, 이관 정리 행(`source_identity`)을 뺀 `target_min`이 30일 안인지로 판정한다. 회의 Q16 원문("min이 30일 안")을 #346 결정 A2(이관 행 보존)에 맞춰 바꾼 것이다.

### 구현

- `tests/deployment/test_image_backup_docker.py`: 앞 기록을 파기(시작 지점 = head − 1)한 뒤 남은 복구 지점을 `restore-check`로 격리 복원하는 경우를 더했다. CI 명시 목록에 이미 있는 파일이다. 기존 경우·fixture·이름은 바꾸지 않았다.
- `docs/backend/backup-recovery.md`: "삭제 장부 30일 파기" 절(시작 지점, 조건 3가지, 잠금 범위, 행 삭제 범위와 이관 행 제외, 재읽기 틈의 승인된 보장 범위, 새 출력 필드, 30일 넘김 실패). 되돌리기 절에 첫 파기 뒤 이 기능 이전 리비전으로 되돌리지 않는다는 문장.
- `docs/backend/image-deletion.md`: 검증을 시작 지점부터로, 끝 절을 30일 파기로.
- `docs/backend/image-operator-first-run.md`: `maintain` 시작 명령 한 줄, 명령별 필요한 변수 표, 파기 설명, 배포 체크리스트(장부 Bucket 키 삭제 권한, 병합 순서 Q-B8, 처리방침 게시 Q17, 첫 실제 파기 확인 SQL), #339 상태 줄 다섯 곳.
- `docs/railway-deployment.md`: 첫 파기 뒤 이 기능 이전 서버로 되돌리지 않는다는 한 줄.

### 리뷰

- 감독 Codex 검수: Standards 0건, Spec 중간 3건.
  1. 행 삭제 재읽기 틈의 보장 범위가 운영 문서에 없음 → `1ab08b3`에서 승인 문구를 보존 정리 절에 넣었다.
  2. 첫 파기 확인 SQL의 "전체 min 30일 안"이 이관 행 보존(A2)과 충돌 → 사용자 결정 "추천대로"로 `7ed13c8`에서 이관 행을 뺀 기준과 SQL로 바꿨다. 대상 0행이면 `target_min`이 NULL이고 정상이다. 장부 기록 없는 업로드 실패 행은 미완료로 30일을 넘겨도 `deletion_records_overdue`에 잡히지 않아 `retry`의 `pending`을 함께 본다.
  3. 처리방침 게시 순서(Q17) 누락 → `1ab08b3`에서 배포 체크리스트에 게시 단계를 넣었다.

### 검증

- 리뷰 전 부분 검사: 새 Docker 경우의 장부 단언(파기 뒤 남은 키, 남은 기록)을 moto 대역으로만 확인했다. 문서 문구 제거·링크·`git diff --check`를 확인했다.
- 확인 SQL: 로컬 PostgreSQL 임시 DB에서 문서의 SQL을 그대로 실행했다. 빈 표, 40일 된 이관 행만(대상 0행, `target_min` NULL), 10일 된 대상 행 추가(`target_min` 10일 전), 35일 된 미완료 대상 행 추가(`target_min` 35일 전)가 각각 기대대로 나왔다. 운영 DB에서는 실행하지 않았다.
- CI(`bde063b`): workflow_dispatch [run 43414783258](https://github.com/clip-back/clipback/actions/runs/43414783258) success.
  - operator-recovery 33 passed, skip 0. `6eadf5a`의 32에서 새 경우 1개가 늘었다. 같은 파일 목록의 로컬 수집에 새 테스트가 있다. 출력이 테스트 이름을 찍지 않아 이름별 통과는 개수로 판단했다.
  - deployment 15 passed, migration 1040 passed·1 skipped, test 3.11·3.12 각 1606 passed.
- `1ab08b3`·`7ed13c8`은 문서만 바꿔 CI를 다시 돌리지 않았다.
- 최종 전체 검증(`7ed13c8`, 깨끗한 작업 트리):

```text
pytest: 2640 passed, 49 skipped, 3 warnings in 337.58s (0:05:37)
pytest skip: 48 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=11 failed=0
```

- deployment skip이 47에서 48로 는 것은 새 Docker 경우다(로컬은 Docker 없이 skip).
- 운영 `maintain` DB 역할 권한은 #346 절의 사용자 운영 콘솔 확인값이다. 이 작업에서 다시 확인하지 않았다.
- 미검증·운영 단계: 장부 Bucket 키 삭제 권한(Q16-B3), 병합 순서(Q-B8), 병합 뒤 첫 `maintain`(Q16-B1)과 처리방침 게시(Q17), 첫 실제 파기(Q16-B2)는 병합 뒤 사용자가 확인한다.
