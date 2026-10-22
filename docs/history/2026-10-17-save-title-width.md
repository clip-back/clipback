# 저장 결과 제목 폭

- 최초 기록일: 2026-10-17
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-30ba5634f8713778"></a>

### 저장 결과 미리보기 제목 최대 폭 (`63800e6` 기준, 해당 범위 적용·검증 완료)

<a id="b-95e35e371e0c7b2f"></a>

- Page 1 > 261007 D05 `111:4902`·D09 `111:4865`의 제목만 우측8px을 확보했습니다. [이번 Figma 조회](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/figma/reference-manifest.json)는 **2026-10-17 04:16:05~04:16:11 UTC(13:16:05~13:16:11 KST)** 총2회 성공이며 원본 누락/fallback이 없습니다. 본문375px의 제목/출처 최대 폭은 **139/147px**, 320px 자동 검사는 **84/92px**입니다. 실제 문단 최대 제약을 검사하며 Padding 위젯 유무로 통과 처리하지 않습니다.
- [변경 전→변경 후→Figma 4쌍](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/comparison-document.html) · [비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/comparison-qa.json) · [실측 표](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/preview-title-width-measurements.json). 기기 제목 ‘저장 결과 확인’의 실제 문단 폭82.1074px·한 줄·출처/카드/글자 경계는 전후 같습니다. 최대 폭만8px 줄었으며 14px 간격·자연 높이/중앙 정렬·시작32px·하단24px·제출 입력/완료 탭 정책을 유지합니다. 한 줄과 두 줄 Figma의 절대 세로 위치가 같다는 의미는 아닙니다.
- [자동 검사 요약](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/automatic-summary.json)에서 기본92·관련335·전체969건 통과, 분석 문제 없음·Dart4파일 변경0건을 확인했습니다. [수정 전 재현](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/reproduction-test-summary.json) · [정정 후 기준 코드 재현](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/amended-reproduction-summary.json)는130건 중74통과/56실패입니다. [검사 소스 정정](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/test-source-amendment.json)는 선택 상자1.2px 초과의 오판4건만 정정하고 기준 코드도 다시74/56으로 확인했습니다. 기본 검사 SHA만 바뀌었으며 네이티브 fixture·확대 검사·[새 BEFORE4원본](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/before-gate.json)은 보존했습니다.
- iPhone16/iOS18.6·Android13/API33 제스처는 각각 기록10건·프레임워크 오류0건·스타일/레이아웃/행동/전체 통과입니다. 결과 진입·탭 고정·추가 저장 없는 닫기를 확인했습니다. 최대 스크롤0px의 무스크롤 상태로 마지막 안내와 하단 여백·버튼 겹침 없음을 확인했으며 드래그 실행 성공으로 보고하지 않습니다.

<a id="b-7fccf5a7bb18916a"></a>

| 플랫폼 | 링크 결과 비교 | 사진 결과 비교 |
| --- | --- | --- |
| iOS | [링크 결과](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/comparison-ios-link.png) | [사진 결과](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/comparison-ios-photo.png) |
| Android 제스처 | [링크 결과](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/comparison-android-gesture-link.png) | [사진 결과](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/comparison-android-gesture-photo.png) |

<a id="b-984d641587856b1b"></a>

- [iOS 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/ios/after/interaction.mp4)(9.426667초) · [Android 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/android-gesture/after/interaction.mp4)(13.778167초). [전체 디코딩](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/media-verification.json) · [직접 시각 검토](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/direct-visual-review.json)의 전체 디코딩 오류0·iOS20/Android29 표본 직접 시각 검사에서 팝업/목표 영역 잘림이 없습니다. 완전한3열4쌍·Figma/조건 누락0건이며 OS 원본의 시계·iOS Dynamic Island 표시 차이는 보정하지 않았습니다.
- [최종 환경 정리](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/cleanup-verification.json)는13:30:15 KST에 기기 종료·adb/에뮬레이터0·8767/8768 리스너0·설정 변경0·데이터 보존을 확인했습니다. [비교 문서 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/comparison-document-check.json)는 JS와 참조31개만 검사했으며 서버 미시작·브라우저 상호작용 미검증입니다. 운영 API/OAuth/실기기/CI 증거가 아니며 출처 최대 폭 원본 기준·한 줄 세로 배치·사진·편집·전체 맞춤은 후속으로 유지합니다. 이전 검증 기록은 이번 성공으로 대체하지 않습니다.

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-4fca6cab4e0479ad"></a>

### 2026-10-17 — 저장 결과 미리보기 제목 최대 폭 (`63800e6` 기준, 해당 범위 적용·검증 완료)

<a id="b-11999310426d26b6"></a>

