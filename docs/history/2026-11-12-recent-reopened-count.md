# 마이 '다시 본 콘텐츠'를 최근 7일 다시 본 콘텐츠 수로 (#338)

2026-11-12, 브랜치 `feat/recent-reopened-count`. 팀 앱 테스트 피드백 시트 13(앱 0.3.0) "다시 본 콘텐츠가 그냥 글 볼때마다 늘어남"에서 왔다.
용어집·ADR 커밋 `2423f46`(시작 커밋), 구현 커밋 `17e59f6`, main 병합 `599b881`(#336·#337), 리뷰 반영 `8a7b7ff`와 최종 실행 기록 커밋은 문서만 바꾼다.
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

기준 `2423f46`, 변경 후 `8a7b7ff`(제품 코드 `599b881`). Figma J01 `111:4707`을 2026-11-12 05:30:25 UTC에 조회했다(375×842). 로컬 증거는 `.utmp/ticket-338/`에 보존하며 저장소에는 포함하지 않는다.

| 플랫폼 | 기종·OS | 조건 | 판정 |
| --- | --- | --- | --- |
| iOS Simulator | iPhone 16, iOS 18.6 | 393×852pt, 안전 영역 위 59/아래 34 | 변경 전·후 정상 1.0배·1.3배·첫 조회 실패 각 3장, 비교 조건·원본 확인 통과 |
| Android Emulator | Medium_Phone, Android 16/API 36 | 1080×2400px, 411.43×914.29dp, 안전 영역 위/아래 24 | 같은 3개 상태 변경 전·후 촬영, 비교 조건·원본 확인 통과 |

- 같은 기종·데이터·배율·스크롤 0으로 비교했다. 정상 데이터는 저장 150, 누적 열람 231, 최근 다시 본 12이며 변경 전 231에서 변경 후 12로 바뀐다. 두 플랫폼의 1.3배에서 새 칸 이름 잘림·넘침 없이 숫자가 정렬됐다.
- 첫 실패는 변경 전 필드 누락, 변경 후 옛 서버의 두 필드만 있는 응답으로 만들었다. 두 대시·조회 실패 안내·다시 시도 버튼을 확인했다. Figma에 해당 실패 상태는 없으므로 가짜 기준 이미지를 만들지 않았다.
- 비교 원본 `compare-ios.png`, `compare-android.png`와 축소 미리보기 `compare-*-preview.png`. Figma와 실제 OS 크기·안전 영역 차이는 원본 보정 없이 설명했다. 칸 이름은 승인된 디자인 차이이며 기존 계정·메뉴 차이는 이번 범위가 아니다. 사용자 최종 화면 판정은 PR 초안 승인 때 받는다.
- Android 변경 전 첫 조회 실패 화면은 승인된 한 번의 재시도에서 89.94초에 확보했다(설치 +1초, 해시 +21초, 최초 실행 +24초, 재실행 +55초, 마이 +78초, 촬영 +86초). 변경 전 미촬영 행은 없다.
- Android 변경 후 첫 실패 촬영도 설치·준비 지연이 있어 허용된 환경 재시도 한 번을 사용했고, 저장 상태 없이 새 부팅 후 392.21초에 완료했다. 각각 `android-before-retry-result.json`, `android-after-retry-result.json`에 원 실행 exit 0을 남겼다.

## 실제 로컬 서버 실행

합성 게스트·콘텐츠를 전용 로컬 PostgreSQL에 준비하고 실제 FastAPI와 앱 HTTP 경로를 사용했다. iOS는 호스트 루프백, Android는 에뮬레이터의 호스트 주소로 연결했다. 운영 서버·실기기·실제 모델은 사용하지 않았다. 정적 화면 대역과 실제 서버 실행 결과를 구분한다.

| 플랫폼 | 처음 마이 | 첫 열람 뒤 마이 | 같은 글 두 번째 열람 뒤 마이 | 삭제 뒤 마이 | 판정 |
| --- | --- | --- | --- | --- | --- |
| iOS | 0 | 1 | 1 | 0 | 실제 API와 화면 모두 통과 |
| Android | 0 | 1 | 1 | 0 | 실제 API와 화면 모두 통과 |

- 삭제 메뉴로 들어가려고 세 번째 상세를 열어 최종 누적 열람 값은 3이다. 최근 값은 삭제 후 0, 누적 저장 값은 1을 유지했다. 앱 내 저장 직후 자동 상세 관측은 앞의 보조 테스트에서 별도로 확인했다.
- iOS 증거: `screens/live-ios-{baseline,first-open,second-open,deleted}.png`, `screens/live-ios-flow.mp4`, `live-ios-*-stats.json`.
- Android 증거: `diagnosis/scenario/android-1-baseline-my.png`, `android-2b-first-open-my.png`, `android-3b-second-open-my.png`, `android-5-deleted-my.png`, `android-*-stats.json`, `android-flow.mp4`. Android 영상은 녹화 제한으로 두 조각을 이어 붙였으며 영상 길이는 시간 제한의 검증 근거로 쓰지 않는다.
- 설치된 Android APK 해시가 `app-after-live.apk`와 일치함을 확인했다. 서버 열람·삭제 응답과 같은 시점 스크린샷을 대조했다. 최종 기기·서버 종료, 잠금 해제, 기준 임시 worktree 제거를 확인했다.

## Android 시작 실패 진단과 한계

처음 실제 서버 APK를 실행했을 때 '저장한 콘텐츠를 불러오지 못했어요.'로 끝나 멈췄다. 사용자 결정 **"원인 진단 승인 (Recommended)"**에 따라 새 Opus 5.5 medium 작업자가 diagnosing-bugs를 적용했다. 제품 코드는 수정하지 않았다.

- 지연 없는 현재 APK는 반복 실행에서 정상 로딩했다. categories 응답을 늦추는 로컬 프록시로 같은 오류와 feed 요청 없음이 재현됐다. 서버 연결 유지 시간을 늘려 분리한 실험에서는 13초 지연 성공·16초 지연 실패였으며, 등록된 기준 worktree `2423f46`에서 빌드한 앱도 같았다. 초기 홈 로딩의 15초 제한은 #247부터 있던 코드이며 이번 변경에서 수정하지 않았다.
- 원래 실행은 첫 요청까지 19초 이상 걸렸고 새 부팅에서는 3–9초였다. 느린 기기 상태가 계기였다는 진단에 따라 환경만 새로 부팅했다. 원래 기기 상태 자체는 재현하지 못했고, 원래 실패가 15초 제한인지 연결 유지 경합인지는 확정하지 못했다. 프록시의 연결 경합 재현을 운영 서버 결함으로 확대하지 않는다.
- 최종 Android 시나리오는 지연 프록시 없이 원래 서버 설정·APK·합성 데이터로 수행해 위 동작을 통과했다. 상세 재현·가설·판정·정리 증거는 로컬 `.utmp/diagnosis-338.md`와 `ticket-338/diagnosis/`에 있다.
- 범위 밖 발견: 느린 시작의 시간 제한·자동 재시도 정책, Android 마이 계정 칸이 '계정 정보 확인 중'에 머물다 삭제 후 복귀 때 갱신된 현상. 후자는 원인과 기준 커밋 재현 여부가 미확정이다. 통계 값 판정과 분리하고 제품 변경 없이 별도 추적 여부를 조율에 전달한다.

## 병합 뒤

- 조율이 병합 커밋 CI와 서버 배포 ID·상태·생성 시각, 운영 소스 SHA 및 `/api/v1/health/ready`를 확인한다. 병합 자체를 배포 성공으로 보지 않는다.
- 확인 ①: 서버 운영 반영 후 조율이 사용자에게 순서표를 전달해 iPhone 13의 TestFlight 0.5.2에서 기존 누적 통계와 조회 실패 없음을 확인한다. 새 앱 후보는 이 확인 뒤에 만든다.
- 확인 ②: 다음 앱 후보의 실기기 확인에서 같은 글 반복 열람은 1만 증가하고 삭제 후 1 감소하는지 확인한다. 결과는 서버·앱 배포 기록에 남긴다.
- 이 작업에서는 운영 배포·실기기 확인·원격 CI를 실행하지 않았다. CI 실행을 위한 push와 PR 생성은 초안 승인 뒤 수행한다.
