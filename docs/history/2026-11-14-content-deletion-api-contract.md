# 콘텐츠 삭제 404의 인증 갱신·세션 교체·취소 계약 보존 (#372)

2026-11-14, 브랜치 `test/content-deletion-api`. 시작 커밋 `aab206d`, 테스트 커밋 `6bd9fe1`(최초 전체 검증 기준). 최초 이력 커밋 `8eef6af`는 문서만 바꿨다. main 병합 후 최종 전체 검증 기준은 아래 `cf96306`이다.
[#364](2026-11-14-delete-404-as-success.md) 재검수에서 비추적 파일에만 있던 API 검사 중 기존 테스트와 겹치지 않는 3건을 저장소 테스트로 옮겼다.

## 사용자 결정

- 2026-11-14 "모두 진행해줘": 재검수 API 검사 45건 중 이슈 목록 3건만 보존한다. 제품 코드·기존 테스트는 바꾸지 않고 추가만 한다.

## 변경

- 추가: `frontend/test/content_deletion_api_test.dart`. 실제 `ClipbackApi`에 `MockClient` 응답을 주고, 요청 보류는 `test/support/http_response_hold.dart`를 쓴다.

| 테스트 | 확인하는 계약 |
| --- | --- |
| `deleteContent succeeds on malformed 404 after refreshing authorization` | 401 → 토큰 갱신 → 재전송 DELETE의 본문 `null` 404가 삭제 성공으로 끝난다. 요청은 DELETE·POST·DELETE 3개, 재전송은 새 토큰을 쓰고 최종 세션은 갱신된 세션이다. |
| `deleteContent rejects late 404 after session replacement and preserves the new session` | DELETE 도착 뒤 세션을 바꾸면 늦은 404(`[]`)가 성공이 되지 않고 `ClipbackApiException`(로그인 상태 변경)으로 실패한다. 새 세션이 남고 추가 요청이 없다. scope 없이 실행해 세션 세대 확인만 따로 본다. |
| `deleteContent rejects late 404 after scope cancellation and preserves the session` | scope 안의 DELETE 도착 뒤 scope를 취소하면 늦은 404(`[]`)가 성공이 되지 않고 넘겨준 취소 사유로 실패한다. 기존 세션이 남고 추가 요청이 없다. |

## 변형 검증

제품 코드 `frontend/lib/clipback_api.dart`를 잠시 바꿔 새 테스트만 돌리고, 복사본으로 되돌린 뒤 diff 없음을 확인했다. 변형은 커밋하지 않았다.

| 변형 | 결과 |
| --- | --- |
| A: `deleteContent`에서 오류 본문 해석을 404 판정 앞으로 이동 | 인증 갱신 사례만 실패(`null` 본문 해석의 타입 오류) |
| B: 응답 뒤 세션 세대 확인 제거 | 세션 교체 사례만 실패(늦은 404가 성공으로 끝남) |
| C: 응답 대기의 scope 취소 확인 제거 | 취소 사례만 실패(늦은 404가 성공으로 끝남) |

되돌린 뒤 새 3건 통과, `dart format`·`flutter analyze` 문제 없음.

## 검증

- 전체 검증(`6bd9fe1`, 작업 트리 깨끗함): `VERIFY result=PASS scope=all checks=12 failed=0`. 앱 테스트 3655건 통과. 백엔드 pytest 2661 passed, 49 skipped. skip은 `tests/deployment` 48건(`RUN_DOCKER_RECOVERY_TESTS=1`과 라벨 붙은 로컬 이미지 필요 외 6종, CI에서만 실행)과 `tests/integration` 1건(`CLIPBACK_IMAGE_TEST_S3_ENDPOINT` 필요)이다. 백엔드는 바꾸지 않았다.
- 앱 단계는 App Validation CI와 같은 명령을 같은 순서로 돈다: `flutter pub get --enforce-lockfile`, `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze --no-pub`, `flutter test --no-pub`.
- 첫 전체 검증은 새 워크트리에 백엔드 가상환경이 없어 `backend:venv`·`backend:pytest`가 실패했다(앱 4단계는 통과). 환경을 준비한 뒤 다시 돌린 결과가 위 PASS다.
- 화면 변경이 없어 시뮬레이터·에뮬레이터 확인은 하지 않았다. 원격 CI는 push 전이라 미실행이다.

## 검토

검수(Codex, `aab206d..6bd9fe1`): Standards 0개, Spec 0개. 검수는 새 3건을 직접 다시 돌려 통과를 확인했고 변형 결과는 작업자 로그와 대조했다.

## main 병합 후 검증 (최종)

- #379 / PR #388의 main `8e0072b`를 한 번 병합한 커밋은 `cf96306`이다. 로컬 `merge=union`이 이력 목차 양쪽 항목을 보존했고 제품 코드·테스트 충돌은 없었다. `check-changelog`·`check-body`와 `git diff --check`를 통과했다.
- main은 앱 초기화 콜백과 주간 추천 상태·이동을 바꿨다. 새 API 테스트 자체는 제품 변경과 분리돼 있지만, 삭제 화면을 포함한 앱 소비자 경로가 같은 초기화를 쓰므로 부분 검사 뒤 전체 검증을 다시 실행했다.
- 부분 검사: `frontend/`에서 `flutter test --no-pub test/content_deletion_api_test.dart test/content_mutation_test.dart test/weekly_one_visit_test.dart test/weekly_root_test.dart test/weekly_visit_behavior_test.dart test/notification_navigation_test.dart` 195건 통과(exit 0), 이어서 `flutter analyze --no-pub` 통과(exit 0).
- 전체 검증: `cf96306`, clean, 원 실행 exit 0. `VERIFY result=PASS scope=all checks=12 failed=0`. 앱 3663건 통과, pytest 2661 passed / 49 skipped / 3 warnings. 이 최종 이력 추가는 문서만 바꾸므로 검증 근거 코드는 `cf96306`과 동일하다.

```text
pytest skip: 48 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
```

- 위 skip은 이 로컬 검사로 검증되지 않았다. 갱신 push의 원격 CI 결과는 별도로 확인한다. PR 승인 본문은 변경하지 않는다.
