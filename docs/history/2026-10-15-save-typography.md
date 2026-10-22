# 저장 화면 기본 글자와 상단

- 최초 기록일: 2026-10-15
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-d3f2bc5b36b20c47"></a>

### 저장 화면 기본 글자와 공통 상단 (`a54c387` 기준, 해당 범위 적용·검증 완료)

<a id="b-9d6dee0869f94814"></a>

이번 대상은 최신 `261008` 저장 화면의 **1배율 글자·공통 상단**입니다.
제목/닫기·링크/사진 탭·입력과 결과의 ‘저장할 링크/사진’·URL/파일명·사진 선택 안내·링크 검증·저장/닫기 버튼에
저장 화면 전용 Pretendard를 명시하고 Figma의 굵기·자간·색상·줄 높이를 대조합니다.
상단 제목과 입력/결과의 ‘저장할’ 제목은 검정 `#000000`, 탭 자간은 −0.4px,
하단 버튼은 16px/SemiBold·줄 높이 22px·자간 0px·활성 노랑/비활성 흰 글자 기준입니다.
나머지 대상은 고정 줄 높이를 새로 만들지 않는 AUTO 기준을 사용합니다.

<a id="b-4fa1a85ae700266e"></a>

상단 64px·닫기 24px/탭 영역 24px·좌우 16px/제목 간격 8px, 탭 56px/밑줄 2·1px,
입력행 기본 44px과 자연 높이·붙여넣기 스타일·사진 안내 최소 89px·CTA 56px은 유지합니다.
기존 `TextScaler`와 확대 자동 검사를 유지하며 새 확대 수정·배율별 수동 촬영은 하지 않습니다.
저장·제출 입력 고정·완료 탭·키보드/OS 하단 여백·공개 콜백/API·전역 테마도 유지합니다.
사진 비율/잘림·미리보기 전체 글자/배치·카테고리 편집과 로딩의 별도 디자인은 후속입니다.

<a id="b-41a906168453e829"></a>

```bash
# frontend/ — 이번 집중 검사와 기존 회귀를 실행합니다.
flutter test --no-pub test/save_base_typography_test.dart
flutter test --no-pub test/save_paste_layout_test.dart test/save_footer_layout_test.dart test/save_search_safe_area_test.dart test/save_scaled_layout_test.dart test/saved_content_confirmation_test.dart test/screenshot_asset_test.dart test/screenshot_asset_api_test.dart test/screenshot_auth_test.dart test/content_auto_category_test.dart test/share/manual_save_preservation_test.dart
flutter test --no-pub
flutter analyze --no-pub

# 실제 Simulator/Emulator ID로 실행하고, 제품 수정 후 PHASE를 after로 바꿉니다.
flutter run --no-pub -d <device-id> -t test/support/save_result_preview.dart \
  --dart-define=SAVE_RESULT_PHASE=before
adb -s "$EMULATOR_ID" forward tcp:8768 tcp:8767
curl 'http://127.0.0.1:8768/base-style-scene?kind=empty'
# kind: empty|valid|invalid|photo-empty|photo-selected|link|photo
# iOS는 8767로 접근합니다. 아래 동작 runner는 AFTER에서 1배율만 실행합니다.
curl 'http://127.0.0.1:8768/base-style-run'
```

<a id="b-c111265eec14e5e8"></a>

새 `/base-style-scene`과 `/base-style-run`은 기본 배율 전용입니다.
기존 `/run`·`/paste-run`의 확대 회귀 동작을 삭제하거나 기본값을 바꾸지 않습니다.
정적 장면은 실제 TextField와 `onChanged`로 초안을 고정하고 클립보드에 쓰거나 읽지 않습니다.
AFTER runner에서 모바일 클립보드/붙여넣기를 한 번 별도로 확인합니다.
저장 화면 위젯·메모리 저장 콜백·고정 사진 선택기와 Flutter 합성 입력을 사용하며,
운영 서버·OAuth·AI/OCR·실기기·원격 CI 검증을 뜻하지 않습니다.

<a id="b-dfff9d3070809467"></a>

