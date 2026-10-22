# 붙여넣기 입력행 확대

- 최초 기록일: 2026-10-15
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-cc7450bd0e958c64"></a>

### 붙여넣기 입력행의 확대 글자 높이 (`b0d0c71` 기준, 해당 범위 적용·검증 완료)

<a id="b-c5fcb486970ecfad"></a>

사용자는 **글자를 줄이지 않고 필요한 높이를 늘리며 URL 입력박스도 붙여넣기 버튼과 같은 높이로 확장**하는 기준을 확정했습니다.
두 영역의 기본·최소 높이는 44px이고 확대 시 실제 글자 레이아웃에 맞춰 같은 높이로 늘어납니다.
붙여넣기는 폭 64px·기존 14px/Medium·자간 −0.35px·최대 두 줄과 세로 중앙 배치를 유지하며,
URL은 한 줄 입력·기존 글자 크기·18px 지우기 아이콘·8px 간격을 유지합니다.
`IntrinsicHeight`와 공통 최소 44px로 입력행을 맞추고 suffix 영역 안에서 지우기 아이콘을 중앙에 둡니다. 지우기 아이콘의 기존 실제 탭 영역 48×44px을 보존해 기본 URL viewport 폭과 아이콘의 가로 위치를 유지합니다.
붙여넣기 글자 위아래에는 각각 1px의 경계 여유를 적용합니다. 기본 높이 44px은 유지하고 확대 시 자연 높이에 총 2px을 더해 실제 줄 경계가 버튼 밖으로 나가지 않게 합니다.
배율별 높이 상수·수동 글자 높이 계산·글자 축소·글꼴 줄 높이 재정의는 추가하지 않습니다.

<a id="b-70c1faddda675429"></a>

이번 범위는 확대 입력행의 표시이며 기존 하단 `32 + max(viewInsets.bottom, viewPadding.bottom)`·56px 저장 버튼,
실제 제출 입력·완료 탭 고정·실패/수동 재시도·공개 생성자/콜백/API/모델은 바꾸지 않습니다.
사진 비율·잘림·카테고리 편집·저장 화면 전체 맞춤은 후속으로 남깁니다.
이번 작업의 Figma D01 `912:16502` 컨텍스트 재조회는 **2026-10-15 20:21:07 KST(11:21:07 UTC)**, 원본 스크린샷 재조회는 같은 분에 시도했으나 둘 다 Starter 호출 한도로 실패했습니다.
기존 D01 원본도 없으므로 비교의 Figma 칸은 누락 사유를 표시합니다. 사용자 확정 확대 기준을 Figma에 새로 존재하는 디자인으로 표시하지 않습니다.

<a id="b-2f4a0fc9504adf10"></a>

```bash
# frontend/ — 확대 입력행과 붙여넣기 동작 회귀입니다.
flutter test --no-pub test/save_paste_layout_test.dart
flutter test --no-pub
flutter analyze --no-pub

# 모바일 Simulator/Emulator에서 같은 프리뷰를 before/after로 실행합니다.
flutter run --no-pub -d <device-id> -t test/support/save_result_preview.dart \
  --dart-define=SAVE_RESULT_PHASE=before
# Android: adb -s "$EMULATOR_ID" forward tcp:8768 tcp:8767
# iOS 주소이며 Android 호스트 요청은 8768 포트를 사용합니다.
curl 'http://127.0.0.1:8767/paste-scene?scale=1.5&keyboard=0'
curl 'http://127.0.0.1:8767/paste-scene?scale=2&keyboard=1'
curl http://127.0.0.1:8767/paste-run
```

<a id="b-8fdf00edc6c8db17"></a>

`/paste-scene`은 배율 `1|1.5|2`와 키보드 `0|1`의 여섯 장면을 제공합니다.
`paste_scale_1_5_keyboard_1.png`처럼 이름을 구분하고 같은 URL·커서 끝 위치·본문 스크롤 0으로 맞춥니다.
프리뷰는 iOS/Android 앱의 `Clipboard.setData`로 고정 URL을 넣고 실제 붙여넣기 버튼을 Flutter 합성 포인터로 누릅니다.
Mac 클립보드 API를 사용하지 않으며 `/paste-run`은 붙여넣기·직접 입력·지우기·유효/무효 검증·키보드·드래그·실패/재시도·완료 탭 고정·닫기를 검사합니다.
기존 `/run`과 다섯 저장 장면은 유지합니다. 실제 서버·인증·저장은 사용하지 않습니다.

