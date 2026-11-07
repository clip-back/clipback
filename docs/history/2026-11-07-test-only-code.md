# 테스트에서만 쓰는 앱 코드를 test로 옮기고 안 쓰는 위젯 삭제 (#273)

2026-11-07, 시작 커밋 `b3f3b0b` 기준으로 구현하고 티켓 리뷰(Standards·Spec 지적 0건)와 전체 검증까지 마쳤다.
코드 커밋은 `32dc0ba`이고, 전체 검증의 기준 코드도 `32dc0ba`이다.
화면이 바뀌지 않는 정리만 했다. `TagChip`, `SearchHistoryRepository.settle`, `EntryTagline`, `CardPagerProgress`는 그대로 두었다.
#212(`SortSheet` 제거)는 같은 PR에서 이어서 처리했다. 아래 [#212 정렬 선택 시트 삭제](#212-정렬-선택-시트-삭제) 절에 따로 적는다.

## 구현

- 옮긴 것: `PlaceholderScreen` → `frontend/test/support/placeholder_screen.dart`, `AppTopBar` → `frontend/test/support/top_bars.dart`,
  `sample_contents.dart`·`sample_categories.dart`(`initialContents`, `initialCategories`, `catToWatch` 등) → `frontend/test/fixtures/`.
  테스트·프리뷰는 import 경로만 상대 경로로 바꿨다. 빈 `frontend/lib/shared/data/`와 `frontend/README.md` 구조 표의 그 행을 지웠다.
- 지운 것: `CategoryTopBar`, `EntrySurface`·`EntryStatusBar`·`EntryHomeIndicator`, `DesignStatusBar`, `CategoryCardPager`(+State)·`CategoryFeaturedCard`,
  이 삭제로 `flutter analyze`가 알린 안 쓰는 import.
- 함께 지운 테스트: `phone_width_test.dart`의 `EntrySurface` 경우, 가짜 OS 표시줄 부재 검사
  (`splash_alignment_test.dart`, `login_alignment_test.dart`, `splash_alignment_fixture.dart`·`login_alignment_preview.dart`의 측정·판정 조건,
  `account_conflict_fixture.dart`·`login_failure_fixture.dart` 목록의 지운 이름), `pending_label_layout_test.dart`의 "category featured card" 반복.
  판정 라벨은 남은 조건에 맞게 `'no text shrink'`, `'no font shrinking'`으로 줄였다.
- 이미 못 찾던 타입 경로를 키로 바꿨다: `category_archive_preview.dart`의 뒤로가기(`category-content-back-hit`),
  `safe_area_device_check.dart`의 03·04·11 머리(`archive-category-header`, `bookmark-header`, `category-content-header`, 도우미 `_keyed` 추가).
  `category_content_fixture.dart`·`unclassified_preview.dart`의 `CategoryTopBar` 대체 경로는 빼고 키만 쓴다.

## 검증

- 생성·호출 0회: 작업 전(`b3f3b0b`) `git grep -n -w`로 대상 이름을 찾으면 `frontend/lib`에서 선언 줄과 대상끼리의 참조만 나왔다.
  작업 뒤 옮긴 이름은 `frontend/lib`에서 0회, 지운 이름은 `docs/history/` 밖 0회, 유지할 4개는 그대로다.
- 부분 검사(구현 중): `flutter analyze --no-pub` 0건, 바꾼 테스트와 그것을 import하는 테스트 25개 파일 `flutter test --no-pub` 704개 통과.
- 리뷰: 티켓 리뷰에서 Standards·Spec 모두 지적 0건.
- 전체 검증(`32dc0ba`): `VERIFY result=PASS scope=all checks=11 failed=0`. 앱 테스트(`flutter test --no-pub`) 3226개 통과, pytest 2235 passed, 47 skipped.
  - `pytest skip: 46 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)`
  - `pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)`
- 미검증: 기기에서 돌리는 촬영 도구(`safe_area_device_check.dart`, `*_preview.dart`)의 실행(컴파일만 확인), iOS Simulator·Android Emulator 실행(화면 변경 없음), 원격 CI.

