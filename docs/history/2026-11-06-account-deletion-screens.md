# 탈퇴 화면 J04·J05·J06과 탈퇴 흐름 (#256)

2026-11-06, 시작 커밋 `fab5b84647fa9a72525b94274d12c77303a99fc4` 기준으로 구현하고 티켓 리뷰 반영과 전체 검증까지 마쳤다.
회원 탈퇴 스펙 #250의 여섯 번째 티켓이다. 204 뒤 검색 기록·저장 대기 공유·Google 연결 해제와 기기 정리 실패의 다음 실행 재시도(R2)는
#257 범위라 이 기록에 없다. 이 기록은 변경 후 화면 촬영·배포·운영 확인 완료를 뜻하지 않는다.
#257 뒤 빌드 전 확인 테스트 수정, 최종 전체 검증과 2026-11-07 양 플랫폼 촬영·비교 결과는 [회원 탈퇴 최종 통합](2026-11-06-account-deletion-final.md)에 있다.
결정 근거는 [ADR 0007](../adr/0007-account-deletion-immediate-and-replayed.md)·[ADR 0008](../adr/0008-account-deletion-ledger-record.md)이고,
앱이 쓰는 데이터 층은 [#253 기록](2026-11-06-account-deletion-request.md)이다.

## 구현

- 계정 관리의 "회원 탈퇴"는 옛 안내 스낵바 대신 탈퇴 화면(J04)을 연다(`frontend/lib/features/account/account_management_screen.dart`).
  계정 작업 중에는 로그아웃 행처럼 막힌다.
- J04·J05(`frontend/lib/features/account/account_deletion_screen.dart`): 헤더 "계정 관리"와 뒤로, 제목, "OOO 님의 …"(이름은 계정 관리 화면의 이름,
  게스트도 같음), 삭제 대상 카드, 사유 4개(복수 선택, 필수 표시), 회원탈퇴 유의사항, "탈퇴하기"·"취소". 사유가 없거나 응답을 기다리는 동안
  "탈퇴하기"는 비활성이다. 사유는 고른 순서와 무관하게 `rejoin`·`low_usage`·`privacy_security`·`other` 순서로 보낸다.
- 삭제 대상 개수(`frontend/lib/data/repositories/user_repository.dart`, `features/account/view_models/account_view_model.dart`): J04를 열 때마다
  기존 `GET /feed?limit=1`의 `total_count`와 기존 `GET /categories`에서 공용 "미분류"(`is_default` 이고 이름이 "미분류")만 뺀 수를 따로 읽는다(U4).
  새 API는 없다. 불러오는 중이거나 실패한 숫자는 자리만 비운다("콘텐츠 개").
- 제출(`frontend/lib/app/app_view_model.dart`의 `deleteAccount`)은 로그아웃과 같은 인증 작업이다. 인증 세대를 올리고 인증 작업 중 표시를 켠 뒤
  공유 세션 변경 차단을 먼저 걸고 #253의 `ClipbackApi.deleteAccount`(60초)를 부른다.
  - 204: `SessionRepository.clearAfterAccountDeletion`이 메모리 세션(원본 이미지 캐시 무효화 포함)·저장 세션·소셜 SDK 상태(Apple 사용자 ID 포함)를
    로그아웃처럼 지우고, 서버 로그아웃 요청은 보내지 않는다. 그 뒤 완료 화면(J06). 저장 세션·SDK 정리가 실패해도 실패 안내 없이 J06이다(R2의 화면 부분).
  - 401: 이미 기존 무효화로 로그인 화면이 되었으므로 그대로 둔다(J06 없음, D29).
  - 그 밖(422·503·5xx·204 아닌 2xx·연결 실패·60초 초과·공유 차단 실패): J04에 머물고 기존 스낵바 "탈퇴하지 못했습니다. 잠시 후 다시 시도해 주세요.",
    고른 사유는 유지된다.
  - 실패 스낵바가 떠 있는 채로 다시 눌러 204가 오면 J06에 이 문구가 남지 않도록 J06 도착 때 앱 스낵바를 지운다(`frontend/lib/app/clipback_app.dart`).
- 대기 중에는 "취소"·헤더 뒤로·시스템 뒤로를 화면과 루트 양쪽에서 막는다. 대기 중이 아니면 J04의 세 동작은 계정 관리로 간다.
- J06(`frontend/lib/features/account/account_deleted_screen.dart`): 일러스트, "탈퇴가 완료되었습니다.", 두 줄 안내, "로그인 화면으로 돌아가기".
  버튼과 시스템 뒤로 모두 로그인 화면이다.
- 글자·간격·아이콘은 2026-11-06 조회한 Figma 노드 값이다(아래 Figma 절). 넘침은 줄바꿈으로 받고 글자 축소·말줄임은 쓰지 않는다(R10).
- 에셋: Figma 원본 바이트 그대로 `frontend/assets/figma/account-deletion-hard-drive.svg`·`account-deletion-dot.svg`·`account-deletion-check.svg`를 더했다.
  J06 일러스트는 기존 `logout-illustration.png`와 SHA-256이 같아(`bd67e886…1a43`) 재사용하고, 뒤로 아이콘은 내용이 같은 기존 `detail-back.svg`를 쓴다.
- 문서: [Figma 맞춤 계획](../figma-ui-alignment-plan.md#figma-pending-15)(디자인 없는 세 상태, 계정·고객지원 행, figma-current-15),
  [앱 동작](../frontend/behavior.md)(로그아웃과 탈퇴 구분), [앱 README](../../frontend/README.md#회원-탈퇴), Android 내부 테스트 출시 스펙,
  백엔드 MVP 계획, [지표 쿼리](../product-metrics-queries.md)(탈퇴로 이벤트가 지워져 누적값이 줄어들 수 있음), `CHANGELOG.md` 미배포 `[앱]` 항목.

## Figma

파일 `svNWsTFh8Ws1Mpt8XQIcrN`의 J02 `111:4533`, J04 `111:5780`, J05 `111:5824`, J06 `111:5756`을 2026-11-06에 조회했다
(디자인 컨텍스트·메타데이터, 에셋은 18:59 KST에 받음). J03 `111:5767`은 메타데이터만 읽었다.

- J04·J05·J06은 현재 노드 값(헤더 19·제목 25·설명 17·카드/사유 15·유의사항 13·버튼 17, 자간·행높이도 노드 값)을 쓴다.
  현재 노드와 기존 코드가 다르다: J02 노드는 헤더 19·이름 21·행 15인데 코드는 18·20·14, J03 노드 제목은 25인데 코드는 24다.
  J02·J03은 이 티켓 범위가 아니라 바꾸지 않았으므로 계정 관리(헤더 18) → J04(헤더 19)로 넘어갈 때 같은 헤더 글자가 1px 커진다.
- 375×812, 배율 1.0에서 J04 위치가 노드와 같음을 테스트로 고정했다: 제목 위 130, 삭제 대상 카드 (16, 240, 343×86), 사유 카드 (16, 330, 343×212),
  유의사항 위 549·높이 86, 두 버튼 위 642·698(높이 48, 아래 32 + OS 여백). 기기 OS 위 여백과 Figma 상태바 50의 차이만큼 아래로 밀리며 보정하지 않는다.
- J06은 이미지 277×277(왼쪽 49)과 문구 묶음의 중심이 본문 중심보다 29.5 위다. 버튼은 안전 영역 바로 위에 둬서, 버튼 아래가 홈 인디케이터에 2px 겹치는
  노드(아래 780)보다 iPhone에서 2px 높다. Android 3버튼 내비에서 버튼이 가려지지 않게 하려는 선택이다.

## 실제 부분 검사

로그는 `.utmp/ticket-256/` 아래에 있고 첫 줄에 명령이 있다. 모두 앱(`frontend/`)에서 실행했다.

- 루트 앱 위젯 테스트 `frontend/test/account_deletion_flow_test.dart`(29개): 스펙 "상태·오류 분류 표 › 앱 J04·J05"·"J06"·"탈퇴 응답 대기 중 다른 일"의
  모든 행을 iOS·Android(첫 테스트는 회원·게스트) 대상으로 고정한다. 대기 전에 시작된 Apple 확인의 "철회됨"은 확인 먼저·탈퇴 먼저 × 204·503·401의
  6개, 60초는 59.999초 미완료·60초 실패·늦은 204가 화면을 바꾸지 않음까지 본다.
- 넘침·Figma 기하 `frontend/test/account_deletion_overflow_test.dart`(12개): 실제 Pretendard로 배율 1.0·1.3 × {이름 80자, 콘텐츠 9999999·카테고리 99999} ×
  {J04, J05}를 각각 따로, J06은 배율별로 시험한다. 줄바꿈으로 안 되는 자리는 없었다.
- 변형 실험: 흐름 10종, 넘침 3종을 넣어 모두 실패로 잡히는 것을 확인했다(처음에 못 잡은 사유 전송 순서·실패 직후 선택 초기화·사용자 스크롤 불가는
  테스트를 보강한 뒤 잡힘). 모든 변형 뒤 파일은 복사본으로 되돌렸다(`mutation-*.log`).
- 실패 스낵바가 J06에 남는 결함은 재현 테스트가 먼저 실패하고(`red-snackbar-on-j06.log`) 고친 뒤 통과했다(`green-snackbar-on-j06.log`).
- 바꾼 부분과 관련된 기존 테스트 43개 파일 + 새 두 파일: format·analyze 뒤 **+1383 All tests passed**(`partial-app.log`).
- 기존 테스트 변경: `account_management_alignment_test.dart`의 옛 안내 스낵바 단언과 그 수명 전용 테스트 6개(rapid·gap100·exit × 플랫폼)를
  "탭하면 탈퇴 화면 콜백, 안내 없음" 2개로 바꿨고(D3·D17), 연타 때 J04가 하나만 열리는 것은 새 루트 테스트가 본다. `top_safe_area_test.dart`는 새 필수 콜백만
  연결했다. 그 밖의 기존 단언은 바꾸지 않았다.

## 티켓 리뷰

2026-11-06 티켓 리뷰 `.utmp/review-256.md`(대상 `fab5b84...3ce6dab`): Standards 낮음 1건, Spec 0건, 문구 참고 2건.

- S1(낮음): 변경 후 촬영 안내(`.utmp/ticket-256-capture-after.md`, 저장소 밖)가 Android에도 iOS의 `--expected-region`을 쓰게 되어 있었다.
  리뷰어는 실제 `tap_label.py`에 위젯 좌표를 넣은 dry-run으로 Android 회원·게스트 둘 다 탭 전에 거부됨을 재현했다(실제 기기 AX 재현은 아님).
  반영: 플랫폼별 영역을 따로 적었다(iOS 회원 `0 0.60 1 0.10`·게스트 `0 0.63 1 0.10`은 그대로, Android 회원 `0 0.53 1 0.06`·게스트 `0 0.575 1 0.06`).
  같은 방식의 dry-run에서 글자 frame과 감싸는 행 frame 모두 각 영역 안에 들어가고, 예전 iOS 영역을 Android에 쓰면 여전히 거부됨을 확인했다.
  이 값은 위젯 좌표에서 만든 후보이며, 실제 AX 노드 확인은 감독 촬영 때 기기 dry-run으로 한다. 제품 코드는 바꾸지 않았다.
- Spec 0건. 리뷰어는 204 뒤 영속 재시도·검색 기록·공유 파일·Google 연결 해제가 #257에서 완성되어야 #250 R2 전체가 끝난다고 짚었다.
- 문구 참고 2건("탈퇴 시 정보 복구가 어려워요.", 숫자 없는 "콘텐츠 개")은 승인된 Figma·D21 문구라 바꾸지 않았다.

## 전체 검증

검증 기준 코드 커밋은 `3ce6dab46e3f8da2414c1d9cbd5ac5a8c8475570`이다(리뷰 S1은 저장소 밖 촬영 안내만 고쳐 코드는 그대로다).
19:30 KST busy 대기 완료 뒤 작업 트리 루트에서 다음 명령을 셸 제한 600초로 한 번 실행했고, 종료 코드 0을 확인했다.
실행 기록(`verify-progress.json`)의 커밋은 `3ce6dab`, 작업 트리는 깨끗했다.

```sh
~/.heoturu-agents/busy.sh && python3 ~/.heoturu-agents/verify.py --log-dir .utmp/ticket-256
```

- 서버 ruff·compileall, 일반·maintenance 테스트 DB 각각의 `alembic upgrade head`·`alembic check`, 전체 pytest 통과.
  `backend-pytest.log`의 마지막 요약: `2207 passed, 47 skipped, 3 warnings in 204.76s (0:03:24)`. 서버를 바꾸지 않아 #255 전체 검증과 같은 수다.
- 앱 pub-get·format·analyze·전체 test 통과. `app-test.log`의 마지막 결과: `02:30 +2984: All tests passed!`.
  #255 때(+2947)보다 37개 많고, 새 흐름 테스트 29개 + 넘침 테스트 12개 − 바꾼 계정 관리 테스트 4개(6개를 2개로)와 같다.
- 결과 원문은 `.utmp/ticket-256/20261106T193059-40a145b4d112/verify-result.txt`, 단계별 원본은 같은 폴더다.
  콘솔 마지막 줄(`.utmp/ticket-256/verify-console.log`)과 결과 파일의 VERIFY 줄이 같음을 대조했다.

```text
pytest skip: 46 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=11 failed=0 logs=/Users/leehyeongyu/orca/workspaces/Clipback/account-deletion/.utmp/ticket-256/20261106T193059-40a145b4d112
```

skip의 전체 사유는 `backend-pytest.log`의 `SKIPPED` 줄에 있다. deployment 46건은 Docker 실행 옵션·라벨된 로컬 이미지가 없는 Docker 검사이고,
integration 1건은 `CLIPBACK_IMAGE_TEST_S3_ENDPOINT`가 필요한 로컬 합성 CLI 검사다. DB 대상 테스트의 skip은 없다. skip은 통과 수에 넣지 않는다.

변경 후 촬영 진입 파일의 빌드 전 확인 테스트(`.utmp/ticket-256/state_preview_after_check_test.dart`, 5개 통과)는 저장소 밖 파일이라
이 전체 검증에 들어 있지 않다. 리뷰 반영 뒤 다시 돌린 결과는 `.utmp/ticket-256/check-after-member-s1.log`(+5 All tests passed)다.

이 결과를 기록하는 후속 커밋은 문서만 바꾸며 검증 기준 코드와 같다. 전체 검증은 다시 실행하지 않았다.

## 미검증

- 변경 후 화면의 시뮬레이터·에뮬레이터 촬영과 변경 전·후·Figma 비교는 하지 않았다(감독 단계). 변경 전 화면은 감독이 8d185f0에서 촬영했다.
  변경 후 촬영 진입 파일과 빌드 전 확인 테스트(5개 통과)는 `.utmp/ticket-256/`에 있다.
- 앱 탈퇴 흐름은 가짜 HTTP 클라이언트와 메모리 저장소로만 확인했다. 실서버·실계정·실기기, Apple·카카오·Google 실제 SDK 정리는 미검증이다.
- CI deployment·operator-recovery Docker 작업은 로컬에서 실행하지 않았다. 이번 변경은 앱만 바꿔 영향이 없을 것으로 보지만 CI 결과로 확인해야 한다.
- 204 뒤 검색 기록·저장 대기 공유 삭제, Google 연결 해제, 기기 정리 실패의 다음 실행 재시도는 #257 범위다.
