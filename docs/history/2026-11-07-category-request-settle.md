# 카테고리 요청 4곳을 요청 수명의 결과 3분류로 옮기기 (#282, #283)

2026-11-07, 상위 스펙 #276의 두 티켓을 브랜치 `refactor/account-request-scope`에서 진행했다.
#282는 앱 코드를 바꾸기 전에 동작 고정 테스트를 추가했고(커밋 `a6afae6`), #283은 요청 수명 `ApiRequestScope`에 `settle`을 더하고 카테고리 요청 4곳을 옮겼다(커밋 `8653f6f`).
이 기록을 더한 커밋은 문서만 바꾼다. 전체 검증의 기준 코드는 `8653f6f`이다.
사용자에게 보이는 동작은 바뀌지 않으므로 CHANGELOG `미배포`에는 적지 않았다.

## 사용자 결정

- 2026-11-07 회의 "모두 추천대로", "추천대로": 범위는 `content_actions.dart`의 카테고리 생성 저장, 수정 저장, 목록 재조회, 수정 저장 뒤 피드 갱신 4곳이다.
  새 메서드는 `ApiRequestScope.settle`이고, 결과는 성공(값) / 늦은 응답 / 실패(오류) 3분류다. 저장소의 `null` 반환은 늦은 응답으로 보며, 시트가 보는 `CategorySaveStatus` 4분류는 바꾸지 않는다.
- 같은 날 스펙 리뷰 반영 "모두 추천대로": 목록 재조회의 응답 검사·`onLoaded`·현재 확인은 수명을 닫기 전에 하고, `onLoaded`는 호출부 zone에서 실행한다. `CategoryReadSuperseded`는 안내 없이 `false`로 끝낸다.
  고정 테스트는 main에서 통과를 확인한 뒤 동결한다. 계정 변경·정리 중인 저장 대기는 지금처럼 응답이나 10초까지 기다린다.
- 화면·API 계약·서버 변경이 없어 변경 전·후·Figma 3면 비교는 하지 않는다. iOS Simulator와 Android Emulator에서 카테고리 생성 저장, 수정 저장, 편집기 준비 조회를 1회씩 실행하고 스크린샷만 남긴다.

## 구현 (#283)

- `frontend/lib/data/services/api_request_scope.dart`: `settle<T>`와 봉인된 결과 `RequestSucceeded` / `RequestStale` / `RequestFailed`를 더했다.
  operation을 수명의 zone 안에서 실행하고, 결과를 취소·시간 초과와 경주시킨다. 끝난 뒤 현재 조건이 false면 성공·실패와 관계없이 늦은 응답이고, 아니면 오류는 실패, 값은 성공이다.
  판정을 마친 뒤 수명을 닫는다. 기존 `run`·`wait`·`checkActive`·`cancel`·`isActive`·`cancelled`·`current`는 그대로다.
- `frontend/lib/app/actions/content_actions.dart`
  - 생성·수정 저장은 공용 비공개 도우미 하나로 결과를 번역한다. 늦은 응답과 `null`은 `stale`, 성공은 `succeeded`와 후속 요청 예약, `CategorySubmissionRejected`는 `rejected`(거절 대응은 그대로), 그 밖의 실패는 `unconfirmed`다.
  - 목록 재조회의 operation은 응답 대기 → `checkActive` → 응답이 현재 것인지 검사 → `onLoaded`(재조회를 시작할 때의 zone에서) → 현재 여부 확인 순서다. 수명 필드와 이전 조회의 즉시 취소는 그대로다.
  - 수정 저장 뒤 피드 갱신은 자기 10초 수명으로 `settle`하고 결과를 버린다.
- `frontend/README.md` 코드 구조 표의 `api_request_scope.dart` 줄에 "요청 결과를 성공·늦은 응답·실패로 돌려줌"을 더했다.
- 바꾸지 않음: `clipback_app.dart`, 저장 화면, Repository·API 클라이언트, 카테고리 시트·관리 ViewModel, `CategorySaveStatus`.

## 테스트

