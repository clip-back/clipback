# 저장 결과 미리보기 글자

- 최초 기록일: 2026-10-16
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-549792ba1f453bc7"></a>

### 저장 결과 미리보기 1배율 글자 (`b082db8` 기준, 해당 범위 적용·검증 완료)

<a id="b-5cec4ae46505a5c8"></a>

이번에는 최신 `261008`의 링크 결과 D05(`912:16639`)·사진 결과 D09(`912:16602`)에서
**‘미리보기’ 제목·콘텐츠 제목·출처** 세 역할만 저장 화면 전용 Pretendard에 맞춥니다.
미리보기 제목은 16px/SemiBold·자간 −0.4px·검정/AUTO, 콘텐츠 제목은 15px/Medium·−0.375px·검정/행간 1.6,
출처는 14px/Regular·−0.35px·`#767676`/행간 1.6 기준입니다.
카드 최소 116px·패딩 8px·이미지 164×100px·이미지/글자 간격 16px·제목/출처 간격 8px과 세로 중앙 정렬·자연 높이를 유지합니다.
제목 최대 두 줄·출처 한 줄의 말줄임과 기존 글자 배율도 유지합니다.
상단/탭·‘저장할’ 제목·제출 URL/파일명·검증·버튼·키보드/안전 영역·저장 정책·전역 테마는 변경하지 않습니다.
사진 비율/잘림·고정 링크 썸네일·카테고리 편집·결과 상단 80px과 전체 저장 화면 맞춤은 후속입니다.

<a id="b-291b734d5e49140e"></a>

```bash
# frontend/ — 집중 검사와 관련 회귀 일부의 재현 예시입니다. 전체 검사도 실행합니다.
flutter test --no-pub test/save_base_typography_test.dart
flutter test --no-pub test/save_scaled_layout_test.dart test/saved_content_confirmation_test.dart test/save_footer_layout_test.dart
flutter test --no-pub
flutter analyze --no-pub

# 제품 수정 전에는 before, 수정 후 같은 기기/데이터로 after를 실행합니다.
flutter run --no-pub -d <device-id> -t test/support/save_result_preview.dart \
  --dart-define=SAVE_RESULT_PHASE=before
adb -s "$EMULATOR_ID" forward tcp:8768 tcp:8767
curl 'http://127.0.0.1:8768/base-style-scene?kind=link'
curl 'http://127.0.0.1:8768/base-style-scene?kind=photo'
# iOS는 8767로 접근합니다. after 앱에서 결과만 확인하는 기본 배율 runner를 호출합니다.
curl 'http://127.0.0.1:8768/base-style-run?resultsOnly=1'
```

<a id="b-640ee092b9bd71c8"></a>

기존 Dialog·폰트/이미지 에셋·프리뷰를 재사용하며 `/base-style-run?resultsOnly=1`은 결과의 탭 고정·스크롤·닫기와 추가 저장 없음을 확인합니다.
기존 전체 `/base-style-run`·`/run`·`/paste-run`의 동작은 보존합니다.
새 기기 비교는 iPhone 16/iOS 18.6과 Android 13/API 33 제스처의 링크/사진 결과 1배율·키보드 없음·스크롤 맨 위,
총 **4쌍**을 확인했습니다. BEFORE는 새 정적 원본만, AFTER는 같은 정적 원본과 플랫폼별 동작 영상 두 개를 확보했습니다.
Android 3버튼·확대 배율 반복 촬영은 제외하고 기존 확대 자동 회귀 검사는 유지합니다.

<a id="b-065868f9e5a13639"></a>

[Figma 원본 출처](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/figma/reference-manifest.json)는
보관된 정확한 D05 컨텍스트/PNG **2026-10-15 09:07:32 UTC**, D09 **08:56:18 UTC**를 사용합니다.
출처 원본은 [D05](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-scaled-layout/figma/D05-implementation.png)·[D09](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-scaled-layout/figma/D09-implementation.png)이며
이번 작업은 **16:42:41 UTC**에 보관 원본과 해시/조회 시각을 대조했습니다. 이를 새 Figma 조회 성공으로 보고하지 않습니다.
[구현 직전 재조회](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/figma/implementation-refresh.json)는
**2026-10-15 16:48:38~16:48:39 UTC**에 두 노드 모두 Starter MCP 호출 한도 응답을 받았습니다. 승인된 fallback에 따라 위 보관 원본을 실제 조회 시각 그대로 사용합니다.

