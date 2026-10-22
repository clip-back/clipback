# OS 하단 안전 영역과 인디케이터

- 최초 기록일: 2026-10-14
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-a0cc738fa71d25bd"></a>

### OS 하단 안전 영역과 공통 인디케이터 (`a9eb69d`)

<a id="b-fa71ef3174432d3e"></a>

아래 Figma 노드·조회 시각과 692개 테스트·기기 화면/영상은 이전 `svNWsTFh8Ws1Mpt8XQIcrN / 261007` 당시의 검증입니다.
사용자가 승인한 OS 안전 영역 정책은 새 디자인 기준에서도 유지합니다.

<a id="b-09705ff422b4007f"></a>

사용자가 승인한 공통 바의 총높이는 **64px + 글자 확대 증가분 + `viewPadding.bottom`**입니다.
기기 하단 안전 영역은 한 번만 더하며 키보드의 `viewInsets.bottom`은 더하지 않습니다.
별도 `SafeArea`로 다시 합산하지 않고, 기존 두 줄 라벨·아이콘 정렬·활성 색상과 네 탭의 콜백을 유지합니다.
추가 버튼은 72×72px·중앙·바 위로 22px 위치와 중심/바 안쪽 하단 입력을 유지합니다.
Figma의 고정 96px과 달리 기기 inset에 따라 바 상단과 본문 사용 높이가 달라집니다.

<a id="b-c0aa97483661276b"></a>

공통 탭을 사용하는 홈·아카이브·즐겨찾기·마이·상세·Placeholder와 카드 다시보기가 이번 범위입니다.
카드 다시보기의 빈/일반 목록 양쪽은 하단 `SafeArea`를 적용하며, 일반 목록은 `ClipRect`를
실제 하단 안전 영역 앞에서 끝냅니다. 기존 카드 크기·상단 좌표·드래그/전환을 유지하고 OS 영역에 그리지 않습니다.
공통 `NavigationHomeIndicator`와 두 사용부를 제거하고 실제 인디케이터 표시를 OS에 맡깁니다.
OS 플래그·화면 생성자·API·데이터 모델·콘텐츠 보존/삭제 처리와 상세 페이지 이동/시트 입력 계약은 변경하지 않습니다.

<a id="b-1982d8bba3cea0ba"></a>

이 공통 바 커밋 당시 진입 스플래시의 `EntryHomeIndicator`와 저장 화면의 `_SaveHomeIndicator`·본문/버튼 배치는 보류했습니다.
이 당시 진입 스플래시는 보류했으며 이후 아래 A01 작업에서 별도 정리했습니다. 저장 창도 아래 사용자 확정 기준의 후속 하단 작업으로 분리한 당시 기록입니다.
마이·상세 본문의 글자 배율 2 넘침도 기존 디자인 확인 대상으로 남기며,
공통 탭 단독 확대 검사를 전체 본문 성공으로 보고하지 않습니다.
기준 Figma는 공통 탭 `111:3680`, C01 `111:3584`, C02 `111:3681`, G02 `111:5047`이고
2026-10-14 01:58:26 KST(2026-10-13 16:58:26 UTC)에 최초 조회하고,
제품 수정 직전 2026-10-14 02:28:08 KST(2026-10-13 17:28:08 UTC)에 원본을 다시 조회했습니다.

<a id="b-5b855c3a6e1ce33b"></a>

```bash
# frontend/ — 관련 회귀와 전체 검사입니다.
flutter test --no-pub test/bottom_safe_area_test.dart test/scaled_navigation_layout_test.dart test/home_alignment_test.dart test/top_safe_area_test.dart test/save_search_safe_area_test.dart test/sheet_safe_area_test.dart
flutter analyze --no-pub
flutter test --no-pub

# 코드 수정 전에 같은 기기·데이터·배율·스크롤·OS 내비게이션 모드로 세 프리뷰를 실행합니다.
flutter run --no-pub -d <device-id> -t test/support/figma_home_preview.dart \
  --dart-define=FIGMA_HOME_CHECK=true --dart-define=FIGMA_HOME_PHASE=before
flutter run --no-pub -d <device-id> -t test/support/navigation_layout_preview.dart \
  --dart-define=NAV_LAYOUT_PHASE=before
flutter run --no-pub -d <device-id> -t test/support/card_review_safe_area_preview.dart \
  --dart-define=CARD_REVIEW_PHASE=before

# 수정 후에는 세 PHASE 값을 각각 after로 바꿔 동일 조건에서 다시 실행합니다.
# 실제 OS 인디케이터 확인용 원본 화면도 별도로 확보합니다.
# SIMULATOR_ID/EMULATOR_ID는 연결된 기기의 로컬 ID로 지정합니다.
xcrun simctl io "$SIMULATOR_ID" screenshot /private/tmp/clipback-ios-bottom-safe-area.png
adb -s "$EMULATOR_ID" exec-out screencap -p > /private/tmp/clipback-android-bottom-safe-area.png
```

