# 갱신 토큰 영속 저장

- 최초 기록일: 2026-10-05
- 영역: 인증
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-974e0189169cd2b3"></a>

### PR 2 구현 및 검증 — 2026-10-05

<a id="b-d9b4ad1b0ab2c035"></a>

- 상태: 구현·로컬 검증 완료. 커밋·푸시·PR 생성은 미실행.
- 커밋·PR 제목: `fix: 갱신된 인증 토큰 영속 저장`. 구현 브랜치와 기준 SHA는 위 시작 기록을 따른다.
- 변경: `ClipbackApi`에 선택적 비동기 `onSessionChanged` 콜백을 추가했다.
  게스트 생성·refresh·소셜 로그인·게스트 전환에서 메모리 반영 → 저장 시도 완료 → 결과 반환 순서를
  통일했으며, refresh 뒤 원래 요청의 재시도도 저장 시도 이후에 실행한다.
  저장소에서 복원한 세션에는 콜백을 실행하지 않는다.
- `ApiSessionStorage`는 토큰과 만료 정보 네 필드를 `clipback.session` JSON 한 값으로 저장한다.
  새 키 우선 읽기·손상된 새 값 오류 처리·기존 네 키 읽기 호환을 적용했다. 읽기만으로 변환하지 않는다.
  저장과 삭제의 예외·`false` 반환을 실패로 처리하고, 삭제는 기존 네 키 성공 후 새 키를 지운다.
- `main.dart`에서 흩어진 저장을 공통 큐로 모았다. 실패해도 다음 작업이 실행되며,
  저장 재시도는 큐 실행 시점의 최신 메모리 세션만 저장한다.
  저장 실패에는 앱 사용을 유지하면서 안내 배너와 “다시 저장” 버튼을 제공한다.
  저장 중 중복 재시도를 막고, 세션 동일성을 확인해 이전 작업 결과가 최신 실패 안내를 지우지 않게 했다.
- 실패 재현: 제품 변경 전 `flutter test --no-pub test/session_persistence_test.dart`에서
  카테고리 생성의 401 → refresh → 생성 성공 후 저장소 캐시를 초기화해 다시 읽었다.
  새 refresh token을 기대했지만 기존 값이 남아 실패했다. 이후 동일 경로와 새 앱 복원 테스트가 통과했다.
  테스트 HTTP 대역의 초기 비동기 assertion 충돌은 대역 밖으로 assertion을 이동해 해결했으며,
  이 테스트 구성 오류를 제품의 실패 재현 결과로 취급하지 않았다.
- 환경: PR 1에서 준비한 별도 Flutter **3.44.9** / Dart **3.12.2** SDK를 재사용했다.
  `flutter pub get --enforce-lockfile` 통과, `pubspec.lock` 원본 SHA-256 유지.
- 회귀 테스트: `session_persistence_test.dart`에 **29건** 추가, PR 1의 저장 시점 기대값을 새 계약에 맞췄다.
  플랫폼 저장 대역의 데이터와 캐시 초기화 후 읽기를 함께 검사했다.
  네 발급 경로의 콜백 대기·인증 재요청 이전 저장, 이후 피드·프로필·통계 실패에도 새 토큰 유지,
  새 앱 복원, 저장 예외·`false`, 반복 저장 실패와 재시도 성공, 네트워크 호출수 불변,
  지연된 이전 저장·새 세션 실패·로그아웃 삭제 순서, 삭제 실패 뒤 큐 복구,
  기존 형식·새 형식 우선·손상된 값·두 형식 삭제를 검증한다.
- `flutter test --no-pub`: **62 passed, skip 0**(기존 33 + 신규 29).
  기존 SVG `<filter/>` 경고가 출력된다.
- `flutter analyze --no-pub`: 최종 **No issues found**.
  신규 테스트의 중괄호 lint 3건을 수정한 뒤 다시 실행했다.
- 웹 빌드: `flutter build web --no-pub` 성공(`build/web`), Wasm dry run 성공.
  기존 CupertinoIcons 폰트 경고가 출력되었으며 폰트·의존성 변경은 하지 않았다.
- 실제 PostgreSQL 검증: 최신 main을 `/private/tmp/clipback-pr2-auth-env.vlo20rpb`에 격리해 새로 실행했다.
  Docker daemon이 실행 중이지 않아 PostgreSQL **17.7** 전용 임시 클러스터를 사용했다(기준 16은 미검증).
  빈 `auth_check`·`browser_probe` DB 각각에 `YOUTUBE_SUMMARY_ENABLED=false`와 전용 DB URL을 지정해
  `alembic upgrade head`·`alembic check`를 통과했다.
  `TEST_DATABASE_URL`을 지정한 `pytest -q tests/integration/test_auth_flow.py`: **6 passed, skip 0**,
  기존 Starlette/httpx 사용 중단 예정 경고 1건. 원본 `.env`와 개발·운영 DB는 사용하지 않았다.
