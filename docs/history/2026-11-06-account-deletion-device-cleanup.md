# 탈퇴 뒤 기기 정리와 다음 실행 재정리 (#257)

2026-11-06, 시작 커밋 `0f4de21906720f6e0615165d602db00808697008` 기준으로 구현하고 티켓 리뷰 반영과 전체 검증까지 마쳤다.
회원 탈퇴 스펙 #250의 일곱 번째 티켓이며 [#256 탈퇴 화면](2026-11-06-account-deletion-screens.md)의 204 경로에 기기 정리와 재시도(R2)를 더했다.
이 기록은 iOS Simulator·Android Emulator 실행 확인, 네이티브 XCTest·계측 테스트 실행, 배포·운영·실계정 확인 완료를 뜻하지 않는다.

## 구현

- 204를 받으면 `RemoteSessionRepository.clearAfterAccountDeletion`(`frontend/lib/data/repositories/session_repository.dart`)이
  메모리 세션을 먼저 지우고(원본 이미지 캐시 무효화 포함) "정리 대기" 기록을 쓴 뒤 다음 세 가지를 한 번씩 시도한다.
  - 저장된 로그인: 저장 세션 삭제와 Apple 사용자 ID 삭제를 둘 다 시도한다.
  - 이 계정의 검색 기록: `SearchHistoryRepository.clearAccount`가 그 계정의 진행 중 쓰기를 기다린 뒤 키를 지운다.
  - 이 계정의 저장 대기 공유: 네이티브 `discardAccountDrafts`. iOS `ShareStore.discardDrafts(userId:)`, Android `ShareStore.discardAccountDrafts`가
    같은 잠금 안에서 계정 번호가 같은 초안의 이미지를 먼저 지우고, 지운 초안만 상태에서 뺀다. 이미지를 지우지 못한 초안은 남기고 오류를 돌려준다.
    계정 번호 없는 초안은 남긴다.
- 그 뒤 Google 계정이면 `SocialAuth.disconnectGoogle()`을 최대 5초, 소셜 SDK `signOut`을 한 번 시도한다. 이 둘과 원본 이미지 캐시는 기록하지 않는다.
  정리 중 무엇이 실패해도 J06으로 가며 서버에 탈퇴를 다시 요청하지 않는다.
- 정리 대기 기록(`frontend/lib/data/repositories/account_deletion_cleanup.dart`): SharedPreferences에 계정마다
  `clipback.account_deletion_cleanup.v1.<환경>.<계정 번호>` 키 하나로 남은 단계를 둔다. 끝난 단계는 빼고, 다 끝나면 키를 지운다.
- 다음 실행: `AppViewModel.restoreSession`이 저장 세션 복원 바로 앞에서 `resumeAccountDeletionCleanup()`을 부른다. 서버 요청과 화면 표시가 없다.
- 새 로그인 보호: 같은 실행에서 새 세션 저장이 성공하고 그 세션이 저장이 끝난 순간의 현재 세션이면, 남은 "저장된 로그인" 단계를 끝난 것으로 본다.
  기록 읽기가 실패했던 실행에서도 이때 다시 읽는다.
- 읽기 실패는 "기록 없음"이 아니라 "모름"으로 다루어 재정리·덮어쓰기를 하지 않는다. 기록 쓰기 실패는 스펙의 남은 위험(R2 세부 5)대로 삼킨다.
- 테스트 이음새: `ClipbackApp(nativeShare:)` 인자, `test/flutter_test_config.dart`의 SharedPreferences 채널 기본 대역.

## 실제 부분 검사

로그는 `.utmp/ticket-257/` 아래에 있고 첫 줄에 명령이 있다. 모두 앱(`frontend/`)에서 실행했다.

- 루트 앱 위젯 테스트 `frontend/test/account_deletion_cleanup_test.dart`(13개): iOS·Android 대상으로 204 뒤 이 계정의 검색 기록·저장 대기 공유만 지움,
  Google 연결 해제 실패·5초 초과에도 J06(4.9초에는 아직 아님), 저장 세션·Apple 사용자 ID·검색 기록·저장 대기 공유 삭제를 각각 실패시켜도 J06·실패 안내 없음·
  탈퇴 재요청 없음과 루트 앱을 다시 띄웠을 때 서버 요청 없이 남은 정리 후 로그인 화면, 503이면 세션·검색 기록·공유 그대로를 본다.
  저장 대기 공유는 공유 채널 대역으로 호출 계정 번호와 결과를 확인한다(실제 네이티브 저장소 아님).