## #212 정렬 선택 시트 삭제

2026-11-07, 시작 커밋 `af2b90a` 기준으로 구현하고 티켓 리뷰(Standards·Spec 지적 0건)와 전체 검증까지 마쳤다.
코드 커밋은 `de987d4`이고, 전체 검증의 기준 코드도 `de987d4`이다. 앱에서 열리지 않는 위젯만 지워 화면은 바뀌지 않는다.

### 구현

- `frontend/lib/features/archive/archive_widgets.dart`에서 `SortSheet`와 이로써 안 쓰게 된 `sheet_primitives.dart` import를 지웠다.
  `AppSheet`·`SheetActionTile`·`SheetInfoRow`는 다른 화면에서 쓰여 그대로 두었다. 정렬 전환(`ArchiveSortButton` 팝업 메뉴)은 건드리지 않았다.
- `frontend/test/favorite_wording_test.dart`에서 `SortSheet`만 다루던 테스트 `정렬 선택 시트 항목은 즐겨찾기 우선이다`를 지웠다.
- 촬영 도구 `frontend/test/support/bookmark_preview.dart`의 정렬 메뉴 없음 확인에서 `_find<SortSheet>(_root) == null` 조건과 안 쓰게 된 import를 지웠다.
  다른 조건(화면 유지, 요청 수 그대로)은 남겼고 대체 조건은 넣지 않았다.

### 검증

- 생성 0회: 작업 전(`af2b90a`) `git grep -n "SortSheet(" -- frontend/lib`는 선언 `const SortSheet({` 1줄뿐이었다.
  `SortSheet` 사용처는 위 테스트 2곳과 `docs/history/` 2곳이었다. 작업 뒤 `git grep -n "SortSheet" -- frontend`는 0회이고, `docs/history/`의 과거 기록은 그대로 두었다.
- 부분 검사(구현 중): `flutter analyze --no-pub` 0건, `archive_widgets.dart`를 import하는 테스트 8개 파일 `flutter test --no-pub` 271개 통과(정렬 전환 테스트 기대값 그대로).
- 리뷰: 티켓 리뷰에서 Standards·Spec 모두 지적 0건.
- 전체 검증(`de987d4`): `VERIFY result=PASS scope=all checks=11 failed=0`. 앱 테스트(`flutter test --no-pub`) 3225개 통과, pytest 2235 passed, 47 skipped.
  - `pytest skip: 46 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)`
  - `pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)`
- 미검증: 촬영 도구 `bookmark_preview.dart`의 기기 실행(컴파일만 확인), iOS Simulator·Android Emulator 실행(화면 변경 없음), 원격 CI.

## 최종 리뷰와 전체 검사(최종, #273·#212 묶음)

위 두 절의 결과는 티켓별 결과이고, 이 절은 두 티켓을 묶은 최종 결과다.

- 기준: `main`과의 merge-base `b3f3b0b`에서 `1cc1158`까지(코드 커밋 `32dc0ba`, `de987d4`, 기록 커밋 `af2b90a`, `1cc1158`). 확인 시점에 `main`은 앞으로 나가지 않았다.
- 최종 리뷰: `b3f3b0b...1cc1158` diff를 #273·#212 본문과 사용자 결정 기준으로 검토해 Standards·Spec 모두 지적 0건.
- 전체 검사(최종, `1cc1158`): `VERIFY result=PASS scope=all checks=11 failed=0`. 앱 테스트(`flutter test --no-pub`) 3225개 통과, pytest 2235 passed, 47 skipped.
  - `pytest skip: 46 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)`
  - `pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)`
- 미검증: 기기에서 돌리는 촬영 도구(`safe_area_device_check.dart`, `*_preview.dart`, `bookmark_preview.dart`)의 실행(컴파일만 확인), iOS Simulator·Android Emulator 실행(화면 변경 없음), 원격 CI.
