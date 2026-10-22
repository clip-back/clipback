# 저장 화면 확대 글자 높이

- 최초 기록일: 2026-10-15
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-c828c2f433e14d94"></a>

### 저장 화면의 확대 글자 높이 (`5d12e9d`, 2026-10-15)

<a id="b-5c157d34da4d4602"></a>

`a14111f`를 기준으로 **글자를 줄이지 않고 필요한 만큼 높이를 늘리는** 사용자 기준을 적용합니다.
사진 선택 전 안내는 최소 89px, 링크·사진 결과 미리보기는 최소 116px이며 기본 배율의 기존 크기를 유지합니다.
텍스트 열은 자연 높이를 사용하고 `TextScaler`·글꼴·글자 크기를 바꾸지 않습니다.
40×40px 선택 아이콘·좌우 16px·기존 간격, 결과 카드 안쪽 8px·164×100px 썸네일·제목 최대 두 줄·출처 한 줄·말줄임과
이미지/텍스트 세로 중앙 정렬을 유지합니다. 배율별 높이나 수동 글자 높이 계산은 추가하지 않습니다.

<a id="b-f43a88a6f8f02454"></a>

최신 `261008`의 D06 `912:16524`·D05 `912:16639`·D09 `912:16602` 컨텍스트·기본 원본을
2026-10-15 17:56:18 KST(08:56:18 UTC)에 확보했습니다. 제품 수정 직전 D05 재조회는 18:07:32 KST(09:07:32 UTC)에 성공했고
D06·D09는 Starter 호출 한도에 막혀 같은 작업에서 확보한 위 원본·컨텍스트를 사용했습니다.
확대 전용 디자인은 없으므로 기본 원본과 사용자 확정 기준을 구분해 비교합니다.
사진 확대/잘림·결과 상단 80px·카테고리·하단 버튼과 인디케이터·안전 영역은 이번 범위에서 바꾸지 않습니다.
공개 생성자·콜백·API·모델·실제 제출 입력과 완료 탭 고정·저장 시점도 유지합니다.

<a id="b-41c51ce9bb0593e7"></a>

```bash
# frontend/ — 새 확대 검사와 기존 입력·탭·키보드 회귀입니다.
flutter test --no-pub test/save_scaled_layout_test.dart test/saved_content_confirmation_test.dart test/save_search_safe_area_test.dart
flutter test --no-pub
flutter analyze --no-pub

# 같은 고정 프리뷰를 before/after로 실행합니다.
flutter run --no-pub -d <device-id> -t test/support/save_result_preview.dart \
  --dart-define=SAVE_RESULT_PHASE=before
# Android: adb -s "$EMULATOR_ID" forward tcp:8768 tcp:8767
# 아래는 iOS 주소입니다. Android 호스트 요청은 8768 포트를 사용합니다.
curl 'http://127.0.0.1:8767/scene?kind=photo-empty&scale=1.5'
curl http://127.0.0.1:8767/run
```

<a id="b-0c218741c4f9c735"></a>

이 커밋 당시 프리뷰는 `kind=photo-empty|link|photo`, 배율 `1|1.5|2`의 9개 상태를 제공했으며
`photo_empty_scale_1_5.png`처럼 배율별 파일명을 구분합니다. `/status`, `/scene`, `/run`, `/scroll`, `/keyboard`, `/keyboard-hide`를 제공합니다.
`/run`은 양 phase에서 기존 문구·제출 입력·성공 탭 고정·중복 제출 방지·실패 후 재시도·재선택·확대 스크롤·늦은 응답·키보드 표시/해제를 검사합니다.
안내·미리보기·텍스트·이미지 경계/크기와 실제 글자 크기를 `report.json`에 기록하고 AFTER에서는 새 레이아웃을 엄격 판정합니다.
제품 수정 전 고정한 파일 SHA256은 `2e45d3ca0d562b52bf6f9accf498b70034fd09f73a596c2c608c5568a61e3880`이며 변경 전·후에 같은 파일을 사용합니다.

