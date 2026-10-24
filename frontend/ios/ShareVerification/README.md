# iOS 공유 검증

`ShareVerification.xcodeproj`는 제품 앱에 포함되지 않는 UIKit 송신 앱과 XCTest UI 테스트다.
시스템 공유 목록에서 `허투루`를 선택하고 실제 Share Extension 프로세스와 URLSession을 사용한다.
`RunnerTests`는 App Group 저장소·공유 Keychain·계정 revision·HTTP 실패 복구를 검사한다.

## 로컬 fixture 준비

저장소의 `frontend/`에서 별도 터미널로 `python3 tool/share_fixture_server.py`를 실행한다.
아래 명령의 `IOS_DEVICE`에는 `xcrun simctl list devices available`에서 확인한 iOS Simulator UDID를 넣는다.
한 번 준비한 뒤 본앱에서 공유 자격이 발급되어야 본앱 종료 상태의 확장 저장을 시험할 수 있다.

```bash
export IOS_DEVICE='<iOS Simulator UDID>'
flutter build ios --simulator --debug --no-pub \
  --dart-define=CLIPBACK_API_BASE_URL=http://127.0.0.1:18765/api/v1 \
  -t test/support/share_preview.dart
xcrun simctl install "$IOS_DEVICE" build/ios/iphonesimulator/Runner.app
xcrun simctl launch "$IOS_DEVICE" com.huturu.app
```

fixture 진입점은 loopback 테스트 API를 필수로 요구하며 운영 서버로 대체하지 않는다.
기본 fixture는 메모리 본앱 세션으로 기존 복원 흐름을 실행하고, 네이티브 공유 자격은 실제 공유 Keychain에 저장한다.

## 네이티브 단위 테스트

위 fixture 빌드 직후 같은 `frontend/`에서 실행한다. Xcode가 `Generated.xcconfig`의 fixture 진입점과 API 설정을 사용한다.

```bash
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
  -configuration Debug -sdk iphonesimulator -destination "id=$IOS_DEVICE" \
  -jobs 2 -parallel-testing-enabled NO \
  -clonedSourcePackagesDirPath "$(pwd)/build/ios/SourcePackages" \
  -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile \
  BUILD_DIR="$(pwd)/build/ios" FLUTTER_SUPPRESS_ANALYTICS=true \
  COMPILER_INDEX_STORE_ENABLE=NO test
```

## 실제 공유 UI 테스트

아래 일곱 테스트가 로컬 fixture 검증 묶음이다. 30초 timeout은 서버 응답을 35초 지연시키고,
응답 유실과 timeout 모두 동일 초안 재시도 후 서버 저장건수가 정확히 한 건 증가하는지 검사한다.
저장 중 닫기·송신 앱 강제 종료 테스트는 서버 저장 후 응답을 각각 10초·20초 지연시킨다. 본앱의 수동 저장 창에
입력만 남겨 두고 외부 공유를 중단한 뒤, 본앱 네이티브 모달에서 같은 초안을 재개한다.
중복 저장이 없고 기존 수동 URL·저장 화면이 유지되는지 확인하며 본앱 저장 버튼은 누르지 않는다.
재실행 때 `test`로 새 러너를 빌드·설치한다. 테스트 코드를 바꾼 뒤에는 이전 러너를 제거해
시뮬레이터가 오래된 테스트 번들을 재사용하지 않게 한다. Simulator의 기본 ad-hoc 서명을 사용한다.

