# 저장 결과 제목·출처 간격

- 최초 기록일: 2026-10-17
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-93677b560c0f30c6"></a>

앞선 `a6dfb4e` 기준 작업은 같은 D05·D09에서 **저장 결과 미리보기 제목–출처 간격 8→14px**만 맞추고 `63800e6`에 저장했습니다. 카드·이미지 크기와 자연 높이/중앙 정렬·글자 스타일·결과 시작 32px·하단 버튼/안전 영역은 유지하며 아래 새 검증 기록으로 구분합니다. 사진 비율/잘림·카테고리 편집·결과 전체 배치는 계속 후속입니다.
앞선 `63800e6` 기준 작업은 **미리보기 콘텐츠 제목 최대 폭만 컬럼보다8px 작게** 맞추고 `fec6b66`에 저장했습니다. 본문375px에서 제목139px·출처147px이며 출처 폭·간격14px·자연 높이·중앙 정렬은 유지합니다. 한 줄 전용 세로 배치·출처 폭 원본 기준은 후속 확인 항목이며 저장 화면 전체 맞춤 완료가 아닙니다.
앞선 `fec6b66` 기준 작업은 **미리보기 카드와 카테고리 제목 사이 시작 간격만30→32px**로 맞추고 `b61a47d`에 저장했습니다. 스크롤0에서 카테고리 전체가2px 내려가며 제목139px·출처147px·간격14px·글자와 하단 정책은 유지합니다. 안내의 제목 옆/아래 배치·편집과 저장 화면 전체 맞춤 완료를 뜻하지 않습니다.
앞선 `b61a47d` 기준 작업은 **링크 검증 문구→미리보기 간격28→32px·사진 파일명 박스→미리보기 간격28→16px**으로 맞추고 `c33a45d`에 저장했습니다. 스크롤0에서 이후 본문이 링크+4px/사진−12px 이동하며 앞 블록·제목139px/출처147px·내부 간격·글자·하단 정책은 유지합니다. 당시44px 파일명 구조와 Figma89px 이미지 구조는 달라 사진 전체 좌표 일치나 전체 맞춤 완료를 뜻하지 않습니다.
앞선 `c33a45d` 기준 작업은 **저장 결과의 사진 요약89px·원본 cover/중앙·사진 썸네일 테두리와 카테고리 자연 Wrap·정확한 SVG**를 적용·검증했습니다. 기존 문구·실제 분류/색상·입력/저장·완료 탭·하단 안전 영역은 유지합니다. 집중143/관련337/전체971건과 iOS·Android 각5상태/25기록·새10쌍 비교/영상을 확인했습니다. 완료는 결과 표현5상태·1배율이며 D07 표시·API 썸네일·편집과 저장 화면 전체 맞춤은 후속입니다.

<a id="b-b8e4bcdf8df4476f"></a>

### 저장 결과 미리보기 제목–출처 간격 (`a6dfb4e` 기준, 해당 범위 적용·검증 완료)

<a id="b-d48d679b30603aa6"></a>

Page 1 > 261007의 D05 링크 결과 `111:4902`·D09 사진 결과 `111:4865`에서 두 문단 사이 간격만 8→14px로 맞추는 범위입니다.
카드 최소 높이 116px·내부 여백 8px·썸네일 164×100px·이미지/텍스트 간격 16px과 기존 글꼴/행간·제목 최대 두 줄/출처 한 줄 말줄임을 유지합니다.
텍스트 묶음은 자연 높이와 세로 중앙 정렬을 유지하며 두 줄 공간 강제 확보·출처 절대 위치 고정은 추가하지 않습니다. 결과 시작 32px과 CTA/안전 영역·저장/완료 탭 정책은 그대로입니다.

<a id="b-43e26c1e0bfc37df"></a>

```bash
# frontend/ — 실제 Pretendard·1배율 및 기존 확대 회귀
flutter test --no-pub test/save_base_typography_test.dart test/save_scaled_layout_test.dart
flutter test --no-pub
flutter analyze --no-pub

# 같은 동결 fixture를 수정 전 before, 수정 후 after로 실행합니다.
flutter run --no-pub -d <device-id> -t test/support/save_result_preview.dart \
  --dart-define=SAVE_RESULT_PHASE=before
# Android는 8768→8767 포워딩, iOS는 8767을 사용합니다.
curl 'http://127.0.0.1:8768/base-style-scene?kind=link'
curl 'http://127.0.0.1:8768/base-style-scene?kind=photo'
curl 'http://127.0.0.1:8768/base-style-run?resultsOnly=1'
```

