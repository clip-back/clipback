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

## #464 사진의 AI 요약 월 한도

2026-11-23, `d3c450d`를 기준으로 사진 저장에 링크와 같은 월 한도를 적용했습니다. 기존 사용자 행 잠금을 얻고 원본 보관 한도를 확인한 뒤 글자 읽기 전에 판정합니다. 글자 읽기에 성공하면 판정 시각으로 저장 트랜잭션에 건수를 기록합니다. 한도에 도달하면 원본과 직접 고른 카테고리·태그를 저장하고 응답에 `skipped`·`monthly_limit_exceeded`를 반환합니다.

- PostgreSQL에서 사진 두 건이 서로 다른 제출 키와 같은 제출 키로 겹칠 때 각각 기록 30건, 사진과 링크가 겹칠 때 기록 31건을 확인했습니다. 글자 읽기 도중 한국 시간으로 다음 달이 되어도 지난달에 기록되고, 응답 유실 후 같은 키로 재확인하면 새 호출이나 기록 없이 원본이 보존됩니다.
- 기존 링크 한도 검사 1건의 대역은 글자 읽기 성공을 반환해 사진이 한도를 사용했습니다. 시작점에서 해당 검사 1건이 통과함을 확인했고 사용자 승인에 따라 그 사진 요청에만 글자 읽기 미설정을 적용했습니다. 기존 이름·기대값·단언과 공용 대역을 유지했고, 단독 검사 1건과 관련 검사 455건이 통과했습니다.
- 검수에서 태그 변경 요청의 응답과 같은 키로 다시 저장할 때 반환하는 현재 콘텐츠에 한도 사유가 이어지는지 확인했습니다. 사진 준비 서비스와 콘텐츠 저장소의 기존 호출 규약을 유지했습니다. 이어지는 PostgreSQL 부분 검사에서 20건이 통과했고 실패·skip은 0건이었습니다.

### 검증

일반·maintenance PostgreSQL의 `alembic upgrade head`와 `alembic check`가 통과했습니다. 같은 DB에서 사진 사유 마이그레이션을 내린 뒤 사용 기록 마이그레이션을 이어서 내리는 통합 테스트도 통과했습니다. Flutter 테스트는 3,967건이 통과했고 이 티켓 대상 skip은 0건입니다.

```text
pytest: 3062 passed, 50 skipped, 3 warnings in 414.98s (0:06:54)
pytest skip: 49 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=12 failed=0
```

이번 실행의 로그와 결과는 `.utmp/ticket-464/20261123T023953-dcf8cc8d6ed6/`에 보관했습니다. 위 skip은 PR 단계의 CI에서 대조합니다.

## #465 카테고리 추천 하루 상한

추천 공급자를 호출하기 직전에 시도 1회를 저장과 별도 트랜잭션으로 확정합니다. 한국 시간 기준 하루 상한은 로그인 200회, 게스트 50회입니다. 직접 고른 카테고리나 추천 입력이 없는 경우에는 호출도 집계도 하지 않습니다. 호출 뒤 저장이 실패하면 추천 기록은 남고, 저장이 끝난 제출 키의 재요청은 추천을 다시 호출하지 않습니다.

검수에서 저장 요청이 보유한 연결 풀에서 다시 연결을 기다리는 상황을 확인해 추천 기록 전용 풀을 분리했습니다. 전용 연결의 끊김 확인과 기록 트랜잭션의 잠금 대기 제한을 추가했습니다. 로컬 검사로 다른 계정의 추천과 기록, 끊긴 연결에서의 복구, 앱 종료 시 풀 정리를 확인했습니다.

### 검증

전체 검사 1회 실패, 단독·비교 44회와 재실행 통과, 원인 미확정. 첫 전체 검사에서는 동시 저장 테스트에서 추천 기록용 연결을 얻지 못한 3건이 미분류로 저장됐습니다. 대상 테스트는 시작점과 반영분에서 각각 단독 20회와 전체 pytest 안 2회씩 통과했습니다. 진단의 전체 pytest에는 Flutter와 maintenance DB 검증이 포함되지 않았습니다.

첫 실패 로그는 `.utmp/ticket-465-retry/first-failure/backend-pytest.log`에 보존했습니다. 제품 변경 없이 일반·maintenance DB와 Flutter를 포함한 전체 검사를 한 번 재실행했습니다. Flutter 3,967건 통과, 종료 코드 0입니다.

```text
pytest: 3102 passed, 50 skipped, 3 warnings in 388.27s (0:06:28)
pytest skip: 49 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=12 failed=0
```

재실행 로그는 `.utmp/ticket-465-retry/verify/20261123T134429-50ce613db4d9/`에 보관했습니다. Docker 배포·복구와 S3 CLI의 로컬 skip은 PR 단계의 원격 CI와 대조합니다.

## #466 상세 화면의 AI 요약 한도 문구

앱이 서버의 `summary_error_code`를 상세까지 전달합니다. `skipped`이면서 사유가 `monthly_limit_exceeded`인 링크와 사진은 요약 자리에 저장 글 대신 “이번 달 AI 요약을 모두 써서 요약하지 않았어요. 다음 달 1일부터 다시 요약해요.”를 같은 글자 모양으로 보입니다. 사유가 없거나 모르는 값, 문자열이 아닌 값은 무시하고 지금처럼 저장 글을 보입니다. 홈·아카이브 카드, 저장 직후 화면, 공유 저장 시트는 바꾸지 않았습니다.

