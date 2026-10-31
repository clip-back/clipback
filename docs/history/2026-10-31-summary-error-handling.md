# 요약 작업과 메타데이터 요청의 예상 밖 오류 처리

최초 기록일: 2026-10-31 KST. 기준은 [이슈 #134](https://github.com/clip-back/clipback/issues/134) 본문과
댓글 "범위 확장 제안"이다. 브랜치 `fix/summary-error-handling`(main `a70009c` 기준)에서 작업했다.

## 결정 (사용자 확인 2026-10-31)

이슈에서 확정되지 않았던 두 가지는 기존 코드·API 계약·앱 영향을 조사한 뒤 사용자가 정했다.

- 주소 해석 실패의 실패 사유는 `invalid_url`이다. 인스타그램 대표 이미지 단계가 이미 쓰는 이름과 같고,
  리다이렉트 `Location` 해석 실패도 `parse_failure` 대신 이 이름으로 기록한다. 이 값은 API 응답에 나가지 않는다.
- 요약 클라이언트의 예상 밖 예외는 기존 `provider_error`로 끝낸다. `ContentRead.summary_error_code`는 허용 값이 고정된
  `Literal`이라 새 코드는 API 계약 변경이 필요하다. 앱은 이 값을 읽지 않는다. 로그의 `reason=unexpected_error`와
  `exception_type`으로 공급자 오류와 구분한다.

## 변경 범위

- `MetadataClient._fetch`: 처음 받은 주소의 해석(`_strip_fragment`)이 실패하면 `ValueError`를 전파하지 않고
  `invalid_url` 실패 결과를 반환한다. `extract_from_url`·`fetch_page`·`fetch_image`가 모두 해당된다.
  리다이렉트 `Location`의 해석 실패도 마지막으로 확인한 주소와 함께 `invalid_url`로 끝난다.
- `SummaryWorker._run_once`: `SummaryError`가 아닌 예외를 재시도 없는 `failed`/`provider_error`로 바로 반영한다.
  이전에는 작업이 `processing`에 남아 점유 만료(5분)와 재시도를 거쳐 약 10분 뒤 `timeout`으로 끝났다.
  `youtube_summary_result` 로그에는 예외 종류만 남기고 메시지는 남기지 않는다. 종료 신호(`CancelledError`)는 기존대로 전파된다.
- 문서: [요약 안내](../youtube-summary.md)의 재시도·로그·인스타그램 판정 표·이미지 미사용 사유,
  [CHANGELOG](../../CHANGELOG.md) 미배포 수정 항목.

## 자동 검사

2026-10-31 이 worktree(`backend/`, Python 3.12, 새 `.venv`)에서 실제로 실행한 결과다.

- 테스트를 먼저 작성해 실패를 확인한 뒤 구현했다.
  - `tests/integrations/test_metadata_client.py`: `https://[broken/p/x/`에서 `ValueError: Invalid IPv6 URL` 재현,
    리다이렉트 `Location` 해석 실패가 `parse_failure`로 기록되는 것 확인.
  - `tests/integration/test_youtube_summary.py`·`test_instagram_summary.py`: 클라이언트가 `RuntimeError`를 던지면
    worker 밖으로 전파되는 것 확인(계약 테스트, 구현 후 `failed`/`provider_error`와 재호출 없음 검증).
  - `tests/services/test_summary_logging.py`: 예외 종류만 기록되고 메시지가 없는 로그.

| 검사 | 결과 |
| --- | --- |
| 바꾼 영역(`tests/integrations`, 요약 통합·로그, 추출·공유 서비스) | 통과 |
| `ruff check app alembic tests` | 통과 |
| `pytest -q` | 1343개 통과, 46개 skip(Docker·빌드 이미지가 필요한 `tests/deployment` 45개, `CLIPBACK_IMAGE_TEST_S3_ENDPOINT`가 필요한 로컬 S3 CLI 1개), 경고 3건 |
| `python -m compileall app alembic tests` | 통과 |
| `alembic upgrade head` + `alembic check` | 통과(`No new upgrade operations detected.`) |
| `git diff --check` | 통과 |

- 첫 `pytest -q` 실행에서는 점검 테스트 DB 이름을 `clipback_maintenance100`이 아닌 이름으로 만들어
  `tests/integration/test_maintenance.py` 5건이 준비 단계에서 오류였다. DB 이름을 바꾼 뒤 전체를 다시 실행한 결과가 위 표다.

- 테스트 DB는 로컬 PostgreSQL(5432)의 이 작업 전용 DB `clipback_test_issue134`와 점검 테스트용
  `clipback_maintenance100`이며 검증 뒤 삭제했다. Docker는 사용하지 않았다.
- 원격 CI·운영 서버 검증은 하지 않았다. 앱 화면 변경이 없어 시뮬레이터·에뮬레이터는 실행하지 않았다.