<a id="b-d22f87b24f4dba14"></a>

[수정 전 집중 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/tests/focused-red-summary.json)는 **실제 검사 122건 중 74통과·48실패**입니다.
1배율 24건과 기존 확대 24건에서 현재 8px과 목표 14px, 그로 인한 텍스트 묶음 높이 6px 차이를 재현했으며 무관한 실패는 0건입니다.
말줄임 없는 두 줄 사례를 링크/사진 × iOS/Android 테마 × 폭 320/375px의 8건으로 추가했습니다. 375px은 D05 원문, 320px은 너비에 맞춘 대역 제목을 사용하며 실제 문단이 두 줄이고 말줄임되지 않는지 검사합니다.
기기 정적 촬영은 기존 한 줄 제목 ‘저장 결과 확인’을 유지합니다. Figma 예제와 콘텐츠/줄 수가 다른 조건이므로 한 줄 제목의 절대 위치까지 원본과 일치한다고 보고하지 않습니다.

<a id="b-c867cdb4385834d9"></a>

[이번 Figma 재조회](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/figma/reference-manifest.json)는 **2026-10-17 03:44:39~03:44:45 UTC(12:44:39~12:44:45 KST)**에 현재 파일 D05·D09를 각각 한 번 호출해 컨텍스트와 375×812px 원본을 확보했습니다.
[D05 원본](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/figma/D05.png)·[D05 컨텍스트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/figma/D05-context.txt), [D09 원본](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/figma/D09.png)·[D09 컨텍스트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/figma/D09-context.txt)를 사용하며 호출 제한·fallback·누락은 없습니다. SHA256과 실제 조회 시각을 보존하고 이전 261008 원본은 사용하지 않습니다.

<a id="b-46914865af22e1ff"></a>

[BEFORE 게이트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/before-gate.json)는 **2026-10-17 03:50:48 UTC(12:50:48 KST)**에 기준 `a6dfb4e` 제품 불변·검사/fixture 동결·새 OS 원본 4장을 확인했습니다.
양 플랫폼의 링크/사진은 모두 간격 8px·텍스트 묶음 높이 54px·카드 116px·제목/출처 각 한 줄·스크롤/최대 스크롤 0px·결과 시작 32px입니다. `stylePassed: true`·목표 `layoutPassed: false`·프레임워크 오류 0건이며 실패 판정이 정적 촬영을 막지 않습니다.
iPhone 16/iOS 18.6은 창 393×852px·DPR3·상하 안전 여백 59/34px, Android 13/API33 제스처는 약 392.7×783.3px·DPR2.75·24/0px입니다. 화면 폭은 원본대로 유지하며 본문의 최대 375px와 구분합니다.
제품 수정은 이 게이트 뒤 제목/출처 사이 `SizedBox(height: 8)` 한 곳을 `14`로 변경한 것뿐입니다.

<a id="b-5a0b1d1e7d291b15"></a>

[iOS 초기 환경 시도](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/ios/attempts/xcode-first-launch.json)는 Xcode가 요구한 CoreSimulator 1174.9.2와 기존 1171.7 차이로 자동 최초 준비가 실행되어, 첫 기기 목록/정리 명령이 각각 120초/60초 시간 초과했습니다. 최초 시도는 캡처 0장이고 제품은 그대로였습니다.
표준 Xcode 진단에서 `Install Succeeded`와 버전 갱신 후 정상 복구한 뒤 표준 `xcrun simctl`로 BEFORE를 다시 촬영했습니다. 우회 촬영·사용자 데이터 초기화·수동 설정 변경은 하지 않았으며 환경 실패와 앱 프레임워크 오류 0건을 구분합니다.

<a id="b-18fc472baf66dd36"></a>

[집중 84건](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/tests/base-typography-green.log)은 통과(12.39초), [관련 회귀 335건](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/tests/related-green.log)도 통과(22.39초)했습니다. 새 말줄임 없는 두 줄 8건과 기존 확대·D07 프레임·상단 32px·하단 배치·입력 보존 검사를 유지합니다.
[전체 Flutter 961건](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/tests/full-test.log)은 통과(59.95초), [정적 분석](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/tests/analyze.log)은 문제 없음(6.85초), [네 Dart 파일 형식 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/tests/format-check.log)는 변경 0건(0.39초)입니다. [이번 자동 검사 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/automatic-checks.json)의 종료 코드는 모두 0이며 과거 성공을 이번 실행으로 대신하지 않습니다.
[BEFORE 빌드](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/before-build.json)와 [AFTER 빌드](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/final-implementation.json)는 양 플랫폼 모두 성공했습니다. AFTER Android는 14.58초·iOS는 89.39초이며 동결 fixture/두 검사 SHA와 실제 제품·바이너리 SHA를 보존합니다. 빌드 성공과 기기 실행 결과는 구분합니다.

