# 공유 저장 시트와 완료 토스트 구현·검증

최초 기록일: 2026-10-31 KST. 통합 브랜치는 `feat/share-save-sheet`(시작 `620cb82`)이다.
실행 기준은 [명세 #122](https://github.com/clip-back/clipback/issues/122)와 티켓별 절의 티켓이다.
현재 동작 기준은 [Figma 화면 맞춤 계획](../figma-ui-alignment-plan.md#figma-current-share-save-sheet)과
[모바일 공유 저장](../frontend/behavior.md#모바일-공유-저장)을 따른다.

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
