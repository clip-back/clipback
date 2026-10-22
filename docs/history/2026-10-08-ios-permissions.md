# iOS 권한 설명·빌드와 재업로드 준비

- 최초 기록일: 2026-10-08
- 영역: iOS
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-fcfdfa687f71e5ad"></a>

이번 준비에는 Flutter **3.44.9 / Dart 3.12.2**를 사용했습니다. 터미널의 `flutter --version`으로
SDK를 먼저 확인하세요. 더 오래된 Flutter로 잠금파일을 다시 생성하지 않습니다.

<a id="b-5aa700400729f748"></a>

권한 설명을 수정한 뒤에는 새 빌드 번호로 배포용 바이너리를 다시 만듭니다. 아래는 빌드 1 다음에
빌드 2를 올리는 예시이며, 이미 업로드한 번호보다 큰 값을 사용합니다. 위 공개 앱 설정의 세 값을
환경변수에 지정하고 `SocialAuth.xcconfig`도 준비해야 합니다. Android Studio의 실행 인자는
터미널 빌드에 자동 전달되지 않습니다.

<a id="b-0724c588f1328f01"></a>

```bash
# frontend/에서 실행
flutter build ipa --release --no-pub --build-number=2 \
  --dart-define="CLIPBACK_GOOGLE_SERVER_CLIENT_ID=$GOOGLE_SERVER_CLIENT_ID" \
  --dart-define="CLIPBACK_GOOGLE_IOS_CLIENT_ID=$GOOGLE_IOS_CLIENT_ID" \
  --dart-define="CLIPBACK_KAKAO_NATIVE_APP_KEY=$KAKAO_NATIVE_APP_KEY"
open build/ios/archive/*.xcarchive
```

<a id="b-9f57b5e3f23bca74"></a>

2026-10-08 로컬 준비 검증: Flutter 3.44.9에서 `pub get --enforce-lockfile`, `analyze --no-pub`,
기존 테스트 400개와 iOS 시뮬레이터 Debug 빌드를 통과했습니다. `flutter run --debug --no-pub
--no-resident`로 iPhone 16 Pro(iOS 18.6) 시뮬레이터에 설치·실행하고 홈의 빈 콘텐츠 화면을
확인했습니다. 실제 iPhone 서명·설치, 사진 선택·업로드, TestFlight 업로드와 갤럭시 설치는
이 검증에 포함하지 않습니다.

<a id="b-ccf8721ac9b2e3a0"></a>

이 Mac에서는 생성된 `Flutter.framework`에 `com.apple.FinderInfo`가 반복 부착되어 서명이
실패했습니다([Apple의 오류 설명](https://developer.apple.com/library/archive/qa/qa1940/_index.html)).
프로젝트 소스와 전역 Flutter 설정은 유지하고, `build/ios` 생성물만
`~/Library/Caches/Clipback/` 아래로 옮겨 원래 경로에 심볼릭 링크를 만들고,
이전 위치의 속성이 남은 생성 프레임워크를 재생성한 뒤 빌드·실행했습니다.
이 링크는 로컬 환경용이며 Git에 포함하지 않습니다. `flutter clean` 등으로 빌드 폴더를
다시 만들면 동일 오류가 재발하는지 확인하고, 필요한 경우 출력 경로를 다시 분리합니다.