<a id="b-64017727b8490055"></a>

Android 첫 AFTER 시도는 앱 보고서 10건이 통과했어도 원본 직접 검사에서 System UI 응답 없음 팝업이 확인되어 [환경 시도](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/android-gesture/attempts/system-ui-anr-first-after)에 원본/보고서/영상을 함께 격리했습니다. 해당 영상·캡처를 성공 증거로 사용하지 않습니다.
같은 APK/fixture/AVD와 원래 탐색 설정을 유지하고, 빌드/테스트 종료·iOS 종료 뒤 Android 단독 실행으로 다시 촬영했습니다. 최종 원본 2장과 영상에 OS 팝업이 없음을 직접 확인한 자료만 아래 성공 증거로 채택합니다.

<a id="b-6eb5efba847f992a"></a>

최종 [iOS 실행](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/ios-after-driver-result.json)·[Android 실행](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/android-gesture/after/driver-result.json)은 각각 **기록 10건·프레임워크 오류 0건**입니다.
[iOS 보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/ios/after/flutter/report.json)·[Android 보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/android-gesture/after/flutter/report.json)의 `stylePassed`·`layoutPassed`·`behaviorPassed`·`checksCompleted`·전체 `passed`는 모두 `true`입니다. 결과 진입·완료 탭 고정·추가 저장 없는 닫기를 확인했으며 두 결과의 최대 스크롤은 모두 0px이므로 무스크롤 상태/마지막 안내 노출로 기록합니다. 실제 드래그 성공으로 보고하지 않습니다.

<a id="b-b29b7ba72d5f1ae5"></a>

[실측 표](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/preview-gap-measurements.json)에서 네 결과 모두 간격 **8→14px**, 텍스트 묶음 **54→60px**, 제목 **−3px**·출처 **+3px**와 중앙 정렬을 확인했습니다.
카드 343×116px·이미지 164×100px·카테고리 행 343×55px·이미지/텍스트 16px·미리보기 제목/카드 16px·결과 시작 32px과 나머지 본문/헤더/탭/viewport/CTA·글자는 유지됐습니다.

<a id="b-f936e5a442812363"></a>

| 기기·결과 | 제목 top 변경 전→후 | 출처 top 변경 전→후 |
| --- | --- | --- |
| iOS 링크 | 413→410px | 445→448px |
| iOS 사진 | 384→381px | 416→419px |
| Android 링크 | 378→375px | 410→413px |
| Android 사진 | 349→346px | 381→384px |

<a id="b-7cbca8f20c2f53da"></a>

본문 하단 명시적 패딩 24px과 viewport의 추가 빈 공간을 구분하며 마지막 안내는 모두 완전히 노출되고 CTA와 겹치지 않습니다. 실제 OS 창/안전 영역은 원본 그대로이며 Figma 375×812px에 맞추려고 화면을 자르거나 보정하지 않습니다.
[완전한 3열 비교 4쌍](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/comparison-document.html)은 **변경 전 → 변경 후 → Figma 기본 원본** 순서입니다. [비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/comparison-qa.json)는 누락/조건 불일치 0건·BEFORE 원본 불변·동결 검사/fixture SHA 동일·간격/이동량과 나머지 배치 유지를 확인했습니다.
직접 볼 수 있는 비교는 [iOS 링크](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/comparison-ios-link.png)·[iOS 사진](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/comparison-ios-photo.png)·[Android 링크](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/comparison-android-gesture-link.png)·[Android 사진](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/comparison-android-gesture-photo.png)입니다. 촬영은 모두 같은 데이터·1배율·키보드 숨김·스크롤 0입니다. 한 줄 대역과 두 줄 Figma 예제의 간격만 대조하며 제목 절대 위치의 일치를 주장하지 않습니다.

<a id="b-2d098b2e3423de6e"></a>

