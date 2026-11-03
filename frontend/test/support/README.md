# HTTP 응답 보류

`HttpResponseHold`는 선택한 MockClient 요청 한 개의 도착과 응답 해제를 묶는다.
fixture가 경로·메서드·쿼리를 선택하고 `hold(request)`를 반환한다.
테스트는 `await hold.waitForRequest()` → 중간 상태 단언 →
`hold.release(response)` → 최종 결과 단언 순서를 따른다.
본문·상태 코드는 fixture가 전달하며 기본 성공 응답은 만들지 않는다.

`waitForRequest`의 기본 제한은 5초다. 미도착 시 요청 설명이 포함된
`TimeoutException`으로 실패한다. `timeout`으로 한도를 바꿀 수 있다.
도착 전 해제·중복 해제·한 도우미에 두 번째 요청 전달은 `StateError`다.
제한 시간 경과가 보류 응답을 자동 해제하지는 않는다.
요청마다 별개 인스턴스를 쓰고, 테스트가 시작한 작업은 명시적으로 해제하고 기다린다.
위젯 테스트에서는 도착에 필요한 프레임을 진행해야 하며, 응답 보류 중
`pumpAndSettle`하거나 큰 고정 대기로 도착 확인을 대신하지 않는다.

# 전환 범위와 남긴 후보

#223에서는 `view_models/content_view_models_test.dart`의 홈 상단 기억과
전체보기 성공·실패만 전환했다. 아래는 후속 적용 후보이며 결함 목록이 아니다.
사용자 결정에 따라 일괄 전환하지 않았으며, 아래 조건을 보존하는 별도 검토가 필요하다.
경로는 `frontend/test/` 기준이다.

| 후보 | 현재 방식을 유지한 이유 |
| --- | --- |
| `view_models/content_view_models_test.dart` 나머지 보류 | 추가 로딩 공유, 선택 카테고리 삭제, 이전 필터·상세의 늦은 응답 검증은 승인된 전환 범위 밖이다. |
| `data/user_repository_test.dart` | 통계·사용자 조회의 독립된 도착 알림과 갱신 순서를 보존해야 한다. |
| `app/home_initial_loading_state_test.dart` | 경로별 gate와 위젯 프레임 진행을 함께 다뤄야 한다. |
| `feed_pagination_test.dart` | 동시 필터 요청·메타데이터 갱신 및 teardown 해제 규칙을 보존해야 한다. |
| `home_hero_memory_test.dart` | 위젯 프레임과 성공·실패 전환을 별도로 검증해야 한다. |
| `data/today_repository_test.dart`, `today_root_test.dart` | 계정 초기화·홈 이탈 뒤의 늦은 사전 조회 억제를 보존해야 한다. |
| `session_refresh_test.dart` | 두 API 인스턴스의 갱신 요청 두 개를 함께 해제하므로 단일 요청 도우미로 단순 교체하지 않는다. |
| `app/app_view_model_test.dart`, `share/share_lifecycle_test.dart` | dispose 뒤 응답·늦은 401 처리의 순서를 보존해야 한다. |
| `app_version_display_test.dart` | 사용자 조회 503과 버전 표시를 위젯 프레임에서 검증해야 한다. |
| `fixtures/today_server.dart`, `fixtures/weekly_server.dart` | 응답 객체 대신 반환 시점을 제어하는 gate이며 여러 repository/root 호출부를 함께 검토해야 한다. |
| `app/account_link_conflict_state_test.dart`, `app/ordinary_login_failure_state_test.dart`, `app/ordinary_login_status_state_test.dart` | 이슈의 추가 검색 후보로, 인증 상태 전환·프레임 조건을 확인한 뒤 적용 여부를 결정한다. |
| `logout_alignment_test.dart`, `notification_navigation_test.dart`, `screenshot_asset_test.dart`, `share/share_credential_api_test.dart`, `splash_startup_test.dart` | 이슈의 추가 검색 후보로, 각 로그아웃·이동·asset·인증·시작 수명 조건을 확인한 뒤 적용 여부를 결정한다. |
| `fixtures/link_pending_fixture.dart`, `fixtures/photo_pending_fixture.dart`, `fixtures/notice_alignment_fixture.dart` | 공유 fixture의 전체 호출부와 해제 수명을 확인한 뒤 적용 여부를 결정한다. |
| `support/account_preview.dart`, `support/logout_alignment_preview.dart` | 촬영용 실행 코드가 포함돼 이번 자동 테스트 전환 범위에서 제외한다. |

제품 코드·화면·API 계약을 바꾸지 않는 테스트 지원 변경이므로
시뮬레이터·에뮬레이터 촬영은 필요하지 않다.
