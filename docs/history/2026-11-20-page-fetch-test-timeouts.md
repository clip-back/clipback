# 페이지 조회 테스트의 시간 제한 완화 (#434)

기록일은 2026-11-20입니다. [이슈 #434](https://github.com/clip-back/clipback/issues/434)

## 변경

인스타그램 자동 요약과 링크 메타데이터를 검사하는 백엔드 테스트 9개 파일의 지정된 10곳에서 페이지 조회 제한을 5초에서 60초로 늘렸습니다. 가짜 HTTP 전송을 쓰는 테스트에서 프로세스가 잠시 멈추면 운영 제한 5초를 넘겨 실패할 수 있었습니다. 변경 범위는 테스트용 기본값입니다.

## 검증

- 첫 페이지의 가짜 HTTP 전송 직전에 5.2초 멈춤을 한 번 주입했습니다. 깨끗한 기준 트리 `b4e1cd8`에서는 기존 테스트 10건이 모두 실패했고, 60초를 적용한 뒤 같은 10건이 모두 통과했습니다. 최초 보고된 인스타그램 요점 정리 테스트에서는 `SummaryError: timeout`을 재현했습니다.
- 변경한 9개 파일의 pytest는 임시 로컬 PostgreSQL을 포함해 398건 통과, 건너뜀 0건입니다. 이 실행에는 명시적으로 짧은 제한을 지정해 시간 초과를 검증하는 기존 테스트도 포함됩니다.
- CI와 같은 백엔드 명령 `ruff check app scripts alembic tests`, `deptry .`, `pytest -q -rs`, `python -m compileall app scripts alembic tests`가 통과했습니다. 앞의 세 명령은 전체 검증에서 실행했고, 마지막 명령은 CI와 같은 출력 옵션으로도 별도 실행했습니다.
- `origin/main`의 `a7035ea`를 합친 `5970450`에서 `python3 ~/.heoturu-agents/verify.py` 전체 검증을 실행했습니다. `VERIFY result=PASS scope=all checks=12 failed=0`. 백엔드는 `2751 passed, 49 skipped, 3 warnings in 341.04s (0:05:41)`, Flutter는 3,943건 통과였습니다.

로컬 검증 도구가 보고한 건너뜀은 다음과 같습니다. 배포 및 S3 실행 환경이 필요한 검사입니다.

```text
pytest skip: 48 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
```