새 AFTER 영상은 [iOS](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/ios/after/interaction.mp4) **9.65초·1,176,329바이트**, [Android](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/android-gesture/after/interaction.mp4) **14.441633초·925,712바이트**입니다.
[미디어 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/media-verification.json)는 원본 전체 디코딩 종료 코드 0·오류 로그 0바이트·원본 SHA 불변을 확인했습니다. 0.5초 간격 iOS 19개·Android 29개 표본을 직접 검사해 결과 진입/탭 유지/닫기 장면과 OS 팝업 없음을 확인했습니다. 첫 Android 환경 실패 영상과 과거 영상은 사용하지 않습니다.
[최종 환경 정리](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/cleanup-verification.json)는 **2026-10-17 03:58:28 UTC(12:58:28 KST)**에 iPhone 16 Shutdown·Emulator/adb/qemu/Xcode 최초 준비 프로세스 0건·8767/8768 listener 없음·포워딩 제거·원래 제스처 mode2/설정 변경 0건·사용자 데이터 보존을 확인했습니다. 임시 비교 서버는 시작하지 않았습니다.
비교 HTML의 JS 문법·참조 31개 경로와 PNG 직접 시각 검사는 확인했으나 브라우저 상호작용 실행은 이번에 검증하지 않았습니다. native 앱 실행·영상 성공과 구분합니다. 메모리 저장/사진 선택 대역·Flutter 합성 입력을 사용했으며 운영 API·OAuth·실기기·원격 CI는 이번 검증 범위가 아닙니다.
화면 증거·빌드 생성물·`AGENTS.md`는 Git에서 제외하고 같은 `feature/figma-ui-alignment`에서 한 커밋으로 저장하며 푸시·PR은 하지 않습니다. 이전 절의 성공/촬영/조회 시각은 당시 기록으로 보존합니다.
과거 절의 제목–출처 8px 유지 기록은 당시 범위로 보존하며 현재 간격은 이 절의 14px을 따릅니다. 이번 완료 범위는 두 문단 사이 간격에 한정합니다. 사진 비율/잘림·카테고리 편집·결과 전체 배치·한 줄 전용 Figma 디자인 미확인은 유지하고 저장 화면 전체 완료로 표시하지 않습니다.

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-abd9fdb66f03f824"></a>

### 2026-10-17 — 저장 결과 미리보기 제목–출처 간격 (`a6dfb4e` 기준, 해당 범위 적용·검증 완료)

<a id="b-eb72e2984e95f310"></a>