<a id="b-bc6bd9faad64784f"></a>

`test/bottom_safe_area_test.dart`는 폭 320·375px, 배율 1·1.5·2와 하단 inset 0·24·34·48px에서
공통 바 높이·탭/FAB 입력·키보드 전후 inset 유지·가짜 인디케이터 없음과 카드의 하단 보호를 검사합니다.
카드의 빈/일반 상태와 드래그·전환 중 하단 렌더링 픽셀도 확인합니다.
이번 수정 후 관련 검사 **148개**와 전체 Flutter 테스트 **692개**를 통과했고 정적 분석은 **문제 없음**입니다.
관련 검사는 하단 67·확대 30·홈 35·상단 11·저장/검색 2·시트 3개이며 Dart 파일 7개의 형식 검사도 변경 없이 통과했습니다.
최종 iOS·Android 제스처·Android 3버튼의 세 프리뷰, 총 9개 `after` 보고서가 모두
`passed`·`checksCompleted: true`, 프레임워크 오류 0건·`failure: null`로 통과했습니다.
이전 625개 테스트나 기기 통과를 이번 결과로 사용하지 않습니다.
수정 전 iOS·Android 제스처·Android 3버튼의 프리뷰 세 종류, 총 9개 보고서는 모두
`phase: before`, `passed`·`checksCompleted: true`와 프레임워크 오류 0건을 확인했습니다.
새 안전 영역 기준은 `after`에서만 검사하므로 변경 전 통과가 중복 인디케이터나 안전 영역 문제의 부재를 뜻하지 않습니다.

<a id="b-b6eb8fe4464e8d12"></a>

이번 홈 프리뷰는 `before`·`after` 양쪽에서 여섯 비교 상태와 다섯 동작 화면, 총 11장을 촬영하고
스크롤·저장 시트/키보드·닫기를 확인합니다.
내비게이션 프리뷰는 실제 여섯 본문 일반 배율과 공통 탭 단독 확대를 구분하고 실제 탭·상세 이전/다음·복귀를 확인합니다.
카드 프리뷰는 실제 다시보기의 일반·드래그 중·다음 카드·빈 목록 PNG 네 장과
북마크·카드 열기·드래그 진입·전환·양쪽 나가기, 하단 viewport/inset을 기록합니다.
각각 `clipback-home-*`, `clipback-navigation-*`, `clipback-card-review-*`에 PNG·`report.json`을 생성하고
`FIGMA_HOME`, `NAV_LAYOUT`, `CARD_REVIEW`의 `PASS/FAIL`을 출력합니다. 실제 세션·HTTP·저장은 사용하지 않습니다.
Flutter 캡처는 실제 OS 인디케이터를 포함하지 않으므로 `simctl`·`adb` 원본 캡처와 플랫폼별 영상을 함께 보존합니다.

<a id="b-25282e5f4f22f502"></a>