- 고정 테스트(#282): `frontend/test/app/content_actions_category_request_test.dart`. #276 표의 S1–S17, R1–R17b, F1–F2를 테스트 128개로 단언한다.
  `a6afae6` 상태로 동결했다(SHA256 `1a48b3f88a77ac6baf925902a3d228515b2e442a0dfec3e50f91737bae586846`). #283 diff에 이 파일은 없다(`git diff a6afae6 8653f6f`).
- 새 단위 테스트(#283): `frontend/test/data/api_request_scope_test.dart`, 15개. 값·`null`·오류·바깥 취소·시간 초과(9.999초 미완료, 10초 실패)·현재 조건 없는 취소·operation 안의 `ApiRequestScope.current`·끝난 뒤 닫힘·시작 전 현재 아님·동기 예외(현재/현재 아님)·마지막 단계의 `isActive`를 확인한다.
  `settle`을 만들기 전에는 컴파일 실패로 시작했다.
- 기존 회귀 `category_auth_recovery_test`, `category_list_recovery_test`, `category_reentry_test`, `category_delete_test`, `app/content_actions_test`는 수정하지 않았다.

## #282 고정 테스트를 main에서 실행 (#282 결과 댓글에서 옮김)

- 방법: 정식 `git worktree`가 아니다. `git archive 901a3b1 frontend`로 main의 frontend 소스를 이 워크트리 안의 임시 디렉터리 `.utmp/ticket-282/main-901a3b1`(커밋하지 않는 작업 폴더)에 풀고, 같은 파일(SHA 동일)을 넣어 `flutter pub get --enforce-lockfile --offline` 뒤 `flutter test --no-pub <이 파일>`을 실행한 소스 비교다.
- 결과: `+128: All tests passed!`. 기획 단계 측정값과 다른 행은 없었다.
- 참고: 901a3b1과 #282 시작 커밋 8cf9698의 차이는 `GLOSSARY.md` 4줄뿐이다.
- 같은 파일의 `a6afae6` 전체 검증은 `VERIFY result=PASS scope=all checks=11 failed=0`, 앱 테스트 `+3353: All tests passed!`였다(원문: [#282 댓글](https://github.com/clip-back/clipback/issues/282#issuecomment-6706830132)).

## 변형 실험

#282(원문은 위 댓글): 앱 코드를 잠시 바꾸고 고정 테스트 파일만 실행한 뒤, 복사본으로 되돌려 `git diff -- frontend/lib`가 비어 있음을 매번 확인했다.

| # | 변형 | 실패 수 | 실패한 테스트 |
| --- | --- | --- | --- |
| 1 | 오류 시 계정 재확인 제거(생성·수정의 거절이 아닌 오류 처리) | 17 | S11 생성·수정 error, S12 생성·수정, S13 생성·수정 error·무응답, S14 생성, S15 생성·수정 error·silence × T0·T1 |
| 2 | `null` → `stale` 판정 제거 | 2 | S6 생성, S6 수정 |
| 3 | 거절 대응 하나 바꾸기(`category_target_missing` → `inputInvalid`) | 2 | S7 생성·수정 `category_target_missing` |
| 4 | 수정 뒤 피드 갱신 호출 삭제 | 10 | S1·S2·S3·S4 수정, F1 성공·실패·무응답, F2 성공·실패·무응답 |
| 5 | 목록 재조회의 이전 조회 취소 삭제 | 1 | R7 |
| 6 | 응답 검사·`onLoaded`를 수명을 닫은 뒤로 옮기기 | 3 | **R1a**, R3a, R3b |
| 7 | `CategoryReadSuperseded` 분기 삭제 | 5 | **R16**(저장 뒤 조회 아님·저장 뒤 조회), **R17**, R17b, R2 |
| 8 (추가) | `onLoaded`를 요청 수명 zone 안에서 부르기 | 1 | R1a |

#283(`8653f6f`의 새 코드에서): 같은 방식으로 복사본으로 되돌리고 SHA256이 시험 전과 같은 것을 확인했다.

| 변형 | 실패한 테스트 |
| --- | --- |
| 목록 재조회에서 `onLoaded`를 호출부 zone 없이 부르기 | R1a 1개 |
| 목록 재조회 operation의 `checkActive` 삭제 | R4·R5·R6·R7 4개 |

## 리뷰

- #282 티켓 리뷰(`a6afae6`): Standards 0건, Spec 0건.
- #283 티켓 리뷰(`a6afae6...8653f6f`): Standards 0건, Spec 0건. 반영할 지적이 없어 코드는 `8653f6f` 그대로다.
- #276 최종 리뷰: Standards 낮음 1건, Spec 0건. 이 파일의 main 비교 위치를 실제 실행 위치로 고쳤고(`5d5a5f4`), #282 결과 댓글의 같은 한 줄도 고쳤다. 문서만 바뀌었다.

## 검증

2026-11-07, 기준 코드 `8653f6f`(로컬, 대역 데이터, 작업 트리 깨끗함).

- 바꾼 부분(구현 중): 새 단위 테스트 `+15`, 고정 테스트 `+128`, 기존 회귀 5개 파일 `+171` 모두 `All tests passed!`. 바꾼 파일의 포맷·분석은 이상 없음.
- 전체 검증 `python3 ~/.heoturu-agents/verify.py`: `VERIFY result=PASS scope=all checks=11 failed=0`.
  `frontend/`에서 CI App Validation과 같은 4개 명령이 이 안에서 실행됐다. `flutter pub get --enforce-lockfile` 성공, `dart format --output=none --set-exit-if-changed lib test` `Formatted 302 files (0 changed)`, `flutter analyze --no-pub` `No issues found!`, `flutter test --no-pub` `+3368: All tests passed!`.
  백엔드 `pytest: 2235 passed, 47 skipped, 3 warnings`.
  - pytest skip: 46 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
  - pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
  - 백엔드는 이번에 바꾸지 않았다. 건너뛴 Docker 복구·S3 통합 테스트는 이 변경과 무관하며 CI·별도 환경 대상이다.
- iOS Simulator·Android Emulator 실행 결과는 아래 "기기 실행 확인"에 적었다. push·원격 CI·실기기·운영 서버 확인은 하지 않았다.

## 기기 실행 확인

2026-11-07 KST, 감독이 최종 리뷰 뒤 실행했다. 실행한 앱의 코드는 `8653f6f`와 같다(촬영 HEAD `5d5a5f4`, 그 사이는 문서만 바뀜).
iOS는 21:43경 빌드를 시작해 21:52에 끝냈고, Android는 21:52경 시작해 21:55에 끝냈다.

- 실행 구성: 실제 `ClipbackApp`, `ContentActions`, Repository, `ClipbackApi`에 앱 프로세스 안의 `MockClient`를 붙인 로컬 대역이다. 카테고리 목록은 메모리에 두며, 저장된 사용자·운영 데이터는 쓰지 않았다.
  실제 HTTP 전송과 운영 서버 저장은 확인 범위가 아니다.
- 입력: Orca의 OS 탭과 ASCII 입력으로 `Scope276`을 쓰고, 수정 때 `X`를 더했다. 미리 채운 값은 없다. 앱 안의 probe로 입력 필드의 문자열과 선택 위치를 확인했다.
  iOS는 하드웨어 키보드 경로라 화면 키보드가 나오지 않았고(probe의 아래쪽 inset 0), Android는 화면 키보드가 나왔다(입력 확인 probe의 아래쪽 inset 336.38).
- 글자 배율은 두 플랫폼 모두 1.0이다.

| 플랫폼 | 기종·OS | 논리 크기(probe JSON) | 시나리오와 결과 |
| --- | --- | --- | --- |
| iOS | iPhone 16 Simulator, iOS 18.6 | 393×852 | 편집기 준비 조회(`GET /api/v1/categories`) 뒤 편집기가 열리고 입력 필드에 초점. 생성 저장 `POST /api/v1/categories` 1회(`Scope276`) 뒤 목록 재조회 1회, 목록에 `Scope276`. 수정 저장 `PATCH /api/v1/categories/900` 1회(`Scope276X`) 뒤 목록 재조회 1회, 목록에 `Scope276X` |
| Android | Medium_Phone Emulator, Android 16(API 36) | 411.42857142857144×914.2857142857143 | iOS와 같은 세 시나리오와 같은 요청 순서·결과 |

- 요청 기록: 각 상태의 probe가 기록한 카테고리 요청은 편집기 준비 2건(첫 목록 조회와 편집기 준비 조회), 생성 뒤 누적 4건, 수정 뒤 누적 7건이다. 예상 밖 요청 목록은 6개 상태 모두 비어 있다.
- 화면: 감독이 원본 PNG 6장을 열어 편집기, 생성한 이름, 수정한 이름을 확인했다. 원본 스크린샷은 보정하지 않았다.
  Android 편집기 준비 화면에는 화면 키보드가 보이지만, 같은 상태의 probe JSON은 아래쪽 inset이 0이다. probe와 스크린샷을 찍은 시점이 다른 것으로 보이며, 따로 재현하지 않았다.
- 증거: 작업 폴더 `.utmp/ticket-283/`(커밋하지 않음)의 `capture-report.md`, `capture-evidence.json`, `screens/`의 PNG와 같은 이름의 JSON이다.
  - iOS: `ios-after-editor-ready-fixed`, `ios-after-created`, `ios-after-updated`
  - Android: `android-after-editor-ready`, `android-after-created`, `android-after-updated`
  - 이미지는 아직 GitHub에 올리지 않았다.
- 촬영 준비 재작업: 앱 코드와 화면은 바꾸지 않았고, 작업 폴더의 촬영용 프리뷰만 고쳤다.
  - 첫 사전 점검은 SharedPreferences mock 초기화가 빠져 시작 대기 시간 초과로 실패했다(`capture-preflight.log`). 초기화를 더한 뒤 `capture-preflight-2.log`, `capture-preflight-3.log`에서 모두 2개 통과했다.
  - iOS 편집기 첫 probe는 공용 프리뷰 설정이 홈 스크롤만 찾아 null 오류가 났다(`ios-editor-ready.log`, 저장을 누르기 전). 현재 화면의 ScrollView를 찾도록 고쳐 iOS를 다시 빌드한 뒤 세 시나리오를 마쳤다. 입력 방식은 바꾸지 않았다.
  - 빌드·설치 로그: `build-ios-fix.log`, `build-ios-after-capture-fix.log`, `ios-install-2.log`, `build-android.log`, `build-android-after-capture-fix.log`, `android-install.log`.
- 제한: 회의 결정에 따라 변경 전 촬영, 변경 전·후·Figma 3면 비교, 영상은 없다. 글자 배율 1.0만 확인했고 iOS 화면 키보드 상태는 확인하지 않았다. 사용자 시각 판정은 대기 중이다.

## 동작 보존 증거에서 제외하는 것 (#276)

아래 항목은 고정 테스트가 단언하지 않으며, 이번 "동작 변경 없음" 주장에도 넣지 않는다.

- T1과 T2 사이의 중간 마이크로태스크 위치에서 계정이 바뀌는 경우. 응답 도착부터 결과 반환까지의 마이크로태스크 수는 구현에 따라 달라질 수 있다. 테스트가 제어하는 경계는 T0·T1·T2뿐이다.
  #283은 `settle`을 거치며 이 구간이 바뀌었고, 판정 뒤 호출부에서 현재 여부를 다시 보지 않는다. 생성·수정 저장 메서드에서 `async`를 뺀 데 따른 스케줄 차이도 보존 주장에 넣지 않는다.
- 피드 갱신 쪽 Repository의 피드 반영과 그 안의 인증 후속 요청. Repository와 API 클라이언트 코드는 바꾸지 않았다. Actions 쪽 수명이 언제 열리고 닫히는지와 요청 안에서 수명이 보이는지는 F1·F2·S1으로 고정한다.
- 실제 HTTP 전송이 실제로 끊기는지, 실제 OS 백그라운드에서의 타이머. MockClient와 가짜 시간으로는 증명되지 않는다. 늦은 응답을 무시하는 논리적 취소까지만 고정한다.
