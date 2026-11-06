# 탈퇴 뒤 기기 정리와 다음 실행 재정리 (#257)

2026-11-06, 시작 커밋 `0f4de21906720f6e0615165d602db00808697008` 기준으로 구현하고 티켓 리뷰·재리뷰 반영과 전체 검증까지 마쳤다.
회원 탈퇴 스펙 #250의 일곱 번째 티켓이며 [#256 탈퇴 화면](2026-11-06-account-deletion-screens.md)의 204 경로에 기기 정리와 재시도(R2)를 더했다.
코드 커밋은 `82bc8ba`(구현) → `8a2fdd6`(리뷰 반영) → `34c9f8e`(재리뷰 반영) → `5aa47e4`(소유권 설계) → `7c2d9e0`(SDK 정리 분리) → `6445858`(재리뷰 D1)이고,
`431f0ee`와 이 기록을 고친 커밋은 문서만 바꾼다. 마지막 전체 검증의 기준 코드는 `6445858`이다.
이 기록은 iOS Simulator·Android Emulator 실행 확인, 네이티브 XCTest·계측 테스트 실행, 배포·운영·실계정 확인 완료를 뜻하지 않는다.

## 구현

최종 코드(`6445858`) 기준이다.

- 204를 받으면 `RemoteSessionRepository.clearAfterAccountDeletion`(`frontend/lib/data/repositories/session_repository.dart`)이
  메모리 세션을 먼저 지우고(원본 이미지 캐시 무효화 포함) "정리 대기" 기록을 쓴 뒤 다음 세 가지를 한 번씩 시도한다.
  - 저장된 로그인: 저장 세션과 Apple 사용자 ID. 아래 소유권 판정을 통과할 때만 지우며, 지울 때는 둘 다 시도한다.
  - 이 계정의 검색 기록: `SearchHistoryRepository.clearAccount`가 그 계정의 진행 중 쓰기를 기다린 뒤 키를 지운다.
  - 이 계정의 저장 대기 공유: 네이티브 `discardAccountDrafts`. iOS `ShareStore.discardDrafts(userId:)`, Android `ShareStore.discardAccountDrafts`가
    같은 잠금 안에서 계정 번호가 같은 초안의 이미지를 먼저 지우고, 지운 초안만 상태에서 뺀다. 이미지를 지우지 못한 초안은 남기고 오류를 돌려준다.
    계정 번호 없는 초안은 남긴다.
- 그 뒤 Google 계정이면 `SocialAuth.disconnectGoogle()`을 최대 5초, 소셜 SDK 로컬 정리 `SocialAuth.signOutSdks`(Google `signOut`·카카오 토큰 정리)를
  한 번 시도한다. 이 둘과 원본 이미지 캐시는 기록하지 않는다. `signOutSdks`는 저장된 Apple 사용자 ID를 지우지 않는다(일반 로그아웃의 `signOut`은 그대로
  SDK 정리와 Apple 사용자 ID 삭제를 함께 한다). 정리 중 무엇이 실패해도 J06으로 가며 서버에 탈퇴를 다시 요청하지 않는다.
- 정리 대기 기록(`frontend/lib/data/repositories/account_deletion_cleanup.dart`): SharedPreferences에 계정마다
  `clipback.account_deletion_cleanup.v1.<환경>.<계정 번호>` 키 하나로 `environment`·`user_id`·남은 단계 `remaining`·탈퇴 순간 기기에 있을 수 있던 세션의
  지문 목록 `logins`(갱신 토큰 SHA-256 소문자 hex)·그 목록이 빠짐없는지 `logins_complete`를 둔다. 끝난 단계는 빼고, 다 끝나면 키를 지운다.
  읽을 때 목록이 없거나 목록이 아니거나 지문 형식이 아닌 값이 섞이면 빠짐없지 않은 목록으로 읽고 형식이 맞는 지문만 남긴다. 기록 형식은 이 브랜치에서 처음 생긴
  배포 전 형식이다.
