# AI 전송 동의 (#474)

## #475 동의 기록·API와 저장 경로의 AI 차단

2026-11-25, `3e7521a`(#462 병합본)에서 시작해 `7d56f12`·`03be83f`·`e3f77eb`·`2d7943f`·`474944a`·`172b3b9`·`5bcc032`·`21d16fa`·`188baa5`·`4a958ac`로 마쳤습니다.

- 시작 전에 #474의 실측 V1–V17을 병합본에서 다시 재 스펙과 같음을 확인했습니다. V15는 0.7.0(`d39c62b`) 임시 워크트리에서 새 응답의 링크·사진 저장 성공, 피드, 상세 본문까지 확인했습니다.
- 계정마다 동의 기록 한 행(`ai_transfer_consents`, 리비전 `202611250027`)을 두고 `GET /users/me`의 `ai_consent_status`와 `PUT /users/me/ai-consent`를 더했습니다. 리비전의 downgrade는 거부하고, #462 되돌리기 SQL은 이 리비전 뒤에 멈춥니다.
- 저장 경로의 판정 지점 G1a·G1b·G2a·G2b·G3에서 동의·스위치(`AI_CONSENT_REQUIRED`)·재동의 규칙으로 AI 처리를 정합니다. 금지된 저장도 성공하고, 유튜브·인스타그램 게시물·사진은 `skipped`·`ai_consent_required`가 되며 한도에 세지 않습니다.
- 검수에서 재동의 판정을 바꿨습니다. 저장 요청은 첫 판정에서 읽은 커밋된 기록을 기억하고, 재동의는 같은 기록일 때만 허용합니다. 재동의가 쓰였으나 커밋 전인 때와 철회 행 잠금을 기다리는 때에 시작한 저장이 새 동의로 처리되던 틈을 막았습니다. `PUT`은 행 잠금 뒤의 DB 시각을 기록합니다.
- 재검수에서 재동의는 같은 커밋 기록이면서 첫 판정의 DB 시각이 재동의 시각 이후일 때만 허용하도록 두 조건을 함께 적용했습니다. 앱의 동의 `PUT`은 기한이 지나도 이미 보낸 갱신의 회전 토큰을 같은 계정에 남기고(계정이 바뀌면 버림) 옛 선택은 다시 보내지 않습니다. 갱신 단계의 연결 실패는 실패, 재전송 응답 유실은 결과 미확인으로 나누고 시간대 오프셋 범위도 검사합니다.
- 사용자 결정 “실패 시점 뒤 추가 0회 (추천)”에 따라 동의 읽기 실패의 0회는 실패 시점 뒤의 추가 전송을 뜻합니다. 판정 순서상 앞서 보낸 사진 글자 읽기·인스타그램 추천은 따로 셉니다.
- 검수에서 G1b는 자신이 만든 추천 시도 행만 지우도록 고쳤습니다. 앱의 동의 `PUT`은 401 갱신·재전송까지 10초 요청 범위로 묶었고, 손상된 갱신 응답과 달력에 없는 결정 시각을 성공으로 보지 않습니다.
- 사용자 결정 “4파일 허용 (추천)”에 따라 기존 테스트 4파일에서 `/users/me` 응답의 새 필드와 동의 읽기 대역, #462 테스트의 대상 리비전만 바꿨습니다. “실제 동시 재현 추가 (추천)”에 따라 게스트 전환과 동의 변경을 실제 PostgreSQL 별도 세션에서 양순서로 겹쳐 확인했습니다.
- 두 번째 재검수에서 동의 `PUT`이 기한 뒤에도 살려 둔 갱신이 401로 끝나면 같은 계정에서만 세션을 한 번 끝내도록 했습니다(`172b3b9`). 이 변경에서 같은 갱신을 기다리던 다른 요청이 세션 종료 전에 401을 넘겨, 세션 복원이 native 차단 전(0ms)에 로컬 세션을 지우고 15초에 또 지우는 회귀가 생겼습니다. `5bcc032`에서 같은 갱신의 모든 요청이 하나의 종료를 기다린 뒤 오류를 넘기게 하고, 종료 대기는 기다리던 요청 중 가장 이른 기한에 끝나게 했습니다.
- 세 번째 재검수에서 거절된 갱신의 세션 종료를 그 계정 세대에 묶었습니다(`21d16fa`). native 차단이나 저장소 쓰기 대기 중에 다른 로그인이 생기면 옛 계정의 종료는 새 계정의 메모리·저장값을 지우지 않고, 기다리던 요청은 401 대신 로그인 변경 오류를 받아 세션 복원의 401 복구도 새 계정을 지우지 않습니다. 공유 갱신의 종료는 가장 이른 기한 대신 그 갱신을 기다리는 요청이 모두 끝날 때까지 native 차단을 기다리고, 각 요청은 자기 기한·취소에 끝납니다. 이미 기한이 지난 동의 `PUT`은 다른 요청의 대기를 끊지 않고, 기다리는 요청이 없으면 차단을 기다리지 않고 바로 지웁니다.
- 네 번째 재검수에서 사용자 결정 “A: 뒤의 401은 그 정리에 합류 (추천)”에 따라 한 로그인의 세션 종료를 하나로 묶었습니다(`188baa5`). 종료가 native 차단을 기다리는 동안 같은 로그인에서 들어온 별개 갱신 거절과 재전송 최종 401은 그 종료에 합류해, 짧은 요청의 기한이 아직 유효한 긴 요청보다 먼저 로컬 세션을 지우지 않습니다. 거절된 로그인의 저장소 삭제가 실패하면 그 보류는 그 로그인에 남고, 다시 시도할 때도 그 로그인만 지웁니다. 그사이 생긴 새 로그인은 메모리·저장값·화면을 유지하고, 세션 복원은 실제로 지웠을 때만 로그인 화면으로 갑니다. 로그아웃·탈퇴의 보류는 그대로입니다.
- 다섯 번째 재검수에서 세션 복원이 보류를 보고 native 차단을 기다리는 사이 거절된 로그인의 첫 삭제가 실패하고 새 로그인이 그 자리를 차지하면, 차단 뒤 재시도가 새 로그인을 지우는 순서가 드러났습니다. 같은 순서를 기준 `3e7521a`에서 돌려도 새 로그인이 지워져 기존부터 있던 경주임을 확인했습니다. 사용자 결정 “좁은 안 + 별도 이슈 (추천)”에 따라 이 티켓은 기다리는 사이 풀린 거절 로그인 보류만 재시도에서 지우지 않게 했습니다(`4a958ac`). 보류 작업을 재시도까지 이어 확인하는 일반 해결과 로그아웃·탈퇴 보류 도중의 같은 경주는 별도 이슈로 남깁니다.
- 테스트의 탈퇴 사유 정리는 자기 계정의 탈퇴 요청에서 만든 행만 지웁니다. 다른 계정의 같은 탈퇴 API를 겹친 테스트는 두 요청을 각자의 PostgreSQL PID·기다리는 PID·만든 사유 행에 묶고, 둘째 계정과 그 행을 만든 직후부터 요청 회수 뒤 정리합니다. 둘째 계정의 사용자 PK는 그 계정을 만드는 요청에서 받아, 이어지는 조회가 실패해도 정리하고, 사유 정리가 실패해도 계정 정리를 따로 시도합니다.
- 동시성 검사는 요청마다 PostgreSQL 연결 PID를 기록하고 `pg_blocking_pids`로 어떤 요청이 어떤 요청을 기다리는지 확인합니다. 외부 AI 호출 수는 OpenAI SDK의 가짜 전송에서 셉니다.

### 검증

- 첫 전체 검사(`e3f77eb`)는 새 읽기 실패 테스트가 사진 정리 행을 남겨 뒤이은 `test_deletion_ledger_disposal.py` 1개가 실패했습니다. 작업자는 정해진 순서와 달리 기준 비교 전에 원인을 찾아 고쳤고(`2d7943f`), 사용자 결정 “수정 유지 + 기준 비교 보충 (추천)”에 따라 수정을 유지하고 기준 `3e7521a`에서 같은 조건의 전체 검사를 한 번 보충했습니다. 기준에서는 그 테스트가 통과했고, 대신 `test_instagram_summary.py::test_transient_gpt_failure_retries_once_after_thirty_seconds`가 재시도 대기 37.29초로 실패했습니다. 사용자 결정 “기준 실패로 기록하고 진행 (추천)”에 따라 진단하지 않았고, 이후 검사에서는 다시 실패하지 않았습니다.
- 첫 재검수 반영 뒤(`474944a`) 전체 로컬 검사가 통과했습니다.
- `172b3b9`의 전체 검사에서 기존 `share_lifecycle_test.dart`의 “확인된 최종401은 native 차단 지연 중에도15초에 로컬 세션을 폐기한다”가 지운 횟수 1 대신 2로 실패했습니다. 기준 `3e7521a`의 같은 조건 비교에서는 앱 검사가 모두 통과했고, 사용자 결정 “앱 실패 진단 승인 (추천)”에 따라 진단한 뒤 고쳤습니다(`5bcc032`). 계측 없는 재현에서 고친 뒤와 기준이 모두 0ms·14.9초에 0회, 15초에 1회를 보였습니다.
- `5bcc032`의 첫 전체 검사에서는 시트 131로 알려진 `test_content_save_flow_contract.py::test_rollback_failure_keeping_transaction_open_does_not_finish_within_time_limit`가 정리 뒤 남은 연결 1개(기대 0)로 실패했습니다. 기준 비교에서는 통과했습니다. 사용자 결정 “단독 여러 번 + 전체 1회 재실행 (추천)”에 따라 같은 커밋에서 그 테스트만 5번 따로 돌려 5번 모두 통과했고, 이어 돌린 전체 로컬 검사가 통과했습니다. 일반·maintenance PostgreSQL DB의 `alembic upgrade head`와 `alembic check`, `flutter analyze`가 통과했고 Flutter 테스트는 4,133개 통과했습니다.
- `21d16fa`는 수정 전 코드에서 장벽 도중 로그인·저장소 대기 중 로그인·재전송 최종 401 도중 로그인과, 만료 `PUT`·명시 취소·짧은 기한 요청이 다른 요청의 대기를 끊는 경우가 새 테스트로 실패하는 것을 먼저 확인했습니다. 새 테스트를 처음 쓸 때 기록 비교·응답 시점·확인 시점의 테스트 자체 오류 3가지를 고쳤습니다. 기존 공유 수명 테스트는 바꾸지 않았습니다. 전체 로컬 검사가 한 번에 통과했고 Flutter 테스트는 4,142개 통과했습니다.
- `188baa5`도 수정 전 코드에서 삭제 실패 뒤 새 로그인(실행 중 실패·실패 뒤 발급·재시도의 native 대기 중 발급)과, 종료 대기 중 별개 갱신 거절·재전송 최종 401이 새 테스트로 실패하는 것을 먼저 확인했습니다. 둘째 계정 정리는 조회 실패와 사유 정리 실패를 실제로 주입해 고치기 전에는 계정이 남고 고친 뒤에는 남지 않음을 확인했습니다. 전체 로컬 검사가 한 번에 통과했고 Flutter 테스트는 4,148개 통과했습니다.
- `4a958ac`는 수정 전 코드에서 같은 순서의 회귀 테스트가 차단 해제 뒤 저장값 확인에서 실패하는 것을 먼저 확인했고, 새 로그인 없는 대조는 거절된 로그인을 지웠습니다. 커밋한 코드로 돌린 전체 로컬 검사가 통과했고 Flutter 테스트는 4,150개 통과했습니다.
- 기준 비교 중에는 `test_recommendation_usage_limits.py::test_recommendation_records_with_all_save_connections_checked_out`이 기준에서만 두 번 실패했습니다. 진단하지 않았고 불안정 후보로 남깁니다.

```text
pytest: 3428 passed, 50 skipped, 3 warnings in 448.69s (0:07:28)
pytest skip: 49 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=12 failed=0
```

위 결과는 `4a958ac`의 코드입니다. 로컬 원본은 `.utmp/ticket-475/20261125T174526-1c8cccf22501/`, 기준 재현은 `.utmp/ticket-475/recheck5-base-repro/`, 그 전 `188baa5`의 통과는 `.utmp/ticket-475/20261125T171032-44a4ae695dcf/`, `21d16fa`의 통과는 `.utmp/ticket-475/20261125T160938-4a05f1c5408c/`, `5bcc032`의 통과는 `.utmp/ticket-475/20261125T150013-b950e4b14b67/`, 시트 131 첫 실패는 `.utmp/ticket-475/sheet131-first-failure-5bcc032/`, 기준 비교는 `.utmp/ticket-475/base-3e7521a-verify/`·`base2-3e7521a-verify/`·`base3-3e7521a-verify/`에 보관했습니다. Docker 배포·복구와 S3 CLI는 위 조건으로 건너뛰었습니다. 원격 CI는 PR 단계이며 운영 서버·운영 스위치·실제 AI 호출·기기 실행은 이 작업의 검증 범위 밖입니다. 서버 작업의 판정(G4·G5)과 철회 때 대기 작업 취소는 #476입니다.

## #476 서버 요약의 AI 전송 차단과 복원 재개

`7f97cc9`에서 시작한 첫 구현(`63df99f`)은 거절 전환에서 대기 요약과 월 한도 기록을 함께 정리합니다. G4에서 작업을 잡을 때, G5에서 실제 AI 업체로 보내기 직전에 동의와 임대를 확인합니다. 공개 health 응답과 worker 시작 로그로 스위치 값을 확인할 수 있게 했습니다. 복원한 DB에서는 동의함 기록만 지우고 대기·처리 중 요약을 취소합니다. 운영자는 정리 결과와 API·worker 스위치 및 복제본을 확인한 뒤 서비스를 재개합니다.

- 첫 구현 전 실제 YouTube·Instagram 클라이언트의 가짜 전송에서 각각 AI 호출 0·1·3회를 셌습니다. 첫 커밋 전 부분 검사 374건이 통과했습니다.
- 검수에서 저장 시점에는 첫 판정 시각, 요약 작업에는 `saved_at`을 쓰던 차이를 확인했습니다. 사용자 결정 “B: 저장 쪽도 저장 시작 시각 기준 (추천)”에 따라 G1a/b·G2a/b·G3는 저장 트랜잭션 시작 시각을 사용합니다. 이 값이 G4·G5에서 읽는 `saved_at`입니다. 첫 판정과 현재 판정에서 읽은 재동의 기록의 일치 조건 및 최초 동의 예외를 유지했습니다.
- 실제 PostgreSQL에서 저장 시작 뒤 별도 세션이 재동의를 쓰고 커밋한 뒤 첫 판정을 진행했습니다. 유튜브·인스타그램·사진은 처음부터 `skipped/ai_consent_required`, 웹은 `not_requested`이며 관련 AI 호출과 사용량은 0이었습니다. 재동의 뒤 시작한 대조군은 링크 요약 완료와 웹 추천, 사진 OCR·추천을 확인했습니다. 기존 #475의 경계·시각·공유 fixture 및 테스트 기대값은 그대로 유지했습니다.
- G5가 DB에서 콘텐츠 시각을 읽도록 하고 임대·동의를 같은 읽기에서 확인했습니다. 실제 asyncpg 연결 오류에선 전송 0과 재시도를 확인했습니다. Instagram의 첫 DB 읽기 실패는 30초 뒤 재시도, 마지막 실패는 한도 기록 해제로 이어집니다. 읽는 동안의 task 취소는 호출자에게 전달됩니다.
- 스위치를 켠 worker가 첫 동의 전에 먼저 건너뛴 전환기 작업도 최종 상태임을 API 문서에 명시했습니다. Docker 복원 검사에는 동의·거절이 든 덤프의 정상 복원과 동의 행 수를 틀리게 적은 manifest의 실패 대조를 추가했습니다.

### 검증

검수 수정 후 부분 검사 316건이 통과했습니다. Docker 복원 검사는 로컬에서 PostgreSQL 16·18 두 케이스가 수집되었고 실행은 CI의 `operator-recovery`에 남았습니다. 기존 #475 테스트 수정은 없었습니다.

2026-11-25, `63df99f`에 검수 수정 코드를 적용한 상태에서 전체 VERIFY를 한 번 실행했습니다. 일반·점검용 DB의 마이그레이션 적용과 정합성 검사, Flutter 검사와 테스트 4,150건이 통과했습니다. 실행 ID는 `20261125T183726-1fe6afff04dc`이고 종료 코드는 0입니다.

```text
pytest: 3485 passed, 52 skipped, 3 warnings in 471.10s (0:07:51)
pytest skip: 51 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=12 failed=0
```

단계별 로그와 결과 파일은 `.utmp/ticket-476/20261125T183726-1fe6afff04dc/`에 있습니다. 운영 스위치·복제본 확인은 사용자 단계이며 Docker 복원 U3는 승인된 서버 PR에서 판정합니다.

### 재검수 보완

`read_consent`가 항상 트랜잭션 시작 시각을 돌려주도록 선택 인자와 SQL 분기를 없앴습니다. 동의 기록을 쓰는 `decided_at`은 계속 `clock_timestamp()`를 사용합니다. 기존 소비자와 테스트 대역에 필요한 변경은 저장 경로의 호출 인자 제거 한 곳이었습니다.

PostgreSQL에서 반환 시각을 직접 확인하는 새 검사는 보완 전에 실패하고 보완 뒤 통과했습니다. YouTube·Instagram의 B안 세 순서 6건과 호출자·대역을 포함한 부분 검사 378건이 통과했습니다. 추적된 테스트는 그대로입니다.

2026-11-25 전체 VERIFY 실행 ID는 `20261125T190135-a9767912bcdd`입니다. 12단계가 모두 통과했고, 종료 코드는 0입니다. 모든 단계의 기록에서 `HEAD=c47507151decfa8ded2f3129b312d5a363ec6eff`, `dirty=true`를 확인했습니다. 검증 대상 코드와 커밋 직전 제품 변경의 해시가 일치했으며, 뒤에 이력 문서만 추가했습니다. Flutter 테스트는 4,150건 통과했습니다.

```text
pytest: 3485 passed, 52 skipped, 3 warnings in 469.94s (0:07:49)
pytest skip: 51 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=12 failed=0
```

단계별 로그와 결과 파일은 `.utmp/ticket-476/20261125T190135-a9767912bcdd/`에 있습니다. Docker 복원 U3는 승인된 브랜치의 CI에서 판정합니다.

## 서버 PR 최종 검수 후속

사용자 결정 “감독 추천대로 4건 수정 (추천)”에 따라 `a6ecdf7`에서 네 지적을 고쳤습니다(`4ee44d0`·`a1cb0c5`).

- 앱의 동의 `PUT`은 자기 10초 범위와 함께 호출한 쪽의 요청 범위를 따릅니다. 호출한 쪽이 취소하거나 기한이 지나면 더 보내지 않고 그 이유를 다른 요청처럼 돌려줍니다. 이미 보낸 갱신은 세션이 가져 회전한 토큰을 지킵니다. 수정 전에는 첫 `PUT`의 401 뒤 갱신 중 취소해도 `PUT`을 두 번 보내고 저장 성공을 돌려주는 것을 새 테스트로 먼저 확인했습니다. 취소하지 않은 대조는 그대로 두 번 보내고 성공합니다.
- Railway 복원 절차에서 복원 대상으로 전환하기 전에 AI 전송 동의 복원 정리를 하도록 이었습니다. 동의함과 대기·처리 중 작업이 0건인지, 지원되는 배포에서 API·worker 스위치가 켜졌는지 확인하고, 하나라도 확인하지 못하면 점검을 유지합니다. 동의 기능 이전 서버는 호환 서버로 쓰지 않습니다. 변수 표의 `AI_CONSENT_REQUIRED`는 0.7.1을 iOS·Android 양쪽에서 받을 수 있게 된 날(M4) 켜고 확인 절차를 따르도록 적었습니다.
- Docker 복원 검사(U3)는 동의 행을 계정 키와 함께 비교하고, 복원본에서 두 계정의 동의를 맞바꾸면 다르게 읽히는지도 확인합니다. 같은 읽기 SQL을 로컬 PostgreSQL에 적용하면 이전 비교는 맞바꿈을 구분하지 못하고 새 비교는 구분했습니다. 실제 Docker 검사는 CI에서 판정합니다.
- 기준부터 있던 로그아웃·탈퇴 삭제 경주(시트 162)는 이 후속의 범위 밖입니다.

2026-11-25 커밋 `a1cb0c5`(작업 트리 깨끗함)의 전체 VERIFY 실행 ID는 `20261125T194136-b33f99e38a07`이고 종료 코드는 0입니다. `flutter analyze`가 통과했고 Flutter 테스트는 4,232개 통과했습니다.

```text
pytest: 3485 passed, 52 skipped, 3 warnings in 473.42s (0:07:53)
pytest skip: 51 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
verify ci-only: backend/tests/deployment/test_ai_consent_resume_runbook.py backend/tests/deployment/test_backup_restore_docker.py (로컬 skip, 티켓 종료 전 CI 필요)
VERIFY result=PASS scope=all checks=12 failed=0
```

단계별 로그는 `.utmp/ticket-475/20261125T194136-b33f99e38a07/`에 있습니다. 운영 전환·배포, 기기, 실제 외부 전송은 실행하지 않았습니다.

### 최종 재검수 보완

사용자 결정 “감독 추천대로 수정 (추천)”에 따라 남은 한 건을 고쳤습니다(`a8064d4`). 동의 `PUT`의 내부 요청 범위가 활성 여부를 볼 때마다 호출한 쪽의 활성 여부도 확인합니다. 화면을 떠나 현재가 아니게 됐을 뿐 취소되지 않은 호출자도 갱신 뒤 재전송하지 않고, 첫 응답이 늦게 401로 와도 새 갱신을 시작하지 않습니다. 이미 보낸 갱신의 회전 토큰은 그대로 남습니다.

고치기 전에는 갱신 도중 현재가 아니게 되면 `PUT`을 두 번 보냈고, 첫 응답 전에 바뀌면 늦은 401 뒤 갱신을 보냈습니다. 새 테스트로 두 경우가 실패하는 것을 먼저 확인했습니다. 새 테스트를 처음 쓸 때 기록 비교의 테스트 자체 오류 1가지를 고쳤습니다. 호출자 유지·명시 취소·기한 만료 대조는 그대로 통과합니다.

2026-11-25 커밋 `a8064d4`(작업 트리 깨끗함)의 전체 VERIFY 실행 ID는 `20261125T200417-f3ac5caedd7e`이고 종료 코드는 0입니다. `flutter analyze`가 통과했고 Flutter 테스트는 4,235개 통과했습니다.

```text
pytest: 3485 passed, 52 skipped, 3 warnings in 484.46s (0:08:04)
pytest skip: 51 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
verify ci-only: backend/tests/deployment/test_ai_consent_resume_runbook.py backend/tests/deployment/test_backup_restore_docker.py (로컬 skip, 티켓 종료 전 CI 필요)
VERIFY result=PASS scope=all checks=12 failed=0
```

단계별 로그는 `.utmp/ticket-475/20261125T200417-f3ac5caedd7e/`에 있습니다. Docker 복원 검사는 CI에서 판정합니다.
