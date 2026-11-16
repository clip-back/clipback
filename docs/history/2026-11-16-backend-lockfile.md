# 서버 의존성 lock과 API Python 패치 고정 (#403)

2026-11-16 기록. [이슈 #403](https://github.com/clip-back/clipback/issues/403)의 첫 구현 `2c28c9f`, 검수 반영 `e0f206a`, main 병합 뒤 검증 기준 `76517099a7553df38b5825cfba62bfc56dccacdc`의 결과와 [PR #405](https://github.com/clip-back/clipback/pull/405) CI(head `25a9600`) 결과다. 실제 Railway 배포 확인은 포함하지 않는다.

## 변경과 결정

- [운영 lock](../../backend/requirements.lock)은 API·운영자 이미지, [개발 lock](../../backend/requirements-dev.lock)은 CI·로컬 설치에 사용한다. 개발용 해석은 운영용 lock을 제약으로 사용한다. lock 설치 → 프로젝트 `--no-deps` 설치 → `pip check` 순서다.
- uv는 dev extras의 `uv==0.13.8`로 고정했다. 처음 lock은 CI 실행 43854818241의 시각인 `2026-11-16T11:06:42Z`를 `--exclude-newer`로 주어 생성했다. 실제 생성 명령은 두 lock 머리에 있다.
- 감독 판단으로 두 compile에 `--universal --python-version 3.11`을 명시했다. `uv pip compile --universal`의 기본 목표 하한은 해석 인터프리터의 Python 부 버전이다. Python 3.12.7에서 옵션을 생략하면 목표가 `>=3.12`여서 운영자의 Python 3.11.2 갈래가 빠졌다. 옵션을 명시하자 `soupsieve==2.10 ; python_full_version < '3.11.5'`와 `soupsieve==4.1.1 ; python_full_version >= '3.11.5'`가 자동 생성됐다. 프로젝트 선언 `requires-python >=3.11`은 유지했다. 근거: [uv universal 옵션](https://docs.astral.sh/uv/reference/cli/#uv-pip-compile--universal), [Python 버전 옵션](https://docs.astral.sh/uv/reference/cli/#uv-pip-compile--python-version), 동일 버전 verbose 통제 실험.
- API 이미지는 `python:3.12.16-slim`이다. 기존 CI의 index digest `sha256:5e2bdb1b0d542d5039cffb8181c65930093949194a65c365dfb1b0fe13a4fa5b`에서 Linux/amd64 manifest와 config를 Docker Registry API로 조회해 `PYTHON_VERSION=3.12.16`을 확인했다. 운영자 `postgres:${POSTGRES_MAJOR}-bookworm`과 digest 고정 여부는 그대로다.
- 두 Dockerfile은 app 복사 전에 운영 lock을 설치해 의존성 층을 재사용한다. CI 설치 5곳·캐시 키 4곳·운영자 경로 판정만 변경했다. 검사 명령·Docker 빌드 인자·옛 리비전 빌드·기존 테스트는 바꾸지 않았다.

사용자 결정(2026-11-16, 원문 각각 **"응"**):

> 기존 버전 diff 0, 추가는 결정 1에 따른 uv 한 줄만 허용

> 검사 범위는 운영 라이브러리, 개발 도구는 검사 대상 아님

후자의 범위는 pyproject와 lock 사이의 불일치 감지다. 프로젝트를 extras 없이 설치하므로 `pip check`는 dev extras의 ruff·deptry·uv·moto 등에 대한 추가·범위 변경을 검사하지 않는다. 개발 도구 변경도 lock을 직접 갱신하고 diff를 확인해야 한다. CI에 lock 최신성 비교 단계를 추가하지 않았다.

## 검수 반영

- **S1(중간):** 위 사용자 결정에 따라 불일치 감지 범위를 운영 의존성으로 명시했다. [README 갱신 안내](../../backend/README.md#빠른-실행)에 dev extras의 한계를 적었으며 CI·코드는 바꾸지 않았다.
- **S2(낮음):** 감독 판단으로 README 한 줄 갱신 명령에서 두 `--upgrade`를 뺐다. 기존 pin을 유지하며 필요한 것만 갱신하고, 전부 올릴 때 두 compile에 `--upgrade`를 붙인다고 안내한다.
- **Standards 판단 사항:** CI 설치 블록 5곳의 반복을 공통화하는 변경은 이슈 허용 범위 밖이므로 반영하지 않았다.

README의 수정된 명령을 pyproject·기존 두 lock을 복사한 임시 디렉터리에서 그대로 실행했다. 두 출력 모두 생성 명령 헤더 두 줄 외 차이 0이다. 커밋된 lock 자체는 변경하지 않았다.

## 회귀 확인 1–4

별도의 새 Python 3.12.7 가상환경에 `requirements-dev.lock` → `pip install --no-deps -e .` 순서로 설치했다. 운영 서버·운영 데이터는 사용하지 않았다.

| 확인 | 결과 |
|---|---|
| 1. 새 환경 설치·검사 | `pip check`, `ruff check app scripts alembic tests`, `deptry .`, `python -m compileall app scripts alembic tests` 모두 종료 0 |
| 일반 CI pytest | `pytest -q -rs`: 1692 passed, 1100 skipped in 100.96s (0:01:40) |
| migration·DB 검사 | 전용 일반·maintenance DB 각각 `alembic upgrade head` → `alembic check` 종료 0; `TEST_DATABASE_URL`·`MAINTENANCE_TEST_DATABASE_URL` 설정 뒤 `pytest -vv -rs -o faulthandler_timeout=60 tests/repositories tests/integration`: 1057 passed, 1 skipped, 3 warnings in 261.96s (0:04:21) |
| 2. 기존 CI 버전 대조 | 새 환경 freeze에서 프로젝트 자신 제외: 기존 73개 diff 0, 추가는 `uv==0.13.8` 한 줄뿐. 운영 lock은 marker 평가 후 API·PG16·PG18 목록 각각 56개 diff 0 |
| 3. 운영·개발 공통 버전 | 공통 57개 패키지 이름의 버전·marker 행 차이 0. Python 3.11.2·3.11.18·3.12.16에서 활성 운영 56개도 버전 차이 0 |
| 4. 불일치 실패 재현 | 운영 의존성 추가·범위 변경 각각 `pip check` 종료 1. 파일 복사본으로 원복하고 프로젝트 metadata 재설치 뒤 종료 0, 원복 전후 diff 일치 |

회귀 4의 메시지:

```text
clipback-backend 0.1.0 requires rich, which is not installed.
clipback-backend 0.1.0 has requirement fastapi<0.100, but you have fastapi 0.163.1.
```

일반 CI pytest의 skip 1100개는 Docker 48개, 미설정 `TEST_DATABASE_URL` 관련 1047개, 미설정 `MAINTENANCE_TEST_DATABASE_URL` 관련 5개다. DB 검사의 skip 원문은 다음과 같다. 경고 3개는 기존 Alembic `No path_separator found in configuration`이다.

```text
SKIPPED [1] tests/integration/test_image_storage_admin_cli.py:20: CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local synthetic CLI test
```

원 명령·종료 코드·개별 skip 원문은 `.utmp/ticket-403/partial-fresh-ci-batch/`와 그 단계별 `partial-*` 로그에 보존했다. 버전 대조는 `partial-final-common-packages/`, 실패 변형·원복은 `partial-pip-check-mutations/`, README 재현은 `partial-review-readme-command/`에 기록했다.

## 병합 후 전체 검증

main을 병합하기 전 merge-tree 충돌 없음, 병합 후 CHANGELOG 검사 종료 0을 확인했다. 전체 검증 직전 fetch와 `HEAD..origin/main` 조회에 추가 커밋이 없었다.

검증 기준 `76517099a7553df38b5825cfba62bfc56dccacdc`에서 전체 검사 원 프로세스 종료 0, 실행 ID `20261116T222733-4573a1096ca2`, 시작·끝 HEAD 동일·작업 트리 clean을 확인했다. 결과 파일은 `.utmp/ticket-403/20261116T222733-4573a1096ca2/verify-result.txt`이며 상위 `verify-result.txt`와 내용이 같다.

```text
VERIFY result=PASS scope=all checks=12 failed=0
```

- 백엔드: 2743 passed, 49 skipped, 3 warnings in 334.84s (0:05:34).
- 앱: 3766 tests passed (`All tests passed!`). 자동 테스트이며 기기 실행 검증은 아니다.
- 정적 검사·앱 의존성 설치/포맷/분석·두 DB migration/check를 포함해 12개 검사 모두 통과했다.

전체 검증 skip 줄 원문:

```text
pytest skip: 48 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
```

이 기록·목차만 추가하는 문서 커밋은 검증 기준 커밋과 코드가 같으므로 전체 검증을 다시 실행하지 않는다.

## PR CI 회귀 확인 5–7

[PR #405 CI run 43878636386](https://github.com/clip-back/clipback/actions/runs/43878636386)(head `25a9600`, 2026-11-16T13:44:14Z–13:53:39Z): `changes`·`lint`·`test (3.11)`·`test (3.12)`·`migration`·`deployment`·`operator-recovery` 7개 job 모두 success. 각 이미지 빌드 로그의 `Successfully installed` 목록을 `backend/requirements.lock`(해당 Python에서 marker 평가, 프로젝트 자신 제외)과 비교했다.

| # | 빌드 | 기본 Python | 설치 목록 vs 운영용 lock | `pip check` |
|---|---|---|---|---|
| 5 | `deployment` API 이미지 | `python:3.12.16-slim` | 56개 diff 0, `soupsieve==4.1.1` | No broken requirements found. |
| 5 | `operator-recovery` API 이미지 | `python:3.12.16-slim` | 56개 diff 0, `soupsieve==4.1.1` | No broken requirements found. |
| 6 | `deployment` 운영자 이미지(PG16) | Debian `python3.11` 3.11.2 | 56개 diff 0, `soupsieve==2.10` | No broken requirements found. |
| 6 | `operator-recovery` 운영자 이미지(PG18) | Debian `python3.11` 3.11.2 | 56개 diff 0, `soupsieve==2.10` | No broken requirements found. |

- 7: `deployment`의 `Check ledger bootstrap and local API handoff` 15 passed, `operator-recovery`의 `Check private source backup, maintenance and isolated recovery` 33 passed.
- 운영자 이미지의 pip 23.0.1이 `python_full_version` marker를 바르게 읽어 3.11.2에서 `soupsieve==2.10`을 설치했다.
- CI의 개발 의존성 설치 6곳(lint·test 2개·migration·deployment·operator-recovery)도 `pip check` 통과. 옛 리비전(`bf65413`) API 이미지 빌드는 범위 밖이라 lock 없이 그대로 빌드됐다.
- 로컬 전체 검증의 `pytest skip: 48 tests/deployment`(Docker)는 위 `deployment`·`operator-recovery` job이 실행했다. `pytest skip: 1 tests/integration`(S3 CLI 통합)은 CI `migration`에서도 같은 1 skipped로 남아 미검증이다.

## 미검증과 남은 확인

- 실제 Railway 배포·운영 설치 목록·운영 데이터는 확인하지 않았다. 병합 뒤 다음 배포 로그의 lock 설치·버전 확인은 별도 배포 기록으로 남긴다.
- 화면 변경·촬영은 없다. 이슈는 PR의 `Closes #403` 대상이므로 댓글·종료하지 않았다.
