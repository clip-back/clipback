# AI 전송 동의 (#474)

## #475 동의 기록·API와 저장 경로의 AI 차단

2026-11-25, `3e7521a`(#462 병합본)에서 시작해 `7d56f12`·`03be83f`·`e3f77eb`·`2d7943f`로 마쳤습니다.

- 시작 전에 #474의 실측 V1–V17을 병합본에서 다시 재 스펙과 같음을 확인했습니다. V15는 0.7.0(`d39c62b`) 임시 워크트리에서 새 응답의 링크·사진 저장 성공, 피드, 상세 본문까지 확인했습니다.
- 계정마다 동의 기록 한 행(`ai_transfer_consents`, 리비전 `202611250027`)을 두고 `GET /users/me`의 `ai_consent_status`와 `PUT /users/me/ai-consent`를 더했습니다. 리비전의 downgrade는 거부하고, #462 되돌리기 SQL은 이 리비전 뒤에 멈춥니다.
- 저장 경로의 판정 지점 G1a·G1b·G2a·G2b·G3에서 동의·스위치(`AI_CONSENT_REQUIRED`)·재동의 규칙으로 AI 처리를 정합니다. 금지된 저장도 성공하고, 유튜브·인스타그램 게시물·사진은 `skipped`·`ai_consent_required`가 되며 한도에 세지 않습니다.
- 검수에서 재동의 판정을 바꿨습니다. 저장 요청은 첫 판정에서 읽은 커밋된 기록을 기억하고, 재동의는 같은 기록일 때만 허용합니다. 재동의가 쓰였으나 커밋 전인 때와 철회 행 잠금을 기다리는 때에 시작한 저장이 새 동의로 처리되던 틈을 막았습니다. `PUT`은 행 잠금 뒤의 DB 시각을 기록합니다.
- 검수에서 G1b는 자신이 만든 추천 시도 행만 지우도록 고쳤습니다. 앱의 동의 `PUT`은 401 갱신·재전송까지 10초 요청 범위로 묶었고, 손상된 갱신 응답과 달력에 없는 결정 시각을 성공으로 보지 않습니다.
- 사용자 결정 “4파일 허용 (추천)”에 따라 기존 테스트 4파일에서 `/users/me` 응답의 새 필드와 동의 읽기 대역, #462 테스트의 대상 리비전만 바꿨습니다. “실제 동시 재현 추가 (추천)”에 따라 게스트 전환과 동의 변경을 실제 PostgreSQL 별도 세션에서 양순서로 겹쳐 확인했습니다.
- 동시성 검사는 요청마다 PostgreSQL 연결 PID를 기록하고 `pg_blocking_pids`로 어떤 요청이 어떤 요청을 기다리는지 확인합니다. 외부 AI 호출 수는 OpenAI SDK의 가짜 전송에서 셉니다.

### 검증

- 첫 전체 검사는 새 읽기 실패 테스트가 사진 정리 행을 남겨 뒤이은 `test_deletion_ledger_disposal.py` 1개가 실패했습니다. 이 계정의 정리 행만 지우도록 고친 뒤(`2d7943f`) 다시 돌린 전체 로컬 검사가 통과했습니다. 일반·maintenance PostgreSQL DB의 `alembic upgrade head`와 `alembic check`가 통과했고 Flutter 테스트는 4,121개 통과했습니다.

```text
pytest: 3344 passed, 50 skipped, 3 warnings in 454.25s (0:07:34)
pytest skip: 49 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=12 failed=0
```

로컬 원본은 `.utmp/ticket-475/20261125T025949-0f975b4bfbf3/`에 보관했습니다. Docker 배포·복구와 S3 CLI는 위 조건으로 건너뛰었습니다. 원격 CI는 PR 단계이며 운영 서버·운영 스위치·실제 AI 호출·기기 실행은 이 작업의 검증 범위 밖입니다. 서버 작업의 판정(G4·G5)과 철회 때 대기 작업 취소는 #476입니다.
