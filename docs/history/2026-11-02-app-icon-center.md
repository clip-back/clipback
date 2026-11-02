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
- Android 12 미만 시작 화면 `res/drawable-nodpi/splash_a01_logo.png`는 이슈 범위가 아니라 바꾸지 않았다(글자 중심이 596px 캔버스에서 −11.62px).

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

- 나머지 iOS 아이콘 14개와 Android 아이콘 8개도 변경 후 모두 ±1px 안이다(가장 큰 값은 20px 아이콘의 −0.74).
- Figma `189:4042` 렌더도 같은 방법으로 −0.06이다.
- Flutter 렌더 확인: 임시 위젯 테스트(커밋하지 않음)로 `SvgPicture`를 154.348×50, 4배율로 그려 측정하니 −0.32px(−0.08pt)이고 반짝임이 잘리지 않았다.
- 형식: 바뀐 PNG 29개 모두 크기·모드가 시작 커밋과 같다. iOS 아이콘은 알파 없는 RGB, Android 아이콘과 시작 이미지는 RGBA다.
- 안전 반경: 적응형 아이콘의 글자·반짝임 중 가장 먼 픽셀은 26.85dp(안전 반경 33dp 안).
  Android 12 이상 시작 아이콘은 79.30dp(아이콘 원 반경 96dp 안).

## 판단과 남은 차이

- 화면 가운데 기준: iOS LaunchScreen과 Flutter 스플래시는 A01대로 그룹을 화면 가운데보다 0.5pt 오른쪽에 둔다.
  소개 문구 위치를 바꾸지 않기 위해 그대로 두었으므로 iOS와 Flutter에서 글자는 화면 가운데보다 0.5pt 오른쪽이다.
  Android 12 이상 OS 시작 아이콘은 OS가 화면 가운데에 둔다.
- iOS 3배율 간 정수 이동이라 1x·2x는 3pt, 3x는 2.67pt를 옮겼다. 각 파일의 차이는 1px 안이다.
