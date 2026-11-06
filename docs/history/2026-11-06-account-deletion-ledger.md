# 계정 탈퇴 장부 기록과 계정 재삭제 (#251)

2026-11-06, 시작 커밋 `8d185f0c0aebc1230b204edcdedd504ab4b7f747` 기준으로 구현하고 티켓 검수와 전체 검증까지 마쳤다.
회원 탈퇴 스펙 #250의 첫 티켓이다. 앱 요청 경로(#253)·운영자 명령(#255)·격리 복원 검증(#252)은 이 기록에 없고,
이 기록은 배포·운영 확인 완료를 뜻하지 않는다. 결정 근거는 [ADR 0007](../adr/0007-account-deletion-immediate-and-replayed.md)·
[ADR 0008](../adr/0008-account-deletion-ledger-record.md)이다.

## 구현

- 삭제 장부에 `kind: "account_deletion"` 기록을 더했다. 칸은 operation UUID, 계정 번호, 계정 생성 시각,
  삭제 의도 시각, 이미지 콘텐츠 삭제 정보(콘텐츠 ID·저장 시각·원본 backend/key·SHA-256·크기)이고 이메일·이름은 없다.
  기존 이미지 삭제 기록은 `kind` 없이 이전 형식 그대로 쓰고 읽는다.
- 기록 operation UUID는 계정 번호와 생성 시각에서 정한다. 같은 operation을 다시 쓰면 삭제 시각과 이미지 목록이 달라도
  처음 기록을 재사용한다(U2).
- 새 계정 삭제 서비스 `backend/app/services/account_deletion_service.py`를 추가했다.
  - 기록 쓰기: 장부 잠금 → 계정 행 잠금 → 기록 하나.
  - DB 삭제: 계정 번호·생성 시각이 둘 다 맞을 때만 이벤트 → 추천 노출 → 추천 항목 → 추천 묶음 → 콘텐츠 → 계정 소유 카테고리 → 계정 순서로 지운다.
  - 정리 작업 행: 삭제 직전 DB의 이미지 콘텐츠마다 하나씩 만든다. 작업 ID는 기록 operation·콘텐츠 ID·UTC 저장 시각의 UUID5다.
- 운영자 재시도는 남은 계정을 마저 지우고 결과에 `deleted_accounts`를 더한다. 기존 `reconciled`·`attempted`·`pending`은 그대로다.
  반영한 이미지 의도와 지운 계정을 합쳐 `--limit`까지 처리한다.
- 보존 정리·이관은 탈퇴 기록을 이미지 삭제 정보로 펼쳐 기존 판정에 넣는다.
- 복원 반영 소스 `scripts/recovery_deletions.py`는 탈퇴 기록을 옛 이미지의 장부 검증·새 모듈 없이 SQL로 직접 반영한다.
  처리는 장부 순서대로 하고, 지운 계정의 모든 콘텐츠를 `deleted`에 넣는다. 삭제 순서와 작업 ID 식은 서비스와 같게 두 곳에 둔다(ADR 0004).
