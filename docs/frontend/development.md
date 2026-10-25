# 프론트 개발 설정과 검증

소셜 SDK·네이티브 설정, 플랫폼 실행, 프리뷰·테스트와 TestFlight 재업로드 안내입니다. SDK 준비와 기본 실행은 [프론트 README](../../frontend/README.md), 제품 동작은 [동작 기준](behavior.md)을 따릅니다.
별도 표기가 없는 `flutter`·`python3 tool/…`·`open ios/…` 명령은 저장소의 `frontend/`에서 실행합니다. 기기·공급자 설정이 필요한 명령은 해당 설정을 먼저 준비합니다.
실행 결과와 미검증 범위를 적는 진행 문서는 [작업·검증 이력](../history/README.md)에서 찾습니다.

## 소셜 로그인 설정

### 공개 앱 설정

`google_sign_in` 7.2.0, `kakao_flutter_sdk_user` 2.0.1, `sign_in_with_apple` 8.2.0을 사용합니다.
`lib/social_auth.dart`의 SDK 어댑터는 초기화를 한 번만 수행하고, 설정 누락·불일치를 인증창 전에
안내합니다. 설정을 생략해도 게스트 실행·빌드는 가능합니다. 공급자 비밀키는 프론트엔드에 넣지 않습니다.

| Dart define | 용도 |
| --- | --- |
| `CLIPBACK_GOOGLE_SERVER_CLIENT_ID` | 양 모바일 공통 Google **웹 OAuth client ID**. 백엔드 ID token audience |
| `CLIPBACK_GOOGLE_IOS_CLIENT_ID` | `com.huturu.app`용 iOS OAuth client ID. iOS에서 필수 |
| `CLIPBACK_KAKAO_NATIVE_APP_KEY` | 양 모바일 공통 카카오 Native app key |

공급자 콘솔에서 발급한 공개 값을 아래 환경변수에 지정한 뒤 실행합니다. 이 값들을 Dart define으로
전달해도 앱에 포함되므로 서버 client secret·Apple `.p8`·토큰·암호화키를 넣지 않습니다.

```bash
# frontend/에서 실행. DEVICE_ID 및 각 공개 ID는 로컬에서 지정합니다.
flutter run -d "$DEVICE_ID" --no-pub \
  --dart-define="CLIPBACK_GOOGLE_SERVER_CLIENT_ID=$GOOGLE_SERVER_CLIENT_ID" \
  --dart-define="CLIPBACK_GOOGLE_IOS_CLIENT_ID=$GOOGLE_IOS_CLIENT_ID" \
  --dart-define="CLIPBACK_KAKAO_NATIVE_APP_KEY=$KAKAO_NATIVE_APP_KEY"
```