[동결 프리뷰](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/fixture-manifest.json)의 SHA256은
`11ee1b11b54ee1133d8d3c80b625d9e216f5289d49603f5520eae55e3c3f5e9e`입니다(2026-10-15 14:43:07 UTC 재동결).
프리뷰의 EditableText 계측·탭 테두리 안쪽 중앙 판정·정적 초안 준비를 고친 중간 시도와
Android 시스템 ANR 팝업이 섞인 원본은 `tests`와 `android-gesture/before/.attempts`에 보존하고 정식 비교에서 제외했습니다.
[변경 전 게이트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/before-gate.json)는
14:50:50 UTC에 기준 제품 해시 불변·동결 fixture와 새 OS 원본 14장을 확인한 뒤 통과했습니다.
각 플랫폼의 BEFORE 정적 7개 기록은 프레임워크 오류 0건·`layoutPassed: true`·`stylePassed: false`입니다.
행동은 실행하지 않아 `checksCompleted`·`behaviorPassed`·전체 `passed`는 `false`이며 행동 실패로 분류하지 않습니다.
변경 전·후에 같은 7상태·데이터·1배율·스크롤 맨 위를 사용합니다.
촬영 범위는 iPhone 16/iOS 18.6과 Android 13/API 33의 정적 상태 7장씩, 총 **14쌍**입니다.
BEFORE는 정적 비교 자료이며 행동 완료나 영상 실행을 주장하지 않습니다. AFTER에서만 기본 runner와 플랫폼별 동작 영상을 확인합니다.
Figma 기준은 D01 `912:16502`·D02 `912:16682`·D03 `912:16712`·D06 `912:16524`·D07 `912:16551`·D05 `912:16639`·D09 `912:16602`입니다.
[구현 직전 조회 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/figma/reference-manifest.json)의
2026-10-15 14:32:21~14:32:23 UTC 재조회는 Education(student/Full) 계정을 다시 확인하고 선택했지만 일곱 노드 모두 Starter MCP 호출 한도 응답을 받았습니다.
계획 단계의 D01/D06 조회 성공과 이번 구현 직전 재조회 실패를 구분합니다.
보관한 정확한 컨텍스트/원본 여섯 개를 사용하며 실제 시각은 D01/D02/D03의 컨텍스트 13:33:18 UTC·PNG 13:33:41 UTC,
D05 09:07:32 UTC, D06/D09 08:56:18 UTC입니다. D07은 미확보이므로 14쌍 중 사진 선택 두 쌍의 Figma 원본이 누락됩니다.
최종 비교는 완전한 세 화면 비교 12쌍과 D07 Figma 원본 누락 2쌍으로 구분했습니다.
대체 디자인은 만들지 않으며 과거 작업의 조회/비교 결과를 이번 성공으로 소급하지 않습니다.

<a id="b-c6f30e7b9677586c"></a>

제품 수정 전 [집중 재현](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/tests/base-typography-red.log)은
**28개 중 0개 통과·28개 실패**(12초)입니다. 실제 Pretendard를 로딩한 Dialog에서 역할별 차이를 한 번에 기록했습니다.
상단/입력 제목의 Roboto·색상, 탭의 Roboto·상속 자간 0.25px, URL/파일명/사진 안내/검증의 Roboto,
CTA의 글꼴 미지정·자간 −0.4px·줄 높이 미지정/실측 16px·비활성 노란 글자를 재현했습니다.
기존 기본 높이·간격·텍스트 경계는 실패하지 않았습니다. 스타일 판정 이후의 탭·저장·닫기는 RED 완료 근거에 포함하지 않습니다.
초기 힌트의 상속 높이를 제품의 AUTO 지정으로 오판한 시도는 `tests/base-typography-red-initial-hint-probe.log`로 보존했고,
최종 검사는 제품 `hintStyle.height`를 확인합니다. [검사 파일 단독 분석](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/tests/base-typography-test-analysis.log)은 문제 없음(11.8초)입니다.

<a id="b-eed62cf86a2a6804"></a>

제품 스타일 적용 후 TextField의 필수 `textBaseline` 단언을 확인해 입력 스타일에 `TextBaseline.alphabetic`을 명시했습니다.
첫 시도는 `tests/base-typography-first-textfield-baseline-error.log`에 보존했습니다.
최종 [집중 28개 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/tests/base-typography-green.log)는 모두 통과(3초),
[기존 관련 회귀 335개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/tests/related-green.log)(14초)와
[전체 Flutter 905개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/tests/full-test.log)(47초)도 통과했습니다.
[전체 분석](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/tests/analyze.log)은 문제 없음(3.3초),
[Dart 세 파일 형식 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/tests/format-check.log)는 변경 0건(0.06초)입니다.
위 시간은 도구 로그 기준이며 [실제 명령 종료 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/automatic-checks.json)의
관련/전체/분석/포맷 소요 시간 18.06/50.94/4.27/0.34초와 구분합니다. 모두 종료 코드 0입니다.
[최종 빌드/소스 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/final-implementation.json)은
제품 SHA256 `9be52797870f4df84e56c535584b9eff722001b3a765e03c945a7ef8dacc6f6c`과 동일 fixture/검사 소스를 기록합니다.
AFTER 빌드는 Android 로그 14.1초/명령 16.63초·iOS 로그 22.0초/명령 34.56초로 성공했고 빌드 성공을 실제 실행 완료로 대신하지 않습니다.