- 기준은 현재 파일 `svNWsTFh8Ws1Mpt8XQIcrN`의 Page 1(`0:1`) > 261007(`111:3379`), D05 링크 결과(`111:4902`)·D09 사진 결과(`111:4865`)다. 이번 대상은 두 문단 사이 간격 8→14px이며 카드 최소116px·내부8px·썸네일164×100px·이미지/텍스트16px·글꼴/행간·줄 수/말줄임·자연 높이/중앙 정렬을 유지한다. 결과 시작32px·하단 버튼/안전 영역·제출 입력/완료 탭 고정·저장/닫기와 공개 API/모델을 변경하지 않는다.
- 실제 Pretendard를 사용한 [수정 전 집중 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/tests/focused-red-summary.json)는 **122건 중74통과·48실패**다. 1배율24건·기존 확대24건에서 기존8px과 목표14px, 텍스트 묶음 높이6px 차이만 실패했으며 무관 실패는0건이다. 말줄임 없는 두 줄 사례8건을 추가했다.375px은 D05 원문,320px은 대역 제목을 사용해 링크/사진·iOS/Android에서 실제 두 줄·말줄임 없음과 기존 카드/중앙 정렬을 검사한다. 두 검사 소스를 포맷/동결했으며 제품 수정은 새 BEFORE 원본4장·기준 제품 불변 게이트를 확인한 뒤 수행했다.
- 새 기기 촬영은 기존 한 줄 제목 ‘저장 결과 확인’과 고정 데이터를 유지한다. Figma 예제와 다른 콘텐츠/줄 수이므로 절대 위치 전체의 일치를 주장하지 않는다. 새 경로 없이 기존 `/base-style-scene?kind=link|photo`·`/base-style-run?resultsOnly=1`을 재사용하며 새 배율별/3버튼/키보드 기기 촬영은 추가하지 않는다. 기존 확대 자동 검사와 D07/상단32px/하단/입력 보존 회귀는 유지한다.
- [이번 Figma 재조회](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/figma/reference-manifest.json)는 **2026-10-17 03:44:39~03:44:45 UTC(12:44:39~12:44:45 KST)**에 현재 파일 D05/D09를 각각 한 번 호출해 컨텍스트와 정확한375×812px 원본을 확보했다. 호출 제한·fallback·누락은 없으며 새 원본/컨텍스트의 SHA256·실제 조회 시각을 보존한다. 현재 Page1 보관본과 원본 SHA가 같아도 이번 새 조회로 구분하고 이전261008 이미지를 사용하지 않는다.
- [BEFORE 게이트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/before-gate.json)는 **2026-10-17 03:50:48 UTC(12:50:48 KST)**에 `a6dfb4e` 제품 불변·검사/fixture 동결·새 OS 포함 원본4장을 확인했다. 링크/사진 모두 간격8px·텍스트 묶음54px·카드116px·제목/출처 각 한 줄·스크롤/최대 스크롤0px·시작32px이며 스타일 통과·목표 레이아웃 실패·프레임워크 오류0건이다. iPhone16/iOS18.6은 창393×852·DPR3·안전 여백59/34px, Android13/API33 제스처는 약392.7×783.3·DPR2.75·24/0px이다. 제품은 이 게이트 뒤 제목/출처 사이 `SizedBox` 한 곳만8→14px로 변경했다.
- [iOS 초기 환경 시도](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/ios/attempts/xcode-first-launch.json)는 Xcode wrapper가 요구한 CoreSimulator1174.9.2와 기존1171.7 차이로 자동 최초 준비가 실행돼 첫 기기 목록120초·정리60초 시간 초과를 기록했다. 최초 캡처0장·제품 불변 상태였다. 표준 Xcode 진단에서 `Install Succeeded`와 버전 갱신을 확인한 뒤 표준 `xcrun simctl` 재시도로 BEFORE를 확보했다. 직접 native 읽기 진단만 했으며 우회 촬영·사용자 데이터 초기화·수동 설정 변경은 없었다. 환경 실패와 앱 프레임워크 오류0건을 구분한다.
- [집중84건](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/tests/base-typography-green.log)은 통과(12.39초), [관련335건](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/tests/related-green.log)도 통과(22.39초)했다. [전체Flutter961건](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/tests/full-test.log)은 통과(59.95초), [정적 분석](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/tests/analyze.log)은 문제 없음(6.85초), [네 Dart 파일 형식 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/tests/format-check.log)는 변경0건(0.39초)이다. [이번 자동 검사 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/automatic-checks.json)의 종료코드는 모두0이며 기존 확대·D07 프레임·상단32px·하단/입력 보존 검사를 유지한다. 이전953건 성공을 이번961건으로 바꾸지 않는다. [BEFORE빌드](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/before-build.json)·[AFTER빌드](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/final-implementation.json)는 iOS/Android 각각 성공했고 AFTER Android14.58초·iOS89.39초와 실제 제품/바이너리/동결 fixture·두 검사 SHA를 기록했다. 빌드 성공을 native 실행 성공으로 대신하지 않는다.
- Android 첫 AFTER는 자동 보고서10건 통과였으나 OS 원본 직접 검사에서 System UI 응답 없음 팝업이 확인돼 [환경 시도](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/android-gesture/attempts/system-ui-anr-first-after)에 원본/보고서/영상을 격리했다. 해당 자료는 성공 증거로 채택하지 않는다. 같은 APK/fixture/AVD·탐색 설정을 유지하고 빌드/테스트 및 iOS 종료 뒤 Android 단독으로 재촬영했으며 실제 정상 원본2장/영상만 최종 채택했다. 앱 프레임워크 오류0건을 OS 화면 정상의 대체 증거로 쓰지 않는다.
- 최종 [iOS 실행](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/ios-after-driver-result.json)·[Android 실행](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/android-gesture/after/driver-result.json)은 각각 **기록10건·프레임워크 오류0건**이다. [iOS 보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/ios/after/flutter/report.json)·[Android 보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/android-gesture/after/flutter/report.json)의 `stylePassed`·`layoutPassed`·`behaviorPassed`·`checksCompleted`·전체 `passed`는 모두`true`다. 결과 진입·완료 탭 고정·추가 저장 없는 닫기를 확인했으며 링크/사진의 최대 스크롤은 모두0px이므로 무스크롤 상태·마지막 안내 노출로 기록하고 실제 드래그 성공으로 보고하지 않는다.
- [실측 표](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/preview-gap-measurements.json)는 네 결과 모두 간격8→14px·텍스트 묶음54→60px·제목−3px/출처+3px·중앙 정렬과 나머지 좌표/크기/간격/글자 유지를 확인했다. iOS 링크 제목413→410px/출처445→448px·사진384→381px/416→419px, Android 링크378→375px/410→413px·사진349→346px/381→384px이다. 카드343×116px·이미지164×100px·카테고리 행343×55px·이미지/글자16px·미리보기 제목/카드16px·결과 시작32px·본문 명시적 하단24px과 헤더/탭/viewport/CTA는 유지했다. 하단 패딩과 viewport의 추가 빈 공간을 구분하며 마지막 안내는 완전히 노출되고 버튼과 겹치지 않는다.
- [새3열4쌍 비교](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/comparison-document.html)·[비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/comparison-qa.json)는 변경 전→변경 후→현재 Figma D05/D09 원본 순서의 완전한4쌍·누락/조건 불일치0건·BEFORE 원본 불변·검사/fixture SHA동일·간격/위치 변화와 나머지 배치 유지를 확인했다. 비교 PNG4장을 직접 확인했으며 OS 팝업은 없다. 촬영은 같은 데이터·1배율·키보드 숨김·스크롤0의 새 OS 원본이고 대체 화면을 만들지 않았다. 원본 창/안전 영역을 그대로 표시하며 한 줄 대역과 두 줄 Figma 예제의 간격만 대조하고 제목 절대 위치의 일치를 주장하지 않는다.
- 새 AFTER 영상은 [iOS](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/ios/after/interaction.mp4)9.65초·1,176,329바이트, [Android](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/android-gesture/after/interaction.mp4)14.441633초·925,712바이트다. [미디어 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/media-verification.json)는 두 원본 전체 디코딩 종료코드0·오류로그0바이트·원본 SHA불변을 확인했다. 0.5초 간격 iOS19개·Android29개 표본 직접 검사에서 결과 진입/탭 유지/닫기 장면과 OS 팝업 없음을 확인했다. 첫 Android 환경 실패 영상과 과거 영상은 사용하지 않는다.
- [최종 환경 정리](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/cleanup-verification.json)는 **2026-10-17 03:58:28 UTC(12:58:28 KST)**에 iPhone16 Shutdown·Emulator/adb/qemu/Xcode 최초 준비 프로세스0건·8767/8768 listener 없음·포워딩 제거·원래 제스처 mode2/설정 변경0건·사용자 데이터 보존을 확인했다. 임시 비교 서버는 시작하지 않았다. 비교 HTML의 JS 문법·참조31개 경로·PNG 직접 시각 검사는 확인했으나 브라우저 상호작용 실행은 이번에 검증하지 않았다. native 앱 실행/영상과 구분하며 메모리 저장/사진 선택 대역·Flutter 합성 입력 검증을 운영 API·OAuth·실기기·원격 CI 증거로 사용하지 않는다.
- 이번 완료 범위는 제목–출처 간격에 한정한다. 과거8px 유지 기록과 앞선 작업의 성공/조회/촬영 시각은 보존하고 현재 간격은14px이다. 사진 비율/잘림·카테고리 편집·결과 전체 배치·한 줄 전용 Figma 미확인은 유지하며 저장 화면 전체 완료로 표시하지 않는다. 화면 증거·빌드 생성물·`AGENTS.md`는 제외하고 같은 `feature/figma-ui-alignment`에서 한 커밋으로 저장하며 푸시·PR은 하지 않는다.

