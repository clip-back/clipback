# 인스타그램 페이지 요청의 httpx 시간 초과를 timeout으로 기록 (#157)

2026-11-08, 시작 커밋 `3b3d10f` 기준으로 구현하고 티켓 리뷰, 전체 검증까지 마쳤다. 코드 커밋은 `e0d1a4f`이다. 서버만 바꿨다.

## 사용자 결정

- 2026-11-02 분류 댓글: httpx 시간 초과를 `timeout`으로 분류한다. 분류는 인스타그램 요약 client에서만 바꾸고 링크 메타데이터 client의 분류는 그대로 둔다. #148 고정 테스트의 해당 행을 함께 고친다.
- 2026-11-08 "내부 표시만 추가 허용 (Recommended)": 메타데이터 client 결과에 '시간 초과였음' 표시만 더하고, 인스타그램 요약에서만 이 표시를 보고 `timeout`으로 기록한다. 메타데이터 client의 분류(요청 실패)와 링크 저장·이미지 요청 결과는 그대로다.
  인스타그램 요약 client는 메타데이터 client가 이미 `request_failure`로 바꾼 결과만 받아, 메타데이터 client를 고치지 않으면 시간 초과를 구별할 수 없어 정했다.
- 2026-11-08 "두 단언 변경 허용 (Recommended)": `test_instagram_summary_client.py::test_page_network_failures_are_retryable`의 httpx `ReadTimeout` 페이지 단언 2개의 값만 바꾼다.

## 바뀐 값

인스타그램 게시물 페이지 요청이 httpx 시간 초과(`httpx.TimeoutException` 계열: 연결·읽기·쓰기·풀)로 끝날 때:

| 항목 | 변경 전 | 변경 후 |
| --- | --- | --- |
| 작업·API `summary_error_code` | `provider_error` | `timeout` |
| 로그 `youtube_summary_result`의 `error_code` / `reason` | `provider_error` / `network_error` | `timeout` / `timeout` |
| `retryable`(30초 뒤 1회 재시도), `provider` | `true`, `instagram` | 그대로 |

바뀌지 않은 것:

- 메타데이터 client의 `failure_reason`은 httpx 시간 초과에도 `request_failure`다. 링크 저장(`extract_from_url`) 결과는 그대로다.
- 대표 이미지 요청의 httpx 시간 초과는 `image.reason=request_failure` 그대로다.
- 연결 실패·DNS 실패는 `provider_error`/`network_error`, 전체 5초 상한 초과는 지금처럼 `timeout`이다.

## 구현

- `backend/app/integrations/metadata_client.py`: `MetadataResult`·`PageMeta`에 `timed_out`(기본 false)을 더했다. `httpx.TimeoutException`이면 `request_failure`에 `timed_out=true`를 붙인다. `ImageFetch`에는 넣지 않았다.
- `backend/app/integrations/instagram_summary_client.py`: 페이지 실패가 `timeout`이거나 `timed_out`이면 `timeout`(reason `timeout`, 재시도)으로 기록한다.
- [자동 요약 안내](../youtube-summary.md)의 인스타그램 페이지 응답 표와 대표 이미지 미사용 사유 설명을 갱신했다.

## 앱 호환과 CHANGELOG

- 현재 `frontend/`와 배포 태그 `app-ios-v0.5.0-b11`·`app-android-v0.5.0-b7`의 `frontend/`에는 `summary_error` 문자열이 없다(`git grep`). 앱은 `summary_status`만 읽는다(`frontend/lib/clipback_api.dart`).
  상태(`failed`)와 재시도 흐름도 같아 화면 표시 차이가 없고 0.5.0과 호환된다. 응답 스키마의 `summary_error_code` 값 목록에 `timeout`이 이미 있어 형식 변경도 없다.
- 이 근거는 코드 확인이며, 시뮬레이터·에뮬레이터·실기기 실행은 하지 않았다(화면 변경 없음).
- CHANGELOG `미배포`는 갱신하지 않았다. 앱 사용자가 경험하는 변화가 없어서이며 티켓 리뷰가 이 판단을 받아들였다. API 값과 운영 로그는 바뀌므로 PR 본문에 바뀌는 값과 제외 사유를 적는다.

## 테스트

- #148 고정 테스트 `tests/integration/test_summary_log_contract.py`의 `page-read-timeout` 행: `provider_error` → `timeout`(결정이 허용한 행만).
- `tests/integrations/test_instagram_summary_client.py::test_page_network_failures_are_retryable`의 `ReadTimeout` 단언 2개: `("provider_error", True)` → `("timeout", True)`, `network_error` → `timeout`.
  허용 범위에 없던 단언을 승인 전에 먼저 고쳤고, 커밋 전에 묻고 위 결정으로 승인받았다. 테스트 이름과 다른 단언은 그대로다.
- 추가: `test_metadata_client.py::test_request_failure_keeps_its_reason_and_marks_httpx_timeouts`(ReadTimeout·ConnectTimeout·ConnectError에서 링크 저장·페이지·이미지 모두 `request_failure`, `timed_out`은 시간 초과만 true),
  `test_instagram_summary_client.py::test_image_read_timeout_stays_a_request_failure`(이미지 시간 초과는 `image.reason=request_failure`, 요약은 캡션으로 성공).
- 수정 전 실패 확인: 테스트만 바꾼 상태에서 6개가 실패했다. 제품 동작 재현은 5개(내부 표시 없음 3개, 단위 단언 1개, 고정 로그 행 1개 — 로그에 `provider_error`/`network_error`)다.
  나머지 1개(이미지 테스트)는 테스트가 요청 주소를 잘못 판별한 작성 오류라 테스트를 고쳤고, 제품 결함 재현이 아니다.

## 리뷰

- 티켓 리뷰(`3b3d10f..e0d1a4f`): Standards 0건, Spec 0건.

## 검증

2026-11-08, 기준 코드 `e0d1a4f`(로컬, 대역 데이터).

- 전체 검증 `python3 ~/.heoturu-agents/verify.py`: `VERIFY result=PASS scope=all checks=11 failed=0`.
  백엔드 `pytest: 2324 passed, 47 skipped, 3 warnings`. `ruff check app scripts alembic tests`는 verify의 `backend:ruff` 단계와 같다.
  - pytest skip: 46 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
  - pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
- verify에 없는 `deptry .`(backend)를 따로 실행해 통과했다.
- Docker가 필요한 deployment·운영자 복구 테스트(위 skip 46개)는 로컬에서 돌지 않았다. 이번 변경은 이 범위를 바꾸지 않았고, 원격 CI는 PR 생성 뒤 확인한다.