- 정리 기록·세션 저장소 테스트 `frontend/test/data/account_deletion_cleanup_test.dart`(14개): 기록 먼저 쓰기, 실패 단계만 남기기, 한 번만 하는 정리는 기록하지 않음,
  기록 쓰기·읽기 실패, 계정별 기록, 새 로그인 보호와 리뷰 P1·P2 순서.
- 그 밖에 `social_auth_test.dart`(Google 연결 해제 1개), `search_history_repository_test.dart`(진행 중 쓰기 기다린 뒤 삭제 1개)를 더했다.
- 변형 실험 15종(재정리를 복원 뒤로·재정리 없음·공유/검색 기록 연결 없음·첫 실패에서 멈춤·5초 제한 없음·연결 해제 없음·503에도 정리·새 로그인 보호 없음·
  세션 실패 뒤 Apple ID 건너뜀·기록을 정리 뒤에 씀·다른 계정 번호로 공유 삭제·검색 기록 쓰기 안 기다림·현재 세션 아닌 저장도 새 로그인으로 봄·읽기 실패를 빈 기록으로 캐시)이
  모두 실패로 잡혔고 매번 파일은 원본과 같게 되돌렸다(`mutation.log`, `mutation-review.log`, `mutation-review-p1.log`).
- 네이티브(기기 없이): iOS 실제 `ShareStore.swift`를 macOS로 컴파일한 실행 검사(`native/ios/main.swift`)에서 이미지를 지울 수 없게 하면 호출이 실패하고 초안이 남으며
  재호출로 모두 지워짐(수정 전 `red-review-s1-ios.log` 실패 → 수정 뒤 `green-review-s1-ios.log` 통과). `ShareStoreTests.swift`의 시뮬레이터 SDK 타입 검사와
  Android 공유 Java·`ShareStoreTest.java` 컴파일(`xctest-typecheck.log`, `java-compile-review.log`). XCTest·계측 테스트 실행은 아니다.
- 기존 테스트 변경: 새 인터페이스 메서드에 맞춘 대역 연결(`social_auth_test.dart`의 가짜 SDK, 검색 기록 메모리 저장소 3곳)뿐이고 기존 단언은 바꾸지 않았다.
  공용 `test/flutter_test_config.dart`에 바인딩이 있는 테스트마다 빈 메모리 SharedPreferences 채널 대역을 두었다. 앱 시작이 정리 기록을 읽게 되면서 대역 없는 채널이
  가짜 시간에서 답하지 않아 기존 루트 앱 테스트가 시작 화면에서 멈췄기 때문이다. 각 테스트가 건 대역이 우선한다.

## 티켓 리뷰

2026-11-06 티켓 리뷰 `.utmp/review-257.md`(대상 `0f4de21...82bc8ba`): Standards 중간 1건, Spec 중간 2건. 모두 반영했다(커밋 `8a2fdd6`).

- S1: 새 계정별 공유 삭제가 이미지 삭제 실패를 성공으로 돌려주고 초안 정보를 먼저 지워 다음 실행에 다시 지울 수 없었다(리뷰어가 macOS 컴파일 실행으로 재현).
  반영: 양 플랫폼에서 이미지를 먼저 지우고 지운 초안만 상태에서 빼며, 지우지 못한 초안은 남긴 채 오류를 돌려준다. 앱은 공유 단계를 남겨 다음 실행 때 다시 한다.
  기존 `discard`·`complete`·만료 정리의 같은 삼킴은 범위 밖으로 남겼다.
- P1: 탈퇴 전에 시작된 옛 세션 저장이 204 뒤 늦게 끝나면 새 로그인으로 취급되어 저장된 로그인 재정리가 지워졌다.
  반영: 저장이 끝난 세션이 그 순간의 현재 세션일 때만 새 로그인으로 본다. 진입점은 발급·갱신 뒤 저장과 저장 재시도 둘이며 모두 같은 함수를 지난다.
