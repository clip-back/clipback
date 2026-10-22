# 붙여넣기 버튼 원본 스타일

- 최초 기록일: 2026-10-15
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-f4a60343963eaa17"></a>

### Figma 붙여넣기 버튼 스타일 (`52132f0` 기준, 해당 범위 적용·검증 완료)

<a id="b-2864b4b0e5868ff0"></a>

이번 범위는 링크 입력 전·유효·무효 상태에서 **붙여넣기 버튼의 흰 배경 `#FFFFFF`·회색 1px 테두리 `#D1D1D1`·회색 글자 `#767676`·모서리 4px과 명시적 Pretendard 14px/Medium·자간 −0.35px**을 적용하는 작업입니다.
기존 폭 64px·기본/최소 높이 44px·최대 두 줄·가운데 정렬과 글자 축소 없이 URL 입력칸과 같은 자연 높이를 쓰는 기준을 유지합니다.
URL의 한 줄 입력·기존 글자 크기·지우기 탭 영역 48×44px/아이콘 18px·입력과 버튼 사이 8px·검증 문구 앞 5px도 유지합니다.
새 테두리 안쪽에 실제 글자 경계가 포함되는지 검사하며 배율별 고정 높이나 수동 글자 높이 계산을 추가하지 않습니다.
공개 생성자·콜백·서버 API·모델·저장 시점·제출 입력·완료 탭 고정·실패 재시도와 하단 안전 영역은 변경 범위가 아닙니다.
사진 비율/잘림·카테고리 편집·저장 화면 전체 맞춤과 추천 API는 후속으로 남깁니다.

<a id="b-159dd5eb7af5fc21"></a>

