# 공유 저장 시트와 완료 토스트 (#122)

다른 앱의 공유 메뉴로 들어오는 경로를 Figma 공유 저장 시트와 완료 토스트로 바꾼 작업의 구현·검증 기록입니다.
명세는 [#122](https://github.com/clip-back/clipback/issues/122)이며 티켓별 절로 나눠 기록합니다.

## #123 iOS 정상 흐름

티켓 [#123](https://github.com/clip-back/clipback/issues/123), 브랜치 `feat/share-save-sheet-123-ios`.
Figma 파일 `svNWsTFh8Ws1Mpt8XQIcrN` Page 1의 `233:3418`(공유 메뉴)·`233:3420`(시트)·`233:3430`(토스트)을
2026-10-31 13:30~13:32 KST에 조회한 값을 기준으로 했다.

### 구현

- 공유 메뉴 경로만 바꿨다. `frontend/ios/ShareExtension/ShareViewController.swift`가 시트를 직접 그리며,
  본앱 복구용 `ShareCore/ShareComposerViewController.swift`는 동작·문구·식별자를 바꾸지 않고 확장 타깃 컴파일에서만 뺐다.
- 시트: 폭 전체, 위쪽 모서리 24, 흰색. 손잡이 50×5 `#D1D1D1`(위 8), 내용 위 32·좌우 16, "저장하기" 343×56
  `#FFD75C`·모서리 8·Pretendard SemiBold 16 `#1A1A1A`, 간격 16, 안내 문구 Pretendard Medium 14 `#767676` 가운데 정렬.
  자간은 원본 -2.5%(16pt -0.4, 14pt -0.35)를 글자 크기에 비례해 적용한다.
- 하단 여백: 원본은 안내 아래 32에서 화면 끝에 닿고 홈 인디케이터가 없다. 결정 Q2에 따라 max(32, 하단 안전 영역)을 쓴다.
  iPhone 16(하단 34pt)에서는 34pt라 시트가 원본 153pt보다 2pt 높다. 토스트도 같은 규칙으로 화면 아래에서 띄운다.
- 글꼴(결정 Q1): Pretendard Medium·SemiBold와 `Pretendard-LICENSE.txt`를 확장 Resources에 넣고 `UIAppFonts`에 등록했다.
  파일은 `frontend/assets/fonts`를 참조하며 저장소에 복사하지 않는다. 확장 용량은 약 3.2MB 늘어난다.
  Flutter가 같은 라이선스 파일을 자산으로 함께 배포하는 방식을 따랐다.
- 큰 글자: 글자를 사용자 글자 크기로 키우고 시트·버튼·토스트가 위로 늘어난다(전용 배치는 디자인 확인 필요).
- 배경: 원본 `bg_diim`은 흐림 2px + 검정 50%다. 확장 안에 흐림 효과(`UIVisualEffectView`)를 임시로 넣어 Simulator에서 본 결과
  뒤의 송신 앱 화면 없이 단색 재질로만 그려졌다. 확장이 다른 앱 화면을 흐리게 할 수 없어 검정 50%만 적용하고 흐림 효과는 넣지 않았다.
  확장은 `overFullScreen`으로 떠서 뒤에 송신 앱과 OS 공유 시트가 보인다(원본 배경 이미지와 같은 구성).
- 준비·저장 중: 시트를 바로 띄우고 공유 내용을 저장 대기 공유로 보관한 뒤 저장 계정을 확인한다.
  그동안과 저장 중에는 모양 변화 없이 "저장하기"만 비활성으로 둔다.
- 완료: 시트가 내려가고 체크 벡터(원본 경로 그대로)와 "저장 완료!" 토스트(343×44 이상, `#1A1A1A`, 모서리 4)를 1.5초(임시값) 보인 뒤
  확장을 닫는다. VoiceOver에는 "저장 완료!"를 알린다. 토스트 중에도 배경 어둡게 처리는 남는다(원본과 같음).
- 닫기: 손잡이 끌어내림(시트 높이의 1/3 또는 빠른 끌기), 배경 탭, VoiceOver 닫기 동작(escape). 의미는 기존 "닫기"와 같다.
  저장 전이고 계정에 연결되지 않은 항목은 버리고, 저장 중이면 결과 미확인으로 남긴다.
  준비가 끝나기 전에 닫으면 이미지 받기를 취소하고, 늦게 보관된 항목은 버린 뒤 확장을 끝낸다.
- 임시 알림창(분류별 버튼은 #125): 받기 거절은 기존 제목 "공유할 수 없습니다"와 기존 문구, 저장 실패·로그인 필요는 제목 없이
  기존 문구를 시트 위 `UIAlertController`로 보인다. 버튼은 [닫기](`share.close`) 하나이며 위 닫기와 같은 보관 규칙을 따른다.
  저장 응답 401은 결정 Q3대로 시트를 남긴 채(저장하기 비활성) 알림창을 띄운다. 준비 단계 로그인 확인도 지금은 같은 방식이다.
- 접근성 식별자: `share.save`(유지), `share.sheet`, `share.dismiss`(배경, 화면 읽기 이름 "닫기"), `share.toast`, `share.close`(알림창 [닫기]).
- 다크 모드는 원본의 밝은 색으로 고정했다(결정 Q13).
- 테스트 송신 앱에 PNG 데이터를 6초 늦게 넘기는 `느린 스크린샷 공유`를 추가했다(결정 Q11, 테스트 전용).
  처음에는 같은 임시 파일을 늦게 넘겼으나 두 번째 공유에서 OS가 파일을 복사하지 못해 데이터 전달로 바꿨다.
- 공유 메뉴: 이름 "허투루"는 `233:3445`와 같다. 아이콘은 Flutter 기본 아이콘이라 `233:3437`과 다르며 바꾸지 않았다(결정 Q6).

### 회귀 테스트 예외

`testUnauthorizedDraftResumesInMainNativeModal`은 원래 401 뒤 알림창이 떠 있는 상태에서 `share.save`가 비활성인지 확인했다.
`UIAlertController`는 접근성 모달이라 그동안 XCUITest가 뒤의 `share.save`를 찾지 못해("No matches found") 무수정으로는 실패했다.
알림창을 접근성 비모달로 바꾸면 통과하지만 VoiceOver가 알림창 뒤를 탐색하게 되어 채택하지 않았다.
2026-10-31 사용자 승인으로 확장 쪽 한 줄(`ShareUITests.swift`의 `isEnabled` 확인)만 알림창 존재 확인으로 바꿨다.
본앱 복구 부분은 바꾸지 않았다. 새로 쓴 응답 유실·이미지 오류 테스트도 같은 방식으로 확인한다.

### 자동 검증

2026-10-31 KST, iPhone 16 Simulator(iOS 18.6, Xcode 27.2), 로컬 대역 서버. 대역은 저장소 `frontend/tool/share_fixture_server.py`를
그대로 import하고 카테고리에 `last_saved_at: null`만 더한 임시 래퍼로 실행했다(원본 대역으로는 본앱 홈과 공유 자격 발급이 막힘, 아래 후속).
운영 서버·실기기·실제 OAuth 검증이 아니다.

- 변경 전 앱으로 새 `testExternalLinkSaveReturnsToSenderWithoutMainApp`을 먼저 실행해 실패("저장" ≠ "저장하기")를 확인했다.
- `ShareUITests` 로컬 묶음 10개를 한 번에 실행해 8개 통과. 실패 2개는 테스트 쪽 문제였다.
  - 본앱 저장 대기 공유 수를 읽는 도우미가 안내 문구를 텍스트 요소로만 찾았는데, Flutter 접근성 트리에서는 다른 종류의 요소로 보여
    항상 0을 반환했다. 모든 종류의 요소에서 찾도록 고쳤다(이 때문에 이전의 "남지 않음" 비교는 의미가 없었다).
  - 준비 중 연속 탭이 시트가 올라오는 도중에 눌려 배경을 탭한 것으로 처리됐다. 시트가 멈춘 뒤 누르도록 고쳤다.
- 고친 뒤 앱을 새로 설치(저장 대기 공유 0개)하고 영향받은 `testImageQuotaAndFileLimitAppearInAlert`·
  `testPreparationDismissKeepsNothingAndRepeatedTapsSaveOnce`·`testDismissBeforeSaveKeepsNoPendingShare`와
  회귀 기준 `testUnauthorizedDraftResumesInMainNativeModal`을 다시 실행해 4개 모두 통과했다.
- 통과한 테스트와 확인 내용
  - `testExternalLinkSaveReturnsToSenderWithoutMainApp`, `testImageSaveAndUnsupportedInput`: 링크·이미지 시트 구성(제목·닫기 버튼·초안 삭제·저장 계정·공유 내용·미리보기 없음),
    "저장하기" → 토스트 "저장 완료!" → 송신 앱 복귀, `save_requests` 1회. 지원하지 않는 공유는 "공유할 수 없습니다" 알림창 [닫기].
  - `testDismissBeforeSaveKeepsNoPendingShare`: 링크 끌어내림·이미지 배경 탭 닫기 뒤 요청 0회, 저장 대기 공유 수 변화 없음.
  - `testPreparationDismissKeepsNothingAndRepeatedTapsSaveOnce`: 느린 이미지 준비 중 배경 탭 닫기 뒤 저장 대기 공유 수 변화 없음,
    준비 중 2회·저장 중 2회 추가 탭에도 요청 1회.
  - `testCloseDuringSaveRecoversWithoutDuplicateAndPreservesManualInput`(저장 중 끌어내림), `testSenderTerminationDuringSave…`:
    결과 미확인으로 보관 → 본앱 복구 화면 재시도에서 요청 2회·저장 1건(중복 없음), 본앱 수동 입력 유지.
  - `testSocketResponseLossRetriesWithoutDuplicate`, `testSocketTimeoutRetriesWithoutDuplicate`: 기존 문구 알림창 [닫기] 뒤 보관 →
    본앱 복구 화면에서 저장, 저장 1건·요청 2회.
  - `testImageQuotaAndFileLimitAppearInAlert`: 409 일시 중단·409 이미지 한도·413의 기존 문구 알림창, [닫기] 뒤 3건 모두 보관(변경 전과 같음),
    본앱 복구 화면에서 저장해 정리.
  - `testUnauthorizedDraftResumesInMainNativeModal`: 위 예외 한 줄 외 무수정으로 통과.
- `RunnerTests`(`xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner … test`, `frontend/ios/ShareVerification/README.md`의 명령) 19개 통과.
- 실행하지 않은 테스트: `testSafariSharesPreparedYouTubePage`·`testPhotosSharesPreparedScreenshot`(Safari 페이지·사진 보관함 사전 준비가 필요한
  별도 OS 앱 검증), `testRealBackend*` 4개(18766 포트 실제 백엔드·전용 DB 필요). 새 동작 기준으로 다시 썼지만 실행하지 않았다.

### 미검증과 후속

- 변경 전·변경 후·Figma 화면 비교, 시트 닫기·토스트 영상, 큰 글자·안전 영역 화면 확인은 통합 후 따로 수행한다.
- Android 코드는 바꾸지 않았다(`git diff -- frontend/android` 0줄). Android 시트는 #124다.
- 저장소 대역 서버는 카테고리에 `last_saved_at`이 없어 현재 본앱이 홈에 가지 못한다(범위 밖, 수정하지 않음).

## #124 Android 정상 흐름

- 티켓: [#124](https://github.com/clip-back/clipback/issues/124). 기준 커밋 `620cb82`(통합 브랜치 `feat/share-save-sheet`).
- Figma: 파일 `svNWsTFh8Ws1Mpt8XQIcrN` Page 1 `0:1`의 `233:3420`(시트)·`233:3430`(완료 토스트), 2026-10-31 13:30~13:32 KST 조회값.
  Android는 iOS 원본을 그대로 옮기는 것으로 2026-10-31 사용자가 승인했다. 단위는 Figma px = Android dp(글자는 sp)로 옮겼다.

### 구현

- 공유 메뉴(`ACTION_SEND`)의 `ShareActivity`를 공유 저장 시트로 새로 작성했다. 본앱 재개용 `ShareRecoveryActivity`는
  기존 전체 화면 코드를 그대로 옮겨 독립 클래스로 두었고, 공유 메뉴 전용 받기 경로(받기·받기 취소·추가 공유)만 뺐다.
  복구 화면의 문구·버튼·닫기 규칙·테마(`ShareTheme`)는 바꾸지 않았다. 시트는 새 반투명 테마 `ShareSheetTheme`를 쓴다.
- 시트: 폭 전체, 흰 배경, 위쪽 모서리 24, 손잡이 50×5(위 8, 모서리 완전 둥근, `#D1D1D1`), 손잡이 아래 내용 시작 32,
  좌우 16, **저장하기** 최소 높이 56(`#FFD75C`, 모서리 8, 글자 16 `#1A1A1A`), 버튼–안내 간격 16, 안내 14 `#767676` 가운데 정렬.
  제목·닫기 버튼·초안 삭제·저장 계정·공유 내용 문구·이미지 미리보기·상태 문구는 없다. 링크·이미지가 같은 시트를 쓴다.
- 글꼴(Q1): 같은 APK의 Flutter 자산 `flutter_assets/assets/fonts/Pretendard-SemiBold.otf`·`Pretendard-Medium.otf`를
  `Typeface.createFromAsset`으로 읽어 APK 용량을 늘리지 않았다. 자간은 Figma -2.5%를 `letterSpacing -0.025em`으로,
  행간은 글꼴 기본(`includeFontPadding=false`)으로 옮겼다.
- 하단 여백(Q2): 시트 안내 아래와 토스트 아래 여백은 `max(32dp, 하단 시스템 인셋)`이다. Figma는 화면 하단에서 32이며
  내비게이션·제스처 영역과의 관계가 없으므로, 인셋이 32dp보다 큰 기기에서는 원본보다 여백이 커진다.
  좌우 시스템 인셋은 16에 더한다. 큰 글자 배율에서는 버튼·안내가 줄바꿈·높이 확장으로 시트를 위로 늘린다.
- 배경: 화면 전체에 검정 50%를 깔고, Android 12(API 31) 이상에서 `FLAG_BLUR_BEHIND` + 흐림 반경 2dp를 요청한다.
  OS 창 흐림이 꺼진 기기(절전·설정·GPU 미지원)와 Android 11 이하는 어둡게 처리만 보이며 원본의 흐림 2px와 다르다.
- 상태: 시트는 받기 시작과 함께 바로 뜨고(배경 페이드 + 시트 올라옴 250ms), 공유 내용을 기기에 보관하는 동안과 저장 중에는
  모양 변화 없이 **저장하기**만 비활성이다. 보관이 끝나면 저장 계정을 확인하고, 로그인이 필요하면 시트를 내린 뒤 알림창을 띄운다.
- 완료: 시트가 내려가고 Activity 안에 그린 토스트(343×44 기준, `#1A1A1A`, 모서리 4, 체크 벡터 20×20 `#FFD75C` 선 1.67,
  간격 8, "저장 완료!" 16 `#FFD75C`)를 1.5초(디자인에 값이 없는 임시값) 보여 준 뒤 배경과 함께 사라지며 창을 닫는다.
  시스템 `Toast`는 쓰지 않는다. 화면 읽기에는 "저장 완료!"를 알리고 체크 아이콘은 장식으로 둔다.
- 닫기: 손잡이·시트 빈 곳을 시트 높이의 1/4 넘게 끌어내리거나, 어두운 배경을 누르거나, 뒤로가기로 닫는다.
  배경은 화면 읽기에서 "공유 닫기"로 읽힌다. 닫기 의미는 기존과 같다: 저장 전 미연결 항목은 버리고, 저장 중이면 결과 미확인으로
  보관하며, 보관이 끝나기 전이면 받기를 취소하고 늦게 보관된 항목도 버린다. 재생성 후에도 같다.
- 비정상 상태(임시): 로그인 필요·저장 실패·받기 거절·보관 실패 등은 OS `AlertDialog`에 기존 문구와 [닫기]만 보여 준다.
  [닫기]와 알림창 취소(뒤로가기·바깥 탭)는 위 닫기와 같아 보관 상태가 변경 전과 같다. 분류별 버튼·문구·폐기는 #126에서 다룬다.
  재생성 시 알림창 문구와 완료 여부를 복원한다.
- 추가 공유 시스템 Toast("새 공유를 대기 항목에 보관했습니다…")는 유지했다.
- 색은 Figma 밝은 값으로 고정했다. 다크 모드 변형은 원본이 없다(Q13).
- 테스트 식별자: 뷰 태그 `share.save`(저장하기), `share.sheet`, `share.background`, `share.toast`.
- 공유 메뉴 아이콘·이름(`233:3437`·`233:3445`): 이름은 매니페스트 `android:label="허투루"`로 일치한다.
  아이콘은 Flutter 기본 아이콘으로 원본과 다르며 바꾸지 않았다(Q6).

### 자동 검증

2026-10-31 로컬 대역 검증이다. 실기기·운영 서버·실제 OAuth는 검증하지 않았다.

- 환경: Android Emulator `Medium_Phone`(API 36, 1080×2400) · `Clipback_Share_API_33`(API 33, 1080×2220, `-gpu swiftshader`),
  두 AVD 모두 `adb shell wm disable-blur` 결과 "Blur supported on device: true / Blur enabled: true".
  대역은 `frontend/tool/share_fixture_server.py`를 카테고리 `last_saved_at`만 보충하는 로컬 래퍼로 실행했다(저장소 파일 무변경).
- 빌드·실행 명령은 [Android 공유 검증](../../frontend/android/SHARE_TESTING.md)과 같다(`frontend/android`에서 `./gradlew :app:assembleDebug :app:assembleDebugAndroidTest …`,
  `adb shell am instrument -w -e class …ShareStoreTest,…ShareActivityTest,…ShareServiceFixtureTest`).
- 실패 먼저 확인: 새 테스트를 기존 구현으로 API 36에서 실행해 시트·`share.save`가 없어 실패하는 것을 확인했다.
- 테스트 경계는 기존 `ShareActivityTest`(11개)·`ShareServiceFixtureTest`(14개)·`ShareStoreTest`(15개)다.
  - 다시 쓴 기존 화면 전제 테스트: 로그인 필요 재생성·[닫기](알림창), 추가 공유 보관, 저장 직후 배경 탭 닫기.
  - 추가: 시트 문구(저장하기·안내만), 저장 전 끌어내림·배경 탭·뒤로가기·재생성 후 끌어내림, 준비 중 닫기(링크·이미지),
    링크(준비·저장 중 연속 탭 포함)·이미지 저장 → 완료 토스트 → 창 종료와 `save_requests` 1회, 저장 중 재생성 후 닫기 → 결과 미확인 보관 → 같은 키 재시도 중복 없음,
    500·401 알림창 [닫기] 후 보관 상태 유지.
  - 회귀 기준 `testRecoveryHostReturnsWithoutDiscardingAuthRequiredDraft`와 복구 Activity 이미지 오류 3개는 고치지 않았고 통과했다(Q12).
- 결과(최종 구현): 새로 쓰거나 추가한 시트 테스트와 회귀 기준은 아래 실행에서 모두 통과했다.
  - API 33 전체 40개: 1회차 39개 통과·1개 실패, 2회차 40개 통과.
  - API 36: 전체 40개 실행 세 번 중 한 번은 39개 통과·1개 오류, 두 번은 39개 통과·1개 실패.
    `ShareActivityTest`+`ShareServiceFixtureTest` 25개 실행은 24개 통과·1개 실패, `ShareServiceFixtureTest` 단독 재실행은 14개 통과.
  - 실패는 모두 기존 서비스 테스트 `testAccountChangeDuringSubmittedRequestDoesNotShowSuccessForNewAccount`(테스트 코드 무변경)다.
    이 테스트는 대역이 저장을 커밋하고 2초 뒤 응답하는 동안 커밋을 폴링으로 확인하고 자격을 차단해야 한다.
    이번 호스트에서는 에뮬레이터→대역 HTTP 요청이 그 테스트만 실행할 때도 요청마다 약 1.0초씩 걸렸다(대역에 시각을 찍어 확인).
    그래서 폴링 두 번이 2초를 다 쓰고, 응답과 자격 차단 중 무엇이 먼저냐에 따라 통과·실패가 갈렸다.
    통과한 단독 실행에서도 자격 차단이 응답보다 5ms 앞섰을 뿐이다. 공유 저장 시트 코드는 이 경로(`ShareService`·`ShareStore`)를 바꾸지 않았다.
  - 오류 한 건은 대역 연결 시간 초과(`SocketTimeoutException`, 5초, 호스트 부하)였다.
- iOS 코드는 바꾸지 않았다(`git status --short -- frontend/ios` 변경 없음).

### 오케스트레이터 4단계에서 확인할 항목

- 변경 전·변경 후·Figma(`233:3420`/`233:3430`) 비교 스크린샷(API 36, API 33)과 시트 닫기·완료 토스트 영상
- 실제 시스템 공유 목록에서 허투루 선택 → 시트 → 저장 → 토스트 → 송신 앱 복귀, 끌어내림·배경 탭·뒤로가기 닫기
- 큰 글자 배율에서 시트가 위로 늘어나 잘리지 않음, 하단 안전 영역·제스처 내비게이션 여백, 회전 재생성
- 에뮬레이터의 흐림 적용 여부와 원본 차이

## #125 iOS 실패 분류

티켓 [#125](https://github.com/clip-back/clipback/issues/125), 브랜치 `feat/share-save-sheet-125-ios`, 기준 커밋 `6991d6c`(통합 브랜치).
#123의 임시 알림창(기존 문구·[닫기]만)을 #122 분류표의 버튼·문구·보관/폐기로 바꿨다. 새 시각 디자인 없이 `UIAlertController`만 쓴다
(전용 표현은 [디자인 확인 필요](../figma-ui-alignment-plan.md#figma-pending-share-alerts)).

### 구현

- 분류 전달(결정 Q4): `ShareCore`의 `ShareFailure`가 분류(`ShareFailureKind`, 받기 거절은 사유 `ShareRefusal`)와 기존 문구를 함께 넘긴다.
  본앱 복구 화면은 지금처럼 기존 문구(`localizedDescription`)를 보여 주므로 동작·문구가 바뀌지 않는다. 공유 저장 시트만 분류로 새 문구를 고른다.
- 문구는 #126과 같은 표를 쓴다([문구표 요약](#문구표-요약)). iOS는 [허투루 열기]가 없어 그 행에서 [닫기]만 두며,
  Android 전용 행(재생성 때 결과 미확인 항목)은 없다. 받기 거절의 사유별 문장은 iOS 받기 경로에 다음처럼 대응한다.
  - 항목이 하나가 아님 → "링크 하나 또는 이미지 한 장만 공유할 수 있습니다."
  - 텍스트 5,000자 초과·링크 없음·서로 다른 링크 두 개 이상 → "공유 텍스트가 너무 깁니다."·"Instagram 또는 YouTube 링크를 공유해 주세요."·"한 번에 링크 하나만 공유해 주세요."
  - 지원하지 않는 주소·포트·사용자 정보·길이·스킴 → "Instagram 또는 YouTube 링크만 저장할 수 있습니다."
  - 공유한 이미지 파일을 읽지 못함 → "이미지를 읽을 수 없습니다.", 10MiB 초과 → "이미지는 10MiB 이하만 공유할 수 있습니다."
  - PNG·JPEG·WebP 아님 → "PNG, JPEG, WebP 이미지만 지원합니다. HEIC와 동영상은 지원하지 않습니다.", 이미지 해석 실패 → "이미지 파일을 읽을 수 없습니다."
  - 링크·텍스트 항목 읽기 실패와 그 밖의 형식 → "Instagram·YouTube 링크 또는 PNG·JPEG·WebP 이미지를 공유해 주세요."
- 순서: 시트 표시 → 공유 내용 보관 → 보관을 마친 뒤 로그인 확인. 준비 단계 실패(받기 거절·보관 실패)는 보관 전에 끝나므로 로그인 필요보다 먼저 보인다.
  - 준비 단계 로그인 필요(저장 계정 없음·만료·자격 읽기 실패, Q9②)는 시트를 내린 뒤 알림창을 띄운다.
  - 저장 응답 401과 저장 시점 자격 만료는 결정 Q3대로 시트를 남긴 채("저장하기" 비활성) 알림창을 띄운다.
- 버튼: [닫기](`share.close`, 취소 형식)와 다시 시도 가능 분류의 [다시 시도](`share.retry`). [허투루 열기]는 없다(공식 API 없음).
  [다시 시도]는 같은 저장 대기 공유를 같은 `Idempotency-Key`로 다시 보낸다.
- [닫기]: 되돌릴 수 없음(410·409·413)은 저장 대기 공유를 버리고 닫는다. 나머지는 #123의 닫기 규칙 그대로라, 한 번 전송했거나
  로그인 필요로 표시한 공유는 남고 준비 단계 실패는 남길 것이 없다.
- 다시 시도 가능 실패 때 저장 계정이 이미 바뀌었으면(revision·userId·sessionId 비교) [다시 시도] 대신 '현재 환경에서 재시도 불가' 알림창을 보인다.
  [다시 시도]를 눌렀더라도 저장소의 기존 계정 경계가 새 계정으로 보내지 않는다.
- 분류 근거(결정 Q9): 그 밖의 4xx(403·404·429 등)는 400/415/422와 같은 다시 시도 가능, App Group 열기·잠금 실패와 쓰기 실패는 보관 실패,
  항목 없음은 '공유 항목이 없어요'. 공유한 이미지 파일을 읽지 못하면 받기 거절 "이미지를 읽을 수 없습니다."다.
  전송 전 기기 안 오류는 Android와 같은 "지금 저장하지 못했어요…" 행을 쓴다.
- 저장 규칙·서버 API는 바꾸지 않았다. 예외는 spec이 정한 '되돌릴 수 없음'의 [닫기] 시 폐기뿐이다.

### 자동 검증

2026-10-31 KST, iPhone 16 Simulator(iOS 18.6, Xcode 27.2), 로컬 대역 서버. 대역은 #123과 같은 임시 래퍼(저장소
`frontend/tool/share_fixture_server.py`를 import하고 카테고리에 `last_saved_at: null`만 더함)로 실행했다. 앱은 새로 설치해
저장 대기 공유 0개에서 시작했다. 운영 서버·실기기·실제 OAuth 검증이 아니다. 명령은 [iOS 공유 검증](../../frontend/ios/ShareVerification/README.md)과 같다.

- 실패 먼저 확인: 테스트만 바꾼 상태(#123 구현)로 앱을 빌드해 새 `testImageSaveAndUnsupportedInput`·`testServerErrorRetriesWithoutDuplicate`가
  분류 알림창 제목을 찾지 못해 실패하는 것을 확인했다. 새 `RunnerTests`는 같은 상태의 소스로 `swiftc` 타입 검사를 해 분류 타입이 없어 컴파일되지 않는 것을 확인했다.
- `RunnerTests` 24개 통과(#123의 19개 + 새 5개).
  - 받기 거절 사유·기기 보관 한도 분류, 저장 시점 항목 없음·계정 변경·다른 서버 환경·자격 없음 분류.
  - HTTP 응답별 분류와 기존 문구·상태 유지(응답 유실·500·2xx 해석 실패·400·415·422·403·429·409 일시 중단·409 이미지 한도·410·409·413·401).
    복구 화면이 보는 기존 문구가 그대로인지 함께 확인한다.
  - 저장 중 계정 변경: 전송 전 변경은 보내지 않고 보관, 전송 뒤 실패는 원래 계정으로 보관되고 원래·새 계정 어느 쪽으로 다시 보내도 요청이 나가지 않음,
    2xx 뒤 변경은 원래 계정 저장으로 끝남(Q7). 대역이 항상 같은 계정을 발급해 UI 테스트로는 계정 변경을 만들 수 없어 이 단위 테스트로 대신했다.
- `ShareUITests` 로컬 묶음 14개를 한 번에 실행해 모두 통과(1,252초).
  - 새로 쓰거나 추가: `testSocketResponseLossRetriesWithoutDuplicate`·`testSocketTimeoutRetriesWithoutDuplicate`·`testServerErrorRetriesWithoutDuplicate`·
    `testUnprocessableLinkRetriesWithoutDuplicate`(각각 [다시 시도] → 완료 토스트 → 저장 1건·요청 2회, [닫기] → 본앱 복구 화면 저장 → 저장 1건·요청 2회),
    `testSignedOutShareIsKeptBeforeLoginAlertAndResumesInMain`(401로 자격이 막힌 뒤 공유하면 요청 없이 보관되고 로그인 필요 알림창, 본앱 복구 화면에서 저장),
    `testDeviceStorageFullKeepsNothingAndNeverSaysKept`(10개 보관 뒤 공유하면 보관 실패 알림창, "보관했습니다" 없음, 보관 수 10 유지, 쌓은 공유는 복구 화면에서 저장),
    `testServerRejectionsRetryKeepOrDiscardByCategory`(일시 중단 [다시 시도] 저장, 이미지 한도 [닫기] 보관 후 복구, 410·409·413 [닫기] 뒤 남지 않음),
    `testImageSaveAndUnsupportedInput`(받기 거절 "공유할 수 없어요" [닫기] 뒤 보관 수 변화 없음).
  - 모든 알림창에서 제목·문구·버튼 수, [허투루 열기] 없음, "초안 삭제"·"초안을 삭제"·"같은 초안으로"가 없음을 확인한다.
  - 회귀 기준 `testUnauthorizedDraftResumesInMainNativeModal`은 #123에서 승인한 한 줄 예외 상태 그대로 고치지 않고 통과했다.
  - 알림창은 접근성 모달이라 준비 단계 로그인 필요에서 "시트가 내려간 뒤" 알림창이 뜨는지는 XCUITest로 구분할 수 없다(알림창 뒤 요소를 찾지 못함). 화면 확인으로 남긴다.
- 실행하지 않은 테스트: `testSafariSharesPreparedYouTubePage`·`testPhotosSharesPreparedScreenshot`(OS 앱 사전 준비 필요),
  `testRealBackend*` 4개(18766 실제 백엔드 필요). 실제 백엔드 이미지 오류 테스트는 새 알림창 기준으로 고쳤지만 실행하지 않았다.
- Android 코드는 바꾸지 않았다(`git diff 6991d6c -- frontend/android` 0줄).

### 미검증과 후속

- 분류별 알림창 스크린샷(변경 전 상태 영역 화면과 나란히, Figma 원본 없음 명시)은 통합 후 따로 남긴다.
- 대역 서버의 `last_saved_at` 누락은 #123과 같이 범위 밖으로 두었다.

## #126 Android 실패 분류

- 티켓: [#126](https://github.com/clip-back/clipback/issues/126). 기준 커밋 `f930ec1`(통합 브랜치 `feat/share-save-sheet`, #124 포함).
- 범위: #124가 임시로 기존 문구와 [닫기]만 보여 주던 Android 공유 저장 시트의 OS 알림창을 #122 분류별 제목·문구·버튼과
  보관/폐기 동작으로 바꿨다. 새 시각 디자인은 없다(`AlertDialog`만 사용). iOS 코드와 본앱 복구 화면은 바꾸지 않았다.

### 구현

- 분류 전달(Q4): 저장소·서비스는 새 `ShareFailure`(분류 + 기존 문구)를 던지거나 넘긴다. 복구 화면(`ShareRecoveryActivity`)은
  리스너 기본 동작으로 기존 문구를 그대로 받고, 공유 저장 시트만 분류의 새 제목·문구를 쓴다.
- 버튼: [다시 시도]는 같은 저장 대기 공유를 같은 `Idempotency-Key`로 다시 보낸다. [허투루 열기]는 앱의 실행 Intent로 본앱을 열고
  공유 창을 [닫기]와 같은 결과로 닫는다. 알림창 취소(뒤로가기·바깥 탭)는 [닫기]와 같다. 버튼 뷰 태그는
  `share.alert.close`·`share.alert.retry`·`share.alert.open`이다.
- [닫기] 시 보관/폐기: 되돌릴 수 없음(410·409·413)은 저장 대기 공유를 지운다. 그 밖에 알림창이 뜬 공유는 남기고,
  알림창 없이 저장 전에 닫은 미연결 공유만 기존처럼 버린다. 받기 거절·보관 실패는 보관된 것이 없다.
- 순서: 보관을 마친 뒤 로그인을 확인하고, 필요하면 시트를 내린 뒤 알림창을 띄운다. 받기 거절·보관 실패는 보관 전에 나므로
  로그인 필요보다 먼저 보인다. 저장 실패 알림창은 시트 위에 뜬다.
- 재생성: 저장 대기 공유가 있는 상태의 알림창은 분류와 문구를 저장해 같은 알림창을 다시 띄운다(재생성 뒤 [닫기]·뒤로가기 결과 동일).
  보관 전 알림창(받기 거절·보관 실패)은 같은 공유를 다시 받아 같은 알림창을 띄운다.
- 저장 중 계정 변경: 다시 시도 가능 분류의 실패가 났을 때 저장 계정이 이미 바뀌었으면 '현재 환경에서 재시도 불가'로 안내해
  [다시 시도]가 새 계정으로 보내지 못하게 했다. 서버 2xx로 원래 계정 저장을 확인한 경우는 기존처럼 완료 처리한다(Q7).
- 추가 공유 실패 Toast는 아래 표의 본문을 쓴다. 추가 공유 성공 Toast는 그대로다.

### 문구표 요약

iOS #125와 같은 표를 쓴다(분류별 iOS 원문 기준, 시트에 없는 동작만 고침, 받기 거절은 Android 상세 사유, Q5).
버튼 순서는 OS 기본 배치(긍정 = [다시 시도]/[허투루 열기], 부정 = [닫기])다. iOS에는 [허투루 열기]가 없다.

| 분류 | 제목 | 본문(대표) | 버튼(Android) | [닫기] 시 |
| --- | --- | --- | --- | --- |
| 받기 거절 | 공유할 수 없어요 | 사유별 기존 Android 문장(예: "Instagram 또는 YouTube 링크만 저장할 수 있습니다.", "이미지는 10MiB 이하만 공유할 수 있습니다.") | [닫기] | 보관된 것 없음 |
| 보관 실패(한도) | 보관하지 못했어요 | 보관 중인 공유가 가득 찼어요. 허투루 앱에서 저장 대기 공유를 저장하거나 삭제한 뒤 다시 공유해 주세요. | [허투루 열기] [닫기] | 보관된 것 없음 |
| 보관 실패(쓰기) | 보관하지 못했어요 | 공유 내용을 보관하지 못했어요. 다시 공유해 주세요. | [닫기] | 보관된 것 없음 |
| 로그인 필요 | 로그인이 필요해요 | 초안을 보관했습니다. 허투루 앱을 열어 로그인을 확인한 뒤 대기 항목을 선택해 주세요. | [허투루 열기] [닫기] | 보관 |
| 다시 시도 가능 | 저장하지 못했어요 | 저장 결과를 확인하지 못했습니다. 다시 시도해도 중복 저장되지 않습니다. / 이미지 저장 일시 중단 기존 문구 / 400·415·422: "지금 링크 정보를 확인하지 못했어요. …" / 전송 전 기기 오류: "지금 저장하지 못했어요. 잠시 후 다시 시도해 주세요." | [다시 시도] [닫기] | 보관 |
| 나중에 이어서 | 지금은 저장할 수 없어요 | 이미지 보관 한도에 도달했어요. 기존 이미지를 삭제한 뒤 다시 저장해 주세요. | [닫기] | 보관 |
| 현재 환경에서 재시도 불가 | 저장 환경이 바뀌었어요 | 저장 계정이 변경되었습니다. 이 창을 닫고 저장할 계정을 확인해 주세요. / 다른 서버 환경: "이 초안은 다른 서버 환경에서 전송되었습니다. 같은 서버 환경의 허투루 앱에서 다시 저장해 주세요." / 2xx 뒤 계정 변경: "전송한 계정의 저장 결과는 보관했습니다. 계정이 변경되어 이 창을 닫아 주세요." | [닫기] | 보관(2xx 뒤 계정 변경은 이미 저장되어 남는 항목 없음) |
| 되돌릴 수 없음 | 다시 저장할 수 없어요 | 410 "이미 저장한 뒤 삭제한 콘텐츠입니다. 새로 공유해 주세요." / 409 "이 초안의 저장 정보가 일치하지 않습니다. 다시 공유해 주세요." / 413 "이미지는 10MiB 이하만 저장할 수 있습니다." | [닫기] | 버림 |
| 항목 없음 | 공유 항목이 없어요 | 보관 기간이 지났거나 삭제된 초안입니다. | [닫기] | 남은 것 없음 |

- 고친 표현: "같은 초안으로 다시 시도…" → [다시 시도]에 맞춘 문장, "이 초안을 삭제한 뒤"·"초안을 삭제한 뒤" 삭제,
  다른 서버 환경의 "다시 시도해 주세요" → "허투루 앱에서 다시 저장해 주세요"(이 분류에는 [다시 시도]가 없다).
- 로그인 필요 문구는 iOS 회귀 테스트가 고정한 원문을 그대로 썼다. "초안"·"대기 항목"은 용어집 지양 표현이지만 원문 고정 때문에 유지했다.
- 바꾸지 않은 문구: 닫기 처리 중 기기 저장 실패 "초안을 보관하지 못했습니다. 다시 시도해 주세요."와 본앱 복구 화면 문구 전부.

### 분류표에 없는 상황의 근거(Q9)

2026-10-31 사용자 확정(Q9)을 따랐다.

- 기타 4xx(403·404·429 등): 다시 시도 가능. 서버가 일시 오류와 영구 오류를 나누지 않으므로 400/415/422와 같게 보관한다.
  본문도 iOS가 같은 그룹으로 묶던 400/415/422 문구를 쓴다. 5xx는 응답 유실과 같은 '결과 미확인' 문구다.
- 보관 후 공유 자격(키스토어) 읽기 실패: 로그인 필요. 공유는 이미 보관됐으므로 "보관했습니다"가 사실이고, 본앱에서 자격을 다시 준비하면 이어 저장할 수 있다.
- 기기 저장소 열기·잠금·쓰기·정리 실패: 보관 실패(쓰기). Android는 받기 중 `ShareInput`의 거절 사유가 아닌 모든 예외가 해당한다.
- 이미지 URI 권한·읽기 실패: 받기 거절("이미지를 읽을 수 없습니다."). 보내는 앱이 준 입력을 읽지 못한 것이며 영문일 수 있는 시스템 문구를 그대로 보이지 않는다.
- 항목 없음(보관 기간 만료 등): 남은 것이 없으므로 기존 문구와 [닫기]만 둔다(문구는 iOS 원문).
- 프로세스 종료 뒤 같은 공유 창이 결과 미확인(`sending`이었다가 요청이 없어진) 항목으로 다시 열리면: 다시 시도 가능 알림창을 띄운다.
- 그 밖에 전송 전 기기 안에서 난 예외(보관 이미지 읽기 실패 등, Android 전용 경로): 다시 시도 가능. 공유는 보관되어 있고 아직 보내지 않았으므로
  "결과를 확인하지 못했다"고 하지 않고 기존 Android 문구에서 "같은 항목으로"만 뺐다.

### 자동 검증

2026-10-31 로컬 대역 검증이다. 실기기·운영 서버·실제 OAuth는 검증하지 않았다.

- 환경: Android Emulator `Medium_Phone`(API 36, 1080×2400) · `Clipback_Share_API_33`(API 33, 1080×2220, `-gpu swiftshader`).
  대역은 #124와 같은 로컬 래퍼(카테고리 `last_saved_at`만 보충, 저장소 파일 무변경)로 실행했다. 빌드·실행 명령은
  [Android 공유 검증](../../frontend/android/SHARE_TESTING.md)과 같고 두 API에 같은 APK를 설치했다.
- 테스트 경계: `ShareActivityTest`(15개)·`ShareServiceFixtureTest`(28개)·`ShareStoreTest`(15개).
  - `ShareActivityTest`: 보관 후 로그인 필요(재생성 뒤 [닫기] 보관, [허투루 열기]가 본앱 실행을 요청하고 창을 닫음),
    기기 보관 한도(자격 없음에서도 보관 실패가 우선, "보관했" 문구 없음, [허투루 열기], 재생성 뒤 뒤로가기 시 보관 없음),
    받기 거절 [닫기] 뒤 보관 없음. 알림창은 제목·본문·버튼 목록을 접근성 트리로 확인한다.
  - `ShareServiceFixtureTest`: 500·422·응답 유실 [닫기] 보관 + 같은 키 저장 1회, 500·422·응답 유실·30초 제한 [다시 시도] 뒤
    완료 토스트와 대역 `saved` 1 증가, 서버 이미지 한도 [닫기] 보관, 401 로그인 필요, 저장 중 계정 변경 → 재시도 불가 [닫기] 보관
    (원래 계정 `userId`, 저장 요청 1회), 410·409·413 [닫기] 폐기, 재생성 뒤 뒤로가기(410 폐기·500 보관),
    재생성 때 결과 미확인 항목 → [다시 시도] 저장 1회.
  - 다시 쓴 #124 임시 테스트: 로그인 필요 재생성(새 문구·버튼), 500·401 알림창(새 문구). 회귀 기준
    `testRecoveryHostReturnsWithoutDiscardingAuthRequiredDraft`와 복구 Activity 이미지 오류 3개는 고치지 않았다.
- 실패 먼저 확인: 새로 쓰거나 바꾼 9개를 기존 구현으로 API 36에서 실행해 9개 모두 분류 알림창·문구가 없어 실패하는 것을 확인했다.
- 결과(최종 구현): API 36 전체 58개 통과(360초), API 33 전체 58개 통과(339초).
  #124에서 불안정했던 `testAccountChangeDuringSubmittedRequestDoesNotShowSuccessForNewAccount`도 이번 두 실행에서는 통과했다(테스트 무변경).
- 통합 브랜치(#123) 병합 뒤 다시 빌드한 API 33 전체 실행은 58개 중 57개 통과했다. 실패 1개는 위 불안정 테스트로, 단독 재실행 두 번은
  1번 통과·1번 실패였다. 대역 응답과 자격 차단의 선후에 따라 갈리는 #124 기록의 원인과 같으며(2xx 저장 경로는 이번에 바꾸지 않음) 고치지 않았다.
  병합으로 Android 코드는 바뀌지 않아 API 36은 병합 전 결과를 기준으로 한다.
- iOS 코드는 바꾸지 않았다(이 티켓 커밋의 `git show --stat -- frontend/ios` 변경 없음. 통합 브랜치 병합으로 들어온 #123 변경은 제외).

### 오케스트레이터 4단계에서 확인할 항목

- 분류별 알림창 스크린샷(API 36, API 33)을 변경 전 상태 영역 화면과 나란히 둔다. Figma 원본은 없다.
  대역 제어로 띄우는 방법은 [Android 공유 검증](../../frontend/android/SHARE_TESTING.md#시스템-공유-창과-화면-증거)의 표를 따른다.
- [허투루 열기] 이동 영상: 로그인 필요(자격 없는 상태로 공유)와 기기 보관 한도 초과에서 본앱이 열리고 공유 창이 닫히는지,
  로그인 뒤 "저장 대기 중인 공유 N개 → 확인" 안내로 이어지는지 확인한다.
- [다시 시도] 뒤 완료 토스트, 알림창이 뜬 상태의 회전·뒤로가기, 큰 글자 배율에서 알림창 문구가 잘리지 않는지 확인한다.

## 통합 리뷰 수정

통합 브랜치 `feat/share-save-sheet`(`834cd7d`) 코드 리뷰 지적 F1~F6을 브랜치 `feat/share-save-sheet-review-fixes`에서 처리했다.
사용자 문구(코드 문자열)·저장 규칙·서버 API는 바꾸지 않았다. 닫기 실패 알림창의 버튼만 바뀌었다(F4).

### 처리

- F1(iOS #125, 저장 시작 전 실패 뒤 [닫기]가 보관할 공유를 지운다는 지적): 재현되지 않아 코드를 고치지 않았다.
  `ShareSaveService.save`는 전송 전 단계(`ShareStore.begin`의 로그인 필요·계정 변경·잠금 실패, 요청 준비, 전송 직전 계정 재확인)에서
  난 모든 실패를 완료 콜백 전에 `authRequired`로 기록한다(`e9f526a`부터 있던 동작). 그래서 알림창 [닫기] → `dismissSheet`의
  폐기 조건(`pending`이면서 `userId` 없음)에 걸리지 않고, 본앱 복구 화면에서 로그인 필요 공유로 이어 저장된다.
  기록 자체가 실패하면 상태가 `pending`으로 남지만, 같은 저장소 트랜잭션을 쓰는 `dismissSheet`의 항목 읽기도 함께 실패해 지우지 않는다.
  이 불변식을 `ShareSaveServiceTests`의 `testBlockedAccountNeverSubmitsRequest`(자격 차단 → 로그인 필요)·
  `testAccountSwitchBeforeSendKeepsDraftUnsent`(전송 전 계정 변경)에 상태 `authRequired` 확인으로 더했다. 수정 전 코드에서 통과했다.
  #125 절의 "전송 전 변경은 보내지 않고 보관"과 "[닫기]: … 로그인 필요로 표시한 공유는 남고"는 이 동작과 맞는다.
- F2(iOS #125, `saveAlert`의 `.refused`·`.storageFull`): 저장 단계에서는 올 수 없어 코드를 고치지 않았다. 두 분류는 받기 단계
  (`ShareStore.createLink`·`createImage`·`insert`, `ShareInputNormalizer`)에서만 만들어진다. 저장 단계의 오류 출처는
  `begin`(로그인 필요·계정 변경·항목 없음·다른 서버 환경, 저장소 잠금·읽기 실패는 분류 없음), 요청 준비(서버 주소 설정 `message`, 보관 이미지 읽기 실패),
  HTTP 응답 분류(결과 미확인·일시 중단·이미지 한도·410·409·413·그 밖의 4xx·401), `complete`(계정 변경)·전송 뒤 계정 변경뿐이다.
  `switch`가 모든 경우를 다뤄야 해서 두 분류가 분류 없는 오류와 같은 줄에 있을 뿐이다.
- F3(Android #126, `ShareActivity.bind()`의 모든 예외를 로그인 필요로 처리): Q9②대로 공유 자격(Keystore) 복호화 실패
  (`GeneralSecurityException`)만 로그인 필요로 둔다. 이때 시트를 내린 뒤 알림창을 띄우고, 사용자 ID가 없는 공유는 `authRequired`로 기록해
  본앱 복구 화면에서 닫아도 지워지지 않게 했다(자격 없음 경로와 같은 기록). 그 밖의 저장소 읽기·상태 기록·보관 파일 정리 실패는
  보관을 확인할 수 없으므로 보관 실패(쓰기 실패) "공유 내용을 보관하지 못했어요. 다시 공유해 주세요." [닫기]로 안내한다(Q9③).
  '전송 전 기기 안 오류'(다시 시도 가능)는 쓰지 않았다. 저장 계정을 읽기 전에 실패하면 [다시 시도]가 보낼 계정이 정해지지 않아
  '저장 계정 변경'으로 잘못 끝나기 때문이다. [닫기]는 기존 규칙대로 알림창이 뜬 공유를 지우지 않는다(남은 공유는 본앱에서 정리 가능).
- F4(Android #126, 닫기 처리 중 저장 실패 알림창의 반복): 문구 "초안을 보관하지 못했습니다. 다시 시도해 주세요."는 그대로 두고
  [다시 시도](닫기를 다시 시도)와 [닫기](공유 창 종료, 기기에 남은 항목은 그대로)로 나눴다. 알림창 취소(뒤로가기·바깥 탭)는 [닫기]와 같다.
  #126 절의 '바꾸지 않은 문구'는 문구 기준으로 여전히 맞다.
- F5(문서): `docs/frontend/behavior.md`의 이번 변경 문장 "대기 항목"을 "저장 대기 공유"로 바꾸고 F3·F4 동작을 더했다.
  `docs/figma-ui-alignment-plan.md`의 `figma-current-share-save-sheet` 행을 iOS·Android 공통 기준(Android 배경 흐림 조건·복구 화면 포함)으로
  고치고, 이 행을 가리키는 '디자인 확인 필요' 행의 링크 이름을 "공유 저장 시트 기준"으로 바꿨다(앵커 유지).
  `frontend/android/SHARE_TESTING.md`에 새 테스트 범위를 적었다.
- F6(iOS, 사소): `ShareViewController`에서 네 번 반복된 시트 내림 변환을 `lowerSheet()`로 묶었다(동작 무변경).

### 자동 검증

2026-10-31 KST 로컬 대역 검증이다. 대역은 앞 절과 같은 임시 래퍼(카테고리 `last_saved_at: null`만 보충, 저장소 파일 무변경)로 실행했다.
운영 서버·실기기·실제 OAuth는 검증하지 않았고, 화면 비교 스크린샷은 통합 후 따로 남긴다.

- 재현 테스트(수정 전 코드에서 먼저 실행)
  - Android API 36 `ShareActivityTest`의 새 3개가 모두 실패했다. `testUnreadableCredentialAfterKeepingIsLoginRequired`(Keystore 키 삭제 →
    로그인 필요 알림창 뒤 시트가 내려가지 않음), `testStorageFailureAfterKeepingIsStorageFailure`(자격 차단·저장소 폴더 쓰기 금지 뒤 재생성 →
    보관 실패 대신 로그인 필요 알림창), `testCloseStorageFailureOffersRetryAndClose`(쓰기 금지 상태의 뒤로가기 → [다시 시도] 없음, [닫기]가 같은 알림창 반복).
    수정 뒤 3개 통과.
  - iOS `RunnerTests/ShareSaveServiceTests`에 더한 상태 확인 2개는 수정 전 코드에서 통과했다(F1 비재현 근거).
- iOS: iPhone 16 Simulator(iOS 18.6, Xcode 27.2). F6 반영 뒤 `RunnerTests` 24개 통과, `ShareUITests` 로컬 묶음 14개 통과(1,260초).
  회귀 기준 `testUnauthorizedDraftResumesInMainNativeModal`은 승인된 한 줄 예외 상태 그대로 통과했다.
- Android: 같은 APK로 `Medium_Phone`(API 36) 61개 통과(366초), `Clipback_Share_API_33`(API 33, `-gpu swiftshader`) 61개 통과(339초).
  `ShareStoreTest`·`ShareActivityTest`·`ShareServiceFixtureTest` 전체이며 앞 절의 58개에 새 3개를 더했다.
  불안정 테스트 `testAccountChangeDuringSubmittedRequestDoesNotShowSuccessForNewAccount`와 회귀 기준
  `testRecoveryHostReturnsWithoutDiscardingAuthRequiredDraft`는 두 실행 모두 통과했다.
- 두 플랫폼 장치는 동시에 띄우지 않았다(iOS 종료 후 API 36, 그 뒤 API 33).

### 범위 밖으로 남긴 것

- iOS 준비 단계의 로그인 확인(`prepared`)은 `try? store.currentCredential()`이라 공유 자격 읽기 실패뿐 아니라 저장소 잠금·상태 파일 읽기 실패도
  로그인 필요로 안내한다. Android F3과 같은 구분은 이번 지적 범위가 아니어서 바꾸지 않았다.
- Android 닫기 실패 알림창은 Activity 재생성 뒤 다시 띄우지 않는다(이번 변경 전과 같음).