- P2: 기록 읽기 실패를 빈 기록으로 캐시해, 같은 실행의 새 로그인이 옛 기록을 지우지 못하고 다음 실행에 새 로그인이 지워졌다. 탈퇴 때 읽지 못한 기존 기록을 덮어쓰기도 했다.
  반영: 기록을 계정마다 키 하나로 나누고 읽기 실패는 "모름"으로 두어 재정리·덮어쓰기를 하지 않으며 새 로그인 저장 때 다시 읽는다. 손상 값은 이전처럼 무시한다.

## 전체 검증

검증 기준 코드 커밋은 `8a2fdd634011600622879763c0dd3d84912e3d7c`이다.
busy 대기 뒤 20:33 KST 작업 트리 루트에서 다음 명령을 셸 제한 600초로 한 번 실행했고 종료 코드 0을 확인했다.
실행 기록(`verify-progress.json`)의 커밋은 `8a2fdd6`, 작업 트리는 깨끗했다.

```sh
~/.heoturu-agents/busy.sh && python3 ~/.heoturu-agents/verify.py --log-dir .utmp/ticket-257
```

- 서버 ruff·compileall, 일반·maintenance 테스트 DB 각각의 `alembic upgrade head`·`alembic check`, 전체 pytest 통과.
  `backend-pytest.log`의 마지막 요약: `2207 passed, 47 skipped, 3 warnings in 206.02s (0:03:26)`. 서버를 바꾸지 않아 #256 전체 검증과 같은 수다.
- 앱 pub-get·format·analyze·전체 test 통과. `app-test.log`의 마지막 결과: `02:30 +3013: All tests passed!`.
  #256 때(+2984)보다 29개 많고 이번에 더한 테스트 수(루트 13 + 정리 기록 14 + 소셜 1 + 검색 기록 1)와 같다.
- 결과 원문은 `.utmp/ticket-257/20261106T203343-d798a4b05360/verify-result.txt`, 단계별 원본은 같은 폴더다.
  콘솔 마지막 줄(`.utmp/ticket-257/verify-console.log`)과 결과 파일의 VERIFY 줄이 같음을 대조했다.

```text
pytest skip: 46 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=11 failed=0 logs=/Users/leehyeongyu/orca/workspaces/Clipback/account-deletion/.utmp/ticket-257/20261106T203343-d798a4b05360
```

skip은 Docker 검사 46건과 로컬 합성 S3 CLI 검사 1건이며 DB 대상 테스트의 skip은 없다. skip은 통과 수에 넣지 않는다.
실행 확인 진입 파일의 빌드 전 확인(`.utmp/ticket-257/state_preview_cleanup_check_test.dart`, 4개 통과, `check-cleanup-review.log`)은 저장소 밖 파일이라
이 전체 검증에 들어 있지 않다. 이 결과를 기록하는 후속 커밋은 문서만 바꾸며 검증 기준 코드와 같다.

## 미검증

- iOS Simulator·Android Emulator 실행 확인(`cleanup-done`, `cleanup-retry`)은 하지 않았다(감독 단계). 진입 파일·제어·순서는 `.utmp/ticket-257-capture.md`에 있다.
- 네이티브 XCTest(`ShareStoreTests`의 계정별 삭제 2개)와 Android 계측(`ShareStoreTest`의 계정별 삭제 2개)은 기기가 필요해 실행하지 않았다.
  iOS 시뮬레이터에서 `chflags`로 삭제 실패를 만드는 방식이 앱 컨테이너에서 동작하는지도 그때 확인한다.
- 저장 대기 공유를 실제 공유 확장으로 만들어 지우는 확인은 이슈대로 미검증 예정이다(자동 테스트로만 확인).
- Google 연결 해제·Apple·카카오 SDK 정리는 가짜 SDK로만 확인했다. 실계정·실기기 확인은 #250 완료 조건 3의 사람 확인이다.
- CI deployment·operator-recovery Docker 작업은 로컬에서 실행하지 않았다. 앱만 바꿔 영향이 없을 것으로 보지만 CI 결과로 확인해야 한다.