<a id="b-e4fa713388cca9f2"></a>

[동결 프리뷰](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/fixture-manifest.json)는
**2026-10-15 16:46:28 UTC**에 fixture SHA256 `e8111186e355ed8a9147fb277c334d9fb2c4d328835fd6ebc76b4ba28363888c`를 기록했습니다.
제품 수정 전 [집중 RED](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/tests/base-typography-red.log)는
**36개 중 20개 통과·16개 실패**(로그 4초/명령 7.19초)로 새 결과 역할의 Roboto 상속·제목 색상·출처 행간 1.43을 재현했습니다.
기존 28조합의 결과 8조합과 긴 제목/출처 결과 8조합에서 차이를 확인했고 나머지 20조합은 통과했습니다.
[준비 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/preparation-checks.json)의
검사/프리뷰 두 파일 분석은 문제 없음(로그 1.4초/명령 2.37초), 형식 검사는 변경 0건(로그 0.05초/명령 0.37초)입니다.
초기 중괄호 린트 1건을 수정하기 전 시도는 `tests/initial-lint-attempt`에 보존했습니다.
[BEFORE 빌드](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/before-build.json)는
Android 로그 22.5초/명령 25.52초·iOS 로그 34.9초/명령 69.3초로 성공했습니다.
빌드 성공을 실행·화면 비교 완료로 대신하지 않습니다.

<a id="b-baf8f9e6e55edf2c"></a>

[iOS BEFORE](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/ios-before-result.json)와
[Android BEFORE](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/android-before-driver-result.json)의
새 정적 원본은 각각 2장, 총 4장이며 직접 시각 확인에서 팝업 0건·프레임워크 오류 0건·`layoutPassed: true`·`stylePassed: false`였습니다.
BEFORE 행동/영상은 실행하지 않았고 두 가상 기기의 앱 종료·정리와 데이터 보존을 확인했습니다.
[변경 전 게이트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/before-gate.json)가
**16:52:33 UTC**에 원본 4장·동결 fixture·제품 해시 불변을 확인한 뒤 통과했고, [제품 수정 시작](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/product-edit-start.json)은 **16:53:01 UTC**에 기록했습니다.
세 역할만 적용한 후 [집중 검사 36개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/tests/base-typography-green.log)는
모두 통과했습니다(로그 4초/명령 6.79초). 제품 한 파일의 형식 검사는 변경 0건(로그 0.03초/명령 0.42초)입니다.

<a id="b-33039d44ab632d45"></a>

[기존 관련 회귀 335개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/tests/related-green.log)는
통과(로그 19초/명령 22.32초)했고 [전체 Flutter 913개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/tests/full-test.log)도 통과했습니다(로그 55초/명령 58.98초).
[전체 분석](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/tests/analyze.log)은 문제 없음(로그 3.6초/명령 4.61초),
[Dart 세 파일 형식 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/tests/format-check.log)는 변경 0건(로그 0.07초/명령 0.41초)입니다.
[실제 명령 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/automatic-checks.json)은 위 자동 검사 모두 종료 코드 0을 확인했습니다.
[최종 AFTER 소스/빌드](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/final-implementation.json)는
제품 SHA256 `9022a734d31d21980060498a312f286fa788649de37b42ba67061904372ffbf3`와 동일한 동결 fixture/검사 소스를 기록합니다.
AFTER 빌드는 Android 로그 15.4초/명령 17.93초·iOS 로그 23.5초/명령 37.06초로 종료 코드 0이며, 빌드 성공과 기기 실행 완료를 구분합니다.
[iOS AFTER](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/ios-after-result.json)와
[Android AFTER](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/android-after-driver-result.json)는
각각 새 OS 원본 2장·보고서 10개 기록(캡처 4개·행동 6개)·프레임워크 오류 0건이며
`stylePassed`·`layoutPassed`·`behaviorPassed`·`checksCompleted`·전체 `passed`가 모두 `true`입니다.