<a id="b-51184777e873d1fa"></a>

제품 수정 전 iPhone 16/iOS 18.6·Android 13/API 33의 세 상태·배율 1/1.5/2를 새로 촬영했습니다.
새 확대 검사는 제품 수정 전 **38개 중 18개 실패·20개 통과**로 넘침을 재현했습니다. 수정 후
집중 확대 검사 **38개**(5초)·관련 회귀 **170개**(32초)·전체 Flutter 테스트 **741개**(1분 20초)를 통과했습니다.
`flutter analyze --no-pub`는 **문제 없음**(12.2초)입니다. 수정 후 두 플랫폼 보고서는 각각 **32개 기록·프레임워크 오류 0건**이며 `checksCompleted`·`behaviorPassed`·`layoutPassed`·전체 `passed`가 모두 `true`입니다.
이번 변경 전 기기 보고서는 두 플랫폼 각각 32개 기록이며 `checksCompleted`·`behaviorPassed: true`, `layoutPassed`·전체 `passed: false`였습니다.
안내/결과 텍스트 열의 확대 넘침을 iOS 2px/46px·Android 4px/47px로 재현했습니다. 이번 변경 전 키보드 inset은 iOS 336px·Android 274.909px로
양쪽에서 측정했으며 위 `a14111f` 당시 Android 0px 한계와 구분합니다.
iPhone 16/iOS 18.6은 논리 393×852·DPR 3·안전 영역 상단/하단 59/34px,
Pixel 3a 설정/Android 13(API 33) 제스처 모드는 논리 392.7×783.3·DPR 2.75·상단/하단 24/0px입니다.
배율 1/1.5의 안내·미리보기 높이는 두 플랫폼 모두 89/116px, 배율 2는 iOS 91/162px·Android 93/163px입니다.
썸네일 164×100px·기존 글자 크기와 배율·텍스트 경계·세로 중앙 정렬을 확인했습니다.
양쪽에서 저장·재선택·실패 후 재시도·요청 중 탭 이동·완료 탭 고정·확대 본문 스크롤·닫기/늦은 응답을 확인했습니다.
키보드 표시/해제 inset은 iOS 336→0px·Android 274.909→0px이고 양쪽 OS 원본에서 표시를 확인했습니다.
이전 `a14111f`의 테스트·확대 오류·기기 결과는 위 당시 기록에 남기고 이번 통과로 사용하지 않습니다.

<a id="b-14c6413a5e7837a4"></a>

증거 루트는 `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-scaled-layout`입니다.
[변경 전 → 변경 후 → Figma 비교 18건](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-scaled-layout/comparison-document.html),
[iOS 동작 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-scaled-layout/ios/after/interaction.mp4),
[Android 동작 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-scaled-layout/android/after/interaction.mp4)을 제공합니다.
동일 기종·데이터·배율·스크롤 위치의 OS 원본과 Figma 기본 원본을 비교하고 실제 안전 영역 차이를 설명합니다.
확대용 대체 디자인을 만들지 않으며 사진 비율/잘림·상단/하단 배치의 보류 범위를 표시합니다. 저장 화면 전체 디자인 맞춤의 완료로 보고하지 않습니다.
실제 서버·인증·AI/OCR·실기기·원격 CI는 대역 프리뷰 검증 범위에 포함하지 않습니다.

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-6120e12b783e1c15"></a>

### 2026-10-15 — 저장 화면의 확대 글자 넘침 수정

<a id="b-5743a57fd094bd49"></a>