## 원문 출처: docs/figma-ui-alignment-plan.md

<a id="b-17a4646ced909003"></a>

### 저장 결과 미리보기 제목–출처 간격 8→14px (2026-10-17, `a6dfb4e` 기준·해당 범위 적용·검증 완료)

<a id="b-759900c75427e735"></a>

- 현재 파일 `svNWsTFh8Ws1Mpt8XQIcrN` / Page 1(`0:1`) > 261007(`111:3379`)의 D05 링크 결과 `111:4902`·D09 사진 결과 `111:4865`를 사용했다. **2026-10-17 12:44:39~12:44:45 KST / 03:44:39~03:44:45 UTC**에 각 `get_design_context` 1회(총2회)로 컨텍스트와 375×812px 원본을 함께 새로 확보했다. [조회·원본 해시](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/figma/reference-manifest.json)의 현재 파일 원본이며 제한·fallback·누락·이전261008 이미지 대체는 없다.
- 제품 수정 전 1배율·기존 확대 검사와 프리뷰를14px 목표로 갱신·동결했다. [최종 RED](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/tests/focused-red-summary.json)는 실제122건 중74통과·48실패(1배율24·기존 배율24)이며 현재8px과 목표14px 및 자연 높이6px 차이만 재현했다. 새 말줄임 없는 두 줄 사례8건을 확인했다. 폭375px은 D05 제목,320px은 짧은 고정 제목을 사용한다. D09 예제 문구는 Flutter375px에서 한 줄이어서 두 줄 대역으로 가정하지 않는다.
- [BEFORE 게이트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/before-gate.json)는 **03:50:48 UTC / 12:50:48 KST**에 제품이 `a6dfb4e`와 같고 검사2개·fixture가 동결된 상태에서 새 네이티브 원본4장을 확인했다. 양 플랫폼 링크/사진 모두 간격8px·텍스트 묶음54px·카드116px·제목/출처1줄·시작 여백32px·스타일 통과·목표 레이아웃 실패·프레임워크 오류0건이다. 목표 실패는 촬영을 막지 않았다. 제품 수정은 이 게이트 이후에 수행했다.
- 제품 diff는 `SavedContentConfirmation`의 미리보기 제목과 출처 사이 `SizedBox` 한 곳의8→14px뿐이다. 카드 최소116px·내부8px·이미지164×100px·이미지/텍스트16px·제목2줄/출처1줄 말줄임·글자·자연 높이·중앙 정렬과 다른 본문 배치를 유지한다. 두 줄 공간 강제 확보·출처 위치 고정·개별 좌표 보정은 추가하지 않는다. 공개 생성자·콜백·API·모델·저장 입력·완료 탭 고정·닫기·시작32px·하단/키보드 정책도 그대로다.
- 프리뷰는 기존 scene와 `resultsOnly=1` runner를 재사용하고 실제 문단 간격·줄 수·경계·자연 높이(제목 높이+출처 높이+14px)를 레이아웃/전체 판정에 연결했다. 새 실행 경로는 없다. 실제 `RenderParagraph` 선택 영역의 서로 다른 행을 줄 수로 기록하지만 선택 상자의 미세한 초과나 의도된 말줄임을 글리프 잘림으로 판정하지 않는다. 기기 데이터의 제목 ‘저장 결과 확인’·출처·이미지·제출 입력은 전후 동일하다.
- [집중84건](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/tests/base-typography-green.log)·[관련335건](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/tests/related-green.log)·[전체 Flutter961건](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/tests/full-test.log)이 모두 통과했다. [분석](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/tests/analyze.log)은 문제 없음, [형식 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/tests/format-check.log)는4파일 변경0건이다. [실행 명령·실제 시간](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/automatic-checks.json)의 종료코드는 모두0(각12.39/22.39/59.95/6.85/0.39초)이며 기존 확대·상단32px·D07 프레임·하단 배치·입력 보존 검사를 유지했다. [BEFORE 빌드](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/before-build.json)·[AFTER 빌드](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/final-implementation.json)도 양 플랫폼 모두 성공했고 검사/fixture SHA는 전후 같다.
- iOS 최초 시도는 [Xcode 초기화 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/ios/attempts/xcode-first-launch.json)에 환경 실패로 구분했다. Xcode의 `simctl` wrapper가 CoreSimulator1174.9.2를 요구하고 기존 버전1171.7에서 초기화를 실행하면서 목록120초·정리60초 대기가 발생했다. 표준 진단 명령의 `Install Succeeded`와 서비스 버전 전환 후 같은 표준 `xcrun simctl`로 BEFORE/AFTER를 촬영했다. 실제 native 바이너리는 읽기 진단만 했고 우회 촬영·기기 데이터 초기화·제품 수정으로 해결하지 않았다. 이 시도에서 원본은0장이고 앱 Flutter 오류와 구분한다.

