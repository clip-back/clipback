# 회원 탈퇴 최종 통합 (#250)

2026-11-06, 회원 탈퇴 스펙 #250의 일곱 티켓(#251–#257)을 브랜치 `feat/account-deletion`에서 마치고 main을 합친 뒤 최종 통합 리뷰를 반영했다.
main `a6048f98bda7a97680a78a2d1f18d4937b4feb8d` 병합 커밋은 `5a64d98`, 최종 리뷰 반영 코드 커밋은 `3caeb1d`, 그 반영 재리뷰(F1) 코드 커밋은 `509b813`이다.
아래 전체 검증은 `3caeb1d` 기준이며 `509b813`의 전체 검증은 아직 하지 않았다.
각 티켓의 구현·리뷰·검증 근거는 티켓 이력에 그대로 두고 여기에는 통합 단계와 승인 원문만 적는다.
결정 근거는 [ADR 0007](../adr/0007-account-deletion-immediate-and-replayed.md)·[ADR 0008](../adr/0008-account-deletion-ledger-record.md)이다.
이 기록은 iOS Simulator·Android Emulator 실행 확인, 네이티브 XCTest·Android 계측 테스트 실행, 배포·운영·실계정 확인 완료를 뜻하지 않는다.

## 티켓 이력

| 티켓 | 이력 |
| --- | --- |
| #251 | [계정 탈퇴 장부 기록과 계정 재삭제](2026-11-06-account-deletion-ledger.md) |
| #252 | [격리 복원 검증의 계정 탈퇴 판정](2026-11-06-account-deletion-restore-probe.md) |
| #253 | [`DELETE /users/me`와 앱의 탈퇴 요청](2026-11-06-account-deletion-request.md) |
| #254 | [탈퇴 때 Apple 토큰 철회·카카오 연결 끊기](2026-11-06-account-deletion-provider-revocation.md) |
| #255 | [운영자 계정 삭제 명령](2026-11-06-account-deletion-operator-command.md) |
| #256 | [탈퇴 화면 J04·J05·J06과 탈퇴 흐름](2026-11-06-account-deletion-screens.md) |
| #257 | [탈퇴 뒤 기기 정리와 다음 실행 재정리](2026-11-06-account-deletion-device-cleanup.md) |

티켓별 전체 검증은 각 티켓 코드의 결과이며 병합·최종 코드의 결과가 아니다.

## 사용자 결정·승인 원문

1. main 병합 충돌(2026-11-06): 사용자 원문 **"진행해줘"**. 조율 질문 "감독의 양쪽 보존안(main의 공통 빈 화면 그림·별칭·옛 상수 삭제 유지,
   그 아래 탈퇴 그림 상수 4개 추가, main 기준 7줄)으로 합치고 최종 리뷰로 진행할까요?"에 대한 답이다. 실제 병합 커밋 `5a64d98`.
