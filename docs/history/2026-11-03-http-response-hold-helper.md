# HTTP 응답 보류 테스트 도우미 (#223)

기록일: 2026-11-03. 시작 커밋 `b3e9c64`, 구현·검증 기준 커밋 `1bcda36`.
브랜치: `chore/test-response-hold-helper`.

## 변경

요청 수 증가나 로딩 플래그 대신 선택한 MockClient 요청 자체의 도착을 확인하도록
`HttpResponseHold`를 추가했다. fixture는 요청 분기와 응답 데이터를 맡고,
도우미는 요청 하나의 도착 대기와 명시적 응답 해제만 맡는다.
기본 대기 한도는 5초이며 미도착 시 요청 설명이 포함된 `TimeoutException`으로 실패한다.
도착 전·중복 해제와 두 번째 요청 전달은 `StateError`로 거부한다.

`content_view_models_test.dart`의 홈 상단 기억과 전체보기 성공·실패만 전환했다.
요청 도착 → 중간 상태 단언 → 해제 → 최종 결과 단언 순서를 유지하며,
전체보기 성공은 기본 응답과 다른 ID·제목을, 실패는 오류 상태를 확인한다.
다른 후보의 유지 사유와 사용 계약은 [테스트 지원 안내](../../frontend/test/support/README.md)에 있다.

제품 코드·API 계약·화면 변경이 없는 테스트 지원 작업이다.
[배포 규칙](../release-process.md#변경-작성과-pr-리뷰)에 따라 CHANGELOG에서 제외하며,
시뮬레이터·에뮬레이터 촬영 대상 화면 변경도 없다.

## 검수

검수-223은 `b3e9c64..1bcda36`을 Standards·Spec 두 축으로 확인했고 지적은 없었다.
검수자가 도우미의 잘못된 해제·기본 응답·본문 교체·두 번째 요청 허용 변형에서
자체 테스트의 실제 단언 실패를 재현했다. timeout 뒤 늦은 요청도 별도로 확인했다.
로컬 상세 자료는 `.utmp/review-223.md`와 `.utmp/review-223-mutations/`에 있다.
반영할 지적이 없어 구현 커밋을 유지한 채 전체 검증했다.

## 검증

모든 테스트·검사 앞에 `~/.heoturu-agents/busy.sh &&`를 붙였다.
전체 검증은 작업 트리에서 직접 실행했으며 프로세스 시간 제한은 600초였다.

| 범위 | 실행·결과 | 로그 |
| --- | --- | --- |
| 테스트 우선 | 도우미 미구현 컴파일 실패, 도착 전 해제가 오류 없이 반환되는 단언 실패, timeout API 미구현 컴파일 실패를 순서대로 확인 | `.utmp/ticket-223/partial-red-{helper,release,timeout}.log` |
| 관련 테스트 | `cd frontend && flutter test --no-pub test/support/http_response_hold_test.dart test/view_models/content_view_models_test.dart`: 자체 테스트 5개 포함 총 50개 통과 | `.utmp/ticket-223/partial-converted.log` |
| 전체 Dart 포맷 | `cd frontend && dart format --output=none --set-exit-if-changed lib test`: 280개 파일, 변경 0, 통과 | `.utmp/ticket-223/partial-format.log` |
| 첫 커밋 전 앱 검사 | `python3 ~/.heoturu-agents/verify.py --only app --log-dir .utmp/response-hold-app-verify`: 3개 검사 통과, 앱 테스트 2,117개 통과 | `.utmp/response-hold-app-verify/` |
| 검수 후 전체 검사 | `python3 ~/.heoturu-agents/verify.py --log-dir .utmp/response-hold-final-verify`: 10개 검사 통과 | `.utmp/response-hold-final-verify/` |

전체 검사는 backend ruff·compileall, 두 전용 DB의 Alembic upgrade·check,
DB 테스트를 포함한 pytest, 앱 pub get·analyze·test를 실행했다.

```text
2024 passed, 46 skipped, 3 warnings in 171.84s (0:02:51)
pytest skip: 45 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=10 failed=0
```

최종 앱 테스트는 2,117개 통과했다. skip 줄은 `verify-result.txt`의 원문이며,
skip은 실행 성공으로 세지 않는다. Docker 복구·로컬 S3 대역 검사는 미실행이며
이번 변경 대상인 테스트 지원·홈 뷰모델 테스트에는 skip이 없다.
원격 CI·실제 OAuth·운영·실기기 검증은 수행하지 않았다.
후속 이력 문서 커밋은 코드가 `1bcda36`과 같으므로 전체 검증을 반복하지 않는다.
문서 경로·내용과 `git diff --check`를 확인했다.