<a id="b-1ff9096892e5f090"></a>

- Android 첫 AFTER는 Flutter 보고서10개가 통과했어도 실제 OS 원본에 System UI ANR 팝업이 있어 정상 촬영으로 채택하지 않았다. [실패 시도 전체](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/android-gesture/attempts/system-ui-anr-first-after)에 원본/보고서/영상을 보존하고 동일 APK·데이터·AVD로 단독 재촬영했다. 부팅 안정화·촬영 직후 native 계층·원본 딤 검사와 직접 시각 QA로 최종 정상 원본만 채택했다. [최종 Android 시각 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/android-gesture/native-visual-qa.json)는 팝업0건이며 탐색 설정 변경·앱/fixture 변경·데이터 초기화는 없다. OS 환경 시도를 앱 프레임워크 오류0건과 구분한다.
- [iOS AFTER](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/ios/after/flutter/report.json)·[Android 최종 AFTER](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/android-gesture/after/flutter/report.json)는 각10개 기록(정적2+결과 전용8), 프레임워크 오류0건이며 `stylePassed`·`layoutPassed`·`behaviorPassed`·`checksCompleted`·전체 `passed`가 모두 `true`다. 결과 진입·완료 탭 고정·1회 저장·추가 저장 없는 닫기를 확인했다. 링크/사진 모두 최대 스크롤0px이므로 무스크롤 상태로 기록하고 드래그 성공으로 보고하지 않는다. 마지막 안내 전체 노출·하단 패딩24px·버튼 비중첩도 확인했다.

