# 테스트에서만 쓰는 앱 코드를 test로 옮기고 안 쓰는 위젯 삭제 (#273)

2026-11-07, 시작 커밋 `b3f3b0b` 기준으로 구현하고 티켓 리뷰(Standards·Spec 지적 0건)와 전체 검증까지 마쳤다.
코드 커밋은 `32dc0ba`이고, 전체 검증의 기준 코드도 `32dc0ba`이다.
화면이 바뀌지 않는 정리만 했다. `TagChip`, `SearchHistoryRepository.settle`, `EntryTagline`, `CardPagerProgress`는 그대로 두었다.
#212(`SortSheet` 제거)는 같은 PR에서 따로 처리한다.

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
