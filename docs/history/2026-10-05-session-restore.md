# 일시 조회 실패와 세션 보존

- 최초 기록일: 2026-10-05
- 영역: 인증
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-c28c4a175cdf5891"></a>

### PR 1 구현 — 2026-10-05

<a id="b-33f1c515368cd1d7"></a>

- 상태: 구현·로컬 검증 완료. 커밋·푸시·수정 PR 생성은 미실행이며 PR base는 `FE`다.
- 커밋·PR 제목: `fix: 일시적인 조회 실패 시 기존 세션 보존`.
- 기준: FE `57488ab8fbd90b8d1332b1bb444c5490cb77f3b1`, 최신 main
  `8c759d1f4a02f43966f4d692d0541d5feb74dcdc`.
- 변경: `main.dart`의 복원 중복 실행 차단·메모리 세션 우선 사용·최종 401만 게스트 전환,
  초기 로딩·오류/재시도 화면, 프로필·통계의 최종 401 전달, 선택적 저장소 주입.
- 저장소 읽기 실패에는 계정을 생성하지 않는다. 삭제 실패에는 기존 메모리를 보존하며 전환을 중단한다.
  저장 실패의 메모리 사용 정책을 유지하고, 새 게스트 조회 실패에도 같은 시도에서 반복 생성하지 않는다.
- 실패 재현: 제품 변경 전 `flutter test --no-pub test/session_restore_test.dart`에서 카테고리 503 뒤
  게스트 생성 횟수가 기대 0 / 실제 1로 실패했다. 수정 후 같은 테스트 1건은 통과했다.
- 환경: 기존 SDK를 바꾸지 않고 `/private/tmp`에 공식 Flutter 3.44.9 stable / Dart 3.12.2 arm64를 준비했다.
  공식 릴리스 manifest와 archive SHA-256을 대조했으며 `flutter pub get --enforce-lockfile`이 통과했다.
  `pubspec.lock`은 변경하지 않았다.
- 회귀 테스트: `frontend/test/session_restore_test.dart`에 **33건**을 추가했다.
  카테고리·피드의 503/403/연결/파싱 실패와 복구, refresh의 비인증 오류,
  갱신 후 조회 실패 시 최신 메모리 토큰 재사용, 네 조회 경로의 최종 401,
  프로필·통계 503 허용, 저장소 읽기/삭제/쓰기 실패, 최초 게스트 보존,
  로딩·오류 중 홈 미노출 및 연속 재시도 중복 방지를 검증한다.
- 프론트 검증:
  - `flutter pub get --enforce-lockfile`: 통과, 원본 잠금파일 유지.
  - `flutter analyze --no-pub`: 최종 **No issues found**. 새 테스트의 중괄호 lint 4건을 수정 후 재실행했다.
  - `flutter test --no-pub`: **33 passed**, skip 없음. 테스트 중 기존 SVG `<filter/>` 경고가 출력된다.
  - `flutter build web --no-pub`: 성공(`build/web`), Wasm dry run 성공.
    CupertinoIcons 폰트 관련 경고는 출력되었으며, 폰트·의존성 변경은 하지 않았다.
  - `git diff --check`: 통과. 새 테스트 파일은 별도로 `git diff --no-index --check /dev/null` 검사했다.
- 실제 PostgreSQL 검증: 최신 main을 `/private/tmp/clipback-pr1-auth-env.wmedfgxf`에 격리해 실행했다.
  Docker daemon이 실행 중이지 않아 전용 PostgreSQL **17.7** 임시 클러스터를 사용했다(기준 16은 미검증).
  새 `auth_check`·`browser_probe` DB에 `YOUTUBE_SUMMARY_ENABLED=false`와 전용 `TEST_DATABASE_URL`을
  지정하고 `alembic upgrade head`·`alembic check`를 모두 통과했다.
  `pytest -q tests/integration/test_auth_flow.py`: **6 passed, skip 0**, Starlette/httpx 사용 중단 예정 경고 1건.
  원본 `.env`와 개발·운영 DB는 사용하지 않았다.
- Chrome 검증: 로컬 Flutter 웹 서버 `127.0.0.1:5187`과 최신 main API `127.0.0.1:50311`을 사용했다.
  정상 홈 → API 중단 → 앱 새로고침 → 오류 화면 → API 복구 → “다시 시도” → 로딩 후 홈 복구를 확인했다.
  CORS preflight와 API 준비 상태도 200이었다. 전후 DB의 사용자 ID가 같고
  `users=1`, `auth_sessions=1`, `contents=0`이 유지되어 추가 계정·세션 생성이 없었다.
  콘텐츠가 있는 계정의 화면 복구는 HTTP 대역 회귀 테스트에서 검증했다.
