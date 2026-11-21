# 깨진 글자 태그 저장과 DB 오류 로그 (#445)

기록일은 2026-11-21입니다. [이슈 #445](https://github.com/clip-back/clipback/issues/445)

## 변경

태그 이름에 NUL이나 짝 없는 유니코드 서로게이트가 있으면 정규화 전에 거절합니다. 링크·공유 저장과 태그 교체는 두 입력을 검사하고 스크린샷 multipart는 NUL을 검사합니다. FastAPI의 기본 422 렌더링이 UTF-8 인코딩에 실패할 때만 같은 오류 구조를 ASCII 이스케이프로 직렬화합니다. AI 태그는 거절된 항목만 건너뜁니다.

API 요청에서 처리되지 않은 예외가 `uvicorn.error`에 기록되면 `unhandled_error`와 `exception_type`을 한 줄로 남깁니다. 스크린샷 확정 여부를 확인하다 실패한 경우도 예외 종류만 기록하며 원본 보존과 예외 전파를 유지합니다. 500 응답은 `text/plain; charset=utf-8`과 `Internal Server Error` 본문을 유지합니다.

[API 태그 계약](../backend/api-contracts.md#tag-replacement)과 [배포 상태 확인 안내](../railway-deployment.md#실행-및-상태-확인)를 갱신했습니다.

## 검수 반영

| 지적 | 판단과 반영 |
| --- | --- |
| HTTP 라이브러리 로그 주석 | 앱 로거와 `uvicorn.error` 필터 설정 범위를 주석에 적었습니다. |
| 운영자 로그 안내 | 배포 문서에 예외 종류 한 줄의 형식과 접근 로그에서 확인할 항목을 설명했습니다. |
| 통합 검사 이름 | 인프로세스 500 응답과 앱 로그 확인을 새 테스트의 이름과 설명에 명시했습니다. |
| 422 대체 렌더링 비교 | 합성 예외의 로컬 렌더러 단위에서 기본 처리기와 대체 처리기를 대조했습니다. |

## 로컬 부분 검사

- 기준 `96745b3`에서 실제 저장 진입점을 차단한 태그 입력 검사 11건이 예상대로 실패했습니다. 같은 실행의 일반 422 응답 바이트 검사는 통과했습니다. 기준 단위 실행에서는 태그 검증 2건과 합성 예외 로그 필터 1건이 예상대로 실패했습니다.
- 첫 구현 `ce96d3d`의 PostgreSQL 부분 검사에서 379건이 통과했고 건너뜀은 0건이었습니다. 초기 실행의 스크린샷 로그 검사 실패는 기준과 수정본에서 한 번의 로그 호출이 stderr 한 줄, `caplog`의 동일한 로그 레코드 객체 두 건으로 수집되는 현상으로 확인했습니다. 해당 새 테스트는 전용 로그 핸들러로 바꿔 출력 한 줄과 표식 비노출을 유지했습니다.
- **필터 단위** 검사에서는 하위 프로세스에 uvicorn 로그 설정을 적용하고 합성 예외 하나를 직접 기록했습니다. 예외 종류 한 줄과 합성 표식·traceback 비노출을 확인했습니다.
- **인프로세스 ASGI** 검사는 다섯 저장 경로의 500 상태·본문·Content-Type과 앱 로그의 합성 표식 비노출을 확인합니다. 스크린샷 확정 확인 실패 경로는 앱 로그 한 줄과 원본 보존도 확인합니다.
- **실제 루프백 uvicorn**에서는 첫 구현으로 링크·공유·스크린샷 저장, 카테고리 만들기, 태그 교체의 500을 각각 확인했습니다. 요청마다 기존 본문과 Content-Type을 유지했고 합성 표식·SQL·traceback 없이 `DBAPIError`가 한 줄씩 기록됐습니다. 실행 도구는 작업 폴더에 보관했고 결과는 `.utmp/ticket-445/partial-loopback-resume/run.log`에 있습니다.
- **로컬 렌더러 단위**에서는 합성 입력에 대체 처리기를 제외하면 `UnicodeEncodeError`가 나고, 대체 처리기를 사용하면 동일한 세부 내용의 422가 반환됐습니다. 일반 입력의 바이트와 헤더도 기본 처리기와 일치했습니다. 3건 통과했습니다.

## 전체 검증

- 전체 검사 직전 조회한 `origin/main`은 `96745b3`이며 `HEAD..origin/main`의 출력은 비어 있었습니다.
- 검수 반영분을 stage한 트리 `16c601208b1d1b1b556bd443cc8cc3704beeafcd`에서 `python3 ~/.heoturu-agents/verify.py --log-dir .utmp/ticket-445`를 한 번 실행했습니다. 실행 당시 HEAD는 `ce96d3d`였습니다. 검수 반영 커밋에는 검증한 트리에서 이 이력과 목차만 추가했습니다.
- `VERIFY result=PASS scope=all checks=12 failed=0`. 백엔드 pytest는 `2906 passed, 50 skipped, 3 warnings in 357.30s (0:05:57)`이며 기존 저장 흐름과 기존 500 단언을 포함합니다. Flutter는 3,943건이 통과했습니다.
- CI와 같은 `ruff check app scripts alembic tests`, `deptry .`, `pytest -q -rs` 증거는 전체 검사 단계 로그를 사용했습니다. 전체 검사는 `compileall`에 `-q`를 사용하므로 CI의 `python -m compileall app scripts alembic tests`도 따로 실행해 통과했습니다.
- 실행 ID는 `20261121T162030-cfcf9c04f7e3`입니다. 단계별 로그와 결과는 `.utmp/ticket-445/20261121T162030-cfcf9c04f7e3/`에 있으며 로컬 결과 파일은 `verify-result.txt`입니다.

로컬 검증 도구의 건너뜀 기록입니다.

```text
pytest skip: 49 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
```

Docker 배포·복구를 확인하는 원격 PR CI는 별도 단계입니다. 운영 서버·DB·로그 조회와 기기 화면 검증은 실행하지 않았습니다.

태그 이외 문자열의 NUL과 잘못된 multipart UTF-8 바이트는 각각 시트 139·140 범위입니다. 배포 후 로그 대조는 사용자 확인 단계입니다.
