# 원본 이미지 접근 확인과 직접 다운로드 (#67)

## 기준과 범위

- 최초 기준: 이미지 보관 통합 브랜치 `b2ee962` (#65 Bucket 저장·기존 인증 조회 통합).
- 작업일: 2026-10-23. 합성 데이터와 전용 PostgreSQL 17 DB, moto S3 경계를 사용했다.
- 기존 원본 보기·원문 창 디자인과 콜백은 유지하고 API의 다운로드 경로를 확장했다.
- 현재 계약은 [백엔드 API](../backend/api-contracts.md#screenshot-storage),
  [프론트 동작](../frontend/behavior.md#저장된-스크린샷-원본-조회),
  [프론트 실행 안내](../../frontend/README.md)를 따른다.

## 구현과 확인 경계

1. 인증된 접근 API → 소유권·삭제·실제 파일 존재를 확인하고 크기·SHA-256·MIME을 반환한다.
   로컬은 기존 프록시, Bucket은 MIME 응답 설정을 포함한 120초 서명 URL을 반환한다.
   이전 메타데이터의 누락된 해시는 실제 바이트에서 계산하며 응답을 저장하지 않는다.
2. 앱 직접 다운로드 → 별도 HTTP 클라이언트로 앱 토큰·쿠키 없이 받고 리다이렉트를 거절한다.
   10MiB와 응답 크기·MIME·SHA-256을 확인한 바이트만 반환한다.
   Bucket 403은 접근 정보를 한 번 재발급받으며 Bucket 오류로 앱 세션을 무효화하지 않는다.
3. 계정 전환 → 접근 정보를 발급 당시 세션 세대에 연결한다. 이전 계정의 늦은 응답과
   이미 받은 접근 정보의 재사용을 거절하고 수신 스트림을 닫는다.
   본문 수신 시간 초과·용량 초과 때도 스트림을 취소한다.
4. 기존 앱·로컬 자료 → 인증된 원본 GET과 콘텐츠 응답 형식을 유지했다.
   기존 원본 화면과 안전 영역 프리뷰의 합성 응답도 새 접근 계약에 맞췄다.

접근 응답은 `private, no-store`다. 서명 URL은 잠시 유효한 접근 권한이며 로그아웃으로
즉시 폐기되지 않는다. 만료는 새 요청의 시작을 제한하고 이미 수락된 다운로드를 중단하지 않는다.
원본의 영구 디스크 캐시는 #68의 범위이며 이 작업에는 추가하지 않았다.

## 실제 실행한 검증

- TDD 최초 실패: 로컬 접근 라우트 404, Bucket 접근 메서드 미구현 500,
  Flutter의 별도 Bucket 클라이언트 미구현 컴파일 실패를 각각 확인한 뒤 통과시켰다.
- 추가 실패 재현: 계정 변경 전에 받은 접근 정보로 이전 원본이 다운로드되는 문제,
  늦은 Bucket 응답과 시간 초과 본문의 스트림이 취소되지 않는 문제를 먼저 확인하고 수정했다.
- 백엔드: 전용 DB에 `alembic upgrade head` 적용 후 아래 관련 검사 **39 passed**.
  기존 Starlette/httpx deprecation warning 1개가 있었다.

```bash
# backend/에서 실행. TEST_DATABASE_URL은 task 전용 합성 PostgreSQL DB다.
PYTHONPATH=. TEST_DATABASE_URL=<전용-합성-DB-URL> python -m pytest \
  tests/integration/test_asset_access.py tests/integration/test_upload_and_isolation.py \
  tests/services/test_upload_service.py tests/api/test_uploads.py -q
```

- Flutter: 아래 API·원본 화면·ViewModel 검사 **118 passed**.
  손상·짧은 파일·과대 스트림·잘못된 MIME, 서명 재발급 한 번, 타임아웃,
  로그인 갱신·영속 저장 실패·계정 전환·기존 원본 화면을 검증했다.

```bash
# frontend/에서 실행
flutter test test/screenshot_asset_access_test.dart test/screenshot_asset_api_test.dart \
  test/screenshot_asset_test.dart test/view_models/content_view_models_test.dart --no-pub
flutter analyze --no-pub
```

- Flutter analyze: **No issues found**.
- 변경 백엔드 파일의 `ruff check --no-cache`: **통과**.
- 최종 `git diff --check`: **통과**.

## 미검증과 후속 통합 확인

- 실제 Railway Bucket·운영 계정·운영 데이터·배포는 사용하지 않았다.
- 이 개별 작업에서는 iOS Simulator·Android Emulator 빌드와 실행 증거를 수집하지 않았다.
  통합 검증 #74에서 같은 합성 원본으로 두 플랫폼 원본 보기와 계정 전환을 확인해야 한다.
- 전체 백엔드·Flutter 검사와 실제 격리 복원도 최종 통합 #74의 검증으로 남아 있다.
  이 작업의 관련 자동 테스트 통과를 해당 실행·운영 검증의 증거로 사용하지 않는다.