```bash
xcrun simctl uninstall "$IOS_DEVICE" com.huturu.shareuitests.xctrunner
xcodebuild -project ios/ShareVerification/ShareVerification.xcodeproj \
  -scheme ShareVerification -configuration Debug -sdk iphonesimulator \
  -destination "id=$IOS_DEVICE" -derivedDataPath /tmp/clipback-share-ui-derived \
  -jobs 2 -parallel-testing-enabled NO \
  -only-testing:ShareUITests/ShareUITests/testExternalLinkSaveReturnsToSenderWithoutMainApp \
  -only-testing:ShareUITests/ShareUITests/testImageSaveAndUnsupportedInput \
  -only-testing:ShareUITests/ShareUITests/testSocketResponseLossRetriesWithoutDuplicate \
  -only-testing:ShareUITests/ShareUITests/testSocketTimeoutRetriesWithoutDuplicate \
  -only-testing:ShareUITests/ShareUITests/testUnauthorizedDraftResumesInMainNativeModal \
  -only-testing:ShareUITests/ShareUITests/testCloseDuringSaveRecoversWithoutDuplicateAndPreservesManualInput \
  -only-testing:ShareUITests/ShareUITests/testSenderTerminationDuringSaveRecoversWithoutDuplicateAndPreservesManualInput \
  test
```

별도 OS 송신 앱 검증은 Safari에 YouTube URL을 열어 놓은 뒤 `testSafariSharesPreparedYouTubePage`,
PNG 스크린샷을 `xcrun simctl addmedia`로 넣은 뒤 `testPhotosSharesPreparedScreenshot`를 각각 실행한다.
Safari 페이지 조회는 실제 브라우저 동작이며 저장 API는 위 로컬 fixture를 사용한다.
Safari가 같은 URL을 여러 `NSItemProvider`로 제공하면 단일 링크로 처리한다.
동일 YouTube 영상의 `www`/`m` 주소와 모바일 표시용 `ra=m`도 단일화하며 처음 전달한 URL을 유지한다.
영상 ID나 나머지 query가 다른 입력은 합치지 않는다.
서로 다른 URL, 여러 이미지, 별도 URL과 이미지가 섞인 입력은 지원하지 않는다.

이미지 계정 한도·운영 중단·파일 크기 오류는 같은 fixture 서버에서
`testImageQuotaAndFileLimitAppearInExistingShareErrorRegion`을 선택해 검사한다.
`next_save_status`와 `next_save_detail`을 제어해 실제 Share Extension의 기존 상태 영역을 확인하고
`ios-share-image-quota`·`ios-share-image-paused`·`ios-share-image-file-limit` OS 스크린샷을 첨부한다.
이는 네이티브 오류 전달 검증이며 서버의 실제 한도 계산은 PostgreSQL API 통합 테스트가 검증한다.

실제 FastAPI·전용 PostgreSQL 검증은 테스트 백엔드를 18766 포트에서 실행한 뒤
위 Flutter 빌드의 API 포트를 18766으로 바꾸고 `--dart-define=SHARE_PREVIEW_REAL_BACKEND=true`를 추가한다.
앱 설치 후 `testRealBackendGuestLoginThenNativeSave`만 실행한다. 이 테스트는 기존 게스트 선택을 거쳐
온보딩·관심사 완료까지 기존 흐름을 진행하고, 검색 입력을 남긴 채 외부 송신 앱으로 이동한다.
실제 서버에서 발급한 공유 자격으로 확장 저장 후 본앱 검색 화면과 입력이 유지되는지 확인한다.
홈의 검색 아이콘은 제목 없는 첫 헤더 버튼으로, iPhone 16의 접근성 트리에서 확인한 순서를 사용한다.
UI 구조가 바뀌면 이 선택자를 실제 접근성 트리와 대조한다. 운영 DB나 운영 API를 사용하지 않는다.

## 화면 증거와 배포 경계

`-resultBundlePath /tmp/<새 이름>.xcresult`를 UI 명령에 추가하면 XCTest PNG를 보관한다.
`xcrun xcresulttool export attachments --path <결과> --output-path <폴더>`로 내보낸다.
영상은 `xcrun simctl io "$IOS_DEVICE" recordVideo --codec=h264 <영상.mp4>`로 촬영하고 SIGINT로 종료한다.

Simulator 성공은 실제 Instagram·YouTube 앱, 실기기 프로비저닝, TestFlight, 운영 저장 검증과 별개다.
실기기 배포 전에 Apple Developer 계정에서 `group.com.huturu.app`과 두 타깃의 App Group/Keychain
프로비저닝을 확인한다. 제품 확장에는 Flutter 엔진이나 소셜 SDK가 연결되지 않는다.
