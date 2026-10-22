# 저장 버튼과 키보드·안전 영역

- 최초 기록일: 2026-10-15
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-b523a72a0351ca61"></a>

### 저장 화면 하단 안전 영역과 버튼 겹침 (2026-10-15, 해당 범위 적용·검증 완료)

<a id="b-467631be8efacd5f"></a>

현재 작업 기준은 `5d12e9d`입니다. 사용자 승인으로 본문 스크롤과 하단 CTA/토스트 영역을 분리하고,
버튼 아래 **`32 + max(viewInsets.bottom, viewPadding.bottom)`**을 한 번만 적용합니다.
키보드가 열리면 키보드 위 32px, 닫히면 실제 OS 안전 영역 위 32px을 유지합니다.
공통 내비게이션의 `64 + fontExtra + viewPadding.bottom` 및 키보드 높이를 더하지 않는 정책은 그대로이며,
입력 화면인 저장 창에 적용하는 위 회피 정책과 구분합니다.

<a id="b-9f79f7ed685928c2"></a>

본문 하단 패딩 24px·버튼 높이 56px/좌우 16px·토스트 좌우 40px/버튼 위 16px·토스트 3초 표시를 유지합니다.
토스트 표시 중에는 본문이 토스트 뒤로 이어지지 않도록 필요한 높이를 확보합니다.
저장 창의 `_SaveHomeIndicator`를 제거하고 실제 탐색 표시는 OS에 맡깁니다.
글자 축소·사진 비율/잘림·결과 상단 80px·카테고리 편집·공개 생성자/콜백/API/모델과 저장 정책은 바꾸지 않습니다.

<a id="b-901edd956d23f61c"></a>

이번 작업의 구현 준비 중 **2026-10-15 18:53:53 KST(09:53:53 UTC)**의 D01 `912:16502`·D06 `912:16524`·D07 `912:16551`·D05 `912:16639`·D09 `912:16602`
재조회는 모두 Figma Starter 호출 한도에 막혔습니다. D05는 앞선 확대 작업의 **18:07:32 KST(09:07:32 UTC)**,
D06/D09는 **17:56:18 KST(08:56:18 UTC)** 원본·컨텍스트를 출처와 함께 사용하며 이번 새 조회로 보고하지 않습니다.
D01/D07은 기존 원본도 없어 Figma 칸을 미확보로 표시합니다. 확대·키보드 전용 디자인이나 누락 원본을 만들어 채우지 않습니다.
기본 비교는 3개 기기/탐색 구성 × 5개 상태 × 3개 배율의 45쌍을 대상으로 하며,
이 중 D06/D05/D09 27건은 세 화면 비교, D01/D07 18건은 Figma 누락 사유를 표시합니다. 키보드·오류·최대 스크롤의 추가 비교는 45쌍이며 최종 산출/매체 확인은 별도 검증 기록을 따릅니다.

<a id="b-07692295615745b4"></a>

```bash
# frontend/ — 하단 배치와 기존 입력/사진 보존 회귀입니다.
flutter test --no-pub test/save_footer_layout_test.dart test/save_search_safe_area_test.dart
flutter test --no-pub
flutter analyze --no-pub

# 같은 고정 프리뷰를 before/after로 실행합니다.
flutter run --no-pub -d <device-id> -t test/support/save_result_preview.dart \
  --dart-define=SAVE_RESULT_PHASE=before
# Android: adb -s "$EMULATOR_ID" forward tcp:8768 tcp:8767
# iOS 주소이며 Android 호스트 요청은 8768 포트를 사용합니다.
curl 'http://127.0.0.1:8767/scene?kind=link-input&scale=1.5'
curl 'http://127.0.0.1:8767/scene?kind=photo-selected&scale=2'
curl 'http://127.0.0.1:8767/keyboard?scale=2'
curl 'http://127.0.0.1:8767/error?scale=1.5&keyboard=1'
curl 'http://127.0.0.1:8767/scroll?max=1'
curl http://127.0.0.1:8767/run
```

<a id="b-7b8ccfd09a7c117e"></a>