<a id="b-82b3a99dbd59762b"></a>

[iOS AFTER](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/ios-after-result.json)와
[Android 제스처 AFTER](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/android-after-result.json)는
각각 새 정적 원본 7장과 보고서 28개 기록(캡처 14개·행동 시나리오 14개)에서 프레임워크 오류 0건,
`checksCompleted`·`behaviorPassed`·`layoutPassed`·`stylePassed`·전체 `passed`가 모두 `true`입니다.
양쪽 정적 7상태의 대상 글자/기하 통과와 OS 팝업 없음을 직접 확인했고, 모바일 클립보드도 플랫폼당 한 번 검증했습니다.

<a id="b-79909a8e18f21330"></a>

| 실행 구성 | 실제 논리 창·DPR | 상단/하단 여백 | IME 표시→해제 |
| --- | --- | --- | --- |
| iPhone 16 / iOS 18.6 Simulator | 393×852·3 | 59/34px | 336→0px |
| Android 13/API 33 제스처 Emulator | 392.7×783.3·2.75 | 24/0px | 274.909→0px |

<a id="b-12e9c83e141f03c6"></a>

AFTER 동작 영상은 [iOS](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/ios/after/interaction.mp4)
15:04:34~15:05:22 UTC와 [Android](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/android-gesture/after/interaction.mp4)
14:59:16~15:00:47 UTC에 촬영했고 두 native 실행 모두 종료 코드 0·실행 오류 0건입니다.
iOS는 앱 종료·Simulator Shutdown·데이터 보존을 확인했고,
[Android 정리 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/android-after-navigation-restored.json)은
원래 mode 2/여섯 탐색 오버레이 일치·설정 변경 0건·앱 종료·포워딩 8768 제거·에뮬레이터 종료/AVD 데이터 보존을 확인했습니다.
스크롤 맨 위에서 링크 결과 카테고리 끝부분은 기존처럼 viewport 밖에 있으며, 최대 스크롤의 마지막 항목 노출은 행동 검사로 확인했습니다.
이 영역 전체 배치를 이번 타이포 맞춤 완료로 포함하지 않습니다.
[14쌍 비교 문서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/comparison-document.html)는
변경 전 → 변경 후 → 해당 Figma 원본 순서이며 [브라우저에서 보기](http://127.0.0.1:8774/comparison-document.html)로도 확인할 수 있습니다.
[비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/comparison-qa.json)와
[전후 상태 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/pair-verification.json)는
조건 불일치 0건·BEFORE 원본 14장 불변·동결 fixture/최종 빌드 소스 일치와 90개 실제 글자 역할의 스타일·최대 줄 수·AUTO/CTA 22px·기존 컨트롤 기하·부모 paint 경계 포함을 확인했습니다.
paragraph 자체를 조금 벗어난 원시 선택 경계는 진단값으로 보존하며 실제 부모의 paint 경계나 말줄임 clip과 구분해 잘림을 판정했습니다.
기본/확대 글자를 임의 축소하거나 원본을 보정하지 않았고 플랫폼 글꼴 파일 식별자를 따로 추출한 증거로 확대하지 않습니다.
[영상 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/media-verification.json)는
AFTER 영상 두 개(iOS 47.100초·Android 89.281878초)의 전체 디코딩 종료 코드 0·오류 로그 0바이트·`allComplete: true`를 확인했습니다. BEFORE 행동/영상은 실행하지 않았습니다.
[브라우저 확인](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/browser-verification.json)은
14개 조건을 실제 선택해 원본 이미지 40개 로딩·D07 누락 안내 2개·양쪽 영상 `readyState: 4`/오류 0건을 확인했습니다.

<a id="b-6a5ac35c752d7511"></a>

이번 완료는 위 저장 화면 1배율 글자·공통 상단과 기존 대역 회귀입니다. D07 원본은 미확보이며 저장 화면 전체 맞춤은 미완료입니다.
Android 3버튼과 확대 배율의 새 기기 촬영은 이번 범위에서 제외했고 기존 확대 자동 검사는 유지했습니다.
이전 877개 검사나 기기 성공을 이번 결과로 사용하지 않으며 실제 서버·OAuth·운영 저장·실기기·원격 CI는 미검증입니다.
사진 비율/잘림·미리보기 전체 배치·카테고리 편집 등 후속 범위는 [계획](../figma-ui-alignment-plan.md#디자인-확인-필요)과 [진행 기록](../fe-merge-fixes.md)을 따릅니다.
새 증거 루트는 `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography`입니다.
화면 증거·빌드 생성물·로컬 `AGENTS.md`는 Git에서 제외하며 푸시·PR은 하지 않습니다.

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-d68cd56fa60077c8"></a>

### 2026-10-15 — 저장 화면 1배율 글자·공통 상단 (해당 범위 적용·검증 완료)

<a id="b-40aacdb5619136ce"></a>

- 기준은 `a54c387`이며 기존 미커밋 정책 문서의 **1배율 Figma 맞춤 우선** 결정을 보존한다. 이번에는 저장 화면 내부의 제목/닫기·링크/사진 탭·입력/결과의 ‘저장할 링크/사진’·URL/파일명·사진 선택 안내·링크 검증·하단 버튼을 맞춘다.
  저장 전용 스타일에 Pretendard와 확정된 굵기·자간·색상을 명시한다. 상단/입력 제목은 검정 `#000000`, 탭 자간은 −0.4px, CTA는 16px/SemiBold·줄 높이 22px·자간 0px·활성 노랑/비활성 흰 글자 기준이다. 나머지는 새 고정 줄 높이를 만들지 않는 AUTO 기준이다.
  상단 64px·닫기 아이콘/탭 영역 24px·좌우 16px/제목 간격 8px·탭 56px/밑줄 2·1px, 입력행 기본 44px과 자연 높이·붙여넣기 스타일·사진 안내 최소 89px·CTA 56px을 유지한다.
  전역 테마·공개 생성자/콜백/API·저장 시점·제출 입력 고정·완료 탭·키보드/하단 안전 영역은 변경하지 않는다. 기존 시스템 글자 배율과 확대 자동 검사를 유지하고 새 확대 수정·배율별 수동 촬영은 후속으로 둔다. 사진 비율/잘림·결과 미리보기 전체 타이포/배치·카테고리 편집·로딩 전용 디자인도 보류한다.
- 제품 수정 전 실제 Pretendard Regular/Medium/SemiBold를 로딩하고 실제 저장 Dialog를 사용하는 `save_base_typography_test.dart`를 추가했다. iOS/Android × 폭 320/375px × 빈 링크·유효·무효·사진 미선택·사진 선택·링크 결과·사진 결과 7상태, 총 28개 시나리오다.
  [최종 RED 로그](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/tests/base-typography-red.log)는 **0개 통과·28개 실패**(12초·종료 코드 1)다. 상단/입력 제목의 Roboto/색상, 탭 Roboto/상속 자간 0.25px, URL/파일명/사진 안내/검증의 Roboto와 CTA의 글꼴 미지정·자간 −0.4px·줄 높이 미지정/실측 16px·비활성 노란 글자를 역할별로 누적 확인했다.
  기존 기본 높이·간격·글자 경계는 실패하지 않았다. 스타일 판정 이후 실행되는 탭·저장·닫기 회귀는 이 RED 단계의 실행 완료로 주장하지 않는다.
  초기 InputDecorator 힌트의 상속 1.5 줄 높이를 제품 AUTO 지정으로 오판한 시도는 `tests/base-typography-red-initial-hint-probe.log`로 보존했다. 최종 검사는 제품의 `hintStyle.height`만 AUTO로 검사하며 CTA만 22/16을 명시 검증한다.
  [집중 검사 파일 단독 분석](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/tests/base-typography-test-analysis.log)은 문제 없음(11.8초)이고 전체 앱 분석 완료로 보고하지 않는다.
- 프리뷰의 EditableText 계측·탭 테두리 안쪽 중앙 판정·정적 초안 준비를 수정한 중간 시도와 Android 시스템 ANR 팝업이 섞인 캡처는 `tests`와 `android-gesture/before/.attempts`에 보존하고 정식 비교에서 제외했다. 이 준비 과정 동안 기준 제품 SHA256 `2b792fc4d1447d21f9129e32c27509a1cb213a7199b714f07b10b0c5d16aac91`은 유지했다.
  [최종 프리뷰 manifest](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/fixture-manifest.json)는 **2026-10-15 14:43:07 UTC**에 SHA256 `11ee1b11b54ee1133d8d3c80b625d9e216f5289d49603f5520eae55e3c3f5e9e`로 동결했다. 변경 전·후 동일 소스와 고정 데이터·1배율·스크롤 맨 위를 사용한다.
  [변경 전 게이트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/before-gate.json)는 **14:50:50 UTC**에 기준 제품 불변·동결 fixture·양 플랫폼의 새 OS 원본 14장을 확인한 뒤 통과했다. 두 플랫폼의 정식 원본은 직접 시각 확인했다.
  BEFORE는 플랫폼당 정적 7개 기록·프레임워크 오류 0건·`layoutPassed: true`·`stylePassed: false`다. 행동을 실행하지 않아 `checksCompleted`·`behaviorPassed`·전체 `passed`는 `false`이며 행동 실패로 분류하지 않는다.
  `/base-style-scene?kind=empty|valid|invalid|photo-empty|photo-selected|link|photo`는 7개 정적 상태, `/base-style-run`은 1배율 동작을 제공한다. 기존 `/run`·`/paste-run`의 확대 회귀 경로는 유지한다.
  BEFORE는 두 플랫폼의 새 정적 7장씩을 대상으로 하고 행동 완료나 영상 실행을 주장하지 않는다. AFTER는 같은 정적 7장씩과 기본 runner·플랫폼별 동작 영상을 확인한다. 정적 초안은 실제 TextField/`onChanged`로 고정하고 클립보드를 쓰거나 읽지 않으며 AFTER runner에서 모바일 클립보드를 한 번 따로 확인한다. 저장 위젯·Flutter 합성 입력·메모리 저장/사진 선택 대역이며 실제 OAuth·운영 서버·AI/OCR·실기기·원격 CI와 구분한다.
- 기준 Figma는 최신 261008의 D01 `912:16502`·D02 `912:16682`·D03 `912:16712`·D06 `912:16524`·D07 `912:16551`·D05 `912:16639`·D09 `912:16602`이다. [구현 직전 재조회](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/figma/reference-manifest.json)는 **2026-10-15 14:32:21~14:32:23 UTC**에 일곱 노드 모두 Starter MCP 호출 한도 응답을 받았다. Education(student/Full) 계정 선택/연결 상태를 재확인했으며 계획 단계 D01/D06의 조회 성공과 이번 구현 직전 실패를 혼동하지 않는다.
  정확한 보관 컨텍스트/PNG 여섯 개를 fallback으로 사용한다. 실제 보관 조회 시각은 D01/D02/D03 컨텍스트 13:33:18 UTC·PNG 13:33:41 UTC, D05 09:07:32 UTC, D06/D09 08:56:18 UTC다. 앱 BEFORE 원본은 현재 기준 커밋에서 새로 촬영하며 과거 앱 화면은 재사용하지 않는다.
  두 플랫폼 × 7상태의 **14쌍**을 변경 전 → 변경 후 → 해당 원본 순서로 제공한다. D07 원본/컨텍스트는 미확보이므로 사진 선택 상태 두 비교의 Figma 누락을 명시하고 대체 이미지를 만들지 않았다. 최종 비교는 완전한 세 화면 비교 12쌍과 Figma 누락 2쌍으로 구분한다. 과거 작업의 조회 성공·14/18/24쌍 비교 결과는 소급 변경하지 않는다.
  제품 적용 후 첫 집중 검사에서 TextField의 필수 `textBaseline` 단언을 확인했고 입력 스타일에 `TextBaseline.alphabetic`을 명시했다. 첫 실패는 `tests/base-typography-first-textfield-baseline-error.log`에 보존했다. 최종 [집중 28개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/tests/base-typography-green.log)는 모두 통과(3초)했다.
  [기존 관련 회귀 335개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/tests/related-green.log)는 통과(로그 14초·명령 18.06초)했고 [전체 Flutter 905개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/tests/full-test.log)도 통과(로그 47초·명령 50.94초)했다.
  [전체 분석](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/tests/analyze.log)은 문제 없음(로그 3.3초·명령 4.27초), [세 파일 형식 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/tests/format-check.log)는 변경 0건(로그 0.06초·명령 0.34초)이다. [실제 종료 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/automatic-checks.json)은 네 명령 모두 종료 코드 0을 기록했다.
  [최종 구현 manifest](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/final-implementation.json)는 제품 SHA256 `9be52797870f4df84e56c535584b9eff722001b3a765e03c945a7ef8dacc6f6c`·동결 fixture·검사와 빌드 소스를 기록한다. AFTER Android/iOS 빌드는 각각 로그 14.1/22.0초·명령 16.63/34.56초로 성공했다. 빌드 성공을 기기 실행 완료로 대신하지 않는다.
  [iOS AFTER](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/ios-after-result.json)와 [Android 제스처 AFTER](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/android-after-result.json)는 각각 새 정적 OS 원본 7장·28개 기록(캡처 14개·행동 시나리오 14개)·프레임워크 오류 0건이고 `checksCompleted`·`behaviorPassed`·`layoutPassed`·`stylePassed`·전체 `passed`가 모두 `true`다. 양쪽 정적 7개 모두 대상 글자/기하 통과와 OS 팝업 없음을 직접 확인했다.
  iPhone 16/iOS 18.6은 393×852·DPR 3·상하 여백 59/34px·IME 336→0px이고 Android 13/API 33 제스처는 392.7×783.3·DPR 2.75·24/0px·IME 274.909→0px이다. 모바일 Clipboard는 각 플랫폼 1건 검증했다.
  [iOS AFTER 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/ios/after/interaction.mp4)은 15:04:34~15:05:22 UTC·7,452,628바이트, [Android AFTER 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/android-gesture/after/interaction.mp4)은 14:59:16~15:00:47 UTC·4,742,691바이트다. 두 native 세션 모두 종료 코드 0·실행 오류 0건이며 검사/촬영은 2026-10-15~16 KST에 걸쳐 수행했다.
  iOS는 앱 종료·Simulator Shutdown·데이터 보존을 확인했다. [Android 정리 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/android-after-navigation-restored.json)은 원래 mode 2/여섯 탐색 오버레이의 `matchesOriginal: true`, 설정 변경 0건·앱 종료·8768 포워딩 제거·에뮬레이터 종료/AVD 데이터 보존을 확인했다.
  [iOS 원본 시각 확인](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/ios-after-visual-review.json)은 정적 7장·팝업 0건·대상 글자 잘림 없음을 확인했다. 스크롤 0의 링크 결과 카테고리 끝부분은 기존 viewport 밖이며 최대 스크롤 시 마지막 항목 노출은 별도 행동 검사로 확인한다. 이 전체 본문 배치를 이번 완료 범위에 포함하지 않는다.
  [14쌍 최종 비교](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/comparison-document.html)와 [브라우저](http://127.0.0.1:8774/comparison-document.html)를 제공한다. [비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/comparison-qa.json)·[전후 상태 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/pair-verification.json)는 조건 불일치 0건·BEFORE 원본 14장 불변·동결 fixture/최종 빌드 소스 일치·실제 90개 글자 역할의 스타일/최대 줄 수/AUTO/CTA 22px·기존 컨트롤 기하·부모 paint 경계 포함을 확인했다.
  원시 선택 경계가 paragraph 자체를 조금 벗어나는 값은 진단으로 보존했다. 실제 부모의 paint 경계와 말줄임 clip에 따라 잘림을 판정하며 그 자체를 넘침으로 오판하거나 수치/원본을 보정하지 않았다. 네이티브 글꼴 파일 식별자를 별도로 추출한 증거로 확대하지 않는다.
  [영상 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/media-verification.json)는 AFTER 두 영상(iOS 47.100초·Android 89.281878초)의 전체 디코딩 종료 코드 0·오류 로그 0바이트·`allComplete: true`를 확인했다. BEFORE 행동/영상은 실행하지 않았다.
  [브라우저 실행 확인](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/browser-verification.json)은 실제 14개 조건 선택·원본 이미지 40개 로딩·D07 누락 안내 2건·플랫폼별 영상 `readyState: 4`/오류 0건과 기본 iOS/빈 입력 상태 복귀를 확인했다.
  이번 완료는 저장 화면 1배율 글자·공통 상단과 기존 대역 회귀이며 전체 저장 화면 맞춤은 미완료다. D07 원본 미확보와 사진 비율/잘림·미리보기 전체 배치·카테고리 편집 등 후속 범위를 유지한다. Android 3버튼/확대 배율의 새 수동 촬영은 이번 범위에서 제외했고 기존 확대 자동 회귀는 유지했다. 이전 877개 검사나 기기 성공을 이번 결과로 사용하지 않으며 실제 서버·OAuth·운영 저장·실기기·원격 CI는 미검증이다.
  증거 루트는 `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography`이고 재현 명령은 [프론트 README](../../frontend/README.md)의 이번 절을 따른다.
  최종 diff·문서 링크·공백을 확인한 뒤 같은 `feature/figma-ui-alignment` 브랜치에서 한 커밋으로 저장한다. 화면 증거·빌드 생성물·`AGENTS.md`는 제외하고 푸시·PR은 하지 않는다.

## 원문 출처: docs/figma-ui-alignment-plan.md

<a id="b-98cfd6b3ac927fa7"></a>

### 저장 화면의 1배율 글자·공통 상단 (2026-10-15 시작)

<a id="b-1215f85871482303"></a>

- 기준은 `a54c387`이며 현재 사용자 결정인 1배율 우선 범위를 적용한다. 저장 화면 내부의 역할별 Pretendard만 명시하고 전역 테마·공통 헤더·다른 화면은 바꾸지 않는다. 기존 붙여넣기 스타일·AUTO 행간·확대 구현과 자동 검사는 유지한다.
- 대상은 상단 제목(18/SemiBold/−0.45/검정), 탭(16/선택 SemiBold·미선택 Medium/−0.4), 입력·결과의 ‘저장할 링크/사진’ 제목(16/SemiBold/−0.4/검정), URL·파일명(14/Medium/−0.35), 사진 선택 제목(15/SemiBold/−0.375)·안내/검증(14/Medium/−0.35), 저장·닫기 버튼(16/SemiBold/행간22/자간0)이다. 버튼은 활성/닫기 노랑·비활성 흰 글자로 맞춘다.
- 헤더 64px·좌우 16px·닫기 24px·제목 간격 8px, 탭 56px·밑줄 2/1px과 기존 입력/버튼/본문·OS 안전 영역을 유지한다. 탭 글자는 테두리를 제외한 실제 내부 영역에서 중앙에 놓이며 바 전체 중심에서 선택 −1px·미선택 −0.5px이 기존 정상 배치다.
- 사진 비율/잘림·결과 미리보기·카테고리·결과 상단 80px·API/저장 정책·공개 생성자/콜백은 제외한다. 로딩 문구·스피너·동작과 요청 중 탭 전환·제출 입력 보존·완료 탭 고정·재시도·닫기도 유지한다.
- 실제 Pretendard를 로드한 7상태×iOS/Android×폭320/375의 집중 재현은 제품 수정 전 28개 모두 실패(12초)했다. 상속 글꼴·탭 자간·제목 색·버튼 자간/행간/비활성 색의 차이를 누적 기록했으며 기본 높이·간격·경계의 제품 실패는 없었다. 최초 힌트 상속 높이 오판 시도는 별도 보존하고 최종 재현과 구분한다.
- 기기 프리뷰는 1배율 전용 7상태와 행동 실행을 추가했다. EditableText wrapper·탭 내부 중심의 계측 오류와 정적 클립보드 준비 의존을 바로잡고 정식 원본 전에 재동결했으며, 최종 fixture SHA256은 `11ee1b11b54ee1133d8d3c80b625d9e216f5289d49603f5520eae55e3c3f5e9e`다. 정적 비교는 실제 TextField/onChanged 고정 입력으로 준비하고 실제 모바일 클립보드는 AFTER 행동에서 한 번 별도로 검사한다. 기존 확대 실행 경로와 자동 회귀는 보존한다.
- 이번 구현 재조회는 2026-10-15 14:32:21~14:32:23 UTC에 D01/D02/D03/D06/D07/D05/D09 모두 Starter MCP 한도 응답을 받았다. Education 연결의 student/Full은 다시 확인했고 이를 재조회 성공으로 바꾸지 않는다. 계획 단계의 D01/D06 조회 성공과 이번 재조회 실패도 구분한다.
- 보관된 정확한 원본·컨텍스트 6개를 실제 조회 시각으로 사용한다. D01/D02/D03은 13:33:18 UTC 컨텍스트·13:33:41 UTC 원본, D05는 09:07:32 UTC, D06/D09는 08:56:18 UTC다. D07 원본은 없으며 다른 상태로 대체하지 않는다. 비교는 7상태×두 플랫폼 14쌍이며, 그중 12쌍의 실제 Figma 3열과 D07 두 쌍의 미확보를 구분한다.
- 변경 전은 양 플랫폼의 새 정적 원본 7장씩만 확보하고 행동/영상 완료를 주장하지 않는다. AFTER는 같은 상태를 새로 촬영하고 1배율 행동·플랫폼별 영상을 확인한다. Android 제스처만 사용하고 3버튼 추가 촬영·확대 배율 촬영은 제외한다. Android OS ANR 팝업이 겹친 최초 원본은 별도 보존하고 완료 근거에서 제외한다.
- 제품 적용 후 실제 TextField가 요구하는 alphabetic baseline을 명시해 첫 단언 실패를 수정했다. 최종 집중 검사는 28개(3초), 관련 회귀는 335개(로그 14초/명령 18.06초), 전체 `flutter test --no-pub`는 905개(로그 47초/명령 50.94초) 통과했다. `flutter analyze --no-pub`는 문제 없음(로그 3.3초/명령 4.27초), 변경한 Dart 3파일의 포맷 검사는 변경 0건이다. 기존 확대 검사는 유지한 채 실행했다.
- 최종 AFTER 빌드는 Android Gradle 14.1초(명령 16.63초), iOS Xcode 22.0초(명령 34.56초)로 성공했다. [자동 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/automatic-checks.json)와 [소스·빌드 해시](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/final-implementation.json)를 남겼다.
- iPhone 16/iOS 18.6과 Android 13/API 33 제스처에서 AFTER 원본 각 7장을 확보하고 직접 검토했다. 플랫폼마다 정적 캡처 14개와 행동 14개, 총 28개 보고서 기록에서 프레임워크 오류 0건·`stylePassed`/`layoutPassed`/`behaviorPassed`/`checksCompleted`/전체 `passed: true`다. 실제 모바일 클립보드 1회씩과 탭 전환·입력/컨트롤러 보존·사진 재선택·키보드·실패/재시도·최대 스크롤·완료 탭 고정·중복 방지·닫기/늦은 응답을 확인했다.
- 실제 iOS 창은 393×852px/DPR3/상단59·하단34px이고 Android 창은 약392.7×783.3px/DPR2.75/상단24·하단0px다. 키보드는 iOS336px·Android274.909px에서 0으로 복귀했다. 375×812px인 Figma와 OS 창·안전 영역이 달라 원본을 보정하지 않는다. Android 원래 탐색 모드2와 navbar overlay6개가 완전히 일치하며 설정 변경은 0건이다. 두 앱·가상 기기를 종료하고 데이터를 보존했으며 Android forward8768도 제거했다.
- 동작 영상은 Android14:59:16~15:00:47 UTC(4,742,691bytes), iOS15:04:34~15:05:22 UTC(7,452,628bytes)로 플랫폼당 1개다. 기록·종료는 정상이며 H.264 전체 디코딩 오류는 0건이다. 실제 길이는 iOS47.100초·Android89.281878초다.
- [전체 14쌍 비교](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/comparison-document.html)와 [로컬 비교 페이지](http://127.0.0.1:8774/comparison-document.html)를 제공한다. [비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/comparison-qa.json)·[스타일/경계 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/pair-verification.json)는 조건 불일치0건, 변경 전 원본14장 불변, 동결 fixture/최종 빌드 소스 일치와 실제 역할90개 검사를 통과했다. 전체 비교는 Figma 포함12쌍/D07미확보2쌍이며 대체 디자인은 없다.
- 선택 상자가 논리적 문단 위로 조금 나오는 글꼴 진단 값은 원시 수치로 보존하고 실제 부모의 paint/clip 경계로 잘림을 판정했다. 허용오차와 기대 스타일·최대 줄 수를 완화하지 않았다. [영상 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/media-verification.json)는 AFTER 영상2개 전체 디코딩을 통과했고, [브라우저 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/browser-verification.json)는 실제 선택14건·원본 이미지40개 로드·두 플랫폼 영상 준비와 미확보 표시를 확인했다.
- iOS 링크 결과의 마지막 카테고리 안내는 스크롤0에서 기존 본문 viewport 끝에 일부 가려지며 최대 스크롤에서 노출됨을 별도로 확인했다. 수정한 글자·상단/탭·버튼의 잘림/겹침과 범위 밖 결과·카테고리 영역을 구분한다. 사진 비율/잘림·결과 미리보기·카테고리·상단80px과 저장 화면 전체 맞춤은 계속 보류한다.
- 증거 루트는 `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography`다. 대역 데이터 기기 실행과 실제 서버·인증·실기기·CI 검증을 구분하며 저장 화면 전체 맞춤 완료로 표시하지 않는다.