<a id="b-96712402acee5443"></a>

제품 수정 전 동결한 프리뷰 SHA256은 `93390e39a9ffb71613cbc9a3c3df1dc2c33eebd7638af925f3d7390a935af4de`입니다.
보고서의 `geometry`는 입력행·URL 박스·EditableText·지우기 버튼/아이콘·붙여넣기 버튼/문단을 기록합니다.
`pasteMetrics`의 실제 `RenderParagraph` 줄 경계·전체 문구·폰트·배율·줄 수·문단/입력/아이콘 중앙 정렬과
`pasteLayoutFindings`·`pasteLayoutPassed`를 하단 판정에 합산합니다. BEFORE는 새 기준의 실패를 기록하고 기존 동작을 계속 검사하며 AFTER는 엄격 판정합니다.
기존 실제 저장 창 위젯 검사 22개는 FontLoader에 Pretendard를 로드했어도 버튼의 상속 스타일 `fontFamily: null`로 테스트 기본 글꼴을 사용했습니다. 이 검사를 실제 Pretendard 렌더링 증거로 보고하지 않습니다.
추가 13개는 모두 Pretendard family를 명시한 분리 모델입니다. 12개는 제품 버튼 스타일·자식에서 family만 바꾼 폭/배율/플랫폼 조합이며, 1개는 상속 행간 1.18·안쪽 여백 없음·기존 고정 44px을 대조합니다. 실제 저장 창·네이티브 상속 글꼴·분리 Pretendard 모델의 결과를 구분합니다.
네이티브 프리뷰는 `fontFamily: null` 기록을 그대로 유지하며 제품의 글꼴 설정을 바꾸지 않습니다. 기존 14px/Medium·자간·실제 배율과 줄 경계를 계속 검사합니다.
최초 네이티브 시도의 `fontFamily` 강제 판정 오탐은 별도 보존하고, 해당 판정만 교정한 위 동결 소스로 모든 구성의 변경 전 화면을 새로 촬영했습니다.
`before-gate.json`은 제품 원본·동결 SHA와 18개 변경 전 OS 원본 확보를 확인합니다. BEFORE 보고서는 iOS 24개·Android 제스처 30개(재촬영 6개 포함)·3버튼 24개 기록이며, 모두 프레임워크 오류 0건·동작 통과·`layoutPassed`/전체 `passed: false`입니다.

<a id="b-ff4a3056803223be"></a>

집중 회귀 **35개**·[관련 10개 파일의 330개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/tests/related-green-final.log)(14초)·[전체 Flutter 테스트 872개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/tests/full-test.log)(50초)를 통과했습니다. [정적 분석](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/tests/analyze.log)은 **문제 없음**(3.6초)이며 Dart 세 파일 포맷 검사도 **0개 변경**으로 통과했습니다. 중간 네이티브 AFTER의 공통 높이 60px에서는 상속 글꼴의 실제 줄 경계가 버튼 위로 약 0.408px 벗어나 엄격 검사에 실패했습니다. 글꼴 높이 동작을 바꾸는 시도는 제거하고 위아래 1px 여유를 적용했으며, Android 배율 1.5 단독 재검사에서 공통 높이 62px·모든 줄 경계 포함을 확인했습니다. 허용 오차를 넓히지 않았습니다.
중간 AFTER는 지우기 탭 영역을 34px로 줄여 기본 URL viewport가 14px 넓어지고 지우기 아이콘이 7px 이동한 문제가 추가로 확인됐습니다. 기존 실효 48×44px 탭 영역으로 복원하고 모든 구성의 AFTER를 새로 촬영했습니다. 이전 Android 3버튼 AFTER는 레이아웃 플래그가 통과했어도 가로 배치 보존을 충족하지 못해 `.attempts/after-clear-hit-width`에 별도 보존하며 최종 증거로 쓰지 않습니다.
지우기 탭 영역을 복원한 최종 AFTER는 iOS·Android 제스처·3버튼 각각 **24개 기록·프레임워크 오류 0건**이며,
`checksCompleted`·`behaviorPassed`·`layoutPassed`·전체 `passed`가 모두 `true`입니다.

<a id="b-3d74ff746e11d67b"></a>

