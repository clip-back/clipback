# 오늘의 추천 열기 상태를 DetailViewModel로 옮기기 (#301, #303, #304)

2026-11-08, 상위 스펙 #301의 두 티켓을 브랜치 `refactor/app-root-today-visit`에서 진행했다.
#303은 앱 코드를 바꾸기 전에 동작 고정 테스트를 추가했고(커밋 `5d66ce0`), #304는 앱 루트 View가 들고 있던 **오늘의 추천 열기**의 시도와 진행 중 요청을 `DetailViewModel`로 옮겼다(커밋 `3d61590`).
그보다 먼저 용어집에 **오늘의 추천 열기**를 더했다(커밋 `c26a068`, 회의 Q6).
감독이 main `ef9f6a8`(#298 링크 저장 재시도 수정)을 충돌 없이 병합해 `222a5d6`을 만들었다. 최종 리뷰·전체 검증·기기 실행의 기준 코드는 `222a5d6`이다. 이 이력을 더한 커밋은 문서만 바꾼다.
사용자에게 보이는 동작은 바뀌지 않으므로 CHANGELOG `미배포`에는 적지 않았다.

## 사용자 결정

- 2026-11-08 기획 회의 Q1–Q11 "추천대로": 범위는 오늘의 추천 열기 하나다. 새 파일·새 ViewModel 없이 기존 `DetailViewModel`에 두고(Q2), 입구는 `todayAction(isCurrent:, onOpened:)`와 `invalidateToday()`다(Q7). `ApiRequestScope`는 씌우지 않는다(Q3).
  계정 세대·`authEpoch`는 앱 View가 `AppViewModel` 값으로 붙잡아 `isCurrent` 안에서 비교한다. ViewModel만 따로 검사하는 단위 테스트는 두지 않는다(Q8). README는 한 문장만 고치고(Q9), ADR은 없다.
- 같은 날 스펙 리뷰 R1·R2 승인: T6(최종 인증 무효화 뒤 늦은 응답)는 고정 행으로 두고 `authEpoch` 비교만 빼는 변형은 참고 변형으로 낮췄다. 판정 순서는 stage 0 → 빈 목록 → 첫 콘텐츠 읽기다.
- 고정 테스트 `today_open_behavior_test`와 기존 회귀 파일 5개(`today_root_test`, `data/today_repository_test`, `system_back_policy_test`, `weekly_root_test`, `weekly_visit_behavior_test`)는 #304에서 고치지 않는다(예외 없음).
- 화면 변화가 없어 변경 전·후·Figma 3면 비교와 영상은 하지 않는다(Q5). iOS Simulator와 Android Emulator에서 홈 Today 버튼 → 상세 `1 / N` → 다음 콘텐츠 → 뒤로 → 홈을 1회씩 확인하고 스크린샷을 남긴다.

## 구현 (#304)

- `frontend/lib/features/content/view_models/detail_view_model.dart`:
  - private 필드 `_todayAttempt`(처음부터 객체)·`_todayRequest`(처음엔 없음)를 더했다.
  - `todayAction`은 부를 때의 시도를 붙잡은 콜백을 돌려준다. 만드는 일은 상태를 바꾸지 않고 알림도 내지 않는다.
  - 콜백은 dispose → 붙잡은 시도 → `isCurrent()` → 진행 중 요청 순서로 막는다. 통과하면 새 토큰을 진행 중 요청으로 두고 목록·첫 콘텐츠 처리를 부른다. 이 처리와 `onOpened` 앞에서는 "붙잡은 시도 그대로 + `isCurrent()` 참 + 토큰이 아직 진행 중 요청"을 다시 본다. 끝나면 자기 토큰일 때만 비운다.
  - `invalidateToday`는 시도를 새 객체로 바꾸고 진행 중 요청을 비운다. 알림을 내지 않고 첫 콘텐츠 읽기 토큰·Today 상세 문맥·`moving`은 건드리지 않는다.
  - `openToday`를 `_openToday`로 바꿨다. 본문(목록 GET, stage 0 → 빈 목록 → 첫 콘텐츠 읽기 순서, 안내 문구)은 그대로다. dispose 때 진행 중 요청을 비운다.
  - `VoidCallback`은 `package:flutter/foundation.dart' show VoidCallback`으로 가져왔다. `show` 없이 가져오면 기존 `dart:typed_data` import가 불필요 경고로 바뀌기 때문이다.
- `frontend/lib/app/clipback_app.dart`: `_todayVisit`·`_todayRequest`를 지웠다(가변 필드 23 → 21).
  - 관찰자 콜백은 `invalidateToday()` → `cancelTodayNavigation()` → `if (mounted) setState(() {})`다. `_onChanged`의 두 줄은 `invalidateToday()` 한 줄이 되었다.
  - `_todayAction`은 계정 세대·`authEpoch`를 붙잡은 `isCurrent`와 `onOpened: _d.app.openDetail`을 넘긴다.
  - `didPush`·`didPop` 조건, `cancelTodayNavigation` 줄, `_openDetail`의 Today 상세 분기는 그대로다.
- `frontend/README.md`: "추천 상세 흐름은 …" 줄의 주간 추천 방문 문장 뒤에 지정된 한 문장을 더했다.
- 제거 검색: 앱 View의 시도·진행 중 요청과 목록 처리 직접 호출 검색은 0줄(`5d66ce0`에서는 14줄)이다. `.openToday(` 밖 호출 검색은 0줄(같은 기준 1줄)이고, 상세 ViewModel의 의존 방향 검색도 0줄이다.
- 새 예약 작업, 비동기 dispose, 새 취소 방식은 더하지 않았다. 아래 "앱 제거 뒤 늦은 응답" 제외 근거의 전제다.
- 바꾸지 않음: `ContentRepository`의 Today 인터페이스·구현, API 클라이언트, 서버, `AppDependencies`, `HomeScreen`의 `onOpenToday` 인자와 빈 상태 버튼, Today 상세 이동·문맥·첫 콘텐츠 읽기 토큰·`cancelTodayNavigation`, 주간 추천 방문, 화면 위젯 트리·문구·`ValueKey`, GLOSSARY·ADR.

## 고정 테스트 (#303)

`frontend/test/today_open_behavior_test.dart`는 테스트 7개다(T6를 두 시점으로 나눔). 실제 앱(`ClipbackApp`)과 실제 `ClipbackApi`·Repository를 `MockClient` 가짜 서버에 연결했다.

| 행 | 관측값 | 표의 예상과 |
| --- | --- | --- |
| T1 | A 목록 GET 대기 중 로그아웃 → 게스트 B 로그인 → B 홈 표시 뒤 A 응답 완료: 상세 없음, 열람 0회, 안내 없음. 이어서 B에서 누르면 목록 GET +1(B 토큰), 상세 `1 / 5`, 열람 1회(B 토큰) | 같음 |
| T2 | 홈 → 보관함 → 홈 뒤 옛 `HomeScreen.onOpenToday` 호출: 목록 GET 0회, 홈 유지. 대조로 새 콜백은 진행(목록 GET 1회, 상세 `1 / 5`) | 같음 |
| T3 | 저장 시트 아래에서 받은 콜백을 시트 닫힘 전환이 끝난 뒤(`route.completed`) 호출: 목록 GET 0회. 닫은 뒤 새로 잡은 콜백은 진행(상세 `1 / 5`) | 같음 |
| T4 | 백그라운드(`paused`) 중 목록 응답: 첫 콘텐츠 GET 1회와 추천 귀속 열람 1회는 그때 끝나지만 위젯 트리는 `HomeScreen` 그대로다. 복귀(`resumed`) 뒤 상세 `1 / 5`가 보이고 열람은 같은 `client_event_id` 1회다 | **다름**(예상: 백그라운드 중 상세가 열려 있음) |
| T5 | 첫 콘텐츠 GET 대기 중(목록 GET 완료 확인 뒤) 다시 누름: 목록 GET 1회, 첫 콘텐츠 GET 1회 그대로. 읽기를 완료하면 상세 `1 / 5`, 열람 1회 | 같음 |
| T6a | 목록 GET 대기 중 즐겨찾기 401 → 토큰 갱신 401로 실제 세션 무효화 시작. 정리가 진행 중이고 홈이 보이는 동안 목록 응답 완료: 상세 없음, 열람 0회, 안내 없음. 정리가 끝나면 로그인 화면이 뜨고 결과는 같음 | 같음 |
| T6b | 같은 경로로 로그인 화면까지 간 뒤 목록 응답 완료: 상세 없음, 열람 0회, 안내 없음 | 같음 |

- T4 차이: 테스트 바인딩은 `paused` 중 프레임을 그리지 않아, 상세로 바뀐 화면이 복귀 뒤 첫 프레임에 반영된다. 위젯 트리 기준 관측이며 실제 기기의 백그라운드 렌더링 증거가 아니다. 실제 관측값으로 고정했다(회의 Q4).
- 열람 `client_event_id`는 키·문자열·UUID v4 형식을 먼저 단언한 뒤 같음·다름만 비교한다.
- main 대조: 같은 테스트 파일을 main `3b3d10f`(`frontend/`가 이 브랜치와 같음) 임시 워크트리에서 돌려 7개 모두 통과했다. 임시 워크트리는 지웠다.
- `5d66ce0` 전체 검증: `VERIFY result=PASS scope=all checks=11 failed=0`, pytest `2320 passed, 47 skipped`, 앱 테스트 3421개 통과.

## 변형 실험

#303은 앱 View 코드에, #304는 같은 규칙을 상세 ViewModel과 앱 View에 적용했다. 두 번 모두 파일을 복사해 두었다가 되돌리고 원상태를 확인했다(#304는 `cmp`). 변형마다 고정 테스트 파일만 돌렸다. #304 로그는 작업 폴더 `.utmp/ticket-304/partial-mutation-*.log`, 변형 코드는 `.utmp/ticket-304/mutate.py`다(커밋하지 않음).

| 변형 | #303 실패 | #304 실패 (바꾼 곳) |
| --- | --- | --- |
| (필수) 콜백이 붙잡은 시도 대신 호출 시점의 지금 시도를 씀 | T2, T3 | T2, T3 (`todayAction`) |
| (필수) 시트 닫힘(`didPop`) 무효화를 뺌 | T3 | T3 (앱 View 관찰자) |
| (필수) 진행 중 요청을 목록 GET이 끝날 때 비움 | T5(목록 GET 1회 기대, 실제 2회) | T5(같음) (`todayAction`의 첫 통과 판정) |
| (참고) 계정 세대 비교를 뺌 | 실패 없음(7개 통과) | 실패 없음(7개 통과) (앱 View `isCurrent`) |
| (참고) `authEpoch` 비교를 뺌 | 실패 없음(7개 통과) | 실패 없음(7개 통과) (앱 View `isCurrent`) |

- 참고 변형 둘이 통과한 것은, 계정 전환·세션 무효화 때 홈 경로·세션 정리 대기·시도 무효화 조건이 먼저 막기 때문이다. #301 스펙 리뷰 R1의 예상과 같다. 이 고정 테스트가 두 비교를 따로 잡지 못한다는 기록이며, 구현에는 두 비교가 있다.
- 두 티켓의 결과가 같아, 옮긴 구조에서도 고정 테스트가 같은 결함을 잡는다.

## 검증

- #303 리뷰(Codex 검수): Standards 0건, Spec 0건. 리뷰어는 다른 작업의 검사와 겹쳐 테스트를 직접 실행하지 않았고, 작업자 로그로 판단했다.
- #304 리뷰(Codex 검수, `5d66ce0...3d61590`): Standards 0건, Spec 0건. 코드 수정 없음. 리뷰어는 `_openToday` 본문이 이름 변경 말고는 바이트 단위로 같은지, 테스트 diff가 없는지를 정적으로 대조했다. Flutter 테스트는 다시 돌리지 않았다.
- #304 작업자 관련 검사(`3d61590` 커밋 전): 바꾼 두 파일 format 0 changed, analyze 문제 없음. 고정 파일과 회귀 5개 파일은 합계 75개 통과했다. 고정·회귀 파일의 diff는 비어 있다.
- #304 작업자 전체 검증(`3d61590`): `VERIFY result=PASS scope=all checks=11 failed=0`, pytest `2320 passed, 47 skipped`, 앱 테스트 `+3421: All tests passed!`.
- main 병합(`222a5d6`) 뒤 작업자 부분 검사: 바뀐 함수는 #298의 링크 저장 경로(`SaveLinkCallback` 등에 `submissionKey` 추가)뿐이다. #304의 두 파일과 고정·회귀 테스트는 병합에서 바뀌지 않았다.
  - `flutter analyze --no-pub` 전체에서 문제 0건
  - 고정·회귀 6개 파일과 저장 계약 관련 5개 파일(`link_save_submission_key_test`, `save_submission_behavior_test`, `saved_content_confirmation_test`, `data/content_repository_test`, `share/manual_save_preservation_test`) 합계 168개 통과
- 최종 리뷰(#301 범위 `ef9f6a8...222a5d6`, Codex 검수): Standards 0건, Spec 0건. 촬영 준비 파일(작업 폴더의 진입 파일·확인 테스트·도착 조건·실행 안내)도 함께 검토했다.
- 최종 전체 검증(리뷰어, `222a5d6`): `VERIFY result=PASS scope=all checks=11 failed=0`
  - pytest: 2325 passed, 47 skipped, 3 warnings in 216.90s (0:03:36)
  - pytest skip: 46 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
  - pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
  - 앱 테스트: `flutter test --no-pub` `+3447: All tests passed!`
  - 백엔드는 이 작업에서 바꾸지 않았다. 건너뛴 Docker 복구·S3 통합 테스트는 이 변경과 무관하며 CI·별도 환경 대상이다.
  - 검사별 로그는 작업 폴더 `.utmp/review-301-verify/20261108T200451-fb337b74b188/`(커밋하지 않음).
- CI App Validation의 4개 명령(`flutter pub get --enforce-lockfile`, `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze --no-pub`, `flutter test --no-pub`)은 verify의 앱 단계가 같은 문구로 실행했다.
- 이 이력 커밋은 문서만 바꾸고 코드는 `222a5d6`과 같다. 그래서 전체 검증을 다시 실행하지 않았다. 문서 링크와 `git diff --check`만 확인했다.
- push·원격 CI·실기기·운영 서버 확인은 하지 않았다. 원격 CI는 PR 생성 뒤 실행한다.

## 기기 실행 확인

2026-11-08 20:15–20:19 KST, 감독이 최종 리뷰·전체 검증 뒤 실행했다. 실행한 앱의 코드는 `222a5d6`과 같다. 최종 촬영 직전 fetch에서 `HEAD..origin/main`은 비어 있었다.

- 실행 구성: 실제 `ClipbackApp`, `ClipbackApi`, Repository에 앱 프로세스 안의 `MockClient` 메모리 서버를 붙인 로컬 대역이다. 고정 테스트와 같은 `TodayServer` fixture를 썼다.
  - 오늘의 추천 응답: stage 1, 추천 5개(606·604·602·605·603). 그래서 N은 5다. 응답은 지연 없이 고정이다.
  - 화면을 따로 만들거나 ViewModel을 거치지 않는 경로는 쓰지 않았다. 운영 서버·실제 OAuth·사용자 데이터는 쓰지 않았다.
- 입력: 홈 Today 버튼, 상세 다음 버튼, 상세 뒤로 버튼을 화면 정보(probe)의 탭 후보 좌표로 OS 탭했다. 누르기 전 dry-run에서 세 대상 모두 후보 1개, 화면 안, 눌림 가능이었다.
  - Today 버튼 후보는 홈 화면 위젯이 받은 `onOpenToday`와 같은 콜백이 붙은 버튼만 골랐다.
  - 화면을 바꾸는 endpoint나 콜백 직접 호출은 쓰지 않았다.
- 글자 배율은 두 플랫폼 모두 1.0이다. 입력이 없어 키보드는 나오지 않았다.

| 플랫폼 | 기종·OS | 논리 크기·배율(probe JSON) | 안전 영역 |
| --- | --- | --- | --- |
| iOS | iPhone 16 Simulator, iOS 18.6 | 393×852, devicePixelRatio 3 | 위 59, 아래 34 |
| Android | Medium_Phone Emulator, Android 16(API 36) | 411.42857142857144×914.2857142857143, devicePixelRatio 2.625 | 위 24, 아래 24 |

두 플랫폼 모두 같은 흐름과 결과였다(probe JSON 기준).

| 단계 | 화면 | 콘텐츠 | 목록 GET | 열람 기록(추천 항목 ID) |
| --- | --- | --- | --- | --- |
| Today 버튼 OS 탭 | 상세 `1 / 5` | 606 | 1 | 1306 |
| 다음 버튼 OS 탭 | 상세 `2 / 5` | 604 | 1 | 1306, 1304 |
| 뒤로 버튼 OS 탭 | 홈 | – | 1 | 1306, 1304 |

- 예상 밖 요청 목록은 6개 상태 모두 비어 있다. 도착은 단계마다 목표 조건(화면 이름, `n / m`, 콘텐츠 ID)이 맞는지 확인했다.
- 화면: 감독이 원본 PNG를 직접 열어 양쪽의 상세 `1 / 5`와 홈 복귀 화면을 확인했다. 상세 `2 / 5`의 화면·콘텐츠 ID·열람은 JSON으로 확인했다. 원본 스크린샷은 보정하지 않았다. 사용자 시각 판정은 아직 받지 않았다.
- 빌드: iOS·Android 모두 촬영 전 확인을 통과한 뒤 빌드했다. 설치본이 그 빌드와 같은지 확인했다(iOS kernel 접두 `aa2127a14105`, Android APK SHA-256 접두 `1a75803fcb13`, 빌드 기록).
- 기기 차례:
  - iOS: headless 시뮬레이터라 등록할 Simulator 앱 프로세스가 없다. 기기 프로세스를 등록하지 않고, 부팅 전부터 종료까지 감독의 배타 잠금을 유지했다. 끝난 뒤 기기를 껐다.
  - Android: 잠금을 잡은 뒤 뜬 에뮬레이터 프로세스를 잠금에 등록했다. 끝난 뒤 에뮬레이터를 껐다. 종료 뒤 프로세스가 늦게 내려가 `busy.sh --wait`로 비는 것을 확인했다(20:20:05). Gradle 데몬도 멈췄다.
- 도구 사용 오류 1회(iOS 빌드): 첫 빌드 호출에 잠금 주인 환경값을 넘기지 않아, 빌드 스크립트 안의 다른 작업 확인이 감독 자신의 잠금을 보고 빌드 시작 전에 거부했다. 주인 값을 넘긴 정상 호출로 촬영 전 확인과 빌드가 통과했다. 다시 찍거나 앱 코드·검사를 바꾸지 않았다.
- 증거: 작업 폴더 `.utmp/ticket-304/`(커밋하지 않음)의 `device-results.md`, 촬영 진입 파일 `state_preview.dart`·`state_preview_check_test.dart`, 도착 조건 `capture-targets.json`, 실행 안내 `capture-plan.md`, `screens/`의 PNG와 같은 이름의 JSON이다.
  - iOS: `ios-after-detail-1`, `ios-after-detail-2`, `ios-after-home-back`, 도착 확인 `ios-after-*-target.json`, 화면 구조 `ios-home-back-ax.json`
  - Android: `android-after-detail-1`, `android-after-detail-2`, `android-after-home-back`, 도착 확인 `android-after-*-target.json`, 화면 구조 `android-detail-1-ax.json`·`android-home-back-ax.json`
  - `ios-after`·`android-after`는 설치 확인용 첫 홈 화면이다.
  - 이미지는 아직 GitHub에 올리지 않았다. PR 본문에 첨부한다.
- 촬영 준비: 앱 코드는 바꾸지 않고 작업 폴더에 촬영 진입 파일만 만들었다.
  - 빌드 전 확인은 13개 통과, 탭 검사는 5개 통과였다(`partial-preflight-check.log`, `partial-preflight-after.log`, 플랫폼별 `preflight-<plat>-after.log`). 여기에는 같은 왕복을 probe 탭 좌표로 위젯 테스트에서 실행하는 확인이 들어 있다.
  - Today 버튼 조건을 모든 버튼으로 넓힌 변형은 후보 20개로 실패했다(`partial-preflight-variant-any-inkwell.log`).
- 제한: 회의 결정에 따라 변경 전 촬영, 3면 비교, 영상은 없다. 글자 배율 1.0만 확인했다.

## 동작 보존 증거에서 제외하는 것 (#301)

아래 항목은 이번에 고정하지 않았으며, "동작 변경 없음" 주장에도 넣지 않는다.

- stage 0·빈 목록·목록 실패·첫 콘텐츠 읽기 실패(404 아님)의 안내 문구. 상세 ViewModel의 목록·첫 콘텐츠 처리 본문에서 나오며, 이 본문은 private으로 바꿨을 뿐 내용은 같다. 기존 테스트가 홈 유지·열람 없음을 단언하는 것으로 갈음한다.
- Repository의 목록·첫 콘텐츠 요청 처리 자체. 바뀌지 않았다. 기존 `data/today_repository_test`가 그대로 통과하는 것으로 갈음한다.
- 인증 재전송(401 → 토큰 갱신 → 재전송). API 계층 동작이고, 오늘의 추천 열기는 그 결과만 받는다. 옮긴 판정은 재전송에 끼어들지 않는다.
- 앱 제거 뒤 늦은 응답. 스펙 리뷰(추가 확인 1)가 정적 추적으로 제외해도 된다고 판정했고, 실행 검증은 아니다.
  - 목록·첫 콘텐츠 처리와 Repository는 `await` 뒤에 dispose를 먼저 본다. 앱 View의 정리는 동기로 끝난다.
  - 보관해 둔 옛 콜백은 이전 전에는 `mounted`에서, 이전 뒤에는 dispose 확인과 비워진 진행 중 요청에서 막힌다.
  - 전제는 새 예약 작업, 비동기 dispose, 새 취소 방식을 더하지 않는 것이다. #304는 이 전제를 지켰다. #304 리뷰도 대기 중·성공 직후 dispose 경로를 정적으로 확인했다.
- 계정 세대 비교가 단독으로 관측되는지. 계정이 바뀌면 화면도 로그인으로 바뀌어 홈 조건이 먼저 거짓이 될 수 있다. T1은 계정 변경 보존 검사로만 두었다(참고 변형에서 실패 없음).
- `authEpoch` 비교가 단독으로 관측되는지(스펙 리뷰 R1). 실제 앱 경로에서 `authEpoch`만 다른 유효한 홈은 만들 수 없다. 세션 정리 대기와 시도 무효화가 먼저 막는다. T6는 "최종 인증 무효화 뒤 늦은 응답으로 상세가 열리지 않는다"를 지키는 고정 행이다.

## 범위 밖 후보 (고치지 않음, #301 Out of Scope)

1. Today 요청에 제한 시간이 없음(`ApiRequestScope`를 씌우지 않음, Q3). 서버가 멈추면 홈을 떠나기 전까지 다시 눌러도 반응이 없을 수 있다(실행 미확인).
2. 상세 ViewModel이 Today 상세 이동까지 맡아 커지는 문제.
3. 주간 추천과 Today의 무효화 기준 차이(시트 열기·닫기, `authEpoch`, 앱 시작 단계).
4. 계정 세대 값이 두 개(`AppViewModel.accountGeneration`·`ContentRepository.accountVersion`)인 점과 앱 루트의 "아직 같은 계정·같은 화면인가" 판정 반복(#294 범위 밖 후보 6·7).
5. 다음 순서: 권한 안내 시도 → 스크롤 보존 → 종료 확인·배너.
