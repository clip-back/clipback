# 홈 최초 불러오기 복구 설계 인터뷰

## 당시 기준과 작업 범위

- 기록일: 2026-10-24.
- 최신 원격 main을 조회한 기준은 `5671e79a6c3451068cf053d185a9334fd9f3144c`다.
  이 기준에서 `docs/home-loading-recovery` 브랜치를 만들었다.
- 사용자가 `grill-with-docs`로 홈 로딩 복구 설계를 요청했고, Q1–Q5에서 추천안을 선택했다.
  최종 흐름 확인을 앞둔 정책·용어 기록이며 제품 구현이나 배포 결과가 아니다.
- 현재 합의와 검증할 결과는 [복구 설계](../frontend/home-loading-recovery.md),
  용어 정의는 [용어집](../../GLOSSARY.md)에 둔다.
- 보류 중인 이미지 보관 PR #75와 별개다. 제품 코드·테스트·운영 설정을 바꾸지 않았고,
  푸시·PR 생성·머지를 수행하지 않았다.

## 코드에서 확인한 근거

기준 커밋의 코드를 읽고 기존 테스트의 검사 대상을 확인했다. 아래는 실행 결과와 구분한다.

| 확인 내용 | 근거 |
| --- | --- |
| 카테고리 → 홈 목록 → 사용자 정보 → 통계를 순서대로 기다린다. 사용자 정보·통계의 인증 오류 외 실패는 허용하지만 무응답은 계속 기다릴 수 있다. | [계정 초기화 Action](../../frontend/lib/app/actions/account_initialization_action.dart) |
| 일반 JSON 요청에는 전체 종료 시간이 없다. 일부 다른 요청의 10초 제한을 홈 초기화 전체 제한으로 볼 수 없다. | [API 요청](../../frontend/lib/clipback_api.dart) |
| 최초 로딩, 수동 재시도 중복 차단, 계정 변경·인증 만료·Apple 계정 확인이 연결돼 있다. 같은 계정의 이전 시도 응답도 별도로 검증해야 한다. | [앱 상태](../../frontend/lib/app/app_view_model.dart) · [콘텐츠 저장소](../../frontend/lib/data/repositories/content_repository.dart) · [사용자 저장소](../../frontend/lib/data/repositories/user_repository.dart) |
| 기존 오류 화면은 홈 실패 외 토큰 읽기·로컬 세션 삭제 실패 복구에도 쓰인다. 홈 전용 변경을 모든 복구 상태로 확대하지 않는다. | [공용 복구 화면](../../frontend/lib/features/auth/session_restore_screen.dart) · [루트 화면 연결](../../frontend/lib/app/clipback_app.dart) |
| 계정 정보를 아직 확인하지 못한 상태에는 기존 ‘계정 정보 확인 중’ 표현이 있다. | [사용자 화면 모델](../../frontend/lib/shared/models/app_user.dart) |

기존 `session_restore_test.dart`, `home_initial_loading_state_test.dart`,
`system_back_policy_test.dart`, `home_initial_loading_alignment_test.dart`에서 관련 회귀 검사 범위를 확인했다.
이번 문서 작업에서는 실행하지 않았다. 앞선 UI/UX 감사의 가상 60초 무응답 재현을
이번에 다시 실행한 결과나 운영 서버의 발생 빈도로 보고하지 않는다.

## Figma 확인과 채택 범위

- 2026-10-24 파일 `svNWsTFh8Ws1Mpt8XQIcrN`의 기존 최초 로딩 `125:4105`와
  L-M01 `120:4881`의 컨텍스트·화면을 확인했다.
- 최초 로딩은 [기존 구현 기준](2026-10-18-initial-loading.md)의 캐릭터·세 점과 최소 900ms를 유지한다.
- L-M01 새 조회 세션은 `d69bc607-1280-44d8-92ee-628d8bfdca8e`다.
  반환된 컨텍스트는 `/private/tmp/home-recovery-figma-120-4881.txt`,
  화면은 `/private/tmp/home-recovery-figma-120-4881.png`에 당시 저장했다.
  임시 경로는 영구 보존을 보장하지 않는다.
- L-M01에는 뒤로가기·인터넷 연결 안내·오프라인 상태 상자가 있지만 Q4에서 첫 구현은
  기존 오류 안내와 다시 시도를 재사용하기로 선택했다. 새 와이어프레임의 외형을 채택한 것으로 기록하지 않는다.
- [Figma 맞춤 계획](../figma-ui-alignment-plan.md#figma-pending-10)에 합의와 남은 구현·디자인 경계를 반영했다.

## 이번 문서 검증과 한계

- 변경 문서 6개의 저장소 내부 상대 링크 대상 427개를 확인했고 누락은 0개였다.
  위 코드 경로와 당시 저장한 L-M01 컨텍스트·화면 파일도 존재했다.
- 최종 diff에서 문서만 변경된 것을 확인했고 `git diff --check`를 통과했다.
- 화면·제품 동작을 변경하지 않은 설계 기록이므로 전체 앱 테스트·iOS Simulator·Android Emulator를
  새로 실행하지 않는다. 구현 시 양 플랫폼의 변경 전·후·Figma 비교와 실제 복구 동작 검증이 필요하다.
- 원격 CI·실제 OAuth·운영 서버·실기기 검증은 이번 작업 범위가 아니다.
