# Android 앱 식별자를 iOS와 통일

최초 기록일: 2026-10-28 KST. 기준 커밋:
`164cb7c0240d4ed8a695a1a3d85bf8c07de2d083`에서 시작한 `chore/android-app-id` 작업이다.

## 요청과 범위

- 사용자가 Google Play 개발자 계정 승인을 완료했다고 알리고 Android 패키지명을
  `com.huturu.app`으로 결정했다. 계정 승인 상태는 사용자 확인이며 콘솔을 별도로 조회하지 않았다.
- Android `applicationId`를 `com.clipback.frontend`에서 `com.huturu.app`으로 변경했다.
  iOS Bundle ID는 이미 `com.huturu.app`이다.
- 내부 Java namespace와 Activity 클래스명은 유지했다. 설치·스토어 식별자와 내부 namespace는
  독립 설정이며 최종 APK의 manifest를 기준으로 확인한다.
- 테스트 APK의 ID는 `com.huturu.app.test`로 파생된다. 이미지 공유 테스트 Provider의 authority와
  송신 URI도 새 테스트 앱 ID에 맞춰 이전 테스트 앱과의 authority 충돌을 피했다.
- 현재 설정·실행 문서와 ADB 명령을 갱신했다. 과거 패키지명으로 실행한 이력은 보존했다.
- 첫 Android 배포의 식별자 설정으로 사용자 기능·화면 변경은 없어 CHANGELOG 항목은 추가하지 않았다.

## 확인 기준

1. APK와 테스트 APK의 실제 ID, MainActivity·ShareActivity의 클래스명, 테스트 Provider authority를 확인한다.
2. 전체 Flutter 분석·회귀 테스트와 기존 Android 네이티브 공유 테스트를 실행한다.
3. Android Emulator에서 새 패키지의 본앱 실행·공유 수신과 iOS Simulator 시작 화면을 확인한다.
4. 문서 경로·명령과 최종 diff를 확인하고 커밋한다.

## 검증 결과와 한계

환경은 macOS arm64, Flutter 3.44.9, Dart 3.12.2, JDK 21.0.9, Android compile/target SDK 36이다.
제품 APK는 후보 버전을 예약하지 않은 Debug `0.1.0+1`이며 배포 산출물이 아니다.

| 확인 | 결과 |
| --- | --- |
| `flutter analyze --no-pub` | 문제 없음 |
| `flutter test --no-pub --concurrency=2 --reporter=expanded` | 재실행 1,992개 통과, 3분 25초 |
| 공유 fixture 앱·instrumentation APK 패키징 | 성공. 아래 디스크 부족 복구 절차 사용 |
| `lib/main.dart` 제품 Debug APK | 성공. `applicationId=com.huturu.app`, min SDK 24, target SDK 36 |
| APK manifest와 네이티브 라이브러리 | MainActivity·ShareActivity·ShareRecoveryActivity는 기존 클래스명으로 해석됨. APK 내 네이티브 라이브러리 8개의 SHA-256이 패키징에 사용한 산출물과 일치 |
| 테스트 APK manifest·DEX | 패키지 `com.huturu.app.test`, instrumentation 대상 `com.huturu.app`, Provider와 송신 URI `com.huturu.app.test.shareimage` 일치 |
| 문서 링크 | 변경 문서 5개의 로컬 링크 308개 존재 확인 |
| 최종 diff | 요청한 앱 식별자·테스트 앱·관련 문서 8개 파일만 변경. `git diff --check` 통과, 비밀값·생성 파일 없음 |

첫 Gradle 실행은 네이티브 컴파일 후 `packageDebug` 단계에서 `No space left on device`로 실패했다.
테스트 APK 패키징도 불완전한 출력의 `AndroidManifest.xml` 중복 오류가 발생했다.
이번 빌드의 불완전한 APK·패키징 증분 파일과, strip 완료 후 중복으로 남은 `merged_native_libs`를
정리했다. 완료된 `stripped_native_libs`를 보존한 상태에서 다음 두 단계를 제외하고 패키징을
재실행해 성공했다. 새 환경의 전체 빌드 성공으로 해석하지 않는다.

```text
-x :app:mergeDebugNativeLibs -x :app:stripDebugDebugSymbols
```

공유 fixture는 `test/support/share_preview.dart`와
`CLIPBACK_API_BASE_URL=http://10.0.2.2:18765/api/v1`, 제품 Debug는 `lib/main.dart`로 빌드했다.
두 빌드 모두 `-Ptarget-platform=android-arm64 --max-workers=2`와
`-Dorg.gradle.jvmargs=-Xmx1536m -XX:MaxMetaspaceSize=768m`를 사용했다.
APK 검증 뒤 이번 Android 중간 산출물을 정리했고 APK와 기존 iOS 릴리스 파일은 보존했다.
첫 Flutter 전체 검사는 320개 진행 뒤 출력이 멈춰 중단했다. 이 실행은 성공으로 집계하지 않고,
중간 산출물 정리와 이번 Gradle 데몬 종료 후 전체 검사를 다시 실행했다.

Android Emulator는 `Clipback_Share_API_33`(Pixel 3a, API 33)을 기존 데이터가 바뀌지 않는
`-read-only -no-snapshot -no-window` 모드로 실행했으나
`Your device does not have enough disk space to run avd`로 시작되지 않았다.
따라서 앱 설치·시작, 시스템 공유 수신, 네이티브 instrumentation 테스트는 **미검증**이다.
iOS 코드·식별자는 바뀌지 않았지만, 남은 공간이 1GiB 미만이어서 이번 소스의 iOS Simulator
재빌드·실행도 진행하지 못했다. 이전 실행 결과를 이번 결과로 대체하지 않았다.
양 플랫폼의 실행 스크린샷·영상은 없으며, UI·디자인 변경이 없어 Figma 3면 비교 대상은 없다.

빌드·테스트·APK 확인 로그는 로컬 `/private/tmp/clipback-android-app-id/`에 보관했다.

## 배포 전 남은 작업

- Google의 Android OAuth 등록에 `com.huturu.app`과 실제 설치본의 서명 SHA-1을 등록한다.
- 카카오 Android 등록에 `com.huturu.app`과 실제 설치본의 서명 key hash를 등록한다.
- 현재 Android Release는 Debug 키로 서명하므로 업로드 키·Release 서명 설정을 준비한다.
  Google Play에서 설치하는 앱은 Play App Signing의 앱 서명 인증서를 공급자 설정에 반영한다.
- 기존 `com.clipback.frontend` 개발 앱과 새 패키지는 별도로 설치된다. 기존 로그인·공유 초안·캐시는
  자동 이전되지 않는다.
- 소셜 공급자 콘솔 변경, 실제 OAuth, Play 앱·AAB 업로드, 공개 배포, 실기기 설치는 이 작업의 검증에 포함하지 않는다.
  Android 버전·빌드 후보를 예약하거나 기존 iOS 0.2.0 빌드 6 산출물을 변경하지 않았다.

## 근거 문서

- [Android application ID와 namespace](https://developer.android.com/build/configure-app-module)
- [Google 로그인 Android 설정](https://pub.dev/packages/google_sign_in_android)
- [Play App Signing과 공급자 인증서 등록](https://developer.android.com/studio/publish/app-signing)
- [카카오 앱의 Android 패키지·키 해시 등록](https://developers.kakao.com/docs/ko/app-setting/app)
- [이전 Android 배포 준비 상태](2026-10-27-android-release-preparation.md)
