# 팀 피드백 시트 작은 화면 수정 묶음 (#355, #356, #357, #358)

2026-11-14, 브랜치 `fix/sheet-small-ui`. 팀 피드백 시트 72·75·84·78번.
시작 커밋 `84ff8b0`(main #350), 구현 커밋 #355 `cfd7d79`, #356 `b009331`, #357 `9097da5`, #358 `5062ac6`, 리뷰 반영 `8c5a9db`(전체 검증 기준), main(#359, 문서만) 병합 `731fe40`.
이 기록을 더한 커밋은 문서만 바꾼다.

## 사용자 결정 (2026-11-14)

- #355: Figma F01처럼 '랜덤 보기' 버튼을 목록 위에 띄우고, 목록 끝 빈 공간은 16 + 버튼 누름 높이(1배율 60).
- #356: '이번주 허투루 픽' 제목은 눌러도 아무 일 없음. 픽 카드 이동은 그대로.
- #357: 확정 전 빈 홈 안내의 고정 높이 211을 최소 높이로. Pretendard와 이 영역이 실제로 받는 글꼴 둘 다로 넘침 확인.
- #358: "아카이브 -> 카테고리 창에 보이는 검정 배경에 노란색 글씨 분류가 필요한 콘텐츠를 제외한 모든 곳을 미분류로 변경". 목록 제목은 "분류가 필요한 콘텐츠여도 될 것 같아", "빈 상태 문장은 그대로", 홈 칩은 "미분류로 바꾸자".

## 구현

- #355: 일반 카테고리 목록(F01)에서 목록을 하단 바 위까지 펴고 버튼을 `Stack` 위 오른쪽 16·아래 16에 둔다. 목록 끝 빈 공간은 `PagedContentList.bottomPadding`(마지막 카드와 '더 불러오는 중'·'다시 시도' 줄 뒤)이며, 크기 16 + `CategoryContentRandomButton.pressHeight`는 버튼과 같은 글자 스타일·글자 배율로 잰 누르는 높이다(1배율 44, 합 60). 추가 페이지는 남은 스크롤 300 이하에서 불러오므로 빈 공간만큼 앞당겨진다(기준 300은 그대로).
- #356: `SectionHeader.onTap`을 선택 값으로 바꾸고 없으면 `InkWell` 없이 그린다. 홈 픽 제목만 onTap을 넘기지 않는다. 앱에서 `SectionHeader`를 쓰는 곳은 홈 두 곳뿐이다.
- #357: `EmptyHomeContent` 확정 전 모양을 `ConstrainedBox(minHeight: 211)` + `Column(mainAxisSize: min)`으로 바꿨다. 이 영역 글자가 실제로 받는 글꼴은 테마 병합 때문에 Android `Roboto`, iOS `CupertinoSystemText`다(위젯 테스트로 확인, [이슈 댓글](https://github.com/clip-back/clipback/issues/357#issuecomment-6861334819)). 글꼴은 바꾸지 않았다.
- #358: 앱 안 미분류 카테고리 이름 `catUncategorized.name`을 서버와 같은 '미분류'로 바꾸고 `categoryFromApi`의 이름 변환을 없앴다. 카드 꼬리표·저장 결과·카테고리 변경 시트·홈 칩은 카테고리 이름을 그대로 보여 '미분류'가 된다. 미분류 판단(칩 결과 0 문장, 검정·노란 칸 진입, E06 전용 꼬리표)은 같은 값과 비교하므로 함께 바뀐다. 남긴 5곳(검정·노란 칸, E06 상단 제목, 빈 상태 문장 3곳)은 화면 문구를 직접 쓰므로 그대로다.

## 테스트

먼저 테스트를 바꿔 실패를 본 뒤 고쳤다(로그는 로컬 `.utmp/ticket-355/partial-*.log`, 저장소에 넣지 않음).

- #355 `category_content_alignment_test.dart`: 스크롤 0에서 목록 아래끝 = 하단 바 위끝이고 버튼이 목록 안에 겹침, 목록 끝 빈 공간 = 16 + 누르는 높이(1배율 44). 글자 배율 1.0·1.15·1.3 × 폭 320·375 × iOS·Android에서 최대 스크롤 때 마지막 카드 아래끝 ≤ 버튼 위끝(2026-10-19 조건). 추가 페이지 실패 뒤 '다시 시도'가 버튼 위에 있고 눌림.
- #356 `home_alignment_test.dart`: 제목에 `InkWell`·탭 동작·버튼 의미 없음, 높이 ≥ 44·18px SemiBold 그대로, 픽 카드는 `onWeeklySelected`(없으면 `onOpenCategories`). `weekly_root_test.dart`: 앱 루트에서 제목을 눌러도 홈에 머묾.
- #357 `home_alignment_test.dart`: 피드 없음·초기화 전·남은 항목 × 1.0·1.15·1.3 × (받는 글꼴, Pretendard)를 따로 그려 넘침 없음, 1.0배 높이 211과 그림·제목·설명 위끝이 변경 전 값(받는 글꼴 11.5·105.5·136.5, Pretendard 22·116·147), 패널 끝이 영역 아래 + 32. 변경 전 실측에서 1.15배는 넘치지 않았고 1.3배만 넘쳤다.
- #358 `uncategorized_name_test.dart`: 표 1–7(홈 카드, 상세·연관 카드, 랜덤 카드, 전체보기형 카드, 저장 결과, 카테고리 변경 줄, 홈 칩)이 '미분류'이고 분류된 카테고리는 그대로, 꼬리표 1.0·1.3배와 칩 1.0·1.15·1.3배 넘침 없음(Pretendard), 미분류 칩 결과 0이면 '분류가 필요한 콘텐츠가 없어요'. `git grep -n "분류가 필요한" -- frontend/lib`은 남긴 5곳뿐이다.

바꾼 기존 테스트(각 이슈의 허용 칸 안):

| 테스트 | 바꾼 것 | 근거 |
| --- | --- | --- |
| `home_alignment_test.dart` 'Weekly header hides chevron …' | 이름에 제목은 눌리지 않음 뜻 추가, `categoryTaps` 1 → 0 | #356 허용 칸 |
| `support/home_base_alignment_preview.dart` | 제목 누름 뒤 홈 유지 확인, 기록 이름 `weekly_title_stays_home` | #356 허용 칸 |
| `home_alignment_test.dart` #217 표(`<state> after <previous> hero at <textScale>`) | 3상태를 1.0만 → 1.0·1.15·1.3, 주석 정리 | #357 허용 칸 |
| `home_alignment_test.dart` `_unclassifiedCategory`, `unclassified_alignment_test.dart` `_uncategorized`, `support/category_sheet_preview.dart` `sheetUnclassified` | fixture 이름 '미분류'. 이 때문에 동적 테스트 이름 `filtered empty …-char "…"`이 '3-char "미분"'이 됨(기대 문장 그대로) | #358 허용 칸 |
| `unclassified_alignment_test.dart` E06 제목 찾기 | `_uncategorized.name` → 문구 '분류가 필요한 콘텐츠'(기대값 그대로) | #358 허용 칸(fixture 이름 연결) |
| `fixtures/category_content_fixture.dart` 호스트, `home_alignment_test.dart` `_render` | 새 테스트용 `onRetry` 콜백, `appTextTheme`(기본값은 기존 동작) 추가 | 연결 추가, 기존 단언 변경 없음 |

## 검토

검수(Codex, `.utmp/review-355.md`): Standards 낮음 1, Spec 중간 1. 둘 다 반영(`8c5a9db`).

- Spec 중간: E06 기기 측정(`test/support/unclassified_preview.dart` `unclassifiedMeasure`)이 미분류 이름으로 상단 제목을 찾아, 이름이 '미분류'로 바뀐 뒤 null 오류가 났다. 남긴 제목 문구로 찾게 하고, 이 측정 함수를 `unclassified_alignment_test.dart`에서 부른다. 같은 원인의 다른 진입점(`test/` 아래 `catUncategorized.name`으로 화면 글자를 찾는 곳)은 이것 하나였다.
- Standards 낮음: 카테고리 변경 줄(#358 표 6)은 글꼴을 정하지 않아 테마 병합 글꼴(Android `Roboto`, iOS `CupertinoSystemText`)을 받는다. 그 글꼴과 1.3배에서 '미분류'가 줄 안에 드는지 `uncategorized_name_test.dart`에 더했다.

## 검증

- `VERIFY result=PASS scope=all checks=11 failed=0`(`8c5a9db`). 앱 테스트 3591개 통과, 백엔드 pytest 2640 통과·49 skip(배포 복구 48, S3 대역 1, 이번 변경과 무관).

## 화면 확인

iOS Simulator iPhone 16(iOS 18.6, 393×852, 안전 영역 위 59·아래 34)과 Android Emulator `Medium_Phone`(API 36, 411×914, 위 24·아래 24)에서 로컬 메모리 대역 서버로 찍었다. 변경 전은 시작 커밋 `84ff8b0`의 화면 파일, 변경 후는 `5e4c794`. 데이터는 `normal`(일상 12개, 여행 6개 뒤 다음 쪽 503, 공용 '미분류' 소속 2개, 주간 픽 2개)과 `empty`(콘텐츠 0개). Figma 기준은 2026-11-14 조회(F01 `111:3968`, C01 `111:3584`, F02 `111:3842`, E02 `111:4133`, E06 `111:4525`, 빈 E06 `142:5097`, C02 `111:3681`). 비교 이미지·영상은 로컬 `.utmp/ticket-355-screens/`(저장소에 넣지 않음).

| 상태 | 결과(두 플랫폼) |
| --- | --- |
| `home-weekly-title-tap` | 변경 전 아카이브 카테고리 탭으로 이동, 변경 후 홈에 그대로. 화면이 달라 비교 이미지 대신 전·후 원본과 영상 |
| `home-weekly-card-tap`, `f01-top` | 전·후 모두 일상 목록으로 이동. 변경 후 카드가 하단 바 위까지 보이고 '랜덤 보기'가 목록 위에 뜸 |
| `f01-scroll-mid` | 카드가 버튼 뒤로 지나감. 스와이프 위치 차이(0.02pt)로 비교 이미지는 만들지 않고 원본과 영상 |
| `f01-scroll-end`, `f01-scroll-end-1.3` | 마지막 카드 아래끝 ≤ 버튼 위끝: iOS 686 ≤ 694, 1.3배 680 ≤ 688 / Android 758.3 ≤ 766.3, 1.3배 752.3 ≤ 760.3. 목록 끝 빈 공간이 76 → 60으로 줄어 최대 스크롤이 16 다르다(설계상 차이라 비교 이미지 대신 원본) |
| `f01-retry-end` | '다시 시도' 아래끝 ≤ 버튼 위끝: iOS 664.5 ≤ 694 / Android 736.8 ≤ 766.3. 원본만(같은 이유) |
| `home-chip-uncategorized`, `detail-uncategorized`(연관 카드 포함), `archive-all-uncategorized`, `category-change-sheet` | 변경 전 '분류가 필요한 콘텐츠', 변경 후 '미분류'. 꼬리표 색 그대로 |
| `archive-category-banner`, `e06-list` | 검정·노란 칸과 E06 제목은 '분류가 필요한 콘텐츠' 그대로, E06 카드 꼬리표 '미분류' 그대로 |
| `home-chip-uncategorized-empty`, `e06-empty`(empty 데이터) | 칩만 '미분류'로 바뀌고 빈 상태 문장 그대로 |
| `home-empty-confirmed-1.3`(empty 데이터) | 전·후 같음(C02 그대로) |

미검증:

- `home-empty-unsettled-1.0`·`-1.3`(#357): 확정 전 빈 홈을 앱 흐름에서 만드는 경로를 찾지 못했다(처음 불러올 때는 홈 로딩 화면이 먼저 나옴). 위젯 테스트로 대신한다.
- `random-card-uncategorized`(#358): 랜덤 보기는 일반 카테고리에서만 열려 미분류 꼬리표가 나오는 앱 흐름이 없다. 위젯 테스트로 대신한다.
- `save-result-uncategorized`(#358): 링크 입력과 저장 요청을 메모리 대역 서버·촬영 도구로 재현하지 못했다. 위젯 테스트(`SavedContentConfirmation`)로 대신한다.
- 실제 VoiceOver·TalkBack 음성(#356 버튼으로 읽지 않음)은 의미 트리 위젯 테스트로만 확인했다.