이번에는 [D01 입력 전 `912:16502`](https://www.figma.com/design/b2lmAo9VtbL6Qi0mzX5IMu/?node-id=912-16502),
[D02 유효한 링크 `912:16682`](https://www.figma.com/design/b2lmAo9VtbL6Qi0mzX5IMu/?node-id=912-16682),
[D03 무효한 링크 `912:16712`](https://www.figma.com/design/b2lmAo9VtbL6Qi0mzX5IMu/?node-id=912-16712)의 컨텍스트를 **2026-10-15 22:05:02 KST / 13:05:02 UTC**, 원본 스크린샷을 **22:05:18 KST / 13:05:18 UTC**에 처음 확보했습니다.
구현 직전 세 노드의 컨텍스트를 **22:33:18 KST / 13:33:18 UTC**, 원본을 **22:33:41 KST / 13:33:41 UTC**에 다시 조회해 모두 성공했습니다. 현재 비교 기준 원본은 이 재조회 결과이며 375×812px·초기 PNG 해시와 동일합니다. 초기 원본·컨텍스트는 `figma/initial-1305`에 별도로 보존합니다.
[새 원본/컨텍스트 조회 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/figma/reference-manifest.json)에 노드·시각·해시를 기록했습니다. Figma 화면 전체 이미지는 제품 에셋으로 사용하지 않습니다.
위 이전 확대 작업의 Starter 호출 실패·D01 미확보와 18쌍 비교 제한은 당시 결과로 보존하며 이번 성공으로 소급 변경하지 않습니다.

<a id="b-181ec6d6edaececc"></a>

```bash
# frontend/ — 수정 전 집중 재현, 수정 후 집중·관련·전체 검사를 실행합니다.
flutter test --no-pub test/save_paste_layout_test.dart
flutter test --no-pub
flutter analyze --no-pub

# Simulator/Emulator용 고정 프리뷰: before/after는 같은 소스를 사용합니다.
flutter run --no-pub -d <device-id> -t test/support/save_result_preview.dart \
  --dart-define=SAVE_RESULT_PHASE=before
# Android 호스트 요청: adb -s "$EMULATOR_ID" forward tcp:8768 tcp:8767
# 아래 8767은 iOS 주소입니다. Android 호스트에서는 8768을 사용합니다.
curl 'http://127.0.0.1:8767/paste-scene?kind=valid&scale=1.5&keyboard=0'
curl 'http://127.0.0.1:8767/paste-scene?kind=valid&scale=2&keyboard=1'
curl 'http://127.0.0.1:8767/paste-scene?kind=empty&scale=1&keyboard=0'
curl 'http://127.0.0.1:8767/paste-scene?kind=invalid&scale=1&keyboard=0'
curl http://127.0.0.1:8767/paste-run
```

<a id="b-c9a40226e3c1268b"></a>

제품 수정 전 [프리뷰 동결 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/fixture-manifest.json)의 SHA256은 `618a868d90cdc69308fd56d33a63f9457b32995dcace219c86236e6ff7e294bf`입니다.
비교 상태는 각 기기/탐색 구성에서 유효 링크의 배율 1/1.5/2 × 키보드 유무 6개와 입력 전·무효 링크의 기본 배율/키보드 없음 2개, 총 8개입니다.
iPhone 16/iOS 18.6·Android 13/API 33 제스처/3버튼의 **24쌍**을 같은 데이터·배율·커서·스크롤로 새로 촬영해 변경 전 → 변경 후 → 해당 Figma 원본을 제공합니다.
확대/키보드 전용 Figma는 없으므로 기본 원본과 사용자 확정 기준을 구분합니다. OS 원본의 여백을 임의로 잘라 맞추지 않습니다.
증거 루트는 `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style`이며 브라우저용 주소는 `http://127.0.0.1:8773/comparison-document.html`입니다.

<a id="b-69369785be82e2f4"></a>

프리뷰의 `pasteMetrics.style`은 현재 WidgetState에 따른 ButtonStyle의 해석 결과와 실제 Material 배경·테두리·반경·RenderParagraph 글꼴/색상을 나눠 기록합니다.
`pasteLayoutFindings`와 스타일 판정을 함께 확인하며 BEFORE는 새 기준의 실패를 남기고 AFTER는 엄격 판정합니다.
모바일 앱의 `Clipboard.setData`·실제 붙여넣기 버튼과 고정 저장 콜백을 사용하며 Mac 클립보드 API나 운영 서버는 사용하지 않습니다.

<a id="b-c792b97290b0e494"></a>

현재 확인한 수정 전 [집중 재현](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/tests/paste-style-red.log)은 **40개 중 17개 통과·23개 실패**(13초)입니다.
실제 Dialog의 명시적 Pretendard 부재 13건, 새 테두리 안쪽 글자 경계 5건, 기존 노란 배경 5건으로 구분합니다.
스타일 검사는 첫 배경색에서 중단되므로 이 재현만으로 뒤에 있는 테두리·글자색·포커스/누름 검사가 모두 실행됐다고 보고하지 않습니다.
이번 실제 Dialog 검사는 RenderParagraph의 Pretendard 적용을 직접 확인하도록 보강했고 기존 분리 글꼴 모델 13개도 유지합니다.
LinkSaveBody의 공개 `onPaste`는 필수 콜백이므로 비활성 스타일은 실제 생성된 TextButton의 스타일/자식을 복제해 `onPressed: null`로 만든 직접 버튼 모델에서 검사합니다.
[초기 검사/프리뷰 파일 정적 분석](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/tests/fixture-analysis.log)은 2항목·문제 없음(2.4초)이며 전체 앱 분석 결과로 사용하지 않습니다.
[변경 전 게이트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/before-gate.json)는 제품 원본·동결 fixture와 새 OS 원본 24장의 해시를 확인한 뒤 제품을 수정하도록 통과했습니다.
BEFORE는 iOS 30개·Android 제스처 22개·3버튼 30개 기록에서 프레임워크 오류 0건이며 `checksCompleted`·`behaviorPassed`·`layoutPassed: true`, `stylePassed`·전체 `passed: false`입니다. 기존 배치는 유지됐지만 새 스타일 기준을 충족하지 못한 결과입니다.
제스처의 최초 행동 시도는 오류 토스트 부재로 중단됐습니다. 저장 호출·URL·컨트롤러는 보존됐고 토스트 만료는 추정으로만 남깁니다. 원본 8장·상태 8개의 해시를 유지한 채 새 앱 세션에서 행동을 재시도해 22개 기록으로 통과했고 [재시도 출처](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/android-gesture/before/retry-origin.json)와 `interaction-retry.mp4`를 구분합니다. 실패 시도는 `.attempts`에 보존합니다.

<a id="b-3e0843bc2353ad5a"></a>

제품의 흰 배경·회색 테두리/글자·명시적 Pretendard를 적용한 첫 [집중 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/tests/paste-style-first-green.log)는 40개 중 30개 통과·10개 실패로 새 테두리 안쪽 글자 경계 초과를 확인했습니다.
버튼의 상하 내용 여유를 1px에서 2px로 늘려 테두리 1px 안쪽에서 실제 글자 경계를 보호하며, 기본 44px과 자연 높이 기준은 유지합니다. 글자 크기나 배율별 높이를 계산하지 않습니다.
최종 [집중 검사 40개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/tests/paste-style-green.log)는 모두 통과했습니다(3초). Dart 세 파일 형식 검사는 변경 0건(0.42초)입니다.
[관련 10개 파일 335개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/tests/related-green.log)(17초)·[전체 Flutter 검사 877개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/tests/full-test.log)(49초)가 통과했고, [전체 정적 분석](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/tests/analyze.log)은 문제 없음(3.3초)입니다.
[최종 소스 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/final-implementation.json)은 제품 SHA256 `2b792fc4d1447d21f9129e32c27509a1cb213a7199b714f07b10b0c5d16aac91`와 같은 fixture·검사 소스를 구분합니다.
Android AFTER APK(14.2초)와 iOS AFTER Xcode 빌드(28.5초)는 성공했습니다. 빌드 소스와 위 제품·fixture·검사 해시를 기록하며, 빌드 성공을 기기 실행 성공으로 대신하지 않습니다.
최종 [iOS AFTER](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/ios-final-result.json)·[Android 두 탐색 방식 AFTER](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/android-final-result.json)는 각각 OS 원본 8장·30개 기록·프레임워크 오류 0건이며 `checksCompleted`·`behaviorPassed`·`layoutPassed`·`stylePassed`·전체 `passed`가 모두 `true`입니다.

<a id="b-be8af6bad05e4ffa"></a>

| 실제 실행 구성 | 논리 창·DPR | 상단/하단 여백 | 키보드 inset 표시→해제 | 입력행 높이 (배율 1/1.5/2) |
| --- | --- | --- | --- | --- |
| iPhone 16 / iOS 18.6 Simulator | 393×852·3 | 59/34px | 336→0px | 44/54/70px |
| Android 13/API 33 제스처 Emulator | 392.7×783.3·2.75 | 24/0px | 274.909→0px | 44/54/70px |
| 같은 Android 3버튼 | 392.7×759.3·2.75 | 24/0px | 250.909→0px | 44/54/70px |

<a id="b-a2cf9270182f5b27"></a>

위 높이는 실제 글꼴에 따른 자연 높이이며 배율별 목표값이 아닙니다. Android는 명시적 Pretendard를 적용하기 전 44/62/84px과 구분합니다.
[Android 탐색 복원](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/android-navigation-restored.json)은 원래 mode 2와 6개 오버레이의 `matchesOriginal: true`를 확인했습니다. [Android 종료 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/android-final-result.json)은 앱 종료·임시 포워딩 8768 제거·에뮬레이터 종료 코드 0과 `emulator-5554` 부재, AVD 데이터 보존을 구분합니다.
iOS도 앱 종료·Simulator Shutdown을 확인하고 기기 데이터를 보존했습니다. 자동 검사·세 구성의 기기 실행·24쌍 비교·동작 영상 QA를 완료했습니다.
[영구 증거 복사 검증](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/evidence-copy-verification.json)은 작업 임시 경로의 자료 270개·102,133,667바이트를 위 증거 루트로 복사하고 모든 파일 해시가 일치함을 확인했습니다. 원본을 보정하거나 이전 작업 자료로 대체하지 않았습니다.
[24쌍 비교 문서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/comparison-document.html)는 모두 변경 전 → 변경 후 → 해당 Figma 원본의 3열입니다.
[비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/comparison-qa.json)·[전후 상태 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/pair-verification.json)는 Figma 누락 0건·조건 불일치 0건·BEFORE 이미지 24장/상태 24개 해시 불변·fixture/최종 빌드 소스 일치와 실제 문자 경계의 테두리 안쪽 포함을 확인했습니다.
의도한 색상·테두리·글꼴 변경 외 초안/커서·URL/지우기의 가로 기하는 유지했습니다. 기본 44px과 입력/버튼의 동일 자연 높이도 확인했고, 기본 배율 12쌍의 원본 픽셀 대조에서 의도한 버튼 외형 변경과 커서/선택 차이를 구분해 보정 없이 기록했습니다.
실제 Dialog·네이티브 RenderParagraph의 효과적 `fontFamily: Pretendard`를 확인했으며 플랫폼의 최종 글꼴 파일 식별자를 별도로 추출한 것은 아닙니다. 확대/키보드 비교에는 해당 기본 Figma 원본과 사용자 확정 기준을 함께 표시합니다.
AFTER 동작 영상: [iOS](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/ios/after/interaction.mp4), [Android 제스처](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/android-gesture/after/interaction.mp4), [Android 3버튼](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/android-threebutton/after/interaction.mp4).
[영상 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/media-verification.json)는 이번 BEFORE/AFTER 영상 6개 모두 전체 디코딩 종료 코드 0·오류 로그 0바이트와 `allComplete: true`를 확인했습니다. 제스처 BEFORE는 성공한 `interaction-retry.mp4`를 사용하고 최초 실패 영상은 완료 근거에 포함하지 않습니다.
이전 `52132f0`의 872개 전체 검사와 기기 성공은 이번 검증으로 사용하지 않으며 실제 서버·인증·운영 저장·실기기·원격 CI는 별도입니다.

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-e9eac4d2edb7f983"></a>

### 2026-10-15 — Figma 붙여넣기 버튼 스타일 (해당 범위 적용·검증 완료)

<a id="b-3a0acf7dd00e7d0d"></a>

- 기준 커밋은 `52132f0`이다. 이번 범위는 붙여넣기 버튼의 배경 `#FFFFFF`, 1px 실선 테두리 `#D1D1D1`, 글자 `#767676`, 반경 4px과 명시적 Pretendard 14px/Medium·자간 −0.35px을 최신 D01/D02/D03에 맞추는 작업이다.
  기존 폭 64px·기본/최소 44px·최대 두 줄·가운데 정렬·글자 축소 없는 공통 자연 높이와 URL 한 줄 입력·지우기 48×44px/아이콘 18px·간격 8px·검증 앞 5px을 유지한다.
  실제 문자가 새 테두리 안쪽 경계에 들어오는지 확인하고 배율별 높이 상수·수동 글자 높이 계산을 추가하지 않는다.
  공개 생성자·콜백·서버 API·데이터 모델·저장 시점·제출 입력·성공 탭 고정·재시도·하단 안전 영역은 유지하며 사진 비율/잘림·카테고리 편집·저장 화면 전체 맞춤·추천 API는 후속이다.
- 이번 [Figma 조회 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/figma/reference-manifest.json)은 D01 입력 전 `912:16502`·D02 유효 링크 `912:16682`·D03 무효 링크 `912:16712`의 초기 컨텍스트 **22:05:02 KST / 13:05:02 UTC**, 원본 **22:05:18 KST / 13:05:18 UTC** 확보와 구현 직전 재조회를 구분한다.
  현재 비교 기준은 구현 직전 컨텍스트 **22:33:18 KST / 13:33:18 UTC**·원본 **22:33:41 KST / 13:33:41 UTC**의 세 노드 조회 성공 결과다. 재조회 원본은 375×812px이며 초기 PNG와 바이트 해시가 같고, 초기 원본/컨텍스트는 `figma/initial-1305`에 별도 보존한다.
  이전 확대 작업의 Starter 한도 실패·D01 원본 누락·18건의 비교 제한은 당시 기록으로 그대로 보존한다. 이번 성공을 과거 작업의 원본 확보나 완전한 세 화면 비교 성공으로 소급하지 않는다.
- 제품 수정 전 [고정 프리뷰 manifest](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/fixture-manifest.json)를 만들었다. fixture SHA256은 `618a868d90cdc69308fd56d33a63f9457b32995dcace219c86236e6ff7e294bf`이며 변경 전·후에 같은 소스를 사용한다.
  `/paste-scene?kind=valid&scale=1|1.5|2&keyboard=0|1`의 6개 상태와 `kind=empty|invalid&scale=1&keyboard=0`의 두 기본 상태를 제공한다. `/paste-run`은 기존 붙여넣기·입력·지우기·검증·키보드·실패/재시도·완료 탭·스크롤·닫기를 검사한다.
  모바일 Clipboard와 실제 버튼·Flutter 합성 입력·메모리 저장 대역을 사용하며 Mac 클립보드 API·운영 서버·인증·실기기·원격 CI 검증과 구분한다.
- [수정 전 집중 재현](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/tests/paste-style-red.log)은 **40개 중 17개 통과·23개 실패**(13초)다. 실제 Dialog의 Pretendard 부재 13건, 새 1px 테두리 안쪽 글자 경계 초과 5건, 기존 노란 배경과 흰 배경 기준 차이 5건으로 분류한다.
  컴파일/타입/비동기 등 검사 자체 오류는 없지만 스타일 5건은 첫 배경색 비교에서 멈춰 이후 테두리·글자색·포커스/누름 상태 검사가 실행된 증거로 사용하지 않는다.
  실제 Dialog RenderParagraph의 명시적 Pretendard를 검사하도록 기존 회귀를 보강하고 분리 글꼴 모델 13개는 유지했다. 공개 `onPaste`는 필수 콜백이므로 비활성 모양은 실제 TextButton의 스타일/자식을 복제하고 `onPressed: null`로 만든 직접 모델에서 검사한다.
  [초기 검사/프리뷰 정적 분석](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/tests/fixture-analysis.log)은 2항목·문제 없음(2.4초)이며 전체 앱 분석 완료로 보고하지 않는다.
- 변경 전 원본은 iPhone 16/iOS 18.6·Android 13/API 33 제스처/3버튼에서 각각 8장, 총 24장을 새로 확보하고 [변경 전 게이트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/before-gate.json)에서 제품 원본·동결 fixture·24개 OS 원본 해시를 확인한 뒤 제품을 수정했다. 유효 링크 배율 1/1.5/2 × 키보드 유무 6개와 기본 입력 전/무효 두 상태의 데이터를 고정했다.
  BEFORE는 iOS 30개·Android 제스처 22개·3버튼 30개 기록에서 프레임워크 오류 0건이고 `checksCompleted`·`behaviorPassed`·`layoutPassed: true`, `stylePassed`·전체 `passed: false`다. 기존 기하 통과와 새 스타일 실패를 구분한다.
  제스처 최초 행동 검사는 오류 토스트 부재로 중단됐으나 저장 호출 1회·URL·컨트롤러는 유지됐고 프레임워크 오류도 없었다. 토스트 만료는 추정이며 확정하지 않는다. 최초 실패를 `.attempts`에 보존하고 원본 8장·상태 8개 해시를 유지한 채 fresh 앱 세션에서 행동을 재시도했다. [재시도 출처](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/android-gesture/before/retry-origin.json)는 13:26:21~13:28:56 UTC·154.6초·22개 기록과 `interaction-retry.mp4`를 구분한다.
  같은 조건으로 AFTER를 촬영해 **24쌍**을 변경 전 → 변경 후 → D01/D02/D03 순서로 제공하고 동작 영상을 첨부한다. 확대/키보드는 기본 Figma와 사용자 확정 기준을 구분하며 전체 화면 원본을 구현 에셋이나 대체 디자인으로 사용하지 않는다.
  증거 루트는 `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style`, 브라우저용 주소는 `http://127.0.0.1:8773/comparison-document.html`이다. 프리뷰 재현 명령은 [프론트 README](../../frontend/README.md)의 이번 스타일 절에 기록했다.
- 첫 스타일 적용 후 [집중 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/tests/paste-style-first-green.log)는 40개 중 30개 통과·10개 실패로 새 1px 테두리 안쪽 경계 초과를 확인했다. 상하 내용 여유를 1px에서 2px로 늘려 테두리 안의 실제 글자를 보호하고 기본 44px·자연 높이·수동 글자 계산 없음 기준을 유지했다.
  최종 [집중 40개 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/tests/paste-style-green.log)는 모두 통과했다(3초). Dart 세 파일 형식 검사는 변경 0건(0.42초)이다. [최종 소스 manifest](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/final-implementation.json)는 제품 SHA256 `2b792fc4d1447d21f9129e32c27509a1cb213a7199b714f07b10b0c5d16aac91`·동결 fixture·검사 소스를 기록한다.
  [관련 10개 파일 335개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/tests/related-green.log)(17초)·[전체 Flutter 검사 877개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/tests/full-test.log)(49초)가 통과했고 [전체 분석](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/tests/analyze.log)은 문제 없음(3.3초)이다.
  Android AFTER APK(14.2초)와 iOS AFTER Xcode 빌드(28.5초)는 성공했고 제품·fixture·검사 소스 해시를 기록했다. 빌드 성공을 실행 성공으로 대신하지 않는다. 이전 `52132f0`의 전체 872개 테스트나 기기 성공을 이번 결과로 사용하지 않는다.
- 최종 [iOS AFTER](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/ios-final-result.json)·[Android 제스처/3버튼 AFTER](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/android-final-result.json)는 각각 OS 원본 8장·30개 기록·프레임워크 오류 0건이고 `checksCompleted`·`behaviorPassed`·`layoutPassed`·`stylePassed`·전체 `passed`가 모두 `true`다.
  세 구성의 입력행 높이는 배율 1/1.5/2에서 44/54/70px이며 Android의 명시적 Pretendard 적용 전 44/62/84px과 구분한다. 실제 글꼴에 따른 자연 높이로 고정 배율값을 구현한 것이 아니다.
  실제 창은 iOS 393×852·DPR 3·상하 여백 59/34px·IME 336→0px, Android 제스처 392.7×783.3·DPR 2.75·24/0px·IME 274.909→0px, 3버튼 392.7×759.3·DPR 2.75·24/0px·IME 250.909→0px다.
  [Android 탐색 복원](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/android-navigation-restored.json)에서 원래 mode 2·6개 오버레이의 `matchesOriginal: true`를 확인했다. [종료 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/android-final-result.json)은 앱 종료·포워딩 8768 제거·에뮬레이터 종료 코드 0·`emulator-5554` 부재와 AVD 데이터 보존을 기록한다.
  iOS도 앱 종료·Simulator Shutdown과 기기 데이터 보존을 확인했다. 자동 검사·세 구성의 기기 실행·24쌍 최종 비교·동작 영상 QA를 완료했다.
  [영구 증거 복사 검증](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/evidence-copy-verification.json)은 임시 작업 경로의 자료 270개·102,133,667바이트를 위 영구 루트에 모든 파일 해시 일치로 복사했음을 확인한다. 임시 원본·실패 시도와 정식 성공 기록의 출처를 유지한다.
- [24쌍 비교 문서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/comparison-document.html)는 모든 상태에서 변경 전 → 변경 후 → 실제 Figma 원본 3열을 제공한다.
  [최종 비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/comparison-qa.json)·[전후 상태 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/pair-verification.json)는 Figma 누락 0건·조건 불일치 0건·BEFORE 24개 이미지/24개 상태 해시 불변·동결 fixture/최종 빌드 소스 일치·실제 문자 경계의 테두리 안쪽 포함을 확인했다.
  의도한 색상/테두리/글꼴 변경 외 초안·커서·URL/지우기 가로 기하와 기본 44px·공통 자연 높이를 유지했다. 기본 배율 12쌍의 픽셀 대조는 의도한 버튼 외형과 원본 커서/선택 차이를 구분하며 원본을 보정하지 않는다. 확대/키보드 전용 디자인을 만들지 않고 기본 Figma와 사용자 확정 기준을 표시했다.
  실제 Dialog·네이티브 RenderParagraph의 효과적 `fontFamily: Pretendard`를 확인했지만 플랫폼의 실제 글꼴 파일 식별자를 따로 추출한 증거로 확대하지 않는다.
- AFTER 영상: [iOS](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/ios/after/interaction.mp4), [Android 제스처](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/android-gesture/after/interaction.mp4), [Android 3버튼](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/android-threebutton/after/interaction.mp4).
  [영상 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/media-verification.json)는 이번 BEFORE/AFTER 6개 영상 모두 전체 디코딩 종료 코드 0·오류 로그 0바이트·`allComplete: true`를 확인했다. 제스처 BEFORE는 성공한 `interaction-retry.mp4`이며 실패 시도 영상은 완료 근거에서 제외했다.
  이번 완료 범위는 붙여넣기 버튼 스타일과 기존 대역 회귀다. 사진 비율/잘림·카테고리 편집·저장 화면 전체 맞춤·추천 API는 후속이며 실제 서버·인증·운영 저장·실기기·원격 CI는 이번에 검증하지 않았다.
  최종 diff·문서 링크·공백을 확인한 뒤 `fix: 피그마 기준으로 붙여넣기 버튼 스타일 맞춤` 한 커밋으로 저장한다. 화면 증거·빌드 생성물·`AGENTS.md`는 제외하며 푸시·PR은 하지 않는다.

## 원문 출처: docs/figma-ui-alignment-plan.md

<a id="b-0b6597747404be24"></a>

### 붙여넣기 버튼 Figma 스타일과 Pretendard (2026-10-15, 적용·검증 완료)

<a id="b-b4953e93a27740b1"></a>

- 기준 커밋은 `52132f0`이다. 이번 범위는 `LinkSaveBody`의 붙여넣기 버튼 색상·테두리·글꼴이다. 흰 배경 `AppColors.surface`(#FFFFFF), 1px `AppColors.subtler`(#D1D1D1) 테두리, `AppColors.subtle`(#767676) 문구와 Pretendard 14px/Medium·자간 −0.35px을 적용한다. 입력 전·유효·무효에서 같은 기본 외형을 사용하며 기존 Material 눌림·포커스 동작을 유지한다.
- 사용자 확정 기준인 폭 64px·모서리 4px·기본/최소 높이 44px·간격 8px, 최대 두 줄·가운데 정렬·글자 축소 없음과 URL 입력칸의 같은 자연 높이를 유지한다. URL 한 줄/가로 스크롤·기존 입력 글꼴·지우기 48×44px/아이콘 18px·검증 앞 5px, 하단 배치와 저장/재시도/제출 입력/완료 탭 정책은 이번 변경 대상이 아니다. 사진 비율·잘림·카테고리 편집·API·다른 화면 글꼴은 후속으로 남긴다.
- 최신 `261008`의 D01 입력 전 `912:16502`, D02 유효 `912:16682`, D03 무효 `912:16712`를 Education 연결로 재조회했다. 세 컨텍스트는 **2026-10-15 13:05:02 UTC(22:05:02 KST)**, 각 375×812px 원본은 **13:05:18 UTC(22:05:18 KST)**에 확보했다. 구현 직전 컨텍스트는 **13:33:18 UTC(22:33:18 KST)**, 원본은 **13:33:41 UTC(22:33:41 KST)**에 다시 조회했고 세 PNG는 최초 원본과 SHA256이 같다. 세 노드 모두 같은 버튼 배경·선·글꼴을 확인했다. 이전 Starter 제한과 당시 D01 누락 기록을 소급해 성공으로 바꾸지 않는다.
- 제품 수정 전 실제 저장 창 검사 40개 중 17개 통과·23개 실패(13초)로 새 기준 차이를 재현했다. 실제 버튼의 Pretendard 미지정 13개, 새 테두리 안쪽 글자 경계 5개, 기존 노란 배경 5개다. 각 스타일 검사는 앞선 실패에서 중단되므로 이 결과를 모든 색상·선·포커스 동작의 개별 재현 성공으로 확대하지 않는다. 프리뷰/검사 두 파일 정적 분석은 문제 없음(2.4초)이다.
- 촬영 프리뷰의 동결 SHA256은 `618a868d90cdc69308fd56d33a63f9457b32995dcace219c86236e6ff7e294bf`다. 유효 입력의 배율 1/1.5/2 × 키보드 표시/해제 여섯 장면과 입력 전·무효의 일반 배율/키보드 해제 두 장면을 사용한다. 플랫폼/탐색 세 구성의 총 24쌍이며 각각 D02·D01·D03 원본에 대응한다. 스타일 불일치를 `stylePassed`로 분리해 기존 기하의 `layoutPassed`와 구분하고 전체 `passed`에는 함께 합산한다.
- 제품 수정 전에 새 OS 원본 24장·상태 24개를 확보한 뒤 `before-gate.json`으로 제품 원본과 fixture·원본 해시를 확인했다. BEFORE는 iOS 30개·Android 제스처 22개·3버튼 30개 기록이며 프레임워크 오류 0건, `checksCompleted`·`behaviorPassed`·`layoutPassed: true`, `stylePassed`·전체 `passed: false`다. 제스처 최초 행동 시도는 오류 토스트 부재로 중단됐고 호출 1회·URL·컨트롤러는 보존됐다. 토스트 만료는 추정으로 구분한다. 실패를 `.attempts`에 보존하고 원본 8장·상태 8개의 해시를 유지한 채 새 앱 세션에서 행동만 재시도해 22개 기록을 확보했다. 정식 영상은 `interaction-retry.mp4`이며 원본 촬영과 같은 세션이라고 보고하지 않는다.
- 첫 스타일 적용 뒤 집중 검사는 40개 중 30개 통과·10개 실패로 테두리 안쪽 문자 경계 초과를 확인했다. 상하 내용 여유를 1px에서 2px로 늘려 해결했으며 기본 44px·자연 높이와 수동 글자 높이 계산 없음 기준을 유지했다. 최종 집중 **40개**(3초)·관련 10개 파일 **335개**(17초)·전체 `flutter test --no-pub` **877개**(49초)가 통과했고 `flutter analyze --no-pub`는 **문제 없음**(3.3초)이다. Dart 세 파일 포맷 검사는 변경 0건(0.42초)이다.
- 최종 제품 소스 SHA256은 `2b792fc4d1447d21f9129e32c27509a1cb213a7199b714f07b10b0c5d16aac91`이다. Android AFTER 빌드 14.2초·iOS Simulator AFTER Xcode 빌드 28.5초의 성공과 빌드 소스 해시를 기록했다. 빌드 성공을 기기 실행 성공으로 대신하지 않는다.
- [이번 변경 전 게이트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/before-gate.json)·[최종 소스](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/final-implementation.json)·[Figma 조회 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/figma/reference-manifest.json)을 보존한다. BEFORE의 기하 통과와 스타일 실패를 분리하고, AFTER는 두 판정을 모두 요구했다. 기기 프리뷰의 글자 경계 검사에 더해 최종 비교 QA에서 실제 1px 테두리 안쪽에 모든 문자 경계가 있는지도 확인했다.

<a id="b-f984c2cbb8a6f88c"></a>

| 이번 AFTER 실행 구성 | 실제 Flutter 창·DPR | 상단/하단 여백·키보드 inset | 기록·프레임워크 오류 | 입력행 높이 (배율 1/1.5/2) |
| --- | --- | --- | --- | --- |
| iPhone 16 / iOS 18.6 Simulator | 393×852·3 | 59/34px·336→0px | 30개·0건 | 44/54/70px |
| Android 13/API 33 Emulator·제스처 | 392.7×783.3·2.75 | 24/0px·274.909→0px | 30개·0건 | 44/54/70px |
| Android 13/API 33 Emulator·3버튼 | 392.7×759.3·2.75 | 24/0px·250.909→0px | 30개·0건 | 44/54/70px |

<a id="b-4fd6a90ba0ba61b1"></a>

- 세 구성의 `checksCompleted`·`behaviorPassed`·`layoutPassed`·`stylePassed`·전체 `passed`는 모두 `true`다. 높이는 실제 측정값이며 배율별 상수로 구현하지 않았다. 명시적 Pretendard 적용 전 iOS 44/52/70px·Android 44/62/84px과 자연 높이가 달라졌으며, 기본 44px과 입력칸/버튼 높이 일치는 유지했다. 네이티브 증거는 TextSpan의 명시적 글꼴과 실제 배율·경계를 확인한 것이며 플랫폼이 사용한 글꼴 파일 정체를 별도로 추출한 검사는 아니다. 실제 Pretendard OTF 로딩은 위젯 검사에서 확인했다.
- 붙여넣기·빈/무효 입력·지우기·URL 한 줄 가로 이동·검증 문구 앞 5px·키보드 표시/해제·본문 드래그·저장 실패/수동 재시도·완료 탭 고정·닫기를 새로 실행했다. 실제 모바일 Clipboard와 저장 창을 사용하고, 준비 입력·사진 선택·저장 응답은 메모리 대역 및 Flutter 합성 포인터/컨트롤러로 실행한 범위를 구분한다. Android 클립보드 미리보기는 8초 기다려 자연 종료한 뒤 정식 OS 원본을 촬영했다.
- 증거는 임시 작업 폴더에서 영구 `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style`로 **270개 파일·102,133,667바이트**를 복사하고 [모든 복사 파일의 해시 일치](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/evidence-copy-verification.json)를 확인했다. [24건 비교 문서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/comparison-document.html)는 변경 전 → 변경 후 → 정확한 D01/D02/D03 기본 원본을 나란히 제공한다. 이번 24건의 Figma 누락은 0건이며 이전 높이 작업의 18건 누락 기록은 그대로 유지한다. 확대/키보드의 전용 디자인을 새로 만들지 않았다.
- [최종 비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/comparison-qa.json)·[입력/글자/원본 보존 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/pair-verification.json)는 조건 불일치 0건·BEFORE 이미지와 상태 24쌍 불변·fixture 불변·예상한 글꼴/색상 변경·문자 경계의 테두리 내부 포함·URL/지우기 가로 배치 보존을 확인했다. OS 영역을 자르거나 커서 차이를 보정하지 않았다. Android 3버튼은 창 자체가 24px 짧으므로 별도 여백을 더하지 않는다.
- [iOS AFTER 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/ios/after/interaction.mp4), [Android 제스처 AFTER 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/android-gesture/after/interaction.mp4), [Android 3버튼 AFTER 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/android-threebutton/after/interaction.mp4)을 제공한다. [영상 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/media-verification.json)는 이번 변경 전·후 정식 영상 6개를 전체 디코딩해 모두 종료 코드 0·오류 로그 0바이트를 확인했다. 제스처 BEFORE의 실패 영상은 완료 근거에 포함하지 않는다.
- [Android 최종 결과](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/android-final-result.json)·[설정 복원](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/android-navigation-restored.json)의 원래 mode 2·6개 overlay 일치와 앱 종료·임시 8768 포워딩 제거·에뮬레이터 종료를 확인했다. [iOS 최종 결과](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/ios-final-result.json)는 앱 종료와 Simulator `Shutdown`을 확인한다. 기기 데이터와 로컬 비교 서버 `127.0.0.1:8773`은 보존했다. 이전 작업의 검증 수치를 이번 결과로 사용하지 않으며 실제 서버·인증·운영 저장·실기기·원격 CI는 이번 대역 실행 검증 범위 밖이다.
