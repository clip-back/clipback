# 동시 인증 갱신 중복 방지

- 최초 기록일: 2026-10-06
- 영역: 인증
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-a7deb00820001432"></a>

### PR 2 FE 병합 확인 및 PR 3 시작 — 2026-10-06

<a id="b-4ad217017e365762"></a>

- PR [#38](https://github.com/clip-back/clipback/pull/38)은 2026-10-06 11:27 KST에 FE에 병합되었다.
- 병합 커밋: `da762cdf86ee53ce97a6bb6e7b3997dc4a6d740a`.
- 위 최신 FE에서 `fix/fe-refresh-single-flight` 생성. 비교 main은 `8c759d1f4a02f43966f4d692d0541d5feb74dcdc`다.
- 목표: 상세 조회·열람·클릭의 동시 401이 HTTP 응답부터 PR 2 저장 콜백까지 하나의 갱신을 공유한다.
  늦은 401은 최신 토큰을 재사용하며 원래 요청 재시도는 한 번으로 제한한다.
- 확정 정책: 로그아웃은 진행 중인 갱신·저장을 기다리고 최신 토큰을 사용한다.
  세션 세대를 바꾼 뒤 이전 응답이 새 계정을 덮어쓰거나 새 저장값을 삭제하지 않게 한다.
- 순서: 실패 재현 → 구현·회귀 테스트 → 최신 main 인증 DB·Chrome 검증 →
  실제 화면과 요청수 공유 → 커밋·푸시·`FE` 대상 일반 PR 생성.
- 범위: 프론트 API·로그아웃 저장 연결·테스트·문서. 백엔드·DB·의존성·잠금파일과 사용자 `AGENTS.md`는 보존한다.
  스크린샷 업로드 인증은 PR 4에 남긴다.
- 환경 준비: 별도 Flutter 3.44.9 / Dart 3.12.2 SDK의 `flutter pub get --enforce-lockfile` 통과.
- 실패 재현: 제품 수정 전 `flutter test --no-pub test/session_refresh_test.dart`에서
  상세·열람·클릭의 동시 401에 refresh 호출수 기대 **1회 / 실제 3회**로 실패했다.
- 시작 시점 상태: 공통 갱신·세션 경합 보호와 회귀 테스트 구현 중. 최종 결과는 아래를 따른다.

<a id="b-be6e1746200b363e"></a>

### PR 3 구현·검증·화면 확인 — 2026-10-06

<a id="b-63a623a79ebfe47d"></a>

- 상태: 구현·로컬 검증 완료, 사용자에게 실제 Chrome 갱신 후 화면과 결과를 공유했다.
  커밋·PR 제목은 `fix: 동시 인증 오류의 토큰 갱신 중복 방지`, PR base는 `FE`다.
- 변경: API 인스턴스마다 하나의 refresh Future를 HTTP 응답·파싱·메모리 반영·저장 콜백 완료까지 공유한다.
  요청 당시 세대·토큰을 확인해 늦은 401은 최신 토큰을 재사용하고, 메서드·쿼리·본문을 유지해 한 번만 재시도한다.
  성공·실패 후 공유 상태를 정리하며 이전 작업 완료가 새 작업을 정리하지 않게 한다.
- 세션 보호: 복원·삭제·신규 발급은 세대를 바꾸고 refresh는 유지한다. 이전 세대의 성공·오류 응답은
  새 계정에 적용하지 않으며 401과 구분되는 취소로 처리한다.
  로그아웃은 진행 중인 갱신·저장을 기다려 최신 토큰을 사용하고, 실패 시에도 현재 토큰으로 시도한다.
  로그아웃 중 새 인증 작업을 막고, 뒤늦은 로그아웃이 새 세션의 저장값과 화면을 초기화하지 않게 했다.
  이 보호는 공통 요청 경로와 세션 발급에 적용하며, multipart 스크린샷 업로드는 PR 4 범위다.
- 제한: refresh의 HTTP 응답 대기는 10초, 저장 콜백은 제한하지 않는다.
  시간 초과 뒤 늦은 HTTP 응답은 세션에 반영하지 않는다. 시간 초과가 실제 서버 요청을 취소하지는 않으므로,
  서버에서 이미 회전했다면 기존 토큰으로 로그아웃해도 해당 서버 세션 해제를 보장하지 못한다.
- 회귀 테스트: `session_refresh_test.dart` **37건**과 기존 저장 테스트의 새 세션 보호 **1건**을 추가했다.
  동시/직접 refresh 공유, 늦은 401, 저장 대기, HTTP 401·503·연결·파싱·콜백 실패와 후속 복구,
  최종 401 재시도 상한, 세대 교체·기존 Future 정리 경합, 로그아웃 대기·실패·새 로그인 경합,
  10초 HTTP 시간 초과와 12초 저장 대기를 가짜 시계로 검증한다.
  기존 PR 2 로그아웃 테스트는 저장 완료 후 최신 토큰으로 로그아웃하도록 기대값을 변경했고,
  별도 만료에 따른 두 번째 refresh와 저장 큐·캐시 초기화 검증은 유지했다.
- 프론트 검증(Flutter **3.44.9** / Dart **3.12.2**):
  - `flutter pub get --enforce-lockfile`: 통과, 원본 잠금파일 유지.
  - `flutter analyze --no-pub`: 최종 **No issues found**.
  - `flutter test --no-pub`: 최종 **100 passed, skip 0**(기존 62 + 신규 38).
  - `flutter build web --no-pub`: 성공, Wasm dry run 성공. 이후 변경은 테스트·문서뿐이다.
  - 기존 SVG `<filter/>`와 CupertinoIcons 폰트 경고가 남아 있다.
- 실제 DB 검증: 최신 main `8c759d1`을 `/private/tmp/clipback-pr3-auth-env.cubijrdz`에 격리했다.
  Docker daemon 미가동으로 PostgreSQL **17.7** 전용 클러스터를 사용했다(기준 16은 미검증).
  두 빈 테스트 DB의 `alembic upgrade head`·`alembic check` 통과,
  전용 `TEST_DATABASE_URL`의 `pytest -q tests/integration/test_auth_flow.py`: **6 passed, skip 0**.
  기존 Starlette/httpx 사용 중단 예정 경고 1건. 원본 `.env`와 개발·운영 DB는 사용하지 않았다.
- Chrome 검증: 웹 `localhost:5187`, 최신 main API `127.0.0.1:50311`, 만료 1분으로 실행했다.
  metadata만 대체하고 외부 HTTP·AI·YouTube 요약을 차단한 전용 환경에서 테스트 링크를 UI로 저장했다.
  만료 후 실제 인증 검사가 만든 401 세 응답을 임시 검증 wrapper의 gate로 모아 방출했다.
  이는 응답 시점만 제어하며 인증·DB·상태 코드를 대체하지 않는다. gate 시간 초과는 없었다.

<a id="b-b9c0889fedf89eb5"></a>

  | 동시 상세 진입 구간 | 실제 결과 |
  | --- | --- |
  | 상세 GET | 401 → 200 |
  | 열람 POST | 401 → 201 |
  | 클릭 POST | 401 → 201 |
  | refresh POST | 1회, 200 |
  | guest POST | 0회 |

<a id="b-5ac55f4aa475a458"></a>

- gate 해제 후 새로고침 구간은 토큰이 다시 만료된 상태였으며, 저장된 회전 토큰으로 refresh 1회 후
  카테고리·피드·프로필·통계가 모두 200이었다. guest 생성은 0회였다.
  DB의 사용자·세션 ID가 같고 `users=1`, `auth_sessions=1`, `contents=1`을 유지했다.
  열람 이벤트·클릭 이벤트·`open_count`는 상세 진입에서 각각 **+1**, 새로고침 이후에도 유지됐다.
- 화면 증거: `frontend/build/verification/pr3/01-before.jpg`, `02-after-refresh.jpg`, `03-restored.jpg`.
  실제 Chrome 캡처이며 생성 이미지가 아니다. `build/`의 로컬 산출물이므로 커밋에서 제외한다.
  해당 홈 화면에서 기존 추천 카드의 13px RenderFlex overflow를 관찰했다. 인증 변경 범위 밖이라 수정하지 않았다.
- 로그: 격리 환경의 `traffic-concurrent-401.jsonl`·`traffic-reload.jsonl`에 method/path/status/timing만 기록했다.
  토큰·헤더·요청 본문은 기록하지 않았다. 검증 후 API·PostgreSQL·Flutter 웹 서버를 종료했다.
- 미검증: PostgreSQL 16, 실제 기기·저장 장치 오류, 실제 OAuth·외부 AI, Railway·운영 API,
  전체 백엔드 테스트 및 최종 FE→main 통합. 원격 GitHub Checks는 PR 생성 후 별도 확인한다.
- 범위 유지: 백엔드·DB·의존성·잠금파일 변경 없음. 사용자 `AGENTS.md` 변경은 그대로 보존한다.
  `git diff --check` 통과, 신규 테스트의 공백 검사 출력 없음(새 파일 차이 종료 코드 1).
  사용자 `AGENTS.md` diff와 잠금파일의 SHA-256이 시작 시점과 같고 화면 3장은 Git 제외 상태다.
  다음 단계는 검증 결과를 기록한 커밋·푸시·일반 PR 생성이며, PR 병합은 수행하지 않는다.

<a id="b-794065020322517b"></a>

### PR 3 커밋·푸시·PR 생성 — 2026-10-06

<a id="b-f5d1074bfa581519"></a>

- 상태: [#39 — fix: 동시 인증 오류의 토큰 갱신 중복 방지](https://github.com/clip-back/clipback/pull/39) 생성.
  `fix/fe-refresh-single-flight` → `FE`의 일반 PR이며 이 작업 대화에 연결했다. 병합은 수행하지 않았다.
- 구현 커밋: `4347e3ec38ea490dee1a42a0aed069d3b8883b9c`. 위 100건의 Flutter 테스트와 6건의 실제 DB 테스트,
  Chrome 화면·요청·DB 결과를 본문에 기록했다. 이후 변경은 이 PR 생성 기록뿐이다.
- 생성 후 확인: 원격 head와 PR head 일치, base `FE`, 관련 6개 파일만 포함,
  충돌 없음(`MERGEABLE`, `CLEAN`). GitHub Checks 기록은 없으며 원격 CI 통과로 취급하지 않는다.
- 사용자 `AGENTS.md`, 잠금파일, 화면·로그 산출물은 PR에 포함하지 않았다. migration은 필요하지 않다.
- 이 링크와 상태 기록을 추가 커밋·푸시하고 최종 원격 head·파일 범위·Checks를 다시 확인한다.
  다음 수정은 PR #39의 FE 병합을 확인한 뒤 PR 4 스크린샷 인증 갱신·재시도를 진행한다.
