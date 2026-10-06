# FE 병합 전 수정 진행 현황

## 1. 목적과 현재 범위

FE의 계정 유지·콘텐츠 저장·재조회 문제를 문제별 PR로 수정하고, 검증 결과를 이 문서에 기록한다.
문서 준비일은 **2026-10-05 (KST)**다. 문서 PR #36과 PR 1의 수정 PR #37은 FE에 병합되었으며,
PR 2의 갱신 토큰 영속 저장은 구현·로컬 검증 후 [수정 PR #38](https://github.com/clip-back/clipback/pull/38)을
생성했으며 리뷰와 FE 병합을 기다린다.
PR 3~10은 미착수이며, 백엔드 API·DB 스키마·기존 데이터는 PR 2에서 변경하지 않는다.

이 문서는 FE 수정 계획과 실행 기록을 관리한다. 화면·실행 안내는
[프론트 README](../frontend/README.md), 백엔드 구현 범위는
[백엔드 MVP 계획](backend-mvp-plan.md)을 참고한다.

### 기준 커밋

| 항목 | 기준 |
| --- | --- |
| 문서 준비 브랜치 | `docs/fe-merge-fixes-plan` |
| 출발점 | `origin/FE` — `41931119f5bfc58c3d1c6c09e2b1a82ba45221b3` |
| 비교 대상 | `origin/main` — `8c759d1f4a02f43966f4d692d0541d5feb74dcdc` |
| 2026-10-05 원격 확인 | FE 전용 3개 / main 전용 60개 커밋으로 분기됨 |

FE의 백엔드 코드는 최신 main보다 이전 상태다. 이후 API 계약 대조와 최종 통합 검증은
그 시점의 최신 main 백엔드를 기준으로 한다. 위 SHA와 과거 결과를 새 검증 결과로 재사용하지 않는다.

## 2. 브랜치·PR 진행 방식

이 작업에서 합의한 흐름은 다음과 같다.

1. 문서 준비 변경을 검토하여 FE에 반영한다.
2. 최신 `origin/FE`에서 해당 문제의 수정 브랜치를 만든다.
3. 실패 재현 테스트를 먼저 추가하고, 최소 수정 후 관련 검사를 실행한다.
4. 해당 PR의 상태·변경 내용·실제 검증 결과를 이 문서에 함께 기록한다.
5. 수정 PR은 **base `FE`**로 검토·병합한다. 병합 여부와 결과 커밋은 다음 작업 시작 시 기록한다.
6. 다음 수정은 갱신된 FE에서 시작한다. PR 2 → 3 → 4는 의존성을 지켜 순서대로 진행한다.
7. 수정이 끝나면 최신 main과의 병합 결과를 검증하고 **최종 `FE → main` PR**을 만든다.

[공통 Git 규칙](git-conventions.md)의 PR base `main` 원칙에 대해,
이 FE 병합 준비 작업의 문서·수정 PR만 base `FE`를 사용하는 예외다. 최종 통합 PR의 base는 `main`이다.
PR 제목은 아래의 한글 Conventional Commits 형식을 사용하며, 하나의 PR에는 해당 수정과 회귀 테스트,
진행 문서 갱신만 포함한다. 2026-10-06 사용자 지시에 따라 앞으로 계획 구현은
검증·문서 기록·커밋·현재 작업 브랜치 푸시까지 진행한다. PR 생성·병합은 요청된 단계에서 수행한다.

## 3. 상태 관리

- **예정:** 수정과 재현 테스트를 시작하지 않음.
- **진행 중:** 재현 또는 구현 중이며 완료 조건을 아직 충족하지 않음.
- **검증 완료:** 해당 PR의 완료 조건을 검증했고, 결과와 미검증 범위를 기록함.
- **PR 생성:** 실제 PR 링크가 있으며 리뷰 또는 병합 대기 중.
- **FE 병합:** FE에 반영된 커밋과 확인 날짜를 기록함. main 통합 완료를 뜻하지 않음.

아래 번호는 작업 식별자이며 GitHub PR 번호가 아니다. 브랜치·PR 링크는 실제 생성 후 채운다.

| 작업 | 우선순위 | 수정 주제 | 선행 작업 | 상태 | 브랜치 / PR |
| --- | --- | --- | --- | --- | --- |
| PR 1 | P1 | 일시 오류에서 기존 세션 보존 | 없음 | FE 병합 | `fix/fe-session-restore` / [#37](https://github.com/clip-back/clipback/pull/37) |
| PR 2 | P1 | 갱신 토큰 영속 저장 | 없음 | PR 생성 | `fix/fe-refresh-persistence` / [#38](https://github.com/clip-back/clipback/pull/38) |
| PR 3 | P1 | 동시 토큰 갱신 중복 방지 | PR 2 | 예정 | 미생성 |
| PR 4 | P1 | 스크린샷 인증 갱신·재시도 | PR 3 | 예정 | 미생성 |
| PR 5 | P1 | 선택 없는 저장의 자동 분류 | 없음 | 예정 | 미생성 |
| PR 6 | P2 | 커서 기반 추가 조회 | 없음 | 예정 | 미생성 |
| PR 7 | P2 | 저장한 스크린샷 원본 재조회 | PR 4 이후 권장 | 예정 | 미생성 |
| PR 8 | P2 | 검색 결과 변경 상태 동기화 | PR 6 이후 권장 | 예정 | 미생성 |
| PR 9 | P2 | 분류 변경 실패 시 상세 복구 | 없음 | 예정 | 미생성 |
| PR 10 | P2 | 카테고리 삭제 안내·동작 일치 | 없음 | 예정 | 미생성 |

## 4. PR별 수정 범위와 완료 조건

코드 위치는 기준 FE의 함수·클래스 이름이다. 작업 시작 시 최신 코드에서 다시 확인한다.
공통 대상 파일은 [main.dart](../frontend/lib/main.dart)와
[clipback_api.dart](../frontend/lib/clipback_api.dart)다.

### PR 1 — `fix: 일시적인 조회 실패 시 기존 세션 보존`

- 위치: `main.dart`의 `_restoreSession()`.
- 수정: 네트워크 오류·503·응답 파싱 실패를 인증 만료와 구분한다. 조회 실패만으로 저장된 세션을
  삭제하거나 새 게스트를 생성하지 않고, 오류 안내와 재시도 경로를 제공한다.
- 완료 조건: 카테고리 조회가 한 번 실패해도 기존 토큰이 유지되고 `/auth/guest` 호출이 없다.
  재시도 성공 시 같은 계정의 데이터를 불러오며, 실제 인증 만료 처리와 구분된다.

### PR 2 — `fix: 갱신된 인증 토큰 영속 저장`

- 위치: `clipback_api.dart`의 `refreshSession()`, `ApiSessionStorage`, `main.dart`의 세션 저장 호출부.
- 수정: refresh 성공 시 새 access·refresh token을 영속 저장한다. `_loadRemoteData()`를 실행해야만
  저장되는 구조를 해소한다.
- 완료 조건: 카테고리 생성 중 401 → refresh → 생성 성공 후 저장소에 새 토큰이 남는다.
  앱 재시작 후 같은 계정으로 복원되고, 저장 실패를 검증 성공으로 취급하지 않는다.

### PR 3 — `fix: 동시 인증 오류의 토큰 갱신 중복 방지`

- 위치: `clipback_api.dart`의 `_request()`, `refreshSession()`.
- 수정: 여러 요청이 하나의 진행 중인 refresh를 공유한다. 이전 access token으로 보낸 요청의
  401이 늦게 도착하면 이미 갱신된 토큰으로 재시도한다.
- 완료 조건: 상세 조회·열람 기록·클릭 기록이 동시에 401을 받아도 refresh는 한 번만 호출되고
  모두 성공한다. 늦은 401과 refresh 실패 후의 다음 요청도 처리되며, 무한 재시도가 없다.

### PR 4 — `fix: 스크린샷 업로드 인증 갱신과 재시도 처리`

- 위치: `clipback_api.dart`의 `uploadScreenshot()`, `main.dart`의 `_runSaveRequest()`.
- 수정: multipart 업로드도 공통 refresh 경로를 사용하고, 재시도할 요청을 새로 구성한다.
  저장 중 401을 새 게스트 생성으로 처리하는 fallback을 제거한다.
- 완료 조건: 유효한 refresh token과 만료된 access token으로 업로드해도 같은 계정으로 저장된다.
  재전송 파일·카테고리·태그가 유지되고 `/auth/guest` 호출이 없다. 인증 복구 실패 시에는 오류를 안내한다.

### PR 5 — `fix: 콘텐츠 저장 시 자동 분류 적용`

- 위치: `main.dart`의 `AddContentSheet`, `_addLinkContent()`, `_addScreenshotContent()`.
- 수정: 사용자 선택이 없으면 `category_ids: []`를 보낸다. 첫 카테고리 강제 지정과 그 이름을
  태그로 자동 주입하는 동작을 제거하고, 결과 표시는 실제 서버 응답을 따른다.
- 완료 조건: 선택 없는 링크·사진 저장은 자동 분류 경로를 사용하고, 명시적 선택은 유지된다.
  YouTube의 비동기 분류와 분류 실패 시 미분류 처리를 성공한 자동 분류로 잘못 표시하지 않는다.
  기존 카테고리 접근 권한·복수 분류·미분류 혼합 거절 계약은 유지한다.

### PR 6 — `fix: 피드 커서 기반 추가 조회 구현`

- 위치: `main.dart`의 `_loadRemoteData()`, `_searchContents()`와 목록 화면, `ClipbackApi.readFeed()`.
- 수정: `next_cursor`로 추가 조회하며, 검색·분류·북마크 조건이나 계정이 바뀌면 해당 목록과 커서를
  초기화한다. 같은 콘텐츠가 중복 표시되지 않도록 한다.
- 완료 조건: 101개 이상 저장한 계정의 오래된 보관·검색·분류·북마크 항목에 접근할 수 있다.
  조건 변경 중 늦게 도착한 응답이 다른 목록에 섞이지 않고, 마지막 페이지에서 추가 요청이 멈춘다.
  현재 로드 수를 전체 개수로 표시하거나 누적 저장 수와 혼용하지 않는다.

### PR 7 — `fix: 저장한 스크린샷 원본 재조회 지원`

- 위치: `main.dart`의 `_contentFromApi()`, `ContentItem`, 상세·원문 화면, `ClipbackApi.readAsset()`.
- 수정: API의 자산 정보를 화면 모델에 보존하고, 인증된 다운로드로 원본을 표시한다.
  선택 직후 메모리에 남아 있는 이미지에만 의존하지 않는다.
- 완료 조건: 저장 확인창을 닫은 뒤 또는 앱을 재시작한 뒤에도 원본 이미지가 보인다.
  토큰 갱신 후 조회, 다른 사용자 자산 접근 거절, 다운로드 실패 안내를 확인한다.

### PR 8 — `fix: 검색 결과의 콘텐츠 변경 상태 동기화`

- 위치: `main.dart`의 `SearchScreen._serverResults`, `_replaceContent()`와 수정·삭제 처리.
- 수정: 성공한 삭제·분류 변경을 검색 결과에도 반영한다. 전역 피드 목록에 없는 검색 항목도
  열린 상세 화면을 서버 응답으로 갱신할 수 있게 한다.
- 완료 조건: 삭제 성공 후 검색 카드가 사라지고, 분류 변경 후 검색·목록·상세가 일치한다.
  첫 페이지 밖의 검색 항목도 상세 데이터가 갱신되며, 실패 시 성공 상태가 남지 않는다.

### PR 9 — `fix: 분류 변경 실패 시 상세 화면 상태 복구`

- 위치: `main.dart`의 `_changeContentCategory()`, `_saveContentCategory()`.
- 수정: 낙관적으로 바꾼 목록과 `_selectedContent`를 실패 시 함께 복구한다.
- 완료 조건: 404·서버 오류·통신 실패 후 목록과 상세가 기존 분류로 돌아가고 오류가 안내된다.
  정상 변경은 서버 응답에 맞게 유지된다.

### PR 10 — `fix: 카테고리 삭제 안내와 화면 동작 일치`

- 위치: `main.dart`의 카테고리 삭제 대화상자와 삭제 처리.
- 수정: 콘텐츠까지 영구 삭제된다는 안내를 바로잡고, 삭제 중 콘텐츠를 목록에서 잘못 제거하는
  동작을 서버 계약에 맞춘다. 백엔드의 콘텐츠 보존 정책은 변경하지 않는다.
- 완료 조건: 카테고리를 삭제해도 콘텐츠는 보존된다. 마지막 분류가 없어지면 미분류로 이동하고,
  다른 분류가 있으면 유지된다. 실패 시 원래 화면 상태가 복구된다.

## 5. 검증과 최종 완료 조건

### 각 수정 PR

- 해당 결함의 실패 재현 → 수정 후 통과를 확인하고, 회귀 테스트를 같은 PR에 포함한다.
- `frontend/`에서 `flutter analyze`와 `flutter test`를 실행한다.
- 루트에서 `git diff --check`와 최종 diff를 확인한다.
- 화면 변경은 `flutter run`으로 검증한 기기·브라우저·시나리오를 기록한다.
  확인하지 못한 환경은 미검증으로 남긴다.
- 인증·저장 계약은 최신 main 백엔드와 대조한다. 대역을 사용한 HTTP·위젯 테스트와
  실제 PostgreSQL HTTP 통합 검증은 구분한다. DB 검증에는 폐기 가능한 전용 테스트 DB만 사용한다.

### SDK와 잠금파일

기준 FE의 `pubspec.lock`은 Dart `>=3.12.0 <4.0.0`, Flutter `>=3.44.0`을 요구한다.
작업 시작 시 실제 SDK와 잠금파일 요구 조건을 확인하고, 잠금파일 그대로 검증할 수 있는 환경을 사용한다.
의존성을 재해석했다면 변경된 환경을 명시하고 원본 잠금파일 검증으로 보고하지 않는다.

```bash
# frontend/에서 실행: 실제 버전과 결과를 아래 실행 기록에 남긴다.
flutter --version
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
flutter build web --no-pub
```

### 최종 FE → main 통합

- 10개 수정의 상태·PR 링크·병합 커밋을 확인한다.
- 최신 main과 FE의 병합 충돌뿐 아니라 병합 결과의 API 계약·회귀 테스트를 확인한다.
- 웹 빌드와 대상 플랫폼의 저장 → 검색·분류·북마크 → 재열람 → 삭제 흐름을 검증한다.
- 로컬 테스트, GitHub Checks, 실제 API·CORS·외부 AI·실기기 결과를 각각 기록한다.
  실행하지 않은 항목은 이유와 다음 확인 작업을 남기며 완료로 표시하지 않는다.

## 6. 실행 기록

### 이전 리뷰 기록 — 2026-10-02

- 기준: 위 FE `4193111`과 main `8c759d1`을 합친 임시 검토본. Git 병합 충돌은 없었다.
- Flutter 3.35.7 / Dart 3.9.2에서 원본 잠금파일 검증은 실패했다. 임시 복사본에서
  의존성 14개를 재해석한 뒤 정적 분석·웹 빌드는 통과했다.
- 임시 HTTP·위젯 테스트 8건 중 공개 게스트 생성·카테고리 배열 조회 2건은 통과했고,
  PR 1~6에 대응하는 결함 재현 6건은 실패했다. PR 7~10은 코드 경로로 확인했다.
- 재현 테스트는 임시 검토본에만 작성되었으며 FE에 추가되거나 결함이 수정된 상태가 아니다.
- 원본 잠금파일 그대로의 빌드, 실제 기기·운영 API·CORS는 미검증이었다.
  이 기록은 과거 리뷰 근거이며 이번 문서 준비에서 재실행한 결과가 아니다.

### 문서 준비 — 2026-10-05

- 상태: 브랜치·진행 문서 준비, 수정 PR 1~10 미착수.
- 브랜치: 최신 `origin/FE`에서 `docs/fe-merge-fixes-plan` 생성.
- 변경: 이 진행 문서 추가 및 프론트 README에 문서 링크 추가.
- 확인: 원격 FE·main SHA, 분기 상태, 기존 진행 문서와 중복 여부 확인.
- 문서 검증: 상대 링크·코드 식별자·SDK 조건 대조 통과. `git diff --check` 통과.
  새 문서의 공백 검사는 `git diff --no-index --check /dev/null docs/fe-merge-fixes.md`로
  확인했으며 공백 오류 출력은 없었다(새 파일 차이를 나타내는 종료 코드 1).
- 미실행: 문서만 변경하므로 Flutter·백엔드 테스트는 실행하지 않음. 원격 CI·운영·실기기 검증도 미실행.
- 문서 커밋: `docs: FE 병합 전 수정 진행 문서 추가` — 이 문서와 프론트 README만 포함한다.
- 원격 상태(문서 준비 커밋 작성 시점): 푸시·PR 생성·병합 미실행.
  기존 사용자 `AGENTS.md` 변경은 커밋에서 제외한다.
- 다음 작업: 문서 준비 변경 반영 후 PR 1의 실패 재현과 세션 보존 수정.

### 문서 PR 생성 — 2026-10-05

- 상태: PR 생성, FE 병합 대기. 수정 PR 1~10은 모두 미착수.
- PR: [#36 — docs: FE 병합 전 수정 진행 문서 추가](https://github.com/clip-back/clipback/pull/36).
- 브랜치: `docs/fe-merge-fixes-plan` → `FE`. 문서 준비 커밋 `e6d04b3`을 origin에 푸시했다.
- 변경: 진행 문서와 프론트 README 두 파일만 포함하며, 기존 사용자 `AGENTS.md` 변경은 제외했다.
- 검증: 상대 링크와 FE 대비 변경 범위 확인, `git diff --check origin/FE...HEAD` 통과.
- GitHub Checks: PR 생성 직후 조회 시 검사 기록 없음. 로컬 문서 검증과 구분한다.
- 미실행: 문서만 변경하여 앱 테스트·빌드·운영·실기기 검증은 미실행. PR 병합도 미실행.
- 다음 작업: 문서 PR의 FE 병합 확인 후 최신 FE에서 PR 1용 수정 브랜치를 만든다.

### 문서 PR FE 병합 확인 — 2026-10-05

- PR [#36](https://github.com/clip-back/clipback/pull/36)은 2026-10-05 16:29 KST에 FE에 병합되었다.
- 병합 커밋: `57488ab8fbd90b8d1332b1bb444c5490cb77f3b1`.
- 위 병합 커밋이 현재 수정 브랜치 `fix/fe-session-restore`의 출발점이다.

### PR 1 구현 — 2026-10-05

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

### PR 1 커밋·푸시·PR 생성 — 2026-10-05

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

### PR 1 FE 병합 확인 및 PR 2 시작 — 2026-10-05

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

### PR 2 구현 및 검증 — 2026-10-05

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

### PR 2 커밋·푸시 — 2026-10-06

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

### PR 2 PR 생성 — 2026-10-06

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

### 다음 작업 기록 양식

작업할 때마다 아래 양식을 복사해 날짜별로 추가하고, 3절의 상태 표도 함께 갱신한다.
실제 토큰·키·사용자 데이터는 기록하지 않는다.

```text
날짜 / 작업 ID / 현재 상태:
브랜치 / 출발 FE SHA / 비교 main SHA:
변경 파일·동작:
재현 시나리오 / 수정 전 결과:
실행 환경·명령 / 수정 후 결과:
미검증·skip 항목 / 이유:
커밋 / PR URL / FE 병합 커밋:
남은 문제 / 다음 작업:
```
