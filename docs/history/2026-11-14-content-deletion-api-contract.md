# 콘텐츠 삭제 404의 인증 갱신·세션 교체·취소 계약 보존 (#372)

2026-11-14, 브랜치 `test/content-deletion-api`. 시작 커밋 `aab206d`, 테스트 커밋 `6bd9fe1`(전체 검증 기준). 이 기록을 더한 커밋은 문서만 바꾸며 코드는 `6bd9fe1`과 같다.
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
