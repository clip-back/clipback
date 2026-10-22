# 저장 결과 상단 여백

- 최초 기록일: 2026-10-17
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-7fb00a6e54d2896e"></a>

앞선 `d1f13d4` 기준 작업은 Page 1 > 261007의 [D05 링크 결과(`111:4902`)](https://www.figma.com/design/svNWsTFh8Ws1Mpt8XQIcrN/?node-id=111-4902)·[D09 사진 결과(`111:4865`)](https://www.figma.com/design/svNWsTFh8Ws1Mpt8XQIcrN/?node-id=111-4865)의 **탭 하단부터 결과 제목까지 시작 여백**만 80→32px로 맞췄습니다.
저장 본문의 패딩을 좌16·상32·우16·하24px로 통일하며 입력 화면의 32px·본문 viewport·헤더/탭·하단 버튼·안전 영역은 유지합니다. 사진 비율/잘림·미리보기 내부 간격·카테고리 편집·결과 전체 배치는 후속으로 남깁니다.

<a id="b-d3bfe3e3f771d286"></a>

### 저장 결과 상단 여백 (`d1f13d4` 기준, 해당 범위 적용·검증 완료)

<a id="b-a67c7774ff5a6033"></a>

Page 1 > 261007의 D05 `111:4902`·D09 `111:4865`를 기준으로 저장 본문의 조건부 상단 패딩을 제거하고 `const EdgeInsets.fromLTRB(16, 32, 16, 24)`를 적용했습니다.
입력 화면은 기존 32px을 유지하며 결과 제목과 뒤따르는 본문만 스크롤 0에서 48px 위로 이동합니다. 절대 좌표나 개별 요소의 위치 보정은 추가하지 않습니다.
헤더 64px·탭 56px·본문 viewport·CTA 56px·OS 하단 여백/키보드 회피·저장/닫기와 제출 입력/완료 탭 고정 정책은 유지합니다.
미리보기의 116px 최소 높이·이미지 164×100px·내부 8px/16px과 제목–출처 8px, 카테고리 행 55px은 이번 조정 대상이 아닙니다.

<a id="b-30ac02496f93049d"></a>

```bash
# frontend/ — 실제 Pretendard·1배율 76건과 기존 확대/하단/입력 보존 회귀
flutter test --no-pub test/save_base_typography_test.dart
flutter test --no-pub test/save_paste_layout_test.dart test/save_footer_layout_test.dart test/save_search_safe_area_test.dart test/save_scaled_layout_test.dart test/saved_content_confirmation_test.dart test/screenshot_asset_test.dart test/screenshot_asset_api_test.dart test/screenshot_auth_test.dart test/content_auto_category_test.dart test/share/manual_save_preservation_test.dart
flutter test --no-pub
flutter analyze --no-pub

# 제품 수정 전에는 before, 수정 후에는 after로 같은 fixture를 실행합니다.
flutter run --no-pub -d <device-id> -t test/support/save_result_preview.dart \
  --dart-define=SAVE_RESULT_PHASE=before
# Android는 포워딩한 8768, iOS는 8767로 접근합니다.
adb -s "$EMULATOR_ID" forward tcp:8768 tcp:8767
curl 'http://127.0.0.1:8768/base-style-scene?kind=link'
curl 'http://127.0.0.1:8768/base-style-scene?kind=photo'
# after 앱에서 기존 결과 전용 runner를 실행하며 영상으로 기록합니다.
curl 'http://127.0.0.1:8768/base-style-run?resultsOnly=1'
```

<a id="b-42976e758d7fd382"></a>

기존 76개 검사와 프리뷰에 탭 하단·본문 viewport·결과 제목 경계, 실제 패딩·스크롤 위치와 시작 간격을 연결했습니다.
32px 위치 판정은 스크롤 0에서만 적용하고 스크롤된 제목 위치를 보정하거나 검사 중 스크롤을 되돌리지 않습니다.
최대 스크롤에서는 마지막 안내 노출·본문 하단 최소 24px·버튼과 겹침 없음을 검사하며 BEFORE의 목표치 실패는 원본 촬영을 막지 않습니다.
[수정 전 집중 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/tests/focused-red-summary.json)는 **76건 중 68건 통과·링크/사진 결과 8건만 예상 실패**로 기존 상단 80px과 목표 32px 차이를 재현했습니다.
실제 Pretendard·iOS/Android 테마 × 폭 320/375px × 1배율이며 입력·기존 D07 프레임·글자·미리보기 내부·CTA 검사를 유지했습니다.

<a id="b-22e1819ac66fe1b9"></a>

[이번 Figma 조회](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/figma/reference-manifest.json)는 **2026-10-16 18:22:34~18:22:41 UTC(2026-10-17 03:22:34~03:22:41 KST)**에 현재 파일의 두 노드를 각각 한 번 조회해 컨텍스트와 원본 375×812px을 확보했습니다.
[D05 원본](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/figma/D05.png)·[D05 컨텍스트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/figma/D05-context.txt), [D09 원본](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/figma/D09.png)·[D09 컨텍스트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/figma/D09-context.txt)를 보존하며 호출 제한·fallback·Figma 누락은 없습니다. 이전 `261008` 파일 이미지는 사용하지 않습니다.
[BEFORE 게이트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/before-gate.json)는 **18:24:04 UTC**에 `d1f13d4` 제품 불변·검사/fixture 동결·새 OS 원본 4장을 확인했습니다.
두 플랫폼의 링크/사진 BEFORE는 모두 시작 간격 80px·`stylePassed: true`·`layoutPassed: false`·프레임워크 오류 0건입니다. 이전 앱 캡처로 대체하지 않고 BEFORE의 목표치 실패를 그대로 기록합니다.

<a id="b-d9585bcee6b61807"></a>

[집중 76건](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/tests/base-typography-green.log)은 통과(명령 9.47초), [관련 335건](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/tests/related-green.log)도 통과(23.6초)했습니다.
[전체 Flutter 953건](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/tests/full-test.log)은 통과(80.77초), [정적 분석](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/tests/analyze.log)은 문제 없음(6.3초), [세 Dart 파일 형식 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/tests/format-check.log)는 변경 0건(0.81초)입니다.
[이번 자동 검사 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/automatic-checks.json)의 종료 코드는 모두 0입니다. 기존 확대·D07 프레임·하단 배치·입력 보존 검사를 포함하며 과거 953건 성공을 이번 실행으로 대신 보고하지 않습니다.
BEFORE/AFTER의 iOS·Android 빌드도 각각 성공했고, 같은 동결 검사/fixture를 사용한 [BEFORE 소스·빌드](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/before-build.json)와 [AFTER 소스·빌드](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/final-implementation.json)에 실제 SHA256을 기록했습니다. 빌드 성공과 아래 native 실행 결과를 구분합니다.

<a id="b-0b1612f1ddc41222"></a>

[iOS AFTER 실행](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/ios-after-driver-result.json)·[Android AFTER 실행](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/android-gesture/after/driver-result.json)은 각각 **기록 10건(정적/runner 캡처 4건·동작 6건)·프레임워크 오류 0건**입니다.
두 [iOS 보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/ios/after/flutter/report.json)·[Android 보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/android-gesture/after/flutter/report.json)의 `stylePassed`·`layoutPassed`·`behaviorPassed`·`checksCompleted`·전체 `passed`는 모두 `true`입니다.
링크/사진 결과 진입·반대 탭을 눌러도 완료 탭/결과 유지·최대 스크롤 분기·추가 저장 없는 닫기를 확인했습니다. AFTER는 두 결과 모두 최대 스크롤이 0px이므로 무스크롤 상태와 마지막 안내의 전체 노출을 확인했으며 실제 드래그 성공으로 보고하지 않습니다.
본문 하단 패딩 24px·CTA와 맞닿는 viewport 경계·추가 여유 공간을 구분하며 마지막 안내와 버튼의 겹침은 없습니다.

<a id="b-75ee2b6208fb4503"></a>

| 실제 실행 구성 | 탭 하단/viewport 시작 (전·후 동일) | 결과 제목 top (링크·사진) | 시작 간격 | CTA top (전·후 동일) |
| --- | --- | --- | --- | --- |
| iPhone 16 / iOS 18.6, 393×852·DPR 3·상하 59/34px | 179px | 259 → 211px | 80 → 32px | 730px |
| Android 13/API 33 제스처, 약392.7×783.3·DPR 2.75·상하 24/0px | 144px | 224 → 176px | 80 → 32px | 약695.273px |

<a id="b-caf3a222f451ff0d"></a>

본문의 제목·미리보기·카테고리/마지막 안내는 스크롤 0에서 모두 48px 위로 이동했고 내부 크기·상대 간격·글자와 헤더/탭/viewport/CTA는 유지했습니다.
Figma 375×812px 원본의 탭 하단 170px·제목 202px도 시작 간격은 32px입니다. 실제 OS 상단 여백 때문에 앱의 절대 좌표가 다르며 비교용으로 OS 표시를 지우거나 창 크기를 강제하지 않습니다.
[완전한 3열 비교 4쌍](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/comparison-document.html)은 **변경 전 → 변경 후 → 현재 Figma D05/D09 원본** 순서이며 [비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/comparison-qa.json)에 누락/조건 불일치 0건·BEFORE 원본 4장 불변·동결 검사/fixture 일치·−48px 이동·내부/CTA 유지 결과를 기록했습니다.
직접 볼 수 있는 비교는 [iOS 링크](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/comparison-ios-link.png)·[iOS 사진](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/comparison-ios-photo.png)·[Android 링크](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/comparison-android-gesture-link.png)·[Android 사진](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/comparison-android-gesture-photo.png)입니다.

<a id="b-8e6655b15d10add3"></a>

새 AFTER 영상은 [iOS](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/ios/after/interaction.mp4) **13.16초·1,111,623바이트**, [Android](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/android-gesture/after/interaction.mp4) **15.313511초·951,268바이트**입니다.
[미디어 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/media-verification.json)는 두 원본의 전체 디코딩 종료 코드 0·오류 로그 0바이트·시작/중간/끝 및 0.5초 간격 표본의 팝업 없음·결과 진입/탭 선택/닫기 장면과 원본 재인코딩 없음을 확인했습니다. BEFORE 영상/동작과 이전 작업의 영상은 이번 증거로 사용하지 않습니다.
iOS 앱/Simulator와 Android 앱/Emulator를 종료하고 데이터를 보존했습니다. Android는 원래 제스처 모드 2/여섯 오버레이 일치·탐색 설정 변경 0건·8768 포워딩 제거·정리 후 기기 목록 비어 있음을 실행 기록에 남겼습니다.

<a id="b-b30d8fae74876bdc"></a>

[최종 환경 정리](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/cleanup-verification.json)는 **18:30:08 UTC**에 iPhone 16 Shutdown·adb/Emulator/qemu 프로세스 0건·8767/8768 listener 없음·포워딩 제거·adb 서버 종료·데이터 보존을 확인했습니다. 임시 비교 서버는 시작하지 않았습니다.
비교 HTML은 JS 문법·36개 파일 경로·PNG 직접 시각 검사를 확인했으며 브라우저 상호작용 실행은 이번에 검증하지 않았습니다. 이 한계와 양 플랫폼 native 실행/영상 성공은 구분합니다.

<a id="b-63f1ff5989c3ed56"></a>

이번 완료 범위는 결과 시작 여백이며 사진 비율/잘림·미리보기 제목–출처 간격·카테고리 편집·결과 전체 배치는 계속 보류합니다. 과거 절의 ‘결과 상단 80px 유지’는 당시 범위 기록이며 현재 값은 이 절의 32px을 따릅니다.
새 확대 대응·배율별/3버튼/키보드 기기 촬영은 추가하지 않으며 기존 확대 구현과 자동 회귀는 유지합니다. 메모리 저장/사진 선택 대역·Flutter 합성 입력·실제 OS 창과 운영 API·OAuth·실기기·원격 CI 검증을 구분합니다.
화면 증거·빌드 생성물·`AGENTS.md`는 Git에서 제외하고 같은 `feature/figma-ui-alignment`에서 한 커밋으로 저장하며 푸시·PR은 하지 않습니다.

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-31b44bf00f72da96"></a>

### 2026-10-17 — 저장 결과 상단 여백 (`d1f13d4` 기준, 해당 범위 적용·검증 완료)

<a id="b-ea01ca3d2852818c"></a>

- 기준은 현재 파일 `svNWsTFh8Ws1Mpt8XQIcrN`의 Page 1(`0:1`) > 261007(`111:3379`), D05 링크 결과(`111:4902`)·D09 사진 결과(`111:4865`)다. 이번 대상은 탭 하단부터 결과 제목까지의 시작 여백이다. 저장 본문의 조건부 상단 패딩만 제거해 좌16·상32·우16·하24px로 통일했으며 입력은 기존32px, 결과 제목과 뒤따르는 본문은 스크롤0에서−48px 이동한다. 절대 좌표/개별 보정은 추가하지 않고 헤더/탭·본문 viewport·하단 버튼/안전 영역·키보드 회피·제출 입력/완료 탭 고정·저장/닫기 정책을 유지한다.
- [구현 직전 Figma 조회](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/figma/reference-manifest.json)는 **2026-10-16 18:22:34~18:22:41 UTC(2026-10-17 03:22:34~03:22:41 KST)**에 D05/D09를 각각 한 번 호출해 컨텍스트와 정확한 375×812px 원본을 확보했다. 호출 제한·fallback·누락은 없으며 이전 `261008` 파일 원본으로 대체하지 않았다. 두 원본/컨텍스트와 SHA256·실제 시각을 이번 증거에 보존한다.
- 기존76개 검사와 프리뷰에 실제 패딩·탭 하단/viewport/제목 경계·스크롤 위치·시작 간격을 추가하고 목표 검사를 레이아웃/전체 판정에 연결했다. 실제 Pretendard·iOS/Android 테마·폭320/375px·1배율의 [수정 전 재현](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/tests/focused-red-summary.json)은 **68통과·결과8건만 예상 실패**다. 시작32px은 스크롤0에서만 판정하며 스크롤을 초기화하거나 원시 위치를 보정하지 않는다. 최대 스크롤은 마지막 안내/본문 하단24px/CTA 비중첩으로 검사한다. 기존 D07 프레임·내부 배치·확대 회귀는 유지하고 새 route 없이 기존 scene/resultsOnly runner를 재사용한다.
- [BEFORE 게이트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/before-gate.json)는 **18:24:04 UTC**에 `d1f13d4` 제품 불변·동결 검사/fixture·새 OS 포함 원본4장을 확인했다. iOS/Android 각각 링크·사진을 같은 데이터·1배율·키보드 숨김·스크롤0으로 촬영했으며 모두 시작80px·스타일 통과·목표 레이아웃 실패·프레임워크 오류0건이다. BEFORE 실패가 촬영을 막지 않으며 이전 캡처를 재사용하지 않는다.
- [집중76개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/tests/base-typography-green.log)는 통과(명령9.47초), [관련335개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/tests/related-green.log)도 통과(23.6초)했다. [전체Flutter953개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/tests/full-test.log)는 통과(80.77초), [분석](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/tests/analyze.log)은 문제 없음(6.3초), [세 Dart 파일 형식](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/tests/format-check.log)은 변경0건(0.81초)이다. [자동 검사 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/automatic-checks.json)의 종료코드는 모두0이며 과거953건 성공을 이번 실행으로 대신하지 않는다. 기존 확대·D07 프레임·하단/입력 보존 회귀를 유지했다. [BEFORE빌드](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/before-build.json)·[AFTER빌드](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/final-implementation.json)는 iOS/Android 각각 종료코드0과 실제 소스/바이너리SHA를 기록하며 검사/fixture SHA가 동일하다. 빌드 결과와 native 실행 성공을 구분한다.
- [iOS AFTER](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/ios-after-driver-result.json)·[Android AFTER](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/android-gesture/after/driver-result.json)는 각각 **기록10건(정적/runner 캡처4건·동작6건)·프레임워크 오류0건**이다. 양쪽 [iOS 보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/ios/after/flutter/report.json)·[Android 보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/android-gesture/after/flutter/report.json)의 `stylePassed`·`layoutPassed`·`behaviorPassed`·`checksCompleted`·전체 `passed`는 모두 `true`다. 링크/사진 결과 진입·완료 탭 고정·최대 스크롤 분기·추가 저장 없는 닫기를 확인했다. AFTER의 두 결과는 모두 최대 스크롤0px이므로 무스크롤 상태/마지막 안내 노출로 기록하고 실제 드래그 성공으로 보고하지 않는다. 본문 패딩24px·추가 여유 공간과 viewport/CTA 경계를 구분했으며 겹침은 없다.
  iPhone16/iOS18.6은 창393×852·DPR3·상하59/34px·탭/viewport top179px·제목259→211px·CTA top730px, Android13/API33 제스처는 약392.7×783.3·DPR2.75·24/0px·탭/viewport144px·제목224→176px·CTA top약695.273px다. 두 결과 모두 시작80→32px과 뒤따르는 모든 본문 anchor−48px을 확인하고 내부 크기/상대 간격/글자·헤더/탭/viewport/CTA를 유지했다. Figma 원본은 탭170px·제목202px으로 간격32px이며 OS 여백에 따른 절대좌표 차이를 원본 그대로 설명한다.
- [새4쌍 비교](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/comparison-document.html)·[비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/comparison-qa.json)는 변경 전→변경 후→현재 Figma D05/D09의 완전한3열4쌍·누락/조건 불일치0건·BEFORE 원본4장 불변·검사/fixture SHA일치·본문−48px·내부/CTA 유지·스크롤0에 한정한 위치 판정을 확인한다. 같은 데이터·1배율·키보드 숨김·스크롤0의 OS 원본을 사용하며 대체 디자인/과거 앱 캡처/이전 파일 원본을 넣지 않았다.
  새 AFTER 영상은 [iOS](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/ios/after/interaction.mp4)13.16초·1,111,623바이트와 [Android](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/android-gesture/after/interaction.mp4)15.313511초·951,268바이트다. [미디어 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/media-verification.json)는 두 원본의 전체 디코딩 종료코드0·오류로그0바이트·시작/중간/끝 및0.5초 간격 표본의 팝업 없음·결과 진입/선택/닫기 장면·원본 재인코딩 없음을 확인했다. BEFORE는 정적 촬영만 수행했고 이전 영상을 재사용하지 않는다. iOS 앱/Simulator와 Android 앱/Emulator 종료·데이터 보존, Android 원래 제스처 mode2/여섯 오버레이 일치·탐색 설정 변경0건·8768 포워딩 제거·기기 목록 비어 있음을 실행 기록에 남겼다.
- 재현 명령은 [프론트 README](../../frontend/README.md)의 저장 결과 상단 여백 절을 따른다. 완료는 결과 시작 여백에 한정하며 과거 ‘결과 상단80px 유지’는 당시 기록으로 보존하고 현재는32px을 적용한다. 사진 비율/잘림·미리보기 제목–출처 간격·카테고리 편집·결과 전체 배치는 계속 보류한다. 새 확대/3버튼/키보드 기기 촬영은 추가하지 않고 기존 확대 구현/자동 검사를 유지한다. 메모리 저장/사진 선택 대역·Flutter 합성 입력·실제 OS 화면을 운영 API·OAuth·실기기·원격 CI 검증과 구분하며 저장 화면 전체 맞춤 완료로 표시하지 않는다. 화면 증거·빌드 생성물·`AGENTS.md`는 제외하고 같은 `feature/figma-ui-alignment`에서 한 커밋으로 저장하며 푸시·PR은 하지 않는다.
- [최종 환경 정리](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/cleanup-verification.json)는 **18:30:08 UTC**에 iPhone16 Shutdown·adb/Emulator/qemu 프로세스0건·8767/8768 listener 없음·포워딩 제거·adb 서버 종료·데이터 보존을 확인했다. 임시 비교 서버는 시작하지 않았다. 비교 HTML의 JS 문법·36개 파일 경로·PNG 직접 시각 검사는 확인했으나 브라우저 상호작용 실행은 이번에 검증하지 않았으며 native 앱 실행/영상 성공과 구분한다.

## 원문 출처: docs/figma-ui-alignment-plan.md

<a id="b-12c32bca39e0bc5e"></a>

### 저장 결과 시작 여백 80→32px (2026-10-17, `d1f13d4` 기준·해당 범위 적용·검증 완료)

<a id="b-f4b56aad4fd3b75c"></a>

- 현재 파일 `svNWsTFh8Ws1Mpt8XQIcrN` / Page 1(`0:1`) > 261007(`111:3379`)의 D05 링크 결과 `111:4902`·D09 사진 결과 `111:4865`를 사용했다. 구현 직전 **2026-10-17 03:22:34~03:22:41 KST / 2026-10-16 18:22:34~18:22:41 UTC**에 각각 `get_design_context` 1회(총2회)로 컨텍스트와 375×812px 원본을 함께 확보했다. [조회 기록·원본 해시](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/figma/reference-manifest.json)에 출처를 남겼으며 호출 제한·fallback·이전261008 이미지 대체·Figma 누락은 없다.
- 제품 수정 전 검사·프리뷰를 32px 목표로 확장하고 데이터를 동결했다. [RED 결과](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/tests/focused-red-summary.json)는 실제 Pretendard·iOS/Android 테마×폭320/375px×1배율의 기존76건 중68통과·링크/사진 결과8건 실패다. 기존80px 차이만 재현했다. [BEFORE 게이트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/before-gate.json)를 **18:24:04 UTC**에 통과한 뒤 제품을 수정했다. 기준 제품 원본 불변·동결된 fixture/검사 해시·새 네이티브 원본4장을 확인했고 목표 레이아웃 실패는 촬영을 막지 않았다.
- 제품 변경은 공통 본문 패딩의 조건식 한 곳을 `const EdgeInsets.fromLTRB(16, 32, 16, 24)`로 통일한 것이다. 입력 화면32px은 유지하고 링크·사진 결과만80→32px로 바뀐다. 개별 절대좌표 보정 없이 본문 전체가 스크롤0에서48px 상승한다. 헤더·탭·viewport·하단 버튼·안전 영역·키보드 회피, 내부 글자·크기·간격과 API/저장 정책은 그대로다.
- 기존 `/base-style-scene?kind=link|photo`·`/base-style-run?resultsOnly=1`을 재사용했고 새 실행 경로는 추가하지 않았다. 프리뷰는 탭 하단·viewport·제목 경계, 실제 패딩·스크롤·시작 간격을 기록하고 전체 레이아웃 판정에 연결한다. **시작 간격32px 위치 검사는 스크롤0에서만** 적용한다. 최대 스크롤에서는 마지막 안내 노출·하단 패딩24px·버튼 겹침을 확인하며 스크롤을 임의로 초기화해 통과시키지 않는다.
- [집중76건](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/tests/base-typography-green.log)·[관련335건](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/tests/related-green.log)·[전체 Flutter953건](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/tests/full-test.log)이 모두 통과했다. [flutter analyze --no-pub](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/tests/analyze.log)는 문제 없음, [형식 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/tests/format-check.log)는 세 파일 변경0건이다. [실제 검사 명령·시간](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/automatic-checks.json)의 종료코드는 모두0(각9.47/23.60/80.77/6.30/0.81초)이며 D07 프레임·기존 확대·하단 배치·입력 보존 회귀를 삭제하거나 건너뛰지 않았다.

<a id="b-38ad5617f0f1d059"></a>

| 실행 구성 | 실제 OS 창·DPR·상단/하단 여백 | 탭 하단=viewport 시작 | 결과 제목 top 전→후 | 시작 여백 전→후 | 버튼 top/높이 전후 |
| --- | --- | --- | --- | --- | --- |
| iPhone16/iOS18.6 Simulator | 393×852px·3·59/34px | 179px 유지 | 259→211px | 80→32px | 730/56px 유지 |
| Android13/API33 제스처 Emulator | 약392.7×783.3px·2.75·24/0px | 144px 유지 | 224→176px | 80→32px | 약695.273/56px 유지 |

<a id="b-f3f44342814f8718"></a>

- [실측 표](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/top-gap-measurements.json)·[비교 조건·해시 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/comparison-qa.json)는 링크/사진4쌍에서 모든 본문 글자·geometry의 top−48px, 스타일·폭/높이·미리보기/카테고리 내부 간격 및 헤더·탭·viewport·CTA 불변을 확인한다. 기존 본문 최대폭375px을 유지한 실측이며 기기 창을375px로 강제하지 않았다. Figma375×812px의 OS 창·안전 여백 차이를 원본 그대로 표시한다. 설정된 하단 패딩24px은 유지하며 내용이 짧아 추가 빈 공간이 생기는 경우를 오류로 판정하지 않는다.
- [iOS AFTER report](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/ios/after/flutter/report.json)·[Android AFTER report](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/android-gesture/after/flutter/report.json)는 **각10개 기록(정적2+결과 전용8)**·프레임워크 오류0건, `checksCompleted`·`stylePassed`·`layoutPassed`·`behaviorPassed`·전체 `passed: true`다. 결과 진입·완료 탭 고정·1회 저장·추가 저장 없는 닫기를 확인했다. AFTER 링크/사진 모두 최대 스크롤0px이므로 **무스크롤 상태**로 기록하고 실제 드래그 성공으로 보고하지 않는다. 마지막 안내는 전체 노출되고 버튼과 겹치지 않는다.
- [새 변경 전→후→Figma 비교4쌍](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/comparison-document.html): [iOS 링크](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/comparison-ios-link.png)·[iOS 사진](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/comparison-ios-photo.png)·[Android 링크](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/comparison-android-gesture-link.png)·[Android 사진](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/comparison-android-gesture-photo.png). 같은 데이터·1배율·키보드 숨김·스크롤0·동결 fixture로 촬영했다. 전체 OS 원본을 등비축소해 나란히 배치했으며 자르기·OS 제거·위치 보정·대체 디자인은 없다. PNG4개를 직접 확인했고 [HTML 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/comparison-html-qa.json)는 JavaScript 구문·관련36경로·원본/상태 해시를 검증했다. 브라우저 런타임 실행은 수행하지 않았으며 위 검사를 브라우저 통과로 보고하지 않는다.
- AFTER 동작 영상은 [iOS13.16초](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/ios/after/interaction.mp4)·[Android15.313511초](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/android-gesture/after/interaction.mp4) 각1개다. [전체 디코딩·시각 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/media-verification.json)에서 원본 재인코딩 없이 전체 프레임 디코딩 오류0건·해시 불변을 확인했다. 0.5초 간격 샘플에서 링크 입력/결과·사진 선택/결과·닫기 장면을 직접 확인했다.
- [정리 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/cleanup-verification.json)는 iPhone16 Shutdown·Android Emulator/ADB 프로세스0·포워딩8768 제거·8767/8768 리스너 없음·원래 제스처 설정 일치·설정변경0건·사용자 데이터 보존을 확인했다. 임시 비교 서버는 시작하지 않았다. 메모리 저장/고정 사진 대역과 Flutter 합성 입력을 실제 OS 창에서 검증한 것이며 운영 API·OAuth·실기기·원격 CI의 증거는 아니다. 새 배율별·3버튼·키보드 기기 촬영은 추가하지 않았다.
- 이번 완료 표시는 **결과 시작 여백32px**에 한정한다. 사진 비율/잘림·미리보기 제목–출처 간격·카테고리 편집·결과 전체 배치는 계속 보류한다. 과거 절의 ‘결과 상단80px 유지’와 조회/검사/비교 기록은 당시 사실로 보존하며 현재 상태에 소급 적용하지 않는다. 화면 증거·빌드·`AGENTS.md`는 제외하고 한 커밋으로 저장한다. 푸시·PR은 하지 않는다.