- Page 1 > 261007의 D05 `111:4902`·D09 `111:4865`에서 콘텐츠 제목에만 우측8px을 확보했습니다. [이번 Figma 조회](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/figma/reference-manifest.json)는04:16:05~04:16:11 UTC(13:16:05~13:16:11 KST) 총2회 성공·누락/fallback0입니다. 출처 폭·제목/출처 간격14px·글자·자연 높이/중앙 정렬·카드/이미지·시작32px·하단 정책과 저장 계약은 유지했습니다.
- [수정 전 재현](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/reproduction-test-summary.json) · [정정 후 기준 코드 재현](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/amended-reproduction-summary.json)는 **130건 중74통과·56실패**였습니다. [BEFORE 게이트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/before-gate.json)에서 제품 불변·새 OS원본4장·fixture/검사 동결을 확인한 뒤 제품을 수정했습니다. 이후 첫 GREEN의 선택 상자1.2px 초과 오판4건은 [검사 소스 정정](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/test-source-amendment.json)에서 실제 제약/레이아웃과 선택 영역 경계를 구분해 고쳤습니다. 허용 오차를 늘리지 않았고 기준 제품으로도 다시74/56을 확인했습니다. 기본 검사 SHA는6d4f95…→b6cc9b…로 변경됐으므로 전후 같다고 표시하지 않습니다. 이 검사 파일은 네이티브 컴파일에 포함되지 않으며 fixture82b806…·확대 검사95abe4…·BEFORE4원본은 그대로입니다.
- [자동 검사 요약](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/automatic-summary.json): 기본92건/8.26초·관련335건/16.85초·전체969건/46.79초 통과, 분석 문제 없음/4.31초·Dart4파일 형식 변경0건/0.35초입니다. 기존 확대 자동 검사는 유지하고 이전961건을 이번 실행으로 대신하지 않았습니다. [최종 빌드·소스 증명](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/final-implementation.json)의 Android14.8초·iOS67.51초 빌드 성공은 아래 native 실행과 구분합니다.
- [변경 전→변경 후→Figma 4쌍](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/comparison-document.html) · [비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/comparison-qa.json) · [실측 표](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/preview-title-width-measurements.json)에서 제목 최대 제약은147→139px·출처147→147px, 320px 자동 사례는92→84px·출처92px입니다. 기기의 기존 짧은 제목은 실제 문단 폭82.1074px·한 줄·경계가 불변이고 Figma는 두 줄 예제입니다. 글리프 픽셀 폭이나 전체 세로 위치를 맞췄다고 주장하지 않습니다. 카드343×116·이미지164×100·텍스트 묶음60px·간격14px·중앙·다른 경계/글자도 유지했습니다.
- [iOS 보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/ios/after/flutter/report.json)·[Android 보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/android-gesture/after/flutter/report.json)는 각각10기록·프레임워크 오류0건·`stylePassed`/`layoutPassed`/`behaviorPassed`/`checksCompleted`/전체 `passed: true`입니다. 결과 진입·탭 고정·추가 저장 없는 닫기를 확인했습니다. 네 상태의 최대 스크롤은0px이며 무스크롤·마지막 안내 완전 노출·본문 하단 최소24px·CTA 겹침 없음을 확인했습니다. 드래그 성공이나 새 확대/키보드/3버튼 촬영으로 보고하지 않습니다.

<a id="b-dd7df940b0e1f062"></a>

- [iOS 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/ios/after/interaction.mp4)(9.426667초) · [Android 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/android-gesture/after/interaction.mp4)(13.778167초). [전체 디코딩](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/media-verification.json) · [직접 시각 검토](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/direct-visual-review.json)는 전체 디코딩 종료0·오류0바이트와 iOS20/Android29 표본 모두의 시각 확인을 구분합니다. 완전한3열4쌍·조건/Figma 누락0·팝업/목표 영역 잘림0이며 촬영 OS 원본은 보정하지 않았습니다. 시계와 iOS Dynamic Island 표시 차이는 보존했고 앱 geometry/inset은 같습니다.
- [최종 환경 정리](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/cleanup-verification.json)는04:30:15 UTC(13:30:15 KST)에 Simulator Shutdown·Emulator/adb0·8767/8768 리스너0·포워딩 제거·원래 설정/변경0·데이터 보존을 확인했습니다. [비교 문서 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/comparison-document-check.json)의 JS 문법·참조31개는 통과했으나 서버 미시작·브라우저 상호작용 미검증입니다. [영구 보존 증명](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/archive-provenance.json)은164개 파일의 복사/SHA 일치와 원본 미변경을 확인합니다.
- 이번 완료는 제목 최대 폭뿐입니다. 출처 최대 폭 원본 기준·한 줄 결과 세로 배치·사진 비율/잘림·카테고리 편집·결과 전체 맞춤과 API/OAuth/실기기/원격 CI 검증은 남겨 둡니다. 고정 선택기·메모리 저장·Flutter 합성 입력 검증을 운영 증거로 확대하지 않으며 과거 조회/검사/비교 기록을 보존합니다. 화면 증거·빌드·`AGENTS.md`는 커밋에서 제외하고 푸시/PR은 하지 않습니다.

## 원문 출처: docs/figma-ui-alignment-plan.md