- 문서: [이미지 삭제](../backend/image-deletion.md), [백업 복원](../backend/backup-recovery.md),
  [Railway 배포 "복원과 롤백"](../railway-deployment.md#복원과-롤백). DB 스키마와 `scripts/` 새 파일은 없다.

## 실제 부분 검사

로그는 `.utmp/ticket-251/` 아래에 있고 첫 줄에 명령이 있다. 서버 테스트는 임시 PostgreSQL DB `clipback_t251`에서
`alembic upgrade head` 뒤 실행했다.

- 시작 커밋에 새 테스트만 얹은 실행: 장부 테스트는 import 실패, 새 보존 테스트 3개 실패, 새 통합 테스트는 서비스 모듈이 없어
  수집 실패. 기대한 실패 기록이다(`red-ledger-retention.log`, `red-account-deletion.log`).
- `tests/integrations/test_deletion_ledger.py` → **26 passed**(`partial-ledger.log`).
- `tests/deployment/test_image_backup_retention.py` → **14 passed**(`partial-retention.log`).
- `tests/integration/test_account_deletion.py` → **8 passed**, skip 없음(`partial-account-deletion.log`).
- 이관·이미지 삭제·장부·보존·백업·복구 지점 출력·운영자 CLI·백업 복원·live restore CLI(비Docker) 묶음 → **364 passed**,
  skip 없음(`partial-consumers.log`). 앞의 실행과 겹치므로 합산하지 않는다.

`python -c` 하위 프로세스 테스트는 현재 코드에서 계정 삭제 모듈과 새 장부 이름을 막은 환경으로 실행한 것이다.
실제 이전 리비전 API 이미지 실행 성공으로 보지 않는다(#252의 CI Docker 사례 몫).

## 실패와 수정

- 장부 입력 시험에 넣은 `user_id: "1"`은 pydantic 기본 검증이 1로 바꿔 받아들였다. 기존 이미지 기록과 같은 동작이라
  코드는 그대로 두고 입력을 `1.5`·`[1]`로 바꿨다.
- 소비자 묶음의 첫 실행은 zsh가 변수 속 공백을 나누지 않아 pytest가 실행되지 않았다. 명령을 고쳐 다시 실행했다.

## 티켓 리뷰와 전체 검증

2026-11-06 티켓 리뷰 `.utmp/review-251.md`의 Standards·Spec 모두 높음·중간·낮음 0건이다. 반영할 지적이 없어
코드·테스트를 바꾸지 않았다.

검증 기준 코드 커밋은 `313a15ffc5173925310ed48fe26a365795116c12`다. 15:51 KST busy 대기 완료 뒤 작업 트리 루트에서
다음 명령을 셸 제한 600초로 한 번 실행했고, 종료 코드 0을 확인했다. 실행 기록의 커밋은 `313a15f`, 작업 트리는 깨끗했다.

```sh
~/.heoturu-agents/busy.sh && python3 ~/.heoturu-agents/verify.py --log-dir .utmp/ticket-251
```

- 서버 ruff·compileall, 일반·maintenance 테스트 DB 각각의 `alembic upgrade head`·`alembic check`, 전체 pytest 통과.
  `backend-pytest.log`의 마지막 요약: `2086 passed, 46 skipped, 3 warnings in 171.93s (0:02:51)`.
- 앱 pub-get·format·analyze·전체 test 통과. `app-test.log`의 마지막 결과: `02:32 +2931: All tests passed!`.
- 결과 원문은 `.utmp/ticket-251/verify-result.txt`, 단계별 원본은 `.utmp/ticket-251/20261106T155103-ed4a4f3447f8/`다.

```text
pytest skip: 45 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=11 failed=0 logs=/Users/leehyeongyu/orca/workspaces/Clipback/account-deletion/.utmp/ticket-251/20261106T155103-ed4a4f3447f8
```

skip의 전체 사유는 `backend-pytest.log`의 `SKIPPED` 줄에 있다. deployment 45건은 Docker 실행 옵션·라벨된 로컬 이미지가 없는
Docker 검사이고, integration 1건은 `CLIPBACK_IMAGE_TEST_S3_ENDPOINT`가 필요한 로컬 합성 CLI 검사다. 이번에 더한 테스트는
skip되지 않았다. skip은 통과 수에 넣지 않는다.

이 결과를 기록하는 후속 커밋은 문서만 바꾸며 검증 기준 코드와 같다. 전체 검증은 다시 실행하지 않았다.

## 미검증

- 서버 CI의 deployment·operator-recovery Docker 작업은 로컬에서 실행하지 않았다. CI 결과로 확인해야 한다.
- 실제 이전 리비전 API 이미지에서의 복원 반영, 운영 DB·Bucket·장부, 실계정·실기기는 미검증이다.
- 사용자에게 보이는 변경이 없어(탈퇴 요청 경로는 #253) `CHANGELOG.md`에는 적지 않았다.