증거 루트는 `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/bottom-safe-area`입니다.
`ios`, `android-gesture`, `android-three-button`의 `before`/`after` 아래 `home`, `navigation`, `card-review`로 구분합니다.
각 모드의 phase마다 홈 11장·내비게이션 9장·카드 4장, 총 24개 화면을 기록합니다.
수정 전에는 원본 OS 캡처와 Flutter 캡처 각 72개·영상 9개를 보존했습니다.
수정 후에도 같은 수의 원본 OS/Flutter 캡처와 영상을 보존했습니다.
이번 측정에서 iOS의 하단 inset 34px·바 높이 98/126/142px(배율 1/1.5/2),
Android 두 모드의 `viewPadding.bottom` 0px·바 높이 64/92/108px을 확인했습니다.
카드 viewport 하단은 iOS 818px, Android 제스처 783.2727px·3버튼 759.2727px로 안전한 영역 끝과 일치했습니다.
Android 3버튼 모드에서는 OS 영역이 Flutter 화면 바깥을 차지하므로 바에 그 높이를 다시 더하지 않습니다.
카드의 고정 496px·드래그/다음 카드·북마크·열기·양쪽 나가기, 상세 이전/다음·Placeholder 복귀·추가 버튼 입력을 확인했습니다.
여섯 실제 본문의 일반 배율과 공통 탭 단독 확대 검사의 한계는 유지합니다.

<a id="b-e520c191ea0767cc"></a>

[원본 3열 비교 문서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/bottom-safe-area/comparison-document.html)는
3조건 × 홈 6개·내비게이션 9개·카드 4개, 총 57개 비교를 제공합니다. 원본 PNG와 OS 픽셀을 보정하지 않습니다.
동작 영상: [iOS](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/bottom-safe-area/ios/interaction-final.mp4),
[Android 제스처](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/bottom-safe-area/android-gesture/interaction-final.mp4),
[Android 3버튼](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/bottom-safe-area/android-three-button/interaction-final.mp4).
플랫폼·내비게이션 모드별 원본 변경 전·후·Figma를 나란히 비교하고 OS 안전 영역과 디자인 프레임의 차이를 설명합니다.
기종·OS·글자 배율·화면 상태·측정값·영상·누락된 비교 항목은 [프론트 진행 기록](../fe-merge-fixes.md)에 기록합니다.
실제 OAuth·운영 서버·실기기·원격 CI는 이 로컬 대역 화면 검증으로 증명하지 않습니다.

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-d233bd2c29688a3a"></a>

### 2026-10-14 — OS 인디케이터와 하단 안전 영역 정리

<a id="b-3096374757ea7112"></a>

- 작업 브랜치 `feature/figma-ui-alignment`, 변경 전 기준 `d01873c`.
  사용자 확정 기준은 **탭 영역 64px + 글자 확대 증가분 + 실제 OS 하단 안전 여백**이다.
  대상은 공통 탭을 쓰는 홈·아카이브·즐겨찾기·마이·상세·Placeholder와 카드 다시보기다.
  로그인·시작·저장 화면 맞춤, 마이·상세 본문의 확대 디자인, 안내·공지와 추천 API는 후속으로 둔다.
- 공통 바는 `MediaQuery.viewPaddingOf(context).bottom`을 한 번만 합산한다.
  별도 `SafeArea`나 `viewInsets.bottom`을 더하지 않으므로 키보드 표시에도 바 높이는 안정적으로 유지된다.
  기존 최대 두 줄·글자 배율·네 아이콘 정렬·28px 아이콘·색상·탭 연결과 저장 버튼 72×72px/상단 −22px을 유지한다.
  기존 96/140px 높이는 이전 커밋의 결과이며 이번 결과를 그 수치에 강제로 맞추지 않는다.
- 카드 다시보기는 빈 상태·카드 상태 모두 하단 안전 영역을 적용한다. 카드의 기존 크기·위치·진행 표시·
  드래그/다음 카드·북마크·나가기 동작을 보존하고 카드와 전환 애니메이션을 안전 영역 안에서 클리핑한다.
  두 사용처의 가짜 선과 사용하지 않는 공통 `NavigationHomeIndicator`를 제거한다.
  화면 생성자·콜백·API·데이터·콘텐츠 보존 정책과 OS 탐색 표시/네이티브 전체 화면 설정은 변경하지 않는다.