- 저장된 로그인 소유권 판정:
  - 지문 목록은 204 순간의 읽기 한 번이 아니라 그 실행의 장부로 만든다. 장부는 저장소가 저장 세션에서 읽은 값과 저장하려 한 모든 세션(성공 여부와 무관)의
    지문이고, 쓰기·삭제를 시도하기 전의 읽기가 성공했을 때만 빠짐없다고 본다. 저장·삭제가 실패한 뒤의 읽기는 기기가 아니라 SharedPreferences 캐시를
    보여 주기 때문이다. 탈퇴 순간의 지문 목록 = 장부 + 메모리 세션 + (탈퇴 뒤 쓰기가 시작되지 않았을 때만) 204 순간 읽기 값.
  - 정리 단계는 매번 저장 세션을 읽는다. 읽지 못하면 저장 세션·Apple 사용자 ID를 모두 두고 단계를 실패로 남긴다. 저장 세션이 없으면 Apple 사용자 ID만,
    지문이 목록에 있거나 탈퇴한 그 실행에서 아직 아무것도 저장·삭제하지 않았으면 둘 다 지운다. 목록이 빠짐없는데 지문이 없으면 새 로그인(같은 소셜 계정으로
    다시 가입한 새 계정 포함)으로 보아 둘 다 두고 단계를 끝낸다. 목록이 빠짐없지 않은데 지문이 없으면 지우지도 끝내지도 않는다.
  - 앱은 시작 때 저장 세션을 읽어야 로그인할 수 있으므로(실패하면 "다시 시도" 화면) 앱 흐름의 목록은 늘 빠짐없다. 새 로그인을 저장할 때 기록을 고치지 않는다.
- 다음 실행: `AppViewModel.restoreSession`이 저장 세션 복원 바로 앞에서 `resumeAccountDeletionCleanup()`을 부른다. 서버 요청과 화면 표시가 없다.
  재정리가 실패해도 복원은 그대로 한다.
- 기록 읽기 실패는 "기록 없음"이 아니라 "모름"으로 다루어 재정리·덮어쓰기를 하지 않는다. 기록 쓰기 실패는 스펙의 남은 위험(R2 세부 5)대로 삼킨다.
- 테스트 이음새: `ClipbackApp(nativeShare:)` 인자, `test/flutter_test_config.dart`의 SharedPreferences 채널 기본 대역.

## 소유권 설계 결정과 경위

- `34c9f8e` 재리뷰에서 세션 읽기 실패에 새 로그인을 지우는 결함(P1)과 204 순간 지문 읽기 실패 뒤 옛 토큰을 새 로그인으로 보는 결함(P2)이 나와,
  감독이 반복 결함으로 자동 수정을 멈추고 결정을 올렸다.
- 사용자 결정(2026-11-06) 원문: "A로 진행해줘". 승인된 A 원문: "같은 작업자가 먼저 설계 문서를 쓴다. 읽기가 실패하면 아무것도 지우지 않고 실패로 남기는 것을
  원칙으로, 옛 정보와 새 로그인을 확실히 가를 근거를 정한다. 저장 형식·Apple ID·기존 사용자 데이터 호환에 영향이 있으면 구현 전에 멈춰 확인받는다.
  그다음 자동 루프를 이어 간다. 작업자는 Claude Opus 5.5 · xhigh."
- 설계 문서는 작업 파일 `.utmp/ticket-257/ownership-design.md`(불변 조건, 상태 전이, P1·P2 차단 표, R2 세부 1–5 대응, 호환 영향 표, 선택지)다.
  설계 중 읽기 실패 없이도 쓰기·삭제 실패만으로 캐시 때문에 옛 토큰이 다음 실행에 복원되는 경로(P2′)를 실제 `ApiSessionStorage`와 채널 대역으로
  재현했고(`design-probe-head.log`) 같은 장부 설계로 막았다(`5aa47e4`).