- Chrome 검증: 웹 `http://localhost:5187`과 최신 main API `http://127.0.0.1:50311/api/v1`에서
  `ACCESS_TOKEN_EXPIRE_MINUTES=1`로 실행했다. 게스트 복원 → 1분 이상 만료 대기 → 카테고리 생성 →
  앱 새로고침 후 정상 홈과 생성한 카테고리 표시를 확인했다.
  DB 비교에서 refresh token 해시의 변경, 동일 사용자 ID·인증 세션 ID 유지,
  `users=1`, `auth_sessions=1`, `contents=0` 유지를 확인했다. 실제 토큰·해시는 기록하지 않는다.
  CORS preflight와 준비 상태는 200이었고, 검증 후 임시 API·PostgreSQL·Flutter 웹 서버를 종료했다.
- 미검증: PostgreSQL 16, 원격 GitHub Checks, Railway·운영 API, 실제 OAuth·외부 AI,
  Android/iOS 실기기, 전체 백엔드 테스트 및 최종 FE→main 통합.
  저장 실패 UI는 플랫폼 저장 대역으로 검증하며 실제 기기의 저장 장치 오류는 재현하지 않았다.
- 한계: 저장 실패를 해결하기 전에 앱을 종료하면 기존 계정 복원을 보장하지 않는다.
  성공 판정은 기기 저장 API의 성공 응답 기준이며 기기 장애에 대한 영구 보존 보장이 아니다.
- 범위 유지: 백엔드·DB·의존성·잠금파일 변경 없음. 사용자 `AGENTS.md` 변경을 그대로 보존했다.
  동시 refresh 통합(PR 3)·스크린샷 인증(PR 4)은 후속 작업이다.
- 최종 문서·diff 검사: `git diff --check` 통과. 신규 테스트는
  `git diff --no-index --check /dev/null frontend/test/session_persistence_test.dart`에서 공백 오류 출력 없음
  (새 파일 차이를 나타내는 종료 코드 1). 사용자 `AGENTS.md` diff와 잠금파일의 SHA-256이 시작 시점과 같다.
- 커밋·푸시·PR 생성은 미실행이며, 생성 시 PR base는 `FE`다.
- 다음 단계: 이 변경을 커밋·푸시하고 `FE` 대상 PR을 검토한 뒤, FE 병합 후 PR 3을 진행한다.

<a id="b-a49a974e9a2b1074"></a>

### PR 2 커밋·푸시 — 2026-10-06

<a id="b-03cc2bf91762e8ae"></a>

- 상태: 구현 커밋을 `origin/fix/fe-refresh-persistence`에 푸시했고 upstream을 설정했다. PR은 미생성이다.
- 구현 커밋: `958e6d165bd72207ff84248934fcfe0dc94bd3ee` — `fix: 갱신된 인증 토큰 영속 저장`.
- 변경 범위: API 클라이언트·앱·회귀 테스트 두 파일·프론트 README·이 진행 문서, 총 여섯 파일.
  사용자 `AGENTS.md` 변경은 제외했다. 사용자 diff와 잠금파일 SHA-256은 구현 완료 시점과 같다.
- 이번 단계 검증: staged diff·`git diff --check` 통과, 커밋 파일 범위와 원격 FE 기준 확인.
  제품 코드 변경 없이 커밋·푸시한 단계이므로 Flutter·DB·Chrome 검증은 재실행하지 않았다.
  위 2026-10-05 구현 기록의 결과와 미검증 범위를 따른다. 원격 CI 통과를 주장하지 않는다.
- 작업 방식 갱신: 사용자 요청에 따라 앞으로 계획 구현은 검증·문서 기록·커밋·푸시까지 진행한다.
  PR 생성과 병합은 별도 요청에 따른다.
- 다음 단계: 요청 시 `FE` 대상 PR을 생성하고, FE 병합 후 PR 3을 진행한다.

<a id="b-f3f450dfe659a9ee"></a>

### PR 2 PR 생성 — 2026-10-06

<a id="b-340da951e0d12cb3"></a>

- 상태: [#38 — fix: 갱신된 인증 토큰 영속 저장](https://github.com/clip-back/clipback/pull/38) 생성.
  draft가 아닌 일반 PR이며 리뷰와 FE 병합을 기다린다.
- 브랜치: `fix/fe-refresh-persistence` → `FE`.
- 생성 시 PR head: `08cf0f8d3d0d1786e316bf3bed41405dfc0476ef`.
  구현 커밋 `958e6d1`과 푸시 결과 기록 `08cf0f8`을 포함한다.
- 검증: 원격 head와 PR head 일치, PR base·파일 범위 확인, `git diff --check origin/FE...HEAD` 통과.
  사용자 `AGENTS.md` 변경은 PR에 포함하지 않았다.
- GitHub 상태: 생성 후 조회 시 충돌 없음(`MERGEABLE`), Checks 기록 없음.
  원격 CI 통과로 취급하지 않는다. 제품 변경 없이 PR을 생성했으므로 앱·DB·Chrome 검증은 재실행하지 않았다.
- PR 본문에 변경 이유·저장 실패 정책·실제 검증 결과·미검증 범위를 기록했다. migration은 필요하지 않다.
- 다음 단계: PR #38 리뷰·FE 병합 후 최신 FE에서 PR 3을 진행한다. FE 병합은 실행하지 않았다.
