# Android 내부 테스트 배포 구현 진행

최초 기록일: 2026-10-28 KST. 시작 소스는 `7f0822f`, 통합 브랜치는
`feature/android-internal-testing`이다. 실행 기준은 [명세 #112](https://github.com/clip-back/clipback/issues/112)와
[승인한 티켓 분할](2026-10-28-android-internal-test-tickets.md)이다.

## 진행 범위

| 티켓 | 이번 진행 | 남은 완료 조건 |
| --- | --- | --- |
| [#113](https://github.com/clip-back/clipback/issues/113) | 업로드 키 Release 서명, 1Password 복구, 정상 AAB·양 플랫폼 시작·네이티브 공유 검사 완료 | 없음; Play 제공·실기기 기능은 #114~#115 |
| [#114](https://github.com/clip-back/clipback/issues/114) | Play의 기존 출시·번들·테스터 상태 조회 | #113 완료 후 앱 서명·공급자 설정, 업로드·처리·본인 제공·Play 설치·실제 OAuth |
| [#115](https://github.com/clip-back/clipback/issues/115) | 기존 자동 검증 재사용 | #114 완료 후 Play 실기기 저장·공유·재로그인·재시작 검증과 화면·영상 증거 |

사용자는 1Password, 본인 Google 계정과 Galaxy S25 Ultra를 지정했다. 기기는 USB 디버깅으로
연결했으며 Android 16 / API 36을 확인했다. 개인 계정 주소와 기기 일련번호는 저장소에 기록하지 않는다.
이후 사용자가 1Password 설치·로그인을 완료해 개인 금고를 사용했다. 피드백 연락처는 내부 테스트 제공 전에 확인한다.
실제 비밀번호·인증 코드는 채팅으로 받지 않는다.
각 티켓의 실제 완료 조건을 충족하기 전에는 이슈를 닫지 않는다.

## 이번 환경과 외부 확인

- 시작 시 디스크 여유는 4.8GiB였으며 개인 파일·캐시와 기존 iOS 후보 산출물을 정리하지 않았다.
- 최초 `adb devices -l`에서는 연결된 Android 기기가 없었으나 사용자 응답 후 Galaxy S25 Ultra 연결을 확인했다.
- iPhone 16 Pro / iOS 18.6 Simulator가 부팅되어 있었다. 이 사실은 이번 소스의 빌드·실행 성공을 뜻하지 않는다.
- 2026-10-28 13:05 KST Play Console의 허투루 앱에서 최신 App Bundle `없음`,
  내부 테스트 출시 `버전 없음`, 내부 테스트 트랙 `비활성`, 설정 `0/3`을 확인했다.
  테스터 이메일 목록과 참여 링크 제공도 아직 준비되지 않았다.
- 외부 조회는 읽기만 수행했다. 이 조회로 Play App Signing이나 Google·카카오 등록을 완료 처리하지 않았다.

## 구현과 키 준비

- `311f278`에서 Release를 외부 업로드 키 서명에 연결했다. 외부 UTF-8 properties 파일에
  키 경로·별칭·비밀번호를 두며 Release 빌드 전 필수 입력·외부 경로·개인키 복호화를 확인한다.
  Debug 서명 대체를 제거했고 Debug 검증은 Release 입력 없이 실행할 수 있다.
- 운영자 전용 저장소 밖 폴더에 영구 업로드 키와 설정 파일을 생성했다. RSA 3072-bit JKS,
  별칭 `upload`, 무작위 비밀번호를 사용하며 파일 권한은 각각 `0600`이다.
  비밀번호·키 내용은 출력하지 않았다. 인증서 SHA-256은
  `b076988adba56995398d726e495fff5918a18e269a8bd0da687e986587e59ad0`이다.
- 인증서 내보내기는 성공했지만 1Password 백업에서 복원한 키가 아니므로 백업·복구 완료로 처리하지 않았다.
- 통합 소스에서 영구 키의 Gradle 검증은 `kakao_flutter_sdk_auth` 구성 중 Gradle Binary store
  쓰기 오류로 실패했다. 정상 AAB 빌드는 실행하지 않았다. 이후 디스크 여유가 약 1.4GiB로 줄어
  재생성 가능한 Xcode DerivedData 약 7.5GB 정리 범위를 사용자에게 확인 요청했다.
  해당 정리는 승인 전 실행하지 않았다. 기존 iOS IPA·Archive와 개인 파일을 삭제하지 않았다.
- 사용자가 Xcode DerivedData 정리 범위를 승인한 뒤 해당 캐시만 삭제했고 디스크 여유 8.8GiB를 확인했다.
- 1Password 개인 금고에 `Huturu Android 업로드 키`, `Huturu Android 서명 설정` 문서를 각각 저장했다.
  업로드 완료 후 두 파일을 다시 다운로드해 원본 해시가 같은지 확인했다. 내려받은 파일은 운영자 전용
  복원 폴더로 옮겨 `0600`을 적용하고, 복원한 키의 인증서 일치와 실제 JAR 서명·검증에 성공했다.
  키와 비밀번호를 한 암호화되지 않은 ZIP으로 묶는 초기 방식은 자동 승인 검토가 거부해 실행하지 않았다.
  직접 암호관리자 문서로 저장·복원하는 방식으로 완료했다.
- Play의 최신 번들이 없음을 13:22 KST에 다시 확인하고 기존 도구로
  [0.2.0 Android 빌드 1 후보](../releases/app-v0.2.0-android-b1.md)를 예약했다. 소스는 `311f278`이며
  로컬 기록·로컬 및 원격 태그·수동 스토어 이력 범위의 번호 확인이 완료됐다. 태그는 생성하지 않았다.
- 복원한 키와 기존 iOS 빌드 6에서 사용한 로컬 공개 소셜 SDK 설정을 읽어 정상 Release AAB 빌드를 시작했다.
  제품 진입점은 `lib/main.dart`, 운영 API와 `--build-name=0.2.0 --build-number=1`을 명시했다.
  현재 Generated.xcconfig의 과거 프리뷰 설정은 재사용하지 않았다.
- 정상 `flutter build appbundle --release --no-pub`는 172.6초에 성공했다. 과거의 Gradle 작업 우회 옵션은
  사용하지 않았다. Flutter 3.44.9, JDK 21, bundletool 1.18.3으로 검사했다.
  Kotlin 2.2.10 지원 종료 예고와 일부 Java deprecated API 경고가 있었으며 빌드는 통과했다.
- AAB는 72,779,698바이트, SHA-256
  `e1872e2a581a1459e2cc8014adbe82f9ceb8578a166c1e9512799236c553583f`다.
  `frontend/build/release-candidates/app-v0.2.0-android-b1/app-release.aab`에 보존했다.
  실제 패키지 `com.huturu.app`, 버전 `0.2.0`, 빌드 `1`, minSdk 24, targetSdk 36,
  `debuggable=false`를 확인했다.
- bundletool validate와 JAR 서명 검증이 통과했고 AAB 서명 인증서는 복구한 업로드 키 인증서와 같았다.
  실제 권한은 INTERNET, USE_BIOMETRIC, USE_FINGERPRINT와 패키지 전용 DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION이다.
  네이티브 라이브러리는 ABI 3종에 각 4개, 총 12개다. 64-bit 라이브러리 8개의 LOAD 정렬이
  16KiB 이상이며 페이지 내 offset·가상 주소가 일치했다. 번들 설정의 native library alignment도
  `PAGE_ALIGNMENT_16K`였다. 이 정적 검사는 16KB 기기 실행 성공을 뜻하지 않는다.
- AAB의 arm64 Dart 바이너리에서 실제 운영 API·Google 웹 OAuth ID·카카오 Native key를 확인했고,
  manifest의 카카오 콜백 scheme도 같은 공개 설정과 일치했다. 공개 값의 원문은 기록하지 않았다.

## 검증 기록

- 배포 후보 CLI: `backend/.venv/bin/python -m pytest backend/tests/deployment/test_prepare_release.py -q`
  결과 48개 통과, Starlette의 httpx 사용 관련 경고 1개. 로그는 로컬 임시 경로에 보관했다.
- Flutter 분석: `flutter analyze --no-pub` 통과.
- Flutter 전체 검사: `flutter test --no-pub --reporter expanded`, 1,992개 통과, 4분 51초.
  Dart 코드가 바뀌지 않은 이번 통합 범위에 대해 실행한 결과다.
- 서명 구현자는 수정 전 실제 `:app:validateSigningRelease`가 입력 없이 성공하는 것을 재현했다.
  수정 후 실제 Gradle 명령의 12개 사례를 확인했다. Release 환경변수 누락, 필수 필드 4종 누락,
  없는 키 파일, 잘못된 저장소 비밀번호·키 비밀번호·별칭은 실패했다. 일회용 키로 사용자 정의 검사와
  Android 플러그인의 서명 검증이 성공했고, Release 정보 없는 Debug 검증도 성공했다.
  `preReleaseBuild`의 누락 입력 실패와 AAB 작업 그래프의 선행 검사 연결도 확인했다.
  일회용 키는 검증 후 제거했으며 영구 업로드 키의 백업 복구 증거로 사용하지 않았다.
- 코드 리뷰의 Standards·Spec 양 축에서 코드 결함·범위 확장 지적은 없었다.
  정상 AAB·백업 복구·양 플랫폼 실행·Play 실기기 검증이 남았음을 별도로 확인했다.
- Android Emulator: Pixel 3a API 33의 800MiB 내부 저장소에서는 APK 설치가
  `INSTALL_FAILED_INSUFFICIENT_STORAGE`로 실패했다. 데이터를 지우지 않고 이 작업에서 부팅한
  read-only 에뮬레이터를 종료한 뒤 Medium Phone / Android 16 / API 36을 사용했다.
  기존 `com.huturu.app`이 없음을 확인한 뒤 실제 AAB에서 bundletool로 변환한 universal APK를
  설치하고 제품 로그인 화면을 실행했다. 버전 `0.2.0(1)`, 실행 PID와 화면을 확인했고 최근 오류 로그에서
  fatal·unhandled 진단은 없었다. 이미지: `/private/tmp/clipback-android-release-runtime/android-product-login.png`.
  로컬 APK는 bundletool의 Debug 서명을 사용하므로 Play 설치·인증 증거로 사용하지 않았다.
  CUA에서 Android 에뮬레이터 앱을 선택할 수 없어 수동 버튼 이동은 미검증이다.
- 실행 후 이 작업에서 생성한 Android 중간 빌드 폴더만 정리하고 Gradle daemon 두 개를 종료해
  iOS 실행 검증에 필요한 공간·메모리를 확보했다. 최종 AAB와 기존 iOS 산출물은 보존했다.
- iOS Simulator: 제품 진입점과 실제 공개 SDK 설정 3개를 사용한 정상 Debug 시뮬레이터 빌드가
  Xcode 106초에 성공했다. 시뮬레이터용 앱 버전은 기존 pubspec의 `0.1.0(1)`이며 새 iOS 배포 후보는 아니다.
  iPhone 16 Pro / iOS 18.6의 기존 앱을 삭제하지 않고 갱신해 로그인 화면과 실행 PID를 확인했다.
  Xcode 27의 DeviceHub에서 카카오·Apple·Google·게스트 버튼을 확인했다. 홈 버튼 동작은
  화면 변화가 확인되지 않아 이동 성공으로 집계하지 않았다. 이미지:
  `/private/tmp/clipback-android-release-runtime/ios-product-login.png`.
- 기존 iOS 배포 IPA의 SHA-256은 `3482f4a77d83557b9c7d2abc8d43ba331de82f9ffbac11079e23f1341ccbf6c0`로
  이전 빌드 기록과 같아 보존을 확인했다.
- Release 환경변수를 명시적으로 제거한 상태의 정상 Debug·androidTest APK 빌드는 39초에 성공했다.
  Android API 36에서 기존 ShareStore 15개·ShareActivity 4개·ShareServiceFixture 9개, 총 28개
  네이티브 검사가 131.879초에 통과했다. HTTP 대역은 정확히 `10.0.2.2:18765`로 제한했고 운영 API로
  우회하지 않았다. 테스트에서 생성한 이미지 한도 오류 스크린샷 두 개도 로컬 증거 폴더에 보관했다.
  이후 이 작업의 read-only AVD·대역 서버만 종료하고 기존 iOS 시뮬레이터의 부팅 상태를 복원한다.
- Play 설치·실제 OAuth·운영 저장·공유 검증은 미실행이며 자동·로컬 결과로 대체하지 않는다.

## 공급자 설정 사전 조회

- Google Cloud의 기존 Android Debug OAuth 클라이언트는 `com.clipback.frontend`로 등록돼 있었다.
  새 Play 설치본은 실제 앱 서명 인증서와 `com.huturu.app`에 맞는 등록이 필요하다.
- 카카오 허투루 앱의 기존 Native 키도 Android 패키지가 `com.clipback.frontend`,
  iOS 번들 ID는 `com.huturu.app`이었다. 아직 값을 수정하거나 저장하지 않았다.

추가 업로드·설치 검증 결과는 실제 실행한 뒤 이어 기록한다. #113의 준비 범위는 완료했으며,
#112·#114·#115는 실제 Play 제공·실기기 검증 전까지 미완료 상태로 유지한다.

이 기록은 진행 상황이며 Android 내부 테스트 제공·실기기 검증의 완료 기록이 아니다.
