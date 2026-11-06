# 탈퇴 때 Apple 토큰 철회·카카오 연결 끊기 (#254)

2026-11-06, 시작 커밋 `76e5bb64e235367ae7410f3894b616da48bcb20d` 기준으로 구현하고 티켓 리뷰 반영과 전체 검증까지 마쳤다.
회원 탈퇴 스펙 #250의 네 번째 티켓이다. 운영자 명령(#255)·탈퇴 화면(#256)은 이 기록에 없고, 이 기록은 배포·운영 확인 완료를 뜻하지 않는다.
결정 근거는 [ADR 0007](../adr/0007-account-deletion-immediate-and-replayed.md)·[ADR 0008](../adr/0008-account-deletion-ledger-record.md)이고
앞 티켓은 [#253 기록](2026-11-06-account-deletion-request.md)이다.

## 구현

- 처리(`backend/app/services/account_deletion_service.py`의 `delete_account`): 계정 단위 잠금 → 공급자 연결 정리(`revoke_provider_links`) →
  #251의 장부 기록 → DB 삭제와 사유 기록 → 커밋 뒤 원본 정리.
  - Apple: 저장된 refresh token을 복호화해 `POST https://appleid.apple.com/auth/revoke`(`token_type_hint=refresh_token`, 기존 client_secret 생성 재사용).
    토큰이 비어 있으면 철회하지 않는다.
  - 카카오: `KAKAO_ADMIN_KEY`로 `POST https://kapi.kakao.com/v1/user/unlink`(`target_id_type=user_id`, `target_id`=카카오 회원번호).
    키가 없거나 비면(개발·테스트) 로그 없이 건너뛴다.
  - Google·네이버 연결은 서버가 철회하지 않는다.
  - 실패(시간 초과 `timeout`, 공급자 오류·연결 실패·200 아님 `provider_error`, Apple 설정·암호화 키 없음 `not_configured`, 복호화 실패 `token_unreadable`)는
    경고 로그 `Provider revocation failed: provider=… reason=… operation_id=…` 한 줄만 남기고 삭제를 이어 간다.
    작업 ID는 장부와 같은 식(계정 번호·생성 시각)으로 미리 계산한다. 토큰·어드민 키·계정 번호·이메일은 로그에 없다.
  - 철회 뒤 DB 삭제가 실패해도 철회를 되돌리지 않는다(D30).
- 클라이언트(`backend/app/integrations/social_auth_client.py`): `revoke_apple_token`, `unlink_kakao`.
- 설정(`backend/app/core/config.py`): `KAKAO_ADMIN_KEY`. 운영에서 없거나 비면 시작 실패(검사는 설정 검사 맨 끝), 개발·테스트는 선택.
- 운영 모드로 API를 띄우는 검사 환경(`backend/scripts/check_deployment.py`, `backend/scripts/check_backup_restore.py`,
  `backend/tests/deployment/test_backup_restore_docker.py`)과 운영 설정 성공 테스트 2개에 가짜 키를 더했다.
  장부 초기화 Docker 검사의 `init`·`checkpoint`는 장부 설정만 읽어 바꾸지 않았다.
- 문서: [API 계약의 회원 탈퇴](../backend/api-contracts.md#회원-탈퇴)·소셜 설정 절, [Railway 배포](../railway-deployment.md#variables)
  (`KAKAO_ADMIN_KEY` 행, 배포 전 Railway 등록), `backend/.env.example`, [서버 README](../../backend/README.md#회원-탈퇴), `CHANGELOG.md` 미배포 `[서버]` 항목.

## 실제 부분 검사

로그는 `.utmp/ticket-254/` 아래에 있고 첫 줄에 명령이 있다. 서버 테스트는 임시 PostgreSQL DB `clipback_t254`에서
`alembic upgrade head` 뒤 실행했다. 공급자는 가짜 HTTP 전송(`httpx.MockTransport`)과 합성 키만 썼다.

- 시작 커밋에 새 공급자·설정 테스트를 얹은 실행 → 6 failed, 20 errors(`red-server.log`).
- 첫 커밋 `8cf3edb`: ruff·compileall과 공급자·설정·#253 API·#251 계정 삭제·Apple 로그인·인증 흐름·소셜/Apple 클라이언트·복원 검사 단위·
  운영자 CLI 단위·복원 probe 계정 테스트 → **254 passed**, skip 없음(`partial-server.log`).
- 변형 7종(철회를 DB 삭제 뒤로, 로그에 계정 번호, 실패 시 중단, 카카오 `target_id_type`, 키 없이 끊기 시도, 200 아님을 성공으로, 빈 Apple 토큰도 시도)이
  모두 실패로 잡혔다. 마지막 변형은 처음에 통과해 빈 토큰 테스트에 "실패 로그 없음" 단언을 더했다(`mutation-server.log`).
- 공급자 테스트는 `backend/tests/integration/test_account_deletion_providers.py`에 있다.

## 티켓 리뷰

2026-11-06 티켓 리뷰 `.utmp/review-254.md`: Standards 0건, Spec 중간 1건.

- 지적 S1: 첫 커밋은 계정·자격을 잠금 없이 읽어 공급자 철회를 먼저 보내고, 그 뒤에 장부 잠금·계정 행 잠금을 얻었다.
  같은 계정의 요청이 겹치면 앞 요청이 끝나기 전에 뒤 요청도 철회를 보낸다. #250 「계정 삭제 모듈」의 "같은 계정의 탈퇴 요청이 겹치면
  계정 행 잠금으로 순서를 세운다. 뒤 요청은 잠금을 얻은 뒤 계정을 다시 확인한다"와 다르다. Apple·카카오 모두 같은 루프라 함께 해당한다.
- 판단: 동의. 다만 철회 전에 계정 행을 `FOR UPDATE`로 잠그면 운영자 재시도(`retry_image_deletions`: 장부 잠금 → `apply_account_deletion`의
  계정 행 잠금)와 순서가 반대가 되어, 장부 기록이 남은 같은 계정을 재시도가 동시에 처리할 때 교착이 생긴다. 그래서 잠금 방식을 물었다.
- 사용자 결정(2026-11-06, 원문 "추천대로 해줘", 승인한 문구):
  > DB 줄 대신 계정 단위 잠금(PostgreSQL advisory lock)으로 같은 계정의 탈퇴만 줄 세운다. 그 뒤 기존 순서(장부 → 계정)대로 잠근다.
  > 이미 있는 재시도 작업은 그대로, 외부 통신 동안 다른 계정의 삭제는 막히지 않는다. 스펙 문구 계정 행 잠금을 계정 단위 잠금으로 넓힌다.
- 반영(`4519e51`): `delete_account`가 트랜잭션 맨 앞에서 `pg_advisory_xact_lock(74264006, 계정 번호)`(두 키 형식)를 잡는다.
  계정 확인·공급자 정리·장부 잠금·계정 행 잠금은 모두 그 뒤다. 기존 장부 잠금 `74264002`(한 키 형식)와 키 공간이 다르다.
- 잠금 순서 대조: 계정 단위 잠금은 `delete_account`만 잡고 항상 맨 처음 잡는다. 장부 잠금을 쓰는 다른 곳(이미지 삭제: 장부 → 콘텐츠 행,
  운영자 재시도: 장부 → 계정 행·콘텐츠 행, 이미지 이관: 장부 → 콘텐츠 행, 백업·복원 실행·백업 작업: 장부 공유 잠금)과
  계정 행을 잠그는 곳(로그인·갱신·Apple 갱신·업로드 정책·카테고리)은 계정 단위 잠금을 기다리지 않으므로 새 순환이 없다.
  복원의 삭제 반영(`scripts/recovery_deletions.py`)은 API 시작 전 격리 환경에서 돌아 바꾸지 않았다.
- 회귀 테스트(실제 커밋되는 PostgreSQL 세션, 공급자 응답을 이벤트로 멈춤):
  - 앞 요청이 공급자 요청 중일 때 뒤 요청이 계정 잠금에서 기다리고 공급자 요청은 1건뿐 → 앞 204, 뒤 401, 공급자 요청 총 1건(Apple·카카오 각각).
  - 앞 요청이 장부 기록에서 실패(503) → 뒤 요청은 앞 요청이 끝난 뒤에야 공급자 요청을 보내고 새로 처리(204).
    앞 요청이 DB 삭제에서 실패(500) → 뒤 요청이 같은 장부 기록을 재사용(204).
  - 한 계정의 공급자 요청이 멈춰 있는 동안 다른 계정의 탈퇴가 204로 끝난다.
  - 장부 기록이 남은 같은 계정에서 운영자 재시도와 탈퇴를 동시에 실행: 탈퇴가 공급자 요청 중이면 재시도가 먼저 계정을 지우고 탈퇴는 401,
    탈퇴가 DB 삭제 단계면 재시도가 장부 잠금을 기다렸다가 지울 계정 0개로 끝난다. 두 경우 모두 교착 없이 끝난다.
  - #253 겹침 3테스트는 helper `overlap()`의 잠금 관측 수만 바꿨다(앞 요청 보유 1 → 2: 계정 단위 잠금 + 장부 잠금, 뒤 요청이 기다리는 잠금이 계정 단위 잠금).
    응답·장부·사유 단언은 그대로다.
- 수정 전 코드 + 새 회귀 테스트 → 5 failed, 2 errors(`red-s1.log`; errors는 당시 fixture 정리 순서 문제로, 뒤에 고침). 변형 3종(계정 잠금을 철회 뒤로, 계정 행 `FOR UPDATE`로 대체, 전역 장부 잠금을 먼저)이
  각각 4·6·5 failed로 잡혔다(`mutation-s1.log`). 계정 행 `FOR UPDATE` 변형에서는 재시도 동시 실행 2사례가 실패했다.
- 수정 뒤 ruff·compileall과 위 부분 검사 범위 + 이미지 삭제 통합 테스트 → **281 passed**, skip 없음(`partial-s1.log`). 실행 뒤 테스트 DB에
  남은 사용자·Apple challenge·사유·삭제 작업 행은 0개였다.

## 전체 검증

검증 기준 코드 커밋은 `4519e51f4febc2207775a82a6d3795fdd6ce9797`이다. 18:03 KST busy 대기 완료 뒤 작업 트리 루트에서
다음 명령을 셸 제한 600초로 한 번 실행했고, 종료 코드 0을 확인했다. 실행 기록의 커밋은 `4519e51`, 작업 트리는 깨끗했다.

```sh
~/.heoturu-agents/busy.sh && python3 ~/.heoturu-agents/verify.py --log-dir .utmp/ticket-254
```

- 서버 ruff·compileall, 일반·maintenance 테스트 DB 각각의 `alembic upgrade head`·`alembic check`, 전체 pytest 통과.
  `backend-pytest.log`의 마지막 요약: `2184 passed, 47 skipped, 3 warnings in 181.06s (0:03:01)`.
- skip 47개: Docker가 필요한 `tests/deployment` 46개(복원·장부 초기화·백업·이관·옛 리비전 탈퇴 복원 등 Docker 이미지 필요)와
  로컬 S3 대역이 필요한 `tests/integration/test_image_storage_admin_cli.py` 1개. 이번 티켓의 공급자·탈퇴 API·설정 테스트는 skip 없이 실행됐다.
- 앱 `flutter pub get --enforce-lockfile`, `dart format`, `flutter analyze --no-pub`, `flutter test --no-pub` 통과(`+2947: All tests passed!`).
- 마지막 줄: `VERIFY result=PASS scope=all checks=11 failed=0`. 로그는 `.utmp/ticket-254/20261106T180322-584d0d34b91d/`.

## 미검증

- CI `backend-validation.yml`의 deployment·operator-recovery Docker job(배포·복원 검사 환경의 `KAKAO_ADMIN_KEY` 가짜 값,
  옛 리비전 이미지 탈퇴 복원 사례 포함)은 로컬에서 실행하지 않았다. push 뒤 CI 결과로 확인한다.
- 실제 Apple·카카오 공급자 철회와 운영 서버는 확인하지 않았다(가짜 HTTP만). 배포 전 Railway `KAKAO_ADMIN_KEY` 등록과
  실계정 확인(#250 D26 (1)–(3))은 사람 작업이다.
