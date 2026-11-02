# 앱 아이콘·시작 화면 로고를 글자 기준 가운데로 맞춤

최초 기록일: 2026-11-02 KST. 이슈 [#180](https://github.com/clip-back/clipback/issues/180), 시작 커밋 `a06a48b`,
작업 브랜치 `fix/app-icon-center`. 현재 기준은
[Figma 화면 맞춤 계획의 앱 아이콘](../figma-ui-alignment-plan.md#figma-current-app-icon)과
[A01 로고 가로 위치](../figma-ui-alignment-plan.md#figma-current-a01-logo-center)를 따른다.

## 문제와 결정

- 앱 아이콘과 시작 화면의 로고는 오른쪽 위 반짝임까지 포함한 범위가 가운데라서, 반짝임을 뺀 글자는 왼쪽으로 치우쳐 보였다.
- 2026-11-02 사용자 결정: 기준은 Figma 앱 아이콘 `189:4042`의 배치(반짝임을 뺀 글자 프레임이 가운데)다.
  시작 화면 3곳(Android 12 이상 시작 아이콘, iOS LaunchScreen, Flutter 스플래시)도 같은 기준으로 맞춘다.
  한 곳만 고치면 OS 시작 화면에서 Flutter 스플래시로 넘어갈 때 로고가 옆으로 움직인다.

## 기준 디자인

- Figma 파일 `svNWsTFh8Ws1Mpt8XQIcrN`, 2026-11-02 조회.
  - `189:4042` "EXPORT / apple-icon / 1024x1024": 글자 범위 x 167–857(1024 기준), 반짝임은 그 오른쪽으로 튀어나온다.
  - A01 `111:3380`: 반짝임까지 포함한 148.771×50 로고 프레임이 가운데다. 이번 작업 뒤 앱과 달라지는 점은 계획 문서에 적었다.
- 새 1024 원본은 `189:4042`에서 내보낸 PNG(RGBA, 알파 전부 255)다. Figma 렌더와 픽셀 차이는 최대 14/255이고,
  배경색은 원본 `#FFD65C`, Figma 렌더 `#FFD75C`로 초록 값이 1 다르다. 원본을 고치지 않고 그대로 썼다.

## 변경 내용

- 원본 보관: `frontend/branding/app-icon-1024.png`를 추가했다. `pubspec.yaml`의 assets에 넣지 않아 앱 번들에는 들어가지 않는다.
  저장소 루트의 옛 `logo.png`는 지웠다.
- 앱 아이콘: [#172 기록](2026-11-01-app-icon.md)의 명령을 그대로 `SRC=$PWD/frontend/branding/app-icon-1024.png`로 다시 실행했다.
  iOS `AppIcon.appiconset` PNG 15개, Android `mipmap-*/ic_launcher.png` 5개, `mipmap-*/ic_launcher_foreground.png` 5개다.
  적응형 아이콘 배경색 `res/values/ic_launcher_background.xml`의 `#FFD75C`는 Figma 값이라 그대로 두었다.
- 시작 화면: 그림을 새로 그리거나 다시 칠하지 않고 로고 픽셀의 위치만 옮겼다.
  - Android 12 이상 `res/drawable-xxxhdpi/splash_a01_icon.png`(1152px): 로고 전체를 오른쪽으로 12px.
  - iOS `SplashA01Brand.imageset/LaunchImage{,@2x,@3x}.png`: 로고 행(위 58·116·174px, 로고 50pt와 문구 사이의 빈 행에서 자름)만
    오른쪽으로 3·6·8px. 아래의 소개 문구 행은 바이트 단위로 그대로다.
  - 옮긴 폭은 측정한 차이에 가장 가까운 정수 픽셀이다. 밀려나는 오른쪽 끝 열과 자르는 경계 행이 모두 투명한지 확인하고,
    옮긴 영역이 원본과 한 픽셀도 다르지 않은지 비교했다.
  - Flutter `frontend/assets/figma/splash-a01-logo.svg`: path는 그대로 두고 viewBox를 `0 0 148.771 50.0002`에서
    `-5.577 0 154.348 50.0002`로 왼쪽만 넓혔다(`width`도 154.348). 글자 path의 범위 x 0–143.194의 가운데가 viewBox 가운데가 된다.
    `preserveAspectRatio="none"`이라 `SplashScreen`의 로고 폭도 154.348로 바꿨다. 그룹 232×89, 그룹 위치(가운데 +0.5, 안전 영역 가운데 −23.5),
    로고–문구 간격 16은 그대로다.
- 테스트: `splash_alignment_test.dart`에 SVG의 viewBox 가운데가 글자 범위 가운데이고 위젯 크기가 viewBox 크기와 같은지 보는 검사를 더했고,
  A01 판정(`splash_alignment_fixture.dart`)의 로고 폭을 154.348로 바꿨다.
- Android 11 이하 시작 화면 `res/drawable-nodpi/splash_a01_logo.png`(2026-11-02 사용자 결정으로 범위 추가, #180 댓글):
  로고가 596×200 캔버스를 꽉 채워(글자 x=0부터, 반짝임 x=595까지) 같은 크기로는 옮기면 반짝임이 잘린다.
  그래서 Flutter SVG처럼 캔버스를 왼쪽으로 넓혔다. 왼쪽에 투명 23px을 붙여 619×200으로 만들고 그림 픽셀은 그대로 두었다.
  같은 배율로 그리도록 `res/drawable/launch_background.xml`과 `res/drawable-v21/launch_background.xml`의 로고 폭을
  148.771dp에서 154.512dp(= 148.771 × 619 / 596)로 바꿨다. 높이 50dp와 가운데 배치는 그대로다.

## 측정

방법: 투명 이미지는 `#FFD75C` 위에 합성하고, 각 열에서 글자색 `#1A1A1A` 쪽으로 어두워진 정도의 최댓값을 구한다.
흰 반짝임과 노란 배경은 0이라 빠진다. 가장자리는 부분 덮임을 더해 소수점까지 잡는다.
iOS `SplashA01Brand`는 위 50pt(로고 행)만 본다. SVG는 `#1A1A1A` path의 곡선 극값까지 포함한 범위를 계산한다.
측정 스크립트는 저장소 밖 작업 폴더 `.utmp/`에 두었다(커밋하지 않음).

```bash
python3 -I .utmp/measure_center.py <파일>...   # 글자 가로 중심 - 캔버스 중심
python3 -I .utmp/shift_logo.py <파일> <dx> [<로고 행 끝>]   # 로고 행 이동
python3 -I .utmp/check_icon_format.py a06a48b   # 크기·모드·알파 비교
python3 -I .utmp/check_safe_radius.py           # 적응형·Android 12 시작 아이콘 반경
python3 -I .utmp/video_logo_track.py <영상>       # 영상 프레임별 글자 중심(아래 실행 절)
python3 -I .utmp/track_summary.py <위 출력>       # 같은 값 구간으로 묶기
python3 -I .utmp/make_compare.py <ios|android> ...  # 변경 전·후·Figma 비교 이미지
```

차이 = 글자 중심 − 캔버스 중심(px, 음수면 왼쪽). 기준은 각 파일의 최대 해상도다.

| 파일 | 캔버스 | 변경 전 | 변경 후 |
| --- | --- | --- | --- |
| `frontend/branding/app-icon-1024.png` | 1024 | (없음) | −0.06 |
| iOS `Icon-App-1024x1024@1x.png` | 1024 | −13.44 | −0.06 |
| Android `mipmap-xxxhdpi/ic_launcher.png` | 192 | −2.51 | +0.00 |
| Android `mipmap-xxxhdpi/ic_launcher_foreground.png` | 432 | −3.72 | +0.02 |
| Android `drawable-xxxhdpi/splash_a01_icon.png` | 1152 | −11.62 | +0.38 |
| iOS `LaunchImage.png` / `@2x` / `@3x` | 232 / 464 / 696 | −2.81 / −5.56 / −8.38 | +0.19 / +0.44 / −0.38 |
| Flutter `splash-a01-logo.svg` | 148.771 → 154.348 | −2.79 | −0.00 |
| Android 11 이하 `drawable-nodpi/splash_a01_logo.png` | 596 → 619 | −11.62 | −0.12 |

- 나머지 iOS 아이콘 14개와 Android 아이콘 8개도 변경 후 모두 ±1px 안이다(가장 큰 값은 20px 아이콘의 −0.74).
- Figma `189:4042` 렌더도 같은 방법으로 −0.06이다.
- Flutter 렌더 확인: 임시 위젯 테스트(커밋하지 않음)로 `SvgPicture`를 154.348×50, 4배율로 그려 측정하니 −0.32px(−0.08pt)이고 반짝임이 잘리지 않았다.
- 형식: 위치만 옮긴 PNG 29개는 크기·모드가 시작 커밋과 같다. iOS 아이콘은 알파 없는 RGB, Android 아이콘과 시작 이미지는 RGBA다.
  Android 11 이하 시작 로고는 폭만 596에서 619로 넓혔고(의도), 높이 200과 RGBA는 같다.
- 안전 반경: 적응형 아이콘의 글자·반짝임 중 가장 먼 픽셀은 26.85dp(안전 반경 33dp 안).
  Android 12 이상 시작 아이콘은 79.30dp(아이콘 원 반경 96dp 안).

## 판단과 남은 차이

- 화면 가운데 기준: iOS LaunchScreen과 Flutter 스플래시는 A01대로 그룹을 화면 가운데보다 0.5pt 오른쪽에 둔다.
  소개 문구 위치를 바꾸지 않기 위해 그대로 두었으므로 iOS와 Flutter에서 글자는 화면 가운데보다 0.5pt 오른쪽이다.
  Android 12 이상 OS 시작 아이콘은 OS가 화면 가운데에 둔다.
- iOS 3배율 간 정수 이동이라 1x·2x는 3pt, 3x는 2.67pt를 옮겼다. 각 파일의 차이는 1px 안이다.
- Android 11 이하 시작 로고는 위치만 옮길 수 없어 캔버스를 넓혔다. 다른 이미지와 달리 파일 크기가 바뀌므로 그리는 폭(dp)도 함께 바꿨다.
  23px은 글자 중심 차이가 가장 작은 정수 폭이다(22px이면 −0.62px).

## 자동 검사

- 구현 중 바꾼 부분만(작업 트리, 첫 커밋 `cf7ba17` 직전, `frontend/`에서):
  `flutter analyze --no-pub` 문제 없음,
  `flutter test --no-pub test/splash_alignment_test.dart test/splash_startup_test.dart test/splash_share_startup_test.dart` 25개 통과.
  테스트를 먼저 바꾼 상태에서 `splash_alignment_test.dart`가 7개 실패하는 것을 확인한 뒤 SVG·위젯을 고쳤다.
- 리뷰 반영 뒤 전체 검사(`c57c37d`와 같은 코드): `python3 ~/.heoturu-agents/verify.py --only app --log-dir .utmp/ticket-180`
  → `VERIFY result=PASS scope=app checks=3 failed=0`. `pub get`, `flutter analyze --no-pub` 문제 없음,
  `flutter test --no-pub` 2019개 통과(건너뜀 0).
- 빌드: `flutter build ios --simulator --debug --no-pub`, `flutter build apk --debug --no-pub` 성공(아래 실행에 쓴 빌드).
  Release·AAB·서명 빌드는 하지 않았다.

- Android 11 이하 시작 로고 추가(첫 실행 뒤 별도 커밋): 바뀐 것은 Android 리소스 PNG 하나와 이를 그리는 XML 두 파일뿐이고,
  이를 검사하는 Dart 테스트가 없어 전체 검사는 다시 돌리지 않았다. 대신 `(cd frontend && flutter analyze --no-pub)` 문제 없음,
  `(cd frontend && flutter build apk --debug --no-pub)` 성공(APK에 619px `splash_a01_logo.png` 포함, XML 리소스 컴파일 확인),
  측정 스크립트로 글자 중심 −0.12px을 확인했다.

## 시뮬레이터·에뮬레이터 실행 (2026-11-02)

- 환경: iPhone 16 / iOS 18.6 Simulator(밝은 모드, 글자 크기 기본), Android Emulator `Medium_Phone` / Android 16 / 1080×2400, 글자 배율 1.0.
  한 번에 하나만 띄웠고 서버·로그인은 쓰지 않았다(빈 세션이라 스플래시 뒤 로그인 화면).
- 변경 전은 `a06a48b`, 변경 후는 `c57c37d`의 debug 빌드를 같은 기기에 덮어 설치했다.
- 홈 화면: iOS는 [#172](2026-11-01-app-icon.md#시뮬레이터에뮬레이터-실행-2026-11-01)처럼 `frontend/ios/ShareVerification`을 저장소 밖에 복사해
  테스트 파일만 바꾼 임시 XCUITest로 홈 화면 2쪽으로 넘긴 뒤 `simctl io screenshot`으로 찍었다. Android는 홈 키 뒤 `screencap`.
- 콜드 스타트: 앱을 종료한 뒤 녹화를 켜고 실행했다. iOS는 앱 데이터의 `Library/SplashBoard`(시작 화면 캐시)를 매번 저장소 밖으로 옮긴 뒤
  `simctl launch`, Android는 `screenrecord` 중 홈 화면 아이콘을 탭했다. 두 플랫폼 모두 OS 시작 화면 → Flutter 스플래시 → 로그인이 녹화됐다.
- 결과(눈으로 확인): 변경 후 홈 아이콘과 시작 화면의 글자가 가운데에 있고, 반짝임은 오른쪽으로 튀어나온다. iOS는 둥근 사각형,
  Android는 원형 마스크 안에 글자가 잘리지 않는다.
- 영상 측정: `video_logo_track.py`로 모든 프레임에서 글자 가로 중심 − 화면 가운데(영상 px)를 쟀다. 시작 확대 애니메이션 중 프레임은 뺐다.

| 플랫폼 | 구간 | 변경 전 | 변경 후 |
| --- | --- | --- | --- |
| iOS(1178px 폭, 3배율) | OS 시작 화면부터 Flutter 스플래시 끝까지 | −6.5 ~ −7.0px(약 −2.3pt) | +0.9 ~ +1.5px(약 +0.4pt) |
| Android(1080px 폭) | OS 시작 화면 | −7.6px | +0.45px |
| Android | Flutter 스플래시 | −5.0px | +1.2px |

- 전환 판정: iOS는 OS 시작 화면과 Flutter 스플래시가 같은 그림이라 프레임만으로 경계를 가를 수 없다. 스플래시 900ms와 로그인 시작 시각으로 구간을 나눴고,
  전체 구간의 흔들림은 영상 압축을 포함해 0.7px 안이라 옆으로 움직이지 않는다.
  Android는 변경 전 전환에서 2.6px(약 1pt) 움직였고, 변경 후 0.8px(약 0.3pt)가 남는다. 남은 차이는 A01 그룹의 +0.5pt 가로 배치다
  ([판단과 남은 차이](#판단과-남은-차이)). Android에서 로고가 위로 조금 움직이는 것은 A01의 세로 배치(소개 문구 포함 그룹이 안전 영역 가운데보다 23.5 위) 때문이며 변경 전과 같다.
- 비교 자료는 저장소 밖 `.utmp/ticket-180-screens/`에 두었다(새 checkout에는 없다).
  `compare-ios.png`, `compare-android.png`(행: 홈 아이콘·OS 시작 화면·Flutter 스플래시, 열: 변경 전·변경 후·Figma),
  `transition-ios.mp4`, `transition-android.mp4`(변경 전·후 시작 영상의 로고 부분을 나란히, 빨간 선은 화면 가운데),
  원본 `before/`, `after/`의 `*-home.png`, `*-coldstart.mp4`, 프레임 측정 `*-track.txt`.
- Figma 열은 앱 아이콘 `189:4042`, 시작 화면 A01 `111:3380` 렌더(2026-11-02 조회)다. A01은 375×812 프레임이라 화면 크기·안전 영역이 기기와 다르며 보정하지 않았다.

## 미검증 범위

- 실기기, 스토어 표시, iPad, 다크·틴트 아이콘 모드, 다른 Android 런처는 확인하지 않았다.
- Android 11 이하 시작 화면: 에뮬레이터가 없어 화면에서 확인하지 않았다. 이미지 측정과 빌드만 확인했다.
  위 영상은 이 변경 전 빌드(`c57c37d`)이며, Android 16에서는 OS 시작 화면이 쓰이므로 이 이미지의 화면 확인으로 쓰지 않는다.