| 실제 실행 환경 | 배율 1/1.5/2의 공통 높이 | 키보드·실행 결과 |
| --- | --- | --- |
| iPhone 16 / iOS 18.6, 논리 393×852·DPR 3·상단/하단 59/34px | 44/52/70px | IME 336px, 24개 기록·오류 0건·네 완료 플래그 통과 |
| Android 13/API 33 제스처, 392.7×783.3·DPR 2.75·상단/하단 24/0px | 44/62/84px | IME 274.909px, 24개 기록·오류 0건·네 완료 플래그 통과 |
| 같은 Android 3버튼, 392.7×759.3·DPR 2.75·상단/하단 24/0px | 44/62/84px | IME 250.909px, 24개 기록·오류 0건·네 완료 플래그 통과 |

<a id="b-059cc59b5522f500"></a>

높이는 각 플랫폼의 상속 글꼴과 실제 TextScaler에 따른 측정값이며 배율별 고정 목표값이 아닙니다.
[18쌍 최종 비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/comparison-qa.json)는 조건 불일치 0건·BEFORE 원본 해시 불변·fixture/최종 빌드 소스 일치·폰트/초안 변경 0건·입력/지우기 가로 기하 변경 0건과 모든 실제 줄 경계 포함을 확인했습니다.
기본 배율의 채워진 URL 여섯 상태는 박스 크기/색상과 지우기 아이콘 픽셀을 보존했습니다. 붙여넣기 글자의 raster·커서 깜박임 차이는 원본 그대로 기록하며 전체 픽셀 동일로 보고하지 않습니다.
빈 URL 상태는 위젯 검사와 지우기 동작으로 확인했고 별도 네이티브 빈 상태 픽셀 쌍은 촬영하지 않았습니다.
네이티브의 최종 플랫폼 글꼴 식별자는 측정하지 않아 Pretendard 실행 증거로 보고하지 않습니다.
[Android 탐색 복원 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/android-navigation-restored.json)의 `matchesOriginal: true`로 원래 모드 2와 전체 여섯 오버레이 일치를 확인했습니다. 포워딩 8768 제거·에뮬레이터와 iOS Simulator 종료를 마쳤고 시뮬레이터/AVD 데이터는 보존했습니다.
[영상 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/media-verification.json)는 이번 BEFORE/AFTER 영상 여섯 개 모두 전체 디코딩 종료 코드 0·오류 로그 0바이트를 확인했습니다. 중간 반복의 검사·단독 재검사나 이전 `b0d0c71`의 성공은 최종 결과로 사용하지 않습니다.
증거 루트는 `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled`이며 기본 비교는 3개 기기/탐색 구성 × 3개 배율 × 키보드 2개 상태의 18쌍입니다.
[18쌍 비교 문서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/comparison-document.html)·[비교 manifest](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/comparison-manifest.json)·[전후 상태 검증](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/pair-verification.json)을 제공합니다.
18건 모두 변경 전/후 두 원본을 나란히 표시하며 Figma 칸에는 D01 미확보 사유를 표시합니다. 완전한 세 원본 비교는 0건이고 확대용 대체 이미지는 만들지 않았습니다.
AFTER 동작 영상: [iOS](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/ios/after/interaction.mp4), [Android 제스처](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/android-gesture/after/interaction.mp4), [Android 3버튼](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/android-threebutton/after/interaction.mp4).
사진 비율/잘림·카테고리 편집 등 보류 디자인은 유지하며 이 결과를 저장 화면 전체 디자인 맞춤이나 실제 서버·인증·운영 저장·실기기·원격 CI 성공으로 보고하지 않습니다.

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-2d08caafd63545d4"></a>

### 2026-10-15 — 붙여넣기 입력행의 확대 글자 높이 (해당 범위 적용·검증 완료)

<a id="b-2647f303d58d8157"></a>

- 기준 커밋은 `b0d0c71`이다. 사용자는 글자를 축소하지 않고 필요한 만큼 높이를 늘리고, URL 입력박스도 붙여넣기 버튼과 같은 높이로 확장하는 기준을 확정했다.
  기본·최소 44px, 붙여넣기 폭 64px·최대 두 줄·기존 14px/Medium·자간 −0.35px,
  URL 한 줄·기존 글자 크기·지우기 아이콘 18px·간격 8px과 세로 중앙 정렬을 유지한다.
  `IntrinsicHeight`와 공통 최소 44px·suffix 중앙 배치를 사용하고 지우기 아이콘의 기존 실효 탭 영역 48×44px을 보존한다. 붙여넣기 위아래 각 1px의 경계 여유를 둔다. 기본 44px은 유지하며 확대 자연 높이에 총 2px의 여유를 확보한다.
  배율별 높이 상수나 수동 글자 높이 계산·글자 축소·글꼴 줄 높이 재정의는 추가하지 않는다.
