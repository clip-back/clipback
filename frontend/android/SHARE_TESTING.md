# Android 공유 수신 검증

제품 공유 수신은 Java `ShareActivity`에서 실행한다. 테스트 송신 Activity와
`content://` 이미지 Provider는 `androidTest` APK에만 포함되며 제품 APK에는 들어가지 않는다.

## HTTP 대역과 네이티브 회귀 테스트

저장소 루트에서 대역 서버를 실행한다. 이 서버는 로컬 fixture 데이터만 사용한다.

```bash
python3 frontend/tool/share_fixture_server.py
```

다른 터미널의 `frontend/android`에서 아래를 실행한다. `JAVA_HOME`에는 현재
Flutter/Android Studio가 사용하는 JBR 또는 호환 JDK 21 이상을 지정한다. Android SDK의
`platform-tools`와 `emulator`가 `PATH`에 있어야 한다.

```bash
export JAVA_HOME="/path/to/Android Studio.app/Contents/jbr/Contents/Home"
SHARE_DEFINES=$(printf '%s' 'CLIPBACK_API_BASE_URL=http://10.0.2.2:18765/api/v1' | base64 | tr -d '\n')
./gradlew :app:assembleDebug :app:assembleDebugAndroidTest \
  -Ptarget-platform=android-arm64 \
  -Ptarget=test/support/share_preview.dart \
  -Pdart-defines="$SHARE_DEFINES" \
  --max-workers=2 -Dorg.gradle.jvmargs='-Xmx1536m -XX:MaxMetaspaceSize=768m'
./gradlew --stop
```

Apple Silicon의 arm64 AVD용 명령이다. x86_64 AVD를 쓰는 호스트에서는
`-Ptarget-platform=android-x64`로 바꾼다. 빌드가 끝난 뒤 Android API 36 AVD를
실행하고 설치한다. 사용 가능한 이름은 `emulator -list-avds`로 확인한다.

```bash
emulator -avd Medium_Phone -memory 1536 -cores 2 -no-snapshot -no-audio
# 별도 터미널, frontend/android
adb -s emulator-5554 install -r ../build/app/outputs/apk/debug/app-debug.apk
adb -s emulator-5554 install -r ../build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk
adb -s emulator-5554 shell am instrument -w \
  -e class com.clipback.frontend.share.ShareStoreTest,com.clipback.frontend.share.ShareActivityTest,com.clipback.frontend.share.ShareServiceFixtureTest \
  com.clipback.frontend.test/android.test.InstrumentationTestRunner
```

클래스를 명시해야 큰 Flutter APK의 불필요한 전체 클래스 탐색을 피한다.
`ShareServiceFixtureTest`는 `18765` 대역 빌드에서만 실행하며, 전역 장애 제어를 쓰므로
iOS 테스트나 다른 HTTP 테스트와 동시에 실행하지 않는다. API 33 AVD에서도 같은 APK와
명령을 실행한다. 이번 검증의 전용 API 33 AVD 이름은 `Clipback_Share_API_33`이다.
기존 AVD의 데이터 공간이 부족하면 데이터를 지우지 않고 별도 AVD를 만든다.

```bash
avdmanager create avd -n Clipback_Share_API_33 \
  -k 'system-images;android-33;google_apis;arm64-v8a' -d pixel_3a
emulator -avd Clipback_Share_API_33 -memory 1536 -cores 2 \
  -gpu swiftshader -no-snapshot -no-audio
```

테스트는 실제 Keystore 암호화·저장 실패·계정/환경 경계·파일 정리·Activity 재생성·
뒤로 가기·저장 직후 닫기와 HTTP 요청 공유·401·30초 제한·응답 유실 재시도를 확인한다.

이미지 한도 오류는 `ShareServiceFixtureTest#testImageQuotaUsesExistingShareErrorRegion`과
`#testImageFileLimitUsesExistingShareErrorRegion`을 선택해 실행한다. 실제 공유 복구 Activity의
기존 상태 문구와 초안·로그인 유지를 확인하고 앱 외부 파일 폴더에
`android-share-image-quota.png`·`android-share-image-file-limit.png` OS 스크린샷을 남긴다.
fixture의 `next_save_detail`은 오류 코드 전달만 대역 처리하며 실제 계정 합계는 서버 API 통합 테스트가 검증한다.

## 시스템 공유 창과 화면 증거

테스트 후 본앱의 fixture 진입점을 한 번 열면 메모리 세션에서 공유 자격을 준비한다.
그다음 별도 송신 앱을 연다.

```bash
adb -s emulator-5554 shell am start -n com.clipback.frontend/.MainActivity
adb -s emulator-5554 shell am start -n com.clipback.frontend.test/com.clipback.frontend.share.ShareTestSenderActivity
```

송신 앱의 링크/이미지 버튼 → 실제 시스템 공유 목록의 허투루 → 계정·입력 확인 → 저장 →
완료 → 닫기/시스템 뒤로 가기 → 송신 앱 복귀를 확인한다. 이미지에는 일시적인 URI 읽기
권한만 전달한다. API 33에서는 이미지 미리보기 중 회전도 확인한다.

401 대역을 설정하고 저장하면 초안을 유지해야 한다. 본앱으로 돌아와 대기 항목을 선택하면
공유 복구 Activity가 열리고, 저장/닫기 후 기존 본앱 화면으로 돌아와야 한다.

```bash
curl -X POST http://127.0.0.1:18765/__test/control \
  -H 'Content-Type: application/json' -d '{"next_save_status":401}'
adb -s emulator-5554 exec-out screencap -p > /absolute/path/share-preview.png
adb -s emulator-5554 shell screenrecord --time-limit 60 /sdcard/share-flow.mp4
adb -s emulator-5554 pull /sdcard/share-flow.mp4 /absolute/path/share-flow.mp4
```

공유 목록·미리보기·성공·실패·복귀 화면을 캡처하고, 외부 송신 앱 복귀와 본앱 복구는 영상도
보관한다. 계정/토큰 원문이나 실제 사용자 데이터가 보이는 로그는 저장하지 않는다.
본앱 수동 저장 입력이나 검색 화면을 열어 둔 상태에서도 외부 공유가 기존 화면을 초기화하지
않는지 확인한다. 메모리가 적은 호스트는 Gradle과 iOS Simulator/Android Emulator를
동시에 실행하지 않는다.

## 실제 로컬 PostgreSQL 백엔드와 구분

`18765`는 HTTP 대역이며 실제 DB 트랜잭션·서버 인증을 증명하지 않는다. 별도로 격리한
PostgreSQL과 로컬 백엔드 harness(`backend/tests/support/share_live_server.py`,
실행 환경은 백엔드 README 참고)를 `18766`에서 실행한 뒤 다음 빌드를 사용한다.

```bash
# frontend/
flutter build apk --debug --no-pub -t test/support/share_preview.dart \
  --dart-define=CLIPBACK_API_BASE_URL=http://10.0.2.2:18766/api/v1 \
  --dart-define=SHARE_PREVIEW_REAL_BACKEND=true
```

이 빌드는 기존 게스트 시작 UI → 일반 인증 → 공유 자격 발급 → 네이티브 저장을 수행한다.
서버의 실제 콘텐츠/asset/receipt 행을 대조하되 provider는 로컬 대역이며 외부 OAuth,
Instagram·YouTube 앱 자체, 운영 서버, 실제 기기는 검증하지 않는다. 이전 환경에서 이미
전송한 초안은 다른 서버에 재전송할 수 없으므로 새 공유 작업으로 검증한다.
