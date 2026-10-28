# Android 내부 테스트 배포 구현·검증

최초 기록일: 2026-10-28 KST. 시작 소스는 `7f0822f`, 통합 브랜치는
`feature/android-internal-testing`이다. 실행 기준은 [명세 #112](https://github.com/clip-back/clipback/issues/112)와
[승인한 티켓 분할](2026-10-28-android-internal-test-tickets.md)이다.

## 진행 범위

| 티켓 | 이번 진행 | 남은 완료 조건 |
| --- | --- | --- |
| [#113](https://github.com/clip-back/clipback/issues/113) | 업로드 키 Release 서명, 1Password 복구, 정상 AAB·양 플랫폼 시작·네이티브 공유 검사 완료 | 없음; Play 제공·실기기 기능은 #114~#115 |
| [#114](https://github.com/clip-back/clipback/issues/114) | 같은 AAB 업로드·처리, 공급자 등록, 본인 참여·Play 설치·서명 일치, 실제 Google·카카오 로그인·같은 제공자 재로그인 완료 | 없음; 저장·공유·데이터 유지 검증은 #115 |
| [#115](https://github.com/clip-back/clipback/issues/115) | 빌드 1 저장·공유·계정 격리·재시작 검증, 사진 압축 결함 재현·수정, 양 플랫폼 실행, Play 빌드 2 업데이트와 새 사진 원본·재시작 후 5개 유지 확인 완료 | 없음; 최종 통합 리뷰와 상위 완료 조건 대조 완료 |

사용자는 1Password, 본인 Google 계정과 Galaxy S25 Ultra를 지정했다. 기기는 USB 디버깅으로
연결했으며 Android 16 / API 36을 확인했다. 개인 계정 주소와 기기 일련번호는 저장소에 기록하지 않는다.
이후 사용자가 1Password 설치·로그인을 완료해 개인 금고를 사용했다. 피드백 연락처는 사용자 승인을 받아 내부 출시 노트에 반영했다.
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

## #114 Play 제공과 실제 인증 검증

### 2026-10-28 14:01 KST 실행 전 확인

- 구현 브랜치 `feature/android-play-internal`은 통합 브랜치의 `c0eb82c`에서 시작했고 작업 전 변경은 없었다.
  #114의 최신 본문과 댓글 없음 상태를 GitHub 연결로 확인했다.
- 고정 AAB의 크기 72,779,698바이트와 SHA-256
  `e1872e2a581a1459e2cc8014adbe82f9ceb8578a166c1e9512799236c553583f`를 다시 확인했다.
  소스·키·빌드를 변경하거나 AAB를 다시 만들지 않았다.
- Play의 `허투루` / `com.huturu.app`에는 이미 사용 중인 앱 서명 키가 있었다.
  키 생성·변경·교체를 실행하지 않았다. 현재 키의 `deployment_cert.der`를 내려받아
  Play 페이지의 SHA-256과 일치함을 확인했다. 페이지에는 첫 업로드 전 업로드 인증서 항목이 없었다.

| 인증서 용도 | SHA-256 | SHA-1 또는 key hash |
| --- | --- | --- |
| 실제 Play 앱 서명 인증서 | `a1979238b888d7cb058dd60d7c59c65dc3289dc5a32b99ea136e37456b1af680` | SHA-1 `9F:66:5D:63:FA:49:D4:71:B2:1F:C3:B2:0C:97:76:87:C6:7C:BB:0E` |
| 같은 인증서의 카카오 key hash | 위와 동일 | `n2ZdY/pJ1HGyH8OyDJd2h8Z8uw4=` |

- 인증서 파일은 비밀키가 아닌 공개 인증서다. 다운로드 묶음의 이전 hybrid 인증서는
  현재 Play 앱 서명 인증서로 사용하지 않았으며 양자 컴퓨팅 대비 베타나 키 변경을 설정하지 않았다.
- Play 내부 테스트의 빈 출시 초안을 만들고 업로드 화면을 준비했다. 업로드는 아직 실행하지 않았다.
- Google 프로젝트 `clipback-507914`의 새 Android 클라이언트 `Clipback Android Play`를
  `com.huturu.app`과 위 SHA-1로 입력했으나 `만들기`는 누르지 않았다.
  기존 Android Debug·iOS·Backend 클라이언트는 수정하지 않았다.
- 카카오 허투루 앱의 같은 Native 키 편집 화면에서 Android 패키지를 `com.huturu.app`으로 바꾸고
  기존 해시를 보존한 채 위 key hash를 추가하는 초안을 준비했다. `저장`은 누르지 않았다.
  Native 키와 iOS 번들 ID는 유지한다. 패키지 입력란이 하나여서 변경하면
  `com.clipback.frontend`로 설치된 예전 Android 개발 앱의 카카오 로그인이 중단될 수 있음을 확인 요청에 포함했다.
- 연결된 Galaxy S25 Ultra는 `SM-S938N`, Android 16 / API 36이었다.
  `com.huturu.app`은 미설치이며 이전 `com.clipback.frontend`만 설치되어 있었다.
  실기기에 로컬 APK를 설치하거나 자동 입력을 실행하지 않았다.
- 업로드할 실제 파일·대상 트랙과 영구 Google·카카오 등록 변경의 화면을 준비한 뒤
  브라우저 작업 정책에 따른 실행 시점 확인을 요청했다. 개인 이메일·기기 일련번호·비밀값은 저장소에 기록하지 않는다.

이 시점의 업로드·Play 처리·테스터 제공·설치·실제 Google/카카오 로그인은 모두 미실행이다.

### 2026-10-28 14:03~14:13 KST 업로드·공급자 등록·본인 제공

- 사용자가 준비된 AAB의 내부 테스트 업로드와 본인 한 명 제공, Google Android 클라이언트 생성,
  카카오 패키지·Play 해시 등록, 본인 이메일의 내부 피드백 연락처 사용을 명시적으로 승인했다.
- Chrome 파일 업로드 API가 확장의 파일 URL 권한 부족으로 실패하여 실제 파일 선택 창으로
  같은 AAB의 절대 경로를 지정했다. 확장 권한이나 보안 설정을 변경하지 않았다.
  업로드 진행률·전송 완료·Play 최적화를 거쳐 새 아티팩트 `1 (0.2.0)`, min SDK 24,
  target SDK 36이 표시되는 것을 확인했다. 중복 AAB를 올리거나 소스를 다시 빌드하지 않았다.
- 첫 업로드 뒤 Play 앱 서명 페이지에 업로드 키가 나타났다. 내려받은 `upload_cert.der`의
  SHA-256은 `b076988adba56995398d726e495fff5918a18e269a8bd0da687e986587e59ad0`로,
  #113의 AAB 업로드 인증서와 일치했다. 이 인증서를 실제 설치본의 앱 서명 인증서로 혼동하지 않았다.
- Google 프로젝트 `clipback-507914`에 `Clipback Android Play` 클라이언트를 생성했다.
  새 클라이언트 상세 화면을 다시 열어 `com.huturu.app`과 실제 Play 앱 서명 SHA-1이 저장됐음을 확인했다.
  기존 Debug·iOS·Backend 클라이언트는 유지했다.
- 카카오의 같은 Native 키 설정을 저장하고 다시 열어 Android 패키지 `com.huturu.app`,
  기존 key hash와 새 Play key hash, iOS 번들 `com.huturu.app`이 유지됨을 확인했다.
  키를 새로 발급하거나 어드민 키·클라이언트 시크릿을 열지 않았다.
- `Huturu Owner Internal` 이메일 목록에 승인된 본인 한 명만 넣고 내부 테스트 트랙에 저장했다.
  초대 메일·메시지는 발송하지 않았다. 이 화면에는 별도 피드백 필드가 없어 승인된 연락처를
  내부 테스트 출시 노트에 넣었다. 개인 주소는 이 기록에 복사하지 않는다.
- 테스터 지정 전의 유일한 경고는 미지정 테스터였고 지정 후 해소됐다. 내부 테스트만 저장·출시했으며
  14:10 KST에 트랙 `활성`, 버전 `0.2.0 (1)`, `내부 테스터에게 제공됨`, `검토되지 않음`을 확인했다.
  임시 앱 이름은 `com.huturu.app (unreviewed)`다. 비공개·공개 테스트나 정식 출시를 시작하지 않았다.
- 참여 링크는 `https://play.google.com/apps/internaltest/4701724719817149461`이다.
  사용자에게 Galaxy에서 승인된 본인 Play 계정으로 참여·Play 설치 후 로그인 화면에서 멈추도록 요청했다.
  목록 지정·내부 제공과 실제 참여·설치를 별도로 구분한다.
- 사용자는 운영 앱 로그인에는 별도 Google 테스트 계정을 선택하고 그 계정의 허용 목록 추가를 요청했다.
  Google의 기존 외부·테스트 중 상태를 유지한 채 해당 계정만 테스트 사용자로 추가하고
  저장 후 기존 한 명과 합계 두 명임을 확인했다. 관리 권한이나 Play 테스터를 추가한 것이 아니다.
- 실제 제공된 고정 AAB에 포함된 기존 Android 변경 12개를 CHANGELOG의 앱 0.2.0 아래로 옮기고
  후보 기록에 연결했다. 서버 항목은 미배포에 유지하고 정식 공개 완료로 표시하지 않았다.

이 시점의 Play 설치·실제 Google/카카오 로그인과 재로그인은 아직 미실행이다.

### 본인 참여 완료 뒤 Play Store 설치 링크 미반영

- 사용자가 Galaxy의 Google Play Store에서 `항목을 찾을 수 없습니다` 화면을 확인했다.
  실제 설치가 되지 않았으므로 앱 시작·로그인·저장 검증으로 진행하지 않았다.
- 승인된 본인 계정으로 Chrome의 정확한 참여 링크를 열었을 때
  `You’re a tester for com.huturu.app (unreviewed)`가 표시됐다. 참여 버튼은 없고
  테스트 탈퇴 버튼만 있어 본인 참여 완료를 확인했다. 에이전트가 새 계정으로 참여하지 않았다.
- 그 참여 완료 페이지의 실제 `Download test app` 링크를 눌러도 웹 Play Store가 `Not Found`를 반환했다.
  따라서 실기기의 계정 불일치만으로 설명할 수 있는 오류는 아니다. 같은 시점에 Play Console은 계속
  `0.2.0 (1)`, `내부 테스터에게 제공됨`, 게시일 14:10 KST를 표시했다.
- [Google의 현재 내부 테스트 안내](https://support.google.com/googleplay/android-developer/answer/9845334?hl=en)는
  첫 테스트 게시 후 링크가 테스터에게 제공되기까지 몇 시간이 걸릴 수 있다고 설명한다.
  본인 참여 완료·콘솔 제공 상태·양쪽 Store 오류를 종합하면 첫 배포 반영 지연으로 추정되지만,
  확정 원인이나 해소 시각으로 보고하지 않는다.
- 같은 참여 링크의 다운로드가 열리는지 나중에 다시 확인해야 한다. 새 빌드·중복 업로드·테스터 확대나
  비공개·정식 출시로 우회하지 않았다. 실제 Play 설치와 Google·카카오 로그인·재로그인은 미검증이며
  #114와 상위 #112를 완료 처리하지 않는다. #115는 이 설치 경계가 해소된 뒤 진행한다.

### 2026-10-28 14:21 KST Store 반영 해소와 실제 Play 설치

- 문서 검토·커밋 뒤 같은 본인 참여 페이지의 `Download test app`을 한 번 다시 확인했다.
  이번에는 `com.huturu.app (unreviewed)` 앱 페이지와 설치 버튼이 열렸다.
  초기 Not Found 결과를 삭제하지 않고 이 해소 결과를 이어 기록한다.
- 사용자가 Galaxy 설치 완료와 로그인 화면 표시를 알렸고 읽기 전용 ADB로 실제 설치를 확인했다.
  `com.huturu.app`, `versionName=0.2.0`, `versionCode=1`, `installer=com.android.vending`이었다.
  이전 `com.clipback.frontend` 개발 앱과 구분했으며 해당 앱의 데이터는 건드리지 않았다.
- 설치된 공개 코드의 `base.apk`만 로컬 증거 폴더로 내려받아 `apksigner verify --print-certs`를 실행했다.
  검증 종료 코드는 0이고 실제 설치본의 SHA-256·SHA-1이 위 Play 앱 서명 인증서와 정확히 일치했다.
  비공개 앱 데이터·토큰은 읽지 않았고 기기에 로컬 APK 설치나 입력 자동화를 수행하지 않았다.
- 실제 전경 Activity는 `com.huturu.app/com.clipback.frontend.MainActivity`였다.
  이전 Java namespace는 유지한 채 배포 패키지가 `com.huturu.app`임을 확인했고
  카카오·Google·게스트 버튼이 있는 실제 로그인 화면을 캡처했다.
- 이 Galaxy의 `getconf PAGESIZE`는 4096이다. #113의 16KB 정적 산출물 검사와 구분하며
  이 실행을 16KB 페이지 실기기 검증으로 보고하지 않는다.
- 이후 별도 테스트 계정의 실제 Google 로그인부터 사용자 수동 흐름으로 진행한다.
  Play 설치 완료를 실제 OAuth나 운영 저장·공유 성공으로 대체하지 않는다.

### 2026-10-28 14:23~14:26 KST 실제 Google 로그인과 재로그인

- 사용자가 실제 Play 설치본의 Google 버튼으로 승인된 별도 테스트 계정을 선택하여 로그인 완료를 알렸다.
  전경 앱은 계속 `com.huturu.app`이었고 첫 로그인 뒤 소개 첫 화면을 관찰·캡처했다.
  이 시점에는 소개 화면을 홈 진입 성공으로 기록하지 않았다.
- 소스의 실제 경로를 확인해 소개의 `다음` 두 번·`시작하기`, 마이의 우상단 계정 관리 설정 아이콘,
  계정 관리의 `로그아웃`, 확인 화면의 `확인`을 안내했다. 사용자가 소개 완료·홈 진입 후 이 경로로
  로그아웃하고 같은 Google 테스트 계정으로 다시 로그인한 뒤 `재로그인 완료`를 알렸다.
- 그 응답 뒤 다시 전경 패키지를 확인하고 빈 콘텐츠 홈 화면을 캡처했다.
  실제 Google 인증·같은 제공자 재로그인과 로그인 후 홈 도달을 확인한 것이며,
  콘텐츠 저장·공유·재시작 후 데이터 지속성은 이 화면으로 증명하지 않는다.
- 카카오 로그인 전 설정을 읽어 기존 카카오 로그인 사용 설정과 OpenID Connect가 모두 ON임을 확인했다.
  추가 설정을 바꾸지 않았다. 설치된 카카오톡 계정을 우선 사용하는 현재 소스 동작에 따라
  제시되는 계정이 의도한 테스트 계정일 때만 수동 진행하도록 안내하며 개인 카카오톡의 삭제·계정 변경을 요구하지 않는다.

### 2026-10-28 14:28~14:30 KST 실제 카카오 로그인과 #114 완료

- 사용자가 앱에서 로그아웃한 뒤 제시되는 카카오 계정이 의도한 허투루 테스트 계정인지 확인하고
  카카오 로그인·홈 진입을 완료했다고 알렸다. 그 응답 뒤 `com.huturu.app` 전경과 빈 콘텐츠 홈을 캡처했다.
- 같은 계정 관리 경로에서 로그아웃·확인 후 같은 카카오 테스트 계정으로 재로그인하도록 요청했고
  사용자가 `재로그인 완료`를 알렸다. 그 뒤 다시 실제 전경 앱의 홈 화면을 캡처했다.
- Google·카카오 조작·계정 선택·OAuth 완료는 사용자가 수행했고, 에이전트는 완료 응답과
  실제 기기의 설치 출처·버전·서명·전경 앱·화면을 읽기 전용으로 대조했다.
  비밀번호·인증 코드·토큰·개인 계정 주소는 저장소에 남기지 않았다.
- #114의 같은 AAB 제공·본인 Play 참여·설치·실제 양 제공자 인증과 재로그인 조건을 완료했다.
  앱 소스·서명 키·AAB는 변경하지 않았고 새 후보·로컬 실기기 APK 설치·추가 테스터·초대·정식 출시는 없었다.
- 후속 #115에는 Play 설치본 `0.2.0(1)`과 실제 앱 서명 일치 기록, 양 제공자 인증 결과,
  현재 카카오 테스트 계정으로 열린 빈 콘텐츠 홈 상태를 전달한다. 아직 실제 콘텐츠를 저장하지 않았으며
  링크·사진 저장, 시스템 공유, 재로그인·재시작 후 같은 계정의 데이터 유지는 #115에서 검증해야 한다.
- 이번 후속 커밋은 문서만 변경하므로 링크·앵커, 변경 항목 내용 보존, 개인 주소 미포함과
  `git diff --check`를 확인한다. #113의 자동·에뮬레이터·시뮬레이터 검사는 이번에 재실행한 것으로 보고하지 않는다.

## #115 Play 저장·공유·재진입 검증과 원본 보존 수정

### 2026-10-28 14:38~15:04 KST 빌드 1의 실제 사용자 흐름

- 작업 브랜치 `feature/android-play-save-share`는 통합 브랜치의 `181c5b9`에서 시작했고 최초 작업 트리는 깨끗했다.
  실제 설치본은 #114의 동일 AAB 소스 `311f2788e479b551c6bf7fec157f5c94077fd3d5`를 사용했다.
- 시작 직전 읽기 전용 ADB로 Galaxy S25 Ultra `SM-S938N`, Android 16 / API 36,
  `com.huturu.app` 버전 `0.2.0`, 빌드 `1`, 설치 출처 `com.android.vending`을 재확인했다.
  #114에서 인증한 카카오 테스트 계정의 빈 홈으로 시작했다.
- 사용자가 실제 터치·계정 선택·저장·공유를 수행했다. 에이전트는 단계 요청 전에 최대 180초 녹화를
  시작하고 응답 뒤 스크린샷을 확보했다. 입력 자동화·비공개 앱 데이터/토큰 조회·데이터 초기화·삭제·사이드로드는 없었다.
- 앱 내 링크는 공개 `https://example.com/?huturu-test=20261028-app`을 사용했다. 사전 HTTP 200을
  확인하고 홈 `+` → `링크 첨부` → `허투루에 저장하기` → `닫기` → 목록 카드 → 상세/전문 보기로 진행했다.
  사용자가 `링크 저장 재열람 완료`를 알렸고 실제 Example Domain 상세를 캡처했다.
- 사진은 기존 공개 로고 `frontend/android/app/src/main/res/drawable-nodpi/splash_a01_logo.png`만 사용했다.
  PNG 596×200, 7,454바이트, SHA-256은 `ce978c44205ead268d055c7b74a56a835092f5cfa7712d4422860d855d7f841f`다.
  기기의 새 `Download/huturu-play-test-20261028-1445-logo.png` 경로가 비어 있음을 확인한 뒤 그대로 복사하고
  미디어 색인을 요청했다. 기기 파일 해시도 일치했으며 개인 사진은 테스트 입력으로 사용하지 않았다.
- `사진 첨부` → 해당 파일 선택 → 저장 → 닫기 → 목록 → `원본 이미지 보기`에서
  사용자가 `사진 저장 원본 재열람 완료`를 알렸다. 사진이 다시 열렸지만 아래 원본 변환 결함이 확인돼
  이 결과를 선택 파일의 원본 바이트 보존 성공으로 집계하지 않는다.
- 외부 링크 공유의 첫 시험 주소는 `https://example.com/?huturu-test=20261028-share`였다.
  실제 Android 공유 화면은 `Instagram 또는 YouTube 링크만 저장할 수 있습니다.`로 거절했다.
  `ShareInput.java`의 기존 허용 호스트와 일치하는 지원하지 않는 입력 사례다. 일반 웹 링크를 받도록 기능을 넓히지 않았다.
- 지원되는 공개 `https://youtu.be/jNQXAC9IVRw`로 다시 확인했다. HTTP 200과 YouTube 공식 oEmbed의
  `Me at the zoo` 응답을 먼저 확인했다. 실제 송신 앱은 YouTube였으며 그 앱의 공유 → 더보기 → Android 공유 대상
  `허투루` → `저장` → `저장했어요` → `닫기` 뒤 YouTube로 돌아왔다. 사용자가 공유 저장·복귀 완료를 알렸고
  녹화에서도 성공 화면과 송신 앱 복귀를 확인했다. 콘텐츠 제목·요약은 이후 서버 처리로 바뀔 수 있어 식별 근거로 고정하지 않는다.
- Samsung 내 파일에서 같은 테스트 PNG 한 장을 선택해 실제 공유 메뉴 → 허투루 → 저장 → 성공 → 닫기로 진행했다.
  사용자가 `이미지 공유 저장 내 파일 복귀 완료`를 알렸고 송신 앱 복귀를 캡처했다.
  네이티브 입력은 `content:` 이미지 URI를 실제 `ContentResolver`로 읽는 기존 경로다.
- 허투루에 다시 진입해 최신 공유 사진의 원본 로고를 다시 열었다. 사용자는
  `공유 사진 원본 재열람 완료, 목록 4개`를 알렸다. 공유 사진의 실제 상세와 원본 표시를 캡처했다.
- 카카오 계정에서 로그아웃하고 #114의 동일 Google 테스트 계정으로 로그인한 뒤 사용자는
  `Google 목록 0개, 카카오 항목 안 보임`을 알렸다. 빈 홈을 캡처했다.
  이어 같은 카카오 테스트 계정으로 재로그인해 `카카오 재로그인 목록 4개, 기존 결과 유지`를 알렸고
  아카이브 전체보기의 `불러온 4개`와 기존 결과를 캡처했다. 계정 병합·데이터 삭제는 수행하지 않았다.
- 전체 재시작은 실행 중 PID `7288` 확인 → `adb shell am force-stop com.huturu.app`만 실행 → PID 없음 확인 →
  사용자가 기존 Play 앱 아이콘으로 다시 실행하는 방식으로 확인했다. 새 PID는 `31703`이었다.
  사용자는 `재시작 후 4개 유지, 원본 재열람 완료`를 알렸고 재시작 후 원본 표시를 캡처했다.
  이 검증은 메모리에 남은 화면 복귀와 구분하지만, 위 앱 내 사진의 원본 변환 결함을 해소하지는 않는다.

### 사진 원본 변환의 원인과 수정

- 같은 PNG를 앱에서 첨부한 원본 화면에는 검은 배경이 생겼고, 내 파일의 이미지 URI 공유로 저장한 원본은
  투명 배경을 유지했다. `save_content_screen.dart`의 `FilePicker.pickFiles(type: FileType.image, withData: true)`는
  압축 허용값을 지정하지 않았다.
- 잠긴 `file_picker` 버전은 8.3.7이다. 해당 버전의 공식
  [Dart API](https://raw.githubusercontent.com/miguelpruivo/flutter_file_picker/8.3.7/lib/src/file_picker.dart)는
  `allowCompression=true`, `compressionQuality=30`을 기본값으로 두고,
  [Android 입력 처리](https://raw.githubusercontent.com/miguelpruivo/flutter_file_picker/8.3.7/android/src/main/java/com/mr/flutter/plugin/filepicker/FilePickerDelegate.java)는
  이미지에 압축이 허용되면
  [JPEG 변환](https://raw.githubusercontent.com/miguelpruivo/flutter_file_picker/8.3.7/android/src/main/java/com/mr/flutter/plugin/filepicker/FileUtils.java)을 거친다.
  이 동작은 [선택 원본을 변환 없이 보관하는 결정](../adr/0001-preserve-account-image-originals.md)과 충돌한다.
- 앱 코드 수정은 파일 선택 요청의 `allowCompression: false` 한 줄이다. 선택한 파일의 이름·바이트를
  기존 업로드 경로에 전달하며 화면 구조·Figma 디자인·네이티브 공유·서버·스키마는 바꾸지 않았다.
  이미 JPEG로 바뀌어 저장된 기존 테스트 사진과 다른 사용자 데이터를 삭제하거나 복원하지 않았다.
- 기존 `screenshot_auth_test.dart`의 공개 앱 저장 화면 → 실제 multipart 업로드 경계에 회귀 사례를 추가했다.
  외부 파일 선택기 대역은 문서화된 Android 동작처럼 압축 허용 시 유효한 JPEG와 이름을 돌려주며,
  테스트는 업로드된 바이트와 파일명이 선택 PNG 원본인지 확인한다. 내부 함수 호출·인자만 맞추는 검사는 추가하지 않았다.
- 기존 코드에서 이 테스트는 PNG 첫 바이트 `137` 대신 JPEG 첫 바이트 `255`를 업로드해 실패했다.
  한 줄 수정 뒤 같은 테스트가 통과했고 저장 인증·원본 조회·저장 완료·수동 초안 보존·공유 생명주기 관련 102개가 통과했다.
  `flutter analyze --no-pub`은 문제 없음, `flutter test --no-pub --reporter expanded`는 전체 1,993개가 통과했다.
  변경하지 않은 CLI·네이티브 공유 검사는 이번에 재실행한 것으로 보고하지 않는다.

### 증거 보관과 남은 완료 조건

수정 소스 `8aeb8f17260749472f596057ec9f226e25304d05`로
[Android 0.2.0 빌드 2 후보](../releases/app-v0.2.0-android-b2.md)를 준비했다.
2026-10-28 15:16 KST Play의 최신 업로드 빌드가 1임을 다시 확인하고 기존 CLI로 번호를 예약했다.
정상 제품 진입점의 Release AAB 빌드는 127.8초에 통과했다. 복원한 기존 업로드 키를 사용했으며,
bundletool 검증·JAR 서명·manifest·공개 SDK 설정·ELF64 8개 16KB 정렬·번들 정렬을 확인했다.
산출물 경로·크기·해시와 번호 확인 근거는 새 후보 기록에 보존한다. 빌드 1과 iOS 빌드 6 산출물은 덮어쓰지 않았다.

- 새 AAB에서 공식 bundletool로 만든 Emulator 전용 Debug 서명 APK를
  Medium_Phone / Android 16 API 36 / 1080×2400 / 420dpi에 설치했다.
  `am start -W`는 26,770ms 뒤 시간 초과를 반환했지만, 이후 제품의 실제 로그인 화면과 PID 3766을 확인했다.
  최근 AndroidRuntime·Flutter 오류 진단 500행 범위의 오류는 0개였다.
  사진 선택·OAuth·운영 쓰기·실제 Play 서명·16KB 페이지 실행은 이 검사 범위가 아니다.
  `/private/tmp/clipback-android-b2-runtime/`에 화면·metadata·시작 로그와 범위를 보관했다.
  모든 명령은 `emulator-5560`을 명시했으며 물리 기기를 호출하지 않았다. 본 작업 AVD와 Gradle 데몬을 종료했다.
- 같은 수정 소스를 iPhone 16 Pro / iOS 18.6에 정상 제품 진입점·운영 API·기존 공개 SDK 설정으로 빌드했다.
  Xcode 빌드는 49.4초에 성공했고 기존 컨테이너를 보존했다. iOS 개발용 버전은 기본값 0.1.0(1)이며,
  0.2.0 빌드 6 Release나 TestFlight를 바꾸지 않았다.
- 실제 UI로 새 게스트 테스트 계정을 만들고 공개 로고 한 장을 PHPicker에서 선택했다.
  선택 직후 생성된 `Documents/picked_images` 파일 한 개와 저장·원본 재열람 후 생성된
  `clipback-originals-v1` 캐시 파일 한 개만 대조했다. 두 파일 모두 PNG 7,454바이트·596×200 RGBA이며,
  원본 SHA-256 `ce978c44205ead268d055c7b74a56a835092f5cfa7712d4422860d855d7f841f`와 일치했다.
  임의 계정 데이터·환경 설정·키체인·토큰 파일은 읽지 않았다. 이 검증은 iOS OAuth·실기기·Release 배포 증거가 아니다.
  `/private/tmp/clipback-ios-picker-fidelity-20261028/`의 선택·저장·원본 재열람 화면과 메타데이터에 기록했다.
- 사용자가 정확한 빌드 2 AAB의 업로드·기존 본인 1명 내부 제공을 승인했다. 전송 직전 파일 크기·해시를
  후보와 다시 대조했다. Chrome 자동 파일 선택은 확장의 파일 URL 접근 제한으로 실패했으며 설정을 변경하지 않았다.
  기본 파일 선택창에서 빌드 2 경로를 명시해 실제 선택 URL과 폴더를 확인한 뒤 업로드했다.
  Play 최적화 후 `2 (0.2.0)`를 확인했다. 내부 출시 미리보기는 출시 준비됨 상태였고 지원 기기 감소는 0이었다.
  기존 내부 트랙에서 저장 및 출시를 확정했고, Play의 최신 `0.2.0 (2)`와 `내부 테스터에게 제공됨`,
  2026-10-28 16:07 KST 게시 시각을 확인했다. 테스터·OAuth·카카오 설정을 바꾸지 않았다.
  화면은 기존 증거 폴더의 `play-b2-preview.png`, `play-b2-available.png`에 보관했다.
  Galaxy의 기존 앱을 삭제하지 않고 Play에서 업데이트하도록 요청했다.
- 사용자는 `업데이트 완료, 기존 목록 4개`를 알렸다. 실제 기기에서 0.2.0(2)·설치 출처 `com.android.vending`과
  기존 Play 서명 인증서 일치를 확인했고 아카이브 전체보기의 `불러온 4개`를 캡처했다.
  공개 base APK만 읽어 서명을 확인했으며 개인 앱 데이터는 읽지 않았다.
  `phase9-b2-updated-four.png`, `play-b2-install-proof.json`에 기록했다.
  실제 기기 페이지 크기는 4,096바이트이며 16KB 페이지 기기 실행으로 표시하지 않는다.
- 같은 카카오 테스트 계정에서 앱 내 사진 선택기로 같은 공개 PNG를 새로 저장했다. 사용자는 `새 사진 원본 정상`을 알렸고,
  16:12에 새로 저장한 사진의 원본 창에서 검은 사각형 없이 로고가 표시됨을 캡처했다.
  기기에서 원본 파일 바이트를 추출한 검증은 하지 않았다. Flutter의 실제 multipart 경계 회귀 검사와
  iOS의 실제 선택·원본 캐시 바이트 대조는 각각 별도 근거다.
- PID 16948의 허투루만 force-stop하고 PID가 없음을 확인했다. 사용자가 다시 앱을 실행하고
  `재시작 후 5개 유지, 새 사진 원본 정상`을 알렸다. 새 PID 21027과 같은 새 사진 원본의 정상 표시를 캡처했다.
  5개는 사용자가 전체 목록에서 확인한 실제 개수이며, 이 단계의 화면 증거는 새 사진의 재열람 화면이다.
  기존 4개와 새 테스트 사진을 보존했고 초기화·삭제·앱 제거·다른 앱 조작은 수행하지 않았다.

증거는 저장소 밖 `/private/tmp/clipback-android-save-share-evidence/`에 보관한다.
브라우저 제안·계정 선택·개인 다운로드 항목 등이 섞인 원본 녹화와 `*-private` 화면은 비공개로 유지하며
공개 저장소나 최종 첨부에 포함하지 않는다. 안전한 완료 화면과 원본 재열람 화면만 전달한다.

| 확인 범위 | 증거 파일 | 해석 |
| --- | --- | --- |
| 앱 링크 상세 | `phase1-app-link-reopened.png` | 실제 저장 뒤 목록에서 연 상세 |
| 앱 사진 재열람·원본 결함 | `phase2-app-photo-original.png` | JPEG 변환으로 원본 보존 실패 |
| 지원하지 않는 외부 링크 | `phase3-unsupported-link.png` | 기존 호스트 제한의 실제 오류 안내 |
| YouTube 공유 저장·복귀 | `phase3b-youtube-saved.png`, `phase3b-youtube-save-return.mp4` | 녹화의 안전한 성공→복귀 부분만 시간으로 잘라낸 7.63초 영상; UI 픽셀 보정 없음 |
| 이미지 URI 공유 저장·재열람 | `phase4-image-uri-saved.png`, `phase5-shared-photo-original.png` | 성공과 제공 URI를 읽어 저장한 원본 표시 |
| 계정 격리·카카오 재진입 | `phase6-google-isolated-empty.png`, `phase7-kakao-four-restored.png` | Google 0개, 카카오 4개 |
| 전체 재시작 | `phase8-b1-restarted-four.png`, `phase8-b1-restarted-original.png` | 새 프로세스의 4개 목록과 기존 공유 사진 원본 재열람; 목록은 녹화 100초의 원본 프레임 |
| 재현·수정 검사 | `tdd-red.log`, `tdd-green.log`, `flutter-related.log` | 운영 API와 분리된 외부 경계 대역 검사 |
| 수정 후 전체 자동 검사 | `flutter-analyze.log`, `flutter-full.log` | 분석 문제 없음, Flutter 1,993개 통과 |
| 빌드 2 제공·Play 업데이트 | `play-b2-available.png`, `phase9-b2-updated-four.png`, `play-b2-install-proof.json` | 내부 제공, 실제 빌드·설치 출처·서명과 기존 4개 유지 |
| 빌드 2 새 사진·완전 재시작 | `phase10-b2-new-photo-original.png`, `phase11-b2-force-stop.txt`, `phase12-b2-restarted-original.png` | 수정 경로의 정상 원본과 새 프로세스 재열람, 사용자 확인 5개 유지 |

상위 명세의 완료 조건은 다음과 같이 대조한다. 앞 단계의 성공을 수정 후 새 후보의 결과로 복사하지 않는다.

| #112 완료 조건 | 현재 근거·상태 |
| --- | --- |
| 배포 대상·소스 연결 | 빌드 1의 AAB·소스·해시는 #113~#114에 연결됨; 수정 소스 `8aeb8f1`은 빌드 2 후보에 연결 |
| 업로드 키·서명·복구 | #113의 실제 Release 서명·1Password 복구 완료; 이번에 키를 바꾸지 않음 |
| Release AAB | 빌드 1 보존; 빌드 2 정상 생성·무결성·정적 호환성 검사 완료 |
| 내부 업로드·처리·본인 제공 | #114에서 빌드 1 완료; 수정 빌드 2도 2026-10-28 16:07 KST 기존 본인 내부 테스터에게 제공됨 |
| 실제 Play 설치 | #114의 빌드 1 신규 설치와 별도로 수정 빌드 2의 실제 Play 업데이트·패키지·버전·현재 서명, 기존 4개 유지 확인 완료 |
| 실제 핵심 기능 | 빌드 1의 양 제공자 인증·저장·공유·재진입 확인. 실패했던 앱 사진 경로는 수정 빌드 2의 실제 Play 업데이트에서 신규 저장·원본 표시·완전 재시작 후 5개 유지로 재검증 완료 |
| 증거·기록 | 자동/운영/실기기, 빌드 1/2, 비공개 원본/안전한 첨부를 구분. 새 후보 결과와 최종 두 축 리뷰까지 확인 완료 |

- 빌드 1에서 확인한 사진 원본 변환 결함은 실패 이력으로 남긴다. 이를 수정한 빌드 2의 실제 Play 업데이트·새 사진·
  완전 재시작 검증을 완료했다. 최종 통합 리뷰도 통과했으므로 #115와 상위 #112를 각각 완료 판단했다.
- 수정 소스의 Android Emulator 시작 확인과 iOS Simulator 실제 사진 선택·저장·원본 재열람 검증을 완료했다.
  이 수정에 대해 #113의 과거 실행을 재사용하지 않는다.
  화면 배치·디자인 변경이 없어 새 디자인이나 Figma 비교 화면을 만들지 않는다.
- Android는 기존 후보·AAB·사진 4개를 보존하고 빌드 2를 같은 내부 제공·설치 절차로 검증했다.
  새 사진을 더한 5개 유지와 원본 재열람까지 확인했다. iOS 0.2.0 빌드 6과 TestFlight는 보존하며 새 iOS Release는 범위 밖이다.
- 팀·지인 확대, 회원 탈퇴·운영 정책·스토어 정보, 비공개 12명·14일, 프로덕션 액세스·정식 출시는 실행하지 않았다.

### 최종 통합 리뷰와 전달 범위

- 비교 기준은 `164cb7c0240d4ed8a695a1a3d85bf8c07de2d083`, 검토 HEAD는 `5cba8dc`다.
  `git diff 164cb7c0240d4ed8a695a1a3d85bf8c07de2d083...5cba8dc` 전체를 독립된 두 검토자가 확인했다.
- Standards: 문서화된 저장소 기준 위반과 수정이 필요한 코드 냄새 0건.
  원본 보존 ADR, 실제 multipart 경계 회귀 검사, 현재 안내·이력·배포 기록의 역할 구분을 확인했다.
- Spec: 누락·잘못된 구현·범위 확장 0건. 빌드 1의 인증·공유 검증과 빌드 2의 변경 경로 재검증을 구분한 상태에서
  #112와 #115의 완료 근거가 갖춰졌다고 판단했다. 두 검토에서 빌드나 기기 조작을 추가 실행하지 않았다.
- 구현과 문서 커밋은 로컬 통합 브랜치 `feature/android-internal-testing`에 보존한다.
  이번 구현 요청으로 푸시·PR·원격 CI를 실행하지 않았다. 실제 내부 배포 성공과 GitHub 코드 병합을 구분한다.
- 실제 완료 근거와 체크리스트를 반영하고 #115와 #112를 각각 `completed`로 종료했다.
  #113·#114도 기존 완료 상태를 확인하고 체크리스트를 실제 완료 결과와 맞췄다.
  GitHub 연결 도구의 이슈 수정은 403으로 거부되어 기존 인증 GitHub CLI로 반영했다.