현재 프리뷰는 `kind=link-input|photo-empty|photo-selected|link|photo`, 배율 `1|1.5|2`의 15개 장면과
`/status`·`/scene`·`/run`·`/scroll?max=1`·`/keyboard?scale=...`·`/error?scale=...&keyboard=1`·`/keyboard-hide`를 제공합니다.
기존 `link`/`photo`는 성공 결과이며 새 `link-input`/`photo-selected`는 제출 전 입력 상태입니다.
제품 수정 전 동결한 SHA256은 `4b0ab767520f98b570a5741b1ca1f6cb5cbc4eaf6257005857765f9ebccc7cd3`이고 변경 전·후 동일 소스를 사용합니다.
`report.json`은 본문 viewport/마지막 항목/버튼/토스트의 경계와 실제 inset·최대 스크롤,
`targetLayoutFindings`·`targetLayoutPassed`를 기록합니다. `layoutPassed`·전체 `passed`는 프레임워크 오류뿐 아니라 실제 하단 정책 위반도 반영합니다.

<a id="b-e7bb5097d175ff1f"></a>

BEFORE는 새 정책 위반을 기록하면서 기존 동작 검사를 계속하고 AFTER는 이를 엄격 판정합니다.
IME에 가려진 BEFORE 버튼은 합성 탭으로 OS 창을 우회할 수 있어 접근 가능 증거로 쓰지 않습니다.
`/run`은 해당 기대 실패를 기록한 뒤 키보드를 닫아 재시도를 이어갑니다. AFTER는 실제 양수 keyboard inset·입력 보존·실패/재시도·완료 탭·닫기를 확인합니다.
선택 사진이 viewport보다 클 때는 최대 스크롤의 사진 하단 노출을, 마지막 안내 텍스트는 전체 경계를 검사합니다.

<a id="b-939893a4825fabc7"></a>

최초 재현 실행은 하단 검사 96개 모두 실패·기존 저장/검색 2개 중 1개 실패로 **98개 중 1개 통과·97개 실패**였습니다.
수정 후 집중 **98개**(8초)·관련 8개 파일 **266개**(20초)·전체 Flutter 테스트 **837개**(76초)가 통과했고
`flutter analyze --no-pub`는 **문제 없음**(5.1초)입니다.
제품 수정 전 iOS·Android 제스처·Android 3버튼 각각 30장, 총 **90장**의 OS 원본을 새로 확보하고 `before-gate.json`의 해시 검증 뒤 제품을 수정했습니다.
세 구성의 BEFORE는 각각 **87개 기록·프레임워크 오류 0건**, 동작 완료/보존은 통과하지만 하단 정책 위반으로 `layoutPassed`·전체 `passed: false`입니다.
AFTER는 iOS **84개 기록**·Android 제스처 **86개 기록**(촬영 재시도 2개 포함)·3버튼 **84개 기록**, 각각 프레임워크 오류 0건·`checksCompleted`·`behaviorPassed`·`layoutPassed`·전체 `passed`가 모두 `true`입니다.
각 구성의 기본 15장·추가 15장, 총 90장의 AFTER OS 원본을 새로 확보했습니다.

<a id="b-5f77ac549acb76ee"></a>

실제 창은 iOS 논리 393×852·DPR 3·안전 영역 59/34px,
Android 제스처 392.7×783.3·DPR 2.75·24/0px, Android 3버튼 392.7×759.3·DPR 2.75·24/0px입니다.
Android 3버튼은 OS 탐색 바가 Flutter 창 밖에 있어 창이 24px 짧으므로 이미 반영된 여백을 다시 더하지 않습니다.
키보드 표시/해제 inset은 iOS 336→0px, Android 제스처 274.909→0px·3버튼 250.909→0px입니다.
AFTER 버튼 아래 간격은 iOS 키보드 없음/있음 66/368px, Android 키보드 없음 32px·표시 시 각각 306.909px/282.909px로 승인식에 일치했습니다.
본문/버튼/토스트 분리·마지막 안내의 최대 스크롤·키보드 실패/재시도/닫기와 기존 제출/완료 탭 정책을 세 구성에서 확인했습니다.
두 Android 구성은 실제 `adb shell input tap`으로 키보드 위 중심 탭의 원래 URL 1회 저장·완료 탭 유지·버튼 하단 2px 탭의 닫기도 확인했습니다.
각 `native-taps/report.json`의 다섯 검사는 모두 `true`이며 실제 저장 API가 아닌 메모리 콜백입니다.
검증 후 탐색 모드/오버레이를 원래 제스처 설정으로 복원했고 `android-navigation-restored.json`의 `restored: true`를 확인했습니다. 임시 포워딩 제거·에뮬레이터 종료도 마쳤습니다.

