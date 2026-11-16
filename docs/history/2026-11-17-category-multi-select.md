# 콘텐츠 카테고리 여러 개 고르기 (#408)

2026-11-17, 브랜치 `feat/category-multi-select`. 시작 커밋 `3007b0e`, 구현 커밋 `9b3317c`, 리뷰 반영 커밋 `4696839`. 그 뒤 main `00c30c2`(#406)를 합친 `327d582`와 업데이트 내역 빈 줄 맞춤 `37c2e95`가 있다.

## 문제

- 출처: 팀 피드백 시트 64, 팀 회의(2026-11-16) "카테고리 선택 화면에서 여러개 선택할 수 있게".
- 콘텐츠 관리의 "카테고리 변경"은 한 개만 고를 수 있었다. 하나를 누르면 그 카테고리로 바로 옮겨지고 바텀시트가 닫혀 다른 카테고리가 빠졌다.
- 서버와 DB는 이미 콘텐츠 하나에 카테고리 여러 개를 저장하고(`PUT /contents/{id}/categories`의 `category_ids` 목록) 돌려준다. 앱만 한 개로 보냈다. 서버는 바꾸지 않았다.

## 사용자 결정

이슈 #408 결정 기록을 따른다. 이 작업 중 추가로 받은 결정은 아래 "바뀐 기존 테스트"의 두 승인이다.

- ① 아카이브 앱 쪽 거르기: 구현 첫 단계에서 실측한 뒤 "속한 카테고리 중 하나라도 이름이 같으면"으로 바꾼다.
- ② 대표 카테고리: 앱이 콘텐츠의 카테고리를 앱 카테고리 목록 순서로 정렬하고, 배지 순서도 함께 바뀐다. 목록에 없는 카테고리는 뒤에 둔다.
- ③ 변경 중 표시: 지금처럼 글자 없이 바로 반영하고 콘텐츠 관리를 잠근다.
- 고를 카테고리가 0개인 상태는 동작만 정하고 디자인은 '디자인 확인 필요'로 올린다.

## 바꾼 것

- 새 화면 `frontend/lib/shared/category/category_change_screen.dart`(Figma `403:4438`, 2026-11-17 조회).
  - 헤더 "‹ 카테고리 변경", "N개 선택"·"전체 선택/전체 해제", 행(폴더 색·이름·저장 시각 규칙·원형 체크), 아래 고정 "선택 완료".
  - 미분류 행은 없다. 지우는 중 행은 누를 수 없고, 전체 선택/해제가 건너뛴다.
  - "선택 완료" 판정 순서(이슈 1–6단계): 중복 제출 무시 → 계정 세대가 다르면 닫기 → 콘텐츠가 없으면 닫기 → 처음 체크와 같으면 닫기 → 최신 목록 순서로 지우는 중·지워진 것을 뺀 목록 → 닫고 변경 시작.
  - 화면이 열린 동안의 최신 카테고리 목록·계정 세대·콘텐츠 존재 여부는 `CategoryChangeScope`(앱 `MaterialApp.builder`)로 받는다. 공급원은 `CategoryManagementViewModel`이다. 계정 세대는 저장소 `accountVersion`이다.
- 체크 자산 2개(`category-change-check-selected/unselected.svg`)를 Figma 원본 그대로 추가했다. 뒤로·폴더 아이콘은 기존 자산과 같아 재사용했다.
- 저장소 `beginContentCategoryChange(int, List<int>)`: 중복 합치기, 모르는 ID·지우는 중·지워진 ID·미분류와 다른 카테고리 혼합이면 시작 거절, `[]`는 바로 미분류로 보이고 `PUT []`.
- 앱 동작·뷰모델 5곳·화면 콜백을 카테고리 ID 목록으로 바꿨다.
- `contentFromApi`: 앱 카테고리 목록 순서로 정렬, 목록에 없는 것은 뒤에 서버 순서로 둔다.
- 아카이브 `ContentListView`의 서버 목록 없는 갈래: 속한 카테고리 중 하나라도 이름이 같으면 보인다.
  - 실측: 실제 앱 조립은 아카이브에 항상 서버 목록을 넘겨 이 갈래를 타지 않는다(`category_multi_select_app_test` 'archive'에서 단언).
- 콘텐츠 관리 메뉴 설명을 "이 콘텐츠를 넣을 카테고리를 골라요."로 바꿨다.
- 옛 `CategoryChangeSheet`·`CategoryChangeTile`은 쓰는 곳이 없어 지웠다.
- 문서: `docs/figma-ui-alignment-plan.md`(현재 기준 [64], 디자인 확인 필요 3건), `CHANGELOG.md` 미배포 추가. `frontend/README.md`는 `lib/shared/category/` 안내가 이미 있어 바꾸지 않았다.

## 새 테스트

- `frontend/test/data/content_repository_test.dart` #408 group: 입력 목록 표의 각 행, 여러 개 실패 되돌림, 계정 초기화 뒤 늦은 응답.
- `frontend/test/presentation/content_mapper_test.dart`: 앱 [A,B]·서버 [B,A], 부분 목록, 빈 목록.
- `frontend/test/app/content_category_change_test.dart`(34건): 시작 체크, 토글·N, 전체 선택/해제, 지우는 중 행과 삭제 상태 변화, 스크롤, 0개 상태, 판정 표 9행·지워진 카테고리·계정 변경·콘텐츠 삭제·연타, ‹·Android 뒤로·iOS 밀기, 스크린리더, 넘침(40자·"N개 선택/전체 해제"·메뉴 설명, 1.0/1.3배, 320폭), 아카이브 거르기.
- `frontend/test/category_multi_select_app_test.dart`(8건, 실제 앱 + 가짜 HTTP): 진입 4곳(아카이브·즐겨찾기·검색·상세), 두 폴더·홈 두 칩·해제 시 빠짐·홈 카드와 상세의 목록 순서, 실패 되돌림, 열린 사이 원본 {A}→{B} 갱신 두 사례.
- 응답 뒤 계정 변경은 기존 `content_mutation_test` 'old-account category success/failure'가 같은 경로를 고정한다(인자만 목록으로 연결).

## 바뀐 기존 테스트

이슈 허용표 범위:

| 파일 | 바꾼 것 |
| --- | --- |
| `test/sheet_safe_area_test.dart` | 타입 이름, 헤더 위치·화면 높이 단언을 새 화면 기준으로, 행 누른 뒤 "선택 완료", 콜백 인자 목록, 긴 목록 행 찾기를 스크롤로 |
| `test/phone_width_test.dart` | 타입 이름, 닫기를 ‹로 |
| `test/theme_font_overflow_test.dart` | 행 위젯 교체(`CategoryChangeRow`) |
| `test/uncategorized_name_test.dart` | 두 테스트를 "변경 화면에 미분류 행 없음"으로 바꾸고 이름도 바꿈 |
| `test/data/content_repository_test.dart` | 시작 함수 인자 `2` → `[2]` |
| `test/category_delete_test.dart`, `content_mutation_test.dart`, `feed_pagination_test.dart`, `bookmark_alignment_test.dart`, `support/category_archive_preview.dart` | 콜백 인자·타입만 목록으로(기대값 그대로) |
| `test/support/unclassified_preview.dart` | 타입 이름, 행 누른 뒤 "선택 완료", 닫힘 대기 |
| `test/support/category_content_preview.dart` | 원래 카테고리 해제 + "여행" 체크 + "선택 완료" |

사용자 승인으로 추가한 행(2026-11-17 "추천대로", 행 누르기가 토글이 되어 허용표만으로 기존 결과를 지킬 수 없음):

| 파일 | 바꾼 것 | 지킨 것 |
| --- | --- | --- |
| `test/support/detail_preview.dart` | `_cat` 해제 → "선택 완료"(결과 [_second]). host 콜백을 ID 목록으로 받아 `copyWith(categories: ...)` | require·record 문구, 장면 순서, 결과 카테고리 하나 |
| `test/support/search_preview.dart` | 101 해제 + 102 체크 → "선택 완료"(결과 [102]) | 같음 |

사용자 승인으로 추가한 행(결정 ②, 2026-11-17 "추천대로"):

| 파일 | 바꾼 것 | 지킨 것 |
| --- | --- | --- |
| `test/archive_all_alignment_test.dart` 'source mapper preserves all embedded categories and absent metadata fallback' | 순서 [103,104,105,106,101,102] → [101,102,103,104,106,105], 105 인덱스 2 → 5, 대표 103 → 101 | 105 이름·색, 미분류 대체, 테스트 이름 |
| `test/category_delete_test.dart` 'stale rename callback rolls back to the latest category name and preserves secondary membership' | 순서 [202,101] → [101,202], 최신 이름 참조 `last` → `first` | '최신 이름', 멤버십 두 개, 테스트 이름 |

## 리뷰

- 티켓 검수(`3007b0e..9b3317c`): Standards 0건, Spec 중간 1건.
- 지적: 이슈가 반드시 넣으라고 한 "열린 사이 원본 갱신 {A}→{B}" 두 사례 테스트가 없었다. 수용했다(`4696839`).
  - 변경 화면을 {A}로 연 뒤 서버 기록을 {B}로 바꾸고, 화면 아래 아카이브의 실제 서버 읽기로 저장소 콘텐츠가 [B]가 된 것을 먼저 단언한다.
  - S1={A}: 요청 0회·닫힘·{B} 유지. S1={A,C}: 요청 1회·본문 [A,C]·최종 [A,C].
  - 변형: 처음 체크와 같으면 닫는 판정을 끈 복사본에서 S1={A} 테스트가 실패했다. 원본으로 되돌리고 차이가 없는지 확인했다.
- 같은 상태(열린 화면 아래 대상 콘텐츠가 바뀜)를 만드는 진입점: 피드 읽기(필터 전환·재시도·더 불러오기), 다른 쓰기 뒤 새로고침, 공유 저장 뒤 새로고침, 상세 읽기, 카테고리 이름 변경·삭제 정규화, 계정 초기화(판정 2단계가 막음). 화면은 연 시점 콘텐츠로 처음 체크를 잡으므로 결과가 같다.

## 검사

- 부분 검사 원본 로그는 작업 폴더 `.utmp/ticket-408/partial-*`에 있다. 실패를 먼저 확인한 단계: 저장소(컴파일 실패), 정렬(2건), 아카이브 거르기(1건).
- 카테고리를 다루는 테스트 75개 파일: `+2922`(구현 커밋 전 작업 트리).
- 전체 검증(main을 합친 `37c2e95`): `VERIFY result=PASS scope=all checks=12 failed=0`.
  - 앱 단계 `dart format --output=none --set-exit-if-changed lib test`·`flutter analyze --no-pub`·`flutter test --no-pub`(`+3824`)는 `app-validation.yml`과 같은 명령이라 따로 돌리지 않았다.
  - `pytest: 2743 passed, 49 skipped, 3 warnings in 347.03s (0:05:47)`
  - `pytest skip: 48 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)`
  - `pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)`
- 이 문서 커밋은 문서만 바꾸므로 전체 검증을 반복하지 않았다(근거 커밋 `37c2e95`).

## 미검증·사람 확인 대기

- iOS Simulator·Android Emulator 실행, 촬영, 변경 전·후·Figma 비교: 이 문서 작성 시점에 미실행(감독 기기 차례). main에서 합친 #406 iOS 설정 변경도 그때 함께 확인한다.
- 고를 카테고리 0개 상태 촬영: 디자인 확인 필요라 미검증 예정. 동작은 자동 테스트로 확인했다.
- 운영 서버 0.6.2 테스트 빌드(두 카테고리 지정 → 아카이브 두 폴더·홈 두 칩 → 하나 해제): 사용자 확인 대기. 로컬 결과로 대신하지 않는다.
- 실기기 VoiceOver(iPhone 13): 사용자 확인 대기. 자동 semantics 테스트로 대신하지 않는다.
- 0.6.1 이하 앱은 카테고리를 바꾸면 하나만 보내 여러 개 지정이 한 개로 바뀐다(테스터는 0.6.2로 올린다). 배포된 0.6.1 바이너리는 확인하지 않았다.
