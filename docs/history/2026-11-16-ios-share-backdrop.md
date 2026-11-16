# iOS 공유 저장 시트 뒤가 보내는 앱 대신 검게 보이던 문제 (#367)

2026-11-15–2026-11-16, 브랜치 `fix/share-backdrop-black`. 시작 커밋 `2db2b19`.
팀 피드백 시트 90("공유하기 눌렀을 때 기존 앱 뒷 배경이 dimmed 처리됐으면 좋겠는데, 지금은 검은 배경이 되어버림", iOS 인스타그램)을 다룬다.

## 문제

- 다른 앱의 공유 메뉴에서 허투루를 고르면 공유 저장 시트 뒤가 보내는 앱을 어둡게 한 모습이 아니라 단색으로 보였다.
- iPhone 13 iOS 27.2, TestFlight 0.6.1(15)에서 인스타그램·사파리·사진 모두 같았다. 위쪽이 둥근 카드 모양이 화면 맨 위에서 약 47pt 아래부터 깔리고, 카드 안은 다크 모드에서 검정(화소 약 (10,12,9)), 라이트 모드에서 회색(약 (121,122,121)) 단색이었다. 카드 위 틈으로만 보내는 앱이 비쳤다.
- iPhone 16 iOS 18.6 Simulator에서는 덮개 아래로 송신 앱이 보였다(2026-10-31 확인과 같음).

## 사용자 결정

- 2026-11-14 "모두 추천대로": 진단은 먼저 하고 수정은 #329 병합 뒤. 앱이 바꿀 수 없는 iOS 제약이면 원인·근거·대안을 보고하고 멈춘다.
- 2026-11-16 "추천대로 해줘": #329를 기다리지 않고 F1을 시험한다(바뀌는 줄은 `Info.plist` 키와 `init`·`viewDidLoad` 표시 설정에만).
- 2026-11-16 "모두 예": 디버거로 화면 구조를 다시 읽고(A1), 그래도 모르면 디자인 결정으로 넘긴다.
- 2026-11-16 "예": F2(시트 테두리 뷰의 배경을 투명하게 바꾸는 비공식 우회)를 시험한다. 새 표시 메서드를 더하므로 "`init`·`viewDidLoad`에만" 조건 밖이지만 사용자 승인으로 진행했다.
- 2026-11-16 "모두 추천대로 해줘": F2를 채택한다. 뒤 화면이 원본보다 어두운 점은 이번에 고치지 않고 디자인 확인 목록에 올린다.

## 진단

| # | 가설 | 결과 |
| --- | --- | --- |
| H1 | iOS가 공유 확장을 자체 시트 안에 띄우고, 그 배경이 불투명하다 | 확인. 아래 A1 |
| H2 | 보내는 앱에 따라 다르다(인스타그램만) | 배제. 세 앱 모두 같음 |
| H3 | iOS 26 이상의 표시 방식이 iOS 18 Simulator와 다르다 | 강한 정황, 미확인. iOS 26 이상 Simulator 런타임이 없고 같은 기기에서 OS만 바꾼 비교도 없다 |