<a id="b-02d4dbb581f10d4f"></a>

변경 전 Android 제스처 배율 1.5 오류 토스트는 최초 촬영 시 표시가 끝나 OS 원본을 재촬영했습니다. 최초 시도는 보존하고 전체 87개 보고서는 수정하지 않았습니다.
해당 변경 전 키보드 화면에서 기존 64×44px ‘붙여넣기’ 버튼의 확대 문구 두 줄 잘림도 확인했습니다.
버튼 크기/줄 정책은 D01 원본 및 확대 디자인이 없어 [디자인 확인 필요 목록](../figma-ui-alignment-plan.md#디자인-확인-필요)에 남기며 이번 하단 작업에서 바꾸지 않습니다.
기본 45쌍의 본문 노드 225개에서 폭·높이·글자 크기/배율·줄 수·말줄임 변경 0건, fixture 동결 SHA 일치를 확인했습니다.
이전 `5d12e9d`의 통과 결과는 이번 성공으로 사용하지 않으며 이번 결과를 저장 화면 전체 디자인·확대 표시 완료로 보고하지 않습니다.
증거 루트는 `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area`입니다.
[기본 45쌍·추가 45쌍 비교 문서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/comparison-document.html),
[iOS 동작](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/ios/after/interaction.mp4)·[iOS 키보드/레이아웃](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/ios/after/layout-keyboard.mp4),
[Android 제스처 동작](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/android-gesture/after/interaction.mp4)·[제스처 키보드/레이아웃](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/android-gesture/after/layout-keyboard.mp4),
[Android 3버튼 동작](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/android-threebutton/after/interaction.mp4)·[3버튼 키보드/레이아웃](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/android-threebutton/after/layout-keyboard.mp4),
[제스처 실제 OS 탭 보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/android-gesture/after/native-taps/report.json)·[3버튼 실제 OS 탭 보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/android-threebutton/after/native-taps/report.json)를 제공합니다.
OS 원본을 보정하지 않으며 [최종 비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/comparison-qa.json)에서 기본/추가 각 45쌍의 조건 불일치 0건·BEFORE 원본 90개 해시 불변·토스트 36개 상태 누락 0건을 확인했습니다.
[이번 촬영 영상 14개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/media-verification.json)를 모두 끝까지 디코딩해 종료 코드 0·오류 로그 0바이트를 확인했습니다.
iOS/Android 빌드는 성공했고 기존 Kotlin 2.2.10 지원 종료 예정·Java native-access 경고는 빌드 실패와 구분합니다.
운영 서버·실제 인증/저장·실기기·원격 CI는 대역 프리뷰 검증에 포함하지 않습니다.

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-b5194255a37fec91"></a>

### 2026-10-15 — 저장 화면 하단 안전 영역과 버튼 겹침 정리

<a id="b-74a04fea94894271"></a>

- 기준 커밋은 `5d12e9d`이며 사용자가 버튼 아래 **32px + 실제 OS 여백**, 키보드 표시 중에는 **키보드 위 32px**을 확정했다.
  공통 하단 탭의 키보드 미합산 정책과 별개인 전체 화면 저장 창의 기준이다.
- 본문 스크롤과 하단 버튼·토스트를 세로로 분리하고 본문 하단 24px을 유지한다. 버튼은 높이 56px·좌우 16px,
  오류 토스트는 좌우 40px·버튼 위 16px을 유지하며 표시 중 필요한 높이를 확보한다.
  하단 회피량은 `max(viewInsets.bottom, viewPadding.bottom)`을 한 번 적용하고 `_SaveHomeIndicator`를 제거한다.
  글자 축소·사진 비율/잘림·결과 상단 80px·카테고리 편집·공개 콜백/API/모델·저장 입력/완료 탭 정책은 변경하지 않는다.
- 이번 구현 준비 중 18:53:53 KST(09:53:53 UTC)에 D01 `912:16502`·D06 `912:16524`·D07 `912:16551`·D05 `912:16639`·D09 `912:16602`를
  재조회했으나 모두 Figma Starter 호출 한도로 실패했다. D05 원본은 이전 작업의 18:07:32 KST, D06/D09는 17:56:18 KST 원본을
  조회 기록과 함께 사용하며 이번에 새로 조회한 것으로 표시하지 않는다. D01/D07 원본은 없으므로 비교 누락을 기록하고 대체 이미지를 만들지 않는다.
- 제품 수정 전 하단 검사 96개와 기존 안전 영역 2개를 실행해 **1개 통과·97개 실패**로 재현했다.
  본문 viewport가 버튼과 32px 겹치며, 키보드 300px에서 버튼 하단이 746px로 고정되어 기대 480px을 충족하지 못했다.
  프레임워크 오류가 없더라도 겹침을 놓치지 않도록 본문·버튼·토스트 경계와 실제 inset을 검사한다.
- 촬영용 프리뷰를 제품 수정 전에 5개 상태 × 배율 1/1.5/2로 확장하고 동결했다.
  SHA256은 `4b0ab767520f98b570a5741b1ca1f6cb5cbc4eaf6257005857765f9ebccc7cd3`이며 변경 전·후 같은 파일을 사용한다.
  큰 선택 사진은 최대 스크롤의 사진 하단 노출을 검사하고, 마지막 안내 텍스트는 전체 경계를 검사한다.
  BEFORE의 OS 키보드에 가린 버튼을 합성 탭으로 누르는 것은 실제 접근 가능 증거로 사용하지 않는다.
- 수정 후 집중 **98개 통과**(8초), 관련 회귀 **266개 통과**(20초), 전체 `flutter test --no-pub` **837개 통과**(1분 16초)다.
  `flutter analyze --no-pub`는 **문제 없음**(5.1초)이며 제품·테스트 포맷과 공백 검사도 통과했다.
  이전 작업의 741개 테스트나 기기 증거를 이번 성공으로 사용하지 않는다.
- 제품 변경 전에 OS 포함 원본 **90개**를 새로 확보하고 `before-gate.json`에 기준 커밋·제품/프리뷰 해시와 원본 해시를 기록했다.
  세 설정의 BEFORE 보고서는 각각 87개 기록·프레임워크 오류 0건·기존 동작 통과였지만 본문/버튼 겹침과 가짜 선 때문에
  `layoutPassed`·전체 `passed`는 `false`였다. 오류 토스트 한 건은 촬영 지연으로 사라져 기존 자료를 `.attempts`에 보존하고 재촬영했다.
  촬영 전·후 토스트 존재를 확인했고 전체 87개 동작 보고서를 덮지 않도록 재촬영 보고서를 별도로 남겼다.

<a id="b-ee50f3c00d75c89e"></a>

| 기기·실제 창/여백 | 이번 AFTER 결과 |
| --- | --- |
| iPhone 16 / iOS 18.6, 393×852 논리 px·DPR 3·상단 59px/하단 34px | 84개 기록·오류 0건·네 완료 플래그 모두 `true`. 키보드 336→0px, 버튼 아래 간격은 일반 66px·키보드 표시 368px. 저장·실패/재시도·완료 탭·스크롤·닫기 성공. |
| Android 13/API 33 제스처, 392.7×783.3·DPR 2.75·상단 24px/하단 0px | 86개 기록·오류 0건·네 완료 플래그 모두 `true`. 키보드 약 274.909px. 실제 OS 입력으로 키보드 위 저장 버튼 중심과 닫기 버튼 하단을 눌러 저장 1회·닫기 성공. |
| 같은 Android 3버튼, 392.7×759.3·DPR 2.75·상단 24px/하단 0px | 84개 기록·오류 0건·네 완료 플래그 모두 `true`. 키보드 약 250.909px. 같은 실제 OS 탭 검사 성공. |

<a id="b-994cd529620dbe5a"></a>

- Android의 3버튼 탐색은 OS 탐색 영역 때문에 Flutter 창 자체가 제스처보다 24px 짧다. 앱에 전달된 하단 여백은 둘 다 0px이므로
  OS 영역을 다시 더하지 않았다. 원래 제스처 탐색 값 `2`와 관련 오버레이 전체를 복원해 원본과 일치함을 확인했다.
  임시 adb 포워딩을 제거하고 에뮬레이터를 종료했으며 앱/AVD 데이터는 보존했다.
- 동작은 실제 저장 위젯·고정 콜백/파일 선택 대역과 Flutter 합성 입력을 사용했다. Android의 별도 `native-taps`는 실제 OS의
  `adb input tap`을 사용하지만 저장 응답은 같은 대역이다. 실제 서버·인증·AI/OCR·실기기·원격 CI 검증으로 보고하지 않는다.
- 기존 범위 밖 문제: 확대 글자에서 링크 입력의 ‘붙여넣기’ 문구가 기존 고정 버튼 안에서 줄바꿈·잘리는 현상을 변경 전 원본에서 확인했다.
  D01 원본·확대용 버튼 배치를 확보하지 못했으므로 디자인 확인 목록에 남기고 이번 하단 수정과 분리한다.
  Android 빌드의 기존 Kotlin 2.2.10 지원 종료 예정·Java native-access 경고는 수정 전후 동일하며 빌드는 모두 성공했다.
- [기본 화면 45쌍과 추가 상태 45쌍 비교](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/comparison-document.html)를 제공한다.
  원본이 있는 D06/D05/D09의 27건은 변경 전 → 변경 후 → Figma 3열이며 D01/D07의 18건은 Figma 미확보 사유를 표시한다.
  확대·키보드 전용 디자인은 만들지 않는다. 기본 45쌍은 같은 기종·창·데이터·배율·스크롤 0이며,
  끝까지 스크롤한 추가 비교는 본문 높이가 달라 숫자 offset은 달라도 같은 마지막 위치를 사용했음을 표시한다.
  원본 OS 화면 전체를 종횡비 그대로 같은 표시 폭으로만 보여주며 OS 영역을 자르거나 보정하지 않았다.
- 본문·안내·미리보기·마지막 항목의 **225개 노드**에서 크기·글자 크기/배율·최대 줄 수·말줄임 변경이 없음을 확인했다.
  실제 제출 URL·사진 파일명/바이트·선택 탭·콜백 수와 고정 프리뷰 해시도 보존했다.
  Android 확대 오류 촬영의 지연 재시도 2건은 `.attempts`에 별도 보존하고 최종 원본에서는 촬영 전·후 토스트 존재를 확인했다.
- AFTER 키보드·오류·스크롤 영상:
  [iOS](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/ios/after/layout-keyboard.mp4),
  [Android 제스처](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/android-gesture/after/layout-keyboard.mp4),
  [Android 3버튼](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/android-threebutton/after/layout-keyboard.mp4).
  각 설정의 `interaction.mp4`와 BEFORE 영상도 비교 문서에서 볼 수 있다.
  실제 Android OS 탭의 [제스처 보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/android-gesture/after/native-taps/report.json)·
  [3버튼 보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/android-threebutton/after/native-taps/report.json)는 저장 1회·완료 탭 고정·닫기를 확인한다.
- [최종 비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/comparison-qa.json)에서 기본/추가 각 45쌍의 조건 불일치 0건·토스트 36개 상태 누락 0건과 BEFORE 90개 원본 해시 불변을 확인했다.
  [영상 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/media-verification.json)는 이번 촬영 영상 14개 모두 전체 디코딩 종료 코드 0·오류 로그 0바이트다.
  브라우저에서 플랫폼/배율 전환·이미지 3개 로드·Figma 누락 시 이미지 2개와 사유 표시·콘솔 오류 0건을 확인했다.
  모든 Simulator·Emulator를 종료하고 데이터는 보존했다.
  읽기 전용 비교 서버 `127.0.0.1:8771`과 기존 비교 서버는 유지한다.
  최종 diff·문서 링크·공백·민감 정보와 생성 파일 제외 여부를 확인한 뒤 `fix: 저장 화면 하단 안전 영역과 버튼 겹침 정리` 한 커밋으로 저장한다.
  화면 증거·빌드 생성물·`AGENTS.md`는 커밋에 포함하지 않고 푸시·PR은 하지 않는다.

## 원문 출처: docs/figma-ui-alignment-plan.md

<a id="b-787f72d119f303f5"></a>

### 2026-10-15 — 저장 화면 하단 안전 영역과 버튼 겹침 정리

<a id="b-1cd40325a6af348f"></a>

작업 기준은 `5d12e9d`이며 **승인된 하단 영역의 적용·검증을 완료**했다. 사용자 승인으로 다음 하단 기준을 확정했다.
기존 공통 내비게이션의 키보드 높이를 더하지 않는 정책과 달리, 전체 화면 저장 창은 입력 중에도 CTA를 키보드 위에 둔다.

<a id="b-0a12a8e84e48c57a"></a>

| 적용 대상 | 승인된 기준 |
| --- | --- |
| 본문·하단 버튼 | 본문 스크롤과 하단 영역을 분리해 viewport가 버튼 위에서 끝나도록 한다. 기존 본문 하단 패딩 24px을 유지하며 끝까지 스크롤하면 마지막 안내·카테고리를 볼 수 있어야 한다. |
| 실제 하단 여백·키보드 | 버튼 아래 `32 + max(MediaQuery.viewInsetsOf(context).bottom, MediaQuery.viewPaddingOf(context).bottom)`을 한 번만 적용한다. 키보드가 열리면 키보드 위 32px, 닫히면 OS 안전 영역 위 32px을 확보한다. 키보드와 OS 여백을 합산하거나 별도 하단 `SafeArea`로 중복 소비하지 않는다. |
| 버튼·오류 토스트 | 버튼 높이 56px·좌우 16px을 유지한다. 토스트는 좌우 40px·버튼 위 16px이며 표시 중 필요한 높이를 별도로 확보해 본문을 덮지 않게 한다. 토스트 모양·3초 표시 시간·수동 재시도를 유지한다. |
| OS 표시와 기존 계약 | `_SaveHomeIndicator`만 제거하고 실제 탐색 표시는 OS에 맡긴다. 공개 생성자·콜백·API·모델·제출 입력 고정·완료 탭 고정·중복 제출 방어는 유지한다. 글자 축소·사진 비율/잘림·결과 상단 80px·카테고리 편집은 이번 범위가 아니다. |

<a id="b-2c7c157ca8f91fe4"></a>

### 이번 작업의 디자인 근거와 비교 제한

<a id="b-f6ff67d9c2bdf1da"></a>

- 이번 작업의 구현 준비 중 **2026-10-15 18:53:53 KST / 09:53:53 UTC**에 D01 `912:16502`·D06 `912:16524`·D07 `912:16551`·D05 `912:16639`·D09 `912:16602`의 재조회를 시도했으나 5개 모두 Figma Starter 호출 한도로 원본·컨텍스트를 새로 확보하지 못했다.
- D05는 이전 확대 작업에서 확보한 **18:07:32 KST / 09:07:32 UTC**, D06/D09는 **17:56:18 KST / 08:56:18 UTC**의 원본·컨텍스트를 출처와 함께 그대로 사용한다. 이를 이번 작업에서 새로 조회한 디자인으로 보고하지 않는다.
- D01/D07은 사용할 기존 원본·컨텍스트도 없다. 앱 변경 전·후는 촬영하되 Figma 칸은 미확보 사유를 표시한다. 다른 상태의 원본을 대신 넣거나 대체 디자인을 만들지 않는다. 확대·키보드의 전용 Figma도 없으므로 기본 원본과 사용자 확정 기준을 구분한다.
- 기본 비교 대상은 iOS·Android 제스처·Android 3버튼의 5개 상태 × 배율 1/1.5/2, 총 **45쌍**이다. D06/D05/D09의 **27건**만 세 화면 비교가 가능하고 D01/D07의 **18건**은 Figma 원본 누락을 표시한다. 키보드·오류·최대 스크롤 비교는 별도 증거로 제공한다. 추가 비교는 키보드 표시/해제·오류 토스트·최대 스크롤의 **45쌍**이다. 최종 산출·매체 확인은 별도 검증 기록을 따른다.

<a id="b-fab9af9976620230"></a>

### 이번 작업의 실제 검증 결과

<a id="b-dbaa8df428179ed3"></a>

- 제품 수정 전 최초 재현 검사는 [하단 배치 검사](../../frontend/test/save_footer_layout_test.dart) 96개 모두 실패하고 [기존 저장/검색 안전 영역 검사](../../frontend/test/save_search_safe_area_test.dart) 2개 중 1개가 실패해, **98개 중 1개 통과·97개 실패**로 기존 하단 고정값·본문 겹침·키보드 회피 문제를 확인했다. 수정 후 집중 **98개**(8초)·관련 8개 파일 **266개**(20초)·전체 Flutter 테스트 **837개**(76초)가 통과했고 `flutter analyze --no-pub`는 **문제 없음**(5.1초)이다.
- [기기 프리뷰](../../frontend/test/support/save_result_preview.dart)는 제품 수정 전에 `link-input`·`photo-empty`·`photo-selected`·`link`·`photo`와 배율 1/1.5/2로 확장하고 동결했다. 변경 전·후 같은 파일을 사용하며 SHA256은 `4b0ab767520f98b570a5741b1ca1f6cb5cbc4eaf6257005857765f9ebccc7cd3`이다.
  본문 viewport·마지막 항목·버튼·토스트 경계, 실제 inset·최대 스크롤을 기록한다. BEFORE는 새 정책 위반을 findings로 남기고 기존 동작을 계속 검사하며 AFTER는 실제 정책과 프레임워크 오류를 함께 엄격 판정한다.
- 키보드가 가린 BEFORE 버튼에 Flutter 합성 탭을 보내도 OS의 IME 창을 우회할 수 있으므로 실제 접근 가능 증거로 쓰지 않는다. `/run`은 이를 기대된 기존 실패로 기록하고 키보드를 닫은 뒤 재시도를 계속한다. AFTER는 양 플랫폼의 실제 양수 inset과 키보드 위 버튼·재시도를 확인해야 한다.
- 큰 선택 사진이 viewport보다 높으면 최대 스크롤에서 사진 하단과 24px 여백을 확인한다. 마지막 안내처럼 viewport 안에 들어갈 수 있는 항목은 전체 경계를 확인한다. 사진 전체가 동시에 보이는 정책으로 바꾸지 않는다.
- 제품 수정 전에 iOS·Android 제스처·Android 3버튼 각 30장, 총 **90장**의 OS 원본을 새로 확보했다. `before-gate.json`에 기준 커밋·제품 파일 및 90장 원본의 해시를 기록한 뒤 제품을 수정했다. 세 구성의 BEFORE 보고서는 각각 **87개 기록·프레임워크 오류 0건**, `checksCompleted`·`behaviorPassed: true`, `layoutPassed`·전체 `passed: false`다. 본문 viewport가 버튼 뒤로 32px 이어지고 가짜 선이 남으며 키보드가 버튼을 가리는 기존 정책 위반을 기록했다.
- AFTER는 iOS **84개 기록**·Android 제스처 **86개 기록**(촬영 재시도 2개 포함)·3버튼 **84개 기록**, 각각 프레임워크 오류 0건이며 `checksCompleted`·`behaviorPassed`·`layoutPassed`·전체 `passed`가 모두 `true`다. 각 구성에서 기본 15장과 추가 15장, 총 90장의 AFTER OS 원본을 확보했다.
- 실제 창 크기는 iPhone 16/iOS 18.6 논리 393×852·DPR 3·상단/하단 59/34px, Android 제스처 392.7×783.3·DPR 2.75·상단/하단 24/0px, Android 3버튼 392.7×759.3·DPR 2.75·상단/하단 24/0px이다. 3버튼은 Flutter 창 자체가 제스처보다 24px 짧고 OS 탐색 바가 창 밖에 있으므로 별도 24px을 다시 더하지 않는다.
- 키보드 표시/해제 inset은 iOS 336→0px, Android 제스처 274.909→0px·3버튼 250.909→0px다. AFTER 버튼 아래 실제 간격은 iOS 키보드 없음/있음 66/368px, Android 키보드 없음 32px·표시 시 각각 306.909px/282.909px로 `32 + max(insets, viewPadding)`과 일치했다. 본문/토스트/버튼 분리·최대 스크롤의 마지막 안내·키보드 실패/재시도/닫기와 기존 제출/완료 탭 정책을 세 구성에서 확인했다.
- 두 Android 탐색 방식은 합성 포인터 검사 외에 실제 `adb shell input tap`으로 키보드 위 CTA 중심을 눌러 원래 URL을 한 번 저장하고, 완료 탭 유지와 버튼 하단 2px 탭의 닫기를 확인했다. `native-taps/report.json`의 다섯 항목은 모두 `true`이며 콜백은 여전히 메모리 대역이다. Android 탐색 모드·오버레이를 원래 제스처 설정으로 복원한 `android-navigation-restored.json`의 `restored: true`를 확인했고 임시 포워딩 제거·에뮬레이터 종료를 마쳤다.
- 변경 전 Android 제스처 배율 1.5 오류 토스트는 최초 OS 촬영 때 3초 표시가 끝나 재촬영했다. 최초 시도는 별도 보존하고 토스트가 실제로 있는 재촬영 원본을 사용하며, 기존 전체 87개 보고서를 수정하지 않았다. 같은 변경 전 원본에서 기존 ‘붙여넣기’ 문구 잘림을 확인해 위 디자인 확인 목록에 별도로 기록했다.
- 기본 45쌍의 본문 노드 225개를 대조해 폭·높이·글자 크기·배율·줄 수·말줄임의 변경 0건을 확인했고 fixture 동결 SHA도 일치했다. 이전 `5d12e9d`의 741개 테스트·32개 기기 기록을 이번 성공으로 사용하지 않으며 이번 하단 검증을 저장 화면 전체 디자인·확대 표시 완료로 확대하지 않는다.
- 증거 루트는 `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area`이다.
  [기본 45쌍·추가 45쌍 비교 문서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/comparison-document.html),
  [iOS 동작](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/ios/after/interaction.mp4)·[iOS 키보드/레이아웃](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/ios/after/layout-keyboard.mp4),
  [Android 제스처 동작](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/android-gesture/after/interaction.mp4)·[제스처 키보드/레이아웃](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/android-gesture/after/layout-keyboard.mp4),
  [Android 3버튼 동작](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/android-threebutton/after/interaction.mp4)·[3버튼 키보드/레이아웃](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/android-threebutton/after/layout-keyboard.mp4),
  [제스처 실제 OS 탭 보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/android-gesture/after/native-taps/report.json)·[3버튼 실제 OS 탭 보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/android-threebutton/after/native-taps/report.json)를 제공한다.
  원본 OS 크기·안전 영역을 보정하지 않으며 Figma의 기본 프레임·사용자 승인 키보드/확대 기준을 구분한다.
- [최종 비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/comparison-qa.json)는 기본 45쌍·추가 45쌍의 조건 불일치 0건, BEFORE 원본 90개 해시 불변, 오류 토스트 36개 상태의 누락 0건을 확인했다.
  [영상 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/media-verification.json)는 이번 촬영 영상 14개 모두 전체 디코딩 종료 코드 0·오류 로그 0바이트다.
  Simulator·Emulator는 검증 후 종료하고 데이터와 로컬 비교 서버 `127.0.0.1:8771`은 보존했다.
- iOS/Android 빌드는 성공했다. 기존 Android Kotlin 2.2.10 지원 종료 예정·Java native-access 경고는 빌드 실패와 구분한다. 실제 서버·인증·AI/OCR·실기기·원격 CI는 대역 렌더링 검증에 포함하지 않는다.
