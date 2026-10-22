# main과 FE 동기화

- 최초 기록일: 2026-10-06
- 영역: 통합
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-dfa363314b8abaef"></a>

### main → FE 동기화 시작 — 2026-10-06

<a id="b-7b4b38828076a16a"></a>

- 사용자 요청: main을 FE에 먼저 병합하고 합쳐진 코드로 테스트한 뒤 FE 대상 PR을 생성한다.
- 출발 FE: `8f3f2f4ed3ae8b372f40fc4cc5aed8c8621c3209`.
  PR #39는 2026-10-06 11:56 KST에 이 커밋으로 병합되었다.
- 병합 main: `8c759d1f4a02f43966f4d692d0541d5feb74dcdc`. 시작 시 FE 전용 16개 / main 전용 60개 커밋이다.
- 브랜치: 별도 worktree의 `chore/fe-sync-main`. 원래 체크아웃과 사용자 `AGENTS.md`는 건드리지 않는다.
- 충돌: `frontend/README.md`의 현재 구현 설명과 실행·연동 안내만 충돌했다.
  FE의 PR 1~3 설명·명령과 main의 API·추천·배포 경계를 함께 보존했고, 오래된 mock 전용 설명을 바로잡았다.
  루트 README도 현재 API 연동 상태에 맞췄다.
- 범위: 백엔드·CI·migration·공유 테스트 앱 제거는 main에서 이미 완료된 변경을 그대로 가져온다.
  프론트 제품 코드·테스트·의존성·잠금파일은 FE 그대로 유지한다. PR 4~10 구현을 섞지 않는다.
- 프론트 검증: Flutter 3.44.9 / Dart 3.12.2의 `flutter pub get --enforce-lockfile`,
  `flutter analyze --no-pub`(No issues found), `flutter test --no-pub`(**100 passed, skip 0**),
  `flutter build web --no-pub`(Wasm dry run 포함) 모두 통과했다. 기존 SVG·CupertinoIcons 폰트 경고는 남아 있다.
- 백엔드 검증 진행: 전용 DB migration·스키마 검사·전체 pytest·Ruff·compileall 및 로컬 API 연결 확인.
  Docker daemon 미가동으로 로컬은 PostgreSQL 17.7을 사용한다.
  FE 대상 PR은 자동 CI 대상이 아니므로, 푸시 후 기존 workflow_dispatch로 PostgreSQL 16·Docker 검증을 병행한다.
  백엔드와 원격 검사 결과는 완료 후 아래에 기록한다.
- 동기화 PR의 base는 `FE`이며 원격 FE·main 병합은 PR 검토 후 별도로 진행한다.
  main의 공통 이력을 보존하도록 동기화 PR은 merge commit 방식으로 병합하는 것을 권장한다.
- 정적 계약 검토: 주요 인증·카테고리·피드·콘텐츠·계정·통계 요청/응답은 일치한다.
  기존 PR 4~10 문제는 남아 있다. 특히 카테고리 이름을 태그로 자동 주입하면 `###`가 태그 정규화 후
  빈 값으로 거절될 수 있으므로, PR 5의 자동 태그 제거와 회귀 테스트에 포함한다. 이번 동기화에서 수정하지 않는다.

<a id="b-dcc563131bc19bd9"></a>

### main → FE 동기화 로컬 화면 확인 — 2026-10-06

<a id="b-f1f4cd33bbe396dd"></a>

- 병합 커밋 `a016c864b394fffd0909e866954cf7acd919ee62`는 FE `8f3f2f4`와 main `8c759d1`을 부모로 갖는다.
  충돌 해결·문서 보정 외에 backend는 main, 프론트 제품 코드·테스트·의존성은 FE와 동일하다.
- Chrome에서 `localhost:5191` 프론트와 병합 worktree의 `127.0.0.1:50311/api/v1` 백엔드를 연결했다.
  별도 전용 DB를 사용하고 metadata만 테스트 응답으로 대체했으며 외부 HTTP·AI·YouTube worker는 비활성화했다.
- API 기동 전 초기 오류 화면 → 기동 후 다시 시도 → 게스트 생성 → 링크 저장(201) →
  새로고침 후 콘텐츠 복원 → 카드 상세(200)·열람(201)·클릭(201)을 확인했다.
  새로고침의 카테고리·피드·프로필·통계 조회는 모두 200이고 추가 게스트 생성은 없었다.