- 검증 후 임시 API·PostgreSQL·Flutter 웹 서버를 종료했다.
- 미검증: PostgreSQL 16, 원격 GitHub Checks, Railway 배포·운영 API, 실제 OAuth·외부 AI,
  Android/iOS 실기기, 전체 백엔드 테스트 및 최종 FE→main 통합. 이번 변경은 프론트 복원 경로에 한정한다.
- 범위 유지: API 클라이언트·백엔드·migration·사용자 `AGENTS.md` 변경 없음.
  토큰 즉시 영속화(PR 2)·동시 refresh 통합(PR 3)·스크린샷 인증(PR 4)은 후속 작업이다.
- 다음 단계: 이 변경을 커밋·푸시해 `FE` 대상 수정 PR을 검토하고, FE 병합 후 PR 2를 시작한다.

<a id="b-c18656f90a16f5f6"></a>

### PR 1 커밋·푸시·PR 생성 — 2026-10-05

<a id="b-c378c4862357501c"></a>

- 상태: [#37 — fix: 일시적인 조회 실패 시 기존 세션 보존](https://github.com/clip-back/clipback/pull/37)
  생성, 리뷰 및 FE 병합 대기. draft가 아닌 일반 PR이다.
- 브랜치: `fix/fe-session-restore` → `FE`.
- 구현 커밋: `69bbc0889f01d873ac53ff0eda639fcbe0f6f382` — `fix: 일시적인 조회 실패 시 기존 세션 보존`.
  PR 생성 시 origin에 푸시한 구현 커밋과 PR head가 일치함을 확인했다.
- 변경 범위: `main.dart`, `session_restore_test.dart`, 프론트 README, 이 진행 문서의 네 파일.
  사용자 `AGENTS.md` 변경은 커밋에서 제외했으며 원본 잠금파일도 유지했다.
- 이번 단계 검증: staged diff 및 `git diff --check` 통과, 원격 FE 기준·PR base·파일 범위 확인.
  제품 코드가 바뀌지 않아 앱·DB·Chrome 검증은 재실행하지 않았다. 결과는 위 구현 기록을 참고한다.
- GitHub 상태: 생성 직후 충돌 없음(`MERGEABLE`), Checks 기록 없음.
  이를 원격 CI 통과로 취급하지 않는다. FE 병합은 실행하지 않았다.
- 다음 단계: PR #37 리뷰·FE 병합 후 최신 FE에서 PR 2를 진행한다.

<a id="b-931435c7a123f11b"></a>

### PR 1 FE 병합 확인 및 PR 2 시작 — 2026-10-05

<a id="b-f32e52db64d9b818"></a>

- PR [#37](https://github.com/clip-back/clipback/pull/37)은 2026-10-05 17:22 KST에 FE에 병합되었다.
- 병합 커밋: `778387d89fee8dff1bec9b613a3a3b28fc88b974`.
- PR 2 브랜치: 위 최신 FE에서 `fix/fe-refresh-persistence` 생성. PR base는 `FE`다.
- 비교 main: `8c759d1f4a02f43966f4d692d0541d5feb74dcdc`.
- 확정 정책: 새 세션 발급 직후 저장을 시도한다. 저장 실패에도 최신 메모리 세션으로 작업을 계속하며,
  안내와 저장만 재시도하는 버튼을 제공한다. 단일 JSON 저장과 기존 네 키 읽기 호환을 유지한다.
- 구현 순서: 갱신 후 이전 토큰이 남는 실패 재현 → 공통 저장 경로·저장 큐·안내 구현 →
  회귀 테스트 → 최신 main 인증 DB 및 Chrome 재시작 검증 → 결과 기록.
- 범위: API 클라이언트·앱 저장 연결·프론트 테스트·문서. 동시 refresh(PR 3)와 스크린샷 인증(PR 4)은 제외한다.
- 기존 사용자 `AGENTS.md`, 의존성·잠금파일, 백엔드·DB 스키마는 변경하지 않는다.
- 시작 시점 상태: 검증 진행 중. 최종 결과는 아래 구현 기록을 따른다.
