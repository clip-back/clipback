# Clipback Frontend

Flutter mobile frontend for the Clipback MVP.

FE 병합 전 수정 순서와 PR별 검증 결과는
[FE 병합 전 수정 진행 현황](../docs/fe-merge-fixes.md)에 기록합니다.

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
- 저장 실패 시 메모리 세션을 계속 사용하는 기존 정책을 유지합니다. 갱신 토큰의 즉시 영속화는
  PR 2, 동시 refresh 통합은 PR 3, 스크린샷 인증 재시도는 PR 4 범위입니다.

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

세션 복원 회귀 테스트는 `test/session_restore_test.dart`에서 HTTP와 저장소 오류를 대체해 확인합니다.
실제 PostgreSQL·Chrome 검증 결과와 미검증 범위는 위 진행 문서에 별도로 기록합니다.