- Figma 하단 바 `111:3680`, C01 `111:3584`, C02 `111:3681`, G02 `111:5047`의 컨텍스트·원본을
  **2026-10-14 01:58:26 KST / 2026-10-13 16:58:26 UTC**에 새로 조회했다.
  변경 전 촬영 gate 확인 후 제품 수정 직전 **02:28:08 KST / 17:28:08 UTC**에 네 노드를 다시 조회했다.
  초기와 직전 원본 PNG는 모두 byte 단위로 같음을 확인했고 두 조회의 컨텍스트·시각을 각각 보존했다.
  전체 화면 원본은 비교 근거로만 사용하며 제품 에셋으로 사용하지 않는다.
  Figma의 96px 고정 바/그려진 인디케이터와 실제 OS 여백은 사용자 확정 기준에 따라 구분한다.
- **제품 수정 전에** 같은 고정 대역 데이터로 iOS·Android 제스처·Android 3버튼의 새 변경 전 화면을 확보했다.
  홈 정상·빈 상태/배율 1·2, 공유 탭 6개 화면/단독 확대 탭, 카드 다시보기의 정상·빈·드래그·다음 상태를 포함한다.
  변경 전 보고서 9개, Flutter PNG 72개·OS 포함 원본 PNG 72개·원본 영상 9개를 기록했다.
  `before-gate.json`에서 제품 diff가 비어 있고 기준 커밋이 `d01873c`임을 확인했으며 이전 촬영 자료를 재사용하지 않았다.
  BEFORE 보고서의 `passed`는 기존 화면 렌더링/입력 검사의 결과다. 새 OS 높이·클리핑 기준은 AFTER에만 적용하므로
  BEFORE의 오류 0건을 인디케이터 중복·OS 경계 침범이 없다는 의미로 사용하지 않는다.
- [새 하단 안전 영역 테스트](../../frontend/test/bottom_safe_area_test.dart)는 수정 전 **6 passed / 61 failed**다.
  폭 320/375px·Android/iOS·배율 1/1.5/2·하단 여백 0/24/34/48px의 실제 바/라벨/아이콘/탭 경계를 확인한다.
  라벨 증가분은 실제 RenderParagraph 높이로 검증하며 제품의 TextPainter 계산을 테스트에 복제하지 않는다.
  앱이 그리는 검은 선의 픽셀, 카드 안전 경계와 실제 드래그/240ms 전환의 하단 픽셀 침범도 재현했다.
  키보드 상태 4개와 하단 여백 0인 카드 2개는 기존 성공으로 보존했다.
- 키보드 `(padding.bottom=0, viewPadding.bottom=34, viewInsets.bottom=300)`에서 바 높이 유지·
  키보드 높이 미합산·닫은 뒤 복원, 저장 버튼 중심/하단 탭과 네 경로를 확인했다.
  관련 확대 30개·홈 35개·상단 안전 영역 11개·저장/검색 2개·시트 3개도 함께 회귀 검사했다.
  상단 헤더의 기존 64/56px와 홈 소개 140px는 하단 바 높이와 다른 기준이며 그대로 유지한다.
- 최종 관련 묶음은 새 하단 67개와 위 회귀 검사 합계 **148 passed**다.
  기존 확대 테스트의 기본 바 높이는 iOS 98px·Android 64px의 실제 주입 inset 기준으로 갱신했다.
  홈·상단·저장·시트 검사의 기대값은 바꾸지 않고 통과했다.
- 최종 `flutter test --no-pub --reporter expanded` **692 passed**,
  `flutter analyze --no-pub` **문제 없음**(6.1초), 변경 Dart 7개 형식 검사 **0 changed**다.
  이번 기기 실행의 홈·공통 탭·카드 다시보기 AFTER 보고서 **9개 모두 `passed: true`·`checksCompleted: true`·
  프레임워크 오류 0건**이다. 이전 625개 통과와 과거 기기 성공을 이번 결과로 사용하지 않는다.

<a id="b-bcf7ce1e5decb258"></a>

| 실행 조건 | 실제 창·안전 여백 | 하단 바 배율 1 / 1.5 / 2 | 카드 정상·빈·드래그·전환의 하단 경계 |
| --- | --- | --- | --- |
| iPhone 16 / iOS 18.6 Simulator | 논리 393×852, DPR 3, 상단 59px·하단 viewPadding 34px | 98 / 126 / 142px | y=818px = 852−34, 카드 크기·상단 257px 유지 |
| Pixel 3a 설정 / Android 13 API 33 / 제스처 | 논리 392.7×783.3, DPR 2.75, 상단 24px·하단 viewPadding 0px | 64 / 92 / 108px | y=783.27px, 실제 OS 제스처 바는 Flutter 창 외부 |
| 같은 Emulator / 3버튼 | 논리 392.7×759.3, DPR 2.75, 상단 24px·하단 viewPadding 0px | 64 / 92 / 108px | y=759.27px, 실제 OS 3버튼 바는 Flutter 창 외부 |

