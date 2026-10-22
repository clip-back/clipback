# 저장 결과 카테고리 글자

- 최초 기록일: 2026-10-16
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-e5cc20da889a931d"></a>

### 저장 결과 카테고리 1배율 글자 (`108ef0f` 기준, 해당 범위 적용·검증 완료)

<a id="b-5df819f1a748127b"></a>

최신 `261008`의 링크 결과 D05(`912:16639`)·사진 결과 D09(`912:16602`)에서
**카테고리 제목·기존 상태 안내·실제 카테고리명** 세 역할의 글자만 맞춥니다.

<a id="b-c8e6d04ba16d840b"></a>

| 역할 | 저장 전용 스타일 |
| --- | --- |
| 카테고리 제목 | Pretendard 16px/SemiBold·자간 −0.4px·검정·AUTO |
| 기존 상태 안내 | Pretendard 14px/Medium·자간 −0.35px·`#767676`·AUTO |
| 실제 카테고리명 | Pretendard 16px/Medium·자간 0·검정·행간 `22 / 16` |

<a id="b-f558a594ec7ec678"></a>

실제 저장 결과의 처리 중/미분류/분류됨 분기와 문구를 유지합니다.
Figma의 예제 문구인 ‘허투루가 자동으로 분류했어요!’를 모든 결과에 표시하지 않습니다.
55px 카테고리 행·좌우 16px·폴더 28px·폴더/이름 간격 8px·세로 중앙 정렬·이름 한 줄 말줄임을 유지합니다.
기존 ‘분류는 상세 화면에서 변경할 수 있어요.’의 문구와 스타일도 변경하지 않습니다.
카테고리 추가/제거·저장 확정 시점(DEC-03), 자동분류 문구 정책(DEC-05), 사진 비율/잘림·미리보기 전체 배치·결과 상단 80px·API는 제외합니다.
새 확대 대응과 배율별/3버튼 기기 촬영을 추가하지 않으며 기존 확대 구현·자동 회귀는 유지합니다.

<a id="b-383fb4ba60008c0a"></a>

```bash
# frontend/ — 실제 Pretendard를 로드한 1배율 집중 검사와 전체 검사
flutter test --no-pub test/save_base_typography_test.dart
flutter test --no-pub test/saved_content_confirmation_test.dart test/save_scaled_layout_test.dart test/save_footer_layout_test.dart
flutter test --no-pub
flutter analyze --no-pub

# 제품 수정 전에는 before, 수정 후에는 after로 같은 fixture를 실행합니다.
flutter run --no-pub -d <device-id> -t test/support/save_result_preview.dart \
  --dart-define=SAVE_RESULT_PHASE=before
# Android는 포워딩 후 8768, iOS는 8767로 접근합니다.
adb -s "$EMULATOR_ID" forward tcp:8768 tcp:8767
curl 'http://127.0.0.1:8768/base-style-scene?kind=link'
curl 'http://127.0.0.1:8768/base-style-scene?kind=photo'
# after 앱에서 결과만 검사하고 영상으로 기록합니다.
curl 'http://127.0.0.1:8768/base-style-run?resultsOnly=1'
```

<a id="b-0dcb845acda808fc"></a>

기존 scene/runner·폰트/사진 에셋을 재사용하고 신규 카테고리 역할의 실제 `RenderParagraph` 스타일과 행 내부 경계를 전체 판정에 포함합니다.
AUTO는 제목·상태 안내, `22 / 16`은 카테고리명에 따로 검사합니다.
선택 상자는 진단값으로 기록하고 문단/행 경계·의도된 말줄임 clip으로 잘림을 판정합니다.
스크롤 0에서 viewport 아래에 있는 카테고리를 잘림으로 처리하지 않으며 최대 스크롤에서 마지막 안내와 본문 하단 24px을 검사합니다.
기존 기본 28건·미리보기 긴 글자 8건과 새 상태별 32건, 총 68건을 유지합니다.
상태별 자동 검사는 짧은/긴 실제 카테고리, 미분류, YouTube `queued/processing`과 긴 상태 안내를 포함합니다.

