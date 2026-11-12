# 마이 '다시 본 콘텐츠'를 최근 7일 다시 본 콘텐츠 수로 (#338)

2026-11-12, 브랜치 `feat/recent-reopened-count`. 팀 앱 테스트 피드백 시트 13(앱 0.3.0) "다시 본 콘텐츠가 그냥 글 볼때마다 늘어남"에서 왔다.
용어집·ADR 커밋 `2423f46`(시작 커밋), 구현 커밋 `17e59f6`, main 병합 `599b881`(#336·#337), 리뷰 반영·이 기록 커밋은 문서만 바꾼다.
전체 검증은 `599b881` 코드에 리뷰 반영 문서 변경을 더한 작업 트리에서 실행했다.

## 문제

- 마이 오른쪽 칸 '다시 본 콘텐츠'는 서버의 누적 열람 이벤트 수(`reopened_count`)라 같은 글을 열 때마다 1씩 늘었다.

## 사용자 결정

- 2026-11-11 팀 회의 "최근 일주일 동안 다시 본 콘텐츠 개수(문구에 최근 추가)", 2026-11-12 회의 Q1–Q13 "모두 추천대로". 정의는 [용어집](../../GLOSSARY.md)의 '최근 다시 본 콘텐츠 수', 누적 필드를 남기는 이유는 [ADR 0012](../adr/0012-my-stats-recent-reopened-count.md).
- 2026-11-12 "둘 다 최소로 허용 (Recommended)": 앱 모델 이름 변경과 서버 시각 인자 연결만 기존 테스트에 허용.
- 2026-11-12 "병합 뒤 따로 추적 (Recommended)": 서버 운영 반영 확인과 사람 확인 1·2는 병합 뒤 조율이 추적한다.
- 2026-11-12 "구현 먼저, 그 1장은 나중에 한 번 더 (Recommended)": Android 변경 전 첫 조회 실패 화면 1장은 감독 최종 촬영 블록에서 한 번 더 시도하고, 또 실패하면 미촬영과 사유를 적는다.

## 구현 (`17e59f6`)

- 서버: `GET /api/v1/users/me/stats`에 필수 정수 `recent_reopened_count`. `content_reopened` 이벤트 중 `created_at >= 요청 시각(UTC) - 7일`(경계 포함)인 것의 `count(distinct content_id)`. 삭제한 콘텐츠는 FK `SET NULL`이라 빠진다. 기존 두 값과 같은 쿼리 한 번이며 DB 변경은 없다. 서비스의 `utc_now()`가 시각을 정해 저장소에 `now`로 넘긴다. `reopened_count`는 옛 앱(0.5.2 이하)용으로 그대로 둔다.
- 앱: `ApiUserStats`가 `recent_reopened_count`를 필수로 읽고 `reopened_count`는 읽지 않는다. 새 필드가 없거나 정수가 아니면 기존 조회 실패 표시다. 칸 이름 "최근 다시 본 콘텐츠".
- 문서: API 계약, 지표 쿼리, 마이 통계 정책, 앱 동작, Figma 현재 기준(칸 이름은 J01과 다른 승인된 차이), CHANGELOG `미배포`.

## 테스트

먼저 테스트를 바꿔 실패를 본 뒤 고쳤다(로그는 로컬 `.utmp/ticket-338/partial-*.log`, 저장소에 넣지 않음).

| 확인 | 테스트 | 구현 전 |
| --- | --- | --- |
| 반복 열람 1, 서로 다른 글 2, 누적은 열람마다 증가 | `test_recent_reopened_stats.py::test_repeated_views_count_once_and_distinct_contents_add_up` | 실패 |
| 저장만·상세 GET만 0 | `test_saved_but_unopened_contents_are_zero` | 실패 |
| 같은 `client_event_id` 재시도 1 | `test_retried_view_request_counts_once` | 실패 |
| 이벤트 시각 + 7×24시간 포함, + 1µs 제외 | `test_window_includes_exactly_seven_days_and_excludes_one_microsecond_later` | 실패 |
| 삭제하면 빠짐(누적 유지) | `test_deleting_viewed_content_removes_it_from_recent_count` | 실패 |
| 게스트·소셜 같은 규칙, 계정 분리 | `test_guest_and_social_accounts_follow_same_rule_without_mixing` | 실패 |
| 새 필드 표시(누적 231이 아니라 12) | `session_restore_test.dart` "마이 통계 오른쪽 칸은 누적 열람 수가 아니라 …" | 실패 |
| 옛 서버 응답 → 최초 조회 실패 | "옛 서버 통계 응답은 누적 열람 수 대신 …" | 실패 |
| 마이에 머문 채 앱 복귀는 새 조회 없음 | "마이에 머문 채 앱 복귀는 …" | 실패(누적 값 표시) |
| 다른 화면에서 재진입 시 한 번 조회, 3 → 2 | "다른 화면에서 마이로 다시 들어오면 …" | 실패 |
| 칸 이름 360px Pretendard 1.0배 한 줄 / 1.3배 두 줄, 잘림·넘침 없음, 두 숫자 정렬 | `my_stats_label_layout_test.dart` | 실패 |

- 판정 조건 변형(`>=`→`>`, distinct 제거, `id` distinct)은 새 서버 테스트가 각각 1·2·3개 실패로 잡았다.
- 바꾼 기존 테스트는 이슈의 허용 칸 안이다: 서버 stats dict에 새 필드 추가, OpenAPI required, 저장소 호출의 `now` 연결과 고정 시각, 앱 가짜 응답 JSON에 같은 값의 새 필드 추가, `reopenedCount` → `recentReopenedCount`, `support/my_preview.dart`의 칸 이름과 누적 의미 단언. 기존 `saved_count`·`reopened_count` 기대값과 쿼리 1회 단언은 그대로다.
- 저장 직후 자동 상세의 `/view` 요청은 변경 전(`2423f46`)과 후 모두 0건(감독 보조 테스트, 저장소 밖).

## 검토

검수(Codex, `.utmp/review-338.md`): Standards 0개, Spec 낮음 2개, 둘 다 반영.

- S1: CHANGELOG 앱 항목을 `[앱]`으로 바꿨던 것을 스펙대로 한 줄에 `[iOS] [Android]`로 표기.
- S2: API 계약의 "0 for both fields"를 "all three fields"로.
- main 병합(`599b881`) 뒤 `flutter analyze --no-pub`와 문의하기·로그인 실패·마이 Figma·칸 이름 배치·세션 복원 테스트 101개 통과.

## 검증

- `VERIFY result=PASS scope=all checks=11 failed=0`(코드 `599b881`).
  - CI App Validation 명령: `flutter pub get --enforce-lockfile`, `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze --no-pub`, `flutter test --no-pub`(+3504 All tests passed).
  - 백엔드: `ruff check app scripts alembic tests`, `python -m compileall`, 로컬 전용 테스트 DB와 maintenance DB에서 `alembic upgrade head`·`alembic check`, `pytest -q -rs` 2509 passed, 47 skipped.
    - `pytest skip: 46 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)`
    - `pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)`
  - `pytest -q tests/repositories tests/integration`은 위 DB 포함 전체 pytest에 들어 있어 따로 돌리지 않았다. verify에 없는 `deptry .`는 따로 실행해 문제 없음.
  - Docker가 필요한 deployment·operator-recovery 시험은 로컬 미검증이며 PR CI에서 확인한다.
- `git diff --check` 통과.

## 화면 확인

- 변경 전(`2423f46`): iOS Simulator 3개 상태(정상 1.0배·1.3배, 첫 조회 실패)와 Android Emulator 정상 2개 상태 촬영, Figma J01 `111:4707` 기준 화면 확보(감독, 저장소 밖 `.utmp/ticket-338/screens/`).
- 미완료: Android 변경 전 첫 조회 실패 1장(위 사용자 결정대로 감독 최종 블록에서 재시도), 양 플랫폼 변경 후 촬영, 로컬 서버로 같은 글 두 번 열기 +1·삭제 −1 실행 확인. 이 기록 시점에는 실행하지 않았다.
- 실기기 사람 확인 1·2와 서버 운영 반영 확인은 병합 뒤 따로 추적한다.