- 외부 근거: [WWDC25 세션 323](https://developer.apple.com/videos/play/wwdc2025/323/)(iOS 26 전체 높이 시트는 불투명), [Apple DTS 답변](https://developer.apple.com/forums/thread/795880), [Apple 엔지니어 답변](https://developer.apple.com/forums/thread/694643)(공유 확장은 시스템 시트로 표시), [커뮤니티 재현 보고](https://developer.apple.com/forums/thread/806117)(iOS 26.1 불투명, 18.5 투명, 상위 뷰를 clear로 바꾸는 우회는 커뮤니티 답글이며 Apple이 승인한 방법이 아님).
- TestFlight 빌드는 디버거 연결이 거부돼 개발 빌드(0.1.0(1), profile, 운영 서버 주소)로 확인했다.

### F1: `NSExtensionActionWantsFullScreenPresentation` — 효과 없음

- `Info.plist`의 `NSExtension` 직접 자식으로 YES를 넣은 개발 빌드에서 세 앱 모두 단색 카드(다크 평균 11.0·편차 0.0, 시작 위치 같음), 라이트 회색(평균 122)이 그대로였다. 끌어내림 닫기도 그대로였다.
- iOS 18.6 Simulator에서는 F1 전·후 화면이 화소까지 같았다. F1 줄은 되돌렸다.

### A1: 불투명 배경은 확장 프로세스 안의 시스템 시트 테두리 뷰

- 공유 확장 프로세스에 디버거를 붙여 시트가 떠 있는 동안 읽었다(사진 앱, 다크 모드). connectedScenes·`UIApplication.windows`는 0개였고 내부 창 목록으로 창 하나를 찾았다.
- 구조: `UIWindow` → `_UIViewServiceRootViewController`(formSheet, `_UIFormSheetPresentationController`) → 자식 `ShareViewController`(overFullScreen, 배경 clear).
- `ShareViewController.view`의 상위 체인: `UIView`(clear) → `UIView` → `_UIDropShadowClippingView` → **`UIDropShadowView`**(frame 0,57,390,787, 배경 `systemBackgroundColor`, layer 배경 (0.110,0.110,0.118, 불투명), `isOpaque` 1) → `UITransitionView` → `UIWindow`. 나머지는 배경이 없다.
- 우리 `.overFullScreen`·검정 50% 덮개는 이 시트 안에서만 그려져, 다크에서는 검정, 라이트에서는 회색으로 보였다(합성 값은 근사, 따로 검증하지 않음).

## 구현(F2)

- `frontend/ios/ShareExtension/ShareViewController.swift`: `viewDidLayoutSubviews`를 더해 확장 루트 view의 상위 뷰를 창 바로 아래까지 배경 `.clear`, `isOpaque = false`로 바꾼다. 클래스 이름은 비교하지 않는다(A1에서 배경이 있는 상위 뷰는 `UIDropShadowView` 하나였다). 시트 그림자·둥근 모서리·흐림은 손대지 않는다.
- 레이아웃마다 다시 적용해 끌어내리는 도중·화면 모드 변경 때 시스템이 다시 칠해도 덮는다.
- #329가 옮길 생명주기 코드(`rg -n 'store\??\.(mark|discard)|service\??\.cancel|currentCredential|savingCredential|deinit|addObserver|removeObserver'`)는 내용이 그대로이고 줄 번호만 12씩 밀렸다. `viewDidAppear`는 바꾸지 않았다.
- 위험: 시스템 뷰 구조에 기대는 비공식 우회라 iOS 업데이트로 다시 단색이 되거나 효과가 달라질 수 있다. 그때는 [디자인 확인 필요](../figma-ui-alignment-plan.md#figma-pending-share-backdrop-ios26)의 결정과 함께 다시 본다.

## 검증

### 실기기(사용자 확인)

iPhone 13, iOS 27.2(24B119), F2 개발 빌드 0.1.0(1)(profile, 운영 서버 주소, 저장하기는 누르지 않음). 화면은 `devicectl device capture screenshot`으로 약 1.4초마다 찍고(녹화 불가) 시트 위 띠(y 12–45%)의 밝기 평균·편차로 단색 여부를 판정했다.

| 단계 | 사용자 확인 | 자동 판정(대표 장면) |
| --- | --- | --- |
| 인스타그램, 바깥 탭 닫기 | 반투명 검정, 둥근 모양, 닫힘 | 뒤 화면 보임(평균 21.6·편차 17.6) |
| 사파리 youtube.com, 끌어내림 닫기 | 같음, 끌어내리는 도중에도 어둡게 보임 유지, 닫힘 | 뒤 화면 보임(16.2·15.9, 끌어내리는 도중 11.1·11.6) |
| 사진, 바깥 탭 닫기 | 같음, 닫힘 | 뒤 화면 보임(35.8·30.3) |
| 인스타그램, 끌어내리다 놓기 → 끌어내림 닫기 | 다시 올라옴, 어둡게 유지, 닫힘, 인스타그램으로 돌아옴 | 뒤 화면 보임(6.4·13.3, 검은 바탕 게시물) |
| VoiceOver | "닫기 Button", 두 번 탭으로 닫힘 | — |
| 라이트 모드 사파리, 바깥 탭 닫기 | 반투명, 닫힘 | 뒤 화면 보임(26.1·24.9) |

- 변경 전(TestFlight 0.6.1(15))과 F1은 같은 판정에서 모두 단색(다크 평균 11.0·편차 0.0, 라이트 122)이었다.
- 뒤 화면은 OS가 어둡게 한 보내는 앱·공유 메뉴 위에 우리 검정 50%가 한 번 더 겹쳐 원본 배경보다 어둡다([디자인 확인 필요](../figma-ui-alignment-plan.md#figma-pending-share-backdrop-ios26)).
- 사파리 첫 시도에서 "공유할 수 없어요 / 한 번에 링크 하나만 공유해 주세요" 안내가 한 번 떴다(팀 피드백 시트 117의 증상, 이번 범위 밖). 두 번째 시도는 정상이었다.
- 끝난 뒤 기기는 TestFlight 0.6.1(15)으로 다시 설치하도록 안내했다.

### iOS Simulator

iPhone 16, iOS 18.6, Xcode 27.2, 로컬 대역 서버. `ShareUITests`의 `testDismissBeforeSaveKeepsNoPendingShare`(끌어내림·배경 탭 닫기), `testPreparationDismissKeepsNothingAndRepeatedTapsSaveOnce`, `testCaptureShareLoadingStates`를 매번 Simulator를 새로 부팅하고 앱을 새로 빌드·설치해 돌렸다.

| 상태 | 회차 | 결과 | 소요(초, 위 순서) |
| --- | --- | --- | --- |
| 변경 전(`2db2b19` 파일) | 1–5 | 5회 모두 3개 통과 | 51.3–52.9 / 71.0–77.8 / 60.6–66.2 |
| F2 | 1–5 | 5회 모두 3개 통과 | 50.8–52.0 / 71.6–73.2 / 61.9–63.7 |

- 이 반복 전 F2 첫 실행 한 번에서 `testCaptureShareLoadingStates`가 첫 공유 시트를 10초 안에 찾지 못해 실패했다(나머지 둘은 통과, 바로 다시 돌린 실행은 모두 통과). 반복 10회에서 다시 나지 않아 F2 때문인지는 가리지 못했고, 같은 조건의 변경 전과 F2에 차이는 없었다.
- iOS 18.6에서는 F2 전·후 시트·준비 화면이 화소까지 같다(이 버전의 시트에는 불투명 배경이 없다).
- iOS 26 이상 Simulator 런타임은 없어 Simulator로 효과를 확인하지 못했다. 효과 확인은 위 실기기 결과다.

### 전체 검증

- 구현 `5401f32`에 main(`747b2f0`)을 합친 `b3e08a3`, CHANGELOG 절 정정 `64d4868`에서: `VERIFY result=PASS scope=all checks=12 failed=0`. 앱 테스트 3766건 통과, 백엔드 pytest 2743 passed·49 skipped.
- 원본 skip 출력:
  - `pytest skip: 48 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)`
  - `pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)`
- main이 공유 코드(`ShareCore`, #398)를 바꿔 합친 트리(`64d4868`)에서 위 공유 UI 테스트 3개를 한 번 더 돌려 모두 통과했다.