<a id="b-46b4fc4b3505cb87"></a>

- Android 기종은 AVD `Clipback_Share_API_33`의 `sdk_gphone64_arm64`다. 하단 여백 0은 실제 보고값이며,
  Android에 임의의 32/34px를 더하지 않는다. OS를 포함한 원본에서 앱의 검은 선 제거와 탐색 표시 보존을 확인했다.
  iOS의 새 높이는 Figma 96px보다 2px 높으며 확대와 실제 여백에 따른 차이도 사용자 확정 기준에 따른다.
- 세 조건의 홈에서 today/archive/content/bookmark 각 1회, 북마크의 카드 탭 전파 없음,
  페이지 점 3/4, 세로 스크롤·빈 홈 저장 진입·실제 키보드 표시·닫기를 확인했다.
  일반 홈 세로 이동은 iOS 85px·제스처 84.73px·3버튼 108.73px다.
  첫 양수 키보드 inset은 각각 약 335.44/268/194.18px로 애니메이션 도중 측정값이며,
  전체 키보드 표시·닫기는 OS 포함 원본과 영상으로 별도 확인했다.
- 공유 탭은 여섯 실제 화면 본문을 배율 1로, 단독 탭은 375px/배율 1.5·2와 320px/배율 2로 실행했다.
  archive/bookmark/my 각 4회·home 5회·카드 1회·상세 이전/다음 각 1회·추가 버튼 6회,
  세 확대 조건의 추가 버튼 중심·하단 가장자리 탭 각각 1회와 Placeholder의 실제 Navigator 복귀가 통과했다.
  아이콘 28px·정렬·두 줄 라벨·추가 버튼 72×72px/상단 −22px·상세 버튼 비겹침을 확인했다.
- 카드 다시보기는 북마크·카드 열기·정상 나가기·빈 상태 나가기 각 1회,
  드래그 offset 약 0.6653과 다음 카드 인덱스 1을 확인했다.
  카드의 496px 높이·상단 좌표는 변경 전과 같으며 하단 보호와 가짜 선 제거만 바뀌었다.
- 세 조건의 변경 전·후 보고서에서 기종·실제 창·DPR·고정 데이터·배율·콜백 수와 프리뷰 소스 해시가 일치한다.
  변경 전·후 각각 OS 원본 PNG 72개·Flutter PNG 72개·원본 영상 9개를 확보했다.
  [독립 대조 결과](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/bottom-safe-area/root-final-verification.json)에
  보고서 9쌍·이미지 크기 일치·비교 57건의 원본 경로 존재를 기록했다.

<a id="b-3fb6776e7449990d"></a>

증거 루트: `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/bottom-safe-area`.

<a id="b-177b3a91fdeb073c"></a>

- [OS 포함 원본 3열 비교](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/bottom-safe-area/comparison-document.html)는
  플랫폼·탐색 방식별로 **변경 전 → 변경 후 → Figma**를 보여준다. 각 비교의 데이터·배율·스크롤·기종·OS·탐색 방식을 맞춘다.
  원본의 OS 영역/프레임 크기/대역 콘텐츠 차이는 유지하며 비교를 위해 픽셀을 잘라내거나 보정하지 않는다.
  마이·상세/Placeholder 등은 이번 수정 대상인 하단 바 원본을 Figma 참조로 쓰며 본문 전체 일치로 보고하지 않는다.
  확대·카드 드래그/빈 상태의 전용 디자인은 없으므로 기본 원본과 사용자 확정 OS 기준을 명시한다.
  비교는 각 조건의 홈 6개·공통 탭 9개·카드 4개, 총 **57건**이다.
  원본 모바일 시계·기기 프레임·OS 여백을 그대로 보존하며 원본 Figma도 재가공하지 않는다.

<a id="b-878c2253cb1ee949"></a>

