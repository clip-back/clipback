# 저장 결과 카테고리 간격

- 최초 기록일: 2026-10-17
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-731d93674ef3eb6a"></a>

### 저장 결과 카테고리 시작 간격 (`fec6b66` 기준, 해당 범위 적용·검증 완료)

<a id="b-3a83f18764ea73bf"></a>

- 기준 `fec6b66`에서 제품은 미리보기 카드와 카테고리 제목 사이 `SizedBox` 한 곳만30→32px로 바꿨다. 스크롤0에서 카테고리 제목·상태 안내·행/이름·폴더·상세 변경 안내가 함께2px 내려간다. 제목139px·출처147px·간격14px·카드116px·이미지164×100px·글꼴·자연 높이/중앙 정렬·결과 시작32px·하단 배치는 유지한다. 처리 중·미분류·분류됨 문구와 읽기 전용 상태·상세 변경 안내·저장/닫기도 유지한다.
- [새 Figma 조회](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/figma/reference-manifest.json)는 Page 1 > 261007의 D05 `111:4902`·D09 `111:4865`를 총2회 성공 조회했다(2026-10-17 04:46:58~04:47:04 UTC / 13:46:58~13:47:04 KST). 정확한 원본·컨텍스트를 보존했으며 누락/fallback은 없다. [32px 좌표 근거](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/figma/gap-reference.json)는 기존 메타데이터의 카드 하단493px/카테고리 제목525px을 새 컨텍스트·원본과 교차 확인한 것이며 메타데이터를 다시 조회한 것은 아니다.
- [RED 재현](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/summary.json)은130건 중58통과·72실패(기본48·기존 확대24)로30px과32px 차이를 재현했다. [수정 전 게이트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/before-gate.json)의 새 OS원본4장 확보 후 제품을 수정했다. fixture·기본/확대 검사 SHA는 전후 모두 같고 검사 소스 정정은 없었다. [자동 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/automatic-summary.json): 기본92건(8.79초)·관련335건(17.16초)·전체 Flutter969건(47.12초) 통과, 분석 문제 없음(4.55초), Dart4파일 형식 변경0건(0.36초). 이전 작업의 검사/조회/촬영은 이번 성공으로 사용하지 않는다.
- [새 3열4쌍 비교](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/comparison-document.html) · [비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/comparison-qa.json) · [실측 표](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/category-start-gap-measurements.json)에서30→32px·카테고리 전체+2px을 스크롤0 기준으로 확인했다. 나머지 본문/헤더/탭/viewport/CTA와 미리보기·카테고리 내부 스타일/크기/간격은 같다. Figma·조건 누락0건이며 기기 한 줄 제목과 Figma 두 줄 예제의 전체 세로 배치가 같다고 주장하지 않는다. OS 영역/원본을 보정하거나 대체 디자인을 만들지 않았다.
- iPhone16/iOS18.6·Android13/API33 제스처 AFTER는 각각 기록10/10건·프레임워크 오류0건, `stylePassed`·`layoutPassed`·`behaviorPassed`·`checksCompleted`·전체 `passed: true`다. [iOS 보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/ios/after/flutter/report.json)·[Android 보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/android-gesture/after/flutter/report.json)에서 결과 진입·완료 탭 고정·추가 저장 없는 닫기를 확인했다. 최대 스크롤은 네 결과 모두0px이므로 무스크롤·마지막 안내 완전 노출·하단 최소24px·CTA 겹침 없음을 확인한 범위이며 실제 드래그 성공으로 보고하지 않는다.

<a id="b-bc1edc6e56198cc0"></a>

| 플랫폼 | 링크 결과 비교 | 사진 결과 비교 |
| --- | --- | --- |
| iOS | [링크 결과](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/comparison-ios-link.png) | [사진 결과](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/comparison-ios-photo.png) |
| Android 제스처 | [링크 결과](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/comparison-android-gesture-link.png) | [사진 결과](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/comparison-android-gesture-photo.png) |

<a id="b-ed4ec276378d02a0"></a>