- 사진 비율/잘림·카테고리 편집·저장 화면 전체 맞춤은 후속이다. 기존 하단 회피량·저장/닫기 버튼·제출 입력·성공 탭 고정·재시도,
  공개 생성자·콜백·API·모델은 유지한다. Figma D01 `912:16502` 컨텍스트는 **20:21:07 KST / 11:21:07 UTC**, 원본 스크린샷은 같은 분에 재조회했지만 둘 다 Starter 호출 한도로 실패했다. 기존 D01 원본도 없어 Figma 비교 칸은 누락 사유를 표시한다.
- 제품 수정 전 비교 프리뷰를 확장하고 동결했다. SHA256은 `93390e39a9ffb71613cbc9a3c3df1dc2c33eebd7638af925f3d7390a935af4de`이다.
  `/paste-scene?scale=1|1.5|2&keyboard=0|1`은 여섯 장면에서 모바일 앱 `Clipboard.setData`와 실제 붙여넣기 버튼을 사용한다.
  Mac 클립보드 API는 사용하지 않는다. 같은 고정 URL·커서 끝·본문 스크롤 0을 변경 전/후에 유지한다.
  `/paste-run`은 붙여넣기·직접 입력·지우기·유효/무효 검증·키보드·스크롤·실패/재시도·완료 탭 고정·닫기를 검사하고 기존 `/run`은 유지한다.
- 실제 `RenderParagraph`의 전체 문구·줄 경계·폰트/배율·줄 수·버튼 내부 포함 여부와 URL/붙여넣기의 공통 높이·EditableText/지우기 아이콘 중앙을 기록한다.
  실제 저장 창 위젯 검사 22개는 FontLoader에 Pretendard를 로드했지만 버튼의 상속 스타일 family가 null이어서 테스트 기본 글꼴을 사용했다. 이 검사를 실제 Pretendard 렌더링 증거로 쓰지 않는다.
  추가 13개는 모두 Pretendard family를 명시한 분리 모델이다. 12개는 제품 버튼 스타일/자식의 family만 바꾼 폭/배율/플랫폼 조합이며 1개는 상속 행간 1.18·여백 없음·기존 고정 44px을 대조한다. 전체 저장 창·네이티브 상속 글꼴·Pretendard 분리 모델의 검증 범위를 구분한다. 네이티브 프리뷰는 `fontFamily: null`을 그대로 기록하며 제품 글꼴 설정을 바꾸지 않는다.
  최초 네이티브 시도의 글꼴 family 강제 판정 오탐을 별도로 보존하고 이 판정만 교정한 동결 소스로 모든 구성의 변경 전 화면을 재촬영했다. 기존 14px/Medium·자간·실제 배율과 줄 경계는 계속 검증한다.
  BEFORE는 새 정책 위반을 남기고 기존 동작을 계속 확인하며 AFTER는 엄격 판정해 `layoutPassed`·전체 `passed`에 합산한다.
- 제품 수정 전 `before-gate.json`으로 기준 제품·동결 fixture SHA와 변경 전 OS 원본 18개 확보를 확인했다. BEFORE 보고서는 iOS 24개·Android 제스처 30개(6개 재촬영 포함)·3버튼 24개 기록이며 모두 프레임워크 오류 0건·동작 통과·레이아웃/전체 판정 `false`다.
- [집중 회귀 테스트](../../frontend/test/save_paste_layout_test.dart) **35개**·[관련 10개 파일 330개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/tests/related-green-final.log)(14초)·[전체 Flutter 테스트 872개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/tests/full-test.log)(50초)가 통과했다. [분석](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/tests/analyze.log)은 **문제 없음**(3.6초)이며 Dart 세 파일 포맷 검사는 **0개 변경**으로 통과했다. 중간 네이티브 AFTER는 공통 높이 60px에서 실제 줄 경계가 위로 약 0.408px 벗어나 실패했다.
  줄 높이 동작을 바꾸는 시도는 모두 제거하고 위아래 각 1px의 여유를 적용했다. Android 배율 1.5 단독 재검사는 공통 62px·모든 줄 경계 포함으로 통과했으며 수동 글자 측정·허용 오차 완화는 하지 않았다.
  중간 네이티브 pixel 대조에서는 지우기 탭 영역을 34px로 줄여 아이콘이 7px 이동하고 URL viewport가 14px 넓어진 문제를 발견했다. 기존 실효 48×44px으로 복원해 기본 가로 배치를 보존한다.
  이전 Android 3버튼 AFTER는 레이아웃 플래그가 통과했어도 가로 보존을 충족하지 못해 `.attempts/after-clear-hit-width`에 보존하고 모든 구성의 AFTER를 새로 촬영했다.
  중간 반복·단독 재검사나 이전 `b0d0c71`의 테스트·기기 성공은 최종 결과로 사용하지 않는다. 실제 서버·인증·운영 저장·실기기·원격 CI와 구분한다.