- 호환 근거와 검증 경계: `ApiSessionStorage`·`rememberAppleUserId`를 배포 태그 `app-ios-v0.4.0-b9`·`app-ios-v0.4.1-b10`(Android 태그 같은 커밋)과 코드 비교해
  세션 저장 형식·Apple 사용자 ID 저장이 같고, 두 태그에 정리 대기 기록 코드가 없음을 확인했다. 재리뷰도 네 태그를 따로 비교해 0.4.0/0.4.1 저장 데이터 호환을
  바꾸는 변경을 찾지 못했다. 설치된 앱을 실제로 올려 보는 확인은 하지 않았다. 감독은 배포 전 기록에 `logins_complete`를 더하는 것은 구현 전 확인 경계
  (세션 저장 형식·Apple ID 소유권 기록·설치된 0.4.0/0.4.1 데이터 호환)를 넘지 않는다고 판정했다.
- SDK Apple 예외 철회: `5aa47e4`의 설계는 탈퇴 뒤 `PlatformSocialAuth.signOut`이 저장된 Apple 사용자 ID를 한 번 지우는 것을 한 번만 하는 SDK 정리로 보아
  읽기 실패 원칙의 예외로 두었다. 감독이 사용자 원문에 그런 예외 승인이 없고 인증 작업 중 로그인 차단도 예외 근거가 아니라고 판단해, `7c2d9e0`에서
  탈퇴 경로만 `signOutSdks`를 부르게 나누고 저장된 Apple 사용자 ID는 소유권 판정을 통과한 저장된 로그인 단계만 지우게 했다.
- 재리뷰 D1(`6445858`): 새 `logins_complete` 필드를 목록 검증 없이 믿어, 손상된 목록(누락·null·숫자·혼합 배열)에 true가 남으면 지문 없는 저장 세션을
  새 로그인으로 보고 단계를 끝냈다(리뷰어 재현 3개 실패). 소유권 설계는 바꾸지 않고 파서의 완전성 판정만 고쳤다. 실제 기록 형식(SHA-256 소문자 hex 64자)이
  아닌 문자열도 손상으로 본다. 잘린 지문 문자열에 true가 남는 경우도 같은 결함이기 때문이다.

## 실제 부분 검사

로그는 `.utmp/ticket-257/` 아래에 있고 첫 줄에 명령이 있다. 모두 앱(`frontend/`)에서 실행했다.

- 루트 앱 위젯 테스트 `frontend/test/account_deletion_cleanup_test.dart`(15개): iOS·Android 대상으로 204 뒤 이 계정의 검색 기록·저장 대기 공유만 지움,
  Google 연결 해제 실패·5초 초과에도 J06(4.9초에는 아직 아님), 저장 세션·Apple 사용자 ID·검색 기록·저장 대기 공유 삭제를 각각 실패시켜도 J06·실패 안내 없음·
  탈퇴 재요청 없음과 루트 앱을 다시 띄웠을 때 서버 요청 없이 남은 정리 후 로그인 화면, 정리 중 J04가 작업 중으로 남음, 503이면 세션·검색 기록·공유 그대로를 본다.
  실제 `PlatformSocialAuth`(가짜 SDK, 실제 preferences의 Apple 사용자 ID 키)로 탈퇴 직전부터 세션 읽기를 실패시키면 J06·세션과 Apple 사용자 ID 유지·
  카카오 정리 한 번·기록 잔류 뒤 다음 실행에서 둘 다 지워짐도 본다. 저장 대기 공유는 공유 채널 대역으로 호출 계정 번호와 결과를 확인한다(실제 네이티브 저장소 아님).
- 정리 기록·세션 저장소 테스트 `frontend/test/data/account_deletion_cleanup_test.dart`(31개): 기록 먼저 쓰기, 실패 단계만 남기기, 한 번만 하는 정리는 기록하지 않음,
  기록 쓰기·읽기 실패, 계정별 기록, 옛 저장 완료·진행 중 저장·새 로그인 순서, 세션 읽기 실패 무삭제(P1), 204 읽기 실패 뒤 옛 토큰 정리(P2), 두 읽기가 모두
  실패해도 다음 실행이 디스크의 옛 토큰을 지움, 불완전 목록의 판정 보류, 204 읽기를 앞지른 새 저장, `logins_complete` 파싱과 손상 목록(D1) 13가지 입력,
  다음 실행·다른 기록 순회에서 손상 목록의 저장된 로그인 단계 잔류.