- [iOS 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/ios/after/interaction.mp4) 9.52167초/1,255,632바이트 · [Android 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/android-gesture/after/interaction.mp4) 13.1323초/948,355바이트. [전체 디코딩](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/media-verification.json)은 종료코드0·오류0바이트·원본 해시 불변, [직접 시각 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/direct-visual-review.json)는 iOS20·Android28개 표본 전부의 결과 진입/탭 고정/닫기와 OS 팝업·목표 영역 잘림/겹침 없음을 확인했다. 시계와 실제 OS 표시 차이는 보존하며 앱 geometry/inset과 원본 조건을 구분한다.
- [환경 정리](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/cleanup-verification.json)(2026-10-17 04:56:23 UTC / 13:56:23 KST)에서 Simulator Shutdown·Emulator/adb0·8767/8768 리스너0·설정 변경0·데이터 보존을 확인했다. [비교 문서 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/comparison-document-check.json)는 JS 문법·참조31개만 검증했다. 서버를 시작하지 않았고 브라우저 상호작용은 미검증이다. 고정 선택기/메모리 저장·합성 입력 증거를 운영 API·OAuth·실기기·원격 CI 검증으로 확대하지 않는다.
- 완료는 카테고리 시작 간격32px에 한정한다. 안내를 제목 옆/아래에 놓는 상태별 기준·카테고리 편집·사진 비율/잘림·한 줄 결과의 세로 배치·출처 최대 폭 원본 기준·전체 맞춤은 보류한다. 기존 확대 자동 검사는 유지하고 새 확대/키보드/3버튼 기기 촬영은 추가하지 않는다. 과거 기록을 보존하며 화면 증거·빌드·`AGENTS.md`는 커밋에서 제외한다. 푸시/PR은 하지 않는다.

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-75e4283da4c7de85"></a>

### 2026-10-17 — 저장 결과 카테고리 시작 간격 (`fec6b66` 기준, 해당 범위 적용·검증 완료)

<a id="b-d949bacac147571c"></a>

- [iOS 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/ios/after/interaction.mp4) 9.52167초/1,255,632바이트 · [Android 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/android-gesture/after/interaction.mp4) 13.1323초/948,355바이트. [전체 디코딩](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/media-verification.json)은 종료코드0·오류0바이트·원본 해시 불변, [직접 시각 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/direct-visual-review.json)는 iOS20·Android28개 표본 전부의 결과 진입/탭 고정/닫기와 OS 팝업·목표 영역 잘림/겹침 없음을 확인했다. 시계와 실제 OS 표시 차이는 보존하며 앱 geometry/inset과 원본 조건을 구분한다.
- [환경 정리](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/cleanup-verification.json)(2026-10-17 04:56:23 UTC / 13:56:23 KST)에서 Simulator Shutdown·Emulator/adb0·8767/8768 리스너0·설정 변경0·데이터 보존을 확인했다. [비교 문서 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/comparison-document-check.json)는 JS 문법·참조31개만 검증했다. 서버를 시작하지 않았고 브라우저 상호작용은 미검증이다. 고정 선택기/메모리 저장·합성 입력 증거를 운영 API·OAuth·실기기·원격 CI 검증으로 확대하지 않는다.
- 완료는 카테고리 시작 간격32px에 한정한다. 안내를 제목 옆/아래에 놓는 상태별 기준·카테고리 편집·사진 비율/잘림·한 줄 결과의 세로 배치·출처 최대 폭 원본 기준·전체 맞춤은 보류한다. 기존 확대 자동 검사는 유지하고 새 확대/키보드/3버튼 기기 촬영은 추가하지 않는다. 과거 기록을 보존하며 화면 증거·빌드·`AGENTS.md`는 커밋에서 제외한다. 푸시/PR은 하지 않는다.
- 같은 `feature/figma-ui-alignment` 브랜치에서 `fix: 피그마 기준으로 저장 결과 카테고리 시작 간격 맞춤`으로 한 커밋에 저장한다.

## 원문 출처: docs/figma-ui-alignment-plan.md

<a id="b-aacd27d52d313b49"></a>

### 저장 결과 카테고리 시작 간격 (2026-10-17, `fec6b66` 기준·해당 범위 적용·검증 완료)