- 지우기 영역 48×44px을 복원한 최종 AFTER는 iOS·Android 제스처·3버튼 각각 **24개 기록·프레임워크 오류 0건**이며 `checksCompleted`·`behaviorPassed`·`layoutPassed`·전체 `passed`가 모두 `true`다.

<a id="b-1188637c7a9ab93b"></a>

| 실제 기기·창·여백 | 배율 1/1.5/2의 공통 높이 | 실제 키보드 inset |
| --- | --- | --- |
| iPhone 16 / iOS 18.6, 논리 393×852·DPR 3·상단 59px/하단 34px | 44/52/70px | 336px |
| Android 13/API 33 제스처, 392.7×783.3·DPR 2.75·상단 24px/하단 0px | 44/62/84px | 274.909px |
| 같은 Android 3버튼, 392.7×759.3·DPR 2.75·상단 24px/하단 0px | 44/62/84px | 250.909px |

<a id="b-e546a252b2b33a84"></a>

- 위 높이는 실제 플랫폼 상속 글꼴·배율의 측정값으로 고정 목표값이 아니다.
  [18쌍 최종 비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/comparison-qa.json)는 조건 불일치 0건·BEFORE 해시 불변·fixture/최종 빌드 소스 일치·폰트/초안 변경 0건·입력/지우기 가로 기하 변경 0건·실제 줄 경계 포함을 확인했다.
  기본 배율의 채워진 URL 여섯 상태는 박스 크기/색상·지우기 아이콘 픽셀을 보존했다. 글자 raster/커서 깜박임 차이는 원본 그대로 기록하고 전체 픽셀 동일로 보고하지 않는다. 빈 URL은 위젯 검사·지우기 동작으로 확인했으며 별도 네이티브 빈 상태 픽셀 쌍은 촬영하지 않았다. 네이티브 플랫폼 글꼴 식별자는 미측정이며 Pretendard 실행 증거로 사용하지 않는다.
  [탐색 복원 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/android-navigation-restored.json)의 `matchesOriginal: true`로 원래 모드 2와 여섯 탐색 오버레이 일치를 확인했다. 임시 포워딩 8768을 제거하고 에뮬레이터와 iOS Simulator를 종료했으며 시뮬레이터/AVD 데이터는 보존했다.
- 새 증거 루트는 `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled`이며 기본 비교는 3개 기기/탐색 구성 × 배율 1/1.5/2 × 키보드 유무, 총 18쌍이다.
  [18쌍 비교 문서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/comparison-document.html)·[비교 manifest](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/comparison-manifest.json)·[전후 상태 검증](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/pair-verification.json)을 제공한다.
  각 비교는 변경 전/후 두 OS 원본과 D01 원본 미확보 사유를 표시한다. 누락 18건·완전한 세 원본 비교 0건이며 확대용 대체 디자인은 만들지 않았다.
- AFTER 동작 영상: [iOS](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/ios/after/interaction.mp4), [Android 제스처](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/android-gesture/after/interaction.mp4), [Android 3버튼](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/android-threebutton/after/interaction.mp4).
  [영상 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/media-verification.json)는 BEFORE/AFTER 여섯 개 모두 전체 디코딩 종료 코드 0·오류 로그 0바이트를 확인했다. 이전 작업 영상의 디코딩 결과를 이번 것으로 사용하지 않는다.
