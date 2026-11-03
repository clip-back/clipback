# 목록 전체 개수 표시 (#225)

2026-11-03, 시작 커밋 `ac434142df9563edd11019ebc050052f1e4a08de` 기준 구현 후 티켓 검수와 전체 검증까지 마쳤다.
서버 정렬 전환은 #226이며 이 기록은 배포·화면 확인 완료를 뜻하지 않는다.

이후 감독의 최종 리뷰·전체 검사·양 플랫폼 촬영은 [최종 검증](2026-11-03-feed-count-final.md)에 기록했다.
아래는 #225 당시 실행 이력이며 사용자 시각 판정은 대기 중이다.

## 구현

- 피드 조회와 COUNT가 사용자·카테고리·즐겨찾기·검색 필터를 공유한다. COUNT에는 커서·limit을 적용하지 않는다.
  기존 커서·정렬·items를 유지하고 응답에 0 이상의 `total_count`를 추가했다. DB 변경은 없다.
- API에서 정수만 읽고 피드 상태·스냅샷·화면으로 전달한다. 옛 서버의 소진된 응답은 받은 항목 수를
  함께 보관한다. 따라서 기존 항목을 유지하는 새로고침에서 초기화되는 페이지 플래그와 무관하게 이전 개수를 유지한다.
- 유지 새로고침은 마지막으로 교체에 쓴 응답의 개수를 반영하고 중간 실패는 버린다. 일반 쓰기 후
  새로고침은 기존 초기화·재시도 동작을 유지하면서 이전 개수를 보관한다. 필터·계정 초기화는 개수도 비운다.
- 상세·툴바 표시에서 모름은 `-`, 유효한 값은 받은 수로 하한 보정한다. 화면 판정이 먼저이며 홈의
  `confirmedEmpty`는 변경하지 않았다. 즐겨찾기 우선의 두 단계 요청은 #226 전까지 모름이다.

## 실제 부분 검사

명령은 저장소 루트에서 busy 대기 후 해당 디렉터리로 이동해 실행했다. 모든 로그는
`.utmp/ticket-225/partial-*.log`이며 첫 줄에 명령, 마지막 줄에 종료 코드를 보관했다.

- `backend`: 임시 PostgreSQL DB `clipback_ticket225` 생성·`alembic upgrade head` 후
  `.venv/bin/pytest -q tests/api/test_feed.py tests/services/test_feed_service.py tests/integration/test_feed_pagination.py`
  → **64 passed in 5.42s**, skip 없음. 필터 조합·다른 계정·복수 카테고리·커서·추가/삭제 후 재집계를 확인했다.
  변경한 서버 파일과 테스트 6개에 `ruff check` → **All checks passed!**.
  `partial-final-server.log`, exit 0. 임시 DB는 종료 시 삭제했다.
- `frontend`: `flutter test --no-pub`에 `test/feed_count_test.dart`, `test/feed_pagination_test.dart`,
  `test/data/content_repository_test.dart`, `test/today_root_test.dart`, `test/archive_all_alignment_test.dart`,
  `test/bookmark_alignment_test.dart`, `test/detail_alignment_test.dart`, `test/category_archive_alignment_test.dart`,
  `test/favorite_wording_test.dart` 지정 → **240 tests passed**, `partial-final-partial-app.log`, exit 0.
- 마지막 응답 개수 단언·도구막대 인자 이름·실제 글자 잘림 단언을 보강한 뒤 관련 5개 파일
  (`feed_count`, `feed_pagination`, `data/content_repository`, `archive_all_alignment`, `bookmark_alignment`)만
  다시 검사 → **198 tests passed**, `partial-final-followup.log`, exit 0. 앞선 240개와 중복이 있어 합산하지 않는다.
- 실제 Pretendard, 폭 375, 1.0·1.15·1.3배에서 네 자리/모름 문구를 36개 독립 위젯 테스트로 확인했다.
  상세·즐겨찾기와 전체보기·카테고리의 최신순/즐겨찾기 우선 모두 넘침·잘림·정렬 글자 겹침이 없었다.
  상세의 기존 말줄임 설정은 유지했다.
