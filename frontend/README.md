# Clipback Frontend

Flutter mobile frontend for the Clipback MVP.

FE 병합 전 수정 순서와 PR별 검증 결과는
[FE 병합 전 수정 진행 현황](../docs/fe-merge-fixes.md)에 기록합니다.

현재 FE는 인증·콘텐츠·카테고리·계정 통계를 API와 연동합니다.
추천·알림 등 일부 화면은 로컬 또는 mock 동작이 남아 있으며, 아래 연동 범위와 진행 문서를 따릅니다.

The current implementation mirrors the supplied Figma flows:

- Onboarding
- Login entry
- Home
- Search
- Archive list
- Category archive
- Bookmark list
- Content detail

Figma-exported SVG assets are registered under `assets/figma/` and `assets/icons/`.
Large exported illustration SVGs include embedded raster data, so matching PNG fallbacks are generated in `assets/figma/` for reliable Flutter rendering.

## 초기 세션 복원과 재시도

- 앱 시작에는 로딩 화면을 표시하며, 카테고리·피드 조회가 끝나기 전에는 홈·샘플 콘텐츠·저장 기능을 노출하지 않습니다.
- 저장소 읽기 실패, 조회의 403·서버 오류·연결 실패·응답 파싱 실패에는 세션을 보존하고
  “저장한 콘텐츠를 불러오지 못했어요.”와 “다시 시도” 버튼을 표시합니다.
- 재시도는 현재 메모리 세션을 우선 사용합니다. 진행 중인 복원은 중복 실행하지 않으며,
  성공하면 서버 데이터가 반영된 홈으로 이동합니다.
- API의 토큰 갱신·재요청 후에도 최종 401이면 저장소 삭제 성공 후 새 게스트로 전환합니다.
  삭제에 실패하면 전환을 중단하고, 한 번의 복원에서 게스트를 반복 교체하지 않습니다.
- 저장된 세션이 없는 최초 실행에서 생성한 게스트도 조회 실패 후 유지합니다.
  프로필·통계의 비인증 오류는 홈 진입을 허용하고, 최종 401은 인증 만료로 처리합니다.
- 스크린샷 업로드의 인증 재시도는 PR 4 범위입니다.

## 갱신 토큰 저장

- 게스트 생성·토큰 갱신·소셜 인증으로 새 세션을 받으면 메모리에 적용한 뒤 바로 저장을 시도합니다.
  토큰 갱신으로 인한 원래 요청의 재시도는 저장 시도가 끝난 뒤 실행합니다.
- 토큰과 만료 정보는 `clipback.session`의 JSON 한 값으로 저장합니다. 새 키가 없을 때만 기존 네 키를
  읽으며, 새 값이 손상됐다면 이전 토큰으로 되돌아가지 않고 초기 복원 오류로 처리합니다.
  기존 세션은 읽기만으로 변환하지 않고 다음 발급·갱신부터 새 형식을 사용합니다.
- 저장과 삭제는 같은 큐에서 순서대로 처리합니다. 삭제는 기존 키들을 먼저 제거하고 새 키를 마지막에
  제거합니다. 저장·삭제 API의 `false` 반환과 예외는 실패로 처리합니다.
- 저장 실패 시 새 메모리 토큰으로 현재 작업을 계속하며 다음 배너와 **다시 저장** 버튼을 표시합니다.
  “로그인 정보를 기기에 저장하지 못했어요. 앱을 종료하기 전에 다시 저장해 주세요.”
- **다시 저장**은 현재 메모리의 최신 세션만 저장합니다. 토큰 갱신·콘텐츠 저장·카테고리 작업은
  반복하지 않으며, 저장 중 중복 실행을 막고 최신 세션 저장 성공 시 안내를 제거합니다.
- 저장 실패를 해결하기 전에 앱을 종료하면 계정 복원이 보장되지 않습니다. 저장 성공은 기기 저장 API의
  성공 응답을 기준으로 하며, 기기 장애나 강제 종료에 대한 영구 보존 보장을 뜻하지 않습니다.

## 동시 인증 오류와 로그아웃

다음 보호는 공통 요청 경로와 세션 발급에 적용합니다. multipart 스크린샷 업로드는 PR 4에서 다룹니다.

- 같은 API 인스턴스의 인증 요청들이 동시에 401을 받으면 진행 중인 refresh를 공유합니다.
  HTTP 응답부터 새 토큰 저장 시도까지 기다린 뒤 원래 메서드·본문을 유지해 한 번만 재요청합니다.
- 이미 갱신이 끝난 뒤 이전 토큰의 401이 도착해도 추가 갱신 없이 최신 토큰을 사용합니다.
  재요청의 최종 401은 호출자에게 전달하며, 갱신 실패 뒤의 새 요청은 다시 갱신할 수 있습니다.
- 세션을 복원·삭제·교체하면 이전 세션에서 시작한 응답은 새 세션을 덮어쓰거나 다른 계정으로
  재전송하지 않습니다. 이 취소는 인증 만료 401과 구분합니다.
- 로그아웃은 진행 중인 갱신과 저장 시도를 기다린 뒤 최신 메모리 토큰을 사용합니다.
  로그아웃 중 새 갱신·인증 재시도를 막고, 나중에 생성된 세션의 저장값과 화면은 보호합니다.
- refresh HTTP 응답 대기는 10초로 제한합니다. 저장 콜백에는 제한을 적용하지 않습니다.
  갱신 실패에도 현재 토큰으로 로그아웃을 시도하지만, 시간 초과는 서버 요청 취소를 보장하지 않습니다.
  서버에서 이미 토큰이 회전했다면 이전 토큰으로 해당 서버 세션을 해제하지 못할 수 있습니다.

## 실행과 검증

잠금파일은 Flutter `>=3.44.0`·Dart `>=3.12.0 <4.0.0`을 요구합니다.
해당 조건을 만족하는 SDK로 의존성을 준비하며 잠금파일을 재해석하지 않습니다.

```bash
cd frontend
flutter pub get --enforce-lockfile
flutter run
```

로컬 API 연결 시에는 실제 서버 주소를 명시합니다. 미지정 시 API 클라이언트의 Railway 기본 주소를 사용합니다.

```bash
flutter run -d chrome --dart-define=CLIPBACK_API_BASE_URL=http://127.0.0.1:8000/api/v1
flutter analyze --no-pub
flutter test --no-pub
flutter build web --no-pub
```

세션 복원·저장·동시 갱신 회귀 테스트는 `test/session_restore_test.dart`, `test/session_persistence_test.dart`,
`test/session_refresh_test.dart`에서 HTTP와 저장소 오류를 대체해 확인합니다.
토큰 저장은 플랫폼 저장 대역과 캐시 초기화 후 읽기도 검증합니다.
실제 PostgreSQL·Chrome 검증 결과와 미검증 범위는 위 진행 문서에 별도로 기록합니다.

## Backend integration boundaries

Use the backend public HTTPS domain and `/api/v1` exactly once in request URLs.
Protected APIs require the backend-issued Bearer access token. Account data and
statistics should come from `/users/me` and `/users/me/stats`; display statistics as
누적 저장 / 누적 열람, not current content totals.

The existing similar-content section filters already-loaded items by category;
today's content opens the first local item. Neither is a server recommendation.
The feed has no total-count field. Reminder and notification screens use mock data.
See [MVP scope decisions](../docs/backend-mvp-plan.md) before adding APIs for these.

For public URL and web CORS configuration, follow the
[deployment guide](../docs/railway-deployment.md).
