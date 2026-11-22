# 월 AI 요약 한도 (#462)

## #463 사용 기록과 링크의 AI 요약 월 한도

2026-11-22, `dbfafc4`에서 시작해 링크 저장 경로와 요약 worker를 `7d04e24`에서 갱신했습니다.

- 한국 시간 달력 월 기준으로 게스트 20건, 로그인 30건을 셉니다. 한도에 도달해도 링크 저장은 성공하고 새 요약 작업은 `skipped`·`monthly_limit_exceeded`가 됩니다. 판정 시각과 사용 기록은 저장 트랜잭션에 남기고, 최종 실패·건너뜀은 작업 상태 갱신과 함께 기록을 지웁니다.
- X4·X5는 2026-11-22 사용자 결정 “감독 추천대로 승인 (추천)”에 따라 실제 PostgreSQL과 HTTP 요청을 유지하고 테스트에서 기존 이벤트 저장 호출을 감쌌습니다. X4는 월 한도 판정 뒤 커밋 전의 서로 다른 키 요청 두 개가 겹쳐 기록 31건을 확인했습니다. X5는 같은 키의 두 번째 요청이 실제 제출 잠금을 기다린 뒤 저장 1건과 기록 30건을 확인했습니다. 두 경우 모두 저장 중 외부 호출은 0회였습니다.
- W7은 같은 날 사용자 결정 “감독 추천대로 승인 (추천)”에 따라 해당 테스트에서만 지난달·이번 달 작업의 예약 시각을 각 합성 시각에 맞췄습니다. 이번 달에 지난달 작업이 실패했을 때 지난달 기록만 빠지는지 확인했습니다.
- 검수에서 같은 한국 시간 월의 다른 날에도 게스트의 21번째 요청이 한도 사유로 건너뛰는 검사를 추가했습니다. 허용 표에 따라 기존 테스트 두 개의 이름을 유지했습니다. 사진은 글자 읽기 전에 판정하고 콘텐츠 생성 뒤 기록해야 하므로 판정 시각을 넘기는 두 단계를 유지했습니다. 월 한도 로그의 `kind`에는 기존 worker 로그와 같은 유튜브·인스타그램 작업 종류를 씁니다.

### 검증

- W7 단독 검사 1개와 첫 PostgreSQL 부분 검사 묶음 472개가 통과했습니다. 검수 반영 뒤 관련 PostgreSQL 검사 29개가 통과했습니다. 세 실행 모두 대상 skip 0개였습니다.
- 검수 반영 뒤 전체 로컬 검사에서 일반·maintenance PostgreSQL DB의 `alembic upgrade head`와 `alembic check`가 각각 통과했습니다. Flutter 테스트는 3,967개 통과했습니다.

```text
pytest: 3046 passed, 50 skipped, 3 warnings in 391.07s (0:06:31)
pytest skip: 49 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=12 failed=0
```

로컬 원본은 `.utmp/ticket-463/20261122T213225-07c9c40caa46/`에 보관했습니다. Docker 배포·복구와 S3 CLI는 위 조건으로 건너뛰었습니다. 원격 CI는 PR 단계이며 운영과 실제 AI 호출은 이 작업의 검증 범위 밖입니다.
