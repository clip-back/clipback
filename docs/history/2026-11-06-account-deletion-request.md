# `DELETE /users/me`와 앱의 탈퇴 요청 (#253)

2026-11-06, 시작 커밋 `a07c9c5233ef5576929c629205149d6fa2487d1d` 기준으로 구현하고 티켓 리뷰 반영과 전체 검증까지 마쳤다.
회원 탈퇴 스펙 #250의 세 번째 티켓이다. 공급자 철회(#254)·운영자 명령(#255)·탈퇴 화면(#256)은 이 기록에 없고,
이 기록은 배포·운영 확인 완료를 뜻하지 않는다. 결정 근거는 [ADR 0007](../adr/0007-account-deletion-immediate-and-replayed.md)·
[ADR 0008](../adr/0008-account-deletion-ledger-record.md)이고 앞 티켓은 [#251 기록](2026-11-06-account-deletion-ledger.md)·
[#252 기록](2026-11-06-account-deletion-restore-probe.md)이다.

## 구현

- 서버 `DELETE /api/v1/users/me`(`backend/app/api/v1/endpoints/users.py`): 기존 Bearer 인증, 본문 `{"reasons": [...]}`, 성공 204 본문 없음.
  - 본문 검증(`backend/app/schemas/user.py`): 사유 값 `rejoin`·`low_usage`·`privacy_security`·`other`만, 1개 이상, 중복 불가. 공백 정리·대소문자 변환 없음.
  - 처리(`backend/app/services/account_deletion_service.py`의 `delete_account`): #251의 장부 기록 → 계정 DB 삭제와 사유 기록을 한 트랜잭션 → 커밋 뒤 원본 정리.
    장부 잠금을 얻은 뒤 계정이 없으면(겹친 앞 요청이 지움) 401, 장부 실패는 503, 그 밖의 예외는 롤백 뒤 기존 5xx다.
    원본 정리 실패는 204를 바꾸지 않고 기존 삭제 작업 행에 미완료로 남는다.
- 탈퇴 사유 기록: 새 테이블 `account_deletion_reasons`(`id`, `reasons` 문자열 배열, `deleted_on` 날짜, FK 없음)와 마이그레이션 `202611060022`.
  날짜는 탈퇴가 성공한 트랜잭션 시점의 한국 표준시 날짜다.
- 앱 `frontend/lib/clipback_api.dart`: `AccountDeletionReason`, `AccountDeletionResult { deleted, unauthorized, failed }`, `ClipbackApi.deleteAccount`.
  기존 요청 경로(401 → 공유 갱신 → 재전송 → 기존 세션 무효화)를 쓰고, 그 전체를 60초 요청 범위 하나로 묶는다. 204만 성공이다.
  화면·인증 작업 가드·기기 정리는 #256에서 연결한다.
- 문서: [API 계약의 회원 탈퇴](../backend/api-contracts.md#회원-탈퇴)(카테고리 제출 기록의 "계정 삭제 시 FK cascade" 문장 정정 포함),
  [서버 README](../../backend/README.md#회원-탈퇴), `CHANGELOG.md` 미배포 `[서버]` 항목.

## 실제 부분 검사

로그는 `.utmp/ticket-253/` 아래에 있고 첫 줄에 명령이 있다. 서버 테스트는 임시 PostgreSQL DB `clipback_t253`에서
`alembic upgrade head` 뒤 실행했다.

- 시작 커밋에 새 API 테스트만 얹은 실행 → 40 failed, 3 errors(라우트·사유 테이블 없음, `red-server.log`).
  앱은 새 테스트가 없는 이름으로 로딩 실패(`red-app.log`). 마이그레이션 테스트는 마이그레이션 뒤에 써서 빨간 단계 로그가 없다.
- 구현 뒤 ruff, `alembic upgrade head`·`alembic check`, 새 API·마이그레이션 테스트와 #251 계정 삭제·이미지 삭제·인증 흐름·복원 probe 계정·
  요약 마이그레이션 테스트 → **83 passed**, skip 없음(`partial-server.log`).
- 앱 format·analyze와 새 API 테스트·세션 갱신·이미지 정책·사용자 Repository 테스트 → **61 passed**(`partial-app.log`).
- 변형 실험: 서버 5종(중복 허용, 겹침 뒤 404, 사유를 장부 전에 커밋, 원본 정리 생략, 한국 날짜 아님), 앱 4종(61초, 기한 없음, 2xx 전부 성공,
  401 재전송 안 함)이 모두 실패로 잡혔고 파일은 복사본으로 되돌렸다(`mutation-server.log`, `mutation-app.log`).
- 서버 상태 표의 각 행, 오류 우선순위 5행(실제 라우트), 겹침 3행은 `backend/tests/integration/test_account_deletion_api.py`에 있다.
  겹침 3행은 실제로 커밋되는 세션에서 두 요청을 동시에 보내고, 뒤 요청이 장부 잠금을 기다리는 것을 `pg_locks`로 확인한 뒤 앞 요청을 진행한다.

## 티켓 리뷰

2026-11-06 티켓 리뷰 `.utmp/review-253.md`: Standards 0건, Spec 중간 1건.

- 지적: 401 뒤 기존 세션 무효화 콜백을 기다리는 동안에는 60초 제한이 걸리지 않았다. `ApiRequestScope.run`은 Zone만 설정하고 반환 Future를
  취소와 경합시키지 않는데, 무효화 콜백 대기 두 곳(`_sendWithSessionRetry`의 갱신 401 경로와 재전송 401 경로)에는 범위의 `wait`가 없다.
  실제 콜백(`frontend/lib/app/app_dependencies.dart`)은 공유 차단과 저장 세션 삭제(`session_repository.dart`의 `invalidate`)를 기다리므로
  저장소가 느리면 탈퇴 호출이 60초에 끝나지 않는다. iOS·Android가 같은 Dart 코드를 쓰므로 두 플랫폼 모두 해당한다. 리뷰어 재현:
  `.utmp/review-253-timeout_test.dart`, `.utmp/review-253-timeout.log`.
- 판단: 동의. R4("로그인 갱신과 재전송을 포함한 탈퇴 제출 전체를 60초로 본다")와 다르다.
- 반영(`92e8d4a`): 요청 전체를 같은 범위의 `wait`로 감쌌다(기존 카테고리 저장 Action과 같은 `scope.run(() => scope.wait(...))` 형태).
  무효화 콜백 자체는 그대로 끝까지 돌아 세션을 정리한다. 일반 요청의 대기 정책은 바꾸지 않았다.
  - 두 401 경로마다 콜백 진입 1회 → 59.999초 미완료 → 60초에 `failed` → 콜백이 늦게 끝나도 결과 그대로를 단언하는 테스트 2개를 더했다.
  - 수정 전 `7740ab0` + 새 테스트 → 2 failed(`red-app-invalidation.log`, 둘 다 60초에 결과 없음).
  - 수정 뒤 format·analyze(출력 포함)와 새 API·세션 갱신·이미지 정책·사용자 Repository 테스트, 리뷰어 재현 테스트 → **65 passed**
    (`partial-app-invalidation.log`).
- 같은 상태를 만드는 다른 진입점: `_onSessionInvalidated`를 기다리는 곳은 위 두 곳뿐이고, 모든 인증 요청(`_request`, 스크린샷 업로드,
  원본 asset 요청)이 이 함수를 지난다. 탈퇴 외에 기한이 있는 범위 중 카테고리 조회·생성·수정과 저장 후 목록 갱신 Action, 홈 최초 불러오기는
  이미 `wait`로 감싼다. 마이 통계(`user_repository.dart`의 10초 `loadStats`)와 계정 초기화의 10초 메타데이터 범위는 `run`만 써서 같은
  성격의 대기가 남지만, 일반 API 대기 정책 유지 대상이고 이 티켓 범위 밖이라 바꾸지 않았다.

## 전체 검증

검증 기준 코드 커밋은 `92e8d4a198f2869faf91da810aec01a0f38f359a`다. 17:20 KST busy 대기 완료 뒤 작업 트리 루트에서
다음 명령을 셸 제한 600초로 한 번 실행했고, 종료 코드 0을 확인했다. 실행 기록의 커밋은 `92e8d4a`, 작업 트리는 깨끗했다.

```sh
~/.heoturu-agents/busy.sh && python3 ~/.heoturu-agents/verify.py --log-dir .utmp/ticket-253
```

- 서버 ruff·compileall, 일반·maintenance 테스트 DB 각각의 `alembic upgrade head`·`alembic check`, 전체 pytest 통과.
  `backend-pytest.log`의 마지막 요약: `2151 passed, 47 skipped, 3 warnings in 184.74s (0:03:04)`.
  #252 전체 검증(2107 passed)보다 44개 많고, 이번에 더한 API 테스트 43개와 마이그레이션 테스트 1개와 같다.
- 앱 pub-get·format·analyze·전체 test 통과. `app-test.log`의 마지막 결과: `02:30 +2947: All tests passed!`.
  #252 때(+2931)보다 16개 많고, 새 앱 테스트 16개와 같다.
- 결과 원문은 `.utmp/ticket-253/20261106T172058-8ea5a398dfd6/verify-result.txt`, 단계별 원본은 같은 폴더다.
  콘솔 마지막 줄(`.utmp/ticket-253/verify-console.log`)과 결과 파일의 VERIFY 줄이 같음을 대조했다.

```text
pytest skip: 46 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=11 failed=0 logs=/Users/leehyeongyu/orca/workspaces/Clipback/account-deletion/.utmp/ticket-253/20261106T172058-8ea5a398dfd6
```

skip의 전체 사유는 `backend-pytest.log`의 `SKIPPED` 줄에 있다. deployment 46건은 Docker 실행 옵션·라벨된 로컬 이미지가 없는
Docker 검사이고(#252와 같은 수), integration 1건은 `CLIPBACK_IMAGE_TEST_S3_ENDPOINT`가 필요한 로컬 합성 CLI 검사
(`test_image_storage_admin_cli.py`)다. 이번에 더한 DB 대상 테스트는 skip되지 않았다. skip은 통과 수에 넣지 않는다.

이 결과를 기록하는 후속 커밋은 문서만 바꾸며 검증 기준 코드와 같다. 전체 검증은 다시 실행하지 않았다.

## 미검증

- CI deployment·operator-recovery Docker 작업은 이 코드로 아직 실행되지 않았다. 특히 #252의 옛 리비전 이미지 사례
  (`test_legacy_account_deletion_restore_docker.py`)는 현재 서버의 `record_account_deletion`·`apply_account_deletion`만 쓰고 새 사유 테이블을
  건드리지 않아 영향이 없을 것으로 보지만, CI 결과로 확인해야 한다.
- 앱 탈퇴 요청은 가짜 HTTP 클라이언트로만 확인했다. 화면 연결과 시뮬레이터·에뮬레이터 확인은 #256 범위다.
- 공급자 철회(#254)는 아직 없다. 운영 DB·Bucket·장부, 실계정·실기기는 미검증이다.