- 실제 저장소 테스트 `frontend/test/data/account_deletion_device_storage_test.dart`(3개, 새 파일): 실제 `ApiSessionStorage`와 SharedPreferences 채널 대역에서
  저장 실패한 갱신 토큰·저장했던 중간 토큰이 있어도 다음 실행에 디스크의 토큰을 지우고 복원하지 않음(P2′), 시작 읽기 없이 저장 실패 뒤의 읽기는 목록을
  빠짐없게 만들지 않음. 기존 data 파일은 `setMockInitialValues`가 플랫폼 저장소를 바꿔 채널 대역이 먹지 않아 따로 두었다.
- 그 밖에 `social_auth_test.dart`(Google 연결 해제 1개, `signOutSdks`가 Apple 사용자 ID를 남김 1개), `search_history_repository_test.dart`(진행 중 쓰기 기다린 뒤 삭제 1개).
- 실패 재현을 먼저 남긴 로그: `red-review-p1-p2.log`(리뷰 반영 전 3개), `red-followup.log`(재리뷰 반영 전 2개), `red-ownership.log`(`34c9f8e` 제품 코드에서 새 6개),
  `red-signout-apple.log`(`5aa47e4`에서 Apple 사용자 ID 단언), `red-d1.log`(`7c2d9e0`에서 새 7개). 리뷰어 원본 재현은 `green-review-repro.log`(소유권 P1·P2),
  `partial-d1.log`(D1 원본 3개 그대로 실행)에서 통과했다.
- 변형 실험: 첫 구현·리뷰 반영 15종(`mutation.log`, `mutation-review.log`, `mutation-review-p1.log`), 재리뷰 반영 16종(`mutation-followup.log`),
  소유권 설계 24종(`mutation-ownership.log`·`mutation-signout-apple.log`·`mutation-d1.log`: 읽기 실패에 삭제, 장부의 읽기·저장 시도 누락, 204 읽기만 사용,
  앞지른 읽기 포함, 불완전 목록을 새 로그인으로 끝냄, 쓰기 뒤 읽기로 완전 표시, 같은 실행 판정 변형, 새 로그인에 Apple 사용자 ID 삭제, 탈퇴가 `signOut` 사용,
  SDK 정리가 Apple 사용자 ID 삭제, 로그아웃 동작 변형, 파서가 손상 목록을 믿음 등)이 모두 실패로 잡혔고 매번 파일은 원본과 같게 되돌렸다.
  `complete-after-writes`는 처음에 잡히지 않아 실제 저장소 테스트를 더한 뒤 잡혔다.
- 네이티브(기기 없이): iOS 실제 `ShareStore.swift`를 macOS로 컴파일한 실행 검사(`native/ios/main.swift`)에서 이미지를 지울 수 없게 하면 호출이 실패하고 초안이 남으며
  재호출로 모두 지워짐(수정 전 `red-review-s1-ios.log` 실패 → 수정 뒤 `green-review-s1-ios.log` 통과). `ShareStoreTests.swift`의 시뮬레이터 SDK 타입 검사와
  Android 공유 Java·`ShareStoreTest.java` 컴파일(`xctest-typecheck.log`, `java-compile-review.log`). XCTest·계측 테스트 실행은 아니다. 네이티브 코드는 `8a2fdd6` 뒤로 바꾸지 않았다.
- 기존 테스트 변경: #257 이전 테스트는 새 인터페이스 메서드에 맞춘 대역 연결(`social_auth_test.dart`의 가짜 SDK, 검색 기록 메모리 저장소 3곳)만 바꾸고 기존 단언은
  바꾸지 않았다. 공용 `test/flutter_test_config.dart`에 바인딩이 있는 테스트마다 빈 메모리 SharedPreferences 채널 대역을 두었다. 앱 시작이 정리 기록을 읽게 되면서
  대역 없는 채널이 가짜 시간에서 답하지 않아 기존 루트 앱 테스트가 시작 화면에서 멈췄기 때문이다. 각 테스트가 건 대역이 우선한다.
  #257에서 만든 테스트는 기록 형식 변경에 맞춰 기대값(`logins`·`logins_complete`)과 fixture 연결을 바꾸었고, 짧은 가짜 지문은 실제 형식 지문으로 바꾸었다.
