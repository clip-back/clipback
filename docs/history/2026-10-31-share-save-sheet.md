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
