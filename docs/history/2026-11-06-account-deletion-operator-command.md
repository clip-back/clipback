# 운영자 계정 삭제 명령 (#255)

2026-11-06, 시작 커밋 `b87a08e3a6ef97258e285d110f5bbfbbc0f34e3e` 기준으로 구현하고 티켓 리뷰 반영과 전체 검증까지 마쳤다.
회원 탈퇴 스펙 #250의 다섯 번째 티켓이다. 탈퇴 화면(#256)과 웹 삭제 요청 처리 절차(본인 확인·5일)는 이 기록에 없고,
이 기록은 배포·운영 확인 완료를 뜻하지 않는다. 결정 근거는 #250의 D14·D19·U2,
[ADR 0007](../adr/0007-account-deletion-immediate-and-replayed.md)·[ADR 0008](../adr/0008-account-deletion-ledger-record.md)이고
앞 티켓은 [#254 기록](2026-11-06-account-deletion-provider-revocation.md)이다.

## 구현

- 명령(`backend/scripts/image_deletions.py`): 하위 명령 `delete-account --user-id <계정 번호> --confirm-irreversible`.
  `python -m scripts.image_deletions ...`와 `python scripts/image_deletions.py ...` 두 형태가 같은 `run` 경로를 탄다.
  - `retry`와 같이 전체 API 설정(`app.db.session`)을 읽고 `MaintenanceGate.operation("account_deletion")` 안에서
    앱 탈퇴와 같은 `delete_account`(계정 단위 잠금 → 공급자 연결 정리 → 장부 → DB → 원본)를 `reasons=None`으로 부른다.
  - 성공: 종료 코드 0, `{"deleted": true, "pending_original_cleanup": <이번 삭제의 미완료 정리 작업 수>}`. 정리가 남아도 0이다.
  - 계정 없음(이미 지워짐 포함): 종료 코드 1, `Account not found; nothing was deleted`. 그 밖의 실패: 종료 코드 1,
    `Account deletion failed; no successful completion is confirmed`. 입력 오류(번호 없음·숫자 아님·0 이하, 확인 옵션 없음): argparse 종료 코드 2.
- 서비스(`backend/app/services/account_deletion_service.py`의 `delete_account`): `reasons`가 `None`이면 사유 기록을 넣지 않는다.
  이번 삭제의 정리 operation ID 목록을 돌려주고, 남은 수는 명령이 센다(API 경로에는 커밋 뒤 조회를 늘리지 않음).
  API 엔드포인트·요청 스키마는 바꾸지 않아 앱 요청은 여전히 사유 1개 이상이 필요하다.
- 문서: [이미지 삭제 운영의 운영자 계정 삭제](../backend/image-deletion.md#운영자-계정-삭제)(명령·결과·종료 코드),
  [서버 README](../../backend/README.md#회원-탈퇴) 한 줄, [API 계약](../backend/api-contracts.md#회원-탈퇴)의 잠금 설명에 운영자 계정 삭제 포함, `CHANGELOG.md` 미배포 `[서버]` 항목.
- `scripts/`에 새 파일이 없어 Dockerfile 허용 목록은 바꾸지 않았다.

## 실제 부분 검사

로그는 `.utmp/ticket-255/` 아래에 있고 첫 줄에 명령이 있다. 임시 PostgreSQL DB `clipback_t255`에서 `alembic upgrade head` 뒤 실행했다.
테스트(`backend/tests/integration/test_account_deletion_operator.py`)는 모두 명령을 실제 하위 프로세스로 실행하고, 공급자는 하위 프로세스 안의 가짜 HTTP 전송만 썼다.

- 구현 전 → 10 failed, 9 passed(`partial-red.log`; 입력 오류 9사례는 하위 명령이 없어 argparse 2로 통과).
- 첫 커밋 `adcaafe`: 새 테스트 19 passed(`partial-green.log`). ruff·compileall과 새 테스트·#253 API·#254 공급자·#251 계정 삭제·이미지 삭제·운영자 소스·이관·운영자 CLI 단위 → 139 passed, skip 없음(`partial-related.log`).
- 변형 2종(명령이 사유를 넘김, 실패 시 예외 원문 출력)이 각각 2·4 failed로 잡혔다(`mutation.log`).

## 티켓 리뷰

2026-11-06 티켓 리뷰 `.utmp/review-255.md`: Standards 0건, Spec 중간 1건.

- 지적 S1: 계정 없음 예외가 점검 게이트 밖으로 나가 게이트가 admission을 끝내지 않았다. 없는 번호나 이미 지운 번호로 실행하기만 해도
  `maintenance_operations`에 행이 남아 이후 점검 drain이 끝나지 않는다. 완료 조건 "계정 없음: DB 변화 없음"과 다르고,
  첫 테스트는 서비스 제어 테이블을 비교에서 빼서 이를 놓쳤다.
- 판단: 동의. 계정 없음은 잠금을 얻은 뒤 확정된 무변경 결과이므로 게이트 안에서 받아 게이트를 정상 종료하고 게이트 밖에서 종료 코드 1로 바꾼다.
  불확실한 실패의 admission 증거 보존과 `retry` 게이트 정책은 바꾸지 않았고, 사전 존재 확인으로 우회하지 않았다(동시 삭제 경합은 기존 잠금 뒤 판정 그대로).
- 반영(`daa0155`): 새 회귀 테스트 `test_missing_account_leaves_no_maintenance_admission`(없는 번호·이미 지운 번호 × 두 실행 형태)이
  서비스 제어 테이블을 포함한 전체 표를 전후 비교한다. DB 실패 테스트에는 admission 행 1개가 증거로 남는다는 단언을 더했다.
  - 수정 전 → 2 failed(`partial-s1-red.log`), 수정 뒤 관련 범위 131 passed(`partial-s1-green.log`), 두 형태로 넓힌 새 테스트 파일 23 passed(`partial-s1-forms.log`).
- 같은 원인 대조: 두 실행 형태는 같은 `run` 경로다. API의 점검 미들웨어는 앱 안에서 401이 응답으로 바뀌어 게이트가 정상 종료된다.
  다른 운영 스크립트(`image_storage_admin`·`image_migration`·`image_backup_jobs`·`image_backup`)는 무변경 결과를 예외로 내지 않는다.

## 전체 검증

검증 기준 코드 커밋은 `daa0155a98d5862876617567144afbaf7d3b2ee8`이다. 18:29 KST busy 대기 완료 뒤 작업 트리 루트에서
다음 명령을 셸 제한 600초로 한 번 실행했다. 실행 기록의 커밋은 `daa0155`, 작업 트리는 깨끗했다.

```sh
~/.heoturu-agents/busy.sh && python3 ~/.heoturu-agents/verify.py --log-dir .utmp/ticket-255
```

- 서버 ruff·compileall, 일반·maintenance 테스트 DB 각각의 `alembic upgrade head`·`alembic check`, 전체 pytest 통과.
  `backend-pytest.log`의 마지막 요약: `2207 passed, 47 skipped, 3 warnings in 205.06s (0:03:25)`.
- skip 47개: Docker가 필요한 `tests/deployment` 46개와 로컬 S3 대역이 필요한 `tests/integration/test_image_storage_admin_cli.py` 1개.
  이번 티켓의 운영자 명령 테스트는 skip 없이 실행됐다.
- 앱 `flutter pub get --enforce-lockfile`, `dart format`, `flutter analyze --no-pub`, `flutter test --no-pub` 통과(`+2947: All tests passed!`).
- 마지막 줄: `VERIFY result=PASS scope=all checks=11 failed=0`. 로그는 `.utmp/ticket-255/20261106T182931-71e90026292f/`.

## 미검증

- CI `backend-validation.yml`의 deployment·operator-recovery Docker job은 로컬에서 실행하지 않았다. push 뒤 CI 결과로 확인한다.
- 운영 서버·운영 DB·Bucket에서 명령을 실행하지 않았고 실제 Apple·카카오 공급자 호출도 하지 않았다(가짜 HTTP만).
- 원본 정리 실패 테스트는 원본 폴더를 읽기 전용으로 바꿔 만든다. root 권한 환경에서는 실패가 재현되지 않는다.