- 브랜치 `feature/figma-ui-alignment`, 변경 전 기준 `a14111f`.
  사용자 확정 기준은 **글자를 축소하지 않고 필요한 만큼 높이를 늘린다**이다.
  사진 선택 전 안내의 기본 89px·저장 결과 미리보기의 기본 116px을 최소 높이로 바꾸고,
  내부 텍스트 열은 자연 높이를 사용한다. 별도 배율별 높이 계산이나 새 세로 여백은 추가하지 않는다.
  기존 아이콘 40×40px·썸네일 164×100px·카드 여백 8px·제목 최대 두 줄·출처/안내 본문 한 줄 말줄임을 유지한다.
  기본 배율의 배치와 확대 시 썸네일/텍스트의 세로 중앙 정렬을 확인했다.
- 공개 생성자·콜백·API·데이터 모델과 저장 시점·제출 입력 고정·완료 탭 정책은 변경하지 않았다.
  사진 비율과 샘플용 잘림, 결과 상단 80px, 카테고리, 고정 하단 버튼/인디케이터는 기존 보류 범위다.
  확대 전용 Figma를 새로 만들지 않고 사용자 확정 기준을 [계획](../figma-ui-alignment-plan.md)에 기록했다.
- 최신 파일 `b2lmAo9VtbL6Qi0mzX5IMu > WireFrame & UI > 261008`의 D06 `912:16524`,
  D05 `912:16639`, D09 `912:16602` 원본·컨텍스트를 이번 작업에서 확보해 **17:56:18 KST / 08:56:18 UTC**에 기록했다.
  제품 수정 직전 재조회는 **18:07:32 KST / 09:07:32 UTC**이며 D05만 성공했다.
  D06·D09는 Figma MCP Starter 호출 한도에 걸려 이번 작업 초기에 확보한 원본을 사용했다.
  각 컨텍스트의 실제 확보 시각·재조회 제한·파일 기록 시각을 구분했으며 이전 작업 이미지를 재사용하거나 대체 디자인을 만들지 않았다.
- **제품 수정 전** 프리뷰에 사진 선택 전 안내·배율 1.5·세 영역의 기하 측정을 추가했다.
  `before-gate.json`에서 기준 SHA·제품 diff 없음과 **두 플랫폼 × 세 상태 × 세 배율 = 새 OS 원본 18장**을 확인했다.
  전후 프리뷰 SHA256은 `2e45d3ca0d562b52bf6f9accf498b70034fd09f73a596c2c608c5568a61e3880`으로 같다.
  이전 문구·제출 입력·완료 탭 정책은 BEFORE/AFTER 양쪽에서 검사하며 단계 차이는 새 높이·경계 기준뿐이다.
- 새 회귀 테스트 **38개**는 iOS/Android 테마 × 폭 320/375px × 배율 1/1.5/2의 세 위젯 검사 36개와
  실제 저장 창 진입·사진 선택·저장·완료 탭 고정·스크롤·닫기 2개다.
  수정 전 **20 passed / 18 failed**로 긴 제목의 링크/사진 카드 넘침을 재현했다.
  위젯 테스트는 대체 폰트/줄 높이가 달라 사진 안내가 89px에 들어갔으며, 기기의 안내 넘침 재현과 구분했다.
  실제 기기 BEFORE에서는 안내 iOS 2px·Android 4px, 카드 텍스트 열 46px·47px 넘침을 확인했다.
- 수정 후 집중 **38 passed**(5초), 관련 7개 파일 **170 passed**(32초),
  전체 `flutter test --no-pub --reporter expanded` **741 passed**(1분 20초),
  `flutter analyze --no-pub` **문제 없음**(12.2초), 변경 Dart 3개 형식 검사 **0 changed**다.
  이전 703개 통과를 이번 결과로 사용하지 않았다. 새 검사에서는 실제 RenderParagraph 배율·글꼴 크기,
  경계·말줄임·이미지 크기·중앙 정렬과 기본 높이를 확인했다.

<a id="b-1bfa8cf629f8a0a6"></a>

