# 즐겨찾기 우선 서버 정렬 (#226)

2026-11-03, `feat/feed-total-count`, 시작 `4c3044a481d95ede172d1b827461a0ef970d1120`.
#225의 개수 표시·상태 보호 위에 #226 실제 본문을 구현했다. 구현 커밋은 `3561ebb0fb6373d233cde67f90207672242a02c9`이며,
아래 후속 기록처럼 티켓 검수와 전체 검증까지 완료했다. 화면 확인 미완료. 운영 배포 기록이 아니다.

## 변경

- 서버 `sort=latest|favorites_first`; 기본 최신순의 `v1.`·숫자 커서는 유지한다.
  즐겨찾기 우선은 `f1.`에 즐겨찾기 여부·저장 시각·ID를 담으며 다른 정렬의 커서를 거절한다.
  COUNT 필터는 정렬과 무관하고 마이그레이션·인덱스 추가는 없다.
- 앱의 전체보기·카테고리·미분류는 즐겨찾기 우선일 때 한 커서 목록을 받는다.
  두 단계 상태와 개수 모름 예외를 제거했다. 일반 다음 페이지와 위치 유지 새로고침 양쪽을 변경했다.
- 기존 422 안내·첫 페이지 재시도를 그대로 사용한다. 목록·개수 보존, 재시도 초기화,
  상세 현재 콘텐츠 부재, 옛 서버 무정렬 호환을 외부 요청·표시로 검사했다.
- API 계약·앱 동작·Figma 현재/보류 기준·README·CHANGELOG를 갱신했다.

## 실제 부분 검사

로그는 `.utmp/ticket-226/`이며 첫 줄은 실제 명령, 마지막 줄은 `EXIT_CODE`다.
모든 테스트·분석 전에 busy 대기와 실행 직전 확인을 수행했다. 첫 구현 단계의 부분 검사에서는 전체 verify를 실행하지 않았다.

| 명령 (작업 위치) | 결과 | 로그 |
| --- | --- | --- |
| `bash ../.utmp/ticket-226/server-test.sh` (backend) | 전용 PostgreSQL `clipback_ticket226` 생성, `alembic upgrade head`, API/service/feed 통합 **85 passed**, skip 없음, ruff 통과, exit 0; DB 삭제 | `partial-server-final.log`, 스크립트 `server-test.sh` |
| `flutter test --no-pub test/feed_pagination_test.dart test/data/content_repository_test.dart test/feed_count_test.dart test/view_models/content_view_models_test.dart test/today_root_test.dart` (frontend) | **213 passed**, exit 0 | `partial-app-final.log` |
| `flutter analyze --no-pub && dart format --output=none --set-exit-if-changed lib test` (frontend) | No issues found, 281 files / 0 changed, exit 0 | `partial-analysis-format-final.log` |
| `ruff check` 변경 서버 코드·테스트 7개, `python -m compileall -q` 변경 서버 코드 4개 (backend, `.venv/bin/`) | 통과, exit 0; 정확한 파일 목록은 로그 첫 줄 | `partial-server-static.log` |
| `flutter test --no-pub test/feed_pagination_test.dart --plain-name 'sorted visible refresh commits count atomically' && dart format --output=none --set-exit-if-changed lib test` (frontend) | 제목도 교체되는지 보강한 **2 passed**, 281 files / 0 changed, exit 0; 앞의 213과 중복이므로 합산하지 않음 | `partial-refresh-final.log` |

검사 대상은 서버 정렬·정렬별 커서·필터/COUNT·옛 앱 호환, 앱 API/저장소/화면의 요청·총개수·실패/늦은 응답·422 복구와 오늘의 콘텐츠 회귀를 포함한다.
실제 Pretendard의 네 자리/모름 문구는 입력·배율(1.0/1.15/1.3)·화면별 독립 테스트로 확인했다.
넘침 예외·말줄임·정렬 버튼과의 간격 검사 통과이며 기기 화면 확인을 뜻하지 않는다.

## 실패에서 수정한 내용