Figma는 2026-11-23 13:58 KST에 조회했습니다. F02 `111:3842`는 기본 상태, F04 `111:3909`는 연관 콘텐츠 없음 상태이고 둘 다 링크 형태이며, 조회한 섹션에 사진 상세 전용 원본은 없습니다. 사용자 결정에 따라 링크·사진 모두 F02 요약 영역(`111:3861`·`111:3862`)과 비교합니다. 사진은 글자 모양만 대조하고, 사진 상세 전체 레이아웃은 Figma 미검증입니다.

### 검증

검수에서 상세 응답을 적용하지 않거나 쓰기를 늦춰도 기존 데이터 경로 테스트가 통과하는 점을 확인해 테스트를 보강했습니다. 피드와 상세 응답을 구분해 처음 상세와 다시 읽기의 반영을 확인하고, 카테고리·즐겨찾기는 쓰기 중 상태와 바뀐 값, 문구를 함께 확인합니다. 제품 코드는 이 보강에서 바꾸지 않았습니다.

변형 8종(사유 전달 4곳, 상세 응답 실패, 다시 읽기 미반영, 카테고리·즐겨찾기 쓰기 지연)이 모두 의도한 단언에서 실패했고, 변형마다 원복과 정상 대조를 확인했습니다.

전체 검사는 `26728af`에서 통과했고 Flutter는 3994건 통과입니다.

```text
pytest: 3102 passed, 50 skipped, 3 warnings in 425.85s (0:07:05)
pytest skip: 49 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=12 failed=0
```

이번 실행의 로그는 `.utmp/ticket-466/20261123T143419-6bbca47ead2d/`에 보관했습니다. Docker 배포·복구와 S3 CLI의 로컬 skip은 PR 단계의 원격 CI와 대조합니다.

### 기기 화면 확인

iPhone 16 Simulator(iOS 18.6)와 Medium_Phone Emulator(Android 16, API 36)에서 링크·사진 상세를 각각 1.0배와 1.3배로 열었습니다. 변경 전에는 `e2b93ea`의 상세 화면 파일을 사용했습니다. 동일한 콘텐츠와 맨 위 스크롤 위치에서 저장 글이 월 한도 문구로 바뀌고 두 배율에서 문장 끝까지 표시되는 것을 확인했습니다.

플랫폼별 변경 전·후 원본 8장과 probe JSON은 `.utmp/ticket-466/screens/`에, F02와 나란히 놓은 비교 이미지는 `.utmp/ticket-466/compare-ios.png`와 `.utmp/ticket-466/compare-android.png`에 보관했습니다. F02 요약 영역(111:3861·111:3862)을 기준으로 삼았고 사진은 글자 모양만 대조했습니다. 사진 상세 전체 레이아웃은 Figma 미검증입니다. 2026-11-23 사용자가 양 플랫폼 비교 화면을 승인했습니다. 낱말 중간 줄바꿈은 기존 한글 줄바꿈 문제(팀 시트 85)와 같은 종류로 보이며 이번 범위 밖입니다. 실기기 문구 확인과 VoiceOver·TalkBack 실제 낭독은 배포 전 사용자 단계입니다.

## #467 배포 전환과 되돌리기

2026-11-23, 리비전 `202611230026`에 한국 시간 기준 이번 달 AI 요약 사용 기록을 채우는 SQL을 추가했습니다. Alembic과 배포 후 재집계가 같은 파일을 실행합니다. 새 기록은 콘텐츠 저장 시각을 쓰고, 옛 worker가 끝내 실패하거나 건너뛴 링크의 요약 기록을 정리합니다. [Railway 배포 전환 절차](../railway-deployment.md#월-ai-요약-한도-전환)

로컬 PostgreSQL 17.7에서 사진 저장 이벤트의 압축 JSON이 `ocr_status=success`로 해석되는 것을 확인했습니다. 옛 서버 기준 `dbfafc4`의 pre-deploy는 새 DB 리비전 `202611220025`에서 중단됐습니다. 콘솔 되돌리기와 Alembic downgrade는 같은 스키마와 콘텐츠·작업 행을 남겼고, 되돌린 DB에서 옛 서버의 pre-deploy와 목록·링크·사진 상세 응답을 확인했습니다.

검수 뒤 pre-deploy 교착 재배포 조건과 되돌리기 SQL의 재시도 절차를 배포 문서와 GitHub 절차 댓글에 반영했습니다. 두 세션으로 잠금 시간 초과와 재시도를 확인했습니다. 롤백 동등성 테스트가 인덱스·제약·콘텐츠·작업 값의 변형을 각각 잡았고, KST 월초와 다음 달 경계에서 사전 집계·채우기·배포 문서의 집계 결과를 대조했습니다. 관련 부분 검사 6건이 통과했습니다.

### 검증

첫 구현 `e06f78d`에 검수 반영을 더한 작업 트리에서 일반·maintenance 로컬 DB의 Alembic upgrade/check와 전체 검사를 통과했습니다. Flutter는 3994건 통과입니다.

```text
pytest: 3106 passed, 50 skipped, 3 warnings in 408.45s (0:06:48)
pytest skip: 49 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=12 failed=0
```

로그는 `.utmp/ticket-467/20261123T162559-3f9b6039a62b/`에 보관했습니다. Docker 배포·복구와 S3 CLI skip은 PR 단계의 원격 CI와 대조합니다. 배포 후 재집계·운영 한도·실기기 낭독 확인은 배포 뒤 사용자 단계입니다. [#467 절차 댓글](https://github.com/clip-back/clipback/issues/467#issuecomment-7094087770)

### 운영 읽기 집계(사용자 실행)

사용자가 운영 읽기 집계를 실행했고 해석 불가 메타데이터는 없었습니다. 집계값은 비공개이며 독립 대조는 하지 않았습니다.