| 실제 실행 환경 | 기본/배율 1.5 → 배율 2 높이 | 동작·기기 결과 |
| --- | --- | --- |
| iPhone 16 / iOS 18.6 Simulator, 논리 393×852·DPR 3·상단 59px/하단 34px | 안내 89/89 → 91px, 링크·사진 카드 116/116 → 162px | 32개 기록, 프레임워크 오류 0건. 확대 본문 스크롤 170px, 키보드 inset 336→0px. |
| Android 13/API 33 Emulator `Clipback_Share_API_33`, 논리 392.7×783.3·DPR 2.75·상단 24px/하단 0px·제스처 모드 2 | 안내 89/89 → 93px, 링크·사진 카드 116/116 → 163px | 32개 기록, 프레임워크 오류 0건. 확대 본문 스크롤 198px, 키보드 inset 약 274.91→0px. |

<a id="b-3d8a0c5e32ea1583"></a>

- 두 AFTER 보고서는 **`checksCompleted`·`behaviorPassed`·`layoutPassed`·전체 `passed` 모두 `true`**다.
  BEFORE의 동작 검사는 통과했지만 기존 넘침으로 레이아웃/전체 판정은 `false`였음을 그대로 보존한다.
  사진 선택/재선택·저장·교차 탭과 초안 변경·완료 탭 고정·중복 방지·실패 후 재시도·닫힌 화면의 늦은 응답,
  확대 본문 스크롤·키보드 표시와 해제를 실제 위젯과 Flutter 합성 포인터/컨트롤러 입력으로 검사했다.
  Android는 이번 키보드 대기 후 실제 양수 inset과 OS 원본 표시를 확인했다. 과거 0px 기록을 수정해 덮지 않는다.
- 이 결과는 수정한 두 영역과 해당 대역 동작의 성공이다. 기존 고정 하단 버튼에 의한 안내 가림,
  앱/OS 인디케이터 중복, 사진의 확대/잘림을 포함한 저장 화면 전체 디자인 완료를 의미하지 않는다.
  실제 OAuth·운영 서버·AI/OCR·실기기·원격 CI·실제 서버 저장 완료는 검증하지 않았다.

<a id="b-68ab7de37a03c913"></a>

증거 루트: `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-scaled-layout`.

<a id="b-e77182c9164f3b8e"></a>

- [변경 전 → 변경 후 → Figma 비교 18건](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-scaled-layout/comparison-document.html)은
  원본 OS 화면 전체를 동일 표시 폭으로만 줄여 제공한다. 기종·창·DPR·데이터·배율·스크롤 0·OS 여백을 맞췄고,
  글꼴 크기·실제 배율·줄 수·이미지 크기 불변을 별도 대조했다. 원본의 OS 영역을 자르거나 위치를 보정하지 않았다.
  Figma 375×812와 실제 창/안전 영역, 기본 원본을 사용하는 확대 비교와 남은 하단/사진 배치 차이를 명시한다.
- AFTER 동작 영상: [iOS](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-scaled-layout/ios/after/interaction.mp4),
  [Android](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-scaled-layout/android/after/interaction.mp4).
  각각 H.264 1178×2556/83.781667초와 1080×2220/122.177111초다. iOS OS PNG는 원본 1179×2556으로 유지했다.
  BEFORE 영상·Flutter 캡처·키보드 표시/해제 원본·전후 보고서와 검사 로그도 보존한다.
- 두 AFTER 영상을 끝까지 디코딩해 종료 코드 0·오류 로그 0바이트를 확인했다.
  18쌍의 원본 조건·글자 배율/크기·줄 수·썸네일 크기와 일반 배율 6개 영역의 픽셀 동일을 확인했다.
  문서 3개의 로컬 Markdown 링크 **159개 모두 존재**하며 최종 diff·공백·민감 정보/생성 파일 제외를 확인했다.
  이번에 실행한 Simulator·Emulator는 종료하고 앱/AVD 데이터는 보존했다.
  읽기 전용 비교 서버 `127.0.0.1:8770`과 이전 비교 서버는 유지한다.
