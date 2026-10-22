# 사진 선택 프레임 치수

- 최초 기록일: 2026-10-17
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-e4934a9d91d42826"></a>

현재 디자인 기준은 [허투루 Page 1의 261007](https://www.figma.com/design/svNWsTFh8Ws1Mpt8XQIcrN/?node-id=111-3379)입니다.
파일 키 `svNWsTFh8Ws1Mpt8XQIcrN`의 **[Page 1(`0:1`)](https://www.figma.com/design/svNWsTFh8Ws1Mpt8XQIcrN/?node-id=0-1) > 261007(`111:3379`)**을 사용합니다.
`1036398` 기준의 문서 전용 기준 전환은 `4d46dfa`에 저장했습니다. 당시 **2026-10-16 17:29:14~17:29:17 UTC(2026-10-17 02:29:14~02:29:17 KST)**에 Page 1 메타데이터를 한 번 조회해 화면 이름과 노드 대응을 확인했습니다.
[메타데이터 원본](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/page1-reference-transition-20261017/page1-metadata.xml)과 [조회 기록·노드 목록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/page1-reference-transition-20261017/reference-manifest.json)을 보존했습니다.
사용자가 전달한 URL의 `85:3222`는 이번 Page 1 메타데이터에 없어 기준 노드로 사용하지 않습니다. 중복된 화면 이름은 노드 ID와 설명으로 구분하며 불명확한 대응은 확인 필요로 남깁니다. 이번 구조 확인을 전체 화면의 시각 대조나 기기 검증으로 보고하지 않습니다.

<a id="b-dbbb85cc03960427"></a>

앞선 사진 프레임 작업의 [D07 사진 선택 후(`111:4814`)](https://www.figma.com/design/svNWsTFh8Ws1Mpt8XQIcrN/?node-id=111-4814)는 **2026-10-16 17:52:02~17:52:10 UTC(2026-10-17 02:52:02~02:52:10 KST)**에 컨텍스트·원본을 한 번 새로 조회했습니다. [정확한 원본](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/figma/D07.png)·[컨텍스트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/figma/D07-context.txt)와 [조회 시각·SHA256](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/figma/reference-manifest.json)을 보존했으며 호출 제한이나 보관 원본 fallback은 없었습니다.
`4d46dfa`를 기준으로 `d1f13d4`에 저장한 적용은 **D07 사진 선택 프레임의 내부 크기·16px 여백**에 한정합니다. 외곽 343×437px에서 내부 309×403px·사방 17px이던 차이를 재현하고, 외곽 테두리를 레이아웃에서 분리해 내부 311×405px·사방 16px로 수정했습니다. 당시 자동 검사와 iOS·Android AFTER 실행·새 2쌍 비교로 확인했습니다. 당시 미정이었던 사진 표시 정책은 이번 사용자 확정의 원본 비율·전체 보기로 별도 적용하며 과거 치수/잘림 검증 기록은 변경하지 않습니다. 카테고리 편집과 결과 전체 배치는 후속이며 저장 화면 전체 맞춤 완료로 표시하지 않습니다.

<a id="b-3e469cd2187b94db"></a>

### 사진 선택 프레임의 내부 크기·여백 (`4d46dfa` 기준, 해당 범위 적용·검증 완료)

<a id="b-a0c62db2f3a155cc"></a>

현재 Page 1 > 261007의 **D07 `111:4814`**에서 사진 선택 프레임만 맞춥니다.
`SelectedPhotoPreview`의 외곽 테두리를 `foregroundDecoration`으로 옮겨 명시적 패딩 16px에 테두리 1px가 더해지지 않도록 했습니다.
외곽 높이 437px·배경·모서리 8px·테두리 1px와 내부 테두리/클리핑은 유지합니다.
내부는 외곽 폭−32px·높이 405px·사방 16px이며, 375px 폭의 검사에서는 외곽 343×437px → 내부 311×405px입니다.
기기의 내부 폭은 실제 외곽 폭으로 계산하며 화면을 Figma의 375px로 강제하지 않습니다.
이미지 위치 계수 −0.4067·높이 계수 1.6607·`BoxFit.fill`과 선택/재선택·제출 입력·완료 탭 고정·닫기는 유지합니다.
이번 변경이 전체 사진 보기·채우기·잘림 정책을 결정한 것은 아닙니다.

<a id="b-20431a9cfe69fa56"></a>

```bash
# frontend/ — 실제 Pretendard, 1배율 geometry와 기존 스타일·동작 회귀
flutter test --no-pub test/save_base_typography_test.dart
flutter test --no-pub test/save_paste_layout_test.dart test/save_footer_layout_test.dart test/save_search_safe_area_test.dart test/save_scaled_layout_test.dart test/saved_content_confirmation_test.dart test/screenshot_asset_test.dart test/screenshot_asset_api_test.dart test/screenshot_auth_test.dart test/content_auto_category_test.dart test/share/manual_save_preservation_test.dart
flutter test --no-pub
flutter analyze --no-pub

# 제품 수정 전에는 before, 수정 후에는 after로 같은 fixture를 실행합니다.
flutter run --no-pub -d <device-id> -t test/support/save_result_preview.dart \
  --dart-define=SAVE_RESULT_PHASE=before
# Android는 포워딩 후 8768, iOS는 8767로 접근합니다.
adb -s "$EMULATOR_ID" forward tcp:8768 tcp:8767
curl 'http://127.0.0.1:8768/base-style-scene?kind=photo-selected'
# after 앱의 전용 1배율 geometry·사진 저장 동작 검사
curl 'http://127.0.0.1:8768/photo-frame-run'
```

<a id="b-d69549bb574c22ae"></a>

기존 68건에 **iOS/Android 테마 × 폭 320/375px × 사진 바이트/에셋 fallback의 8건**을 추가했습니다.
외곽·내부 `DecoratedBox`·`ClipRect`·`LayoutBuilder`와 이미지 경계, 사방 간격·배경·테두리·모서리·crop/fit·실제 이미지 소스를 검사합니다.
확대된 이미지가 clip보다 큰 기존 구성은 유지하며 이미지 자체의 containment를 요구하지 않습니다.
프리뷰도 같은 경계를 기록하고 새 프레임 검사를 `stylePassed`·`layoutPassed`·전체 `passed`에 합산합니다.
BEFORE의 목표치 실패는 실제 실패로 기록하되 원본 촬영을 막지 않으며 기존 기본/결과 전용/확대 실행을 유지합니다.

<a id="b-6d446b2f0110afa5"></a>

[수정 전 재현](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/tests/before-photo-frame-summary.json)은 **기존 68건 통과·새 8건만 실패**했습니다.
375px 폭에서는 내부 309×403px, 320px 폭에서는 254×403px이며 사방 17px입니다.
[변경 전 게이트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/before-gate.json)는 **17:57:12.927909 UTC**에 기준 제품·동결 fixture·새 OS 원본 2장을 확인했고,
[제품 수정](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/product-edit-start.json)은 **17:57:13.019530 UTC**에 시작했습니다.
처음 Android 촬영의 System UI ANR 상태는 `android-gesture/attempts/system-ui-anr`에 분리하고 정상 상태로 다시 촬영했습니다.
최초 SDK 캐시 쓰기 권한 오류도 `tests/environment-attempt-*`에 보존하며 재현 실패나 최종 성공으로 혼합하지 않습니다.

<a id="b-1fec4a667db88a23"></a>

[집중 76건](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/tests/base-typography-green.log)은 통과(로그 4초/명령 7.41초),
[관련 335건](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/tests/related-green.log)도 통과(로그 13초/명령 16.04초)했습니다.
[전체 Flutter 953건](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/tests/full-test.log)은 통과(로그 41초/명령 43.96초),
[정적 분석](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/tests/analyze.log)은 문제 없음(로그 3.4초/명령 4.25초)입니다.
[세 Dart 파일 형식 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/tests/format-check.log)는 변경 0건(로그 0.07초/명령 0.35초)이며
[실제 명령 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/automatic-checks.json)의 최종 종료 코드는 모두 0입니다.
기존 확대 자동 검사는 이번 관련/전체 실행에 포함하며 새로운 배율별·3버튼·키보드 기기 촬영은 추가하지 않습니다.

<a id="b-56c7b74f618494de"></a>

[iOS AFTER 실행](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/ios-after-driver-result.json)과
[Android AFTER 요약](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/android-gesture/after/device-summary.json)은 각 **기록 8건(정적/runner 캡처 2건·동작 6건)·프레임워크 오류 0건**이며
`stylePassed`·`layoutPassed`·`behaviorPassed`·`checksCompleted`·전체 `passed`가 모두 `true`입니다.
실제 사진 선택/재선택·탭 왕복 시 사진 바이트와 링크 초안/컨트롤러 보존·`other-photo.png`와 새 사진 바이트의 1회 제출·완료 탭 고정·닫기를 확인했습니다.
D07과 사진 결과 모두 최대 스크롤이 0px이므로 필요한 전체 영역 노출과 무스크롤 분기를 확인한 것이며 실제 드래그 성공으로 보고하지 않습니다.

<a id="b-eaafc24d60e41e75"></a>

| 실제 기기·창·안전 여백 | 외곽 크기·위치 (전/후 동일) | 내부 전 → 후 | 사방 전 → 후 |
| --- | --- | --- | --- |
| iPhone 16 / iOS 18.6, 393×852·DPR 3·상하 59/34px | 343×437px·left 25/top 246px | 309×403 → 311×405px | 17 → 16px |
| Android 13/API 33 제스처, 392.7×783.3·DPR 2.75·상하 24/0px | 343×437px·left 약24.864/top 211px | 309×403 → 311×405px | 17 → 16px |

<a id="b-ed4cc842cf031cd1"></a>

[새 2쌍 비교](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/comparison-document.html)는 **변경 전 → 변경 후 → Figma D07 원본** 순서입니다.
[비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/comparison-qa.json)는 Figma 누락/조건 불일치 0건·BEFORE 원본 2장 불변·동결 fixture 일치·외곽 크기/위치 보존·내부 가로/세로 각 2px 증가·사방 16px·기존 crop/fit 보존을 확인했습니다.
같은 데이터·1배율·키보드 숨김·스크롤 0의 OS 포함 원본을 사용하며 OS 창/안전 여백 차이를 제거하거나 원본을 잘라 맞추지 않습니다.
확대용 대체 디자인은 만들지 않았고 과거 `261008` 비교를 이번 Page 1 검증으로 사용하지 않습니다.

<a id="b-0e56ba6dabbe4a77"></a>

AFTER 영상은 [iOS](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/ios/after/interaction.mp4) **8.861667초·2,601,967바이트**,
[Android](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/android-gesture/after/interaction.mp4) **14.535733초·1,804,959바이트**입니다.
[iOS 미디어 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/ios-after-media-verification.json)는 전체 디코딩 종료 코드 0·오류 로그 0바이트와 시작/중간/끝 화면의 예기치 않은 팝업 없음을 확인했습니다.
iOS의 최초 기본 null muxer 검사는 가변 프레임 시각을 반올림해 duplicate DTS 경고를 냈습니다. 원본 영상을 바꾸지 않고 demux 시간 기준과 프레임 passthrough로 전체 디코딩을 다시 검증했습니다.
[Android 미디어 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/android-gesture/after/media-verification.json)도 같은 demux 시간 기준으로 전체 디코딩해 종료 코드 0·오류 로그 0바이트를 확인했습니다. [종합 미디어 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/media-verification.json)의 두 영상은 모두 `passed: true`이며 원본 재인코딩은 하지 않았습니다.
양 플랫폼 앱과 Simulator/Emulator를 종료하고 사용자 데이터를 보존했습니다. Android 탐색 설정 변경은 0건이며 원래 모드/오버레이 일치·임시 포워딩 없음·adb 기기 목록 비어 있음을 확인했습니다.
이번 완료 표시는 사진 선택 프레임 치수·여백에 한정하며 사진 비율/잘림·카테고리 편집·결과 전체 배치는 후속입니다.
메모리 저장/사진 선택 대역·Flutter 합성 입력·OS 화면 증거를 운영 API·OAuth·실기기·원격 CI와 구분합니다.
화면 증거·빌드 생성물·`AGENTS.md`는 Git에서 제외하고 푸시·PR은 하지 않습니다.

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-9184883523eb5b23"></a>

### 2026-10-17 — 사진 선택 프레임의 내부 크기·여백 (`4d46dfa` 기준, 해당 범위 적용·검증 완료)

<a id="b-2607696d2ead31c6"></a>

- 현재 디자인은 파일 `svNWsTFh8Ws1Mpt8XQIcrN`의 Page 1(`0:1`) > 261007(`111:3379`), D07 사진 선택 후(`111:4814`)다. 이번 완료 범위는 사진 선택 프레임의 크기·16px 여백이며 사진 전체 보기/채우기/잘림 정책·카테고리 편집·결과 전체 배치는 별도 미정으로 유지한다. 1배율 우선·기존 확대 구현/자동 검사·제출 입력 고정·완료 탭 고정·기존 OS 안전 영역 정책은 유지한다.
- [구현 직전 Figma 조회](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/figma/reference-manifest.json)는 **2026-10-16 17:52:02~17:52:10 UTC(2026-10-17 02:52:02~02:52:10 KST)**에 D07 컨텍스트와 정확한 원본을 한 호출로 새로 확보했다. 호출 제한이나 보관 원본 fallback은 없었다. [원본 PNG](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/figma/D07.png)의 SHA256은 `6d39065266bd00e128045fc1ec1eec7f5a40d4edb98ac75d1eaff56db133016b`로 앞선 정확한 원본과 같으며 [새 컨텍스트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/figma/D07-context.txt)와 조회 시각은 이번 기록으로 구분한다. 이전 `261008` D07 원본 미확보와 과거 앱 비교는 변경하지 않는다.
- 기존 68개 검사를 유지하고 실제 Pretendard·1배율·iOS/Android 테마·폭320/375px·사진 바이트/에셋 fallback의 8개 프레임 검사를 추가했다. 외곽/내부/clip/LayoutBuilder/이미지 실제 경계, 사방 간격, 배경·테두리1px·모서리8px·crop/fit와 소스를 검사한다. 이미지가 clip보다 큰 기존 표현은 의도된 확대 구조로 구분한다. 프리뷰의 새 경계 검사는 스타일·레이아웃·전체 판정에 합산하며 기존 기본·결과 전용·확대 runner는 유지한다. `/base-style-scene?kind=photo-selected`와 새 `/photo-frame-run`을 사용한다.
- [수정 전 재현](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/tests/before-photo-frame-summary.json)은 **기존68개 통과·새8개만 예상 실패**다. 375px 폭의 내부309×403px(목표311×405px), 320px 폭254×403px(목표256×405px)과 사방17px(목표16px)의 차이를 실제 render bounds로 확인했으며 나머지 표현 검사는 통과했다. 최초 SDK 캐시 권한 오류는 `tests/environment-attempt-*`에 별도 보존하고 권한을 확보한 재실행으로 실제 RED를 기록했다.
- [변경 전 게이트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/before-gate.json)는 **17:57:12.927909 UTC**에 `4d46dfa` 제품 불변·동결 fixture/검사·새 OS 원본2장을 확인했다. [제품 수정 시작](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/product-edit-start.json)은 **17:57:13.019530 UTC**다. Android 첫 System UI ANR 시도는 `android-gesture/attempts/system-ui-anr`에 격리한 뒤 정상 상태로 새로 촬영했다. iOS/Android BEFORE 모두 외곽343×437px·내부309×403px·사방17px을 확인했으며 정적 후보를 실제 기기 프리뷰에서 재현한 결과다. BEFORE 목표치 실패를 원본 촬영 중단으로 처리하지 않았다.
- 제품 변경은 `SelectedPhotoPreview` 외곽 테두리를 `foregroundDecoration`으로 옮겨 기존 명시적 패딩16px에 합산되지 않도록 한 것뿐이다. 외곽437px·배경/색상/모서리·내부 테두리/clip과 이미지 위치−0.4067·높이1.6607·`BoxFit.fill`을 유지한다. 내부는 외곽 폭−32px·높이405px·사방16px이며 실제 기기 화면을375px로 강제하지 않는다. 공개 생성자·콜백·API·데이터 모델과 저장/닫기 정책은 변경하지 않는다.
- [집중76개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/tests/base-typography-green.log)는 통과(로그4초/명령7.41초), [관련335개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/tests/related-green.log)도 통과(로그13초/명령16.04초)했다. [전체 Flutter953개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/tests/full-test.log)는 통과(로그41초/명령43.96초), [분석](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/tests/analyze.log)은 문제 없음(로그3.4초/명령4.25초)이다. [세 Dart 파일 형식 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/tests/format-check.log)는 변경0건(로그0.07초/명령0.35초)이고 [자동 검사 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/automatic-checks.json)의 최종 종료코드는 모두0이다. 기존 확대 자동 검사를 유지했으며 과거945개 성공을 이번953개의 실행으로 사용하지 않는다.
- [iOS AFTER](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/ios-after-driver-result.json)·[Android AFTER](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/android-gesture/after/device-summary.json)는 각 **기록8건(정적/runner 캡처2건·동작6건)·프레임워크 오류0건**이며 `stylePassed`·`layoutPassed`·`behaviorPassed`·`checksCompleted`·전체 `passed`가 모두`true`다. 사진 선택/재선택·탭 왕복 시 사진 바이트와 링크 초안/컨트롤러 유지·새 바이트/`other-photo.png`의1회 제출·완료 탭 고정·닫기를 확인했다. D07/사진 결과의 최대 스크롤은 모두0px이므로 필요한 전체 영역 노출·무스크롤 분기를 확인했으며 실제 드래그 성공으로 보고하지 않는다.
  양쪽 모두 외곽343×437px는 유지되고 내부309×403→311×405px·사방17→16px로 바뀌었다. iPhone16/iOS18.6은 창393×852·DPR3·상하59/34px·외곽left25/top246px, Android13/API33 제스처는392.7×783.3·DPR2.75·24/0px·left약24.864/top211px로 외곽 위치도 동일하다. OS 창/안전 여백 차이를 원본 그대로 구분한다.
- [새2쌍 비교](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/comparison-document.html)와 [비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/comparison-qa.json)는 변경 전→변경 후→현재 Figma D07 원본3열2쌍·누락/조건 불일치0건·BEFORE 원본2장 불변·동결 fixture 일치·외곽 크기/위치·crop/fit 유지·내부가로/세로+2px·16px 여백을 확인했다. 같은 데이터·1배율·키보드 숨김·스크롤0이며 OS 표시를 제거하거나 대체 디자인/이전 앱 캡처를 넣지 않았다.
  새 AFTER 영상은 [iOS](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/ios/after/interaction.mp4)8.861667초·2,601,967바이트, [Android](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/android-gesture/after/interaction.mp4)14.535733초·1,804,959바이트다. [iOS 미디어 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/ios-after-media-verification.json)는 전체 디코딩 종료코드0·오류로그0바이트·키프레임 팝업 없음을 확인했다. 최초 기본 null muxer의 duplicate DTS는 가변 프레임 시각 양자화 경고였으며 원본 변경 없이 demux 시간 기준·프레임 passthrough로 전체 디코딩을 재검증했다. [Android 미디어 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/android-gesture/after/media-verification.json)도 같은 시간 기준으로 전체 디코딩 종료코드0·오류로그0바이트를 확인했다. [종합 미디어 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/media-verification.json)의 두 영상 모두`passed: true`이며 원본 재인코딩은 하지 않았다. 양 플랫폼 앱·Simulator/Emulator 종료·데이터 보존을 확인했고 Android 탐색 설정 변경0건·원래 모드/오버레이 일치·임시 포워딩 없음·adb 기기목록 비어 있음으로 정리했다.
- 재현 명령은 [프론트 README](../../frontend/README.md)의 사진 선택 프레임 절을 따른다. 메모리 저장/사진 선택 대역·Flutter 합성 입력과 실제 OS 창을 사용하며 운영 API·OAuth·실기기·원격 CI는 검증 범위 밖이다. 새 배율별/3버튼/키보드 기기 촬영은 추가하지 않는다. 사진 비율/잘림·카테고리 편집·결과 전체 배치와 기존 보류 항목을 유지하고 저장 화면 전체 완료로 표시하지 않는다. 화면 증거·빌드 생성물·`AGENTS.md`는 제외하고 같은 `feature/figma-ui-alignment`에서 한 커밋으로 저장하며 푸시·PR은 하지 않는다.

## 원문 출처: docs/figma-ui-alignment-plan.md

<a id="b-df8fc0d9bb8430cb"></a>

- `4d46dfa` 기준 전환 문서 작업 시작 시 Page 1 메타데이터를 **1회** 조회했다. 요청은 **2026-10-17 02:29:14~02:29:17 KST / 2026-10-16 17:29:14~17:29:17 UTC**이며 페이지·섹션·화면/설명 프레임의 실제 ID와 이름을 확인했다. 구조 확인을 전체 화면의 시각·동작 검증으로 확대하지 않는다.
- 메타데이터 원본과 노드 대응은 Git 밖의 `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/page1-reference-transition-20261017/`에 `page1-metadata.xml`·`reference-manifest.json`으로 보관했다.
- D07 **사진 선택 후 `111:4814`**의 정확한 컨텍스트와 375×812px 원본은 앞선 확인에서 확보했다. 보관 확인 시각은 **2026-10-17 02:22:34 KST / 2026-10-16 17:22:34 UTC**이며 당시 문서 전환에서 이를 재사용했다. 출처와 파일은 같은 상위 경로의 `page1-reference-check-20261017/reference-manifest.json`·`D07-context.txt`·`D07.png`다. 이전 파일의 D07 `912:16551` 원본 미확보 기록은 아래 과거 기록에 그대로 남긴다.
- `4d46dfa`에서 D07 외곽 `111:4832` 343×437px·내부 `111:4833` 311×405px·간격16px과 코드의 309×403px·간격17px 차이를 정적 후보로 기록했다. 후속 치수 작업에서는 제품 수정 전 위젯 검사와 새 iOS/Android 원본의 실제 경계로 차이를 재현했다. 외곽 테두리만 `foregroundDecoration`으로 옮겨 명시적 패딩16px에 테두리 폭이 합산되지 않도록 수정했으며, 외곽437px·내부405px·내부 폭=외곽 폭−32px을 검사한다. 상세 실행 결과는 아래 이번 작업 기록을 따른다.
- 당시 프레임 작업의 D07 컨텍스트·원본은 **2026-10-17 02:52:02~02:52:10 KST / 2026-10-16 17:52:02~17:52:10 UTC**에 한 번의 `get_design_context` 호출로 함께 확보했다. 제한·fallback은 없었으며 원본 SHA256은 앞선 보관 원본과 같다. 현재 근거는 위 증거 상위 경로의 Git 밖 `save-photo-frame/figma/reference-manifest.json`·`D07-context.txt`·`D07.png`다.
- 앞선 치수 수정에서는 사진 전체 보기·채우기·확대/잘림 정책을 별도 미정으로 남겼다. 그 당시 기록은 보존한다. 이번 `b9f77ff` 기준 작업은 사용자 확정으로 D07의 실제 사진/에셋 fallback 모두 원본 비율의 전체 보기·중앙 정렬로 변경한다. 결과 사진의 중앙 cover·카테고리 편집과 구분하며 새 조회/검사·기기 근거는 아래 D07 전체 보기 기록을 따른다.
- `4d46dfa`의 기준 전환은 문서 세 개에 한정했고 당시 Flutter 검사·기기 실행·새 화면 촬영을 수행하지 않았다. 이후 이번 D07 작업의 검사·촬영은 아래 별도 기록으로 구분한다.
- `4d46dfa` 문서 검증에서 당시 화면표·중복 설명과 보류 목록의 고유 노드 **67개**가 보관 메타데이터에 존재함을 확인했다. 변경 행의 로컬 링크 **40회·고유 30경로**, D07 보관 파일의 SHA256, 과거 기기 검증·README 상세·진행 기록의 보존과 `git diff --check`를 확인했다.

<a id="b-0b9ec11aad513273"></a>

### D07 사진 선택 프레임의 내부 여백·크기 (2026-10-17, 해당 범위 적용·검증 완료)

<a id="b-687303f2e2cd20ba"></a>

- 기준은 `4d46dfa`, 현재 Page 1 >261007의 D07 `111:4814`다. 외곽343×437px·내부311×405px·간격16px의 컨텍스트와 원본을 **2026-10-16 17:52:02~17:52:10 UTC(2026-10-17 02:52:02~02:52:10 KST)**에 한 번의 호출로 함께 새로 확보했다. [조회 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/figma/reference-manifest.json)·[정확한 원본](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/figma/D07.png)·[컨텍스트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/figma/D07-context.txt)를 사용한다. 한도·fallback·대체 이미지는 없으며 이전 261008 D07 미확보 기록은 보존한다.
- 제품 수정 전 기존1배율 검사에 iOS/Android×폭320/375px×사진 바이트/에셋 fallback의8건을 추가했다. [재현 결과](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/tests/before-photo-frame-summary.json)는 기존68건 통과·새8건 예상 실패다. 375px에서 내부309×403px·간격17px, 320px에서 내부254×403px·간격17px을 재현했고 기존 테두리·모서리·clip·이미지 fit/확대 계수는 통과했다. 최초 SDK sandbox 실행 실패는 별도 환경 시도로 보존했다.
- 제품 수정 전에 두 플랫폼의 새 OS 원본을 촬영했다. [변경 전 게이트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/before-gate.json)는 **17:57:12 UTC**, [제품 수정 시작](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/product-edit-start.json)은 **17:57:13 UTC**다. 제품 원본 불변·동결 fixture와 검사 소스·새 원본2장 해시를 확인했다. Android 첫 촬영의 System UI ANR 팝업은 `android-gesture/attempts/system-ui-anr`에 실패로 격리하고 새로 촬영했다. 최종 비교에는 팝업이 없는 canonical 원본만 사용한다.
- 제품은 `SelectedPhotoPreview`의 외곽 테두리만 `foregroundDecoration`으로 이동했다. 배경·모서리8px·테두리1px·패딩16px·외곽높이437px, 내부 테두리/clip과 이미지 `BoxFit.fill`·top−0.4067·height1.6607은 유지한다. 공개 생성자·콜백·API·데이터 모델과 저장 정책은 변경하지 않았다.
- 프리뷰는 기존 `/base-style-scene?kind=photo-selected`를 정적 촬영에 재사용하고 `/photo-frame-run`만 추가했다. 실제 outer/inner/clip/LayoutBuilder/Stack/Image 경계와 사방 inset·기존 스타일/확대 계수를 기록하고 프레임 findings를 `targetLayoutPassed`·전체 판정에 연결했다. BEFORE 목표치 실패는 촬영을 차단하지 않고, AFTER는 실제 경계 통과를 요구한다. 기존 기본·결과 전용·확대 실행은 유지했다.
- [집중76건](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/tests/base-typography-green.log)·[관련335건](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/tests/related-green.log)·[전체 Flutter953건](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/tests/full-test.log)이 모두 통과했다. [전체 분석](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/tests/analyze.log)은 문제 없음, [세 파일 형식 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/tests/format-check.log)는 변경0건이다. [실제 검사 명령·시간](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/automatic-checks.json)은 각각7.41/16.04/43.96/4.25/0.35초·모두 종료코드0이며 이전 검사 수를 재사용하지 않았다.
- [iOS AFTER](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/ios/after/flutter/report.json)·[Android AFTER](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/android-gesture/after/flutter/report.json)는 각8개 기록(캡처2+동작6)·프레임워크 오류0건이고 `layoutPassed`·`stylePassed`·`behaviorPassed`·`checksCompleted`·전체 `passed`가 모두 `true`다. 사진 재선택·탭 왕복의 사진 바이트/링크 초안·컨트롤러 보존, 새 파일/바이트1회 제출·완료 탭 고정·추가 저장 없는 닫기를 확인했다. D07/사진 결과의 최대 스크롤은 양쪽0px이므로 드래그 성공으로 보고하지 않는다.

<a id="b-896cbd0519dd6fee"></a>

| 실행 구성 | 실제 창·DPR·OS 상단/하단 여백 | 외곽 전→후 | 내부 전→후 | 사방 간격 전→후 |
| --- | --- | --- | --- | --- |
| iPhone16/iOS18.6 Simulator | 393×852·3·59/34px | 343×437px 유지 | 309×403 →311×405px | 17 →16px |
| Android13/API33 제스처 Emulator | 약392.7×783.3·2.75·24/0px | 343×437px 유지 | 309×403 →311×405px | 17 →16px |

<a id="b-9949546478e514ce"></a>

- 외곽 위치도 iOS left25/top246px, Android left약24.864/top211px로 전후 같다. 기존 본문 최대폭375px을 유지한 실제 측정값이며 앱 창을375px로 강제하지 않았다. 375×812px Figma와 OS 창·안전 영역 차이는 원본 그대로 설명한다. 사진이 clip보다 크게 그려지는 기존 확대 구조는 의도된 잘림으로 구분하며 새로운 사진 표시 정책으로 확정하지 않는다.
- [변경 전→후→Figma 비교2쌍](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/comparison-document.html), [iOS 비교](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/comparison-ios.png)·[Android 비교](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/comparison-android-gesture.png), [실측 표](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/frame-measurements.json)·[조건/해시 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/comparison-qa.json)에 같은1배율·키보드숨김·스크롤0·데이터·fixture와 BEFORE 원본 불변을 기록한다. 표시는 원본 전체의 등비축소만 사용하며 OS 제거·화면 위치 보정·대체 디자인은 없다.
- 비교 PNG2개를 직접 열어 3열·OS 전체 원본·주석을 확인했다. [HTML 매체 경로 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/html-media-verification.json)는 내장 데이터의 이미지6개·영상2개 경로를 확인했다. 브라우저 미리보기 도구는 kernel assets 초기화 오류로 실행하지 못했으므로 브라우저 런타임 통과로 표시하지 않는다. 임시 비교 서버는 종료했으며 PNG·영상 원본 검증 결과와 구분한다.
- 새 AFTER 동작 영상은 [iOS](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/ios/after/interaction.mp4)·[Android](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/android-gesture/after/interaction.mp4) 각1개다. iOS [전체 디코딩·키프레임 확인](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/ios-after-media-verification.json)은8.861667초·2,601,967바이트·오류0건이다. 최초 null muxer의 가변 프레임 타임스탬프 경고는 별도 로그로 보존하고 원본 변경 없이 demux 시간 기준의 전체 디코딩으로 재검증했다. Android [매체 검증](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/android-gesture/after/media-verification.json)은14.535733초·1,804,959바이트·전체 디코딩 오류0건이며, [종합 영상 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/media-verification.json)에서 두 원본의 해시·디코딩 통과·재인코딩 없음을 확인했다.
- iOS 앱·Simulator 종료와 Android 앱·Emulator 종료·포워딩8768제거·원래 제스처/여섯 오버레이 일치·설정변경0건·사용자 데이터 보존을 확인했다. 실행은 고정 사진 선택기/메모리 저장 콜백과 Flutter 합성 입력의 native 대역 검증이며 운영 서버·OAuth·실기기·원격 CI 증거가 아니다. 새 배율별·3버튼·키보드 기기 촬영은 하지 않았다.
- 완료는 **D07 프레임의 내부 치수·여백**에 한정한다. 사진 전체 보기·채우기·잘림, 카테고리 편집·결과 전체 배치와 이전 보류 항목은 유지한다. 화면 증거·빌드 생성물·`AGENTS.md`는 Git에서 제외하며 푸시·PR은 하지 않는다.