| 이번 AFTER 동작 영상 | 자료 |
| --- | --- |
| iOS 홈 → 공통 탭 → 카드 다시보기 | [영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/bottom-safe-area/ios/interaction-final.mp4) |
| Android 제스처의 같은 동작 | [영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/bottom-safe-area/android-gesture/interaction-final.mp4) |
| Android 3버튼의 같은 동작 | [영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/bottom-safe-area/android-three-button/interaction-final.mp4) |

<a id="b-6bd0cae177e376e1"></a>

- 세 결합 영상은 각 조건의 AFTER 원본 3개를 `ffmpeg -c copy`로 연결하고 재인코딩·스케일·재프레이밍하지 않았다.
  iOS 녹화 원본은 H.264 1178×2556이고 PNG 원본은 1179×2556이다. Android는 세 영상 모두 1080×2220이다.
  ffprobe로 최종 길이 iOS 238.318초·제스처 267.959초·3버튼 299.305초를 확인했다.
  녹화 원본의 가변 프레임률·시간 기준을 유지한 `ffmpeg -fps_mode passthrough -enc_time_base -1 -f null -` 전체 디코딩도
  세 영상 모두 종료 코드 0·오류 로그 0바이트다. 영상 파일을 다시 쓰지 않고 검증했다.
  원본 영상과 보고서는 각 조건의 `after/home`, `after/navigation`, `after/card-review`에 각각 보존했다.
- 별도 `EntryHomeIndicator`의 실제 사용처는 `SplashScreen`의 `EntrySurface`다. A01 `111:3380`의 전체 프레임과
  OS 안전 영역 배치를 확인할 후속 항목으로 남긴다. 저장 화면의 `_SaveHomeIndicator`는 D01 `111:4765`,
  D05 `111:4902`, D07 `111:4814`, D09 `111:4865`의 버튼·키보드·결과 배치와 함께 별도 디자인 확인 대상으로 유지한다.
  공통 탭의 정리를 앱 전체 인디케이터 제거 완료로 보고하지 않는다. [디자인 확인 목록](../figma-ui-alignment-plan.md)을 따른다.
- 실제 OAuth·운영 서버·원격 CI·실기기·실제 저장 완료는 이번 로컬 대역 실행에 포함하지 않는다.
  화면 증거·빌드 생성물·`AGENTS.md`는 커밋에서 제외하고 푸시·PR을 수행하지 않는다.
- SVG 로더의 기존 `unhandled element <filter/>` 메시지는 변경 전·후 로그에 동일하게 남아 있다.
  이번 하단 변경과 구분하며 프레임워크 예외 0건을 모든 로그 메시지의 부재로 보고하지 않는다.
- Android 탐색 설정을 원래 mode 2/gestural 및 전체 navbar overlay 목록과 일치하게 복원했다.
  이번에 시작한 두 기기·Flutter·녹화 프로세스를 종료하고 AVD·앱 데이터를 보존했다.
  이전 비교 서버 8765와 이번 원본 비교 서버 8766·브라우저는 유지한다.
  최종 문서 링크 127개·diff·공백·민감 정보/생성 파일 제외를 확인했으며,
  제품 2개·테스트/프리뷰 5개·문서 3개, 총 10개 파일만 한 커밋으로 저장한다.

## 원문 출처: docs/figma-ui-alignment-plan.md

<a id="b-5e736e18f9277fcc"></a>

### OS 하단 안전 영역과 인디케이터 작업

<a id="b-f473534af97b2eea"></a>

작업 기준은 `d01873c`이다. Figma 공통 하단 탭 `111:3680`, C01 `111:3584`, C02 `111:3681`,
G02 `111:5047`의 원본을 2026-10-14 01:58:26 KST(2026-10-13 16:58:26 UTC)에 처음 조회하고,
제품 수정 직전 2026-10-14 02:28:08 KST(2026-10-13 17:28:08 UTC)에 다시 조회했다.
사용자는 Figma의 고정 96px 대신 **기본 콘텐츠 64px + 글자 확대 증가분 + 실제 OS 하단 안전 영역**을 선택했다.
Figma의 인디케이터는 앱 그래픽으로 복제하지 않고 OS에 맡긴다. 안전 영역과 원본 프레임 차이를 비교 기록에 설명한다.