2. 계정 단위 잠금(#254, 2026-11-06): 사용자 원문 **"추천대로 해줘"**, 승인한 설명 원문:
   > DB 줄 대신 계정 단위 잠금(PostgreSQL advisory lock)으로 같은 계정의 탈퇴만 줄 세운다. 그 뒤 기존 순서(장부 → 계정)대로 잠근다.
   > 이미 있는 재시도 작업은 그대로, 외부 통신 동안 다른 계정의 삭제는 막히지 않는다. 스펙 문구 계정 행 잠금을 계정 단위 잠금으로 넓힌다.

   반영과 검증은 [#254 이력](2026-11-06-account-deletion-provider-revocation.md)에 있다.
3. #257 저장된 로그인 소유권 설계 재개(2026-11-06): 사용자 원문 **"A로 진행해줘"**. 승인된 A 원문:
   > 같은 작업자가 먼저 설계 문서를 쓴다. 읽기가 실패하면 아무것도 지우지 않고 실패로 남기는 것을 원칙으로, 옛 정보와 새 로그인을 확실히 가를 근거를 정한다.
   > 저장 형식·Apple ID·기존 사용자 데이터 호환에 영향이 있으면 구현 전에 멈춰 확인받는다. 그다음 자동 루프를 이어 간다. 작업자는 Claude Opus 5.5 · xhigh.

   이에 따라 저장 세션을 읽지 못하면 저장 세션·Apple 사용자 ID를 지우지 않고 재정리 단계로 남긴다. 감독은 배포 전 정리 기록에 완전성 필드를 더하는 것이
   구현 전 확인 경계(세션 저장 형식·Apple ID 소유권 기록·설치된 0.4.0/0.4.1 데이터 호환)를 넘지 않는다고 판정했고, 탈퇴 뒤 SDK 정리가 저장된 Apple 사용자 ID를
   지우던 예외 해석은 원문에 승인이 없어 철회했다. 경위·호환 근거와 검증 경계는 [#257 이력](2026-11-06-account-deletion-device-cleanup.md)에 있다.

## main 병합

- 사전 병합 검사에서 충돌은 `frontend/lib/shared/theme/assets.dart` 하나였다. 위 1번 승인대로 main의 공통 빈 화면 그림·별칭과 옛 상수 삭제를 유지하고
  그 아래 #256 탈퇴 그림 상수 4개를 더했다(main 기준 7줄). 제품 선택이 갈리는 충돌은 없었다.
- main 쪽 #248 UI 정리, #245 공유 전송 상태, #201 전문 보기 제거와 저장 콜백의 `submissionKey`·저장 완료 문구 소비자를 대조했다.

## 최종 통합 리뷰와 반영

리뷰 대상 `a6048f9...5a64d98`(97파일): Standards 0건, Spec 중간 2건. 둘 다 반영했다. 문구 참고 의견(J04 "탈퇴 시 정보 복구가 어려워요.")은
Figma 확정 문구라 바꾸지 않았다.

- P1(코드 `3caeb1d`): Google SDK 초기화가 끝나지 않으면 탈퇴 뒤 Google 연결 해제가 5초에 끝난 다음 소셜 SDK 로컬 정리(`signOutSdks`)가 같은 초기화를
  다시 기다려 J06이 오지 않았다. SDK 로그아웃·카카오 토큰 정리 자체가 끝나지 않을 때도 같았다. 저장된 Google 로그인을 복원한 실행에서는 SDK가 아직
  초기화되지 않아 실제로 생기는 경로다.
  - 반영: 탈퇴 경로는 Google 연결 해제만 최대 5초 기다리고(D6), 그 뒤 SDK 로컬 정리는 한 번 시작만 하고 결과를 기다리지 않는다. 새 대기 시간은 더하지 않았고
    연결 해제 → SDK 로그아웃 시작 순서와 한 번만 하는 원칙은 그대로다. 일반 로그아웃·로그인 동작은 바꾸지 않았다.
  - 회귀(`frontend/test/account_deletion_cleanup_test.dart`, iOS·Android, 실제 `PlatformSocialAuth` + 루트 앱): 초기화 미완료 4.9초에 J06 없음, 5초에 J06·탈퇴 요청 1회,
    나중에 초기화가 끝나면 연결 해제·SDK 로그아웃 각 한 번. Google SDK 로그아웃 미완료·실패, 카카오 토큰 정리 미완료에도 바로 J06.
    수정 전 6개 실패(`.utmp/ticket-250/red-p1-google.log`), 리뷰어 원본 재현 2개 통과, 변형 2종(SDK 정리를 다시 기다림·SDK 정리 생략)이 잡힘.
  - 이 반영의 경계 설명(`99e303c`의 "늦게 끝나는 SDK 정리는 기존 D6의 늦은 연결 해제와 같은 종류")은 틀려 철회했다. 아래 F1처럼 새 로그인 뒤에
    정리가 새로 시작되는 경로가 있었고, D6는 연결 해제를 부르지 않는 경로의 근거가 아니다.
- P2(작업 파일, 제품 코드 변경 없음): #257부터 앱 시작이 정리 대기 기록을 SharedPreferences에서 읽는데, #256 빌드 전 확인 테스트
  (`.utmp/ticket-256/state_preview_after_check_test.dart`)는 `frontend/test/flutter_test_config.dart`가 닿지 않아 저장소 응답을 기다리다 4개가 멈췄다
  (1개 통과, `.utmp/ticket-250/red-capture-p2.log`). 테스트마다 빈 메모리 저장소를 두게 고쳐 5개가 통과했고 #257 확인 테스트 4개도 통과했다
  (`.utmp/ticket-250/check-capture-p2.log`). 변경 전 확인 테스트는 변경 전 코드(`8d185f0`)의 기준 자료라 바꾸지 않았다. 촬영 안내에 같은 내용을 적었다.

### 반영 재리뷰 F1

재리뷰 대상 `5a64d98..99e303c`: Standards 0건, Spec 중간 1건(F1).

- F1: `3caeb1d`로 J06과 새 로그인이 SDK 정리를 기다리지 않게 되자, 게스트(연결 공급자 없음) 탈퇴의 SDK 정리가 Google 초기화를 기다린 다음에야
  카카오 토큰 삭제를 새로 시작해 J06 뒤 카카오로 새로 로그인한 SDK 토큰을 지웠다(리뷰어 재현 양 플랫폼). Clipback 세션·Apple 사용자 ID는 그대로였고
  지워진 것은 새 카카오 SDK 인증 상태다.
- 반영(코드 `509b813`): `PlatformSocialAuth`가 SDK 로그인 시작 횟수를 세고, 탈퇴 정리(Google 연결 해제·SDK 로그아웃·카카오 토큰 정리)는 시작할 때
  그 값을 잡아 SDK 호출 바로 앞에서 새 로그인이 시작됐으면 호출하지 않는다. 공급자 갈래는 동시에 시작해 서로 기다리지 않는다. J06이 정리를 기다리지 않는 것,
  Google 연결 해제 최대 5초, 한 번만 하는 원칙, 일반 로그아웃·로그인 계약은 그대로다.
- 회귀(iOS·Android, 실제 `PlatformSocialAuth` + 루트 앱): 게스트 → 카카오 새 로그인 보존(삭제된 로그인의 카카오 정리는 새 로그인 전에 한 번),
  같은 SDK 초기화를 기다리던 정리는 새 카카오 로그인 뒤 하지 않음, Google 계정이 Google로 다시 로그인하면 시작 전이던 연결 해제·SDK 로그아웃을 하지 않음,
  이미 시작한 카카오 토큰 정리 뒤 새 로그인 보존. 수정 전 6개 실패(`.utmp/ticket-250/red-f1-sdk-race.log`), 변형 4종이 잡힘.
- 이미 시작한 호출: SDK 호출은 취소할 수 없다. 설치된 SDK 소스 기준으로 카카오 토큰 정리는 시작 때 메모리 토큰을 비우고 저장 키 하나를 지워
  새 로그인이 나중에 저장하는 토큰을 남기며, Google SDK 로그아웃은 로컬 호출이다. Google 연결 해제는 네트워크 철회 뒤 로컬 로그아웃을 하므로,
  5초를 넘겨 진행 중일 때 Google로 새 로그인을 마치면 그 로그인의 SDK 상태를 지울 수 있다. 막으려면 새 로그인 대기라는 새 정책이 필요해
  구현하지 않고 결정 대기로 남겼다.

## 전체 검증

검증 기준 코드 커밋은 `3caeb1decb3b40e8b061a8ed0e5f7af01566aee6`이다.
busy 대기 뒤 22:48 KST 작업 트리 루트에서 다음 명령을 셸 제한 600초로 한 번 실행했고 종료 코드 0을 확인했다.
실행 기록(`verify-progress.json`)의 24개 이벤트 모두 커밋 `3caeb1d`, 작업 트리 깨끗함이다.

```sh
~/.heoturu-agents/busy.sh && python3 ~/.heoturu-agents/verify.py --log-dir .utmp/ticket-250
```

- 서버 ruff·compileall, 일반·maintenance 테스트 DB 각각의 `alembic upgrade head`·`alembic check`, 전체 pytest 통과.
  `backend-pytest.log`의 마지막 요약: `2207 passed, 47 skipped, 3 warnings in 204.54s (0:03:24)`.
- 앱 pub-get·format·analyze·전체 test 통과. `app-test.log`의 마지막 결과: `02:43 +3172: All tests passed!`.
- 결과 원문은 `.utmp/ticket-250/20261106T224852-60a342ea0bc4/verify-result.txt`, 단계별 원본은 같은 폴더다.
  콘솔 마지막 줄(`.utmp/ticket-250/verify-console-final.log`), 상위 `verify-result.txt`, 결과 파일의 VERIFY 줄이 같음을 대조했다.

```text
pytest skip: 46 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=11 failed=0 logs=/Users/leehyeongyu/orca/workspaces/Clipback/account-deletion/.utmp/ticket-250/20261106T224852-60a342ea0bc4
```

skip은 Docker 검사 46건과 로컬 합성 S3 CLI 검사 1건이며 통과 수에 넣지 않는다. 빌드 전 확인 테스트(위 P2)는 저장소 밖 파일이라 이 전체 검증에 들어 있지 않다.
이 결과를 기록하는 후속 커밋은 문서만 바꾸며 검증 기준 코드와 같다.

## 미실행과 남은 확인

자동 완료 범위이지만 아직 하지 않은 것(감독 단계):

- iOS Simulator·Android Emulator 실행: #256 변경 후 화면 상태·전환 영상과 변경 전·후·Figma 비교, #257 `cleanup-done`·`cleanup-retry` 실제 프로세스 재시작.
  빌드 전 확인 테스트 통과는 기기 실행이 아니다.
- iOS XCTest(`ShareStoreTests`)와 Android 계측(`ShareStoreTest`)의 계정별 공유 삭제 테스트 실행.
- `509b813`(F1 반영 코드)의 전체 검증. 위 전체 검증은 `3caeb1d`의 결과다.
- `509b813`과 이 문서 커밋의 CI(Docker deployment·operator-recovery 작업 포함). 이전 티켓 CI는 그 티켓 코드의 결과다.

이 기능 범위 밖(사람 확인): 운영 DB·Bucket, 실계정 공급자(Apple·카카오·Google) 확인, 설치된 앱의 실기기 업그레이드, 운영 서버 `KAKAO_ADMIN_KEY` 등록과
서버 먼저 배포·옛 서버 되돌리기 금지 확인. 실제 공유 확장으로 저장 대기 공유를 만들어 지우는 확인은 이슈대로 미검증 예정이다.

## 범위 밖 발견

- 저장 세션을 복원한 실행에서는 Google 연결 해제가 실제로 철회하지 못할 수 있다(코드 판단): Android `disconnect`는 이 실행에서 로그인한 계정만 철회하고,
  iOS도 이전 로그인 복원을 부르지 않아 현재 사용자가 없을 수 있다. 바꾸지 않았다.
- 일반 로그아웃도 소셜 SDK 정리(`signOut`)를 끝까지 기다린다. 코드상 Google SDK 초기화가 끝나지 않으면 같은 대기가 생길 수 있으나 재현하지 않았고
  로그아웃 동작은 이번에 바꾸지 않았다.
- 티켓 이력에 남긴 기존 발견(네이티브 완료 영수증 미삭제, 기존 공유 정리의 파일 삭제 실패 삼킴, 손상된 저장 세션 JSON이면 복원이 "다시 시도" 화면에 머묾)은 그대로다.