- 사진 비율/잘림·카테고리 편집 등 미정 디자인은 계속 보류한다. 이번 완료 범위는 붙여넣기/URL 입력행의 확대 표시와 대역 회귀이며 저장 화면 전체 디자인 맞춤으로 보고하지 않는다.
  화면 증거·빌드 생성물·로컬 `AGENTS.md`는 커밋에서 제외하고 푸시·PR은 수행하지 않는다.

## 원문 출처: docs/figma-ui-alignment-plan.md

<a id="b-9a4a4021d2a95ebf"></a>

### 붙여넣기 입력행 확대 글자 높이 적용·검증 (2026-10-15)

<a id="b-334c6c6028f0a4c6"></a>

- 기준은 `b0d0c71`이며 버튼 최대 두 줄·폭 64px·최소 44px, URL 입력칸과 동일 자연 높이·한 줄 URL과 지우기 아이콘 중앙 정렬은 사용자 확정 기준이다. 글자 축소·말줄임·강제 줄바꿈·배율별 높이 계산을 추가하지 않는다. 일반 배율의 기존 44px과 8px 간격, 검증 문구 앞 5px을 유지한다.
- D01 `912:16502` 컨텍스트는 2026-10-15 11:21:07 UTC(20:21:07 KST), 원본 스크린샷은 같은 분에 재조회했지만 둘 다 Starter 호출 한도에 막혔다. 기존 D01 원본도 없으므로 원본 미확보를 표시하고 다른 화면이나 대체 디자인으로 채우지 않는다.
- 제품 수정 전 실제 저장 위젯 검사는 **22개 중 16개 통과·6개 실패**로 배율 2의 실제 문자 경계 세로 잘림과 두 줄/중앙 정책 부재를 재현했다. 보강 후에도 같은 결과를 확인했다. 배율 1.5의 위젯 검사는 통과하며 네이티브 기본 테마의 잘림과 구분한다. 초기 검사에서 Pretendard를 로드했지만 버튼의 명시적 스타일이 글꼴 이름을 지정하지 않아 기본 테스트 대체 글꼴을 사용한 점을 확인했다. 실제 Pretendard를 명시한 별도 버튼 모델 검사와 전체 위젯·네이티브 검사를 구분한다.
- 프리뷰의 글꼴 이름 강제 판정 오탐은 제품 수정 전에 교정했다. 네이티브는 기존 앱 테마의 상속 `fontFamily: null`을 유지하고 14px/Medium·자간 −0.35px·실제 배율과 전후 동일성을 검사한다. 첫 iOS 시도는 별도로 보존했으며 교정한 고정 프리뷰로 변경 전 화면을 다시 확보했다. 실제 네이티브 대체 글꼴 이름을 측정한 증거로 해석하지 않는다.
- 사진 비율/잘림·카테고리 편집·저장 화면 전체 맞춤은 보류하며 실제 서버·운영 저장·인증·실기기·원격 CI는 이번 대역 검증 범위 밖이다.
- 구현은 공통 최소 44px·자연 높이 행과 한 줄 URL, 최대 두 줄 붙여넣기로 구성한다. 입력의 실제 채움 배경도 같은 높이를 사용하며 지우기 탭 영역의 기존 실효 48×44px·아이콘 18px을 보존한다.
- Android 중간 수정에서 첫 줄의 선택 측정 경계가 줄 상자보다 약 0.408px 위로 나와 엄격 경계 검사가 실패했다. 이를 픽셀 잘림으로 단정하지 않고 기존 44px의 큰 문구 잘림과 구분했다. 글꼴 높이 변경 시도는 효과가 없어 제거하고, 버튼 안쪽 상하 1px의 경계 여유를 적용했다. 기본 44px은 유지하고 확대 시 내용에 따라 자연 높이가 늘어나며 수동 글자 높이 계산이나 검사 오차 완화는 없다.
- 최종 [붙여넣기 검사](../../frontend/test/save_paste_layout_test.dart) **35개**가 통과했다. 실제 저장 창·기본 테스트 대체 글꼴 검사 22개와 제품 버튼 스타일에 Pretendard를 명시한 별도 모델 13개를 구분한다. iOS/Android 테마 × 폭 320/375px × 배율 1/1.5/2에서 높이·줄 경계·글자 크기·URL 가로 스크롤·지우기 중앙 정렬·탭 영역·검증 간격을 확인했다. 클립보드의 유효/무효 URL·앞뒤 공백·빈 값·입력/지우기·종료/성공 후 늦은 응답과 키보드 전후 컨트롤러/초안 보존도 검사했다.
- 관련 10개 파일 **330개**(14초)·전체 `flutter test --no-pub` **872개**(50초)가 통과했다. `flutter analyze --no-pub`는 **문제 없음**(3.6초), Dart 포맷 검사는 3개 파일·변경 0건이다. 이전 `b0d0c71`의 검사 결과를 이번 성공으로 사용하지 않는다.
- [기기 프리뷰](../../frontend/test/support/save_result_preview.dart)는 제품 수정 전에 고정했으며 SHA256은 `93390e39a9ffb71613cbc9a3c3df1dc2c33eebd7638af925f3d7390a935af4de`다. 세 구성 × 배율 1/1.5/2 × 키보드 표시/해제의 **18장 BEFORE 원본**을 확보한 뒤 제품을 수정했고, 같은 상태의 AFTER 18장을 새로 촬영했다. 조건 불일치 0건·BEFORE 이미지/상태 해시 불변·글자/입력/커서/가로 배치 보존을 확인했다.