<a id="b-c48004a2cf64d9cd"></a>

| 적용 영역 | 승인 기준과 구현 범위 |
| --- | --- |
| 공통 하단 탭 | 총높이는 `64 + fontExtra + MediaQuery.viewPaddingOf(context).bottom`이다. 글자 확대 증가분은 기존 네 라벨의 공통 높이 계산을 유지한다. 실제 하단 inset은 한 번만 합산하며, `viewInsets.bottom`의 키보드 높이를 더하거나 별도 `SafeArea`로 중복 소비하지 않는다. |
| 아이콘·라벨·추가 버튼 | 기존 56px 항목과 글자 확대, 두 줄 라벨·아이콘 정렬·활성 표시·네 탭 목적지를 유지한다. 추가 버튼은 72×72px·중앙·바 위로 22px 위치와 중심/바 안쪽 하단 탭을 유지한다. 기기 안전 영역에 따라 바 상단과 본문 사용 높이는 달라진다. |
| 카드 다시보기 | 빈 목록과 콘텐츠가 있는 목록 두 분기 모두 하단 `SafeArea`를 적용한다. 일반 목록의 `ClipRect`는 실제 하단 안전 영역 앞에서 끝난다. 카드의 고정 크기·상단 좌표·애니메이션을 유지하고, 드래그 시 안전 영역 밖으로 나간 부분은 기존 클리핑으로 잘라 OS 영역에 그리지 않는다. 카드·나가기·북마크·다음 카드 동작을 보존한다. |
| 공유 가짜 인디케이터 | 공통 바와 카드 다시보기에서 사용하는 `NavigationHomeIndicator`와 두 사용부를 제거한다. OS 플래그·네이티브 인디케이터 표시 설정을 바꾸지 않는다. 이 공통 바 작업 당시 별도 `EntryHomeIndicator`와 `_SaveHomeIndicator`는 보류했다. 진입 스플래시는 계속 보류하며 저장 창은 아래 사용자 확정 하단 작업으로 분리한다. |
| 상세·시트의 영향 | 공통 바를 사용하는 여섯 화면을 확인한다. 상세의 기존 `DetailPager`/상태 행은 바 높이를 따라 이동하며 별도 안전 영역을 추가하지 않는다. 저장 창·바텀시트는 기존 독립 안전 영역과 입력 보존을 유지하고, 키보드·시트를 닫은 뒤 탭의 안전 영역 복원을 확인한다. |

<a id="b-3f61637919eab923"></a>

화면 생성자·공개 콜백·API·데이터 모델·콘텐츠 보존/삭제 처리에는 변경이 없다.
마이·상세 본문의 글자 배율 2는 별도 디자인 확인 대상으로 유지한다.
기존 확대 커밋의 625개 테스트·96/124/140px 측정과 이번 작업의 검증 결과를 구분한다.

<a id="b-c653bae20da3b1ab"></a>

### OS 하단 작업의 검증 상태

<a id="b-e3d3d32cf70f2d71"></a>

- 수정 후 관련 검사 **148개**, 전체 Flutter 테스트 **692개**를 통과했고 정적 분석은 **문제 없음**이다.
  Dart 파일 7개의 형식 검사도 변경 없이 통과했다. 관련 검사는 하단 67·확대 30·홈 35·상단 11·저장/검색 2·시트 3개다.
  수정 후 iOS·Android 제스처·Android 3버튼 모드에서 세 프리뷰 모두 통과했다.
  총 9개 `after` 보고서의 `passed`·`checksCompleted`는 `true`, 프레임워크 오류는 0건, `failure`는 `null`이다.
  이전 커밋의 성공을 이번 성공으로 기록하지 않는다.
- 수정 전 iOS·Android 제스처·Android 3버튼 모드의 프리뷰 세 종류, 총 9개 보고서를 확인했다.
  모두 `phase: before`, `passed`·`checksCompleted: true`, 프레임워크 오류 0건이다.
  `before`는 기존 화면·동작을 기록하며 새 OS 안전 영역 판정은 `after`에서만 실행하므로,
  변경 전 통과를 가짜 인디케이터 중복이나 하단 안전 영역 문제가 없었다는 의미로 사용하지 않는다.