<a id="b-25f0f154bcf772e5"></a>

| 실행 구성·1배율 | 제목 top 전→후 | 출처 top 전→후 | 문단 간격 전→후 | 묶음 높이 전→후 |
| --- | --- | --- | --- | --- |
| iPhone16/iOS18.6·링크 | 413→410px | 445→448px | 8→14px | 54→60px |
| iPhone16/iOS18.6·사진 | 384→381px | 416→419px | 8→14px | 54→60px |
| Android13/API33 제스처·링크 | 378→375px | 410→413px | 8→14px | 54→60px |
| Android13/API33 제스처·사진 | 349→346px | 381→384px | 8→14px | 54→60px |

<a id="b-571491ead54afc1c"></a>

- [실측 표](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/preview-gap-measurements.json)·[비교 조건/해시 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/comparison-qa.json)에서 카드343×116px·이미지164×100px·텍스트 묶음 중앙을 유지하고 제목−3px·출처+3px 외 모든 본문/카테고리·헤더·탭·viewport·CTA 경계와 글자/다른 간격이 동일함을 확인했다. iOS 실제 창393×852·DPR3·상하59/34px, Android 약392.7×783.3·DPR2.75·상하24/0px이며 기존 본문 최대폭375px을 유지한다. 기기 창을 Figma375×812px로 강제하거나 OS 영역을 제거하지 않는다.
- [변경 전→변경 후→Figma 비교4쌍](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/comparison-document.html): [iOS 링크](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/comparison-ios-link.png)·[iOS 사진](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/comparison-ios-photo.png)·[Android 링크](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/comparison-android-gesture-link.png)·[Android 사진](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/comparison-android-gesture-photo.png). 원본 전체의 등비축소만 사용했고 현재 파일의 정확한 Figma 누락0건·조건 차이0건·BEFORE 원본과 동결 소스 SHA 불변을 확인했다. 앱 제목은 한 줄, Figma는 두 줄 예제이므로 절대 제목/출처 위치까지 같다고 판정하지 않는다. 한 줄 전용 디자인은 미확인 상태이며 두 줄·긴 제목은 위젯 검사에서 확인한다. root가 PNG4개를 직접 확인했고 [HTML 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/comparison-html-qa.json)는 내장 JSON·JS 문법·로컬31경로·원본 해시를 통과했다. 브라우저 런타임 실행은 수행하지 않았다.
- AFTER 영상 [iOS](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/ios/after/interaction.mp4)는9.65초·1,176,329바이트, [Android](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/android-gesture/after/interaction.mp4)는14.441633초·925,712바이트다. [전체 디코딩·시각 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/media-verification.json)에서 두 원본 재인코딩 없이 디코딩 종료0·오류로그0바이트·해시 불변을 확인했다. 0.5초 간격의 iOS19·Android29개 표본을 직접 확인해 링크/사진 진입·결과·닫기와 OS 팝업 없음을 확인했다. Android 첫 실패 영상은 최종 비교·성공 증거에 사용하지 않는다.
- [최종 환경 정리](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/cleanup-verification.json)는 **03:58:28 UTC / 12:58:28 KST**에 iPhone16/iOS18.6 Shutdown, Android Emulator/ADB/qemu·Xcode 초기화 명령 프로세스0, 포워딩8768 제거·8767/8768 리스너 없음·원래 제스처 일치·설정변경0·사용자 데이터 보존을 확인했다. 임시 비교 서버는 시작하지 않았다.
- 완료 표시는 **미리보기 제목–출처 간격14px**에 한정한다. 사진 비율/잘림·한 줄 전용 디자인·전체 텍스트 폭/배치·카테고리 편집·결과 전체 맞춤은 계속 보류한다. 과거8px 유지·조회·검사·비교는 당시 기록으로 보존한다. 메모리 저장/고정 선택기·Flutter 합성 입력의 native 대역 검증이며 운영 API·OAuth·실기기·원격 CI의 증거는 아니다. 새 확대/3버튼/키보드 기기 촬영은 추가하지 않았고 기존 확대 자동 검사를 유지했다. 화면 증거·빌드·`AGENTS.md`는 제외하고 같은 브랜치에서 한 커밋으로 저장하며 푸시·PR은 하지 않는다.