<a id="b-14a176ed33f6eccc"></a>

[Figma 재조회](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/figma/implementation-refresh.json)는
**2026-10-16 02:01:15~02:01:18 UTC**에 두 노드 모두 Starter MCP 호출 한도로 실패했습니다.
[원본 출처](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/figma/reference-manifest.json)에 기록된 정확한 보관 원본 D05 **2026-10-15 09:07:32 UTC**·D09 **08:56:18 UTC**를 사용하며 새 조회 성공으로 보고하지 않습니다.
이전 앱 화면을 이번 BEFORE로 사용하지 않습니다.
[변경 전 게이트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/before-gate.json)는
**02:04:05 UTC**에 제품 원본 불변·동결 fixture·새 OS 원본 네 장을 확인했고,
[제품 수정](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/product-edit-start.json)은 **02:04:36 UTC**에 시작했습니다.
BEFORE는 iPhone 16/iOS 18.6과 Android 13/API 33 제스처의 각 플랫폼에서 링크 한 장·사진 한 장, 총 네 장입니다. 프레임워크 오류 0건·`layoutPassed: true`·`stylePassed: false`이며 행동/영상은 실행하지 않았습니다.

<a id="b-464c3a153ae8a5fb"></a>

[최종 수정 전 재현](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/red-checks.json)은
**68건 중 20건 통과·48건 실패**(로그 28초/명령 36.41초)로 세 역할의 상속 글꼴/색상·카테고리명 행간 차이를 재현했습니다.
초기 준비의 중괄호 린트 두 건·출처 헬퍼 import를 수정한 시도와, 선택 상자를 글자 paint로 오판한 초기 재현 시도는 각각 별도 로그로 보존합니다.
첫 수정 후 검사에서 넓은 375px에서도 안내가 무조건 두 줄이어야 한다는 검사 오판으로 60건 통과·8건 실패(명령 10.11초)가 발생했습니다.
제품 변경 없이 실제 Pretendard의 자연 줄바꿈(320px 두 줄·375px 한 줄)에 맞게 검사만 수정하고 `tests/initial-wrap-expectation-attempt`에 첫 시도를 보존했습니다. 최대 줄 수 제한 없음·기존 문구·부모 경계 검사와 네이티브 fixture/BEFORE 원본은 유지했습니다.
[집중 검사 68건](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/tests/base-typography-green.log)은 모두 통과(로그 6초/명령 9.82초)했고,
[기존 관련 회귀 335건](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/tests/related-green.log)도 통과했습니다(로그 17초/명령 20.33초).
[전체 Flutter 945건](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/tests/full-test.log)은 통과(로그 59초/명령 62.29초),
[전체 분석](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/tests/analyze.log)은 문제 없음(로그 3.9초/명령 5.19초)입니다.
첫 형식 검사에서 제품 파일의 포맷 차이를 발견해 `tests/initial-format-attempt`에 보존했습니다. 제품 formatter는 공백 정리 한 건(로그 0.03초/명령 0.4초)만 적용했고 의미 변경은 없습니다.
이후 [세 파일 최종 형식 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/tests/format-check.log)는 변경 0건(로그 0.07초/명령 0.35초)이며 [실제 명령 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/automatic-checks.json)의 최종 명령은 모두 종료 코드 0입니다.
[AFTER 소스·빌드 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/final-implementation.json)은
제품·최종 검사 소스와 변경 전·후 동일한 fixture SHA를 기록합니다. Android 빌드는 로그 17.2초/명령 19.91초, iOS 빌드는 로그 30초/명령 46.33초로 모두 종료 코드 0입니다. 빌드 성공과 실제 기기 실행/화면 비교 완료는 구분합니다.
[iOS AFTER](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/ios-after-result.json)와
[Android AFTER](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/android-after-driver-result.json)는 각각 새 OS 원본 2장·기록 10건(캡처 4건·동작 6건)·프레임워크 오류 0건이며 `stylePassed`·`layoutPassed`·`behaviorPassed`·`checksCompleted`·전체 `passed`가 모두 `true`입니다.

