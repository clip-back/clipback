# 미분류와 확인된 빈 상태

- 최초 기록일: 2026-10-17
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-b2b6b93432601f40"></a>

### 미분류 콘텐츠 목록·확인된 빈 상태1배율 — 2026-10-17

<a id="b-34853415142d889a"></a>

`9fce418` 기준으로 Page 1 > `261007`의 [E06 정상 미분류 목록](https://www.figma.com/design/svNWsTFh8Ws1Mpt8XQIcrN/?node-id=111-4525) (`111:4525`)·[확인된 빈 미분류](https://www.figma.com/design/svNWsTFh8Ws1Mpt8XQIcrN/?node-id=142-5097) (`142:5097`)의 **1배율 승인 영역**을 적용·검증했다. 다른 화면 전체와 새 확대 맞춤 완료를 뜻하지 않는다.

<a id="b-a59d9d7624c1dc71"></a>

### 적용 범위와 유지한 정책

<a id="b-6479da229ffae8f6"></a>

- 사용자 확정으로 미분류에서만 정렬/개수 행과 랜덤 보기 진입을 숨기고 설정을 기존 카테고리 관리로 연결했다. 기존 선택 정렬과 서버 조회·일반 카테고리의 정렬/랜덤 보기·뒤로의 카테고리 탭 복귀는 유지한다.
- 상단64px/좌우16px·뒤로/검색/설정24px·제목18 SemiBold/자간−0.45/검정/AUTO·아이콘 중심32.5px을 적용했다. 정상 첫 카드만 헤더 아래12px, 카드 사이8px이다. 기존 전체보기의 정렬된 카드 본문/아이콘을 재사용하고 미분류 시스템 배지만 표시용 ‘미분류’/57×22px/회색으로 바꿨다. 실제 ID·전체 소속/순서·제목/요약/날짜와 카드 동작은 보존한다.
- 실제 미분류 metadata ID와 현재 피드 필터가 일치하고, 조회 완료·오류/로딩/다음 페이지 없음·현재 items0인 경우에만 빈 원본을 표시한다. 전체 저장0이나 집계 누락으로 오판하지 않는다. 새 상자86×100px과 원본 크롭·기존 Pretendard Bold 별칭/24px 제목·16px 본문·16/8px 간격·CTA 없음, 본문 중앙−84px/본문 안 제한과 자연 높이 스크롤을 적용했다. 빈 본문에는 목록의12px을 더하지 않는다.
- [보존 감사](/private/tmp/clipback-unclassified-20261017/preservation-audit.json): 필수 생성 인수·콜백·REST/API·모델·Repository/ViewModel/App·공통 EmptyState/하단 바·네이티브 설정·기존 에셋/폰트를 보존했다. 공유 카드의 새 선택 옵션 기본값은 꺼짐이며 E01과 일반 카테고리/검색/즐겨찾기 기본 표현은 유지한다. 관리/검색/상세 단순 왕복은 기존 필터/위치를 유지하고, 분류 변경 성공 후 재조회는 기존처럼 위치0으로 초기화한다.

<a id="b-f6bb144abc085525"></a>

### 원본·재현·최종 검사

<a id="b-47599512b0974c13"></a>

- [이번 Figma 컨텍스트/원본](/private/tmp/clipback-unclassified-20261017/figma/reference-index.json): **2026-10-17 13:07:48 UTC /22:07:48 KST**에 두 노드를 각각1회 조회해 컨텍스트와375×812 PNG를 확보했다. MCP2호출이며 별도 메타데이터/스크린샷 호출·fallback·대체 디자인은 없다. 정적 에셋10개는 반환 URL에서 별도로 내려받았다.
- [에셋/번들/실제 렌더 감사](/private/tmp/clipback-unclassified-20261017/static-assets-verification.json): 원본SVG9건 중6건은 byte동일, 설정2건의clip ID와 별1건의XML 속성 순서만 다른3건은 시각 구조가 동일하다. 새1254×1254 PNG는 원본 byte 그대로 등록했으며 홈의71×82 이미지를 대체 사용하지 않았다. 선택 별은 E01의 기존 확정 에셋을 재사용한다. 최종APK/Runner8역할의 원본/등록/바이트·기하·무필터와 실제6상태 관측을 재확인했다. 그림자의 alpha 효과와 원색 주 이미지를 구분한다.
- [새 변경 전 게이트](/private/tmp/clipback-unclassified-20261017/before-gate.json): 제품 수정 전 **새 canonical OS원본6장**을 확보했다. [동결 소스](/private/tmp/clipback-unclassified-20261017/fixture-manifest.json)의 fixture SHA는 `8e686531978ff0ab84f6f65f4a390cf663f011289f3546ff6249e648d96f7e86`이며 전후 동일하다. 실제 앱/메모리 API 대역의 미분류99·8개4+4페이지와 마지막1건 분류→확인0/다른 콘텐츠 보존을 사용했다.
- 초기28건은7통과/예상 목표차이21·예상밖0으로 재현했다. [이번 자동 검사](/private/tmp/clipback-unclassified-20261017/automatic-checks.json): 집중 **28/28**(6.864초), 관련 **451/451**(36.148초), 전체 **1169/1169**(93.141초) 통과·실패/건너뜀0이며 `flutter analyze --no-pub` **문제0건**이다. 기존 확대 자동 검사를 유지했다. 최종 전체 검사와 분석은 계측 교정 후 다시 실행했다. 별도 외부 진단2건은375×360/1배율의 iOS/Android에서250px 자연 그룹을139/208px 본문 안에서 끝까지 스크롤해 마지막 본문 전체 노출과 오류0을 확인했으며 전체 앱 검사 수에 합산하지 않는다.
- [계측 교정과 제외한 진단](/private/tmp/clipback-unclassified-20261017/.attempts/oracle-width-r1/oracle-amendment.json): 처음 프리뷰가 부모 텍스트 열192px과 자연 문단 폭을 같게 검사한 오류를 발견했다. 제품을 그 검사에 맞춰 늘리지 않고 열의 최대 제약192px·실제 문단의 포함/가운데 정렬로 교정했다. 이전 BEFORE6/부분AFTER2는 진단으로 보존·제외하고, 기준 제품을 안전 복원해 교정된 동일 fixture로 BEFORE부터 새로 촬영했다. [제품 복원 바이트 확인](/private/tmp/clipback-unclassified-20261017/temporary-baseline.json)으로 최종 제품6개가 이전 통과 구현과 byte동일함을 확인했다.

<a id="b-bfc95a476ef57010"></a>

### 양 플랫폼 실행과 비교

<a id="b-823c683ed6ee090d"></a>

- **iPhone16/iOS18.6**: Flutter 논리창 `Size(393.0, 852.0)`·DPR3.0·OS viewPadding 상59.0/하34.0px·IME0.0px, 36기록이다. 실제 최대 스크롤 관측은 829.000px이며 해당 시점 maxScrollExtent와 일치한다. style/layout/behavior/coverage/checksCompleted/전체 `passed:true`·프레임워크 오류0이다.
- **Android13/API33 제스처**: Flutter 논리창 `Size(392.7, 783.3)`·DPR2.75·OS viewPadding 상24.0/하0.0px·IME0.0px, 36기록이다. 실제 최대 스크롤 관측은 828.727px이며 해당 시점 maxScrollExtent와 일치한다. style/layout/behavior/coverage/checksCompleted/전체 `passed:true`·프레임워크 오류0이다.

<a id="b-f3a85355f3f89558"></a>

| 플랫폼 | 첫 카드 시작 여백 전→후 | AFTER 카드·배지 | 빈 그룹·이미지 슬롯 | 제목 자연 폭 / 텍스트 열 최대 폭 |
| --- | --- | --- | --- | --- |
| iOS | 64→12px | 173px / 57×22px | 224×250px / 86×100px | 145.927px / 192px |
| Android | 64→12px | 173px / 57×22px | 224×250px / 86×100px | 145.927px / 192px |

<a id="b-a1d100724e457801"></a>

- 두 기기의 화면 내부는 기존 PhoneFrame375px 상한을 유지하며320px은 자동 검사 범위다. 실제 OS 전체 원본과 Flutter 논리창/하단 inset의 차이를 구분한다.
- [실측·동작 요약](/private/tmp/clipback-unclassified-20261017/native-validation-summary.json)·[독립 동일 조건/API 대역 판정](/private/tmp/clipback-unclassified-20261017/pair-verification.json): 실제 배너ID99/4+4페이지·합성 포인터 드래그·8행 완전 노출/최대 스크롤·관리/검색/상세 왕복·북마크1회 변경/복원·더보기 취소·분류 실패/재시도(중복 제출 방지는 자동 App 회귀로 별도 확인)·마지막 한 건 분류 후 빈 화면/배너 제거·네 하단 탭·저장 진입/추가 저장 없는 닫기를 확인했다. native 공유는 첫 실행부터 메모리 채널로 격리해 위임0/미지원0이며 기존 큐·자격 내용을 조회/출력/삭제하지 않았다.
- [새3열 비교6쌍](/private/tmp/clipback-unclassified-20261017/comparison-document.html)·[비교 QA](/private/tmp/clipback-unclassified-20261017/comparison-qa.json): 양 플랫폼 정상0/300px·빈0의 새 전후 OS원본 각6장이다. 실제 데이터/1배율/IME0/스크롤을 맞췄으며 Figma누락/조건 불일치0이다. 스크롤300 전용 원본은 없으므로 같은 E06 전체 원본을 기준으로 설명한다. 예제 데이터·OS 창/상태/탐색 표시·실제 하단 여백 차이를 그대로 표시하며 원본 자르기/보정은 없다.

<a id="b-a0296ff051d4e7c7"></a>

| 상태 | iOS | Android 제스처 |
| --- | --- | --- |
| 정상 목록·스크롤0 | [3열 비교](/private/tmp/clipback-unclassified-20261017/comparisons/ios-unclassified_list_scale_1_scroll_0.png) | [3열 비교](/private/tmp/clipback-unclassified-20261017/comparisons/android-gesture-unclassified_list_scale_1_scroll_0.png) |
| 정상 목록·스크롤300 | [3열 비교](/private/tmp/clipback-unclassified-20261017/comparisons/ios-unclassified_list_scale_1_scroll_300.png) | [3열 비교](/private/tmp/clipback-unclassified-20261017/comparisons/android-gesture-unclassified_list_scale_1_scroll_300.png) |
| 조회 완료된 미분류0 | [3열 비교](/private/tmp/clipback-unclassified-20261017/comparisons/ios-unclassified_empty_scale_1_scroll_0.png) | [3열 비교](/private/tmp/clipback-unclassified-20261017/comparisons/android-gesture-unclassified_empty_scale_1_scroll_0.png) |

<a id="b-b38f88cbfd941d16"></a>

- 개요: [iOS 3상태 비교](/private/tmp/clipback-unclassified-20261017/comparisons/ios-comparison-overview.png) · [Android 3상태 비교](/private/tmp/clipback-unclassified-20261017/comparisons/android-gesture-comparison-overview.png).
- 영상: [iOS AFTER](/private/tmp/clipback-unclassified-20261017/ios/after/interaction.mp4) · [Android AFTER](/private/tmp/clipback-unclassified-20261017/android-gesture/after/interaction.mp4). [미디어 검사](/private/tmp/clipback-unclassified-20261017/media-verification.json)는 두 원본의 동작 완료까지 녹화와 전체 디코딩 오류0을 확인했다. Android 첫 영상은 인코딩된 길이가 실행 구간보다0.596초 짧아 완료 범위 게이트를 통과하지 못했다. [제외한 영상 진단](/private/tmp/clipback-unclassified-20261017/.attempts/android-recording-tail-r1)으로 보존하고 제품/동결 fixture/정적 화면은 유지한 채 시작·종료 여유를 둬 동작 영상만 재촬영한 결과를 사용했다.
- [환경 정리](/private/tmp/clipback-unclassified-20261017/cleanup-verification.json)·[최종 자원 확인](/private/tmp/clipback-unclassified-20261017/final-resource-check.json): 앱/기기 종료·포워딩/임시 리스너 제거·탐색/키보드 원설정 일치·기기 데이터 보존을 확인했다. [HTML 참조/문법 검사](/private/tmp/clipback-unclassified-20261017/comparison-html-verification.json)는 정적 검사이며 비교 브라우저/HTTP서버 실행 성공으로 보고하지 않는다.
- 검증은 실제 ClipbackApp/Repository와 HTTP MockClient·메모리 세션·합성 포인터의 로컬 실행이다. 운영 서버·실제 OAuth·영속 저장·실기기·원격 CI·새 확대/3버튼 기기 촬영의 증거가 아니다. 미조회/로딩/오류·일반 목록의 미확정 빈 상태·정렬/미선택 탭 굵기·시트 배경/자유 색상·새 확대 맞춤은 보류한다.

<a id="b-57219f4aa59edac9"></a>

### 프리뷰 실행

<a id="b-6eae8f62469d6974"></a>

```bash
/Users/leehyeongyu/flutter/bin/flutter run --no-pub -t test/support/unclassified_preview.dart --dart-define=UNCLASSIFIED_PHASE=after -d <device-id>
```

<a id="b-baa16db8a9f8f38b"></a>

프리뷰는 loopback8767의 `/scene?kind=list&offset=0`·`/scene?kind=list&offset=300`·`/scene?kind=empty&offset=0`으로 고정 상태를 준비하고 `/run`으로 실제 앱 동작을 확인한다. Android는 세션 소유8768→8767 포워딩을 사용한 뒤 제거한다. phase는 기록용이며 같은 수정 후 빌드의 label만 바꿔 BEFORE로 사용하지 않는다. BEFORE는 기준 제품으로 새 빌드/촬영해야 한다. native 공유 격리는 첫 앱 실행 전에 설치한다.

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-b23bc6233813df7f"></a>

### Figma 미분류 콘텐츠 목록·확인된 빈 상태1배율 — 2026-10-17

## 원문 출처: docs/figma-ui-alignment-plan.md

<a id="b-3c795a6696939de5"></a>

### 미분류 콘텐츠 목록·확인된 빈 상태 적용·검증 — 2026-10-17