- `partial-red-server.log`: 새 PostgreSQL 정렬 테스트에서 혼합 즐겨찾기 3건 실패를 확인한 뒤 서버 구현.
- `partial-red-app.log`: 미분류 요청의 `sort` 단언 실패를 확인한 뒤 앱 전환.
- `partial-app.log`: 기존 즐겨찾기 우선 모름 기대값, 가짜 짧은 페이지의 옛 커서 조건 두 실패를 새 계약으로 수정.
- `partial-app-v2.log`: 새 테스트가 아카이브에서 HomeScreen 전용 이동 도우미를 호출해 실패했다.
  화면의 실제 탭 콜백으로 이동하도록 수정했다. 제품 결함으로 보고하지 않는다.
- `partial-analysis-format.log`: 새 테스트의 if 중괄호 lint 1건 수정. 동작 변경 없음.

## 남은 확인

티켓 검수와 전체 verify는 아래 기록처럼 완료했다. 최종 리뷰 및 감독의 화면 확인은 남아 있다.
화면 확인 미완료: iOS/Android 촬영은 최종 리뷰 뒤 감독이 지정한 목록만 확인한다.
시뮬레이터·에뮬레이터·실기기·Docker는 실행하지 않았다. 서버 CI operator-recovery, 실제 배포된 옛 앱,
운영 API·실기기·계정 규모 성능은 미검증이다. API/위젯/로컬 PostgreSQL 결과로 대신하지 않는다.


## 티켓 검수 후 전체 검증 (2026-11-03)

`.utmp/review-226.md`를 직접 확인했다. Standards 높음/중간/낮음 0/0/0,
Spec 0/0/0으로 반영할 확정 지적이 없다. 새 리팩터링이나 검수 재현 테스트 복사는 하지 않았다.
검수자의 직접 경계 검사와 이번 작업자의 전체 검증은 별개의 실행이다.

- 검증 코드 SHA: `3561ebb0fb6373d233cde67f90207672242a02c9`.
- 22:28 KST busy 대기 완료 및 실행 직전 확인 후 작업트리에서 한 번 실행, 22:34 KST 종료 코드 0.
  `python3 /Users/leehyeongyu/.heoturu-agents/verify.py --log-dir .utmp/ticket-226`를
  Python subprocess의 600초 timeout으로 감싸 실행했다. 사본·저장소 내부 basetemp는 사용하지 않았다.
  긴 검사는 30초 간격으로 기다렸으며 재집계를 위한 재실행은 없다.
- ruff·compileall, 테스트/유지보수 DB 각각의 `alembic upgrade head`·`alembic check` 통과.
- 서버 pytest 원문: `2047 passed, 46 skipped, 3 warnings in 171.27s (0:02:51)`.
- 앱 `flutter pub get --enforce-lockfile`, `flutter analyze --no-pub`, `flutter test --no-pub` 통과.
  앱 테스트 마지막 집계: `02:03 +2187: All tests passed!`.
- 원본: `.utmp/ticket-226/verify-result.txt`, `backend-{ruff,compileall,pytest}.log`,
  `backend-alembic-*.log`, `app-{pub-get,analyze,test}.log`. 기존 `partial-*.log`는 보존했다.

`verify-result.txt`의 skip 및 마지막 VERIFY 원문:

```text
pytest skip: 45 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=10 failed=0 logs=/Users/leehyeongyu/orca/workspaces/Clipback/feed-total-count/.utmp/ticket-226
```

위 skip 요약은 verify가 출력한 축약 원문이다. 개별 `SKIPPED` 사유 전체는 `backend-pytest.log`에 보존했다.
Docker deployment/operator-recovery 및 S3 합성 CLI 미실행을 성공으로 세지 않는다.
화면 확인 미완료이며 운영·실기기·원격 CI 미검증도 그대로 남는다.
이번 후속 커밋은 이력 문서만 갱신하므로 검증 코드와 제품 코드·테스트가 동일하고 전체 검사를 반복하지 않는다.
최종 리뷰 반영 뒤 검증은 `.utmp/ticket-226/final`로 분리한다.
