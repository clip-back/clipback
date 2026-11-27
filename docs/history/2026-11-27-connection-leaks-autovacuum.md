# 서버 테스트의 남은 연결 집계에서 autovacuum 빼기 (#496)

저장 흐름 고정 테스트의 `connection_leaks()`가 정리 후에도 작업 중인 autovacuum worker를 남은 연결로 셌다. 구현 커밋 `b5a5e8f`는 non-idle을 세는 SQL에 `backend_type = 'client backend'`를 추가했다. 고정 기대값, 풀에서 빌린 연결 수, advisory 잠금 집계는 유지했다. 시트 161의 추천 테스트 시간 초과는 별도 진단 범위다.

## 부분 검사

PostgreSQL 17.7을 별도 루프백 포트에 새로 준비했다. 조건 C는 autovacuum 간격 1초, vacuum·analyze threshold와 scale factor 0, cost delay 100ms, cost limit 1이었다. 수정 전후에 같은 클러스터·설정과 실제 테스트 파일을 사용했고, 반복 실행마다 새 시험 DB를 만들었다. 검증 뒤 전용 클러스터를 종료·삭제했다. 아래 로그 경로는 당시 워크트리의 `.utmp/ticket-496/` 기준이다.

| 검사 | 결과 | 로그 |
| --- | --- | --- |
| 수정 전 `1fa6389`에서 `content-after_server_finished` | 지정 실패 10/10. 정리 뒤 `non_idle_backends`만 달랐고, 관측값 1 또는 2는 활성 autovacuum worker 수와 같았다. | `partial-condition-c-red-rerun/run.log` |
| 같은 사례 수정 뒤 | 통과 10/10. 매회 집계 시 활성 autovacuum worker가 관측됐다. | `partial-condition-c-green/run.log` |
| client 누수 변형 | `idle in transaction` 연결 하나를 유지하니 `non_idle_backends`가 0에서 1로 바뀌었다. | `partial-condition-c-client-leak/run.log` |
| 조건 C 나머지 사례 | 롤백 정리, 링크 서버 진행 중, 스크린샷 서버 완료 뒤·진행 중 4건 통과. | `partial-condition-c-remaining/run.log` |
| 일반 로컬 PostgreSQL 전용 DB | 변경한 테스트 파일 전체 162건 통과. | `partial-local-flow/run.log` |

첫 실행은 관측기가 `asyncpg.Record`를 JSON으로 직렬화하다 중단됐다. 고정 단언에 도달하지 못해 집계에서 제외했다. 실제 Record로 관측기 출력을 확인한 뒤 새 클러스터에서 10회를 처음부터 실행했다. 관련 로그는 `partial-condition-c-red/run.log`와 `partial-observer-record-preflight/run.log`에 보존했다.

## 검수와 전체 검사

최종 검수는 Standards 0건, Spec 낮음 1건이었다. 수정 뒤 부분 검사 네 건은 커밋 전 작업 트리에서 실행됐고, 실행 로그에 당시 diff 해시가 없다. 보존된 변형 실험 사본은 검수 이후 저장소 루트에서 아래 명령을 `pipefail` 상태로 실행해 커밋 파일과 바이트가 일치함을 확인했다. 이 종료 코드 0은 사후 대조 결과다.

```sh
git show b5a5e8f:backend/tests/integration/test_content_save_flow_contract.py | cmp -s - .utmp/ticket-496/flow_496_mutation.py
```

실행 직전 fetch 결과 `origin/main`은 `1fa6389`였고 선행 커밋은 없었다. 깨끗한 `b5a5e8f`에서 전체 VERIFY가 종료 코드 0으로 끝났다. 백엔드 pytest는 3,557건 통과·52건 건너뜀, Flutter는 4,444건 통과였다. 아래 결과의 로그 경로는 워크트리 기준이다. 이력 커밋은 이 문서와 목차만 바꾸므로 이 실행을 검증 근거로 삼았다.

```text
pytest skip: 51 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=12 failed=0 logs=.utmp/ticket-496/20261127T231112-86760d0f2844
```

화면 변경이 없어 기기 실행·촬영은 해당 없었다. 원격 CI와 운영 환경은 이 로컬 검사 범위에 포함하지 않았다.