- 실제 화면: 원래 체크아웃의 `frontend/build/verification/fe-main/01-saved-detail.jpg`,
  `02-restored-home.jpg`, `03-live-detail.jpg`. Git 제외 산출물이며 사용자에게 대화에서 공유한다.
  기존 홈 추천 카드의 13px RenderFlex overflow와 자동 분류 표시 문제(PR 5)는 남아 있다.
- 원격 CI: [Backend Validation 실행](https://github.com/clip-back/clipback/actions/runs/37407420325)을
  작업 브랜치에서 수동 실행했다. FE 대상 자동 trigger는 추가하지 않았다. 최종 결과는 다음 기록에 남긴다.

<a id="b-62ccc11bbad23d3f"></a>

### main → FE 동기화 검사 결과 — 2026-10-06

<a id="b-2b4d21b3ef8b2d98"></a>

- 로컬 백엔드(Python 3.12, PostgreSQL 17.7): `ruff check app alembic tests` 통과,
  전용 `TEST_DATABASE_URL`의 `pytest -q` **878 passed, skip 0**, `python -m compileall app alembic tests` 통과.
  기존 Starlette/httpx 사용 중단 예정 경고 1건. 두 빈 전용 DB의 전체 `alembic upgrade head`·`alembic check` 통과.
  처음 새 bytecode 캐시 경로에서 import가 지연된 시도는 테스트 시작 전에 중단했고, 기존 캐시를 사용한 전체 재실행 결과다.
- 원격 CI [37407420325](https://github.com/clip-back/clipback/actions/runs/37407420325):
  병합 커밋 `a016c86`에서 **5개 job 모두 success**.
  - Python 3.11·3.12 각각 **524 passed, 354 skipped**. DB URL 없는 일반 테스트 job의 skip이며 DB 통과로 세지 않는다.
  - PostgreSQL **16** migration job의 전체 upgrade·schema check 통과, 저장소·HTTP 통합 테스트 **355 passed, skip 0**.
  - Docker 이미지 빌드·컨테이너 재생성 후 인증/콘텐츠/이미지 바이트 영속성·새 볼륨의 DB/파일 쌍 복원 모두 통과.
  - lint·compile도 통과. FE 대상 자동 trigger를 추가하지 않고 기존 workflow_dispatch를 사용했다.
- Chrome DB 확인: 사용자·인증 세션·콘텐츠 각 1개, 저장·열람·클릭 이벤트와 `open_count` 각각 1.
  프론트 웹 서버·전용 API·PostgreSQL은 검증 후 종료했다. 토큰·인증 헤더는 기록하지 않았다.
- 병합 범위 검사: `git diff --check` 통과. 백엔드·CI·Compose·도구 정리는 main과 동일,
  프론트 제품 코드·테스트·플랫폼·의존성·잠금파일은 FE와 동일하다. 사용자 `AGENTS.md` 원본 diff도 보존했다.
- migration: 새 revision은 만들지 않았다. main의 기존 12개 revision을 동기화하므로 이전 FE DB는
  기존 migration 적용이 필요하다. 운영 cutover와 기존 데이터 변환은 [추천 운영 절차](../content-recommendation-plan.md)를 따른다.
  이번 검증은 폐기 가능한 DB만 사용했고 개발·운영 DB에는 적용하지 않았다.
- 미검증: Railway/운영 배포, 실제 OAuth·외부 AI, Android/iOS 실기기, 실제 사용자 데이터의 migration,
  최종 FE→main 병합. 기존 후속 PR 4~10 및 UI 경고를 해결했다는 의미는 아니다.

<a id="b-6be6e522f636b0b0"></a>

### main → FE 동기화 PR 생성 — 2026-10-06

<a id="b-1e9869da9e7c809e"></a>

- [#40 — chore: main 변경사항을 FE에 동기화](https://github.com/clip-back/clipback/pull/40) 생성.
  `chore/fe-sync-main` → `FE`의 일반 PR이며 작업 대화에 연결했다. 원격 FE·main 병합은 실행하지 않았다.
- 구현/병합 커밋 `a016c86`에서 위 로컬·원격 검사를 완료했다. 이 추가 커밋은 검증 결과·PR 링크 기록만 포함한다.
- 최종 문서 푸시 후에도 원격 head·파일 범위·충돌 여부를 확인하고, 같은 기존 CI를 최종 head에서 다시 실행한다.
  실제 최종 Checks 결과는 PR Checks와 작업 대화에 보고한다.
- 사용자 `AGENTS.md`와 원래 작업 브랜치는 그대로 유지했다. 다음 수정은 PR #40의 FE 병합을 확인한 뒤 시작한다.