<a id="b-81b99a38eff9e8b3"></a>

| 실행 구성 | 논리 창·DPR | 상단/하단 여백 | 링크 최대 스크롤 | 사진 최대 스크롤 |
| --- | --- | --- | --- | --- |
| iPhone 16 / iOS 18.6 Simulator | 393×852·3 | 59/34px | 14px | 0px |
| Android 13/API 33 제스처 Emulator | 392.7×783.3·2.75 | 24/0px | 약 13.727px | 0px |

<a id="b-1d9550446e315f7f"></a>

결과 진입·완료 탭 고정·추가 저장 없는 닫기, 링크의 실제 드래그/최대 스크롤·마지막 안내 노출/본문 하단 24px을 확인했습니다.
사진은 최대 스크롤 0px이므로 드래그 성공으로 보고하지 않습니다. 처리 중/미분류 상태의 추가 기기 촬영은 하지 않았고 해당 분기는 자동 검사로 확인했습니다.
양쪽 플랫폼의 문단 높이는 제목 23→19px·안내 21→17px·이름 24→22px이며 카테고리 행/기존 안내는 자연 본문 흐름으로 8px 위로 이동했습니다. 위치 보정값은 추가하지 않았습니다.
같은 고정 카테고리명은 Pretendard에서 한 줄로 전부 표시됐습니다. 더 긴 이름의 실제 말줄임은 단위 검사에서 확인했고 기본 한 줄/말줄임 정책은 유지했습니다.
[iOS 원본 시각 확인](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/ios-after-visual-review.json)과 Android 기록에서 팝업·대상 영역 잘림/겹침이 없음을 확인했습니다.

<a id="b-b8961b8b5ef3d8a4"></a>

