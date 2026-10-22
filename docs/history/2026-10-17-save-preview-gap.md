# 저장 결과 미리보기 시작 간격

- 최초 기록일: 2026-10-17
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-1c03cc80e6d52c18"></a>

### 저장 결과 미리보기 시작 간격 (`b61a47d` 기준, 해당 범위 적용·검증 완료)

<a id="b-8fcb323573fad546"></a>

- 기준 `b61a47d`에서 링크 검증 문구→미리보기 제목 간격28→32px, 사진 파일명 박스→미리보기 제목 간격28→16px만 적용했다. 스크롤0에서 미리보기 제목 이후 카드·카테고리·마지막 안내 전체가 링크+4px/사진−12px 이동한다. 앞 입력/검증 블록·헤더·탭·본문 viewport·버튼은 같으며 결과 시작32px·카드→카테고리32px·제목139px/출처147px·제목–출처14px·카드116px·이미지164×100px·글자·자연 높이/중앙 정렬을 유지한다.
- [Figma 조회](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/figma/reference-manifest.json)는 Page 1 > 261007의 D05 `111:4902`·D09 `111:4865` 원본·컨텍스트를2회 성공 조회했다(2026-10-17 05:04:51~05:04:57 UTC / 14:04:51~14:04:57 KST, 누락/fallback0). [간격 좌표 근거](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/figma/gap-reference.json)는 기존 메타데이터를 새 원본·컨텍스트와 교차 확인했으며 메타데이터는 다시 조회하지 않았다. 사진은 앱의 현재 파일명 박스44px 다음 간격만 맞췄다. Figma의 앞 이미지89px와 다른 구조·사진 비율/잘림은 보류하므로 사진 전체 좌표가 같다는 판정은 하지 않는다.
- [RED 재현](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/summary.json) 130건 중74통과·56실패(기본32·기존 확대24)는 기존28px과 링크32px/사진16px의 차이만 재현했다. [제품 수정 전 게이트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/before-gate.json)의 새 OS원본4장을 먼저 확보했으며 fixture·기본/확대 검사 SHA는 전후 동일하고 검사 소스 정정은 없다. [자동 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/automatic-summary.json): 기본92건(13.85초)·관련335건(24.63초)·전체 Flutter969건(111.6초) 통과, 분석 문제 없음(5.14초), Dart4파일 형식 변경0건(0.45초). [최종 빌드](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/final-implementation.json)의 양 플랫폼 빌드도 성공했다(android 16.45초·ios 124.76초). 과거 검사·조회·촬영을 이번 성공으로 사용하지 않는다.
- [새 비교4쌍](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/comparison-document.html) · [비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/comparison-qa.json) · [실측 표](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/preview-start-gap-measurements.json): 같은 데이터·1배율·스크롤0·키보드0px의 완전한3열4쌍이며 Figma·조건 누락0건이다. 원본은 OS 영역을 포함해 무보정으로 보존했고 비교 표시만 종횡비대로 축소했다. 기기의 한 줄 제목과 Figma 두 줄 예제의 절대 위치·전체 세로 배치까지 같다고 판정하지 않는다.
- iPhone16/iOS18.6·Android13/API33 제스처 AFTER는 각각 기록10/10건·프레임워크 오류0건, `stylePassed`·`layoutPassed`·`behaviorPassed`·`checksCompleted`·전체 `passed: true`다. [iOS 보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/ios/after/flutter/report.json)·[Android 보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/android-gesture/after/flutter/report.json)에서 두 결과 진입·반대 탭을 눌러도 완료 탭 유지·추가 저장 없는 닫기를 확인했다. 최대 스크롤은 네 결과 모두0px이므로 무스크롤·마지막 안내 완전 노출·하단 최소24px·버튼 겹침 없음을 확인한 범위다.

<a id="b-dd24c2f2202a053a"></a>

| 플랫폼·결과 | 앞 블록→미리보기 | 이후 전체 이동(스크롤0) | 최대 스크롤 | 3열 비교 |
| --- | --- | --- | --- | --- |
| iOS 링크 | 28→32px | +4px | 0px | [변경 전 → 후 → Figma](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/comparison-ios-link.png) |
| iOS 사진 | 28→16px | -12px | 0px | [변경 전 → 후 → Figma](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/comparison-ios-photo.png) |
| Android 제스처 링크 | 28→32px | +4px | 0px | [변경 전 → 후 → Figma](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/comparison-android-gesture-link.png) |
| Android 제스처 사진 | 28→16px | -12px | 0px | [변경 전 → 후 → Figma](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/comparison-android-gesture-photo.png) |

<a id="b-ccc7fac48f97661d"></a>

- [iOS 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/ios/after/interaction.mp4) 9.35833초/1,246,375바이트 · [Android 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/android-gesture/after/interaction.mp4) 13.0768초/978,062바이트. [영상 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/media-verification.json)는 전체 디코딩 종료코드0·오류0바이트·원본 해시 불변이며 [직접 시각 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/direct-visual-review.json)에서 새 원본4장·비교4장과 iOS20개·Android28개 표본 전부를 확인했다. OS 팝업과 목표 영역 잘림/겹침은 없으며 시계 등 실제 OS 표시 차이는 원본 그대로 남겼다.
- [환경 정리](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/cleanup-verification.json)(2026-10-17 05:15:51 UTC / 14:15:51 KST): Simulator Shutdown·Emulator/adb0·8767/8768 리스너0·탐색 설정 변경0·데이터 보존. [비교 문서 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/comparison-document-check.json)는 JS 문법·참조31개만 검증했다. 비교 서버는 시작하지 않았고 브라우저 상호작용은 미검증이다. 고정 선택기·메모리 저장·합성 입력 증거를 API/OAuth·실기기·원격 CI 증거로 확대하지 않는다.
- 완료는 앞 블록과 미리보기 제목 사이 간격에 한정한다. 한 줄 결과 세로 배치·출처 최대 폭 원본 기준·사진 표시/잘림·카테고리 안내의 제목 옆/아래 배치와 편집·전체 맞춤은 보류한다. 문구·분류 상태·저장/닫기·기존 확대 자동 검사는 유지했고 새 확대/키보드/3버튼 기기 촬영은 추가하지 않았다. 화면 증거·빌드·`AGENTS.md`는 커밋에서 제외하며 푸시/PR은 하지 않는다.

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-3c9fcee4de3852cd"></a>

### 2026-10-17 — 저장 결과 미리보기 시작 간격 (`b61a47d` 기준, 해당 범위 적용·검증 완료)

## 원문 출처: docs/figma-ui-alignment-plan.md

<a id="b-26fddb923960e747"></a>

### 저장 결과 미리보기 시작 간격 (2026-10-17, `b61a47d` 기준·해당 범위 적용·검증 완료)