<a id="b-b242b77ca805e40e"></a>

| 이번 실행 구성 | 실제 Flutter 창·DPR | 상단/하단 여백·키보드 inset | AFTER 기록·오류 | 입력행 높이 (배율 1/1.5/2) |
| --- | --- | --- | --- | --- |
| iPhone 16 / iOS 18.6 Simulator | 393×852·3 | 59/34px·336px | 24개·0건 | 44/52/70px |
| Android 13/API 33 Emulator·제스처 | 392.7×783.3·2.75 | 24/0px·274.909px | 24개·0건 | 44/62/84px |
| Android 13/API 33 Emulator·3버튼 | 392.7×759.3·2.75 | 24/0px·250.909px | 24개·0건 | 44/62/84px |

<a id="b-65edf53edf5fd42d"></a>

- 세 구성 모두 `checksCompleted`·`behaviorPassed`·`layoutPassed`·전체 `passed: true`다. 위 높이는 실제 측정값이며 배율별 고정값으로 구현하지 않았다. URL 입력 배경과 버튼의 높이가 같고 실제 문구 줄 경계가 내부에 있다. 붙여넣기·입력·지우기·검증·키보드·저장 실패/재시도·완료 탭 유지·본문 드래그·닫기를 새로 실행했다. 실제 모바일 Clipboard를 쓰되 입력 준비·사진 선택·저장 응답은 대역이며 Flutter 합성 포인터/컨트롤러 입력으로 실행한 범위를 구분한다.
- 기본 6쌍의 44px 높이·배경색·64px 버튼·18px 지우기 아이콘을 확인했다. 지우기 아이콘은 6쌍 모두 픽셀 동일하고 URL 영역 5쌍은 동일하며 1쌍은 커서의 284픽셀 차이만 있다. 붙여넣기 글자의 미세 래스터 차이는 원본 그대로 남기며 비교 이미지를 보정하지 않는다. Android OS 클립보드 미리보기는 붙여넣기 후 8초 기다려 자연스럽게 사라진 뒤 정식 원본을 촬영했다.
- Android 탐색 모드와 6개 오버레이 설정을 원래 값으로 복원했으며 `android-navigation-restored.json`의 `matchesOriginal: true`를 확인했다. 포워딩 제거·Simulator/Emulator 종료를 마쳤고 기기 데이터는 보존했다. Android 3버튼은 Flutter 창 자체가 24px 짧으며 OS 탐색 표시는 원본에 포함된다. D01 원본이 없어 Figma의 치수·안전 영역은 추정하지 않는다.
- 증거 루트는 `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled`다.
  [18쌍 비교 문서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/comparison-document.html)와
  [비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/comparison-qa.json)·[원본/입력 보존 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/pair-verification.json)를 제공한다.
  D01 원본 미확보로 18건 모두 세 번째 열은 누락 사유이며 실제 세 화면 비교가 완료된 것으로 보고하지 않는다. 확대/키보드 배치는 이번 사용자 확정 기준이다.
- [iOS 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/ios/after/interaction.mp4),
  [Android 제스처 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/android-gesture/after/interaction.mp4),
  [Android 3버튼 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/android-threebutton/after/interaction.mp4)을 제공한다.
  [영상 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/media-verification.json)는 변경 전·후 정식 영상 6개를 이번에 전체 디코딩해 종료 코드 0·오류 로그 0바이트를 확인했다. 이전 시도 영상은 완료 근거에서 제외한다.