- 제품 1개·회귀 테스트 1개·프리뷰 1개·문서 3개를 한 커밋으로 저장하며 제목은
  `fix: 글자 확대 시 저장 화면 넘침 수정`이다. 화면 증거·빌드 생성물·`AGENTS.md`는 제외하고 푸시·PR은 수행하지 않는다.

## 원문 출처: docs/figma-ui-alignment-plan.md

<a id="b-596d2040898760f0"></a>

### 2026-10-15 — 저장 화면의 확대 글자 높이

<a id="b-61275bef92183eb7"></a>

작업 기준은 `a14111f`이다. 사용자는 **글자를 축소하지 않고 필요한 만큼 높이를 늘린다**는 기준을 확정했다.
확대 전용 Figma를 새로 만들지 않고 최신 `261008`의
[사진 선택 전 D06](https://www.figma.com/design/b2lmAo9VtbL6Qi0mzX5IMu/?node-id=912-16524),
[링크 결과 D05](https://www.figma.com/design/b2lmAo9VtbL6Qi0mzX5IMu/?node-id=912-16639),
[사진 결과 D09](https://www.figma.com/design/b2lmAo9VtbL6Qi0mzX5IMu/?node-id=912-16602)의 기본 원본과 사용자 기준을 함께 사용한다.
원본·컨텍스트는 17:56:18 KST(08:56:18 UTC)에 확보했고 D05는 제품 수정 직전 18:07:32 KST(09:07:32 UTC)에 재조회했다.
D06·D09 직전 재조회는 Starter 호출 한도에 막혀 같은 작업에서 확보한 최초 원본·컨텍스트를 사용했다.

<a id="b-d9d1875085293639"></a>

| 적용 영역 | 확정 기준과 구현 |
| --- | --- |
| 사진 선택 안내 | 고정 89px을 최소 89px로 바꾸고 텍스트 열은 자연 높이를 사용한다. 40×40px 아이콘·좌우 16px·아이콘 뒤 8px·문구 사이 4px·본문 한 줄 말줄임을 유지한다. 새 세로 여백을 추가하지 않는다. |
| 링크·사진 결과 미리보기 | 고정 116px을 최소 116px로 바꾸고 텍스트 열은 자연 높이를 사용한다. 안쪽 8px·164×100px 썸네일·제목 최대 두 줄·출처 한 줄·말줄임·기존 간격을 유지하며 이미지와 텍스트를 세로 중앙에 둔다. |
| 글자와 동작 | 기존 `TextScaler`·Pretendard·글자 크기를 그대로 사용한다. 배율별 높이 상수·수동 글자 높이 계산·글자 축소는 추가하지 않는다. 실제 제출 입력과 완료 탭 고정·오류/수동 재시도·저장/닫기 정책도 유지한다. |

<a id="b-cc8bf2111a5482c5"></a>

공개 생성자·콜백·API·데이터 모델은 바꾸지 않는다. 사진 확대/잘림·결과 상단 80px·카테고리·하단 버튼과
`_SaveHomeIndicator`·안전 영역은 이번 수정 범위에 포함하지 않는다. UI-06 전체 적용으로 표시하지 않는다.

<a id="b-bcb21c029b226990"></a>

### 저장 화면 확대 작업의 검증 상태

<a id="b-bd042f63f0cc1f35"></a>

- [확대 회귀 검사](../../frontend/test/save_scaled_layout_test.dart)는 제품 수정 전 **38개 중 18개 실패·20개 통과**로 넘침을 재현했다.
  iOS/Android 테마 × 폭 320/375px × 배율 1/1.5/2의
  사진 선택 안내·링크 결과·사진 결과와 두 플랫폼의 실제 저장 창 통합 동작을 검사한다.
  기본 높이·필요 높이 증가·실제 글자 크기/배율·텍스트 경계·말줄임·썸네일 크기·세로 중앙 정렬을 확인한다.
- [기기 프리뷰](../../frontend/test/support/save_result_preview.dart)는 제품 수정 전에 3개 상태 × 배율 1/1.5/2의 9개 장면으로 확장하고
  동일 파일을 변경 전·후에 사용한다. 고정 SHA256은 `2e45d3ca0d562b52bf6f9accf498b70034fd09f73a596c2c608c5568a61e3880`이다.
  `photo_empty_scale_1_5`처럼 배율별 이름을 구분하며 각 안내·카드·글자·이미지의 경계·높이와 글자 크기를 보고서에 기록한다.
  기존 문구·실제 제출 입력·완료 탭 정책은 양 phase에서 검사하고 새 레이아웃의 엄격 판정은 AFTER에 적용한다.
- 제품 수정 전 두 플랫폼의 OS 원본 18개를 새로 확보했다. 집중 확대 검사 **38개**(5초)·관련 회귀 **170개**(32초)·전체 Flutter 테스트 **741개**(1분 20초)가 통과했다.
  `flutter analyze --no-pub`는 **문제 없음**(12.2초)이다. 변경 후 두 플랫폼의 보고서는 각각 32개 기록·프레임워크 오류 0건이며
  `checksCompleted`·`behaviorPassed`·`layoutPassed`·전체 `passed`가 모두 `true`다.
  이전 `a14111f`의 703개 테스트·18개 기기 기록·확대 실패는 해당 문구 작업의 역사로 보존하며 이번 통과 근거로 사용하지 않는다.
- 이번 변경 전 기기 보고서는 두 플랫폼 각각 32개 기록이며 `checksCompleted`·`behaviorPassed: true`, `layoutPassed`·전체 `passed: false`였다.
  확대 상태의 안내/결과 텍스트 열 넘침을 iOS 2px/46px·Android 4px/47px로 재현했다.
  변경 전 키보드 inset은 iOS 336px·Android 274.909px로 양쪽에서 측정했으며 이전 작업의 Android 0px 한계와 구분한다.
- iPhone 16/iOS 18.6 Simulator는 논리 393×852·DPR 3·상단/하단 59/34px,
  Pixel 3a 설정/Android 13(API 33) Emulator 제스처 모드는 논리 392.7×783.3·DPR 2.75·상단/하단 24/0px이다.
  배율 1/1.5의 안내·미리보기는 양쪽 모두 89/116px이다. 배율 2는 iOS 91/162px·Android 93/163px이며
  썸네일은 모두 164×100px·글자 크기와 배율은 기존 값 그대로다. 안내·카드 안의 텍스트 경계와 세로 중앙 정렬을 검사했다.
  저장·재선택·실패 후 재시도·요청 중 탭 이동·완료 탭 고정·확대 본문 스크롤·닫기/늦은 응답을 양쪽에서 확인했다.
  키보드 표시/해제 inset은 iOS 336→0px·Android 274.909→0px이며 양쪽 OS 원본에서 실제 표시를 확인했다.
- 증거 루트는 `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-scaled-layout`이다.
  [변경 전 → 변경 후 → Figma 비교 18건](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-scaled-layout/comparison-document.html),
  [iOS 동작 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-scaled-layout/ios/after/interaction.mp4),
  [Android 동작 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-scaled-layout/android/after/interaction.mp4)을 제공한다.
  같은 기종·데이터·배율·스크롤 위치의 OS 원본을 사용하며 안전 영역과 Figma 기본 프레임 차이를 설명한다.
  배율 1.5/2에서도 Figma는 기본 원본을 사용하고 확대 디자인을 만들어 채우지 않는다. 사진 비율/잘림·결과 상단·하단 배치는 보류 범위로 표시한다.
- 실제 서버·인증·AI/OCR·실기기·원격 CI는 대역 렌더링 검증에 포함하지 않는다.
