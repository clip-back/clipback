# 저장 글자와 스크린샷 태그 입력 검증 (#448)

기록일은 2026-11-21입니다. [이슈 #448](https://github.com/clip-back/clipback/issues/448)

## 변경

콘텐츠 직접 저장의 `title`·`summary`, 카테고리 생성·수정의 `name`·`color`, 피드의 `q`, Apple 로그인·게스트 업그레이드의 `display_name`에서 NUL을 거절합니다. 제한 없는 `summary`의 짝 없는 유니코드 서로게이트도 422로 거절합니다. 길이 제한 필드의 기존 서로게이트 422와 Apple의 일반 인증 오류 응답을 유지합니다.

스크린샷 폼에서 `tag_names`만 원시 바이트로 UTF-8을 확인합니다. 파서는 해석할 수 없는 값을 폼에 추가하지 않고 표시를 남겨 다음 파트를 해석합니다. 폼 해석, 인증·권한 확인, 다른 본문·헤더 필드 검증을 모두 통과한 요청에 잘못된 태그 바이트가 있으면 저장이나 제출 처리 전에 `loc ["tag_names"]`와 기존 태그 오류 문구가 담긴 422를 반환합니다. 이 오류의 `input`은 `null`입니다. [API 계약](../backend/api-contracts.md#screenshot-storage)

## 검수 반영

| 지적 | 판단과 확인 |
| --- | --- |
| Standards 1 · Starlette 의존 | 원시 파트와 `Request._form` 캐시를 사용하는 이유와 버전 갱신 때 다시 볼 통합 테스트를 주석에 적었습니다. 테스트에서 임시 파일의 닫힘과 저장 파일·행 미생성을 확인했습니다. |
| Standards 2 · 폼 오류 처리 | FastAPI 본문 해석과 같은 HTTP 예외 전파와 일반 파싱 실패 400 처리에 출처를 적었습니다. 폼 구조 오류 400의 본문과 기존 본문 한도 413 검사가 통과했습니다. |
| Standards 3 · 검증기 배치 | 두 카테고리 모델에서 공통 검증을 이름 정규화 뒤에 배치했습니다. NUL·서로게이트 응답과 카테고리 기존 테스트를 다시 확인했습니다. |
| Standards 4 · 서비스 테스트 대역 | 직접 요청 모델은 내부 입력 모델의 하위 클래스여서 기존 대역으로 서비스 흐름을 계속 검사할 수 있습니다. 검증 경계의 근거를 아래에 기록했습니다. |
| Spec 1 · 인증 순서 | 기준에서 인증 누락·잘못된 토큰은 같은 401, 잘못된 태그 뒤의 폼 구조 오류는 400이었습니다. 첫 구현에서 셋 모두 422가 되는 것을 재현했습니다. 반영 후 인증 실패·파싱 실패·인증 성공에 각각 401·400·태그 422를 확인했습니다. |
| Spec 2 · multipart charset | charset 선언과 무관한 태그 UTF-8 규칙을 문서화했습니다. 선언 유무에 따른 잘못된 FF의 거절과 정상 ÿ·😀·한글의 저장을 확인했습니다. `category_ids`는 선언된 ISO-8859-1로 해석되는 기존 오류 입력을 유지했습니다. |
| Spec 3 · 요청·내부 모델 | 직접 요청인 `ContentCreate`에 새 검증을 붙였습니다. `ContentSaveInput`을 쓰는 OCR 결과·메타데이터 보강·공유 입력은 기존 해석과 처리 경계를 유지합니다. 외부 값에서 같은 HTTP 상태가 나오더라도 새 검증을 적용하면 오류가 발생하는 단계가 달라집니다. |
| Spec 4 · 정상 응답 바이트 | 기준과 반영본의 정상 응답 7개 및 OpenAPI를 아래 실행 기록으로 남겼습니다. 기존 서로게이트 422 바이트는 커밋된 통합 테스트가 검증합니다. |

같은 폼 경로의 다른 진입점을 검색했습니다. multipart 쓰기는 `POST /api/v1/uploads/screenshots` 하나이며 일반·공유 인증이 여기서 합쳐집니다. 같은 인증 의존성을 쓰는 `POST /api/v1/contents/share`는 JSON 요청이고, 원본 조회·접근 URL 발급은 읽기입니다.

## 재검수 판단

- Standards 1의 `request.state` 전달과 기본값을 유지했습니다. 판정 표시가 엔드포인트까지 전달되지 않으면 잘못된 태그의 HTTP 422를 단언하는 기존 통합 검사가 실패합니다.
- Spec 1은 재검수의 로컬 재현 5건에 맞춰 문서 표현을 바로잡았습니다. 파일이 없거나 `category_ids` 또는 `Idempotency-Key`의 형식이 잘못된 요청은 해당 필드 오류를 먼저 반환합니다.
- 재검수 반영은 문서만 바꿨습니다. 코드와 테스트가 전체 검증을 통과한 `f83ca30`과 동일하므로 그 검증 결과를 사용했습니다.

## 부분 검사

- 기준 `2d5d4f0`에서 폼 실험 6건 통과. 첫 구현을 위한 회귀 검사에서는 지정 글자 칸 17건이 500, 잘못된 태그 인코딩 6건이 201로 예상 실패했습니다. 첫 커밋 `97f1d48` 전 관련 검사 508건이 통과했고 검증 제거·정상 글자 오거절 변형 10개가 잡혔습니다.
- 인증 순서 검수에서는 기준 4건이 통과했고 첫 구현에서는 토큰 누락·무효 토큰·잘못된 폼 구조의 새 단언 3건이 예상대로 실패했습니다. 반영본은 로컬 PostgreSQL에서 관련 검사 365건이 통과했고 건너뜀은 0건이었습니다.
- 기준과 반영본에서 카테고리 생성·수정, 콘텐츠 저장, 피드, 스크린샷 저장, Apple 로그인·업그레이드의 정상 응답 7개를 비교했습니다. 동적으로 생성되는 ID·저장 시각·토큰·원본 다운로드 URL의 형식을 확인하고 값만 마스킹했으며 나머지 바이트가 일치했습니다. OpenAPI 전체 바이트도 일치했습니다. 공유 저장 메타데이터·URL의 NUL 처리와 기존 서로게이트 422도 부분 통합 검사를 통과했습니다.

## 전체 검증

- `97f1d48` 위에 검수 반영분을 stage한 트리 `0ceca9a3ac5ef682be13708e2f1c053b9ab6e78a`에서 `python3 ~/.heoturu-agents/verify.py --log-dir .utmp/ticket-448`를 실행했습니다. 전체 검증 뒤에는 이 이력과 목차를 추가했습니다.
- `VERIFY result=PASS scope=all checks=12 failed=0`이며 종료 코드는 0입니다. 백엔드 pytest는 `2950 passed, 50 skipped, 3 warnings in 371.20s (0:06:11)`입니다. Flutter 테스트는 3,967건이 통과했습니다.
- CI와 같은 `ruff check app scripts alembic tests`, `deptry .`, `pytest -q -rs`는 전체 검증 단계에서 확인했습니다. 전체 검증은 compileall의 출력 억제 옵션을 사용하므로 CI 명령인 `python -m compileall app scripts alembic tests`도 실행해 종료 0을 확인했습니다.
- 실행 ID는 `20261121T191410-7bd2371feb8c`입니다. 단계별 로그와 `verify-result.txt`는 로컬 작업 폴더의 해당 실행 디렉터리에 있습니다.

로컬 검증 도구의 건너뜀 기록입니다.

```text
pytest skip: 49 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
```

배포용 Docker 검증은 PR CI 단계입니다. 이 작업의 실행 근거는 로컬 PostgreSQL과 외부 공급자 대역을 사용한 자동 검사이며, 운영 대조와 기기 화면은 이슈 범위 밖입니다.