- 실행 확인 진입 파일의 빌드 전 확인(`.utmp/ticket-257/state_preview_cleanup_check_test.dart`, 4개)은 매 단계 통과했다(`partial-d1.log`). 저장소 밖 파일이라 전체 검증에 들어 있지 않다.

## 티켓 리뷰

2026-11-06 티켓 리뷰 `.utmp/review-257.md`(대상 `0f4de21...82bc8ba`): Standards 중간 1건, Spec 중간 2건. 모두 반영했다(커밋 `8a2fdd6`).

- S1: 새 계정별 공유 삭제가 이미지 삭제 실패를 성공으로 돌려주고 초안 정보를 먼저 지워 다음 실행에 다시 지울 수 없었다(리뷰어가 macOS 컴파일 실행으로 재현).
  반영: 양 플랫폼에서 이미지를 먼저 지우고 지운 초안만 상태에서 빼며, 지우지 못한 초안은 남긴 채 오류를 돌려준다. 앱은 공유 단계를 남겨 다음 실행 때 다시 한다.
  기존 `discard`·`complete`·만료 정리의 같은 삼킴은 범위 밖으로 남겼다.
- P1: 탈퇴 전에 시작된 옛 세션 저장이 204 뒤 늦게 끝나면 새 로그인으로 취급되어 저장된 로그인 재정리가 지워졌다.
  당시 반영: 저장이 끝난 세션이 그 순간의 현재 세션일 때만 새 로그인으로 본다(`storedLoginReplaced`). 이 방식은 아래 재리뷰 1에서 세션 지문 판정으로 바뀌었다.
- P2: 기록 읽기 실패를 빈 기록으로 캐시해, 같은 실행의 새 로그인이 옛 기록을 지우지 못하고 다음 실행에 새 로그인이 지워졌다. 탈퇴 때 읽지 못한 기존 기록을 덮어쓰기도 했다.
  반영: 기록을 계정마다 키 하나로 나누고 읽기 실패는 "모름"으로 두어 재정리·덮어쓰기를 하지 않는다. 새 로그인 저장 때 다시 읽던 방식은 재리뷰 1에서 없앴다.

재리뷰 1 `.utmp/review-257-followup.md`(대상 `82bc8ba..431f0ee`, Spec 중간 1건·확신 낮은 후보 1건, 커밋 `34c9f8e`): 시작과 새 로그인 때 기록 읽기가 모두 실패하면
다음 실행이 새 로그인을 지웠다. 기록에 탈퇴한 계정 세션의 지문을 남기고 정리 단계가 디스크 세션을 지문과 비교하게 바꿔 새 로그인 때 기록을 고치던 경로를 없앴다.
확신 낮은 후보(정리 중 새 로그인)는 앱의 인증 작업 가드로 막히는 것을 경계 테스트로 확인했다.

재리뷰 2 `.utmp/review-257-ownership.md`(대상 `431f0ee..34c9f8e`, Spec 중간 2건): 위 "소유권 설계 결정과 경위"의 P1·P2. 반영 커밋 `5aa47e4`, 감독 판단 반영 `7c2d9e0`.

재리뷰 3 `.utmp/review-257-design.md`(대상 `34c9f8e..7c2d9e0`, Spec 중간 1건 D1): 이전 P1·P2·P2′ 재현 23개 통과, 네 배포 태그 대비 저장 호환 변경 없음을 확인했고
손상 목록 D1을 지적했다. 반영 커밋 `6445858`.

## 전체 검증

검증 기준 코드 커밋은 `6445858cdbaf8c81e73ee9a190d7d13d6386a855`이다.
busy 대기 뒤 22:03 KST 작업 트리 루트에서 다음 명령을 셸 제한 600초로 한 번 실행했고 종료 코드 0을 확인했다.
실행 기록(`verify-progress.json`)의 24개 이벤트 모두 커밋 `6445858`, 작업 트리 깨끗함이다.

```sh
~/.heoturu-agents/busy.sh && python3 ~/.heoturu-agents/verify.py --log-dir .utmp/ticket-257
```

