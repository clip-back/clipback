# 격리 복원 검증의 계정 탈퇴 판정 (#252)

2026-11-06, 시작 커밋 `fd527847b45c17a9c7ede623e60a4a48292d8204` 기준으로 구현하고 티켓 리뷰 반영과 전체 검증까지 마쳤다.
회원 탈퇴 스펙 #250의 두 번째 티켓이다. 앱 요청 경로(#253)·운영자 명령(#255)은 이 기록에 없고, 이 기록은 배포·운영 확인
완료를 뜻하지 않는다. 결정 근거는 [ADR 0004](../adr/0004-recovery-point-manifest-single-standard.md)·
[ADR 0008](../adr/0008-account-deletion-ledger-record.md)이고 앞 티켓은 [#251 기록](2026-11-06-account-deletion-ledger.md)이다.

## 구현

- 격리 복원 probe `backend/scripts/recovery_probe.py`(옛 API 이미지 안에서 도는 소스, 새 모듈 import 없음):
  - 반영 전 실행에서 탈퇴 기록과 계정 번호·생성 시각이 둘 다 맞는 계정을 찾아 `matching_accounts`로 돌려준다.
    입력에 탈퇴 기록 목록이 없으면 출력은 이전과 같다.
  - 반영 뒤 실행에서 그 계정의 `users` 행과 `users`를 외래키로 참조하는 모든 표의 행을 직접 세어 하나라도 있으면 실패한다.
    표 목록은 `pg_constraint`에서 찾으므로 옛 스키마에 없는 표는 빠진다. FK가 없는 정리 작업 행(`image_deletions`)은 대상이 아니다.
  - 토큰 계정이 지운 계정이면 `users/me`와 삭제 목록의 콘텐츠·원본·access descriptor 경로가 모두 401이어야 통과하고
    200이면 실패한다. 이때 표본 선택과 원본 GET은 하지 않는다. 지워지지 않은 토큰은 기존 확인(인증·원본 열람·삭제 경로 404)을 그대로 한다.
- 호스트 `backend/scripts/check_backup_restore.py`:
  - 반영 전 probe에 장부의 탈퇴 기록(계정 번호·생성 시각)을 넘기고, 일치한 계정이 있으면 반영 뒤 probe에 지운 계정과 토큰 계정 판정을 넘긴다.
  - 토큰 계정은 자격의 `secret_key`로 서명을 확인하고 API의 `decode_access_token`과 같은 claim 규칙(`type`, `sub`·`sid`·`exp` 필수,
    양수 번호, 유효 만료값)을 통과한 토큰의 `sub`다. 통과하지 못하면 지운 계정 토큰으로 보지 않아 기존처럼 인증 실패가 된다.
  - 결과에 `deleted_account_count`, `token_account_deleted`를 더했다. 반영 전 manifest 사전 일치 검사와 기존 필드는 그대로다.
- 반영 소스 `scripts/recovery_deletions.py`와 그 출력은 바꾸지 않았다.
- CI operator-recovery: main 리비전 `bf654132676aa76a8b8152c6d85bb883ea15cfc9`(#247)의 `backend/`로 그 리비전 라벨의 API 이미지를 빌드하고,
  새 Docker 사례 `tests/deployment/test_legacy_account_deletion_restore_docker.py`를 실행 목록에 더했다.
  사례는 그 이미지에 계정 삭제 모듈이 없음을 확인하고, 옛 이미지로 만든 복구 지점에 현재 반영 소스·probe로 탈퇴 기록을 반영한다
  (지운 토큰 401, 살아 있는 토큰의 원본 열람, 모든 계정 삭제, 계정 행이 남은 원본 DB에서 probe 실패).
  공유 fixture `bucket_backup`에는 이미지를 간접 인자로 받는 연결만 더했다(기본값 그대로).
- 문서: [백업 복원](../backend/backup-recovery.md)의 탈퇴 기록 판정·자격 토큰 안내·Docker 사례 설명,
  [격리 복원 실행](../backend/isolated-restore-execution.md)의 운영자 토큰 안내와 보고서 필드.

## 실제 부분 검사

로그는 `.utmp/ticket-252/` 아래에 있고 첫 줄에 명령이 있다. 서버 테스트는 임시 PostgreSQL DB `clipback_t252`에서
`alembic upgrade head` 뒤 실행했다.

- 시작 커밋에 새 테스트만 얹은 실행 → 11 failed, 37 passed. 탈퇴 기록 입력 없음·probe 함수 없음으로 기대한 실패다(`red-probe.log`).
- 구현 뒤 `tests/deployment/test_backup_restore.py tests/integration/test_recovery_probe_accounts.py` → **48 passed**(`partial-probe.log`).
- ruff·compileall과 복원·probe·탈퇴·이관·백업·live restore CLI·운영자 CLI·복구 지점·보존 묶음 → **273 passed, 5 skipped**
  (`partial-related.log`). skip 5건은 새 사례를 포함한 Docker 사례로 `RUN_DOCKER_RECOVERY_TESTS`가 없어 건너뛰었다. 앞 실행과 합산하지 않는다.
- 변형 6종(지운 토큰도 404 기대, `users/me` 확인 생략, `users` 표만 셈, 생성 시각 비교 생략, 서명 확인 생략, 지운 토큰인데 표본 유지)이
  모두 실패로 잡혔고 파일은 복사본으로 되돌렸다(`mutation-probe.log`).

## 실패와 수정

- CI run 42180683905: 옛 이미지 빌드 단계가 `failed to read dockerfile`로 실패해 복원 검사가 skipped였다.
  워크플로 작업 폴더 `backend`에서 하위 트리 `REV:backend`를 `git archive`하면 git이 `current working directory is untracked`로 끝나고,
  단계 셸에 pipefail이 없어 빈 폴더로 빌드가 진행된 것이다(`repro-archive.log`). `git -C ..`로 저장소 루트에서 꺼내고 `set -o pipefail`을
  켰다(`5a438dd`). 같은 단계를 Docker 빌드만 빼고 로컬에서 실행해 빌드 컨텍스트 파일과 옛 리비전임을 확인했다(`partial-legacy-archive.log`).
- 그 뒤 CI run 42181109505(head `5a438dd`)의 전체 job이 성공했다. operator-recovery 실제 복원 단계 32 passed·skip 없음,
  deployment 14 passed로 리뷰어가 확인했다(`.utmp/review-252-ci-status.json`, `.utmp/review-252-ci-run.log`).

## 티켓 리뷰

2026-11-06 티켓 리뷰 `.utmp/review-252.md`: Standards 0건, Spec 중간 1건(S1).

- S1: 토큰 계정 판정이 `sub`·`type`만 확인해, `exp`·`sid`가 없거나 `sid`가 null인 서명 토큰의 401도 탈퇴 계정의 401로 인정했다.
  API의 `decode_access_token`은 이 토큰들을 인증 오류로 거부하므로 401의 원인이 계정 삭제가 아니다. 같은 claim 규칙을 호스트 판정에 넣었다(`7534af8`).
  - `5a438dd`에 회귀 사례(claim 누락·null·잘못된 타입·0) 10개를 얹은 실행 → exp·sid 관련 6개 실패(`red-s1-claims.log`).
  - 수정 뒤 `tests/deployment/test_backup_restore.py tests/integration/test_recovery_probe_accounts.py` → **58 passed**(`partial-s1-claims.log`).
  - 토큰을 해석하는 다른 경로는 API의 `decode_access_token`(`app/api/deps.py`, `app/api/v1/endpoints/auth.py`)과
    공유 토큰 `decode_share_write_token`, 소셜 로그인 공급자 토큰 검증뿐이다. 복원 검사 판정은 `token_account` 한 곳이라 함께 고칠 곳이 없다.

## 전체 검증

검증 기준 코드 커밋은 `7534af8efe88f83a29cfa3566d2ffe57ddc226c2`다. 16:46 KST busy 대기 완료 뒤 작업 트리 루트에서
다음 명령을 셸 제한 600초로 한 번 실행했고, 종료 코드 0을 확인했다. 실행 기록의 커밋은 `7534af8`, 작업 트리는 깨끗했다.

```sh
~/.heoturu-agents/busy.sh && python3 ~/.heoturu-agents/verify.py --log-dir .utmp/ticket-252
```

- 서버 ruff·compileall, 일반·maintenance 테스트 DB 각각의 `alembic upgrade head`·`alembic check`, 전체 pytest 통과.
  `backend-pytest.log`의 마지막 요약: `2107 passed, 47 skipped, 3 warnings in 158.15s (0:02:38)`.
- 앱 pub-get·format·analyze·전체 test 통과. `app-test.log`의 마지막 결과: `02:36 +2931: All tests passed!`.
- 결과 원문은 `.utmp/ticket-252/verify-result.txt`, 단계별 원본은 `.utmp/ticket-252/20261106T164607-f17fb47c718f/`다.
  콘솔 마지막 줄(`.utmp/ticket-252/verify-console.log`)과 결과 파일의 VERIFY 줄이 같음을 대조했다.

```text
pytest skip: 46 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=11 failed=0 logs=/Users/leehyeongyu/orca/workspaces/Clipback/account-deletion/.utmp/ticket-252/20261106T164607-f17fb47c718f
```

skip의 전체 사유는 `backend-pytest.log`의 `SKIPPED` 줄에 있다. deployment 46건은 Docker 실행 옵션·라벨된 로컬 이미지가 없는
Docker 검사(#251 때 45건 + 새 옛 이미지 사례 1건)이고, integration 1건은 `CLIPBACK_IMAGE_TEST_S3_ENDPOINT`가 필요한 로컬 합성 CLI 검사다.
이번에 더한 비Docker 테스트(`test_backup_restore.py`의 새 사례, `test_recovery_probe_accounts.py`)는 skip되지 않았다. skip은 통과 수에 넣지 않는다.

이 결과를 기록하는 후속 커밋은 문서만 바꾸며 검증 기준 코드와 같다. 전체 검증은 다시 실행하지 않았다.

## 미검증

- S1 수정(`7534af8`) 뒤의 CI deployment·operator-recovery Docker 작업은 아직 실행되지 않았다. 직전 CI 성공은 `5a438dd` 기준이다.
  이번 수정은 호스트 판정만 바꾸고 Docker 사례의 토큰은 정상 claim이라 결과가 같을 것으로 보지만, CI 결과로 확인해야 한다.
- 잘못된 claim 토큰을 실제 Docker 복원 전체로 돌린 사례는 없다(호스트 판정 단위 테스트로 확인).
- 운영 DB·Bucket·장부, 실제 운영 복구 지점·운영자 토큰, 실계정·실기기는 미검증이다.
- 운영자 복원 검사의 판정만 바뀌고 사용자에게 보이는 변경이 없어 `CHANGELOG.md`에는 적지 않았다.