[새 4쌍 비교](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/comparison-document.html)는 모두 **변경 전 → 변경 후 → Figma 원본** 순서이며 [브라우저에서 보기](http://127.0.0.1:8776/comparison-document.html)로도 확인할 수 있습니다.
[비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/comparison-qa.json)·[전후 상태 검증](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/pair-verification.json)은 Figma 누락/조건 불일치 0건·BEFORE 원본 4장 불변·fixture/최종 빌드 일치와 이번 카테고리 역할 **12개**의 실효 스타일/행간·행 내부 문단/말줄임 경계·기존 행/폴더 기하 상수·상단/미리보기 글자·기존 상세 변경 안내의 문구/스타일 보존을 확인했습니다.
[최종 실측 요약](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/final-evidence-summary.json)에 8px 자연 이동과 AUTO/이름22px 실측을 구분했습니다. OS 창/안전 여백 차이는 원본 그대로 표시하며 확대용 대체 디자인은 만들지 않았습니다.

<a id="b-6cfb9ee5fb0b0eaf"></a>

AFTER 동작 영상은 [iOS](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/ios/after/interaction.mp4) **02:11:35~02:11:53 UTC·2,019,274바이트**,
[Android](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/android-gesture/after/interaction.mp4) **02:12:40~02:13:08 UTC·952,887바이트**입니다.
[영상 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/media-verification.json)는 이번 새 영상 두 개(iOS 14.96초·Android 약25.87초)를 전체 디코딩해 종료 코드 0·오류 로그 0바이트를 확인했습니다. BEFORE 행동/영상은 실행하지 않았고 이전 영상을 이번 것으로 사용하지 않았습니다.
[iOS 실행/정리](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/ios-after-driver-result.json)는 앱 종료·Simulator Shutdown·데이터 보존을 확인했습니다.
[Android 정리](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/android-after-navigation-restored.json)와 실행 기록은 원래 mode2/여섯 오버레이 일치·설정 변경 0건·앱/에뮬레이터 종료·포워딩8768 제거·adb 기기 목록 비어 있음·데이터 보존을 확인했습니다.
[브라우저 검증](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/browser-verification.json)은 네 조건을 직접 선택해 원본 이미지 12개 로딩·Figma 누락 0건·두 영상 `readyState: 4`/오류 없음·iOS/링크 기본 상태 복귀를 확인했습니다.
이번 기기 실행은 결과 두 상태의 1배율이며 클립보드/키보드·새 확대 배율·3버튼 동작을 확인한 것으로 확대하지 않습니다.

<a id="b-17dd07204584ded7"></a>

이번 완료 범위는 카테고리 세 역할의 1배율 글자입니다. 기존 결과 정책·이름/상태 안내를 보존하며 저장 화면 전체 맞춤으로 표시하지 않습니다.
증거 루트는 `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography`입니다.
메모리 저장/사진 선택 대역·Flutter 합성 입력과 실제 OS 창을 사용하며 운영 서버·OAuth·실기기·원격 CI는 검증 범위 밖입니다.
화면 증거·빌드 생성물·`AGENTS.md`는 Git에서 제외하고 푸시·PR은 하지 않습니다.

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-db8a6694aad5e83c"></a>

### 2026-10-16 — 저장 결과 카테고리의 1배율 글자 (해당 범위 적용·검증 완료)

<a id="b-6d6ce1c5330273e0"></a>

- 기준 커밋은 `108ef0f`이며 최신261008 D05 `912:16639`·D09 `912:16602`의 카테고리 제목·기존 상태 안내·실제 카테고리명 세 역할만 적용한다.
  제목은 Pretendard16/SemiBold/−0.4/검정/AUTO, 안내는14/Medium/−0.35/#767676/AUTO, 이름은16/Medium/자간0/검정/행간22÷16이다.
  기존 저장 전용 스타일을 재사용·확장하고 행55px·좌우16px·폴더28px·아이콘/이름8px·세로 중앙·한 줄 말줄임을 유지한다.
  처리 중/미분류/실제 분류 문구·분기와 ‘분류는 상세 화면에서 변경할 수 있어요.’의 기존 스타일은 유지한다.
  Figma의 자동분류 완료 예제를 고정 표시하지 않으며 카테고리 추가/제거·확정 시점(DEC-03)과 자동분류 정책(DEC-05), 사진 비율/잘림·전체 미리보기 배치·결과 상단80px·API는 제외한다.
- [구현 직전 Figma 재조회](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/figma/implementation-refresh.json)는 **2026-10-16 02:01:15~02:01:18 UTC**에 두 노드 모두 Starter MCP 호출 한도로 실패했다.
  [정확한 보관 원본 출처](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/figma/reference-manifest.json)의 D05 **2026-10-15 09:07:32 UTC**·D09 **08:56:18 UTC**를 승인된 fallback으로 사용한다. 개인 계정 정보는 기록하지 않으며 과거 앱 캡처를 새 BEFORE로 대신하지 않는다.
- 기존 `save_base_typography_test.dart`의 기본28건·긴 미리보기8건을 보존하고 새 카테고리32건을 추가했다. 실제 Pretendard·결과2종·iOS/Android 테마·폭320/375px·1배율에서 짧은/긴 이름, 미분류, YouTube queued/processing과 긴 안내를 검사한다.
  역할별 글꼴/행간·55px행/폴더/패딩/간격/중앙 정렬/말줄임과 실제 이름·상태 안내·기존 상세 변경 안내 보존을 확인한다.
  선택 상자는 진단값으로 분리하며 실제 문단·행·말줄임 clip과 최대 스크롤의 마지막 안내/본문 하단24px으로 잘림을 판정한다.
  `/base-style-scene?kind=link|photo`, `/base-style-run?resultsOnly=1`과 기존 기본/확대 runner를 유지하고 프리뷰의 신규 세 역할을 전체 스타일/레이아웃 판정에 연결했다.
- [준비 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/preparation-checks.json)는 검사/프리뷰 두 파일 분석·형식 검사를 통과했다. 초기 중괄호 린트 두 건과 출처 헬퍼 import 수정 전 기록은 `tests/initial-preparation-attempt`에 남겼다.
  [수정 전 최종 재현](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/red-checks.json)은 **68건 중20건 통과·48건 실패**(로그28초/명령36.41초)로 세 역할의 상속 글꼴/색상·이름 행간 차이를 확인했다. 선택 상자를 paint로 오판한 초기 시도는 `tests/initial-selection-diagnostic-attempt`에 별도 보존하고 실제 문단/행/말줄임 경계 검사는 유지했다.
- [변경 전 게이트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/before-gate.json)는 **02:04:05 UTC**에 `108ef0f` 제품 불변·동결 fixture·새 OS 원본4장을 확인한 뒤 통과했다. [제품 수정 시작](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/product-edit-start.json)은 **02:04:36 UTC**다.
  BEFORE는 iPhone16/iOS18.6·Android13/API33 제스처의 각 플랫폼에서 링크1장·사진1장, 총4장이다. 프레임워크 오류0건·`layoutPassed: true`·`stylePassed: false`이며 행동·영상은 실행하지 않았다.
  변경 전·후는 같은 데이터·1배율·키보드 숨김·스크롤0으로 맞춰 총4쌍을 새로 촬영했다. 새 확대 배율/3버튼 반복 촬영은 제외하고 기존 확대 자동 회귀는 유지한다.
- 첫 수정 후 집중 검사는 60건 통과·8건 실패(명령10.11초)였으며 원인은 넓은375px에서도 처리 중 안내가 무조건 두 줄이라는 검사 오판이었다. 제품 수정 없이 실제 Pretendard의 자연 줄바꿈(320px 두 줄·375px 한 줄)에 맞게 검사만 수정하고 `tests/initial-wrap-expectation-attempt`에 보존했다. 기존 문구·최대 줄 수 제한 없음·부모 경계와 native fixture/BEFORE 원본은 유지했다.
- 최종 [집중68건](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/tests/base-typography-green.log)은 통과(로그6초/명령9.82초), [관련335건](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/tests/related-green.log)도 통과(로그17초/명령20.33초)했다.
  [전체 Flutter945건](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/tests/full-test.log)은 통과(로그59초/명령62.29초)했고 [전체 분석](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/tests/analyze.log)은 문제 없음(로그3.9초/명령5.19초)이다.
  첫 형식 검사 차이는 `tests/initial-format-attempt`에 보존했다. 제품 formatter가 공백 한 건만 정리(로그0.03초/명령0.4초)한 뒤 [세 파일 형식 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/tests/format-check.log)는 변경0건(로그0.07초/명령0.35초)이다. [최종 자동 명령 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/automatic-checks.json)은 모두 종료코드0이며 의미 변경 없는 공백 정리만으로 테스트를 다시 반복하지 않았다.
  [AFTER 소스·빌드](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/final-implementation.json)는 제품·최종 검사·변경 전/후 동일한 fixture와 Android/iOS 바이너리 SHA를 기록했다. Android 빌드는 로그17.2초/명령19.91초·iOS 빌드는 로그30초/명령46.33초로 모두 종료코드0이며 실행 검증과 구분한다.
- [iOS AFTER](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/ios-after-result.json)·[Android AFTER](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/android-after-driver-result.json)는 각각 새 OS 원본2장·기록10건(캡처4건/동작6건)·프레임워크 오류0건이다. `stylePassed`·`layoutPassed`·`behaviorPassed`·`checksCompleted`·전체 `passed`가 모두 `true`다.
  실제 창은 iPhone16/iOS18.6의393×852·DPR3·상하59/34px, Android13/API33 제스처의392.7×783.3·DPR2.75·24/0px이다. 링크의 실제 드래그·최대 스크롤(iOS14px·Android약13.727px)·마지막 안내/본문하단24px·탭 고정·추가 저장 없는 닫기를 확인했다. 사진은 max0px로 드래그 성공으로 기록하지 않는다.
  카테고리 문단 높이는 양쪽 모두 제목23→19·안내21→17·이름24→22px이며 행/기존 안내Y는 자연스럽게−8px 이동했다. 위치 보정값은 추가하지 않았다. 고정 카테고리명은 Pretendard에서 한 줄에 들어가며 더 긴 이름의 실제 말줄임은 단위 검사로 확인했다.
  [iOS 원본 시각 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/ios-after-visual-review.json)와 Android 실행 기록은 팝업/대상 잘림/겹침이 없음을 확인했다. 처리 중/미분류 분기는 자동 검사로 확인했으며 이번 기기의4쌍은 고정된 분류됨 결과다.
- [4쌍 새 비교](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/comparison-document.html)와 [브라우저](http://127.0.0.1:8776/comparison-document.html)는 변경 전→변경 후→Figma 원본 순서다.
  [비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/comparison-qa.json)·[전후 상태 검증](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/pair-verification.json)은 완전한3열4쌍·Figma 누락/조건 불일치0건·BEFORE 원본4장 불변·fixture/최종 빌드 일치·이번 카테고리 역할12개의 스타일/행간·행 안의 문단/말줄임 경계·기존 행/폴더 기하 상수·상단/미리보기 스타일·기존 상세 변경 안내 문구/스타일 보존을 확인했다.
  [실측 요약](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/final-evidence-summary.json)은 AUTO와 이름22px 실측·행Y−8px의 자연 흐름을 구분한다. OS 창/안전 여백 차이를 원본 그대로 설명하고 대체 디자인은 만들지 않았다.
  [iOS AFTER 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/ios/after/interaction.mp4)은02:11:35~02:11:53UTC·2,019,274바이트, [Android AFTER 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/android-gesture/after/interaction.mp4)은02:12:40~02:13:08UTC·952,887바이트다.
  [영상 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/media-verification.json)는 두 새 영상(iOS14.96초/Android약25.87초)의 전체 디코딩 종료코드0·오류로그0바이트를 확인했다. BEFORE 행동/영상과 이전 작업의 영상은 사용하지 않았다.
  [iOS 정리](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/ios-after-driver-result.json)와 [Android 정리](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/android-after-navigation-restored.json)/실행 기록은 앱·Simulator/AVD 종료·데이터 보존, Android 원래mode2/여섯 오버레이 일치·설정 변경0건·포워딩8768 제거·adb 기기목록 비어 있음을 확인했다.
  [브라우저 검증](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/browser-verification.json)은 실제 네 조건 선택·원본12개 로딩·Figma 누락0건·양 영상 `readyState: 4`/오류 없음·iOS/링크 기본 상태 복귀를 확인했다.
  이전913개 테스트와 이전12개 미리보기 역할 검사를 이번945개/새12개 카테고리 역할의 성공으로 사용하지 않는다. 새 클립보드/키보드·확대/3버튼 기기 동작은 이번 범위가 아니다.
  재현 명령은 [프론트 README](../../frontend/README.md)의 이번 카테고리 절을 따른다. 증거 루트는 `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography`다.
  고정 사진 선택·메모리 저장 대역·Flutter 합성 입력 검증을 운영 서버·OAuth·실기기·원격 CI와 구분한다. 완료는 세 역할의1배율 글자에 한정하고 저장 화면 전체 맞춤·카테고리 편집은 후속으로 남긴다.
  같은 `feature/figma-ui-alignment`에서 최종 diff·문서 링크·공백을 확인해 한 커밋으로 저장하며 화면 증거·빌드 생성물·`AGENTS.md`는 제외하고 푸시·PR은 하지 않는다.

## 원문 출처: docs/figma-ui-alignment-plan.md

<a id="b-a7955265b4229808"></a>

### 저장 결과 카테고리 영역의 1배율 글자 (2026-10-16, 해당 범위 적용·검증 완료)

<a id="b-ee0eb114d38420df"></a>

- 기준 `108ef0f`, 최신261008 D05 `912:16639`·D09 `912:16602`의 카테고리 제목·상태 안내·실제 카테고리명만 적용했다. 제목은 기존 저장 전용 heading(Pretendard16/SemiBold/−0.4/검정/AUTO)을 재사용한다. 안내는14/Medium/−0.35/#767676/AUTO, 이름은16/Medium/자간0/검정/행간22px(`height:22/16`)이며 `inherit:false`로 글꼴·색상·행간 상속을 막았다.
- 실제 처리 중·미분류·분류됨의 조건/문구와 `content.category.name`을 유지한다. Figma 예제 ‘허투루가 자동으로 분류했어요!’를 무조건 표시하지 않으며 기존 ‘분류는 상세 화면에서 변경할 수 있어요.’ 안내의 문구/스타일도 보존한다. 공개 생성자/콜백/API/모델·저장/닫기·완료 탭·하단 안전 영역은 변경하지 않았다.
- 기존55px 행·좌우16px·폴더28px·폴더/이름8px·제목/안내8px·안내/행16px·행/상세안내8px·한 줄 말줄임·세로 중앙 정렬을 유지한다. 글자 높이 변경에 따른 자연 본문 흐름은 기록하되 위치 보정값을 추가하지 않는다. 카테고리 편집/확정 시점·상태별 전체 배치·사진 비율/잘림·결과 상단80px·전체 맞춤·새 확대 대응은 후속이고 기존 확대 자동 검사를 유지한다.
- 기존 실제 Pretendard 검사의36개를 유지하고 카테고리32개를 추가해68개로 확장했다. 링크/사진×iOS/Android×320/375px에서 미분류·실제 분류·긴 이름·YouTube queued/processing을 검사한다. 부모/행/말줄임 경계를 검사하며 선택 상자는 실제 글자 잉크로 단정하지 않는다. 처리 중 안내는320px에서2줄,375px에서1줄의 자연 줄바꿈이고 최대 스크롤의 마지막 안내/본문 하단24px/버튼 겹침도 확인한다.
- 제품 수정 전 최종 RED는20개 통과·48개 실패(로그28초/명령36.41초)로 글꼴·색상·자간·상속 행간 차이를 재현했다. 준비 분석3건(import누락/if블록2건), 선택 상자 진단 보완 이전 RED, 첫 GREEN의 넓은 화면2줄 기대 오판(60개 통과·8개 실패)은 `tests/initial-preparation-attempt`, `tests/initial-selection-diagnostic-attempt`, `tests/initial-wrap-expectation-attempt`에 보존했다. 제품의 배치를 바꾸지 않고 검사 판정을 바로잡았다.
- 기존 `/base-style-scene?kind=link|photo`와 `/base-style-run?resultsOnly=1`에 세 역할의 실효스타일과 `layout.category` 경계를 연결했다. 기존 기본 실행과 확대 실행은 유지한다. 고정 네이티브 fixture SHA256은 `a6af26a1d252f497d455f8c8ff3ca187f383dc8c9e689788d2343638343260f3`이며 제품 수정 전 [before-gate.json](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/before-gate.json)에서 기준 제품 불변·새 OS원본4장·동일 조건을 확인했다. 단위 테스트만 선택 상자 판정을 보완했으며 해당 파일은 네이티브 프리뷰 진입점의 컴파일 대상이 아니다. 프리뷰·촬영 데이터는 전후 변경하지 않았다.
- Figma 재조회는 2026-10-16 02:01:15 UTC~2026-10-16 02:01:18 UTC에 두 노드 모두Starter MCP 호출 한도 응답이었다. [figma/reference-manifest.json](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/figma/reference-manifest.json)에 이번 실패와 정확한 보관 원본/컨텍스트의 실제 조회 시각·해시를 분리했다. D05는2026-10-15 09:07:32 UTC, D09는08:56:18 UTC다. 원본 누락이나 대체 디자인은 없다. 기존 로컬 이미지/아이콘/폰트의 이번 메타데이터 확인은 [asset-metadata.json](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/asset-metadata.json)에 기록한다.
- 수정 후 집중68개(로그6초/명령9.82초), 관련335개(17초/20.33초), 전체 `flutter test --no-pub`945개(59초/62.29초)가 통과했다. `flutter analyze --no-pub`는 문제 없음(3.9초/5.19초)이고 제품 서식1건 정리 후3파일 형식 검사는 변경0건(0.07초/0.35초)이다. 첫 서식 검사 실패는 `tests/initial-format-attempt`에 보존했다. [automatic-checks.json](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/automatic-checks.json)과 [final-implementation.json](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/final-implementation.json)에 실제 명령/종료 코드 및 최종 소스·빌드 해시를 기록했다. AFTER Android빌드는17.2초(명령19.91초), iOS는30초(명령46.33초)로 성공했다.
- [iOS AFTER 결과](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/ios-after-result.json)·[Android AFTER 결과](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/android-after-driver-result.json)는 각각 새 원본2장·캡처4개/동작6개인10개 기록에서 프레임워크 오류0건, `stylePassed`·`layoutPassed`·`behaviorPassed`·`checksCompleted`·`passed`가 모두 `true`다. iPhone16/iOS18.6의 창393×852/DPR3/안전 여백59·34px, Android13/API33 제스처의 창약392.7×783.3/DPR2.75/여백24·0px과 Figma375×812 차이를 원본 그대로 표시한다.
- 양 플랫폼에서 제목 문단23→19px·안내21→17px·이름24→22px, 행 상단−8px의 자연 변화를 확인했다. AUTO인 제목/안내를19/17px 고정 높이로 바꾸지 않았다. 이름의 실효/명시 행간은22/16이다. [실측 요약](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/final-evidence-summary.json)에 실제 경계와 차이를 기록한다. 같은 긴 카테고리명이 Pretendard에서 폭 안에 들어가더라도 한 줄 말줄임 정책은 유지하며 더 긴 이름은 자동 검사에서 말줄임을 검증한다.
- iOS 링크 최대 스크롤22→14px, Android21.7273→13.7273px에서 실제 본문 드래그·마지막 안내 전체 노출·하단24px·버튼과 겹침 없음을 확인했다. 사진 결과는 최대 스크롤0px로 드래그가 필요 없었다. 저장1회·완료 탭 고정·추가 저장 없이 닫기도 양쪽에서 통과했다. [iOS 동작 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/ios/after/interaction.mp4)14.96초·[Android 동작 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/android-gesture/after/interaction.mp4)25.869856초의 전체 디코딩 종료0/오류 로그0바이트를 [영상 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/media-verification.json)에 기록했다. BEFORE는 정적 촬영만 수행했다.
- [새 4쌍 비교](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/comparison-document.html)·[브라우저](http://127.0.0.1:8776/comparison-document.html)는 변경 전→변경 후→정확한 D05/D09 기본 원본 순서다. [전후 조건 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/pair-verification.json)·[비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/comparison-qa.json)에서 Figma누락/조건불일치0건·BEFORE4원본 불변·고정fixture/최종빌드소스일치·카테고리12역할 일치·기존 미리보기/공통 스타일·행/폴더/간격/상세안내 보존을 확인했다. [직접 시각 확인](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/comparison-visual-review.json)에서도 팝업·목표 영역 잘림/겹침은 없었다. [브라우저 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/browser-verification.json)는4조건 선택·원본이미지12개 로딩·양 영상 readyState4/오류없음·기본 iOS/링크 복귀를 확인했다.
- [iOS 시각/정리 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/ios-after-visual-review.json)·[Android 정리 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/android-after-navigation-restored.json)·플랫폼 driver결과에 앱 종료/기기 Shutdown/데이터 보존을 기록했다. Android는 원래 제스처mode2·6개 오버레이 불변/설정 변경0건·forward8768 제거·AVD종료/adb목록 비어 있음을 확인했다. 새 확대 배율·3버튼·키보드 기기 촬영은 하지 않았다.
- 이번 완료는 카테고리 세 역할의 기본 글자에 한정한다. 고정 입력/사진 선택/저장 응답 대역과 Flutter 합성 입력의 검증이며 운영 서버·OAuth·실기기·원격 CI의 증거가 아니다. 이전913개 검사·이전 미리보기 비교/영상은 이번 성공으로 사용하지 않았다. 카테고리 편집·상태별 전체 배치·사진 비율·결과 상단80px 등 보류 범위는 유지한다. 최종 diff·문서 링크·`git diff --check`를 확인하고 같은 브랜치에서 `fix: 저장 결과 카테고리 영역의 기본 글자 맞춤`으로 한 커밋 저장하며, 화면 증거·빌드·`AGENTS.md`는 제외하고 푸시/PR은 하지 않는다.