<a id="b-78f48aae200308f1"></a>

### 저장 결과 미리보기 제목 최대 폭 (2026-10-17, `63800e6` 기준·해당 범위 적용·검증 완료)

<a id="b-14551093c906471b"></a>

- 현재 Page 1 > 261007의 D05 `111:4902`·D09 `111:4865`를 기준으로 제목에만 우측8px을 확보했다. 출처 전체 컬럼 폭·글자·14px 간격·카드 최소116px/내부8px·이미지164×100px·가로16px·자연 높이/중앙 정렬과 저장 동작은 유지한다. [이번 Figma 조회](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/figma/reference-manifest.json)는 **04:16:05~04:16:11 UTC(13:16:05~13:16:11 KST)** 총2회 성공이며 정확한 원본·컨텍스트와 해시를 보존했다. 누락·fallback은 없다.
- [수정 전 재현](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/reproduction-test-summary.json) · [정정 후 기준 코드 재현](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/amended-reproduction-summary.json)는 각각 **130건 중74통과·56실패**로 제목 폭 차이를 재현했다. 제품 수정 전 새4원본을 확보한 [BEFORE 게이트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/before-gate.json) 뒤 적용했다. 첫 GREEN에서 선택 상자의1.2px 초과를 잘림으로 오판한4건은 [검사 소스 정정](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/test-source-amendment.json)에서 검사 경계만 정정했다. 허용 오차나 제품을 완화하지 않았으며 기준 코드 재현도 다시74/56이었다. 기본 검사 SHA는 `6d4f95…`→`b6cc9b…`로 바뀌었고 네이티브에 컴파일되지 않는 검사 소스다. 네이티브 fixture `82b806…`·기존 확대 검사 SHA와 BEFORE4원본은 그대로다.
- [자동 검사 요약](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/automatic-summary.json): 기본92건(8.26초)·관련335건(16.85초)·전체 `flutter test --no-pub`969건(46.79초) 통과, `flutter analyze --no-pub` 문제 없음(4.31초), Dart4파일 형식 변경0건(0.35초). 기존 확대 자동 검사를 유지했다. 이전961건 성공을 이번 검사로 사용하지 않았다.
- [변경 전→변경 후→Figma 4쌍](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/comparison-document.html) · [비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/comparison-qa.json) · [실측 표](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/preview-title-width-measurements.json). 제목/출처의 실제 `RenderParagraph.constraints.maxWidth`를 최종 레이아웃/전체 판정에 연결했다. 본문375px은 **147→139 /147→147px**, 320px 자동 검사는 **92→84 /92→92px**다. 기기의 짧은 제목 ‘저장 결과 확인’은 실제 문단 폭82.1074px·한 줄과 모든 경계가 그대로다. 최대 제약 폭 변화와 실제 문단 폭을 구분하며 두 줄 Figma 예제와 절대 세로 위치 전체가 같다고 주장하지 않는다.
- 새 iPhone16/iOS18.6·Android13/API33 제스처 AFTER는 각각 기록10건·프레임워크 오류0건, `stylePassed`·`layoutPassed`·`behaviorPassed`·`checksCompleted`·전체 `passed: true`다. 결과 진입·탭 고정·추가 저장 없는 닫기를 확인했다. 네 결과의 최대 스크롤은 모두0px이므로 무스크롤·마지막 안내와 하단24px 패딩·CTA 겹침 없음을 확인한 범위이며 드래그 성공으로 표시하지 않는다.

<a id="b-04fd83180cc12da4"></a>

- [iOS 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/ios/after/interaction.mp4)(9.426667초) · [Android 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/android-gesture/after/interaction.mp4)(13.778167초). [전체 디코딩](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/media-verification.json) · [직접 시각 검토](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/direct-visual-review.json)에서 전체 디코딩 오류0·iOS20/Android29 표본 전부의 직접 시각 검사로 OS 팝업·목표 영역 잘림/겹침 없음을 확인했다. 4쌍 모두 정확한3열이고 Figma/조건 누락0건이다. OS 원본은 보정하지 않았으며 시계·iOS Dynamic Island 표시 차이와 실제 창/안전 여백을 그대로 남겼다. 앱 경계와 inset은 전후 같다.
- [최종 환경 정리](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/cleanup-verification.json)는 **04:30:15 UTC(13:30:15 KST)**에 Simulator Shutdown·Emulator/adb0·8767/8768 리스너0·원래 탐색 설정/변경0·데이터 보존을 확인했다. [비교 문서 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/comparison-document-check.json)는 JS 문법·참조31개만 검사했다. 서버를 시작하지 않았고 브라우저 상호작용은 미검증이다. 메모리 저장/선택기·합성 입력 증거를 운영 API·OAuth·실기기·원격 CI 검증으로 사용하지 않는다. 완료는 제목 최대 폭뿐이며 출처 원본 폭 기준·한 줄 세로 배치·사진·카테고리 편집·전체 배치 보류와 과거 기록은 유지한다.