- `flutter analyze --no-pub` → **No issues found!**, `partial-analysis.log`, exit 0.
- `dart format --output=none --set-exit-if-changed lib test` → **Formatted 279 files (0 changed)**,
  `partial-final-followup.log`, exit 0. `git diff --check` 통과.

## 실패와 수정

- 서버 응답의 필드 누락(2 failed), 앱 모델의 필드 미구현(컴파일 실패)을 먼저 확인했다.
  `partial-server-red.log`, `partial-app-red.log`는 기대한 실패 기록이다.
- 유지 새로고침 경로 통합 시 기존 즐겨찾기 재시도가 동작하지 않아 통합을 제거하고 기존 경로를 유지했다.
- 추가 단언을 잘못된 테스트 위치에 삽입한 1건과 ruff 긴 줄 1건을 수정했다.
- 첫 포맷 실행은 저장소 상대 경로와 frontend 작업 경로가 달라 파일을 찾지 못했다.
  `git diff --relative`로 수정하고 최종 포맷 검사에서 변경 0개를 확인했다.

## 티켓 리뷰와 전체 검증

2026-11-03 티켓 리뷰 `.utmp/review-225.md`의 Standards·Spec 모두 높음·중간·낮음 0건이다.
반영할 확정 지적이 없어 코드·테스트를 추가 변경하지 않았다. 리뷰어가 직접 실행한 추가 경계 검사
4개 통과는 `.utmp/review-225-checks/boundaries.log`에 있으며, 작업자의 전체 검사 수에 합산하지 않는다.

검증 기준 코드 커밋은 `c42434702419aeb8f3d8d805508662504333839a`다.
22:05 KST busy 대기 완료 뒤 작업 트리 루트에서 다음 명령을 셸 제한 600초로 한 번 실행했고,
22:10 KST 종료 코드 0을 확인했다. 저장소 사본·저장소 내부 basetemp는 사용하지 않았다.

```sh
~/.heoturu-agents/busy.sh && python3 ~/.heoturu-agents/verify.py --log-dir .utmp/ticket-225
```

- 서버 ruff·compileall, 일반/maintenance 테스트 DB 각각의 `alembic upgrade head`·`alembic check`,
  전체 pytest 통과. `backend-pytest.log`의 실제 마지막 요약:
  `2026 passed, 46 skipped, 3 warnings in 170.54s (0:02:50)`.
- 앱 pub-get·analyze·전체 test 통과. `app-test.log`의 마지막 결과:
  `02:03 +2176: All tests passed!`.
- 결과·skip 집계 원문은 `.utmp/ticket-225/verify-result.txt`, 단계별 원본은 같은 폴더의
  `backend-*.log`, `app-*.log`다. 재집계를 위해 검사를 다시 실행하지 않았다.

```text
pytest skip: 45 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=10 failed=0 logs=/Users/leehyeongyu/orca/workspaces/Clipback/feed-total-count/.utmp/ticket-225
```

Skip의 전체 사유는 `backend-pytest.log`의 `SKIPPED` 줄에 있다. deployment 45건은
Docker 실행 옵션·라벨된 로컬 API/operator 이미지 등 전제 조건이 없고,
integration 1건은 `CLIPBACK_IMAGE_TEST_S3_ENDPOINT`가 필요한 로컬 합성 CLI 검사다.
이 skip은 성공한 검사 수에 포함하지 않는다. Docker·시뮬레이터·에뮬레이터·실기기는 실행하지 않았다.

이 결과를 기록하는 후속 커밋은 문서만 변경하며 검증 기준 코드와 같다. 문서 diff·공백·경로를
확인하고 전체 검증을 다시 실행하지 않는다. 최종 리뷰 후 검증은 `.utmp/ticket-225/final`에 분리한다.

## 미검증

서버 CI의 operator-recovery 작업은 로컬에서 미검증이다. 운영·실기기·배포된 옛 앱 호환은 미검증이다.

**화면 확인 미완료**. 작업 지시에 따라 시뮬레이터·에뮬레이터·실기기를 켜지 않았다.
감독이 최종 리뷰 후 #225 촬영 상태 목록의 변경 전·후·Figma 비교와 이동·스크롤·문구를 확인한다.
변경 전 준비·촬영 기록은 `.utmp/start-224.md`, 촬영 자료는 `.utmp/ticket-224/`에 보존했다.
