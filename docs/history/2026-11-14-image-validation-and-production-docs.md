# 깨진 이미지 저장 거절과 운영 API 문서 비활성화 (#362)

2026-11-14, 브랜치 `fix/image-validate-docs-off`. 스펙은 이슈 #362이며 시작 커밋은 `3d1e2dd`다.
구현 및 전체 검증 기준은 `1afeb93575bd40a4fb1bcf56356939a19191120c`다.
이 문서를 추가하는 커밋은 문서만 바꾸며 검증한 서버·앱 코드는 그대로다.

## 구현과 검수

- 스크린샷 저장 시 이미지 구조를 verify한 같은 바이트를 다시 열어 load한다.
  디코드 실패는 기존 `415`와 `Unsupported or invalid screenshot image`로 처리하며
  OCR·원본 저장·콘텐츠 생성 전에 거절한다. 기존 경고 처리와 이벤트 루프의 호출 위치를 유지했다.
- 정상 PNG·JPEG·WebP의 지원 형식과 저장 원본은 바꾸지 않았다. 앱 변경도 없다.
- `production`에서 FastAPI의 docs·redoc·openapi URL을 모두 비활성화한다.
  `/docs`, `/redoc`, `/api/v1/openapi.json`, `/docs/oauth2-redirect`는 404이며
  `local`·`test`의 문서 접근과 root·health 응답은 유지한다.
- 현재 안내는 [API 계약](../backend/api-contracts.md)과 [백엔드 README](../../backend/README.md)에 반영했다.
- 고정 범위 `3d1e2dd..1afeb93` 검수는 Standards 0건, Spec 0건이다. 검수 후 구현 수정은 없었다.
  기존 테스트의 이름·입력·기대값·fixture는 보존했다.

## 검증

- 변경 전 회귀 테스트로 이미지 거절 실패 2건과 production 문서 접근 실패 1건을 확인한 뒤 구현했다.
- 부분 pytest는 업로드 19개, 문서·기존 OpenAPI·설정 소비자 115개,
  PostgreSQL 기반 기존 스크린샷 저장 판정 순서 10개가 통과했다. 부분 검사 skip은 없다.
- 검수자가 준비한 로컬 정상 이미지 변형을 작업자가 실행했다. PNG 색 모드 7개,
  JPEG 기본·progressive 6개, WebP 기본·lossless 4개로 총 17개가 검증을 통과했다.
  이는 이미지 판정 검사이며 모든 변형의 전체 저장 흐름을 각각 실행한 결과는 아니다.
- 전체 검증은 위 코드 커밋의 clean 상태에서 한 번 실행했고 원 프로세스 종료 코드는 0이다.
  백엔드 ruff·compileall, 두 전용 PostgreSQL DB의 migration·schema 검사,
  전체 pytest, 앱 pub-get·format·analyze·전체 테스트가 통과했다.
  Flutter 테스트 마지막 결과는 `+3621: All tests passed!`다.

```text
pytest: 2661 passed, 49 skipped, 3 warnings in 333.93s (0:05:33)
pytest skip: 48 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=11 failed=0
```

VERIFY 줄의 로컬 로그 경로는 생략했다. 원 실행의 결과 파일·단계 로그·HEAD·clean 상태를 대조했다.

- 서버 CI의 `ruff check app scripts alembic tests`, `pytest -q`,
  `python -m compileall app scripts alembic tests`는 전체 검증의 같은 단계 로그로 확인했다.
  pytest의 `-rs`와 compileall의 `-q`는 결과 표시 옵션이므로 중복 실행하지 않았다.
- 전체 검증에 없는 `deptry .`만 별도로 실행해 `Success! No dependency issues found.`와 종료 코드 0을 확인했다.
- `git diff --stat main -- frontend`는 비어 있다. 기기·화면 검증은 이번 변경 대상이 아니다.

## 로컬 정상 표본 시간 측정

Pillow 13.0.0에서 정상 RGB 잡음 표본을 새로 생성해 각 형식을 한 번 측정했다.
각 행에서는 같은 바이트로 verify만 실행한 경우와 verify+load를 비교했다.

| 정상 표본 | verify | verify+load |
| --- | --- | --- |
| PNG 1900×1800, 약 9.8MiB | 0.835ms | 46.133ms |
| JPEG 4032×3024, 약 8.8MiB | 0.094ms | 90.652ms |

이슈 작성 당시의 표본 원본이 없어 크기·형식이 같은 새 표본을 사용했다.
따라서 과거 표본과 바이트가 같은 재측정으로 볼 수 없으며, 전체 요청 시간이나 운영 성능 수치도 아니다.
상세 생성 스크립트·표본 해시·실행 로그는 로컬 검사 자료로 보관한다.

## 한계와 미검증

- load는 현재 프레임 디코드다. 애니메이션의 모든 후속 프레임 검사까지 보장하지 않는다.
- 이미 저장된 원본의 재검사와 외부 대표 이미지를 처리하는 Instagram 요약 경로는 변경하지 않았다.
- Docker deployment·operator-recovery 48개와 로컬 S3 CLI 통합 검사 1개는 위 사유로 미실행이다.
  `main.py` 변경은 배포·복구 CI 경로 대상이므로 원격 CI 결과를 별도로 확인해야 한다.
- 운영 서버 요청·배포·실제 앱 실행은 하지 않았다. 배포 뒤 운영 확인은 이슈 범위 밖이며
  [서버 배포 절차](../release-process.md)를 따른다.