<a id="b-2bc30a82721b093b"></a>

| 실행 구성 | 논리 창·DPR | 상단/하단 여백 | 링크 최대 스크롤 | 사진 최대 스크롤 |
| --- | --- | --- | --- | --- |
| iPhone 16 / iOS 18.6 Simulator | 393×852·3 | 59/34px | 22px | 0px |
| Android 13/API 33 제스처 Emulator | 392.7×783.3·2.75 | 24/0px | 약 21.727px | 0px |

<a id="b-69478e4c22499312"></a>

링크 결과의 최대 스크롤/마지막 항목 노출, 완료 탭 고정·추가 저장 없는 닫기를 확인했습니다.
사진 결과는 스크롤이 불필요하므로 실제 드래그 성공으로 보고하지 않습니다. 이번 기기 동작은 결과 두 상태이며 키보드/클립보드·확대 배율의 새 기기 검증은 포함하지 않습니다.
양쪽 ‘미리보기’ 제목의 문단 높이는 23→19px이고 카드/이미지는 자연 본문 흐름으로 4px 위로 이동했습니다. 위치 보정값은 추가하지 않았습니다.
출처는 실효 `height: 1.6`과 문단 실측 22px을 구분하며 계산상 22.4px을 고정 높이로 강제하지 않습니다.
AFTER 영상은 [iOS](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/ios/after/interaction.mp4)
17:00:29~17:00:41 UTC·2,128,724바이트, [Android](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/android-gesture/after/interaction.mp4)
16:57:54~16:58:14 UTC·1,208,741바이트이며 두 native 실행은 정상 종료했습니다.
iOS 앱 종료·Simulator Shutdown·데이터 보존과 [Android 정리](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/android-after-navigation-restored.json)의
원래 mode 2/여섯 오버레이 일치·설정 변경 0건·앱/에뮬레이터 종료·8768 포워딩 제거/데이터 보존을 확인했습니다.
[iOS 원본 시각 확인](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/ios-after-visual-review.json)은
새 원본 2장·팝업 0건·대상 글자 잘림/겹침 없음을 확인했습니다.
[최종 4쌍 비교](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/comparison-document.html)는
모두 변경 전 → 변경 후 → 실제 D05/D09 원본을 제공합니다. [브라우저에서 보기](http://127.0.0.1:8775/comparison-document.html)로도 확인할 수 있습니다.
[비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/comparison-qa.json)·[전후 상태 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/pair-verification.json)는
Figma 누락/조건 불일치 0건·BEFORE 원본 4장 불변·최종 빌드 소스/동결 fixture 일치·12개 미리보기 역할의 실효 스타일/행간·부모 안의 문단 경계와 기존 기하 상수/공통 스타일 보존을 확인했습니다.
원시 선택 상자는 글꼴 선택 경계의 진단값으로 보존하며 실제 글자 잉크/paint 경계나 잘림으로 단정하지 않습니다.
[최종 실측 요약](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/final-evidence-summary.json)은
제목/카드의 자연 이동 −4px과 출처 행간 1.6/문단 실측 22px을 구분합니다.
[영상 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/media-verification.json)는
이번 새 AFTER 영상 두 개(iOS 10.8초·Android 18.048989초)의 전체 디코딩 종료 코드 0·오류 로그 0바이트를 확인했습니다.
최종 재확인은 같은 작업 영상의 동일 SHA에 해당하는 성공 결과를 재사용한 것이며 이전 작업 영상을 대신 사용한 것이 아닙니다. BEFORE 행동/영상은 실행하지 않았습니다.
[브라우저 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/browser-verification.json)는
네 조건의 실제 선택·원본 12개 로딩·양 영상 `readyState: 4`/오류 0건·iOS/링크 기본 상태 복귀를 확인했습니다.

<a id="b-83c6512d86fbb0b9"></a>

이번 완료는 저장 결과 미리보기 세 역할의 1배율 글자와 기존 회귀입니다. 사진 비율/잘림·고정 링크 썸네일·결과 전체 배치·카테고리 편집·결과 상단 80px은 후속이며 저장 화면 전체 맞춤은 미완료입니다.
API·저장 정책은 이번 변경 범위에서 제외했고 기존 연결을 유지합니다. 이전 905개 검사나 과거 28개 기기 기록을 이번 검증에 재사용하지 않습니다.
증거 루트는 `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography`입니다.
실제 저장 위젯·고정 사진 선택기/메모리 저장 콜백·Flutter 합성 입력을 사용하며 운영 서버·OAuth·실기기·원격 CI는 검증 범위 밖입니다.
화면 증거·빌드 생성물·로컬 `AGENTS.md`는 Git에서 제외하고 푸시·PR은 하지 않습니다.

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-286748ed6c5c1ce9"></a>

### 2026-10-16 — 저장 결과 미리보기 1배율 글자 (해당 범위 적용·검증 완료)

<a id="b-405812b0b8cb0afd"></a>

- 기준은 `b082db8`이며 이번 대상은 최신 261008의 링크 결과 D05 `912:16639`·사진 결과 D09 `912:16602` 안의 ‘미리보기’ 제목·콘텐츠 제목·출처 세 역할이다. 미리보기 제목은 Pretendard 16/SemiBold/−0.4px/검정/AUTO, 콘텐츠 제목은 15/Medium/−0.375px/검정/행간 1.6, 출처는 14/Regular/−0.35px/`#767676`/행간 1.6으로 맞춘다.
  카드 최소 116px·패딩 8px·이미지 164×100px·이미지/글자 간격 16px·제목/출처 간격 8px·세로 중앙 정렬·자연 높이, 제목 최대 두 줄/출처 한 줄 말줄임과 글자 배율을 유지한다. 상단/탭·‘저장할’ 제목·URL/파일명·검증/CTA·키보드/OS 하단 여백·전역 테마·공개 API·저장 시점/제출 입력/완료 탭 정책은 변경하지 않는다.
  사진 비율/잘림·고정 링크 썸네일·카테고리 편집·결과 상단 80px과 전체 저장 화면 맞춤은 후속이다. 새 확대 대응/배율별 수동 촬영은 하지 않고 기존 확대 자동 회귀를 유지한다.
- 기존 `save_base_typography_test.dart`와 실제 Pretendard 세 굵기의 Dialog harness를 확장했다. 기존 iOS/Android × 폭 320/375 × 7상태 28개를 보존하고 결과 8조합에서 세 역할과 카드 기하를 검사한다. 명확한 한 줄 제목과 두 줄/한 줄로 말줄임되는 긴 제목/출처의 결과 8조합을 더해 총 36개다. 행간 1.6은 실효 TextStyle로 확인하고 글자 경계/실측 높이는 별도로 검사한다.
  [최종 RED](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/tests/base-typography-red.log)는 **20개 통과·16개 실패**(로그 4초/명령 7.19초·종료 코드 1)다. 새 결과 역할의 Roboto 상속·제목 색상·출처 행간 1.43을 재현했으며 기존 결과 8개와 긴 문구 결과 8개가 실패했다. 나머지 20개는 통과했고 기하 실패로 분류하지 않는다.
  첫 시도의 중괄호 린트 1건은 수정 후 `tests/initial-lint-attempt`에 보존했다. [준비 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/preparation-checks.json)는 검사/프리뷰 두 파일 분석 문제 없음(로그 1.4초/명령 2.37초)·형식 변경 0건(로그 0.05초/명령 0.37초)을 기록한다. 단독 준비 분석을 전체 앱 분석 완료로 보고하지 않는다.
- [Figma 출처 manifest](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/figma/reference-manifest.json)는 정확한 보관 원본/컨텍스트를 사용한다. 실제 조회 시각은 D05 **2026-10-15 09:07:32 UTC**, D09 **08:56:18 UTC**이며 출처 원본 [D05](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-scaled-layout/figma/D05-implementation.png)·[D09](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-scaled-layout/figma/D09-implementation.png)의 해시를 보존했다.
  이번 보관 자료의 해시/조회 시각 대조는 **16:42:41 UTC**에 수행했으며 새 Figma 조회 성공으로 취급하지 않는다. [이번 구현 직전 재조회](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/figma/implementation-refresh.json)는 **2026-10-15 16:48:38~16:48:39 UTC**에 D05/D09 모두 Starter MCP 호출 한도 응답을 받았다. 계정 진단은 별도로 보존하고 개인 정보는 문서에 싣지 않는다. 승인된 fallback으로 정확한 보관 원본의 기존 조회 시각/해시를 사용하며 이전 앱 화면을 새 BEFORE로 사용하지 않는다.
- [프리뷰 manifest](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/fixture-manifest.json)는 **2026-10-15 16:46:28 UTC**에 제품 SHA256 `9be52797870f4df84e56c535584b9eff722001b3a765e03c945a7ef8dacc6f6c` 불변과 fixture SHA256 `e8111186e355ed8a9147fb277c334d9fb2c4d328835fd6ebc76b4ba28363888c`를 기록했다. 고정 URL/파일명·콘텐츠/사진과 1배율·키보드 없음·스크롤 맨 위 조건을 변경 전·후에 맞춘다.
  기존 `/base-style-scene?kind=link|photo`를 사용하고 `/base-style-run?resultsOnly=1`로 결과의 탭 고정·스크롤·닫기·추가 저장 없음을 확인한다. 기존 전체 runner/확대 경로는 보존한다.
  iPhone 16/iOS 18.6과 Android 13/API 33 제스처의 두 결과, 총 **4쌍**을 새로 촬영해 변경 전 → 변경 후 → 실제 D05/D09 원본 순서로 제공한다. BEFORE는 정적 원본만, AFTER는 동일 정적 원본과 플랫폼별 동작 영상 2개를 확인한다. Android 3버튼/확대 배율의 새 촬영은 제외한다.
  [변경 전 빌드](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/before-build.json)는 Android 로그 22.5초/명령 25.52초·iOS 로그 34.9초/명령 69.3초로 성공했다. 빌드 성공을 기기 실행/화면 비교 완료로 대신하지 않는다.
  [iOS BEFORE](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/ios-before-result.json)·[Android BEFORE](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/android-before-driver-result.json)는 새 정적 원본 각 2장·총 4장의 직접 시각 확인에서 팝업 0건·프레임워크 오류 0건·`layoutPassed: true`·`stylePassed: false`를 기록했다. 행동/영상은 실행하지 않았으며 두 앱·가상 기기의 정리와 데이터 보존을 확인했다.
  [변경 전 게이트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/before-gate.json)는 **16:52:33 UTC**에 새 원본 4장·동결 fixture·제품 해시 불변을 확인한 뒤 통과했고 [제품 수정 시작](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/product-edit-start.json)은 **16:53:01 UTC**에 기록했다. 세 역할의 스타일만 적용한 후 [집중 36개 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/tests/base-typography-green.log)는 모두 통과(로그 4초/명령 6.79초)했다. 제품 한 파일의 형식 검사는 변경 0건(로그 0.03초/명령 0.42초)이다.
  [기존 관련 회귀 335개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/tests/related-green.log)는 통과(로그 19초/명령 22.32초)했고 [전체 Flutter 913개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/tests/full-test.log)도 통과(로그 55초/명령 58.98초)했다.
  [전체 분석](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/tests/analyze.log)은 문제 없음(로그 3.6초/명령 4.61초)이고 [세 파일 형식 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/tests/format-check.log)는 변경 0건(로그 0.07초/명령 0.41초)이다. [실제 자동 명령 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/automatic-checks.json)은 제품 형식 검사·집중·관련·전체·분석·최종 형식 검사 모두 종료 코드 0을 확인했다.
  [최종 AFTER 소스/빌드](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/final-implementation.json)는 제품 SHA256 `9022a734d31d21980060498a312f286fa788649de37b42ba67061904372ffbf3`와 동일한 동결 fixture/검사 소스를 기록했다. AFTER Android/iOS 빌드는 로그 15.4/23.5초·명령 17.93/37.06초로 모두 종료 코드 0이다. 빌드 성공을 기기 실행 완료로 대신하지 않는다.
  [iOS AFTER](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/ios-after-result.json)·[Android AFTER](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/android-after-driver-result.json)는 각각 새 OS 원본 2장·10개 보고서 기록(캡처 4개·행동 6개)·프레임워크 오류 0건이다. `stylePassed`·`layoutPassed`·`behaviorPassed`·`checksCompleted`·전체 `passed`가 모두 `true`다.
  실제 iPhone 16/iOS 18.6은 393×852·DPR3·상하 여백 59/34px, Android 13/API33 제스처는 392.7×783.3·DPR2.75·24/0px이다. 링크 최대 스크롤/마지막 항목 노출은 iOS 22px·Android 약21.727px에서 확인했다. 사진은 최대 스크롤 0px로 스크롤 불필요이며 무조건 실제 드래그 성공으로 기록하지 않는다. 완료 탭 고정·추가 저장 없이 닫기도 확인했다. 결과 두 상태 이외의 키보드/클립보드/확대 배율 새 기기 실행은 포함하지 않는다.
  양쪽 미리보기 제목의 실측 높이는 23→19px이고 카드/이미지 Y는 자연 본문 흐름에 따라 −4px 이동했다. 별도 위치 보정값은 추가하지 않았다. 출처의 실효 행간 1.6과 문단 실측 22px은 구분하며 계산상 22.4px을 고정 높이로 강제하지 않는다.
  [iOS AFTER 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/ios/after/interaction.mp4)은 17:00:29~17:00:41 UTC·2,128,724바이트이고 [Android AFTER 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/android-gesture/after/interaction.mp4)은 16:57:54~16:58:14 UTC·1,208,741바이트다. 두 native 세션은 정상 종료했고 iOS 앱 종료/Simulator Shutdown/데이터 보존을 확인했다.
  [Android 정리 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/android-after-navigation-restored.json)은 원래 mode2/여섯 오버레이 `matchesOriginal: true`·설정 변경0건·앱/에뮬레이터 종료·forward8768 제거·데이터 보존을 확인했다.
  [iOS 최종 시각 확인](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/ios-after-visual-review.json)은 새 원본 2장·팝업 0건·대상 글자 잘림/겹침 없음을 확인했다. [4쌍 최종 비교](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/comparison-document.html)와 [브라우저](http://127.0.0.1:8775/comparison-document.html)는 모두 변경 전 → 변경 후 → 실제 D05/D09 원본 순서다.
  [비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/comparison-qa.json)·[전후 상태 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/pair-verification.json)는 Figma 누락/조건 불일치 0건·BEFORE 원본 4장 불변·최종 빌드 소스/동결 fixture 일치·12개 미리보기 역할의 실효 스타일/행간·부모 안의 문단 경계·기존 카드/이미지 기하 상수 및 공통 스타일 보존을 확인했다. 원시 선택 상자는 글꼴 선택 경계의 진단값이며 실제 글자 잉크/paint나 잘림으로 단정하지 않는다.
  [실측 요약](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/final-evidence-summary.json)은 제목/카드 Y의 자연 이동 −4px과 출처의 실효 행간 1.6/문단 실측 22px을 구분한다. 위치 보정이나 고정 높이 추가 없이 자연 흐름을 유지했다.
  [영상 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/media-verification.json)는 이번 새 AFTER 두 영상(iOS 10.8초·Android 18.048989초)의 전체 디코딩 종료 코드 0·오류 로그 0바이트를 확인했다. 최종 재확인은 같은 작업의 동일 영상 SHA에 해당하는 성공 디코딩 결과를 재사용했으며 이전 작업의 영상은 사용하지 않았다. BEFORE 행동/영상은 실행하지 않았다.
  [브라우저 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/browser-verification.json)는 네 조건의 실제 선택·원본 이미지 12개 로딩·양 영상 `readyState: 4`/오류 0건·iOS/링크 기본 상태 복귀를 확인했다.
  이번 완료는 저장 결과 미리보기 세 역할의 1배율 글자와 기존 회귀다. 사진 비율/잘림·고정 링크 썸네일·카테고리 편집·결과 상단 80px·저장 화면 전체 맞춤은 미완료다. API·저장 정책은 이번 변경 범위에서 제외하고 기존 연결을 유지했다. 이전 905개 검사나 과거 28개 기기 기록을 이번 913개 검사/새 4쌍 비교의 증거로 사용하지 않는다.
  재현 명령은 [프론트 README](../../frontend/README.md)의 이번 절을 따른다. 증거 루트는 `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography`이며 메모리 저장/사진 선택 대역·Flutter 합성 입력을 실제 OAuth·운영 서버·실기기·원격 CI와 구분한다.
  최종 diff·문서 링크·공백을 확인한 뒤 같은 `feature/figma-ui-alignment`에서 한 커밋으로 저장한다. 화면 증거·빌드 생성물·`AGENTS.md`는 제외하고 푸시·PR은 하지 않는다.

## 원문 출처: docs/figma-ui-alignment-plan.md

<a id="b-c225fd7e8f18ec64"></a>

### 저장 결과 미리보기의 1배율 글자·행간 (2026-10-16, 해당 범위 적용·검증 완료)

<a id="b-7c657f2cae1ac384"></a>

- 기준 `b082db8`, 최신261008 D05 `912:16639`·D09 `912:16602`의 세 역할만 적용했다. ‘미리보기’는 Pretendard16/SemiBold/−0.4/검정/AUTO, 콘텐츠 제목은15/Medium/−0.375/검정/행간1.6, 출처는14/Regular/−0.35/#767676/행간1.6이다. 기존 저장 전용 heading을 재사용하고 private previewTitle/previewSource를 추가했으며 실제 콘텐츠 제목·출처는 유지한다.
- 카드 최소116px·내부 여백8px·썸네일164×100px·이미지/텍스트 간격16px·제목/출처 간격8px·제목2줄/출처1줄 말줄임·세로 중앙·자연 높이 확장을 유지했다. 공개 생성자/콜백/API/모델·저장/닫기·붙여넣기·로딩·하단 안전 영역은 변경하지 않았다.
- 사진 비율/잘림·링크 썸네일 데이터·결과 상단80px·카테고리·전체 세로 배치는 후속이다. 새 확대 대응과 배율별/3버튼 기기 촬영은 제외하고 기존 확대 구현·자동 회귀는 유지했다. 이번 결과를 저장 화면 전체 맞춤 완료로 표시하지 않는다.
- 기존 실제 Pretendard 검사의 결과8조합에 세 역할/기하를 추가하고 긴 제목·출처8조합을 더해 총36개로 확장했다. 제품 수정 전20개 통과·16개 실패(로그4초/명령7.19초)로 글꼴·검정색·출처 상속 행간 차이를 재현했다. if 블록 린트1건을 정리한 초기 시도는 `tests/initial-lint-attempt`에 보존했고 최종 준비 분석은 문제 없음(1.4초/명령2.37초)이었다.
- 촬영 프리뷰는 기존 link/photo 장면과 노드를 재사용한다. `/base-style-run?resultsOnly=1`은 결과2종의 저장1회·반대 탭 고정·최대 스크롤·닫기만 확인하며 기존 기본7상태/확대 실행은 유지한다. 동결 SHA256은 `e8111186e355ed8a9147fb277c334d9fb2c4d328835fd6ebc76b4ba28363888c`다. [변경 전 게이트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/before-gate.json)는 양 플랫폼의 새 원본4장·조건·기준 제품 불변을 확인했고 각 원본의 팝업 없음도 직접 검토한 뒤 제품을 수정했다. BEFORE는 정적 촬영만 수행했다.
- Figma 재조회는2026-10-15 16:48:38~16:48:39 UTC에 두 노드 모두Starter MCP 한도 응답을 받았다. [조회 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/figma/reference-manifest.json)에 이번 실패와 보관된 정확한 원본/컨텍스트2개의 실제 조회 시각·해시를 분리했다. D05는2026-10-15 09:07:32 UTC, D09는08:56:18 UTC다. 원본 누락이나 대체 디자인은 없다.
- 수정 후 집중36개(로그4초/명령6.79초), 관련335개(19초/22.32초), 전체 `flutter test --no-pub` 913개(55초/58.98초)가 통과했다. `flutter analyze --no-pub`는 문제 없음(3.6초/4.61초), Dart3파일 형식 검사는 변경0건(0.07초/0.41초)이다. [명령·종료 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/automatic-checks.json)과 [최종 소스/빌드](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/final-implementation.json)를 제공한다. AFTER 빌드는 Android15.4초(명령17.93초), iOS23.5초(명령37.06초)로 성공했다.
- [iOS 결과](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/ios-after-result.json)·[Android 결과](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/android-after-driver-result.json)는 각각 새 원본2장, 캡처4개+행동6개인10개 기록에서 프레임워크 오류0건·스타일/레이아웃/행동/완료/전체 판정이 모두 `true`다. 수정 영역의 잘림/겹침과 OS 팝업은 없었다. iPhone16/iOS18.6의 창393×852·DPR3·여백59/34px, Android13/API33 제스처의 창약392.7×783.3·DPR2.75·여백24/0px을 기록했다. Figma375×812px과 OS 차이는 원본 그대로 표시한다.
- 양 플랫폼의 미리보기 제목 실측 높이는23→19px이고 카드/이미지는 자연스럽게4px 위로 이동했다. 카드 크기와 내부 간격·중앙 정렬은 보존했으며 보정 여백을 추가하지 않았다. 출처의 `height:1.6`은 설정상22.4px이고 실제 문단은22px임을 [실측 요약](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/final-evidence-summary.json)에 구분했다. 선택 상자는 진단으로 보존하며 실제 부모 레이아웃 경계·말줄임 clip으로 잘림을 판정했다.
- 링크 결과는 실제 드래그 후 최대 스크롤 iOS22px/Android21.727px에서 하단 노출을 확인했다. 사진 결과는 최대 스크롤0px으로 스크롤이 필요 없었다. 두 결과 모두 완료 탭 고정·추가 저장 없음·닫기를 확인했다. Android 원래 탐색 모드2와6개overlay는 일치했고 설정 변경은0건이다. 두 앱/가상 기기 종료·데이터 보존과 Android 포트8768 제거도 확인했다.
- [4쌍 비교](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/comparison-document.html)·[로컬 브라우저](http://127.0.0.1:8775/comparison-document.html)는 변경 전→변경 후→Figma 순서다. [비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/comparison-qa.json)·[전후 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/pair-verification.json)는 완전3열4쌍·조건 불일치0건·BEFORE4원본/상태 불변·최종 소스/동결fixture 일치·12개 역할 및 기존 공통 스타일/기하 상수 보존을 확인했다. [브라우저 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/browser-verification.json)도4개 선택 조건·원본12개 로드·플랫폼별 영상 준비를 확인했다.
- [iOS 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/ios/after/interaction.mp4)10.800초와 [Android 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/android-gesture/after/interaction.mp4)18.048989초를 제공한다. [영상 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/media-verification.json)는 이번 새 영상2개의 전체 디코딩 종료0·오류 로그0바이트를 확인하고 최종 재생성에서도 동일 SHA를 대조했다. BEFORE 행동/영상은 실행하지 않았다. 이전905개 검사·14쌍 비교·기기 성공을 이번 결과로 재사용하지 않으며 실제 서버·OAuth·운영 저장·실기기·원격CI는 별도다.
