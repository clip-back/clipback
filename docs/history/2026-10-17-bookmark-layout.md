# 즐겨찾기 표현

- 최초 기록일: 2026-10-17
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-b937d5dd13af95ea"></a>

### 즐겨찾기 화면의1배율 맞춤 — 2026-10-17 작업

<a id="b-3a3e1e0991551f1c"></a>

`5a19b9d` 기준으로 Page 1 > `261007`의 [I01 콘텐츠 있음](https://www.figma.com/design/svNWsTFh8Ws1Mpt8XQIcrN/?node-id=111-4091) (`111:4091`)·[I02 빈 상태](https://www.figma.com/design/svNWsTFh8Ws1Mpt8XQIcrN/?node-id=111-4103) (`111:4103`)에서 **즐겨찾기의 승인된 1배율 상단·목록·확인된 빈 표현**을 적용·검증했다. 검색 화면·즐겨찾기 전체 기능·새 확대 맞춤 완료를 뜻하지 않는다.

<a id="b-f44aaa26bb2e6dec"></a>

### 적용 범위와 보존 정책

<a id="b-fd8b1f2d9e4c6e7d"></a>

- 제목을 ‘즐겨찾기’로 바꾸고 뒤로가기를 제거했다. 헤더64px/좌우16px·시각 중심32.5px·Pretendard18 SemiBold/−0.45/검정/AUTO와 검색/설정24px·간격16px을 적용했다. 설정은 기존 카테고리 관리를 열고 닫으면 즐겨찾기로 돌아온다.
- 정상 목록의 행52px에는 사용자 확정 **읽기 전용 ‘최신순’**과 **‘불러온 N개’**를14 Medium/−0.35/#767676/AUTO로 표시한다. 원본의 드롭다운 화살표·메뉴와 ‘총 N개’는 복사하지 않는다. 기존 콘텐츠 저장일/ID 최신순의 독립 `is_favorite=true` 조회·커서 페이지네이션을 유지한다.
- E01의 정렬된 카드 표현을 즐겨찾기에서만 선택해 재사용했다. 기본173px·제목1줄/요약2줄·구분선/날짜·북마크28px/더보기24px·카드 간격8px과 실제 카테고리명/색/순서/복수 소속 자연 Wrap을 보존한다. E06 회색 미분류 옵션과 공유 카드의 기본값은 바꾸지 않았다.
- 즐겨찾기 필터 true/검색·카테고리 없음/조회 완료/오류·로딩·추가 페이지 없음/피드와 표시 항목 모두0인 경우만 I02를 표시하고52px 행을 숨긴다. 상자40×46px·원본 크롭/실루엣 그림자·제목16 Medium/−0.4/#484848/AUTO·본문14 Medium/−0.35/#767676/1.6·16/8/16px 간격·책18px과 ‘전체 리스트 보기’ 버튼을 적용했다. 그룹 최대260px·자연 높이/문단 폭을 유지하고 실제 본문 중앙−43.5px을 본문 안으로 제한하며 짧은 공간에서는 스크롤한다.
- 선택적 콜백2개만 추가했다. 빈 화면 버튼은 기존 아카이브 열기로 탭0·카테고리/검색 필터 없음에 진입하고 **기존 아카이브 정렬은 보존**한다. 단순 검색/상세/관리/하단 탭 왕복의 즐겨찾기 피드·위치는 유지하며 실제 변경 성공 후 재조회·위치0 정책도 유지한다.
- 북마크 해제 중에는 행·잠금을 유지하고 실패 시 별을 원복해 수동 재시도한다. 성공 후 재조회로 행을 제거하고 마지막 항목도 조회 완료0을 확인한 뒤 빈 화면으로 바꾼다. 성공 뒤 조회 실패를 해제 실패로 원복하거나 UI에서 즉시 행을 필터하지 않는다. API/Repository/모델/저장·공통 하단 바/OS 안전 영역·다른 화면은 보존했다([보존 감사](/private/tmp/clipback-bookmark-alignment-20261017/preservation-audit.json)).

<a id="b-7530f67e0b03515d"></a>

### 이번 원본·재현·자동 검사

<a id="b-97c65a92a5af12aa"></a>

- [Figma 조회/원본](/private/tmp/clipback-bookmark-alignment-20261017/figma/reference-index.json): **2026-10-17 14:25:53~14:26:00 UTC /23:25:53~23:26:00 KST**에 두 노드의 컨텍스트와375×812 원본을 각각 한 번, MCP2호출로 확보했다. 별도 메타데이터/스크린샷 호출·fallback·대체 디자인은 없다. 계획 단계 조회와 이번 구현 조회를 구분한다.
- [에셋 감사](/private/tmp/clipback-bookmark-alignment-20261017/static-assets-verification.json): 반환 URL에서9개 원본(8SVG/1PNG)을 내려받았다. 기존8개 참조는6개 byte동일·설정2개 clipID만 다르며, 상자 PNG는 기존 `unclassified-empty.png`와 byte동일해 재사용했다. 새 책 SVG18×18만 원본 그대로 추가했다. 최종 로컬/양 번들·실제4상태의 요청 영역 경로·슬롯·크롭·필터를 확인했다. 공통 하단 탭 전체의 Figma 일치를 주장하지 않는다.
- [제품 수정 전 게이트](/private/tmp/clipback-bookmark-alignment-20261017/before-gate.json): 기준 제품에서 새 OS원본4장을 확보한 뒤에만 제품을 수정했다. [동결 소스](/private/tmp/clipback-bookmark-alignment-20261017/fixture-manifest.json)의 SHA `babfcd507f6f6ee200bcd0487712ecb32ba360d4d898e109acbc69bdbe9b9dce`를 전후 동일하게 유지했다. 즐겨찾기8건4+4페이지·일반 콘텐츠1건·전체 통계999를 사용하는 메모리 API 대역이며 빈 상태는 마지막 즐겨찾기1건을 실제 대역 PUT/재조회해 만들었다. 기존 저장 콘텐츠는 삭제하지 않았다.
- [변경 전 재현](/private/tmp/clipback-bookmark-alignment-20261017/tests/focused-before-summary.json): 41건 중15통과/예상 목표차이26/예상밖0이었다. AFTER 집중 **41/41**, 관련 **651/651**, 전체 **1207/1207** 통과·실패/건너뜀0이며 `flutter analyze --no-pub` 문제0이다([집중](/private/tmp/clipback-bookmark-alignment-20261017/tests/focused-after-summary.json)·[관련](/private/tmp/clipback-bookmark-alignment-20261017/tests/related-after-summary.json)·[전체](/private/tmp/clipback-bookmark-alignment-20261017/tests/all-after-summary.json)·[분석](/private/tmp/clipback-bookmark-alignment-20261017/tests/analyze-after-summary.json)).
- [동일 프리뷰의 별도 AFTER 실제 앱 검사](/private/tmp/clipback-bookmark-alignment-20261017/tests/after-fixture-probe-summary.json)2건도 스타일/레이아웃 true·JSON 직렬화·프레임워크 오류0이다. 기존 확대 검사를 유지했고 공통 상단 안전 영역 검사는 새 즐겨찾기 헤더 finder만 적응해 높이·OS inset 단언을 보존했다. 320/375px·양 테마1배율에서 자연 문단/부모260px 구별·짧은 본문 스크롤·탭 영역·긴/복수 소속을 확인했다. 중복 해제 방지와 쓰기 성공 후 재조회 실패·재시도, 이전 아카이브 정렬true 보존은 자동 App 회귀로 별도 검증했다.

<a id="b-de64566b89cb5247"></a>

### 양 플랫폼 실행과 비교

<a id="b-4530b1b4c364a0be"></a>

- **iPhone16/iOS18.6**: Flutter 논리창 `Size(393.0, 852.0)`·DPR3.0·OS viewPadding 상59.0/하34.0px·IME0.0px. 37기록의 style/layout/behavior/coverage/checksCompleted/전체 `passed:true`·프레임워크 오류0이다. 최대 스크롤 관측은 959.000px이며 해당 관측의 maxScrollExtent와 일치한다.
- **Android13/API33 제스처**: Flutter 논리창 `Size(392.7, 783.3)`·DPR2.75·OS viewPadding 상24.0/하0.0px·IME0.0px. 37기록의 style/layout/behavior/coverage/checksCompleted/전체 `passed:true`·프레임워크 오류0이다. 최대 스크롤 관측은 958.727px이며 해당 관측의 maxScrollExtent와 일치한다.

<a id="b-02340e092c823866"></a>

| 플랫폼 | 헤더→첫 카드 여백 전→후 | AFTER 카드 기본 높이 | 빈 그룹·상자·버튼 실측 |
| --- | --- | --- | --- |
| iOS | 37→52px | 173px | 260×162 / 40×46 / 155.009×35px |
| Android | 37→52px | 173px | 260×162 / 40×46 / 155.009×35px |

<a id="b-5fc16f93efd0c56e"></a>

- [실측·동작 요약](/private/tmp/clipback-bookmark-alignment-20261017/native-validation-summary.json)·[독립 동일 조건/API 대역 판정](/private/tmp/clipback-bookmark-alignment-20261017/pair-verification.json): 추가 조회·8행 완전 노출/최대 스크롤·합성 포인터 드래그·관리/검색/상세 왕복·더보기 취소·해제 대기/실패 복원/재시도 성공·마지막 해제/재조회0·전체 리스트 보기·네 하단 탭·저장 진입/추가 저장 없는 닫기를 실제 앱에서 확인했다. native 공유는 첫 실행부터 메모리 채널로 격리해 실제 공유 채널 위임/미지원0이며 기존 큐·자격 내용을 조회/출력/삭제하지 않았다.
- [3열 비교4쌍](/private/tmp/clipback-bookmark-alignment-20261017/comparison-document.html)·[비교 QA](/private/tmp/clipback-bookmark-alignment-20261017/comparison-qa.json): 정상·빈 상태×양 플랫폼의 전후 OS원본 각4장이다. 데이터/1배율/IME0/스크롤0을 맞췄으며 Figma누락/조건 불일치0이다. 원본은 자르거나 보정하지 않았다. 기존 PhoneFrame375px 상한·실제 OS 창/상태/하단 여백·예제 콘텐츠와 실제 복수 배지의 차이를 구분한다.

<a id="b-a264958770c05f75"></a>

| 상태 | iOS | Android 제스처 |
| --- | --- | --- |
| 정상 목록·스크롤0 | [3열 비교](/private/tmp/clipback-bookmark-alignment-20261017/comparisons/ios-bookmark_list_scale_1_scroll_0.png) | [3열 비교](/private/tmp/clipback-bookmark-alignment-20261017/comparisons/android-gesture-bookmark_list_scale_1_scroll_0.png) |
| 조회 완료된 즐겨찾기0 | [3열 비교](/private/tmp/clipback-bookmark-alignment-20261017/comparisons/ios-bookmark_empty_scale_1_scroll_0.png) | [3열 비교](/private/tmp/clipback-bookmark-alignment-20261017/comparisons/android-gesture-bookmark_empty_scale_1_scroll_0.png) |

<a id="b-10db196ed67ebc0a"></a>

- 개요: [iOS](/private/tmp/clipback-bookmark-alignment-20261017/comparisons/ios-comparison-overview.png)·[Android](/private/tmp/clipback-bookmark-alignment-20261017/comparisons/android-gesture-comparison-overview.png). 영상: [iOS AFTER](/private/tmp/clipback-bookmark-alignment-20261017/ios/after/interaction.mp4)·[Android AFTER](/private/tmp/clipback-bookmark-alignment-20261017/android-gesture/after/interaction.mp4). [미디어 확인](/private/tmp/clipback-bookmark-alignment-20261017/media-verification.json)에서 동작 완료까지 녹화·전체 디코딩 오류0을 확인했다.
- [환경 정리](/private/tmp/clipback-bookmark-alignment-20261017/cleanup-verification.json)·[최종 자원](/private/tmp/clipback-bookmark-alignment-20261017/final-resource-check.json): 소유 앱/기기/포워딩/adb 종료·임시 포트 비움·탐색/키보드 원설정 보존을 확인했다. [HTML 검사](/private/tmp/clipback-bookmark-alignment-20261017/comparison-html-verification.json)는 정적 참조/문법 검사이며 비교 브라우저/HTTP서버 실행 성공으로 보고하지 않는다.
- 검증은 실제 ClipbackApp/Repository와 HTTP MockClient·메모리 세션·합성 입력의 로컬 실행이다. 운영 서버/실제 OAuth/영속 저장/실기기/원격 CI·새 확대/3버튼 기기 검증은 아니다. 공통 하단 활성 즐겨찾기 아이콘은 기존 윤곽선을 유지해 Figma 채움별과 다르며 **공통 하단 바 후속 범위**로 남긴다. 정렬 화살표/메뉴·정확한 전체 집계·원본 없는 별도 상태·검색 화면·새 확대 맞춤도 후속이다.

<a id="b-3e8fe2202548220d"></a>

### 즐겨찾기 프리뷰 실행

<a id="b-f1842e44c5e28bc4"></a>

```bash
cd /Users/leehyeongyu/Desktop/project/Clipback/frontend
/Users/leehyeongyu/flutter/bin/flutter run --no-pub -t test/support/bookmark_preview.dart --dart-define=BOOKMARK_PHASE=after -d <device-id>
```

<a id="b-cef423c398e09052"></a>

loopback8767의 `/scene?kind=list&offset=0`·`/scene?kind=empty&offset=0`으로 고정 상태를 준비하고 `/run`으로 실제 앱 동작을 검사한다. Android 소유8768→8767 포워딩은 검증 후 제거한다. phase는 기록용이며 AFTER빌드의 이름만 바꿔 BEFORE로 사용하지 않는다. BEFORE는 제품 수정 전 기준 소스로 새 빌드/촬영해야 한다. 공유 채널 격리는 첫 앱 실행 전에 설치하며 네이티브 IME는 실제 채널을 유지한다.

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-fa0e85b1e3fed544"></a>

### Figma 즐겨찾기 화면의1배율 맞춤 — 2026-10-17 작업