- 서버 ruff·compileall, 일반·maintenance 테스트 DB 각각의 `alembic upgrade head`·`alembic check`, 전체 pytest 통과.
  `backend-pytest.log`의 마지막 요약: `2207 passed, 47 skipped, 3 warnings in 203.71s (0:03:23)`. 서버를 바꾸지 않아 이전 전체 검증과 같은 수다.
- 앱 pub-get·format·analyze·전체 test 통과. `app-test.log`의 마지막 결과: `02:41 +3036: All tests passed!`.
  #256 때(+2984)보다 52개 많고 이번에 더한 테스트 수(루트 15 + 정리 기록 31 + 실제 저장소 3 + 소셜 2 + 검색 기록 1)와 같다.
- 결과 원문은 `.utmp/ticket-257/20261106T220320-703bd6928c07/verify-result.txt`, 단계별 원본은 같은 폴더다.
  콘솔 마지막 줄(`.utmp/ticket-257/verify-console-d1.log`), 상위 `verify-result.txt`, 결과 파일의 VERIFY 줄이 같음을 대조했다.

```text
pytest skip: 46 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=11 failed=0 logs=/Users/leehyeongyu/orca/workspaces/Clipback/account-deletion/.utmp/ticket-257/20261106T220320-703bd6928c07
```

skip은 Docker 검사 46건과 로컬 합성 S3 CLI 검사 1건이며 DB 대상 테스트의 skip은 없다. skip은 통과 수에 넣지 않는다.
이 결과를 기록하는 후속 커밋은 문서만 바꾸며 검증 기준 코드와 같다.

### 이전 전체 검증(구 설계)

`8a2fdd634011600622879763c0dd3d84912e3d7c`(구 설계: `storedLoginReplaced`)에서 20:33 KST에 같은 명령으로
`VERIFY result=PASS scope=all checks=11 failed=0 logs=/Users/leehyeongyu/orca/workspaces/Clipback/account-deletion/.utmp/ticket-257/20261106T203343-d798a4b05360`,
pytest `2207 passed, 47 skipped, 3 warnings in 206.02s (0:03:26)`, 앱 `02:30 +3013: All tests passed!`(skip 줄은 위와 같음)였다.
이 결과는 `8a2fdd6`의 것이며 그 뒤 코드의 근거가 아니다. `34c9f8e`·`5aa47e4`·`7c2d9e0`은 각자 전체 검증을 하지 않았고 부분 검사만 했다.
`431f0ee`의 CI(앱 42212193936, 서버 42212197779)는 성공했으나 그 뒤 코드의 결과가 아니다.

## 미검증

- iOS Simulator·Android Emulator 실행 확인(`cleanup-done`, `cleanup-retry`)은 하지 않았다(감독 단계). 진입 파일·제어·순서는 `.utmp/ticket-257-capture.md`에 있다.
- 네이티브 XCTest(`ShareStoreTests`의 계정별 삭제 2개)와 Android 계측(`ShareStoreTest`의 계정별 삭제 2개)은 기기가 필요해 실행하지 않았다.
  iOS 시뮬레이터에서 `chflags`로 삭제 실패를 만드는 방식이 앱 컨테이너에서 동작하는지도 그때 확인한다.
- 저장 대기 공유를 실제 공유 확장으로 만들어 지우는 확인은 이슈대로 미검증 예정이다(자동 테스트로만 확인).
- Google 연결 해제·Apple·카카오 SDK 정리는 가짜 SDK로만 확인했다. 실계정·실기기 확인은 #250 완료 조건 3의 사람 확인이다.
- 설치된 0.4.0/0.4.1 앱을 올려 보는 확인은 하지 않았다. 호환 판단은 태그와의 코드 비교에 기댄다.
- 실제 기기의 SharedPreferences 쓰기·삭제 실패와 읽기 실패는 채널·저장소 대역으로만 만들었다.
- `6445858`의 CI와 CI deployment·operator-recovery Docker 작업은 실행하지 않았다. 앱만 바꿔 영향이 없을 것으로 보지만 CI 결과로 확인해야 한다.