Android의 `applicationId`는 `com.clipback.frontend`입니다. Google 콘솔에는 이 패키지와 실제
Debug/Release 서명 SHA를, 카카오 콘솔에는 패키지와 해당 서명 key hash를 등록합니다.
Google `serverClientId`를 명시하므로 `google-services.json`을 추가하지 않습니다.
Gradle은 Flutter `dart-defines`에서 카카오 Native key를 읽어 manifest의
`AuthCodeHandlerActivity` 콜백 `kakao{Native key}://oauth`를 구성합니다.
([Google Android 설정](https://pub.dev/packages/google_sign_in_android),
[카카오 Flutter 설정](https://developers.kakao.com/docs/en/flutter/getting-started))

iOS는 같은 `com.huturu.app`을 Google·카카오 콘솔에 등록하고 다음 파일을 준비합니다.

```bash
# frontend/에서 최초 한 번. 기존 로컬 파일은 덮어쓰지 않습니다.
test -f ios/Flutter/SocialAuth.xcconfig || \
  cp ios/Flutter/SocialAuth.example.xcconfig ios/Flutter/SocialAuth.xcconfig
```

Git에서 제외된 `SocialAuth.xcconfig`의 `CLIPBACK_GOOGLE_IOS_URL_SCHEME`은 iOS OAuth
`REVERSED_CLIENT_ID`, `CLIPBACK_KAKAO_IOS_URL_SCHEME`은 `kakao` 뒤에 Native key를 붙인
값으로 바꿉니다. `Debug`·`Profile`·`Release`에서 이 설정을 포함합니다. Dart client ID를 전달해도
네이티브 URL scheme은 별도로 필요합니다. 로그인 전에 Info.plist의 실제 scheme과 Dart define의
일치를 검사하므로 한쪽만 수정하면 설정 오류를 표시합니다. `LSApplicationQueriesSchemes`에는
카카오톡 확인용 `kakaokompassauth`가 있습니다. 설정 변경 후에는 앱을 완전히 다시 빌드합니다.
([Google iOS 설정](https://pub.dev/packages/google_sign_in_ios))

Apple은 Runner의 Sign in with Apple entitlement와 콘솔의 `com.huturu.app` App ID capability를
모두 활성화하고, 해당 entitlement를 포함한 서명·프로비저닝을 준비합니다. 이 기능의 실제 기기 검증에는
Sign in with Apple을 지원하는 Developer Program 팀이 필요합니다. Apple 로그인은 네이티브 iOS만
사용하며 Services ID·웹 redirect는 설정하지 않습니다.
([Apple capability 설정](https://developer.apple.com/help/account/capabilities/about-sign-in-with-apple))

백엔드는 `GOOGLE_CLIENT_IDS`에 사용한 웹 OAuth client ID를 허용하고, `KAKAO_CLIENT_IDS`에는
실제 SDK가 발급하는 ID token의 audience를 허용해야 합니다. 카카오 콘솔의 로그인·OpenID Connect
활성화와 동의항목도 확인합니다. Apple 서버 설정·암호화키·migration은
[백엔드 소셜 API 안내](../backend/api-contracts.md#mobile-social-authentication)와 [MVP 현황](../backend-mvp-plan.md)을 따릅니다.
비밀키·서버 토큰은 앱과 로컬 공개 URL scheme 설정에 복사하지 않습니다.

Bundle ID를 기존 `com.clipback.app`에서 `com.huturu.app`으로 변경했으므로 실제 로그인 전에는
Google의 iOS OAuth client와 URL scheme, 카카오의 iOS 플랫폼 등록, Apple App ID·프로비저닝을
새 식별자 기준으로 확인합니다. 백엔드 Apple 설정의 `APPLE_CLIENT_ID`도 `com.huturu.app`이어야 하며,
`APPLE_TEAM_ID`·키는 해당 App ID에 사용할 개발자 팀과 일치해야 합니다. 저장소 설정 변경만으로
공급자 콘솔이나 배포 환경변수가 변경되지는 않습니다. Android 패키지명은 그대로 유지합니다.

### 검증 범위

`test/social_auth_test.dart`는 SDK 대역으로 플랫폼 제한, 초기화, 설정 불일치, 취소·카카오 fallback,
ID token 누락, Apple nonce·code·사용자 식별자, credential state, 로컬 로그아웃을 확인합니다.
`test/social_login_test.dart`는 HTTP·SDK 대역으로 로그인 선택, 게스트 유지/승격, 409 확인·취소,
새 인증 재시도, 로그아웃·세션 복원과 Apple 취소 상태 처리를 확인합니다.

로컬 테스트·APK/iOS 빌드·로그인 선택 화면 실행은 실제 공급자 인증 성공을 뜻하지 않습니다.
릴리스 전 실제 설정으로 양 모바일 Google/카카오, iPhone Apple 로그인·취소·재로그인·앱 재시작,
카카오톡 설치/미설치, 게스트 승격/409 전환, Apple 연결 철회 후 복귀를 각각 검증해야 합니다.

## 실행과 검증

기본 분석·테스트 명령은 [README의 기본 검증](../../frontend/README.md#기본-검증)을 따릅니다. 아래는 각 테스트의 범위이며 실제 실행 결과와 미검증 범위는 [작업 이력](../history/README.md)에서 확인합니다.

세션 복원·저장·동시 갱신 회귀 테스트는 `test/session_restore_test.dart`, `test/session_persistence_test.dart`,
`test/session_refresh_test.dart`에서 HTTP와 저장소 오류를 대체해 확인합니다.
`test/screenshot_auth_test.dart`는 실제 multipart 본문과 파일 선택 대역으로 업로드·저장 실패를 검증합니다.
`test/content_auto_category_test.dart`는 선택 없는 요청과 실제 서버 분류·YouTube 처리 상태 표시를 검증합니다.
`test/feed_pagination_test.dart`는 커서·필터·북마크 우선·실패 재시도·늦은 응답·상세 경계 탐색을 검증합니다.
`test/screenshot_asset_test.dart`와 `test/screenshot_asset_api_test.dart`는 원본 표시·다운로드 인증·시간 초과·화면 전환 경합을 검증합니다.
`test/content_mutation_test.dart`는 변경 중 잠금·실패 복구·늦은 조회·계정 전환·삭제 성공 시점과 상태 보존을 검증합니다.
삭제 응답 직후 화면에 남아 있는 카드를 눌러도 상세 열기가 거부되면 목록에 머물고, 다른 콘텐츠를 대신 표시하지 않는지도 확인합니다.
`test/category_delete_test.dart`는 삭제 안내·진행·실패 보존·전체 분류·동시 변경·늦은 응답과 조회 재시도를 검증합니다.
`test/category_list_recovery_test.dart`는 실제 앱·HTTP 대역·메모리 세션에서 저장 성공과 후속 조회 실패를
분리하고, 마지막 목록 보존·GET만 재시도·정상 빈 배열/잘못된 본문·필수 요약 필드·각 조회의 전체10초·공유 인증 갱신·
이전 조회/계정/스낵바의 늦은 결과와 과거 성공 스냅샷을 검증합니다. 생성·수정 재실행이나 프로필·통계·
콘텐츠의 공통 refresh가 카테고리 재조회에 섞이지 않는지는 외부 HTTP 요청으로 확인합니다.
`test/category_reentry_test.dart`는 실제 앱·HTTP 대역·메모리 세션 경계에서 아카이브/관리의 생성·수정 직접 닫기,
미확인 닫기 확인·같은 키 유지/새 키 시작·현재 서버 값 준비·GET만 재시도 뒤 열기·새 앱 자동 재전송 없음·늦은 결과를 검증합니다.
낙관적 표시와 원본의 구분, 수정 대상 ID 부재와 같은 이름의 다른 ID, 공통 조회가 준비 조회를 대체하는 경쟁도 포함합니다.
관련 묶음은 `flutter test --no-pub --concurrency=1 test/category_reentry_test.dart test/category_list_recovery_test.dart test/category_delete_test.dart`로 실행합니다.
`test/app/account_stats_regression_test.dart`와 `test/data/user_repository_test.dart`는 프로필 재조회 시
이미 받은 서버 통계를 보존하고, 계정 초기화 때만 기존 통계를 비우는 경계를 검증합니다.
`test/session_restore_test.dart`와 `test/content_mutation_test.dart`는 실제 앱·HTTP 대역·메모리 세션 경계에서
마이 통계의 미확인/실제0·재진입·요청 공유·전체10초·마지막 확인값·프로필 독립 반영을 확인합니다.
`test/social_login_test.dart`와 세션 복원 검사는 계정 전환·로그아웃·최종401·단독/공유 인증 갱신과 이전 재시도 콜백의 무효화도 같은 경계에서 확인합니다.
재시도 입력은 단일 포인터의 표준 두 번 탭 판별 시간을 기다린 뒤 요청 시작부터10초를 측정하며,
글자2배율 연속 입력의 아래 메뉴 오작동, 접근성·키보드 활성화도 같은 앱 경계에서 검사합니다.
토큰 저장은 플랫폼 저장 대역과 캐시 초기화 후 읽기도 검증합니다.
실제 PostgreSQL·Chrome 검증 결과와 미검증 범위는 [작업·검증 이력](../history/README.md)에 날짜와 환경을 구분해 기록합니다.

## 안전 영역 검증 도구

화면 배치 계약은 [상단 안전 영역과 헤더](behavior.md#상단-안전-영역과-헤더)를 따릅니다. 기기 실행에는 연결된 기기와 해당 플랫폼 개발 환경이 필요합니다.

`top_safe_area_test.dart`는 상단 inset 0/20/44/59/62와 375×812·430×932에서 헤더 위치·높이·탭을
검사하고, 스크롤·드래그 중 상태바 영역의 렌더링 픽셀을 비교합니다.
`auth_safe_area_test.dart`, `save_search_safe_area_test.dart`, `sheet_safe_area_test.dart`는
인증 배치, 입력·선택 사진 보존, 높은 시트와 상세 이미지 요청 공유를 검증합니다.

기기에서 화면만 확인하려면 아래 테스트 전용 진입점을 사용합니다. 실제 `ClipbackApp`에 HTTP 대역과
메모리 세션·인증을 연결하므로 운영 서버나 기기에 저장된 실제 세션을 사용하지 않습니다.
지원하지 않는 HTTP 요청은 오류로 끝나며 실제 서버로 전달하지 않습니다. 새 의존성은 필요하지 않습니다.

```bash
# frontend/에서 실행. 연결된 기기의 ID를 지정합니다.
flutter run --no-pub -d <iPhone-device-id> -t test/support/safe_area_preview.dart

# 화면 콜백·합성 포인터로 자동 순회하고 기기 좌표 및 PNG를 기록합니다.
flutter run --no-pub -d <iPhone-device-id> -t test/support/safe_area_device_check.dart
```

자동 순회는 앱 임시 폴더에 `report.json`과 PNG를 저장하고 경로 및 PASS/FAIL을 출력합니다.
무선 iOS 실행에서 Flutter 터미널에 앱 로그가 보이지 않으면 Xcode 콘솔이나 기기의
`tmp/clipback-safe-area-*` 결과 파일을 확인합니다.
이 결과는 **실제 기기의 렌더링과 프로그램 입력 검증**이며 사람의 수동 탭·실제 OAuth·운영 API 검증과
구분합니다. 이 진입점을 출시하지 않으며 제품 빌드의 진입점은 계속 `lib/main.dart`입니다.

## Android 개발 실행

Android SDK Platform 36을 설치하고, 실제 기기는 개발자 옵션의 USB 디버깅을 켠 뒤
Mac의 디버깅 연결을 허용합니다. `flutter doctor --android-licenses`로 필요한 라이선스를
확인하고 동의한 다음 실행합니다.

```bash
# frontend/에서 실행
flutter pub get --enforce-lockfile
flutter devices
flutter run -d <Android-device-id> --debug --no-pub
```

실행 중 터미널에서 `r`로 hot reload, `R`로 hot restart를 할 수 있습니다.
Android Gradle 설정·네이티브 플러그인을 바꿨다면 실행을 종료한 뒤 다시 빌드합니다.
기기 없이 APK 빌드만 확인하려면 `flutter build apk --debug --no-pub`를 사용합니다.

현재 잠금파일의 `file_picker` 8.3.7은 API 34로 컴파일하도록 설정되어 있지만,
`flutter_plugin_android_lifecycle` 2.0.35는 API 36 이상을 요구합니다.
`android/build.gradle.kts`에서 `file_picker` 모듈에만
[`finalizeDsl`](https://developer.android.com/reference/tools/gradle-api/9.0/com/android/build/api/variant/LibraryAndroidComponentsExtension)을 적용해
compileSdk를 36으로 맞춥니다. 앱의 minSdk·targetSdk와 패키지 잠금파일은 유지합니다.
`file_picker`를 업데이트할 때 플러그인 자체의 compileSdk를 확인하고 이 보정의 필요성을 재검토합니다.


## iOS 개발 실행

iOS 프로젝트는 `ios/Runner.xcworkspace`로 엽니다. 앱 이름은 **허투루**, Bundle ID는
`com.huturu.app`이며, Debug·Profile·Release의 서명 Team은 `8X6N747PQM`으로 설정되어 있습니다.
실제 기기 실행에는 해당 팀의 접근 권한과 유효한 서명·프로비저닝이 필요합니다.
Runner의 Deployment Target은 현재 Xcode의 `Recommended` 설정을
사용합니다(Xcode 27.0에서는 iOS 17). Xcode 버전을 바꾸면 실제 최소 버전을 다시 확인합니다.


```bash
# frontend/에서 실행
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
flutter build ios --simulator --debug --no-pub
open ios/Runner.xcworkspace
```

첫 빌드에서 Flutter 설정·플러그인 등록 파일과 Swift 패키지를 생성하고, Xcode가 네이티브
의존성을 내려받습니다. `Generated.xcconfig`, `GeneratedPluginRegistrant.*`,
`Flutter/ephemeral/`은 자동 생성물이므로 직접 작성하거나 커밋하지 않습니다.

실제 iPhone은 Mac에 연결하고 기기에서 신뢰·개발자 모드를 설정한 뒤, Xcode의 Runner 타깃에서
본인의 Team과 자동 서명을 확인합니다. 실행 대상으로 연결된 iPhone을 선택해 Run하거나
다음 명령을 사용합니다. 기기 설정은 [Flutter iOS 준비 문서](https://docs.flutter.dev/platform-integration/ios/setup)를 따릅니다.

```bash
flutter devices
flutter run -d <iPhone-device-id> --no-pub
```

현재 Runner에는 Sign in with Apple entitlement가 있으므로 실제 기기 빌드는 해당 capability를
지원하는 Apple Developer Program 팀과 프로비저닝이 필요합니다. TestFlight도 이 프로그램을 사용합니다
([Apple 계정 안내](https://developer.apple.com/help/account/basics/about-your-developer-account)).
시뮬레이터 빌드 성공만으로 기기 서명이나 설치 성공을 판단하지 않습니다.
기본 API는 HTTPS Railway 주소이며, 실제 기기에서 로컬 서버에
연결할 때는 `127.0.0.1` 대신 기기가 접근할 수 있는 서버 주소를 사용합니다.

### TestFlight 권한 설명과 재업로드

`ios/Runner/Info.plist`에는 `NSPhotoLibraryUsageDescription`, `NSCameraUsageDescription`,
`NSLocationWhenInUseUsageDescription`을 유지합니다. 사진 권한 설명은 선택한 사진·스크린샷을
저장하고 분류하는 목적입니다. 현재 앱은 사진 보관함에서 이미지를 선택하며 카메라와 현재 위치에는
접근하지 않으므로, 나머지 두 문구도 미사용 사실을 안내합니다.

`file_picker` 8.3.7의 Swift Package 의존성인 `DKImagePickerController`에 `DKCamera`가 포함되어
카메라·위치 API가 바이너리에 연결됩니다. 해당 기능을 호출하지 않아도 App Store Connect의
정적 검사에서 `ITMS-90683`이 발생할 수 있습니다. 설명 키만 추가해 카메라나 위치를 요청하지는
않습니다. 의존성을 변경할 때는 미사용 API 포함 여부와 이 설명들의 필요성을 함께 재확인합니다.

권한 설명을 수정한 뒤에는 새 빌드 번호로 배포용 바이너리를 다시 만듭니다. `APP_BUILD_NUMBER`에
이미 업로드한 번호보다 큰 미사용 값을 로컬에서 지정합니다. 위 공개 앱 설정의 세 값을
환경변수에 지정하고 `SocialAuth.xcconfig`도 준비해야 합니다. Android Studio의 실행 인자는
터미널 빌드에 자동 전달되지 않습니다.

```bash
# frontend/에서 실행
flutter build ipa --release --no-pub -t lib/main.dart --build-number="$APP_BUILD_NUMBER" \
  --dart-define="CLIPBACK_GOOGLE_SERVER_CLIENT_ID=$GOOGLE_SERVER_CLIENT_ID" \
  --dart-define="CLIPBACK_GOOGLE_IOS_CLIENT_ID=$GOOGLE_IOS_CLIENT_ID" \
  --dart-define="CLIPBACK_KAKAO_NATIVE_APP_KEY=$KAKAO_NATIVE_APP_KEY"
open build/ios/archive/*.xcarchive
```

Xcode Organizer에서 새 아카이브를 검증하고 `Distribute App → App Store Connect`로 업로드합니다.
이전 아카이브에는 수정된 문구가 반영되지 않습니다. 로컬 빌드 성공과 App Store Connect 처리·심사
통과는 별도이며, 새 빌드의 처리 결과와 실제 사진 선택·저장 동작을 확인합니다.

## 모바일 공유 개발과 검증

공유 초안·자격·재시도 동작은 [모바일 공유 저장](behavior.md#모바일-공유-저장)을 따릅니다. 아래 플랫폼 설정 후 로컬 검증을 진행합니다.

### 플랫폼 설정

- iOS: Runner `com.huturu.app`, 확장 `com.huturu.app.ShareExtension`, App Group
  `group.com.huturu.app`, 공유 Keychain `$(AppIdentifierPrefix)com.huturu.app.share`.
  기존 기본 Keychain 그룹과 소셜 설정은 유지합니다. 실기기·배포 시 Apple 개발자 계정에
  App Group과 두 App ID의 capabilities를 등록하고 프로비저닝을 갱신해야 합니다.
- Android: application ID `com.clipback.frontend` 유지. 공유 수신 Activity에만 `ACTION_SEND`
  `text/plain`·`image/*`를 등록하며 복구 Activity는 외부에 공개하지 않습니다.
  자격은 Android Keystore AES-GCM으로 암호화해 앱 전용 저장소에 기록합니다.
- Dart와 두 네이티브 구현의 API 주소는 같은 `CLIPBACK_API_BASE_URL` 빌드 값을 사용합니다.
  저장된 자격의 대상 환경이 빌드 주소와 다르면 저장하지 않습니다. 릴리스에서 로컬 HTTP를
  허용하지 않으며, 웹·데스크톱은 네이티브 공유 연동 없이 기존 수동 저장을 사용합니다.

### 로컬 공유 검증

HTTP 대역은 Flutter와 네이티브 양쪽에서 실제 소켓으로 접근합니다. 운영 서버 fallback은 없습니다.

```bash
# frontend/ — 별도 터미널에서 유지
python3 tool/share_fixture_server.py

# iOS Simulator
flutter run --no-pub -d <simulator-id> -t test/support/share_preview.dart \
  --dart-define=CLIPBACK_API_BASE_URL=http://127.0.0.1:18765/api/v1

# Android Emulator
flutter run --no-pub -d <emulator-id> -t test/support/share_preview.dart \
  --dart-define=CLIPBACK_API_BASE_URL=http://10.0.2.2:18765/api/v1
```

`SHARE_PREVIEW_SIGNED_OUT=true`를 추가하면 미로그인 초안 복구를 확인할 수 있습니다.
실제 FastAPI·전용 PostgreSQL 검증은 [백엔드 테스트 안내](../backend/testing.md#native-share-local-backend-harness)의 `share_live_server`를 실행하고,
주소를 18766 포트로 변경한 뒤 `SHARE_PREVIEW_REAL_BACKEND=true`를 추가합니다.
이 경우 본앱의 게스트 시작 버튼으로 테스트 서버 세션을 발급받습니다.
외부 OAuth·AI/OCR·metadata는 대역이며 실제 공급자 동작이나 운영 저장을 증명하지 않습니다.

```bash
flutter analyze --no-pub
flutter test --no-pub
flutter build web --no-pub
flutter build apk --debug --no-pub
flutter build ios --simulator --debug --no-pub
```

기존 Flutter 회귀 테스트에 공유 자격·계정 차단·오래된 발급·영수증·목록 범위 보존 테스트를
추가했습니다. 네이티브 저장소와 실제 OS 공유 UI 검증은 각 플랫폼 테스트 타깃으로 별도 수행합니다.
공유 확장·실제 Keychain·송신 앱 UI 테스트 명령은 [iOS 공유 검증 안내](../../frontend/ios/ShareVerification/README.md)를 참고합니다.
Android의 Keystore·수신 Activity·HTTP 테스트와 API 33·36 재현 명령은
[Android 공유 검증 안내](../../frontend/android/SHARE_TESTING.md)에 있습니다.
실행 환경과 실제 결과는 [작업·검증 이력](../history/README.md)에 기록합니다.
