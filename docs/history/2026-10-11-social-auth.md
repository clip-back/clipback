# 모바일 소셜 인증과 게스트 전환

- 최초 기록일: 2026-10-11
- 영역: 인증
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: docs/backend-mvp-plan.md

<a id="b-e22ecc162b06a73b"></a>

### 모바일 소셜 로그인 구현 범위 (2026-10-11)

<a id="b-d34b304090e61c06"></a>

구현 및 로컬 검증 완료:

<a id="b-551d6b8bd89decc3"></a>

- 전용 PostgreSQL 16.15: 빈 DB 전체 upgrade와 `202609240012`에서 `202610110013` upgrade 모두 통과, 두 DB `alembic check` 차이 없음. 기존 revision에 넣은 합성 Naver identity·사용자는 보존됐다.
- Apple challenge 저장소 테스트 8건: 목적·게스트 바인딩, 만료 경계, 재사용 거절, 만료 정리, 독립 트랜잭션 4개의 동시 소비 중 정확히 1회 성공을 확인했다.
- Python 3.12.7에서 전용 `TEST_DATABASE_URL`을 지정한 전체 `pytest -q` **960건 통과, skip 0건**. 실제 PostgreSQL repository·API·동시성 검증을 포함한다. 공급자 응답은 대역이다.
- `ruff check app alembic tests`, `python -m compileall -q app alembic tests`, `git diff --check` 통과.
- Flutter 3.44.9 / Dart 3.12.2: `flutter analyze --no-pub` 문제 없음, `flutter test --no-pub` **434건 통과**. `flutter build apk --debug --no-pub`, `flutter build ios --simulator --no-pub` 통과.
- `flutter run --debug --no-pub --no-resident`로 임시 iPhone 16 Pro(iOS 18.6)에 설치·실행해 Google·Kakao·Apple 및 게스트 선택 화면을 확인했다. 테스트 기기와 DB는 검증 후 정리했다.
- 게스트 승격의 공급자 401은 코드 재전송 없이 `/users/me`로 세션을 별도 확인한다. Apple 서버 grant의 `at_hash` 검증과 인증 422 응답의 민감 입력 제외도 회귀 테스트로 확인했다.
- 미검증: 실제 공급자 콘솔·키·SDK 발급 토큰, Galaxy/iPhone 실기기 OAuth, Release/TestFlight, 원격 CI·Railway 배포. 로컬 검증을 실제 로그인 성공이나 출시 완료로 해석하지 않는다.

<a id="b-20935b242cffd4a6"></a>

실기기 연결 전 [프론트 공개 ID·URL scheme 설정](../../frontend/README.md#공개-앱-설정),
[서버 인증 설정](../../backend/README.md#mobile-social-authentication)을 적용하고 migration `202610110013`을 준비한다.