- [하단 안전 영역 회귀 테스트](../../frontend/test/bottom_safe_area_test.dart)는 폭 320·375px,
  배율 1·1.5·2, 하단 inset 0·24·34·48px에서 한 번의 안전 영역 합산·네 탭/FAB 입력을 확인한다.
  키보드 높이와 안전 영역을 구분하며 카드 빈/일반 상태·드래그·전환 중 하단 픽셀을 검사한다.
- 이번 [홈 프리뷰](../../frontend/test/support/figma_home_preview.dart),
  [공유 내비게이션 프리뷰](../../frontend/test/support/navigation_layout_preview.dart),
  [카드 다시보기 프리뷰](../../frontend/test/support/card_review_safe_area_preview.dart)를 수정 전후 같은 조건으로 실행했다.
  각 프리뷰는 실제 위젯과 고정 대역 데이터·합성 포인터를 사용하며 실제 세션·HTTP·저장을 사용하지 않는다.
  `FIGMA_HOME_PHASE`, `NAV_LAYOUT_PHASE`, `CARD_REVIEW_PHASE`의 `before`/`after`를 구분한다.
  이번 홈 프리뷰는 양 phase 모두 여섯 비교 상태와 다섯 동작 화면, 총 11장을 촬영하고 스크롤·저장 입력/키보드·닫기를 실행한다.
  내비게이션 9장·카드 다시보기 4장을 합쳐 모드별 phase당 24개 화면이며, 변경 전·후 각각 원본 OS 화면·Flutter 화면 각 72개와 영상 9개를 보존했다.
- iOS에서 하단 inset 34px과 바 높이 98/126/142px(배율 1/1.5/2)을 확인했다.
  카드 viewport는 상단 59px·하단 818px(852−34)이었고, 고정 카드 496px·드래그 후 다음 인덱스 1과
  북마크·카드 열기·일반/빈 목록 나가기 각 1회를 확인했다.
  Android 두 모드의 `viewPadding.bottom`은 0px, 바 높이는 64/92/108px이었다.
  카드 viewport 하단은 제스처 783.2727px·3버튼 759.2727px로 각 모드의 안전한 Flutter 영역 끝과 일치했다.
  3버튼 모드의 OS 영역은 Flutter 화면 바깥에서 차지하므로 그 높이를 바에 다시 더하지 않는다.
  여섯 실제 본문은 일반 배율이며 공통 탭 단독 확대·상세 이전/다음·Placeholder 복귀·FAB 중심/하단 입력을 확인했다.
- 증거 루트는 `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/bottom-safe-area`다.
  `ios`, `android-gesture`, `android-three-button` 아래 각각 `before`/`after`의 `home`, `navigation`, `card-review`를 보존했다.
  [원본 3열 비교 문서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/bottom-safe-area/comparison-document.html)는
  3조건 × 홈 6개·내비게이션 9개·카드 4개, 총 57개 비교를 제공한다. OS 픽셀과 원본 PNG를 보정하지 않았다.
  조건별 연결 영상: [iOS](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/bottom-safe-area/ios/interaction-final.mp4),
  [Android 제스처](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/bottom-safe-area/android-gesture/interaction-final.mp4),
  [Android 3버튼](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/bottom-safe-area/android-three-button/interaction-final.mp4).
- Flutter `RepaintBoundary` 캡처는 Flutter 배치 측정용이며 OS 인디케이터 자체를 포함하지 않는다.
  OS 비교에는 `simctl io screenshot`·`adb exec-out screencap`으로 얻은 원본 화면과 영상도 사용한다.
  플랫폼·모드별 변경 전·후·Figma를 나란히 전달하고 원본을 보정하거나 없는 기준 화면을 만들어 채우지 않는다.
  기기 준비·비교 항목이 누락되면 이유와 미검증 범위를 기록한다.
- 기종·OS·최종 통과 수·기기 결과·영상·한계는 [프론트 진행 기록](../fe-merge-fixes.md)에 이번 작업으로 따로 기록했다.
  원격 CI·실제 OAuth·운영 서버·실기기 성공을 의미하지 않는다.
