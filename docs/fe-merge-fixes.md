# FE 병합 전 수정 진행 현황

## 1. 목적과 현재 범위

FE의 계정 유지·콘텐츠 저장·재조회 문제를 문제별 PR로 수정하고, 검증 결과를 이 문서에 기록한다.
문서 준비일은 **2026-10-05 (KST)**다. 문서 PR #36과 PR 1의 수정 PR #37은 FE에 병합되었으며,
PR 2의 [수정 PR #38](https://github.com/clip-back/clipback/pull/38)도 FE에 병합되었다.
PR 3의 [수정 PR #39](https://github.com/clip-back/clipback/pull/39)도 2026-10-06 FE에 병합되었다.
[동기화 PR #40](https://github.com/clip-back/clipback/pull/40)은 2026-10-06 FE에 병합되었다.
[수정 PR #41](https://github.com/clip-back/clipback/pull/41)은 2026-10-06 FE에 병합되었다.
[수정 PR #42](https://github.com/clip-back/clipback/pull/42)는 2026-10-06 FE에 병합되었다
(`550833e01253010102e05fee614bb724b222e376`). PR 6의
[수정 PR #43](https://github.com/clip-back/clipback/pull/43)은 2026-10-06 FE에 병합되었다
(`da895d34f7623a095045127d39f34a150d6f69dc`). PR 7의 저장한 스크린샷 원본 조회
[수정 PR #44](https://github.com/clip-back/clipback/pull/44)는 2026-10-06 FE에 병합되었다
(`ab45071aaefc9defb89938a1e8fd99e727f01a22`). PR 8과 PR 9는 공통 콘텐츠 변경 처리로 통합하여
완료했다. [수정 PR #45](https://github.com/clip-back/clipback/pull/45)는 2026-10-06 FE에 병합되었다
(`6fbfcce4b79fc64342a93fad98062319cd3b9198`). PR 10의 카테고리 삭제 안내·콘텐츠 보존 수정은
[PR #46](https://github.com/clip-back/clipback/pull/46)으로 검토 중이다.
백엔드·DB·HTTP 계약·의존성·잠금파일은 변경하지 않는다.

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

위 표는 최초 계획의 기준이다. 2026-10-06 동기화 브랜치는 FE `8f3f2f4`에 main `8c759d1`을 병합한다.
이후에는 동기화된 FE의 프론트·백엔드를 함께 검증하며, 최종 main 병합 전에도 최신 변경을 확인한다.
위 SHA와 과거 결과를 새 검증 결과로 재사용하지 않는다.

## 2. 브랜치·PR 진행 방식

이 작업에서 합의한 흐름은 다음과 같다.

1. 문서 준비 변경을 검토하여 FE에 반영한다.
2. 최신 `origin/FE`에서 해당 문제의 수정 브랜치를 만든다.
3. 실패 재현 테스트를 먼저 추가하고, 최소 수정 후 관련 검사를 실행한다.
4. 해당 PR의 상태·변경 내용·실제 검증 결과를 이 문서에 함께 기록한다.
5. 수정 PR은 **base `FE`**로 검토·병합한다. 병합 여부와 결과 커밋은 다음 작업 시작 시 기록한다.
6. 다음 수정은 갱신된 FE에서 시작한다. PR 2 → 3 → 4는 의존성을 지켜 순서대로 진행한다.
7. PR 3 이후 main을 FE에 먼저 동기화하고 통합 테스트한 뒤, 이후 수정은 동기화된 FE에서 시작한다.
8. 수정이 끝나면 최신 main과의 병합 결과를 다시 검증하고 **최종 `FE → main` PR**을 만든다.

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
| PR 2 | P1 | 갱신 토큰 영속 저장 | 없음 | FE 병합 | `fix/fe-refresh-persistence` / [#38](https://github.com/clip-back/clipback/pull/38) |
| PR 3 | P1 | 동시 토큰 갱신 중복 방지 | PR 2 | FE 병합 | `fix/fe-refresh-single-flight` / [#39](https://github.com/clip-back/clipback/pull/39) |
| 동기화 | P1 | main → FE 병합·통합 검증 | PR 3 | FE 병합 | `chore/fe-sync-main` / [#40](https://github.com/clip-back/clipback/pull/40) |
| PR 4 | P1 | 스크린샷 인증 갱신·재시도 | 동기화 | FE 병합 | `fix/fe-screenshot-auth` / [#41](https://github.com/clip-back/clipback/pull/41) |
| PR 5 | P1 | 선택 없는 저장의 자동 분류 | PR 4 | FE 병합 | `fix/fe-auto-category` / [#42](https://github.com/clip-back/clipback/pull/42) |
| PR 6 | P2 | 커서 기반 추가 조회 | 없음 | FE 병합 | `fix/fe-feed-pagination` / [#43](https://github.com/clip-back/clipback/pull/43) |
| PR 7 | P2 | 저장한 스크린샷 원본 재조회 | PR 4 이후 권장 | FE 병합 | `fix/fe-screenshot-original` / [#44](https://github.com/clip-back/clipback/pull/44) |
| PR 8·9 | P2 | 콘텐츠 변경 상태 동기화·실패 복구 | PR 6·7 | FE 병합 | `fix/fe-content-state-sync` / [#45](https://github.com/clip-back/clipback/pull/45) |
| PR 10 | P2 | 카테고리 삭제 안내·동작 일치 | PR 8·9 | PR 생성 | `fix/fe-category-delete` / [#46](https://github.com/clip-back/clipback/pull/46) |

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
  `###`처럼 카테고리로는 유효하지만 태그 정규화 시 빈 값이 되는 이름도 저장되는지 회귀 검증한다.

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

### PR 8·9 — `fix: 콘텐츠 변경 상태 동기화 및 실패 복구`

- PR 6의 성공 후 동일 조건 첫 페이지 재조회는 유지하고, 남은 낙관적 변경·연속 입력·실패 복구를 다룬다.
  기존 PR 9의 목록·열린 상세 분류 복구를 같은 공통 처리에 포함한다.
- 같은 콘텐츠의 북마크·분류·삭제는 처리와 후속 조회가 끝날 때까지 잠그고, 다른 콘텐츠·탐색은 허용한다.
  북마크·분류는 즉시 반영 후 필드 단위로 복구하고, 삭제는 서버 성공 후 제거한다.
- 진행 중·완료한 변경은 먼저 시작한 피드·상세 응답으로 되돌리지 않는다. 이전 읽기가 끝나면 보호 상태를
  정리하며, 계정·검색 조건이 바뀐 목록에 과거 항목을 삽입하지 않는다.
- 완료 조건: HTTP·연결·파싱 실패에서 목록·상세·북마크 집합이 함께 복구되고 잠금이 해제된다.
  성공 후 조회 실패는 쓰기 성공을 취소하지 않으며, 최종 401에서도 기존 계정을 보존한다.
- 연결 종료·응답 파싱 실패는 서버 롤백을 보장하지 않는다. 화면은 마지막 확인값으로 복구하고
  다음 정상 조회에서 실제 서버 상태를 반영한다. 카테고리 자체의 삭제·안내는 PR 10에 남긴다.

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

### PR 2 FE 병합 확인 및 PR 3 시작 — 2026-10-06

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

### PR 3 구현·검증·화면 확인 — 2026-10-06

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

  | 동시 상세 진입 구간 | 실제 결과 |
  | --- | --- |
  | 상세 GET | 401 → 200 |
  | 열람 POST | 401 → 201 |
  | 클릭 POST | 401 → 201 |
  | refresh POST | 1회, 200 |
  | guest POST | 0회 |

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

### PR 3 커밋·푸시·PR 생성 — 2026-10-06

- 상태: [#39 — fix: 동시 인증 오류의 토큰 갱신 중복 방지](https://github.com/clip-back/clipback/pull/39) 생성.
  `fix/fe-refresh-single-flight` → `FE`의 일반 PR이며 이 작업 대화에 연결했다. 병합은 수행하지 않았다.
- 구현 커밋: `4347e3ec38ea490dee1a42a0aed069d3b8883b9c`. 위 100건의 Flutter 테스트와 6건의 실제 DB 테스트,
  Chrome 화면·요청·DB 결과를 본문에 기록했다. 이후 변경은 이 PR 생성 기록뿐이다.
- 생성 후 확인: 원격 head와 PR head 일치, base `FE`, 관련 6개 파일만 포함,
  충돌 없음(`MERGEABLE`, `CLEAN`). GitHub Checks 기록은 없으며 원격 CI 통과로 취급하지 않는다.
- 사용자 `AGENTS.md`, 잠금파일, 화면·로그 산출물은 PR에 포함하지 않았다. migration은 필요하지 않다.
- 이 링크와 상태 기록을 추가 커밋·푸시하고 최종 원격 head·파일 범위·Checks를 다시 확인한다.
  다음 수정은 PR #39의 FE 병합을 확인한 뒤 PR 4 스크린샷 인증 갱신·재시도를 진행한다.

### main → FE 동기화 시작 — 2026-10-06

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

### main → FE 동기화 로컬 화면 확인 — 2026-10-06

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

### main → FE 동기화 검사 결과 — 2026-10-06

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
  기존 migration 적용이 필요하다. 운영 cutover와 기존 데이터 변환은 [추천 운영 절차](content-recommendation-plan.md)를 따른다.
  이번 검증은 폐기 가능한 DB만 사용했고 개발·운영 DB에는 적용하지 않았다.
- 미검증: Railway/운영 배포, 실제 OAuth·외부 AI, Android/iOS 실기기, 실제 사용자 데이터의 migration,
  최종 FE→main 병합. 기존 후속 PR 4~10 및 UI 경고를 해결했다는 의미는 아니다.

### main → FE 동기화 PR 생성 — 2026-10-06

- [#40 — chore: main 변경사항을 FE에 동기화](https://github.com/clip-back/clipback/pull/40) 생성.
  `chore/fe-sync-main` → `FE`의 일반 PR이며 작업 대화에 연결했다. 원격 FE·main 병합은 실행하지 않았다.
- 구현/병합 커밋 `a016c86`에서 위 로컬·원격 검사를 완료했다. 이 추가 커밋은 검증 결과·PR 링크 기록만 포함한다.
- 최종 문서 푸시 후에도 원격 head·파일 범위·충돌 여부를 확인하고, 같은 기존 CI를 최종 head에서 다시 실행한다.
  실제 최종 Checks 결과는 PR Checks와 작업 대화에 보고한다.
- 사용자 `AGENTS.md`와 원래 작업 브랜치는 그대로 유지했다. 다음 수정은 PR #40의 FE 병합을 확인한 뒤 시작한다.

### PR 4 시작 — 2026-10-06

- PR #40은 2026-10-06 12:15 KST, `a7dceba1fb8c5f00c6923a63e010ce7093e7a91a`로 FE에 병합되었다.
- 위 최신 FE에서 `fix/fe-screenshot-auth`를 만들었다. 깨끗한 기존 worktree를 재사용하고
  원래 체크아웃의 사용자 `AGENTS.md` 변경은 보존한다. 비교 main은 `8c759d1`이다.
- 목표: multipart도 PR 3의 공통 인증·세대·로그아웃 보호를 사용하고, 저장 콜백 완료 후 401을 한 번만 재시도한다.
  파일·분류·태그를 snapshot하고 매번 새 multipart 요청을 만든다. 합의대로 첫 값만 전송하던 복수 목록도 수정한다.
- 저장의 최종 401에서 계정을 삭제하고 새 게스트로 재저장하는 경로는 링크·사진 모두 제거한다.
  최초 세션 없음의 게스트 생성, 선택 입력 유지, 기존 오류 안내와 PR 2 저장 실패 배너는 유지한다.
- 자동 재전송은 인증 401에만 한 번 허용한다. timeout·연결 오류·다른 HTTP 오류는 자동 재전송하지 않는다.
  서버 저장 취소 및 수동 재시도의 중복 방지는 보장하지 않으며 백엔드 idempotency 기능은 추가하지 않는다.
- 순서: 업로드 refresh 누락·복수 목록 누락·최종 401 게스트 전환을 먼저 재현 → 구현 →
  Flutter/전용 DB/Chrome 실제 검증 → 화면 공유 → 커밋·푸시·FE 대상 일반 PR → 최종 head CI.
- 환경 준비: Flutter 3.44.9 / Dart 3.12.2, `flutter pub get --enforce-lockfile` 통과.
  사용자 `AGENTS.md` diff와 잠금파일의 시작 SHA-256을 보관했다.
- 실패 재현: 새 `screenshot_auth_test.dart`를 제품 수정 전에 실행해 **0 passed / 3 failed**를 확인했다.
  업로드 401에서 refresh 기대 1회/실제 0회, 분류·태그 두 값 기대/각 첫 값만 전송,
  최종 401의 새 게스트 기대 0회/실제 1회였다. FilePicker 대역 초기화 오류를 먼저 고친 뒤 제품 실패만 확인했다.

### PR 4 구현·검증 — 2026-10-06

- `clipback_api.dart`: JSON의 인증 처리를 `_sendWithSessionRetry()`로 추출해 multipart와 공유한다.
  세션 세대·로그아웃 보호, 진행 중인 refresh와 저장 콜백 대기, 늦은 이전 토큰의 401 처리와 1회 재시도를 유지했다.
  파일 바이트·분류·태그를 복사하고 매 시도마다 요청과 파일 part를 새로 만든다.
  분류·태그는 filename 없는 반복 form part로 순서·중복·한글을 모두 보낸다.
- `main.dart`: 공통 저장 함수의 최종 401 새 게스트 전환을 제거했다. 링크·사진 입력과 계정을 유지한다.
  최초 세션 없음의 게스트 생성과 PR 1 초기 복원 정책은 변경하지 않았다.
- `screenshot_auth_test.dart`: 먼저 실패한 세 사례를 포함해 **48건**을 추가했다.
  실제 직렬화된 multipart의 전체 값·파일·입력 snapshot, 동시 JSON/업로드 401과 저장 콜백 대기,
  늦은 401, 갱신 실패 후 재사용, 최종 401, 일반 오류, send/body/refresh timeout,
  세션 교체·삭제·로그아웃 경합, 입력 보존·중복 제출·저장 실패 배너를 확인했다.
  시간 경합은 Completer와 가짜 시계를 사용하며 실제 10초 대기에 의존하지 않는다.
- Flutter 3.44.9 / Dart 3.12.2에서 다음을 실행했다.
  - `flutter pub get --enforce-lockfile`: 통과, 잠금파일 변경 없음.
  - `flutter analyze --no-pub`: 통과, 이슈 0. 새 테스트의 불필요 import 1건을 제거한 뒤 재검사했다.
  - `flutter test --no-pub`: 기존 PR 1~3을 포함해 **148 passed**, 실패·skip 0.
  - `flutter build web --no-pub`: 통과. 기존 CupertinoIcons 폰트 경고가 남아 있다.
  - 변경 Dart 파일 포맷, `git diff --check`와 새 테스트 파일 별도 whitespace 검사 통과.
- 동기화된 같은 브랜치 백엔드를 사용했다. Docker daemon을 사용할 수 없어 **PostgreSQL 17.7**의
  새 전용 cluster와 테스트/Chrome DB를 각각 준비했다. 두 DB 모두 migration 전체 upgrade와 `alembic check` 통과.
  `tests/integration/test_auth_flow.py`, `test_upload_and_isolation.py`,
  `test_content_category_validation.py`를 함께 실행해 **22 passed, skip 0**, Starlette/httpx 경고 1건이었다.
  PostgreSQL 16·Docker 검증은 최종 원격 head의 기존 Backend Validation workflow에서 별도로 확인한다.
- Chrome에서는 전용 API·파일 저장소·1분 access token을 사용했다. OCR은 고정 응답 대역,
  외부 HTTP·AI·YouTube worker는 비활성화했다. 확장 파일 업로드 권한 대신 Chrome 기본 파일 창으로
  77-byte PNG를 선택했다. 토큰·인증 헤더를 캡처하거나 기록하지 않았다.

| 실제 Chrome 검증 구간 | API·DB 확인 결과 |
| --- | --- |
| 만료된 토큰으로 사진 저장 1회 | 업로드 `401 → 201`, 그 사이 refresh `200` 1회, 추가 게스트 0회 |
| 저장 후 DB·파일 확인 | 기존 사용자·세션 유지, 콘텐츠·첨부파일·저장 이벤트·파일 각각 1건, 원본 바이트 일치 |
| 앱 새로고침 | 기존 계정·저장 콘텐츠 복원, 카테고리·피드·프로필·통계 조회 200 |
| 전용 refresh 세션 만료 후 사진 저장 | 업로드 401 → refresh 401, 재업로드·추가 게스트 없음, 사진·계정·저장 버튼 유지 |
| 최종 실패 후 DB·파일 확인 | 기존 1건씩 유지, 신규 콘텐츠·첨부파일·이벤트·파일 없음 |

- 실제 Chrome 캡처는 대화에 이미지로 공유했다. 로컬 경로는 원래 체크아웃의 ignored 디렉터리
  `frontend/build/verification/pr4/01-selected.jpg`, `02-saved.jpg`, `03-restored.jpg`, `04-auth-failed.jpg`다.
  화면·서버 로그·테스트 DB 파일은 커밋하지 않는다.
- 기존 홈 추천 카드에서 13px overflow가 관찰됐으며 이번 인증 수정 범위에는 포함하지 않았다.
  사진 저장 완료 화면의 링크 문구, 기본 분류, 저장된 원본 표시도 이번 PR에서 재설계하지 않았다.
- 한계: timeout·연결 종료·세션 변경은 서버의 저장 취소를 보장하지 않는다. 수동 재시도 중복 방지는 미구현이다.
  운영 배포·실제 OCR/AI·OAuth·실기기 검증은 수행하지 않았다. migration·백엔드·의존성 변경은 없다.
- 관련 5개 파일을 `4a97350`으로 커밋·푸시하고 FE 대상 일반 [PR #41](https://github.com/clip-back/clipback/pull/41)을 생성했다.
  원래 체크아웃의 사용자 `AGENTS.md`와 잠금파일 SHA-256이 시작 값과 같음을 확인했다.
- 이 PR 링크 기록을 추가 푸시한 최종 head에서 기존 Backend Validation을 수동 실행한다.
  실제 CI 결과와 실행 링크는 PR 본문·작업 대화에 기록한다. PR을 병합하지 않는다.
- Chrome/API/전용 PostgreSQL 검증 프로세스는 정상 종료했다. 임시 DB·로그·원본 PNG는 로컬에 보관한다.

### PR 5 시작 — 2026-10-06

- PR #41은 2026-10-06 12:54 KST, `9cea2589c408eb675a49d7786476b64f535ec765`로 FE에 병합되었다.
  위 최신 FE에서 `fix/fe-auto-category`를 만들었다. 비교 main은 `8c759d1`이다.
- 저장 화면의 첫 일반 카테고리 강제 지정과 이름 태그 주입을 제거한다. 선택 없는 링크·사진은
  빈 카테고리·태그 목록으로 저장하고, 명시적 카테고리와 API 복수 목록 계약은 유지한다.
- `summary_status`를 클라이언트 모델에 보존하고 실제 카테고리와 YouTube 처리 상태를 표시한다.
  고정 자동 분류 성공 문구와 작동하지 않는 변경 장식은 제거한다.
- 사용자 선택에 따라 저장 전 수동 선택 UI와 자동 폴링은 추가하지 않는다. 상세 화면에서 수동 변경하며,
  비동기 결과는 기존 상세 조회·앱 새로고침에서 반영한다. 초기 저장 후 분류 PUT은 보내지 않는다.
- Flutter 3.44.9 / Dart 3.12.2의 `flutter pub get --enforce-lockfile` 통과.
  사용자 `AGENTS.md` diff와 잠금파일 SHA-256이 PR 4 종료 값과 같음을 확인했다.
- 순서: 잘못된 요청·성공 문구 재현 → 최소 구현 → Flutter·전용 DB·Chrome 검증 →
  화면 공유·커밋·푸시·FE 대상 일반 PR → PR 링크 기록 후 최종 head 원격 CI.
- 제품 수정 전 `content_auto_category_test.dart`는 **0 passed / 3 failed**였다.
  링크 JSON과 사진 multipart에 첫 카테고리 ID `101`·이름 태그가 실제 전송됐으며,
  미분류 결과에도 고정 자동 분류 성공 문구가 표시되는 제품 오류를 확인했다.
- 구현: 저장 콜백은 선택적 카테고리를 받으며 현재 저장 화면은 선택 없이 호출한다.
  카테고리 이름 태그 주입을 제거하고 `summary_status`를 모델·복사 경로에 보존했다.
  확인창은 처리 중 안내·미분류·저장된 카테고리를 구분하고 상세 화면의 변경 경로를 안내한다.
  기존 자동 선택에만 쓰이던 저장창 인자와 마이 화면의 카테고리 전달 인자를 정리했다.

### PR 5 구현·검증 — 2026-10-06

- 새 `content_auto_category_test.dart`의 최초 재현 3건은 수정 후 모두 통과했다. 총 **40건**으로 확장해
  선택 없는 JSON·실제 multipart, 명시적 분류와 복수 값 계약, `###` 이름, 서버 분류 표시,
  요약 상태 기본값·복사, YouTube 모든 처리 상태와 미분류 조합, 30초 동안 폴링·분류 PUT 없음,
  다음 상세 조회와 새 앱 인스턴스의 완료 결과 반영을 확인했다.
  PR 4 테스트는 앱의 기본 전송값과 제거된 저장창 인자만 수정했으며 명시적 복수 값 검증은 유지했다.
- Flutter 3.44.9 / Dart 3.12.2에서 `flutter pub get --enforce-lockfile`,
  `flutter analyze --no-pub`(이슈 0), `flutter test --no-pub`(**188 passed**, 실패·skip 0),
  `flutter build web --no-pub`를 통과했다. 기존 CupertinoIcons 폰트 경고는 남아 있다.
- 같은 브랜치 백엔드로 새 전용 cluster의 테스트·Chrome DB를 각각 준비했다.
  로컬 Docker daemon을 사용할 수 없어 **PostgreSQL 17.7**을 사용했으며,
  두 DB 모두 migration 전체 upgrade와 `alembic check`를 통과했다.
  `tests/integration/test_auth_flow.py`, `test_content_flow.py`, `test_upload_and_isolation.py`,
  `test_content_category_validation.py`, `test_youtube_summary.py`는 **43 passed, skip 0**,
  Starlette/httpx 경고 1건이었다. PostgreSQL 16·Docker는 최종 head의 원격 CI로 별도 확인한다.
- Chrome은 전용 API·파일 저장소·DB를 사용했다. 메타데이터·OCR·AI·YouTube 공급자만 고정 대역으로
  바꾸고 외부 HTTP를 차단·집계했다. YouTube는 자동 worker를 멈춰 대기 화면을 확인한 다음
  실제 `SummaryWorker.run_once()`의 claim·finish·DB 변경을 실행했다.

| 실제 Chrome 검증 | 요청·이벤트·DB 확인 결과 |
| --- | --- |
| 일반 링크 저장 | `category_ids=[]`, `tag_names=[]`, 201. AI 1회, 첫 분류 취업 대신 공부로 저장·표시 |
| 사진 저장 | 분류·태그 multipart part 없음, 201. OCR·AI 각 1회, 공부로 저장·표시, 파일 원본 일치 |
| AI 오류 링크 저장 | 201, 미분류 유지. 이벤트의 추천 실패 `error` 확인, 화면은 원인을 추정하지 않고 미분류 안내 |
| 첫 YouTube 대기 → 완료 | 201·`queued`·`apply_category=True`, 미분류 및 처리 중 안내. worker 후 `completed`·공부, 새로고침·상세 조회에 반영 |
| 두 번째 YouTube 수동 변경 | 대기 중 상세 UI에서 취업으로 PUT 1회. `apply_category=False`, worker 완료 후에도 취업 보존 |

- 확인창에 머무는 동안 추가 상세 조회·분류 PUT은 없었다. 일반 링크·사진의 생성 이벤트는 `ai`,
  실패 링크는 `uncategorized`로 기록됐으며, YouTube 생성 시점의 미분류 snapshot은 후속 변경에도 보존됐다.
  최종 콘텐츠·저장 이벤트 각 5건, 첨부파일·파일 각 1건, 태그 0건이며 동일 사용자·세션을 유지했다.
  카테고리 추천 대역 3회, OCR 1회, YouTube 공급자 2회, 외부 HTTP 시도 0회였다.
- 로컬 화면 증거는 원래 체크아웃의 ignored `frontend/build/verification/pr5/`에 저장하고 대화에 공유한다.
  `01-link-auto.jpg`, `02-photo-auto.jpg`, `03-uncategorized.jpg`, `04-youtube-pending.jpg`,
  `05-youtube-completed.jpg`, `06-manual-preserved.jpg`는 실제 Chrome 캡처이며 화면·토큰·서버 로그·DB 파일은 커밋하지 않는다.
- 한계: 자동 폴링은 없으므로 후속 분류는 다음 조회 시 반영된다. 운영 배포·실제 OCR/AI·OAuth·실기기는
  검증하지 않았다. OCR 오류 fallback은 기존 통합 테스트로 확인했고 Chrome에서는 AI 오류 fallback을 실행했다.
  OCR 성공 응답의 빈 텍스트 시나리오는 이번 Chrome 검증에서 별도 실행하지 않았다.
  기존 사진 확인창의 링크 문구와 저장된 원본 재표시는 이번 범위에 포함하지 않는다.
  백엔드·DB·의존성·잠금파일 변경과 migration은 없다.
- 실제 화면과 결과를 대화에 공유했다. 제품 코드·새 테스트의 별도 읽기 전용 리뷰에서도
  승인 범위의 추가 결함은 발견되지 않았다. `git diff --check`와 새 테스트의 whitespace 검사를 통과했다.
  사용자 `AGENTS.md`는 원래 체크아웃에 그대로 두고 커밋에서 제외한다.
- 관련 6개 파일을 `5bf4501`로 커밋·푸시하고 FE 대상 일반
  [PR #42](https://github.com/clip-back/clipback/pull/42)를 생성했다.
  이 링크 기록을 추가 푸시한 최종 head에서 Backend Validation을 수동 실행하며,
  실제 결과·실행 링크는 PR 본문과 작업 대화에 기록한다. PR은 병합하지 않는다.

### 2026-10-06 / PR 6 / PR 생성

- PR #42의 FE 병합을 확인하고 `550833e`에서 `fix/fe-feed-pagination`을 만들었다.
  `AGENTS.md`의 사용자 변경은 원래 체크아웃에 보존하고 구현과 커밋에서 제외한다.
- 변경 전 재현: `feed_pagination_test.dart` 1건 실패. 서버가 첫 100개와 `next_cursor`를
  반환해도 아카이브 끝 스크롤에서 다음 요청이 없어 101번째 콘텐츠에 접근하지 못했다.
- 홈·아카이브·북마크·검색에 분리된 페이지 상태와 요청 버전을 두고, 20개씩 커서를 전달한다.
  북마크 우선은 북마크 구간을 먼저 읽고 일반 구간으로 이어가며 전체를 미리 받지 않는다.
  서버 분류 필터 결과를 대표 분류 이름으로 다시 거르지 않는다.
- 로딩·빈 결과·오류를 구분하고, 추가 조회 실패에는 기존 카드/커서를 유지한다.
  상세의 이전·다음은 진입 목록을 사용하며 페이지 경계 조회와 뒤로 가기 경합을 보호한다.
  성공한 쓰기는 같은 조건의 첫 페이지부터 갱신한다. 개수는 불러온 수와 서버 분류 집계를 구분한다.
- Flutter 3.44.9 / Dart 3.12.2에서 `flutter pub get --enforce-lockfile`,
  `flutter analyze --no-pub`, `flutter test --no-pub`를 통과했다.
  한 번의 전체 실행에서 기존 188개와 새 회귀 51개, 총 **239개**가 통과했다.
  새 테스트는 필터/정렬/계정 전환, 같은 검색어 재제출, 추가 실패·422·최종401, 복수 분류,
  북마크 구간 전환, 상세 경계/뒤로 가기, 짧은 화면, 쓰기 후 초기화, 서버 집계/원본 시각 정렬을 포함한다.
- 리뷰와 테스트에서 초기화 직후 이전 스크롤이 새 페이지를 더 읽는 경합, 연속 쓰기와 카테고리 메타데이터
  응답 순서 경합, 삭제된 분류 필터 잔존, 성공한 쓰기를 늦은 상세 GET이 덮는 문제를 추가로 막았다.
  두 번째 페이지의 수정/삭제 실패도 원래 목록에 복구하며 홈에 잘못 삽입하지 않는다.
  분류 변경 실패 시 열린 상세 복구와 연속 낙관적 수정의 세부 동기화는 PR 9/PR 8에 남긴다.
- `flutter build web --no-pub`에 로컬 API 주소를 명시해 빌드했고,
  `git diff --check`와 신규 테스트의 공백 검사도 통과했다. 잠금파일 SHA-256은 변경 전과 동일하다.
  기존 `CupertinoIcons` 폰트 경고가 있으나 빌드는 성공했다.
- 전용 PostgreSQL 17.7의 새 DB에서 migration·`alembic check` 및 인증·피드·콘텐츠 흐름·업로드 격리·
  콘텐츠/카테고리 저장소 테스트 36개 통과, skip 0. 로컬 Docker daemon이 실행되지 않아
  PostgreSQL 16·Docker 검증은 최종 head의 Backend Validation에서 별도로 실행한다.
- Chrome의 전용 계정에 105개를 준비했다. 검색어 `경계`/취업/북마크에 일치하는 101개,
  일반 콘텐츠 4개, 동일 저장 시각과 복수 분류를 포함했다. 실제 API 응답을 DB의
  `(saved_at DESC, id DESC)` 예상 ID와 대조해 아카이브 105개, 검색/취업/북마크 각 101개의
  전체 순서·누락 없음·중복 없음·동일 계정을 확인했다. 공부 6개에는 대표 분류가 취업인 2개도 표시됐다.
- 북마크 우선은 북마크 101개를 모두 조회한 뒤 일반 4개로 이어졌다. 다음 페이지 503에서
  기존 20개를 유지하고 자동 반복 없이 같은 커서·필터를 재시도해 40개로 복구했다.
  단순 페이지 조회 때 DB 열람/클릭 이벤트와 `open_count`는 모두 0이었다.
- 상세에서 20번째 `페이지 경계 077` → 21번째 `페이지 경계 070`으로 이동했다.
  두 콘텐츠는 저장 시각이 같으며 ID 내림차순 경계다. 첫 검증 구간에서 각각 상세 GET 200·열람 POST 201·
  클릭 POST 201, DB 열람/클릭 각 2건·open_count 합계 2를 확인했다.
  Chrome에서 발견한 상세 개수 문구의 줄바꿈도 조정한 뒤 같은 경계를 최종 빌드에서 재확인했다.
- 북마크 변경 성공 후 현재 상세를 유지하고, 첫 페이지 밖의 현재 항목은 이전/다음을 비활성화했다.
  돌아온 아카이브는 같은 조건의 첫 20개와 맨 위 위치로 초기화됐다.
- 화면 증거는 원래 체크아웃의 ignored `frontend/build/verification/pr6/`에 저장했다:
  `01-initial-list.jpg`, `02-after-100.jpg`, `03-search-filter.jpg`, `04-bookmarks.jpg`,
  `05-category.jpg`, `06-multi-category.jpg`, `07-page-error.jpg`, `08-page-recovered.jpg`,
  `09-bookmark-first-boundary.jpg`, `10-detail-next-page.jpg`, `11-write-reset.jpg`.
  인증값·로그·DB·화면 파일은 커밋하지 않는다. 실제 OCR/AI 호출과 외부 HTTP 시도는 0이었다.
- 실제 화면과 결과를 작업 대화에 공유했다. 사용자 `AGENTS.md` 변경의 SHA-256이 작업 전과 같음을
  확인했으며, 관련 제품·테스트·README·진행 문서 4개 파일만 커밋·푸시한다.
- 관련 4개 파일을 `a05e8d2`로 커밋·푸시하고 FE 대상 일반
  [PR #43](https://github.com/clip-back/clipback/pull/43)을 생성했다.
  최종 화면 재확인까지 동일 사용자/세션 1개, 콘텐츠/저장 이벤트 105개를 유지했으며,
  상세 경계의 두 차례 검증으로 열람/클릭 이벤트와 open_count 합계는 각각 4가 됐다.
  검증 전용 API·PostgreSQL·웹 서버와 Chrome 탭은 종료하고 증거 파일은 보존했다.
  이 PR 링크 기록을 추가 푸시한 최종 head에서 Backend Validation을 수동 실행한다.
  실행 링크·PostgreSQL 16/Docker 결과는 PR 본문과 작업 대화에 남기며 PR은 병합하지 않는다.
- 커서는 요청 사이 DB 스냅샷을 보장하지 않으며, 다른 기기에서 추가한 최신 항목은 새 조회에 반영된다.
  운영 배포·실제 외부 OCR/AI·OAuth·실기기는 이번 검증 범위가 아니다. migration은 필요 없다.

### 2026-10-06 / PR 7 / PR 생성

- PR #43의 FE 병합(`da895d3`)을 확인하고 최신 FE에서 `fix/fe-screenshot-original`을 만들었다.
  사용자 `AGENTS.md`는 원래 체크아웃에 보존하고 커밋에서 제외한다.
- 수정 전 재현: 사진 저장 → 확인창 종료 → 상세 복귀·재진입 후 원본 이미지 표시가 없는 위젯 테스트
  1건이 실패했다. 다운로드 전송 대기/본문 수신이 10초 이후에도 끝나지 않는 API 테스트 2건도 실패했다.
- 자산 정보를 화면 모델과 복사 경로에 보존하고, 기존 상세 펼침 영역·원문 창에서 같은 인증 다운로드
  상태를 공유한다. 상세 이탈·자산/계정 변경 시 바이트를 정리하고 늦은 응답을 무시한다.
  별도 확대 화면·영속 이미지 캐시·다운로드 기능은 추가하지 않는다.
- `readAsset()`은 기존 공통 인증 재시도를 유지하고 다운로드의 전송 대기/본문 수신에 각각 10초를
  적용한다. 일반 JSON 요청 정책은 변경하지 않는다. 오류·없는 자산·디코딩 실패를 구분하고 수동 재시도한다.
  리뷰 중 발견한 원문 창 첫 프레임 전 상세 교체 경합도 막고 회귀 테스트를 추가했다.
- Flutter 3.44.9 / Dart 3.12.2에서 `flutter pub get --enforce-lockfile`,
  `flutter analyze --no-pub`(이슈 0), `flutter test --no-pub`(**298 passed, skip 0**),
  `flutter build web --no-pub`를 통과했다. 기존 239개와 원본 API 29개·위젯/모델 30개를 포함한다.
  기존 CupertinoIcons 폰트 경고는 남아 있지만 빌드는 성공했다.
- 테스트는 PNG/JPEG/WebP 실제 디코딩과 렌더 비율, 저장 후 재진입/앱 재생성, 두 영역의 요청 공유,
  401 공유 갱신·저장 콜백 대기, 다운로드/본문 시간 초과, 403/404/503/최종401/연결/빈 바이트/손상 이미지,
  뒤로/인접 상세/자산/계정 전환 후 늦은 응답, 저장 실패 배너·다시 저장을 포함한다.
  이미지 재시도나 토큰 저장 재시도로 게스트·원래 업로드·열람/클릭을 반복하지 않는지도 확인했다.
- 같은 브랜치 백엔드와 새 폐기용 DB 3개에서 migration 전체 upgrade와 `alembic check`를 통과했다.
  Docker daemon을 사용할 수 없어 로컬은 **PostgreSQL 17.7**을 사용했다.
  `tests/integration/test_auth_flow.py`, `test_upload_and_isolation.py`,
  `tests/api/test_uploads.py`, `tests/services/test_upload_service.py`는 **36 passed, skip 0**, 경고 1건이다.
  PostgreSQL 16·Docker는 최종 head 원격 CI에서 별도로 확인한다.
- Chrome 전용 계정에 긴 PNG(900×2400)와 가로 PNG(1600×900)를 실제 로컬 업로드 API로 저장했다.
  fixture 호출을 브라우저 요청과 구분했고, 저장 전후 사용자·세션·refresh 저장값은 그대로였다.
  확장의 파일 URL 접근 권한 제약과 사용 중인 기본 창을 고려해 **이번 Chrome의 파일 선택/업로드 UI는
  실행 완료하지 않았다.** 저장 확인창 종료 후 재진입은 FilePicker/HTTP 대역 위젯 테스트에서 검증했다.
- Chrome에서 상세의 원본을 열기 전에는 다운로드가 없었으며, 자연 만료된 1분 access token으로
  `GET /uploads/assets/1` **401 → refresh 200 → GET 200**을 확인했다.
  해당 구간 refresh 1회·추가 게스트 0회, 원문 창을 열어 긴 이미지 끝까지 스크롤해도 추가 다운로드 0회였다.
- 앱 새로고침 후 같은 사용자·세션으로 목록과 원본을 다시 조회했다. 다른 사진의 원본에 503을 한 번
  주입하고 오류 안내를 확인했으며, 자동 반복 없이 수동 재시도 GET 200으로 복구했다.
  503→복구 구간 refresh/guest는 모두 0회였고 DB 열람/클릭/open_count는 각각 3을 유지했다.
  별도 만료 시점의 정상적인 갱신은 각 검증 구간과 구분했다.
- 원본 파일·다운로드 bytes의 SHA-256이 두 사진 모두 정확히 같았다. 최종 사용자/세션 1개,
  콘텐츠/첨부파일/저장 이벤트/저장 파일 각 2개, 실제 상세 진입 3회에 열람/클릭/open_count 각 3이었다.
  별도 probe DB의 실제 API로 소유자 bytes 200, 인증 없음 401, 다른 사용자/없는 자산/유실된 파일 404를 확인했다.
  OCR·AI 고정 대역 각 2회, 외부 HTTP 시도 0회이며 원본 조회는 공급자를 호출하지 않았다.
- 실제 Chrome 화면은 원래 체크아웃의 ignored `frontend/build/verification/pr7/`에 보존했다.
  `01-detail-original.jpg`, `02-original-sheet-top.jpg`, `03-original-sheet-bottom.jpg`,
  `04-after-reload.jpg`, `05-download-error.jpg`, `06-download-recovered.jpg`를 대화에 공유한다.
  화면·테스트 사진·인증값·로그·DB·저장 파일은 커밋하지 않는다.
- `git diff --check`, 신규 파일 whitespace와 최종 diff를 확인했다. 사용자 `AGENTS.md` 변경 및
  잠금파일의 SHA-256은 작업 전과 동일하다. 백엔드·DB·의존성 변경과 migration은 없다.
- 운영 배포·실제 OCR/AI·OAuth·실기기 및 Chrome 파일 선택 UI는 미검증이다.
  원본의 영속 캐시·확대·파일 다운로드 기능은 범위 밖이며, 시간 초과/화면 이탈이 서버 전송을 취소하지 않는다.

- 실제 검증 화면과 결과를 대화에 공유하고 관련 6개 파일을 `d4ce0e5`로 커밋·푸시했다.
  FE 대상 일반 [PR #44](https://github.com/clip-back/clipback/pull/44)를 생성했다.
  이 PR 링크 기록을 추가 푸시한 최종 head에서 Backend Validation을 수동 실행한다.
  PostgreSQL 16·Docker 결과와 실행 링크는 PR 본문과 작업 대화에 기록하며, PR은 병합하지 않는다.

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

### 2026-10-06 — PR 8·9 콘텐츠 변경 상태 동기화 및 실패 복구

- PR #44의 FE 병합을 원격에서 확인하고 최신 FE `ab45071`에서 `fix/fe-content-state-sync`를 만들었다.
  사용자 선택에 따라 PR 8·9를 통합하고, 같은 콘텐츠만 잠금·삭제 성공 후 제거 정책을 적용한다.
- 수정 전 회귀 4개가 모두 실패했다: 분류 503 후 상세 분류 잔존, 북마크 모델·표시 불일치,
  같은 콘텐츠 중복 쓰기, 삭제 응답 전에 상세 이탈. 이 실패를 먼저 확인한 뒤 구현했다.
- 콘텐츠별 변경 필드·작업 식별자와 읽기 시작 버전으로 진행 중·완료 후 이전 응답을 보호한다.
  이전 읽기가 끝나면 보호 값을 정리하며, 별도 콘텐츠 캐시나 상태 관리 의존성은 추가하지 않았다.
- 목록·상세의 실제 변경 버튼을 비활성화하고 공통 진입점에서도 중복과 오래된 메뉴 콜백을 차단한다.
  실패 복구는 변경한 필드만 적용하여 요약·자산과 새로운 검색 조건을 보존한다.
- 다른 콘텐츠의 성공 후 첫 페이지를 갱신하는 동안에도 기존 항목을 유지하여 다른 항목의 변경을 허용한다.
  새 첫 페이지 성공 시 서버 순서로 교체하며, 실패하면 기존 항목과 조회 오류를 표시한다.
  오래된 메뉴·카드 콜백은 현재 같은 ID의 값을 사용한다. 늦은 통계 응답도 조회 버전으로 차단한다.
- Chrome 검증에서 발견한 검색 상세 복귀 시 입력 자동 포커스로 맨 위로 이동하는 문제를 수정했다.
  처음 빈 검색 화면에서만 자동 포커스하며, 상세 복귀는 기존 두 번째 페이지 위치를 유지한다.
  긴 분류명과 진행 문구를 함께 표시할 때의 카드 넘침도 회귀 테스트 후 수정했다.
- Flutter **3.44.9 / Dart 3.12.2**에서 다음을 통과했다. 잠금파일·의존성은 그대로다.
  - `flutter pub get --enforce-lockfile`
  - `flutter analyze --no-pub`: 이슈 0
  - `flutter test --no-pub`: **357 passed, skip 0** — 기존 298개 + 신규 59개
  - `flutter build web --no-pub --dart-define=CLIPBACK_API_BASE_URL=http://127.0.0.1:50311/api/v1`
  - `git diff --check` 및 신규 테스트 파일 whitespace 검사
  기존 CupertinoIcons 폰트 경고는 남아 있으며 웹 빌드는 성공했다.
- 신규 회귀는 HTTP 401/403/404/503·연결·JSON 오류, 중복 쓰기·다른 항목 쓰기, 오래된 조회/메뉴,
  변경 필드만 복구, 삭제 응답 순서, 후속 조회 실패, 계정 교체, 자산·요약 보존, 통계·검색 복귀를 포함한다.
  PR 6의 삭제 기대값은 서버 성공 후 제거 정책에 맞추고 기존 커서·조건 검증은 유지했다.
- 같은 브랜치 백엔드와 새 폐기용 DB 3개에서 migration 전체 upgrade와 `alembic check`를 통과했다.
  Docker daemon을 사용할 수 없어 로컬은 **PostgreSQL 17.7**을 사용했다.
  인증·콘텐츠 변경·피드 페이지네이션·카테고리 검증·업로드/사용자 격리와 관련 저장소 테스트는
  **49 passed, skip 0**, Starlette/httpx 경고 1건이다. 실제 대상은 다음 8개다:
  `tests/integration/test_auth_flow.py`, `test_content_flow.py`, `test_feed_pagination.py`,
  `test_content_category_validation.py`, `test_upload_and_isolation.py`,
  `tests/repositories/test_content_repository.py`, `test_category_repository.py`, `test_event_repository.py`.
  PostgreSQL 16·Docker는 최종 head 원격 CI에서 별도로 확인한다.
- Chrome 전용 계정에 로컬 실제 API로 콘텐츠 45개를 준비했다. 검색 `동기화`의 20+20+5개 응답을
  DB 순서와 대조해 누락·중복·계정 혼입이 없음을 확인했다. 준비 API 요청과 Chrome 요청은 구분했다.
- 두 번째 페이지의 콘텐츠 21 북마크 응답을 지연시켜 목록·상세의 변경 중 표시와 잠금을 확인했다.
  기다리는 동안 다른 콘텐츠 44의 북마크 변경은 성공했다. 두 PUT은 각각 1회이며 두 항목만 북마크됐다.
  콘텐츠 21의 분류 503 후 목록·상세가 기존 `취업`으로 복구됐고, 수동 재시도 200 후 `공부`로 일치했다.
  최종 빌드 검증 구간은 분류 PUT **503 1회 → 200 1회**다. 앞선 별도 재현의 503 1회와 구분한다.
- 콘텐츠 45·44의 삭제를 지연·503 처리해 카드와 상대 순서가 유지되는지 확인했다.
  45의 재시도는 DB commit 후 응답을 지연해도 카드가 남았으며, **204 수신 후에만** 제거됐다.
  같은 검색어의 첫 페이지는 44→25 순서로 재조회됐다. 44는 삭제되지 않고 북마크도 유지했다.
- 새로고침 뒤에도 같은 사용자·세션 1개, 콘텐츠 44개, 북마크 2개(44·21), 공부 분류 1개(21)를 확인했다.
  저장 이벤트는 누적 45개를 유지하고 분류 변경 이벤트는 1개다. 실제 상세 진입 4회에 열람·클릭·
  open_count 합계가 각각 4였다. 준비 이후 추가 게스트·refresh·실제 AI/OCR·외부 HTTP는 모두 0회다.
  인증 갱신·최종 401·계정 교체 경합은 자동 회귀 테스트로 별도 검증했다.
- 실제 Chrome 화면을 작업 대화에 공유했다. 원래 체크아웃의 ignored
  `frontend/build/verification/pr8/`에 다음 파일을 보존하며 인증값·로그·DB·화면은 커밋하지 않는다:
  `07-category-restored-final.jpg`, `10-two-deletes-pending.jpg`, `11-deletes-failed-order-preserved.jpg`,
  `12-delete-awaiting-success.jpg`, `13-delete-success.jpg`, `15-restored-bookmarks-capture.jpg`,
  `17-final-detail.jpg`, `18-search-back-position.jpg`.
- 사용자 `AGENTS.md` 변경의 SHA-256은 작업 전과 동일하다. 제품·회귀 테스트·README·진행 문서
  5개 파일만 포함하며 백엔드·DB·HTTP 계약·의존성·잠금파일 변경과 migration은 없다.
- 연결 종료·응답 파싱 실패는 서버 변경 취소를 보장하지 않는다. 화면 복구는 마지막 확인값 기준이며
  다음 정상 조회에서 서버 상태를 반영한다. 운영 배포·실제 외부 AI/OAuth·실기기는 미검증이다.
  다음 작업은 PR 10의 카테고리 삭제 안내·동작 수정이다.
- 검증용 API와 PostgreSQL은 정상 종료했고 증거 파일은 보존했다.
- 관련 5개 파일을 `116322f`로 커밋·푸시하고 FE 대상 일반
  [PR #45](https://github.com/clip-back/clipback/pull/45)를 생성했다.
  이 링크 기록을 추가 푸시한 최종 head에서 Backend Validation을 수동 실행한다.
  실행 링크·PostgreSQL 16·Docker 결과는 PR 본문과 작업 대화에 남긴다.
  FE 대상 PR의 자동 Checks와 수동 CI를 구분하고 PR은 병합하지 않는다.

### 2026-10-06 — PR 10 카테고리 삭제 안내와 화면 동작 일치

- PR #45의 FE 병합을 확인하고 최신 FE `6fbfcce4`에서 `fix/fe-category-delete`를 만들었다.
  사용자 `AGENTS.md`는 원래 체크아웃에 보존하고 커밋에서 제외한다.
- 확정 UX: 확인창을 닫고 폴더에 삭제 진행을 표시한다. 성공 전 선제적으로 콘텐츠·북마크를 제거하지 않는다.
  같은 카테고리 수정/삭제만 잠그고 다른 콘텐츠·카테고리 변경과 조회·탐색은 허용한다.
  삭제된 활성 필터는 ID로 확인하여 전체 콘텐츠로 바꾸고, 사용자가 이미 다른 조건으로 이동했으면 유지한다.
- 전체 분류를 화면 모델에 보존하고 삭제 성공한 ID만 제거한다. 남은 분류가 없을 때만 미분류로 이동한다.
  늦은 조회·쓰기 응답·실패 복구에도 삭제 ID 보호를 적용하며 계정 교체 시 관련 상태를 정리한다.
- 완료 조건: 잘못된 안내/선제 제거/실패 순서 변경을 먼저 재현한 뒤 회귀 테스트, 전체 Flutter 검사,
  폐기용 PostgreSQL 검증, 실제 Chrome 45개 fixture와 원본 bytes 보존을 확인한다.
  화면 공유 후 FE 대상 일반 PR과 최종 head 수동 CI까지 진행하며 병합하지 않는다.
- 수정 전 핵심 재현 4건 모두 실패했다: 콘텐츠 함께 삭제 안내, 응답 전 홈 콘텐츠·북마크 제거,
  실패 후 목록 순서 변경, 같은 카테고리 중복 DELETE. 수정 후 모두 통과했다.
- 독립 리뷰에서 찾은 이름 수정과 늦은 메타데이터/분류 실패 복구 경합도 각각 실패부터 재현했다.
  이름 수정 성공 후 새 조회로 이전 조회를 무효화하고, 분류 복구 시 현재 카테고리 이름·색을 적용했다.
- Flutter 3.44.9 / Dart 3.12.2: `pub get --enforce-lockfile`, `analyze --no-pub` 이슈 0,
  `test --no-pub` **400 passed, skip 0**(기존 357 + 신규 43), `build web --no-pub`를 통과했다.
  실제 화면 검증 빌드는 `CLIPBACK_API_BASE_URL=http://127.0.0.1:50311/api/v1`을 사용한다.
  기존 CupertinoIcons 폰트 경고는 남아 있지만 빌드는 성공했다. 의존성·잠금파일은 그대로다.
- 새 폐기용 PostgreSQL DB 3개에서 전체 migration upgrade와 `alembic check`를 통과했다.
  Docker daemon 비가동으로 로컬은 **PostgreSQL 17.7**을 사용했다.
  `pytest -q tests/api/test_categories.py tests/services/test_category_service.py tests/repositories tests/integration`
  결과는 **403 passed, skip 0**, Starlette/httpx 경고 1건이다. PostgreSQL 16·Docker는 최종 head CI로 확인한다.
- Chrome에서 삭제 확인창이 데스크톱 전체 폭으로 늘어나는 문제를 발견했다.
  1600×900 회귀 테스트에서 폭 1536px 실패를 재현하고, 기존 앱 폭과 inset 기준 최대 311px로 제한했다.
  본문과 두 버튼이 확인창 안에 배치되고 렌더링 오류가 없는지 포함한 신규 **43개** 테스트가 통과했다.
  이 수정까지 포함한 전체 회귀 400개·분석·웹 빌드를 다시 실행해 통과했다.
- Chrome 전용 계정에 실제 로컬 API로 콘텐츠 45개를 준비했다. 삭제할 공부 단독 20개,
  공부+취업 20개(공부는 두 번째 분류), 취업 단독 5개이며 북마크 8개·스크린샷 1개·빈 분류를 포함했다.
  삭제 확인창 취소에서는 DELETE가 없음을 별도 기준 구간에서 확인했다.
- 최종 빌드 Chrome 구간에서 공부 DELETE **503 1회 → 수동 재시도 204 1회**를 확인했다.
  첫 응답 대기 중 콘텐츠 1의 북마크 PUT 200은 1회 성공했다. 503 뒤 폴더 순서·분류·45개 콘텐츠는
  그대로였고 북마크는 사용자가 변경한 1개만 늘었다. 성공 재시도도 DB commit 후 응답을 지연하여
  폴더가 계속 남고 204 수신 후 제거되는 것을 확인했다.
- 삭제 후 공부 단독 20개는 미분류, 복수 분류 20개는 취업을 유지했고 취업 집계는 25개였다.
  검색 `분류삭제`의 20+20+5개 응답 ID 45→1은 준비 당시·최종 DB 순서와 정확히 일치했다.
  콘텐츠 45개, 저장 이벤트 45개, 북마크 9개, 첨부파일·저장 파일 각 1개를 보존했다.
  제목·요약·저장 시각과 생성 이벤트의 분류 스냅샷은 그대로이며, 영향을 받은 40개에만
  올바른 before/after 분류 변경 이벤트가 기록됐다.
- 새로고침 후 사용자·세션이 같고 추가 게스트·refresh는 각각 0회였다. 콘텐츠 25·45의 실제 상세 진입
  각 1회에만 열람·클릭·open_count가 각각 총 2개였다. Chrome 원본 다운로드는 200 1회였으며,
  준비·별도 해시 검증 요청은 이 수에서 제외했다. 63,696 bytes 원본·다운로드·저장 파일의 SHA-256이
  삭제 전후 모두 같았다. 토큰·인증 헤더는 기록하지 않았다.
- 별도 probe DB에서 빈 분류 삭제, 삭제 rollback, 동시 북마크, YouTube 후속 실제 worker의
  남은 분류 보존을 확인했다. worker 공급자는 대역이며 Chrome 결과와 구분한다.
  준비 단계 메타데이터 44회·OCR 1회는 대역, AI 추천 0회·외부 HTTP 0회다.
- 실제 Chrome 화면을 대화에 공유했다. 원래 체크아웃의 ignored `frontend/build/verification/pr10/`에
  `01-delete-confirmation.jpg`, `02-delete-pending.jpg`, `03-concurrent-bookmark.jpg`,
  `04-delete-failure-preserved.jpg`, `05-delete-success-counts.jpg`, `06-single-category-uncategorized.jpg`,
  `07-multi-category-retained.jpg`, `08-retained-category-detail.jpg`, `09-reloaded-home.jpg`,
  `10-reloaded-original.jpg`를 보존했다. 화면·로그·인증값·DB·원본 파일은 커밋하지 않는다.
- `git diff --check`, 신규 테스트 whitespace와 최종 diff를 확인했다. 사용자 `AGENTS.md`의 SHA-256은
  작업 전과 동일하다. 제품 코드·신규 테스트·README·진행 문서 4개 파일만 포함하며 migration은 없다.
- 최종 401·계정 교체·늦은 응답·후속 조회 실패·빈 카테고리·같은 이름의 새 ID 등은 자동 회귀로 검증했다.
  연결 종료·응답 파싱 실패는 서버 삭제 취소를 보장하지 않으며 다음 정상 조회에서 서버 상태를 반영한다.
  운영 배포·실제 외부 AI/OAuth·실기기는 미검증이다. 로컬 PostgreSQL 17.7 결과와 최종 head의
  PostgreSQL 16·Docker 수동 CI 및 FE PR 자동 Checks를 구분해 기록한다.
- 검증용 API·PostgreSQL·웹 서버와 Chrome 탭을 정상 종료하고 증거 파일은 보존했다.
- 관련 4개 파일을 `effef47`로 커밋·푸시하고 FE 대상 일반
  [PR #46](https://github.com/clip-back/clipback/pull/46)을 생성했다.
  이 PR 링크 기록을 추가 푸시한 최종 head에서 Backend Validation을 수동 실행한다.
  실행 링크와 PostgreSQL 16·Docker 결과는 PR 본문과 작업 대화에 기록한다. PR은 병합하지 않는다.

### 2026-10-12 — 프론트엔드 1차 파일 분리

- 상태: 1차 파일 분리와 로컬 검증 완료. 브랜치는
  `refactor/frontend-module-split`이며, 앞선 FE 병합 준비와 별개의
  구조 정리 작업이다. 이 문서의 과거 FE 작업에 적용한 자동 커밋·푸시 및 base `FE` 예외는
  이번 작업에 적용하지 않는다. 커밋·푸시·PR 생성·병합은 별도 사용자 요청 범위에서 수행한다.
- 구현: `main.dart`에는 앱 시작 진입점 7줄을 남기고, 앱 구성과 기존 루트 상태 조정은
  `app/clipback_app.dart` 2,041줄로 옮겼다. 인증·홈·보관함·검색·콘텐츠·카테고리·계정 화면은
  각 `features/` 디렉터리로, 공통 모델·테마·계약·범용 위젯은 `shared/`로 분리했다.
  모델에 의존하는 재사용 UI는 `shared/content/`와 `shared/category/`로 구분하고,
  기존 초기 카테고리·샘플 콘텐츠는 `shared/data/`에 보존했다.
  `lib/`는 기존 API·소셜 인증 2개 파일과 분리 대상 54개 파일을 포함해 총 56개다.
- 의존 방향: `main` → `app` → 기능 화면·공유 요소를 따른다. 기능 화면은 공통 모델·계약·UI를
  사용하고, `shared`는 앱이나 기능 화면을 역참조하지 않는다. 자세한 역할은
  [프론트 README](../frontend/README.md)의 코드 구조 절에 기록한다.
- 유지 범위: 화면 동작, 세션·계정 전환, 실패 복구, 피드 조회와 콘텐츠·카테고리 변경 동작을 보존했다.
  `clipback_api.dart`·`social_auth.dart`는 기존 위치와 책임을 유지했으며, 백엔드·DB·API 계약·의존성·
  잠금파일 변경은 없다. 사용자의 기존 `AGENTS.md` 변경은 작업 전후 해시가 같음을 확인했다.
- 후속 범위: 루트의 상태 책임을 나누는 2차 작업, 새 상태 관리 패키지·라우터 도입,
  추천·알림 등 미연동 기능 구현은 이번 파일 분리에 포함하지 않는다.
- 완료 조건: 화면·공유 요소가 의도한 경계로 이동하고 순환·역방향 import가 없어야 한다.
  기존 테스트가 새 파일 위치에서도 동작하며, 분리 전후 `flutter analyze --no-pub`와
  `flutter test --no-pub` 결과를 비교한다. `git diff --check`와 최종 diff로 동작 변경·무관한 변경이
  섞이지 않았는지 확인한다.
- Flutter **3.44.9 / Dart 3.12.2**에서 다음 자동 검사를 실행했다.
  이전 실행 기록을 재사용한 결과가 아니다.
  - 분리 전: `flutter analyze --no-pub` 문제 없음, `flutter test --no-pub` **434 passed**(27초).
  - 공통 요소 분리 후: `flutter analyze --no-pub` 문제 없음, 피드·콘텐츠 변경·자동 분류 관련
    테스트 **150 passed**(12초).
  - 전체 분리 후: `flutter analyze --no-pub` 문제 없음, `flutter test --no-pub`
    **434 passed**(38초).
  - 웹 빌드: `flutter build web --no-pub --no-web-resources-cdn
    --dart-define=CLIPBACK_API_BASE_URL=http://127.0.0.1:18766/api/v1` **성공**(74.3초).
    CupertinoIcons 폰트 포함 관련 경고는 있었으나 종료 코드는 0이었다.
- 구조·이동 검사: 로컬 import 그래프의 순환 0건, `shared`의 상위 계층 참조 0건을 확인했다.
  이동한 선언 194개의 토큰을 비교하여 파일 경계에 필요한 공개명·API `FeedPage` 이름 구분·
  위젯 `key` 조정을 제외한 차이는 없었다. 테스트·helper 13개도 import를 제외한 본문의
  SHA-256이 같았다. 이는 소스 이동 확인이며 실제 플랫폼 동작 검증과 구분한다.
- 화면 확인: Codex 내장 브라우저에서 로컬 정적 서버 `http://127.0.0.1:18765`의 웹 빌드를 열어
  브랜드 로고·소개 문구·**게스트로 시작하기**가 있는 `LoginScreen` 렌더링을 확인했다.
  웹의 소셜 공급자 목록은 기존처럼 비어 있어 소셜 버튼은 표시되지 않았다.
  실제 로그인·API 요청은 수행하지 않았으며, 브라우저 콘솔의 경고·오류는 0건이었다.
- 최종 확인: 선언 194개의 허용된 이름·`key` 조정 외 토큰 차이 0건, import 순환·공유 계층의
  역참조 0건, 기존 `AGENTS.md`의 해시 일치, `git diff --check`를 다시 확인했다.
- 미검증: 실제 API·PostgreSQL, 원격 CI, Railway 배포, 외부 OAuth/AI, Android·iOS 빌드·실기기
  실행은 이번에 수행하지 않았다. 웹 화면 확인은 로그인 진입 화면으로 한정하며, 저장·분류·검색 등
  후속 흐름을 브라우저에서 수동 검증한 것은 아니다. 기존 작업 결과를 이번 분리 검증으로 재사용하지 않는다.

### 2026-10-12 — 프론트엔드 2차 상태·데이터 계층 분리

- 상태: 2차 구현과 전체 정적 분석·테스트·웹 빌드·로컬 로그인 진입 화면 확인 완료.
  1차 변경이 남아 있는 `refactor/frontend-module-split`에서 이어가며 1차 결과와 기존 `AGENTS.md`
  변경을 보존한다. 과거 FE 작업의 자동 커밋·푸시·PR 규칙은 적용하지 않는다.
  자동 커밋·stash·reset·푸시·PR 생성·병합은 수행하지 않는다.
- 범위: 기존 화면과 API 계약을 유지하면서 `ChangeNotifier`와 생성자 주입으로 MVVM과 데이터 계층을
  분리했다. 앱 View는 의존성 조립·화면 연결·Flutter 생명주기·UI 효과를, AppViewModel은 인증과 계정·
  화면 전환을 담당한다. 홈·보관함·북마크·검색·상세·계정·카테고리 관리·저장 상태는 기능 ViewModel
  8개로 옮겼다. `app/clipback_app.dart`는 2,041줄에서 434줄로 줄었고, 인증·조회·쓰기 구현은
  ViewModel과 세 Repository·두 Action으로 분리했다.
- 데이터 경계: `SessionRepository`는 세션 복원·인증·저장/삭제 큐·소셜 인증 자격 상태,
  `ContentRepository`는 피드·상세·카테고리·변경 상태·늦은 응답 조정,
  `UserRepository`는 사용자와 서버 통계를 담당한다. 각 Repository의 추상 계약과 구현을 두되
  서로 직접 참조하지 않는다. API DTO를 재사용하고 표시 형식은 공용 mapper로 분리한다.
- 조정 경계: `app/actions/`가 계정 초기화와 콘텐츠·카테고리 변경 후 조회·통계 갱신 순서를 담당한다.
  기능 ViewModel은 이 하위 조정 계층과 Repository 계약을 참조할 수 있지만 앱 View·AppViewModel이나
  다른 기능 ViewModel을 참조하지 않는다. 공유 표시 코드는 데이터 계약만 사용하며 상위 계층을 참조하지 않는다.
- 유지할 계약: 네 피드는 읽기 전용 스냅샷을 제공하고 추가 조회의 진행 중 Future를 공유한다.
  화면의 `FeedPage` 객체는 유지하며 query version이 바뀔 때만 스크롤을 초기화한다.
  요청·계정·인증·화면 탐색의 세대를 구분하고, 변경 잠금은 후속 조회까지 유지한다.
  서버 쓰기 성공 후 조회 실패는 쓰기를 되돌리지 않는다. 원본 이미지 요청 공유와 시트 정리도 보존한다.
- 제외: 서비스 파일·의존성·라우터·백엔드 계약·네이티브 설정 변경, 추천 연결·원문 열기·랜덤 보기 개선.
  실제 OAuth·운영 서버 쓰기·실기기 출시는 이번 완료 조건에 포함하지 않는다.
- 구현 전 기준: 이번 작업에서 새로 실행한 `flutter analyze --no-pub`는 **문제 없음**(2.6초),
  `flutter test --no-pub`는 **434 passed**(22초)다. 앞선 1차 작업의 실행 기록을 재사용하지 않았다.
- 최종 자동 검사: `flutter analyze --no-pub` **문제 없음**(2.1초), `flutter test --no-pub`
  **492 passed**(24초). 기존 434개에 새 경계 테스트 58개를 추가했으며 기존 테스트를 줄이거나
  skip하지 않았다. 추가 범위는 콘텐츠 Repository 19개, 세션·사용자·AppViewModel 13개,
  표시 변환·피드 투영 14개, 기능 ViewModel·Action 10개, 오래된 Action 요청 차단 2개다.
- 경계 검증: 조회·쓰기 경합과 필드별 복구, 삭제 데이터 부활 방지, 세션 저장 큐, 피드 요청 공유와
  스크롤 보존, 상세 닫기 후 동일 콘텐츠 재진입, 후속 통계 조회까지 변경 잠금 유지, dispose 이후
  저장 결과·UI 효과·통계 조회 차단을 확인했다. 이는 로컬 대역 테스트 결과이며 실제 공급자·서버 검증은 아니다.
- 보존·구조 검사: 기존 테스트·helper의 소스 바이트는 2차 작업 시작 시점과 동일하다.
  `clipback_api.dart`·`social_auth.dart`·`pubspec.yaml`·잠금파일과 기존 `AGENTS.md` 해시도 그대로다.
  `lib/`의 Dart 파일 77개에서 로컬 import 순환·공유 계층의 상위 참조·Repository 간 참조는 0건이다.
- 웹 빌드: `flutter build web --no-pub --no-web-resources-cdn
  --dart-define=CLIPBACK_API_BASE_URL=http://127.0.0.1:18766/api/v1` **성공**(27.5초).
  기존 CupertinoIcons 폰트 경고는 남아 있지만 종료 코드는 0이었다.
- 화면 확인: Codex 내장 브라우저에서 로컬 정적 서버 `http://127.0.0.1:18765`의 웹 빌드를 열어
  브랜드 로고·소개 문구·**게스트로 시작하기**가 있는 로그인 선택 화면을 확인했다.
  웹 소셜 버튼이 표시되지 않는 기존 정책을 유지했고, 콘솔 경고·오류는 0건이었다.
  게스트·소셜 로그인 버튼을 누르거나 백엔드 쓰기를 수행하지 않았다.
- 최종 문서 변경 후 `git diff --check`를 통과했다. 화면 확인은 로그인 진입 화면으로 한정하며,
  저장·분류·검색 등 후속 흐름을 브라우저에서 수동 검증한 것은 아니다.
  원격 CI·운영 배포·실제 OAuth/AI·PostgreSQL·Android/iOS 빌드·실기기 검증은 수행하지 않았다.

### 2026-10-12 — 2차 분리 리뷰에서 확인한 회귀 수정

- 상세 진입: `DetailViewModel.open()`이 상세 선택 성공 여부를 반환하고, 앱 View는 성공한 경우에만
  상세 경로로 전환한다. 삭제 응답 직후 아직 렌더된 카드를 눌러도 목록에 머물며, 마지막 항목의
  빈 목록 예외나 다른 홈 콘텐츠를 대신 표시하는 문제가 발생하지 않는다. 저장 후 상세 진입에도
  같은 성공 검사를 적용하며, 뒤로 가기 목적지는 홈이고 저장 자체의 추가 열람 이벤트는 없다.
- 통계 보존: 일반 프로필 조회 `UserRepository.loadMe()`에서 통계를 0으로 덮는 처리를 제거했다.
  계정 초기화의 `resetAccount()`가 기존 통계를 비우는 책임은 유지한다. 초기 프로필 조회 실패 후
  후속 조회로 복구한 통계가 계정 정보 재확인·연결 화면 취소 후에도 유지된다.
- 재현 테스트 5개를 추가했다. `content_mutation_test.dart`는 삭제 응답 처리 후 다음 프레임 전
  실제 카드를 탭해 남은 항목 0개·1개 모두에서 경로 유지와 잘못된 상세 GET·열람·클릭 이벤트 부재를
  확인한다. `user_repository_test.dart`의 2개 테스트는 프로필 재조회 시 통계 보존과 계정 초기화의
  통계 제거를 검사한다. `app/account_stats_regression_test.dart`는 실제 ViewModel·Action·Repository를
  조립하고 HTTP만 대체해 최초 프로필 실패 → 통계 복구 → 계정 연결 → 뒤로 가기에서 70/30 보존과
  추가 통계·소셜 인증 요청 부재를 확인한다.
- 새 테스트는 구현 수정 전 5개 모두 실패했고 수정 후 통과했다. 기존 assertion·시나리오를 줄이거나
  skip하지 않았다. 관련 목록·상세·저장·원본 이미지 테스트 **192 passed**(16초), 통계·AppViewModel
  테스트 **12 passed**를 확인한 뒤 전체 검사를 실행했다.
- 이번 수정 후 `flutter analyze --no-pub` **문제 없음**(3.4초), `flutter test --no-pub`
  **497 passed**(30초). 앞선 492개에 회귀 테스트 5개가 추가된 결과이며 이전 실행 결과를 재사용하지 않았다.
- `flutter build web --no-pub --no-web-resources-cdn
  --dart-define=CLIPBACK_API_BASE_URL=http://127.0.0.1:18766/api/v1` **성공**(45.1초).
  기존 CupertinoIcons 폰트 경고는 남아 있다. 로컬 웹 로그인 진입 화면의 로고·소개·게스트 시작 표시를
  확인했고 브라우저 콘솔 경고·오류는 0건이었다. 검증용 탭과 로컬 서버는 종료했다.
- `git diff --check`와 수정 전 비교로 기존 테스트 본문·`AGENTS.md` 보존 및 변경 범위를 확인했다.
  두 경합의 동작 검증은 HTTP 대역과 Flutter 테스트 환경의 결과다. 실제 OAuth·운영 서버 쓰기·
  원격 CI·실기기 실행은 이번에 수행하지 않았으며 웹 수동 확인은 로그인 진입 화면에 한정했다.
- 기존 1차·2차 변경과 사용자 `AGENTS.md`를 보존하고 `refactor/frontend-module-split`에서 수정했다.
  API·소셜 인증 서비스·의존성·백엔드·네이티브 설정 변경과 커밋·푸시·PR은 수행하지 않았다.

### 2026-10-12 — iOS 앱 식별자·서명 팀 정리

- 사용자가 변경한 iOS 설정을 `chore/ios-app-signing` 브랜치로 분리했다. Runner의
  Debug·Profile·Release에서 Bundle ID는 `com.clipback.app` → `com.huturu.app`,
  서명 Team은 `BNTT9T6W95` → `8X6N747PQM`으로 바뀐다. `Info.plist`의
  `CFBundleVersion`은 항목 위치만 이동했으며 파싱한 전체 설정값은 기존과 동일하다.
- 프론트 README의 실행·소셜 설정 안내를 새 식별자와 팀에 맞췄다. 백엔드 README와
  `.env.example` 주석에는 Apple의 `APPLE_CLIENT_ID`가 새 Bundle ID와 일치해야 함을 기록했다.
  실제 환경변수 값·서비스 코드·토큰 암호화 키·API 계약·의존성·DB/migration은 변경하지 않았다.
- 실제 로그인 전 Google iOS OAuth client·URL scheme, 카카오 iOS 플랫폼 등록,
  Apple App ID·팀/키·프로비저닝과 배포 서버 설정을 각각 확인해야 한다. 저장소 변경으로
  외부 설정이 자동 반영되지는 않으며, Apple의 단일 audience를 바꾸면 이전 Bundle ID용
  토큰을 계속 허용하지 않는 점을 백엔드 문서에 명시했다.
- 이번 작업에서 `flutter analyze --no-pub` **문제 없음**(2.9초), `flutter test --no-pub`
  **497 passed**(45초)를 확인했다. 기존 테스트와 assertion을 변경하지 않았다.
- `flutter build ios --debug --no-codesign --no-pub` **성공**(Xcode 빌드 39.9초).
  생성된 `Runner.app/Info.plist`의 Bundle ID가 `com.huturu.app`임을 확인했다.
  기기용 컴파일 결과이며 코드 서명·프로비저닝이나 실제 기기 설치 성공을 뜻하지 않는다.
- `plutil -lint`로 프로젝트·Info.plist·entitlements를 검증했고, 세 빌드 구성의 Team/Bundle ID,
  `.env.example`의 기존 설정값 보존, 사용자 iOS 변경 원문의 보존을 확인했다.
  문서 갱신 후 `git diff --check`를 통과했다.
- 미검증: 실제 iPhone 설치·실행·사진 업로드, 공급자 콘솔·실제 OAuth, TestFlight·운영 배포.
  백엔드는 문서·예제 주석만 바뀌므로 Python·DB 테스트를 실행하지 않았다.
  `AGENTS.md`는 계속 Git 추적에서 제외하고 빌드 생성물·로컬 인증 설정은 커밋하지 않는다.

### 2026-10-12 — 상단 안전 영역·헤더 여백 통일

- 브랜치: `fix/frontend-top-safe-area`, 기준 `9690a9e`(`main`).
- 일반 화면의 헤더는 시스템 상단 inset을 제외한 64 논리 픽셀(`appHeaderHeight`)로 맞췄다.
  각 화면 본문에서 SafeArea를 한 번 적용하며, 기존 북마크·검색의 보호를 중복하지 않는다.
  저장 창은 별도 route에서 보호하고, 모든 하단 시트 진입에 `useSafeArea: true`를 적용했다.
- 홈은 헤더도 함께 스크롤하는 기존 동작과 본문 간격을 유지한다. 랜덤은 단일 Stack에서 헤더·본문·
  카드 승격 좌표를 함께 보정하고 ClipRect로 드래그 중 상태바 영역 침범을 막는다.
  인증 화면 배치, 하단 내비게이션·저장 CTA, 버튼 hitSize, 화면 최대 너비는 유지한다.
  API·ViewModel·Repository·네이티브 설정·의존성·AGENTS.md는 변경하지 않았다.
- 변경 전 기준: `flutter analyze --no-pub` 무오류, `flutter test --no-pub` **497 passed**.
  새 상단 inset 재현 테스트 5개가 수정 전 실패하는 것을 확인했다. 이후 테스트를 보강했다.
- 신규 회귀 25개: 5가지 inset(0/20/44/59/62) × 2개 화면 크기의 헤더·버튼 탭 10개,
  홈 스크롤·랜덤 드래그의 상태바 픽셀 보호 1개, 인증 배치·동작 9개,
  저장 실패 후 링크·선택 사진 및 검색어 보존 2개, 높은 시트·원본 이미지 요청 공유 3개.
  기존 테스트의 assertion·시나리오를 축소하거나 skip하지 않았다.
- 최종 로컬 검사: `flutter analyze --no-pub` 무오류, `flutter test --no-pub` **522 passed**,
  `flutter build web --no-pub`, `flutter build ios --debug --no-codesign --no-pub` 성공.
  웹 빌드는 CupertinoIcons 폰트 탐색 경고를 출력했으며 실패는 없었다.
- 기기 검증 도구: `test/support/safe_area_preview.dart`는 실제 앱에 메모리 세션·인증 및 HTTP 대역을
  연결하고, `safe_area_device_check.dart`는 화면 콜백·합성 포인터로 기기 좌표·PNG·결과 JSON을 남긴다.
  운영 서버로 전달하는 fallback이 없으며 실제 저장 세션·공급자 SDK를 사용하지 않는다.
- 실기기: 연결된 **iPhone 15 / iOS 26.7.1**, 393×852 논리 픽셀·DPR 3·상단 inset 59px에서
  테스트 전용 앱 설치·실행 및 자동 화면 순회를 완료했다. 11개 헤더가 모두 top 59px·높이 64px였다.
  홈 헤더 동반 스크롤, 원본 이미지 디코딩·시트(top 157.4px), 키보드 308px가 열린 카테고리 시트
  (top 116px), 랜덤 카드 합성 드래그(offset 변경·다음 카드 전환), 전체 화면 저장 창을 확인했다.
  `report.json`은 passed=true·frameworkErrors=[]이며 PNG 17장을 확보해 화면 배치도 확인했다.
- 실기기 증거는 로컬 `/private/tmp/clipback-safe-area-iphone15-final/`에 보존한다. PNG는 Flutter
  렌더링 캡처로 OS 상태바·키보드 자체의 픽셀을 포함하지 않으며, 기기가 제공한 실제 inset을 함께
  측정했다. 실제 기기에 대역 데이터를 표시하고 화면 콜백·프로그램 포인터를 사용한 검증이다.
  사람의 수동 사용·실제 OAuth·운영 서버 쓰기·외부 AI·원격 CI·출시 검증은 수행하지 않았다.
- 첫 무선 실행은 연결이 끊겼으나 재시도 후 통과했다. 재시도의 Flutter 터미널에 앱 로그가 전달되지
  않아 기기 앱 임시 폴더의 결과 JSON과 PNG를 직접 읽어 검증했다. 기기 디버깅 심볼 준비 지연은
  앱 코드 오류와 구분했다. 검증 앱을 종료했으며 실제 사용자 세션 저장소에는 쓰지 않았다.
- 검증 후 `lib/main.dart`로 서명된 Debug 앱을 다시 빌드·설치해 iPhone의 다음 실행에 테스트 fixture가
  남지 않도록 복원했다. 복원 앱은 실행하지 않았으며 기존 앱 데이터·실제 세션을 삭제하지 않았다.
- 최종 `git diff --check` 통과. 커밋 범위는 상단 안전 영역 수정, 회귀 테스트, 기기 검증 도구와
  관련 문서이며, 로컬 기기 캡처·빌드 생성물·AGENTS.md는 포함하지 않는다.

### 2026-10-12 — 모바일 공유 창에서 직접 저장

- 브랜치: `feature/mobile-share-intake`, 기준 `af31ea9`(`origin/main`, 상단 안전 영역 PR #55 병합).
  구현 전 정적 분석 무오류와 기존 Flutter 전체 테스트 **522 passed**를 새로 확보했다.
- iOS는 Swift/UIKit Share Extension, Android는 Java ShareActivity에서 링크·이미지 미리보기,
  저장 계정 확인, 저장·완료·닫기를 제공한다. 정상 외부 공유는 Flutter 엔진·본앱을 시작하지 않는다.
  본앱에서 대기 초안을 선택하면 같은 네이티브 UI를 모달/내부 Activity로 열고 원래 화면으로 복귀한다.
- 공유 전용 토큰은 본앱 access/refresh와 분리한다. 플랫폼 영속 revision으로 계정 전환을 차단하고,
  발급 응답·401·저장 완료의 지연 응답을 원래 계정·서버 환경에 묶는다. 네이티브 저장 실패로 기존
  본앱 세션을 삭제하지 않으며, 확인된 본앱 인증 무효화는 공유 저장소 오류가 있어도 처리한다.
- 초안은 플랫폼 저장소만 소유한다. 같은 초안의 재시도는 같은 UUID를 사용하고, 성공 영수증은
  같은 계정·API 환경에서 목록·카테고리·통계 갱신이 완료된 뒤 소비한다. 후속 조회 실패는 저장을
  다시 실행하지 않는다. 공유 안내는 닫을 수 있으며 다음 앱 복귀에서 다시 확인할 수 있다.
- 본앱의 수동 저장·인증·게스트 승격·409 확인 흐름과 화면 경로를 유지한다. 외부 저장 반영은
  이미 조회한 목록 범위를 임시로 읽고 한 번에 반영해 검색어·필터·스크롤의 중간 초기화를 피한다.
- 서버에는 공유 자격 발급과 두 저장 API의 제한 인증·멱등성 영수증을 추가했다. 신규 migration은
  `202610120014`이며 기존 access 인증·멱등성 헤더 없는 저장도 계속 지원한다. 백엔드와 migration을
  먼저 배포한 후 새 앱을 배포해야 한다. 이번 작업에서 운영 배포는 수행하지 않는다.
- 테스트 전용 `test/support/share_preview.dart`, 로컬 소켓 fixture, 네이티브 송신 앱을 사용한다.
  실제 FastAPI 경로 확인에는 외부 공급자를 대체하고 폐기 가능한 별도 PostgreSQL DB를 연결한다.
  운영 서버·실제 OAuth·AI·사용자 데이터를 사용하지 않는다. 제품 진입점에 테스트 분기를 추가하지 않는다.
- 구현 중 발견한 경합도 회귀로 고정했다. 공유 준비 뒤 영수증 조회에서 토큰이 바뀌면 새 자격을
  한 번 더 준비하고, 성공한 저장의 목록 갱신이 실패해도 기존 항목·페이지 커서를 유지한다.
  커서 보존 검사는 수정 전 실패·수정 후 통과했다. 공유 안내의 실제 렌더링과 닫기·입력 보존도 검사한다.
- 네이티브 자격을 읽지 못한 경우에는 초안과 본앱 로그인을 보존하면서 공유 자격만 차단·재발급한다.
  발급이 거절된 뒤 기존 자격을 재사용할 때도 사용자·세션·만료뿐 아니라 API 환경을 확인한다.
  다른 서버 환경을 준비 완료로 오인하는 검사는 수정 전 실패·수정 후 통과했다.
- 백엔드 최종 검사: 전용 PostgreSQL을 포함해 **986 passed, 0 skipped**(81.32초), Ruff·compileall 통과.
  기존 Starlette `httpx` deprecation 경고 1건이 있다. 빈 DB 전체 upgrade와 직전 `202610110013`에서
  `202610120014`로 upgrade, `alembic check`를 통과했다. 실제 운영 DB에 적용한 결과가 아니다.
- Flutter 전체 테스트는 동시성 1로 **552 passed, 0 skipped**(1분 5초)를 확인했다.
  기존 522개에 공유 연동 회귀 30개가 추가됐으며 기존 assertion·시나리오는 축소하지 않았다.
  Dart 로컬 import 순환과 데이터 계층의 앱·기능 계층 역참조가 없는 것도 확인했다.
- 실제 수동 저장 경로에 공유 복구 안내를 띄우는 위젯 회귀를 추가했다. URL controller·화면 State,
  선택 이미지 bytes·파일명이 유지되고 사진을 다시 선택하거나 수동 저장을 자동 호출하지 않는 것을 확인했다.
- 최종 `flutter analyze --no-pub` **문제 없음**(7.7초), `flutter build web --no-pub` **성공**(102.4초).
  웹 빌드의 기존 CupertinoIcons 폰트 탐색 경고는 남아 있으며 실패는 없다.
- iPhone 16 / iOS 18.6 Simulator에서 네이티브 전체 **17 passed**. 실제 App Group·공유 Keychain,
  계정 revision·자격 교체·초안 파일 정리·401·잘못된 성공 응답·URLSession 경계를 확인했다.
  정상 링크, 이미지/지원하지 않는 입력, 401 후 본앱 모달 복구, 응답 유실, 30초 timeout의
  공유 UI 5개 시나리오도 각각 통과했다. 응답 유실·timeout 재시도는 서버 저장 건수가 한 번만 증가했다.
- 실제 Safari와 사진 앱의 시스템 공유 목록에서 허투루를 선택해 저장 완료·원래 앱 복귀를 확인했다.
  Safari가 같은 YouTube 영상의 `www` 주소와 `m` 주소(`ra=m`)를 함께 제공하는 경우를 재현했다.
  알려진 모바일 경로 표시만 정규화하고 다른 영상·query·여러 이미지는 거부한다.
  제공자 순서를 보존하며 이 재현 테스트는 수정 전 실패·수정 후 통과했다.
- 실제 로컬 FastAPI·전용 PostgreSQL을 사용한 iOS 시나리오도 통과했다(58.3초).
  기존 게스트 시작·온보딩·관심사 선택 → 검색어 작성 → 외부 Instagram 링크 공유 저장 →
  송신 앱 복귀 → 본앱 검색 화면 복귀를 실행했다. 콘텐츠와 같은 사용자의 멱등성 영수증이
  함께 commit된 것을 DB에서 확인했고 XCTest로 검색 입력값 `share warm state` 보존을 검사했다.
  복귀 PNG에는 남아 있던 초안 안내가 다시 표시되므로 입력 보존 근거는 전 화면 PNG와 값 assertion이다.
- iOS 저장 중 닫기·송신 앱 강제 종료의 추가 UI **2 passed, 0 failures**(122.8초).
  서버 저장 후 응답을 지연한 상태에서 중단하고 본앱 네이티브 모달로 같은 초안을 재개해,
  각 시나리오의 저장 건수가 한 번만 증가하고 작성 중인 수동 URL·저장창이 유지되는 것을 검사했다.
  최종 PNG는 안내를 닫아 기존 입력이 보이는 상태로 촬영했다. 마지막 Simulator fixture 빌드는
  36.1초에 성공했다. UI 검증은 위 시나리오별 실행 결과이며 하나의 일괄 테스트 실행 결과가 아니다.
- Android Medium Phone / API 36 Emulator의 네이티브 **25 passed, 0 skipped**(131.8초).
  실제 Keystore, 계정·서버 환경 경계, Activity 재생성·재공유, 저장 직후 닫기 경합,
  HTTP 401·응답 유실·30초 timeout·이미지 재시도를 확인했다.
  시스템 공유 목록 → 링크 저장 → 송신 앱 복귀와 401 → 본앱 대기 항목 → 복구 저장 →
  기존 검색 화면 복귀도 통과했다. 최종 PNG에는 안내를 닫은 뒤 검색어 `9`와 결과 목록이 보인다.
- Android API 33 Emulator에서도 동일 네이티브 **25 passed, 0 skipped**(74.6초).
  시스템 공유 목록에서 `content://` 이미지를 받아 미리보기 → 가로·세로 회전 → 저장 →
  시스템 뒤로 가기로 송신 앱 복귀를 확인했다. 기존 API 33 AVD는 데이터 공간이 부족해 설치가
  실패했으므로 기존 데이터를 보존하고 캐시된 동일 API 이미지로 전용 테스트 AVD를 만들었다.
  최신 코드의 실제 로컬 백엔드용 Android Debug APK 빌드도 성공했다(26초).
- Android의 실제 로컬 FastAPI·전용 PostgreSQL 검증은 기존 게스트 로그인·온보딩을 거쳐
  YouTube 링크와 PNG를 각각 한 건 저장했다. DB에서 콘텐츠 **2→4**, asset **0→1**,
  멱등성 영수증 **2→4**를 확인했다. 두 콘텐츠·영수증과 이미지 asset이 같은 테스트 게스트에
  귀속된 것도 대조했다. 외부 OAuth·metadata·OCR은 계속 테스트 대역이다.
- Android 홈의 기존 Weekly 카드에서 `BOTTOM OVERFLOWED BY 13 PIXELS`를 관찰했다.
  공유 전용 화면의 가림과는 별개이며, 해당 카드의 위젯·문구·높이는 이번 변경에 포함하지 않았다.
  공유 기능 검증을 앱 전체 화면의 레이아웃 무결성 검증으로 확대하지 않는다.
- 캡처·영상은 저장소 밖 `~/.codex/visualizations/2026/10/11/01a12b8d-120f-7aa1-a4c0-22b66028b14b/mobile-share/`
  아래 플랫폼별 폴더에 보관한다. 테스트 fixture·공급자 대역 검증과 실제 외부 앱 검증을 구분하며,
  실제 Instagram·YouTube 앱, OAuth 공급자, 외부 AI/OCR·metadata, 운영 서버 저장·배포, 원격 CI,
  실기기 서명·프로비저닝·TestFlight 검증은 수행하지 않았다.
- 최종 문서 링크·`git diff --check`·전체 staged diff 검사를 통과했다. 로컬 테스트 서버 2개와
  Simulator·Emulator·촬영 프로세스를 종료했고, 기존 AVD·Docker·DB 데이터는 보존했다.
  커밋에는 제품 코드·회귀 테스트·로컬 검증 도구·문서만 포함하며 `AGENTS.md`, 환경 파일,
  로컬 빌드 생성물·로그·PNG·영상은 포함하지 않는다.

### 2026-10-13 — Figma 화면 맞춤 계획 문서화

- 브랜치: `feature/figma-ui-alignment`, 비교 기준: 로컬 `main`의 `5389f48`.
- [Figma 화면 맞춤 계획](figma-ui-alignment-plan.md)에 기존 화면의 차이, 기능 연결,
  M 번호 신규 보완안, 정책 확인 항목, 단계별 완료 조건을 정리했다. 앱 구현은 미착수다.
- 기존 카테고리 삭제 시 콘텐츠 보존, 게스트 승격/계정 전환, API 저장 시점, 처리 중·미분류 표시,
  페이지 단위 개수의 의미를 유지하고 디자인과 충돌하는 항목은 별도 결정 대상으로 기록했다.
- 비교 설명을 재확인해 빈 홈의 저장 버튼은 이미 저장 화면을 연다는 점을 정정했다.
  이 항목은 저장 진입 추가가 아닌 문구·화면 구성 수정으로 분류했다.
- 문서화 직전 분석에서 수행한 iPhone 16 / iOS 18.6 대역 렌더링 결과와 공유 초기화 실패 배너에
  따른 화면 가림, Android·실제 공급자·운영 환경 미검증 범위는 계획 문서에 별도로 기록했다.
  이 결과를 이번 문서 변경 후 재실행한 검증으로 사용하지 않는다.
- 이번 변경은 계획 문서와 README·진행 기록에 한정한다. 로컬 문서 링크 55개와 앞서 조회한
  Figma 구조의 노드 참조 53개, 기준·명령·최종 diff와 공백 오류를 확인했다.
  앱 코드 변경이 없어 전체 앱 테스트·Simulator/Emulator 실행은 생략했다.

### 2026-10-13 — Figma 공통 텍스트 스타일 첫 구현

- 브랜치: `feature/figma-ui-alignment`, 기준: 계획 문서 커밋 `f6e2793`.
  사용자는 기존 화면 맞춤과 카테고리 삭제 시 콘텐츠 보존을 선택했다.
  이 결정은 게스트 정책 변경이나 신규 M 보완안 전체의 승인을 뜻하지 않는다.
- 첫 구현 커밋은 공통 스타일에 한정한다. `AppText.sectionTitle`은 Pretendard 18px/w600,
  자간 −0.45px과 기존 텍스트 색상을 사용한다. 본문 스타일을 상속하지 않고 `height`를 지정하지 않아
  폰트 기본 행간을 사용한다. `primaryButtonLabel`은 기존 16px/w700을 옮기며 색상을 지정하지 않는다.
- `SectionHeader`는 제목의 남은 폭을 `Expanded`로 제한하고 한 줄 말줄임을 적용한다.
  최소 높이 44px·세로 여백 각 8px·오른쪽 24px 아이콘을 사용하며 글자 확대 시 높이가 늘어난다.
  `PrimaryButton`의 높이 52/56px, 기본·사용자 지정 foreground·배경·8px 모서리·클릭을 보존한다.
  기존 생성자와 콜백 인터페이스, API·데이터 모델·저장·삭제 처리를 변경하지 않는다.
- 홈의 공통 섹션 제목 3곳에 적용했다. 홈 배치·문구·일러스트·페이지 점·추천 연결은 미착수이며,
  이번 결과를 홈 전체의 Figma 일치로 보고하지 않는다. 승인된 콘텐츠 보존 정책은 계획의 DEC-01에 반영했다.
- 구현 직전에 Figma `111:3604`의 최근 콘텐츠 제목·chevron 디자인 컨텍스트와 스크린샷을 새로 조회했다.
  기존 로컬 chevron 에셋은 329바이트, 24×24 viewBox이며 실제 24px 렌더링을 확인해 재사용했다.
- 이번 SDK는 Flutter **3.44.9 / Dart 3.12.2**다. 기존 잠금파일을 사용하고 의존성을 변경하지 않았다.
- 수정 전 `flutter test --no-pub test/common_text_style_test.dart`는 긴 제목 **4 failed**, 버튼 **4 passed**였다.
  폭 320/375px·글자 배율 1/2에서 오른쪽 넘침 78/413/23/358px을 재현했다.
  수정 후 같은 명령으로 **8 passed**를 확인했다. 실제 Pretendard 폰트와 Material 3 테마를 사용한다.
- `flutter test --no-pub --reporter expanded` **560 passed**, `flutter analyze --no-pub` **문제 없음**을 확인했다.
  변경 Dart 파일의 형식 검사도 **0 changed**였다. 기존 안전 영역 검사는 전체 테스트에 포함된다.
- [기기 프리뷰](../frontend/test/support/figma_common_style_preview.dart)는 실제 홈과 공통 위젯에 메모리 데이터를
  전달한다. 실제 세션·HTTP·네이티브 공유 서비스를 사용하지 않으며 제품 `main.dart`에 테스트 분기를 추가하지 않는다.
  기본 모드는 상단 도구막대로 화면을 전환하고, 자동 모드는 합성 포인터로 홈 스크롤·제목/아이콘/버튼 탭을 확인한다.
  기기 임시 폴더에 PNG 5개와 측정·콜백·프레임워크 오류를 담은 `report.json`을 기록한다.
- iOS **iPhone 16 / iOS 18.6 Simulator**: 최종 Xcode 빌드 30.6초 후 실행했다.
  논리 크기는 393×852, 안전 영역은 위 59px·아래 34px이다. 결과는 `passed: true`,
  `checksCompleted: true`, `componentChecksPassed: true`, 프레임워크 오류 **0건**이었다.
- Android **Clipback_Share_API_33 / Android 13(API 33) Emulator**: AVD는 Pixel 3a 설정이고
  실제 시스템 모델은 `sdk_gphone64_arm64`다. Gradle 빌드 195.4초·설치 79.5초 후 실행했다.
  논리 크기는 392.7×783.3, 안전 영역은 위 24px·아래 0px이다. 측정·탭은 끝까지 실행했고
  `checksCompleted: true`, `componentChecksPassed: true`, 공통 컴포넌트 프레임워크 오류 **0건**이었다.
  **전체 결과는 `passed: false`**다. 기존 홈 Weekly 카드의 `Column`에서 아래쪽 넘침 13px·3px이 발생했다.
- Android 홈 넘침은 이번 공통 스타일 오류와 구분한다. 2026-10-12 모바일 공유 기록에도 13px 넘침이 있으며,
  이번 변경에는 `home_screen.dart`가 포함되지 않는다. 일반 섹션 제목 높이도 기존 44px을 유지했다.
  이 홈 레이아웃 문제는 UI-04~05 후속 작업으로 남기고 Android 홈 전체를 통과했다고 보고하지 않는다.
- 양 플랫폼에서 일반 제목 높이 **44px**, 글자 배율 2에서 **59px**, 아이콘 **24px**을 확인했다.
  버튼 높이 **56/52px**, 기본 foreground `AppColors.main`·사용자 지정 `AppColors.text`와 탭 1회 호출도 확인했다.
  제목·좌측 여백·아이콘을 각각 누른 콜백은 배율별 3회로 총 6회였고 각 버튼은 배율별 1회로 총 2회였다.
  120px 합성 포인터 이동으로 홈 스크롤은 iOS 78px·Android 110px 변했으며 카테고리 제목 탭 콜백은 각각 1회였다.
- 보고서에는 전체 `passed`와 별도로 `checksCompleted`, `componentChecksPassed`, `componentFrameworkErrors`,
  화면별 `frameworkErrorDetails`를 기록했다. 오류를 지우거나 공통 컴포넌트 통과를 전체 홈 통과로 확대하지 않는다.
- 증거는 Git에서 제외된 `frontend/build/verification/figma-ui-01/{ios,android}/`에 보관한다.
  각 플랫폼 PNG 5개(`00_home`, `01_home_scrolled`, `02_empty_home`, `03_components`, `04_components_scale_2`)와
  `report.json`과 플랫폼별 `interaction.mp4`를 확보하고 화면·영상의 실제 검증 장면을 확인했다.
  영상에는 홈 스크롤·제목 탭·버튼 탭·글자 확대 전환이 포함되며, Android의 기존 홈 넘침도 그대로 남겼다.
- 실제 OAuth·AI/OCR·운영 서버·실기기·원격 CI는 이번 공통 스타일 검증 범위에 포함하지 않는다.
  검증에 사용한 Flutter 실행·촬영·Simulator·Emulator는 종료했다.
  최종 diff·문서 링크·공백 검사는 커밋 직전에 수행한다. 로그·PNG·영상·빌드 생성물·`AGENTS.md`는 커밋에서 제외한다.


### 2026-10-13 — Figma 기준 홈의 확정된 영역 적용

- 브랜치 `feature/figma-ui-alignment`, 수정 전 기준 `6f8fa73`.
  홈 상단(8+56px), 소개(기본 140px/좌측 16px/캐릭터 99×123px/버튼 모서리 8px),
  추천(133×120px), 최근 카드(298×186px), 홈 칩(기본 32px), 페이지 점을 적용했다.
  글자 확대에는 높이를 늘리고 제목 2줄·요약 3줄 및 실제 남은 공간 제한을 적용한다.
  Weekly 제목만 화살표를 숨기며 다른 공통 헤더 기준·기존 연결은 유지했다.
- 빈 홈은 필터 없음·조회 완료·로딩/오류 없음·양쪽 콘텐츠 목록 0개를 확인한 경우에만 C02를 표시한다.
  ‘아직 저장한 콘텐츠가 없어요.’·‘지금 하나만 저장해볼까요?’·‘첫 콘텐츠 저장하기’와 기존 저장 진입을 사용한다.
  필터 빈 목록·미조회·로딩·오류는 기존 표현을 유지한다. 최대 4개 카드와 콘텐츠 보존 정책도 유지한다.
- 페이지 점은 카드 중심(offset/306)으로 갱신한다. 필터·피드 버전·복사한 표시 ID 순서 변경 시 위치와 점을
  초기화하고 북마크만 변경되면 유지한다. 북마크 44×44px 탭 영역을 카드 안에 배치해 경계 잘림도 방지했다.
- Figma C01 `111:3584`·C02 `111:3681`의 컨텍스트와 원본 375×910 화면을
  **2026-10-13 20:58:44 KST / 11:58:44 UTC**에 새로 조회했다.
  기존 캐릭터 PNG는 여백/잘림이 달라 재사용하지 않았다. `111:3678`의 SVG가 모바일에서 빈칸으로
  렌더링되는 것을 확인해 같은 개별 노드를 Figma에서 3배율 PNG(297×369px)로 내보냈다.
  `111:3712` 상자는 원본 PNG 71×82px를 논리 67×78px 및 그림자 여유로 배치했다.
  Figma 전체 화면 이미지는 구현 에셋으로 사용하지 않았다. 임시 Figma URL도 앱에 남기지 않았다.
- **제품 수정 전** 동일한 데이터로 두 플랫폼의 정상/빈 홈을 새로 캡처했다.
  iOS는 오류 0건, Android는 기존 추천 카드 아래 넘침 **13px·3px**을 재현했다.
  추가 OS 포함 스크린샷은 수정 전 설치된 동일 baseline 바이너리를 직접 재실행해 촬영했다.
  수정 전·후 보고서의 콘텐츠 ID·카테고리·피드 상태·기종/크기·배율 1·스크롤 0이 일치함을 확인했다.
- 수정 전 홈 회귀 테스트 29개는 **6 passed / 23 failed**였으며 Android 추천 넘침을 재현했다.
  최종 홈 35개 + 안전 영역 11개 + 콘텐츠 변경 61개는 **107 passed**다.
  폭 320/375px·iOS/Android 테마·배율 1/2의 긴 문구, 0/1/4개, 실제 포인터 드래그와 점,
  필터/버전/ID 변경 초기화·북마크 위치 보존·처리 중 비활성화·북마크 네 모서리 탭을 검증했다.
  기존 콘텐츠 변경 테스트의 카테고리 탐색을 현재 홈 전용 태그 구조에 맞추고 기존 크기/말줄임 검사를 유지했다.
- 최종 `flutter test --no-pub --reporter expanded` **595 passed**,
  `flutter analyze --no-pub` **문제 없음**, 변경 Dart 8개 형식 검사 **0 changed**다.
  Flutter 3.44.9 / Dart 3.12.2, 기존 잠금파일을 사용하며 의존성을 변경하지 않았다.
- [홈 기기 프리뷰](../frontend/test/support/figma_home_preview.dart)는 실제 HomeScreen과 고정 메모리 데이터를 사용한다.
  제품 진입점·API·데이터 모델·저장 시점·콘텐츠 보존은 변경하지 않았다. 실제 세션/HTTP/저장을 사용하지 않는다.
  합성 포인터로 today/archive/content/bookmark를 각각 1회 확인하고 북마크의 콘텐츠 탭 전파가 없음을 확인했다.
  가로 드래그의 마지막 점은 **3/4**, 실제 저장 시트의 키보드 표시 및 닫기를 양쪽에서 확인했다.

| 플랫폼 | 이번 실행 결과 |
| --- | --- |
| iPhone 16 / iOS 18.6 Simulator | 앱 논리 크기 393×852, DPR 3, 안전 영역 위 59/아래 34px. 일반 배율 홈 오류 0건, 세로 스크롤 0→83px, 키보드 약 335.85px. 배율 2 카드 높이 316px를 추가 스크롤 후 viewport 안에서 확인했다. |
| Pixel 3a 설정 Clipback_Share_API_33 / Android 13 API 33 Emulator (`sdk_gphone64_arm64`) | 앱 논리 크기 392.7×783.3, DPR 2.75, 안전 영역 위 24/아래 0px. 일반 배율 홈 오류 0건이며 기존 추천 13px·3px 넘침이 사라졌다. 세로 스크롤 0→116.73px, 키보드 약 251.64px. 배율 2 카드 높이 316px를 viewport 안에서 확인했다. |

- **기기 전체 결과는 양쪽 모두 `passed: false`**다. 글자 배율 2의 기존 하단 탭 Column에서
  9px·43px 아래 넘침이 정상/빈 홈에 각각 발생해 플랫폼별 프레임워크 오류 **8건**을 보존했다.
  `checksCompleted`, `normalHomeChecksPassed`, `interactionChecksCompleted`, `scaledScenesCaptured`는 모두 true다.
  일반 배율 홈/동작 성공을 확대 전체 화면 성공으로 보고하지 않는다.
- 별도 좁은 화면 검사에서 기존 최근 카테고리 행의 가로 넘침도 확인했다.
  K02 `111:4667`·K03 `111:4683`의 미정 본문/상태, 필터·로딩·오류,
  확대 하단 탭/좁은 최근 카테고리 행은 [디자인 확인 필요 목록](figma-ui-alignment-plan.md)에 기록했다.
  새 안내·공지 카드/상세는 보류하고 현재 최근 카테고리 블록을 유지한다. Today/Weekly API·추천/공지 목적지·
  실제 읽지 않은 알림 데이터 연결은 후속 작업이며 고정 알림 점을 추가하지 않았다.
- 아래 비교는 OS 포함 원본 PNG다. Figma는 375×910·상태바 50px이며 실제 기기 크기/안전 영역이 다르다.
  앱 PhoneFrame의 최대 폭 375px 및 양쪽 여백, 네이티브 상태/제스처 영역을 보정하거나 잘라내지 않았다.
  기존 앱 내부 홈 인디케이터와 실제 OS 인디케이터 처리도 그대로 보인다.
  빈 홈은 안내·공지 카드 보류와 최근 카테고리 유지로 아래쪽 배치가 C02와 다르다.
  예시 콘텐츠/카테고리/북마크 차이는 고정 대역 데이터와 Figma 예시 데이터 차이다.
- 화면 증거는 아래 로컬 폴더에 보관하며 **Git에서 제외**했다. 프레임워크 PNG 7개/플랫폼과 OS 포함
  PNG 7개/플랫폼, report.json, 로그·영상 및 Figma 기준을 보존한다. 첫 재시도의 SVG 빈칸 증거도 after/initial에 보존했다.

증거 루트: `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/home-alignment`.

| 비교 | 변경 전 | 변경 후 | Figma 원본 |
| --- | --- | --- | --- |
| iOS 정상 홈 | [원본](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/home-alignment/ios/before/native_00_home.png) | [원본](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/home-alignment/ios/after/native_00_home.png) | [C01](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/home-alignment/figma/C01.png) |
| iOS 빈 홈 | [원본](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/home-alignment/ios/before/native_01_empty_home.png) | [원본](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/home-alignment/ios/after/native_01_empty_home.png) | [C02](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/home-alignment/figma/C02.png) |
| Android 정상 홈 | [원본](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/home-alignment/android/before/native_00_home.png) | [원본](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/home-alignment/android/after/native_00_home.png) | [C01](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/home-alignment/figma/C01.png) |
| Android 빈 홈 | [원본](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/home-alignment/android/before/native_01_empty_home.png) | [원본](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/home-alignment/android/after/native_01_empty_home.png) | [C02](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/home-alignment/figma/C02.png) |

페이지 점·스크롤·저장 시트·키보드와 확대 상태를 담은 영상:
[iOS](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/home-alignment/ios/after/interaction.mp4), [Android](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/home-alignment/android/after/interaction.mp4).
보고서: [iOS](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/home-alignment/ios/after/report.json), [Android](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/home-alignment/android/after/report.json).

- 첫 실행은 디스크 공간 부족으로 빌드가 실패했다. 저장소의 재생성 가능한 테스트/웹/해시 빌드 캐시만 정리한 뒤
  다시 빌드·실행했다. 기존 화면 증거와 사용자 파일·AVD·세션/DB 데이터는 보존했다.
- 실제 OAuth·운영 서버·실기기·실제 저장 완료·원격 CI는 이번 검증 범위에 포함하지 않는다.
  최종 diff·로컬 문서 링크 83개·공백·생성 파일/민감 정보 제외를 확인했다. 변경 13개 파일만 한 커밋으로 저장한다.
  푸시·PR은 수행하지 않는다. AGENTS.md는 계속 로컬 제외 파일로 유지한다.

- 최종 H.264 영상은 iOS 약 86초·Android 약 169초이며 ffprobe와 영상 장면을 확인했다.
  Flutter·녹화 세션과 이번 작업에서 실행한 Simulator/Emulator를 종료했고 기존 기기 데이터는 보존했다.

### 2026-10-13 — 확대 글자·좁은 화면의 하단 탭과 홈 카테고리 넘침 수정

- 브랜치 `feature/figma-ui-alignment`, 변경 전 기준 `cc73b21`.
  사용자가 하단 탭 이름 최대 두 줄·높이 확장과 최근 카테고리 이름/날짜 각각 한 줄 말줄임을 확정했다.
  글자를 줄이지 않는다. OS 인디케이터·하단 안전 영역 변경, 안내·공지, 추천 API, 저장 화면 맞춤은 제외한다.
- [공통 하단 탭](../frontend/lib/shared/widgets/navigation_bar.dart)은 Pretendard 12px/Medium·자간 −0.3px을
  명시한다. 폭 56px에서 실제 TextScaler로 네 라벨을 측정하고 가장 높은 라벨 공간을 공유한다.
  기본 배율보다 늘어난 높이를 항목 56px·내부 64px·전체 96px에 동일하게 더한다.
  아이콘은 높이 28px과 같은 위쪽 위치를 유지하고 라벨은 공통 영역의 위쪽부터 배치한다.
- 저장 버튼의 선언 크기 72px가 기존 64px Row에 의해 실제 높이 64px로 제한되는 문제도 검사에서 확인했다.
  버튼은 전체 바의 Stack에 높이 72px·상단 −22px로 배치하고 Row에는 같은 폭의 자리를 유지한다.
  원형 버튼 중심뿐 아니라 하단 가장자리에서 2px 안쪽의 실제 포인터 탭도 확인한다.
  기존 색상·탭 연결·앱 내부 인디케이터·공개 생성자/콜백은 유지한다.
- [최근 카테고리 행](../frontend/lib/shared/category/category_widgets.dart)은 텍스트 열에 남은 폭을 할당하며
  이름·날짜 각각 `maxLines: 1`과 말줄임을 적용한다. 확대 시 행 높이는 글자에 따라 늘어난다.
  폴더 40px·화살표 18px·간격·전체 행 탭과 고정 날짜는 유지한다. API·데이터 모델은 변경하지 않는다.
- Figma 공통 내비게이션 `111:3680`, C01 `111:3584`, C02 `111:3681`의 컨텍스트와 원본을
  **2026-10-13 22:23:08 KST / 13:23:08 UTC**에 새로 조회했다.
  확대 상태와 기존 최근 카테고리 행의 전용 Figma는 없다. 기본 배율 원본과 사용자 확정 기준을 구분하며
  대체 디자인 이미지는 만들지 않았다.
- **제품 수정 전에** 두 플랫폼에서 이번 기준 커밋으로 정상 홈·빈 홈·긴 카테고리, 배율 1/2의
  여섯 화면을 새로 촬영했다. 초기화된 조회 완료·필터 없음·로딩/오류 없음 상태, 동일 콘텐츠 ID와
  카테고리 순서·긴 이름·기종/화면 크기·배율·스크롤 0을 고정했다. 이전 커밋의 화면을 재사용하지 않았다.
  각 플랫폼의 변경 전 보고서는 `baselineCaptured: true`, `checksCompleted: true`, `passed: false`,
  프레임워크 오류 **14건**이었다. 하단 탭은 배율 2에서 9px·43px 넘침,
  긴 카테고리는 iOS 194/650px·Android 216/695px의 가로 넘침을 기록했다.
- [확대 레이아웃 테스트](../frontend/test/scaled_navigation_layout_test.dart) 30개는 수정 전 **30 failed**였다.
  폭 320/375px·iOS/Android 테마·배율 1/1.5/2에서 라벨/아이콘 위치와 잘림, 카테고리 말줄임,
  네 탭·저장 버튼·행의 실제 탭 호출을 검사한다. 공유 하단 바를 쓰는 홈·아카이브·즐겨찾기·Placeholder의
  확대 상태와 마이·상세의 기본 상태를 검사하고 상세 이전/다음 및 저장 시트 진입도 확인한다.
  마이·상세 본문의 기존 배율 2 오류는 범위 밖이며 아래 보류 목록에 기록했다.
- 초기 수정의 버튼 하단 탭 누락은 **26 passed / 4 failed**로 재현했다.
  최종 수정 후 확대 30개 + 홈 35개 + 안전 영역 11개 **76 passed**를 확인했다.
  최종 `flutter test --no-pub --reporter expanded` **625 passed**,
  `flutter analyze --no-pub` **문제 없음**이다. Flutter 3.44.9 / Dart 3.12.2,
  기존 잠금파일을 사용하며 의존성을 변경하지 않았다.
- [홈 프리뷰](../frontend/test/support/figma_home_preview.dart)와
  [공유 하단 탭 프리뷰](../frontend/test/support/navigation_layout_preview.dart)는 실제 화면과 고정 메모리 데이터를 사용한다.
  제품 진입점에 테스트 분기를 추가하지 않으며 세션·HTTP·운영 데이터·실제 저장을 사용하지 않는다.
  홈의 저장 시트와 실제 키보드 insets 확인은 최대 15초 동안 기다린다. 이전 2.5초 대기의 Android 시간 초과
  자료는 `android/after/initial`에 보존하고 실제 키보드 표시가 확인된 재실행 결과와 구분한다.
- 최종 코드를 고정한 뒤 홈·공유 하단 탭 프리뷰를 각 플랫폼에서 새로 실행했다.
  네 보고서 모두 **`passed: true`·`checksCompleted: true`·프레임워크 오류 0건**이다.
  이전 버튼 배치의 중간 실행 자료는 `pre-hitfix`로 보존하며 최종 결과와 구분한다.

| 플랫폼 | 최종 홈·공유 하단 탭의 실제 실행 결과 |
| --- | --- |
| iPhone 16 / iOS 18.6 Simulator | 논리 크기 393×852, DPR 3, 안전 영역 위 59/아래 34px. 정상·빈·긴 카테고리의 배율 1/2 홈 모두 오류 0건. 일반 홈 세로 스크롤 0→83px, 키보드 첫 양수 inset 약 335.24px·실제 표시/닫기 확인. 확대 카드 높이 316px, y=368.375~684.375로 viewport y=59~712 안에서 확인. |
| Pixel 3a 설정 Clipback_Share_API_33 / Android 13 API 33 Emulator (`sdk_gphone64_arm64`) | 논리 크기 392.7×783.3, DPR 2.75, 안전 영역 위 24/아래 0px. 같은 여섯 홈 상태 모두 오류 0건. 일반 홈 세로 스크롤 0→116.73px. 첫 양수 키보드 inset 약 104.73px는 표시 애니메이션 중의 값이며, OS 포함 촬영에서는 실제 키보드 전체 표시/닫기를 확인. 확대 카드 높이 316px, y=314.58~630.58로 viewport y=24~643.27 안에서 확인. |

- 양쪽 홈에서 today/archive/content/bookmark 호출 각각 1회, 북마크의 카드 탭 전파 없음,
  마지막 페이지 점 **3/4**, 빈 홈 저장 진입·실제 키보드·닫기를 확인했다.
- 공유 프리뷰는 양쪽에서 실제 홈·아카이브·즐겨찾기·마이·상세·Placeholder를 **배율 1**로 확인했다.
  공통 하단 탭은 별도 폭 375px/배율 1.5·2 및 폭 320px/배율 2에서 확인했다.
  바 높이는 배율 1/1.5/2에서 **96/124/140px**, 아이콘 28px·네 아이콘 상단 일치,
  라벨 영역 포함·탭 항목 폭 56px·최소 높이 56px, 추가 버튼 72×72px·상단 −22px이다.
  각 확대 조건에서 저장 버튼의 중심·하단 가장자리 탭은 각각 한 번 호출됐다.
  archive/bookmark/my 탭 각 4회·home 5회·카드 1회·상세 이전/다음 각 1회·추가 버튼 총 6회이며
  상세 페이지 버튼은 바와 겹치지 않았다. Placeholder의 실제 Navigator 복귀도 확인했다.
- 홈 비교 프레임워크/OS 원본 PNG는 변경 전 6개·변경 후 11개씩, 공유 프리뷰는 9개씩 확보했다.
  두 플랫폼의 변경 전·후 보고서에서 기종·논리 크기·DPR·insets·콘텐츠 ID·카테고리·긴 이름·조회 상태·
  배율 1/2·스크롤 0이 일치함을 대조하고 `comparison-validation.json`에 원본 해시와 결과를 기록했다.

증거 루트: `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/scaled-layout`.

- [모든 원본 3열 비교](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/scaled-layout/comparison-document.html)는
  iOS/Android와 정상·빈·긴 카테고리의 배율 1/2를 선택해 **변경 전 → 변경 후 → Figma 기본 원본** 순서로 보여준다.
  OS 안전 영역·기기 크기·PhoneFrame 여백·상태바 시각을 보정하지 않는다.
  C02 안내·공지 대신 유지한 최근 카테고리 영역과 고정 대역 데이터 차이는 기존 보류 범위다.

| 최종 실행 증거 | iOS | Android |
| --- | --- | --- |
| 홈 동작 영상 | [영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/scaled-layout/ios/after/interaction.mp4) | [영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/scaled-layout/android/after/interaction.mp4) |
| 공유 하단 탭 동작 영상 | [영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/scaled-layout/ios/navigation/interaction.mp4) | [영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/scaled-layout/android/navigation/interaction.mp4) |
| 홈 보고서 | [보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/scaled-layout/ios/after/report.json) | [보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/scaled-layout/android/after/report.json) |
| 공유 하단 탭 보고서 | [보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/scaled-layout/ios/navigation/report.json) | [보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/scaled-layout/android/navigation/report.json) |
| 홈 → 공유 하단 탭 결합 영상 | [영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/scaled-layout/ios/interaction-final.mp4) | [영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/scaled-layout/android/interaction-final.mp4) |

- 결합 영상은 원본 네 영상 스트림을 플랫폼별로 시간순 연결했다. 스케일·재프레이밍·재인코딩 없이
  `ffmpeg -c copy`를 사용하며 원본도 보존했다. ffprobe로 iOS H.264 1178×2556/192.198초,
  Android H.264 1080×2220/240.834초를 확인했다. 비교에 쓰는 iOS PNG는 원본 1179×2556 그대로다.

- 남은 디자인 확인: 앱 내부 홈 인디케이터와 실제 OS 영역 처리, 마이 본문 배율 2의 하단 넘침 6px/59px,
  상세 본문 배율 2의 오른쪽 넘침 112px/92px. 마이는 J01 `111:4707`·J02 `111:4533`,
  상세는 F02 `111:3842`·F03 `111:3771`·F04 `111:3909`의 확대/좁은 상태 확인이 필요하다.
  본문 디자인은 임의로 수정하지 않았다. [계획의 디자인 확인 목록](figma-ui-alignment-plan.md)을 따른다.
- 실제 OAuth·운영 서버·실기기·원격 CI·실제 저장 완료는 이번 로컬 대역 검증에 포함하지 않는다.
  화면 증거·빌드 생성물·`AGENTS.md`는 커밋에서 제외하며 푸시·PR을 수행하지 않는다.
- 최종 변경 Dart 5개 형식 검사 **0 changed**, 로컬 문서 링크 **106개 모두 존재**, 최종 diff·공백·
  생성 파일/민감 정보 제외를 확인했다. 이번 작업에서 부팅한 Simulator·Emulator와 Flutter/녹화 프로세스를
  종료하고 AVD·앱 데이터를 보존했다. 원본 비교를 확인할 로컬 브라우저와 읽기 전용 비교 서버는 유지한다.
  제품 2개·테스트/프리뷰 3개·문서 3개, 총 8개 파일만 한 커밋으로 저장한다.

### 2026-10-14 — OS 인디케이터와 하단 안전 영역 정리

- 작업 브랜치 `feature/figma-ui-alignment`, 변경 전 기준 `d01873c`.
  사용자 확정 기준은 **탭 영역 64px + 글자 확대 증가분 + 실제 OS 하단 안전 여백**이다.
  대상은 공통 탭을 쓰는 홈·아카이브·즐겨찾기·마이·상세·Placeholder와 카드 다시보기다.
  로그인·시작·저장 화면 맞춤, 마이·상세 본문의 확대 디자인, 안내·공지와 추천 API는 후속으로 둔다.
- 공통 바는 `MediaQuery.viewPaddingOf(context).bottom`을 한 번만 합산한다.
  별도 `SafeArea`나 `viewInsets.bottom`을 더하지 않으므로 키보드 표시에도 바 높이는 안정적으로 유지된다.
  기존 최대 두 줄·글자 배율·네 아이콘 정렬·28px 아이콘·색상·탭 연결과 저장 버튼 72×72px/상단 −22px을 유지한다.
  기존 96/140px 높이는 이전 커밋의 결과이며 이번 결과를 그 수치에 강제로 맞추지 않는다.
- 카드 다시보기는 빈 상태·카드 상태 모두 하단 안전 영역을 적용한다. 카드의 기존 크기·위치·진행 표시·
  드래그/다음 카드·북마크·나가기 동작을 보존하고 카드와 전환 애니메이션을 안전 영역 안에서 클리핑한다.
  두 사용처의 가짜 선과 사용하지 않는 공통 `NavigationHomeIndicator`를 제거한다.
  화면 생성자·콜백·API·데이터·콘텐츠 보존 정책과 OS 탐색 표시/네이티브 전체 화면 설정은 변경하지 않는다.
- Figma 하단 바 `111:3680`, C01 `111:3584`, C02 `111:3681`, G02 `111:5047`의 컨텍스트·원본을
  **2026-10-14 01:58:26 KST / 2026-10-13 16:58:26 UTC**에 새로 조회했다.
  변경 전 촬영 gate 확인 후 제품 수정 직전 **02:28:08 KST / 17:28:08 UTC**에 네 노드를 다시 조회했다.
  초기와 직전 원본 PNG는 모두 byte 단위로 같음을 확인했고 두 조회의 컨텍스트·시각을 각각 보존했다.
  전체 화면 원본은 비교 근거로만 사용하며 제품 에셋으로 사용하지 않는다.
  Figma의 96px 고정 바/그려진 인디케이터와 실제 OS 여백은 사용자 확정 기준에 따라 구분한다.
- **제품 수정 전에** 같은 고정 대역 데이터로 iOS·Android 제스처·Android 3버튼의 새 변경 전 화면을 확보했다.
  홈 정상·빈 상태/배율 1·2, 공유 탭 6개 화면/단독 확대 탭, 카드 다시보기의 정상·빈·드래그·다음 상태를 포함한다.
  변경 전 보고서 9개, Flutter PNG 72개·OS 포함 원본 PNG 72개·원본 영상 9개를 기록했다.
  `before-gate.json`에서 제품 diff가 비어 있고 기준 커밋이 `d01873c`임을 확인했으며 이전 촬영 자료를 재사용하지 않았다.
  BEFORE 보고서의 `passed`는 기존 화면 렌더링/입력 검사의 결과다. 새 OS 높이·클리핑 기준은 AFTER에만 적용하므로
  BEFORE의 오류 0건을 인디케이터 중복·OS 경계 침범이 없다는 의미로 사용하지 않는다.
- [새 하단 안전 영역 테스트](../frontend/test/bottom_safe_area_test.dart)는 수정 전 **6 passed / 61 failed**다.
  폭 320/375px·Android/iOS·배율 1/1.5/2·하단 여백 0/24/34/48px의 실제 바/라벨/아이콘/탭 경계를 확인한다.
  라벨 증가분은 실제 RenderParagraph 높이로 검증하며 제품의 TextPainter 계산을 테스트에 복제하지 않는다.
  앱이 그리는 검은 선의 픽셀, 카드 안전 경계와 실제 드래그/240ms 전환의 하단 픽셀 침범도 재현했다.
  키보드 상태 4개와 하단 여백 0인 카드 2개는 기존 성공으로 보존했다.
- 키보드 `(padding.bottom=0, viewPadding.bottom=34, viewInsets.bottom=300)`에서 바 높이 유지·
  키보드 높이 미합산·닫은 뒤 복원, 저장 버튼 중심/하단 탭과 네 경로를 확인했다.
  관련 확대 30개·홈 35개·상단 안전 영역 11개·저장/검색 2개·시트 3개도 함께 회귀 검사했다.
  상단 헤더의 기존 64/56px와 홈 소개 140px는 하단 바 높이와 다른 기준이며 그대로 유지한다.
- 최종 관련 묶음은 새 하단 67개와 위 회귀 검사 합계 **148 passed**다.
  기존 확대 테스트의 기본 바 높이는 iOS 98px·Android 64px의 실제 주입 inset 기준으로 갱신했다.
  홈·상단·저장·시트 검사의 기대값은 바꾸지 않고 통과했다.
- 최종 `flutter test --no-pub --reporter expanded` **692 passed**,
  `flutter analyze --no-pub` **문제 없음**(6.1초), 변경 Dart 7개 형식 검사 **0 changed**다.
  이번 기기 실행의 홈·공통 탭·카드 다시보기 AFTER 보고서 **9개 모두 `passed: true`·`checksCompleted: true`·
  프레임워크 오류 0건**이다. 이전 625개 통과와 과거 기기 성공을 이번 결과로 사용하지 않는다.

| 실행 조건 | 실제 창·안전 여백 | 하단 바 배율 1 / 1.5 / 2 | 카드 정상·빈·드래그·전환의 하단 경계 |
| --- | --- | --- | --- |
| iPhone 16 / iOS 18.6 Simulator | 논리 393×852, DPR 3, 상단 59px·하단 viewPadding 34px | 98 / 126 / 142px | y=818px = 852−34, 카드 크기·상단 257px 유지 |
| Pixel 3a 설정 / Android 13 API 33 / 제스처 | 논리 392.7×783.3, DPR 2.75, 상단 24px·하단 viewPadding 0px | 64 / 92 / 108px | y=783.27px, 실제 OS 제스처 바는 Flutter 창 외부 |
| 같은 Emulator / 3버튼 | 논리 392.7×759.3, DPR 2.75, 상단 24px·하단 viewPadding 0px | 64 / 92 / 108px | y=759.27px, 실제 OS 3버튼 바는 Flutter 창 외부 |

- Android 기종은 AVD `Clipback_Share_API_33`의 `sdk_gphone64_arm64`다. 하단 여백 0은 실제 보고값이며,
  Android에 임의의 32/34px를 더하지 않는다. OS를 포함한 원본에서 앱의 검은 선 제거와 탐색 표시 보존을 확인했다.
  iOS의 새 높이는 Figma 96px보다 2px 높으며 확대와 실제 여백에 따른 차이도 사용자 확정 기준에 따른다.
- 세 조건의 홈에서 today/archive/content/bookmark 각 1회, 북마크의 카드 탭 전파 없음,
  페이지 점 3/4, 세로 스크롤·빈 홈 저장 진입·실제 키보드 표시·닫기를 확인했다.
  일반 홈 세로 이동은 iOS 85px·제스처 84.73px·3버튼 108.73px다.
  첫 양수 키보드 inset은 각각 약 335.44/268/194.18px로 애니메이션 도중 측정값이며,
  전체 키보드 표시·닫기는 OS 포함 원본과 영상으로 별도 확인했다.
- 공유 탭은 여섯 실제 화면 본문을 배율 1로, 단독 탭은 375px/배율 1.5·2와 320px/배율 2로 실행했다.
  archive/bookmark/my 각 4회·home 5회·카드 1회·상세 이전/다음 각 1회·추가 버튼 6회,
  세 확대 조건의 추가 버튼 중심·하단 가장자리 탭 각각 1회와 Placeholder의 실제 Navigator 복귀가 통과했다.
  아이콘 28px·정렬·두 줄 라벨·추가 버튼 72×72px/상단 −22px·상세 버튼 비겹침을 확인했다.
- 카드 다시보기는 북마크·카드 열기·정상 나가기·빈 상태 나가기 각 1회,
  드래그 offset 약 0.6653과 다음 카드 인덱스 1을 확인했다.
  카드의 496px 높이·상단 좌표는 변경 전과 같으며 하단 보호와 가짜 선 제거만 바뀌었다.
- 세 조건의 변경 전·후 보고서에서 기종·실제 창·DPR·고정 데이터·배율·콜백 수와 프리뷰 소스 해시가 일치한다.
  변경 전·후 각각 OS 원본 PNG 72개·Flutter PNG 72개·원본 영상 9개를 확보했다.
  [독립 대조 결과](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/bottom-safe-area/root-final-verification.json)에
  보고서 9쌍·이미지 크기 일치·비교 57건의 원본 경로 존재를 기록했다.

증거 루트: `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/bottom-safe-area`.

- [OS 포함 원본 3열 비교](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/bottom-safe-area/comparison-document.html)는
  플랫폼·탐색 방식별로 **변경 전 → 변경 후 → Figma**를 보여준다. 각 비교의 데이터·배율·스크롤·기종·OS·탐색 방식을 맞춘다.
  원본의 OS 영역/프레임 크기/대역 콘텐츠 차이는 유지하며 비교를 위해 픽셀을 잘라내거나 보정하지 않는다.
  마이·상세/Placeholder 등은 이번 수정 대상인 하단 바 원본을 Figma 참조로 쓰며 본문 전체 일치로 보고하지 않는다.
  확대·카드 드래그/빈 상태의 전용 디자인은 없으므로 기본 원본과 사용자 확정 OS 기준을 명시한다.
  비교는 각 조건의 홈 6개·공통 탭 9개·카드 4개, 총 **57건**이다.
  원본 모바일 시계·기기 프레임·OS 여백을 그대로 보존하며 원본 Figma도 재가공하지 않는다.

| 이번 AFTER 동작 영상 | 자료 |
| --- | --- |
| iOS 홈 → 공통 탭 → 카드 다시보기 | [영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/bottom-safe-area/ios/interaction-final.mp4) |
| Android 제스처의 같은 동작 | [영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/bottom-safe-area/android-gesture/interaction-final.mp4) |
| Android 3버튼의 같은 동작 | [영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/bottom-safe-area/android-three-button/interaction-final.mp4) |

- 세 결합 영상은 각 조건의 AFTER 원본 3개를 `ffmpeg -c copy`로 연결하고 재인코딩·스케일·재프레이밍하지 않았다.
  iOS 녹화 원본은 H.264 1178×2556이고 PNG 원본은 1179×2556이다. Android는 세 영상 모두 1080×2220이다.
  ffprobe로 최종 길이 iOS 238.318초·제스처 267.959초·3버튼 299.305초를 확인했다.
  녹화 원본의 가변 프레임률·시간 기준을 유지한 `ffmpeg -fps_mode passthrough -enc_time_base -1 -f null -` 전체 디코딩도
  세 영상 모두 종료 코드 0·오류 로그 0바이트다. 영상 파일을 다시 쓰지 않고 검증했다.
  원본 영상과 보고서는 각 조건의 `after/home`, `after/navigation`, `after/card-review`에 각각 보존했다.
- 별도 `EntryHomeIndicator`의 실제 사용처는 `SplashScreen`의 `EntrySurface`다. A01 `111:3380`의 전체 프레임과
  OS 안전 영역 배치를 확인할 후속 항목으로 남긴다. 저장 화면의 `_SaveHomeIndicator`는 D01 `111:4765`,
  D05 `111:4902`, D07 `111:4814`, D09 `111:4865`의 버튼·키보드·결과 배치와 함께 별도 디자인 확인 대상으로 유지한다.
  공통 탭의 정리를 앱 전체 인디케이터 제거 완료로 보고하지 않는다. [디자인 확인 목록](figma-ui-alignment-plan.md)을 따른다.
- 실제 OAuth·운영 서버·원격 CI·실기기·실제 저장 완료는 이번 로컬 대역 실행에 포함하지 않는다.
  화면 증거·빌드 생성물·`AGENTS.md`는 커밋에서 제외하고 푸시·PR을 수행하지 않는다.
- SVG 로더의 기존 `unhandled element <filter/>` 메시지는 변경 전·후 로그에 동일하게 남아 있다.
  이번 하단 변경과 구분하며 프레임워크 예외 0건을 모든 로그 메시지의 부재로 보고하지 않는다.
- Android 탐색 설정을 원래 mode 2/gestural 및 전체 navbar overlay 목록과 일치하게 복원했다.
  이번에 시작한 두 기기·Flutter·녹화 프로세스를 종료하고 AVD·앱 데이터를 보존했다.
  이전 비교 서버 8765와 이번 원본 비교 서버 8766·브라우저는 유지한다.
  최종 문서 링크 127개·diff·공백·민감 정보/생성 파일 제외를 확인했으며,
  제품 2개·테스트/프리뷰 5개·문서 3개, 총 10개 파일만 한 커밋으로 저장한다.

### 2026-10-14 — 최신 Figma `261008` 기준으로 문서 갱신

- 작업 브랜치 `feature/figma-ui-alignment`, 코드 비교 기준 `a9eb69d`.
  사용자가 최신 디자인을 [허투루 UIUX 디자인의 `261008`](https://www.figma.com/design/b2lmAo9VtbL6Qi0mzX5IMu/?node-id=912-13961)으로 지정하고
  기준·다음 커밋 계획 정리 후 문서 갱신을 요청했다. 이번 범위는 계획 문서·프론트 README·이 진행 기록 3개다.
- 실제 파일 키 `b2lmAo9VtbL6Qi0mzX5IMu`, 부모 페이지 `WireFrame & UI`(`3:5961`),
  섹션 `261008`(`912:13961`)을 Figma에서 확인했다. 섹션 전체 구조·노드 이름·설명은
  **2026-10-14 12:43:38 KST / 03:43:38 UTC**에 다시 조회하고 후보·보완안·현재 보류 항목의 ID를 대응했다.
- 앞선 기준 전환 검토 **12:36~12:41 KST / 03:36~03:41 UTC**의 홈 C01 `912:16240`,
  C02 `912:16337`, 하단 바 `912:16336`, 홈 최초 로딩 `912:16483`의 상세 컨텍스트·스크린샷도 근거로 사용했다.
  이 네 화면 외에는 구조·설명 중심의 확인이며 모든 화면의 스타일·실행을 재검증한 것은 아니다.
  구현 직전에 해당 화면의 상세 컨텍스트와 원본을 다시 확보한다.
- `6f8fa73`·`cc73b21`·`d01873c`·`a9eb69d`의 적용·검증 기록은 이전 별도 파일
  `svNWsTFh8Ws1Mpt8XQIcrN / 261007`을 사용한 결과로 보존했다. 기존 조회 시각·노드·테스트 수·
  기기 측정·이미지·영상 링크를 최신 기준의 성공으로 치환하지 않았다.
  2026-09-07 캐시는 현재 파일의 옛 `업데이트_260730`(`624:16572`) 자료임을 정정하고 캐시 자체는 보존했다.
- 최신 `912:16483` 원본의 전면 캐릭터·세 점과 설명 `912:16497`의 콘텐츠·카테고리 스켈레톤이 충돌한다.
  적용 조건·표현을 확인할 항목으로 기록하며 기존 홈 로딩 표현을 유지한다.
  K02 `912:14488`·K03 `912:14504`는 본문 추후 작성, J07 `912:14410`·K04 `912:14447`은 본문 미작성이다.
  알림·문의의 M 보완안도 함께 기록했다. K05 `912:14450`의 약관 본문은 존재하며 운영 문안 확정과 구분했다.
- 최신 E12 `912:17268`의 동시 삭제 문구와 관계없이 사용자 확정 콘텐츠 보존 정책을 유지한다.
  공통 바의 `64 + fontExtra + viewPadding.bottom` 한 번 합산·실제 OS 표시, 확대 라벨/최근 카테고리 말줄임,
  기존 최대 4개 홈 카드·페이지 점·저장 시점도 변경하지 않는다.
  새 링크만으로 게스트 로컬 저장·계정 병합·추천 API·M 기능을 일괄 구현하도록 범위를 확대하지 않았다.
- [Figma 화면 맞춤 계획](figma-ui-alignment-plan.md)의 활성 출처·화면/M 노드·보류 목록·구현 순서를 갱신하고
  [프론트 README](../frontend/README.md)에서 현재 기준과 과거 구현·검증 기록을 구분했다.
  후속 화면 변경은 같은 조건의 새 변경 전·후·최신 Figma 3열 비교와 양 플랫폼 검증을 진행한다.
- 조회 원본과 선택한 컨텍스트·PNG는 Git 밖
  `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/figma-261008-reference`에 보존한다.
  이 자료는 참조 근거이며 앱 구현 에셋이나 새 실행 검증으로 사용하지 않는다.
- 앱 코드·테스트·API·빌드 설정은 수정하지 않았다. 문서만 변경해 전체 Flutter 테스트·정적 분석·
  Simulator/Emulator·실기기·원격 CI·운영 서버 검사는 이번에 실행하지 않았다.
  앞선 692개 테스트와 기기 성공을 이번 문서 작업의 검사 결과로 재사용하지 않는다.
- 커밋 제목은 `docs: 최신 피그마 261008 기준으로 화면 맞춤 계획 갱신`이며 문서 3개만 저장한다.
  `AGENTS.md`·조회 원본·화면 증거·생성 파일은 제외하고 푸시·PR을 수행하지 않는다.
- 실제 문서 검사에서 로컬 Markdown 링크 **132개 모두 존재**, 최신 Figma ID **75개 모두 조회한 섹션에 존재**함을 확인했다.
  노드 이름과 후보·보류 항목의 대응도 별도로 읽어 확인했다. 기존 화면/영상 링크 40개·과거 조회 시각과
  진행 기록의 원문을 보존했으며 최종 diff·`git diff --check`로 문서 외 변경·공백·생성 파일 포함 여부를 확인했다.

### 2026-10-15 — 사진 저장 결과 문구와 실제 제출 입력 유지

- 브랜치 `feature/figma-ui-alignment`, 변경 전 기준 `b905769`.
  최신 `b2lmAo9VtbL6Qi0mzX5IMu`의 `WireFrame & UI > 261008`에서 D05 `912:16639`·D09 `912:16602`를 사용했다.
  초기 원본·컨텍스트를 확보하고 제품 수정 직전 **2026-10-15 17:28:27 KST / 08:28:27 UTC**에 다시 기록했다.
  원본 화면은 비교 자료로만 사용하며 제품 에셋으로 사용하지 않았다.
- 사진 결과 제목을 ‘저장할 사진’으로 바꾸고 링크 검증 메시지와 바로 앞 5px 간격은 링크에만 표시한다.
  사진 파일명·기존 이미지 미리보기·링크의 기존 제목/검증 표현을 유지한다.
  제출 직전 URL/파일명/사진 바이트 참조를 캡처하여 같은 값으로 저장 콜백을 호출하고 성공한 콘텐츠와 함께 보관한다.
  서버가 반환한 콘텐츠 종류나 현재 초안으로 결과 입력을 다시 판정하지 않는다.
- 요청 중 탭 전환·입력 변경·다른 사진 선택을 허용한다. 성공하면 실제 제출한 종류의 탭으로 복귀해
  결과 맨 위를 한 번 표시하며 닫기 전까지 탭과 결과를 유지한다. 실패 시 현재 초안을 보존하고 재시도 때 새로 캡처한다.
  늦은 사진 선택기/붙여넣기, 오래된 제출 콜백과 화면 종료 뒤 응답이 결과·스크롤·저장 횟수를 바꾸지 않도록 방어한다.
- 공개 생성자·콜백·API·데이터 모델과 저장 실행 시점은 변경하지 않는다. 사진 비율/고정 잘림, 결과 상단 80px,
  미리보기와 카테고리 배치·분류 정책·하단 버튼·`_SaveHomeIndicator`는 후속 범위다.
  [계획의 UI-06과 디자인 확인 목록](figma-ui-alignment-plan.md)을 부분 적용 기준으로 갱신했다.
- **제품 수정 전** 실제 저장 다이얼로그에 고정 메모리 콜백·사진 선택 대역을 연결한 프리뷰를 준비했다.
  `before-gate.json`에서 제품 diff가 비어 있고 기준 SHA가 `b905769c84df669eabd97b24b50319e5e93615b0`임을 확인했다.
  링크·사진 × 배율 1/2 × 두 플랫폼의 OS 원본 **8장**을 새로 촬영했다. 과거 화면을 재사용하지 않았다.
  프리뷰 소스 SHA256 `3d0181ef1b596b171a356939039f4d444d2e6bfd7b1a10fef3de4ad5d86492c9`를 변경 전·후 동일하게 유지했다.
- 새 집중 테스트의 수정 전 결과는 **4 passed / 7 failed**다. 사진 제목, 제출 중 초안/탭 변경에 따른 결과 오표시,
  늦은 사진 선택 응답, 성공 뒤 이전 제출 콜백을 통한 중복 저장을 재현했다.
  수정 후 집중 **11 passed**, 관련 인증·원본 이미지·자동 분류·키보드·수동 입력 보존 6개 파일 묶음은 **132 passed**다.
  전체 `flutter test --no-pub --reporter expanded` **703 passed**(Flutter 3분 56초, wall 242.26초),
  `flutter analyze --no-pub` **문제 없음**(20.5초), 변경 Dart 3개 형식 검사 **0 changed**를 확인했다.
  이전 692개 통과를 이번 결과로 사용하지 않았다.

| 실제 실행 환경 | 창·OS 여백 | 수정 후 동작 결과 |
| --- | --- | --- |
| iPhone 16 / iOS 18.6 Simulator | 393×852 논리 px, DPR 3, 상단 59px·하단 viewPadding 34px | 링크/사진·배율 1/2, 요청 중 교차 탭/초안 변경, 성공 탭 고정, 중복 방지·실패 재시도·닫기/늦은 완료 확인. 결과 배율 2 드래그 offset 124px, 실제 키보드 표시 시 inset 336px. |
| Android 13 / API 33 Emulator (`Clipback_Share_API_33`) | 392.7×783.3 논리 px, DPR 2.75, 상단 24px·하단 viewPadding 0px, 제스처 탐색 값 2 | 같은 동작 확인. 결과 배율 2 드래그 offset 약 161.73px. OS 원본에서 키보드 표시·이후 해제를 확인했으나 프리뷰의 MediaQuery inset은 0px로 기록돼 양수 inset 측정 성공으로 보고하지 않는다. |

- 실제 위젯과 Flutter 합성 포인터·컨트롤러 입력, 메모리 저장 콜백/파일 선택기를 사용했다.
  양 플랫폼 AFTER 보고서는 각각 **18개 기록, `checksCompleted: true`, `behaviorPassed: true`**다.
  배율 2에서 기존 고정 미리보기 텍스트 열의 넘침(iOS 46px·Android 47px)과 사진 선택 전 안내 열의 넘침(2px·4px)이
  변경 전·후 동일하게 남아 **`layoutPassed: false`, 전체 `passed: false`**로 보존했다.
  일반 배율에서는 프레임워크 오류가 없으며 확대 전용 배치 디자인을 임의로 만들거나 카드 높이를 수정하지 않았다.
  정상 링크의 카테고리 안내/고정 닫기 버튼 겹침과 저장 화면의 앱/OS 인디케이터 중복도 이번 범위 밖이다.
- Android 최초 실행에서 호스트 창 렌더링 오류가 나 검증용 Emulator를 창 없이 다시 실행했다.
  앱/AVD 데이터를 지우거나 OS 탐색 설정을 바꾸지 않았다. 최종 OS 캡처·동작 검증은 재실행한 동일 AVD에서 수행했다.
  최종 빌드 생성은 iOS Xcode 337.7초·Android Gradle 302.6초이며 실제 API/인증 호출을 포함하지 않는다.

증거 루트: `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-wording`.

- [변경 전 → 변경 후 → Figma 비교 문서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-wording/comparison-document.html)는
  플랫폼·입력 종류·글자 배율별 **8개 비교**와 원본/영상 링크를 제공한다. 같은 기종·논리 크기·DPR·고정 데이터·배율·스크롤 0·OS 여백을 대조했다.
  OS 원본 16장과 Figma 원본 2개의 해시를 보존했다. 비교 PNG는 원본 전체를 동일 표시 폭으로만 줄였으며 잘라내거나 위치/OS 영역을 보정하지 않았다.
  Figma 375×812와 실제 기기/안전 영역 차이, D09의 사진 띠 대신 유지한 파일명 필드와 부분 적용 범위를 표시한다.
  확대 비교는 기본 원본과 사용자 확정 기준을 사용하고 별도 디자인 이미지를 만들지 않았다.
- 동작 영상: [iOS](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-wording/ios/after/interaction.mp4),
  [Android](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-wording/android/after/interaction.mp4).
  iOS 원본은 HEVC 1178×2556/140.335초(PNG 1179×2556), Android 원본은 H.264 1080×2220/178.630초다.
  변경 전 원본 영상·플랫폼별 키보드/스크롤 PNG·보고서도 보존한다.
- 두 AFTER 영상의 전체 스트림을 디코딩해 종료 코드 0·오류 로그 0바이트를 확인했다.
  문서 3개의 로컬 Markdown 링크 **147개 모두 존재**, 최종 diff·공백·생성 파일/민감 정보 제외를 확인했다.
  검증에 사용한 Simulator·Emulator와 이번 빌드 프로세스를 종료하고 AVD·앱 데이터는 보존했다.
  읽기 전용 비교 서버 `127.0.0.1:8769`와 기존 비교 서버는 유지한다.
- 실제 OAuth·운영 서버·AI/OCR·실기기·원격 CI·실제 서버 저장 완료는 검증하지 않았다.
  화면 증거·빌드 생성물·`AGENTS.md`는 Git에서 제외하고, 커밋 제목은 `fix: 사진 저장 결과의 링크 전용 문구 수정`이다.
  푸시·PR은 수행하지 않는다.

### 2026-10-15 — 저장 화면의 확대 글자 넘침 수정

- 브랜치 `feature/figma-ui-alignment`, 변경 전 기준 `a14111f`.
  사용자 확정 기준은 **글자를 축소하지 않고 필요한 만큼 높이를 늘린다**이다.
  사진 선택 전 안내의 기본 89px·저장 결과 미리보기의 기본 116px을 최소 높이로 바꾸고,
  내부 텍스트 열은 자연 높이를 사용한다. 별도 배율별 높이 계산이나 새 세로 여백은 추가하지 않는다.
  기존 아이콘 40×40px·썸네일 164×100px·카드 여백 8px·제목 최대 두 줄·출처/안내 본문 한 줄 말줄임을 유지한다.
  기본 배율의 배치와 확대 시 썸네일/텍스트의 세로 중앙 정렬을 확인했다.
- 공개 생성자·콜백·API·데이터 모델과 저장 시점·제출 입력 고정·완료 탭 정책은 변경하지 않았다.
  사진 비율과 샘플용 잘림, 결과 상단 80px, 카테고리, 고정 하단 버튼/인디케이터는 기존 보류 범위다.
  확대 전용 Figma를 새로 만들지 않고 사용자 확정 기준을 [계획](figma-ui-alignment-plan.md)에 기록했다.
- 최신 파일 `b2lmAo9VtbL6Qi0mzX5IMu > WireFrame & UI > 261008`의 D06 `912:16524`,
  D05 `912:16639`, D09 `912:16602` 원본·컨텍스트를 이번 작업에서 확보해 **17:56:18 KST / 08:56:18 UTC**에 기록했다.
  제품 수정 직전 재조회는 **18:07:32 KST / 09:07:32 UTC**이며 D05만 성공했다.
  D06·D09는 Figma MCP Starter 호출 한도에 걸려 이번 작업 초기에 확보한 원본을 사용했다.
  각 컨텍스트의 실제 확보 시각·재조회 제한·파일 기록 시각을 구분했으며 이전 작업 이미지를 재사용하거나 대체 디자인을 만들지 않았다.
- **제품 수정 전** 프리뷰에 사진 선택 전 안내·배율 1.5·세 영역의 기하 측정을 추가했다.
  `before-gate.json`에서 기준 SHA·제품 diff 없음과 **두 플랫폼 × 세 상태 × 세 배율 = 새 OS 원본 18장**을 확인했다.
  전후 프리뷰 SHA256은 `2e45d3ca0d562b52bf6f9accf498b70034fd09f73a596c2c608c5568a61e3880`으로 같다.
  이전 문구·제출 입력·완료 탭 정책은 BEFORE/AFTER 양쪽에서 검사하며 단계 차이는 새 높이·경계 기준뿐이다.
- 새 회귀 테스트 **38개**는 iOS/Android 테마 × 폭 320/375px × 배율 1/1.5/2의 세 위젯 검사 36개와
  실제 저장 창 진입·사진 선택·저장·완료 탭 고정·스크롤·닫기 2개다.
  수정 전 **20 passed / 18 failed**로 긴 제목의 링크/사진 카드 넘침을 재현했다.
  위젯 테스트는 대체 폰트/줄 높이가 달라 사진 안내가 89px에 들어갔으며, 기기의 안내 넘침 재현과 구분했다.
  실제 기기 BEFORE에서는 안내 iOS 2px·Android 4px, 카드 텍스트 열 46px·47px 넘침을 확인했다.
- 수정 후 집중 **38 passed**(5초), 관련 7개 파일 **170 passed**(32초),
  전체 `flutter test --no-pub --reporter expanded` **741 passed**(1분 20초),
  `flutter analyze --no-pub` **문제 없음**(12.2초), 변경 Dart 3개 형식 검사 **0 changed**다.
  이전 703개 통과를 이번 결과로 사용하지 않았다. 새 검사에서는 실제 RenderParagraph 배율·글꼴 크기,
  경계·말줄임·이미지 크기·중앙 정렬과 기본 높이를 확인했다.

| 실제 실행 환경 | 기본/배율 1.5 → 배율 2 높이 | 동작·기기 결과 |
| --- | --- | --- |
| iPhone 16 / iOS 18.6 Simulator, 논리 393×852·DPR 3·상단 59px/하단 34px | 안내 89/89 → 91px, 링크·사진 카드 116/116 → 162px | 32개 기록, 프레임워크 오류 0건. 확대 본문 스크롤 170px, 키보드 inset 336→0px. |
| Android 13/API 33 Emulator `Clipback_Share_API_33`, 논리 392.7×783.3·DPR 2.75·상단 24px/하단 0px·제스처 모드 2 | 안내 89/89 → 93px, 링크·사진 카드 116/116 → 163px | 32개 기록, 프레임워크 오류 0건. 확대 본문 스크롤 198px, 키보드 inset 약 274.91→0px. |

- 두 AFTER 보고서는 **`checksCompleted`·`behaviorPassed`·`layoutPassed`·전체 `passed` 모두 `true`**다.
  BEFORE의 동작 검사는 통과했지만 기존 넘침으로 레이아웃/전체 판정은 `false`였음을 그대로 보존한다.
  사진 선택/재선택·저장·교차 탭과 초안 변경·완료 탭 고정·중복 방지·실패 후 재시도·닫힌 화면의 늦은 응답,
  확대 본문 스크롤·키보드 표시와 해제를 실제 위젯과 Flutter 합성 포인터/컨트롤러 입력으로 검사했다.
  Android는 이번 키보드 대기 후 실제 양수 inset과 OS 원본 표시를 확인했다. 과거 0px 기록을 수정해 덮지 않는다.
- 이 결과는 수정한 두 영역과 해당 대역 동작의 성공이다. 기존 고정 하단 버튼에 의한 안내 가림,
  앱/OS 인디케이터 중복, 사진의 확대/잘림을 포함한 저장 화면 전체 디자인 완료를 의미하지 않는다.
  실제 OAuth·운영 서버·AI/OCR·실기기·원격 CI·실제 서버 저장 완료는 검증하지 않았다.

증거 루트: `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-scaled-layout`.

- [변경 전 → 변경 후 → Figma 비교 18건](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-scaled-layout/comparison-document.html)은
  원본 OS 화면 전체를 동일 표시 폭으로만 줄여 제공한다. 기종·창·DPR·데이터·배율·스크롤 0·OS 여백을 맞췄고,
  글꼴 크기·실제 배율·줄 수·이미지 크기 불변을 별도 대조했다. 원본의 OS 영역을 자르거나 위치를 보정하지 않았다.
  Figma 375×812와 실제 창/안전 영역, 기본 원본을 사용하는 확대 비교와 남은 하단/사진 배치 차이를 명시한다.
- AFTER 동작 영상: [iOS](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-scaled-layout/ios/after/interaction.mp4),
  [Android](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-scaled-layout/android/after/interaction.mp4).
  각각 H.264 1178×2556/83.781667초와 1080×2220/122.177111초다. iOS OS PNG는 원본 1179×2556으로 유지했다.
  BEFORE 영상·Flutter 캡처·키보드 표시/해제 원본·전후 보고서와 검사 로그도 보존한다.
- 두 AFTER 영상을 끝까지 디코딩해 종료 코드 0·오류 로그 0바이트를 확인했다.
  18쌍의 원본 조건·글자 배율/크기·줄 수·썸네일 크기와 일반 배율 6개 영역의 픽셀 동일을 확인했다.
  문서 3개의 로컬 Markdown 링크 **159개 모두 존재**하며 최종 diff·공백·민감 정보/생성 파일 제외를 확인했다.
  이번에 실행한 Simulator·Emulator는 종료하고 앱/AVD 데이터는 보존했다.
  읽기 전용 비교 서버 `127.0.0.1:8770`과 이전 비교 서버는 유지한다.
- 제품 1개·회귀 테스트 1개·프리뷰 1개·문서 3개를 한 커밋으로 저장하며 제목은
  `fix: 글자 확대 시 저장 화면 넘침 수정`이다. 화면 증거·빌드 생성물·`AGENTS.md`는 제외하고 푸시·PR은 수행하지 않는다.

### 2026-10-15 — 저장 화면 하단 안전 영역과 버튼 겹침 정리

- 기준 커밋은 `5d12e9d`이며 사용자가 버튼 아래 **32px + 실제 OS 여백**, 키보드 표시 중에는 **키보드 위 32px**을 확정했다.
  공통 하단 탭의 키보드 미합산 정책과 별개인 전체 화면 저장 창의 기준이다.
- 본문 스크롤과 하단 버튼·토스트를 세로로 분리하고 본문 하단 24px을 유지한다. 버튼은 높이 56px·좌우 16px,
  오류 토스트는 좌우 40px·버튼 위 16px을 유지하며 표시 중 필요한 높이를 확보한다.
  하단 회피량은 `max(viewInsets.bottom, viewPadding.bottom)`을 한 번 적용하고 `_SaveHomeIndicator`를 제거한다.
  글자 축소·사진 비율/잘림·결과 상단 80px·카테고리 편집·공개 콜백/API/모델·저장 입력/완료 탭 정책은 변경하지 않는다.
- 이번 구현 준비 중 18:53:53 KST(09:53:53 UTC)에 D01 `912:16502`·D06 `912:16524`·D07 `912:16551`·D05 `912:16639`·D09 `912:16602`를
  재조회했으나 모두 Figma Starter 호출 한도로 실패했다. D05 원본은 이전 작업의 18:07:32 KST, D06/D09는 17:56:18 KST 원본을
  조회 기록과 함께 사용하며 이번에 새로 조회한 것으로 표시하지 않는다. D01/D07 원본은 없으므로 비교 누락을 기록하고 대체 이미지를 만들지 않는다.
- 제품 수정 전 하단 검사 96개와 기존 안전 영역 2개를 실행해 **1개 통과·97개 실패**로 재현했다.
  본문 viewport가 버튼과 32px 겹치며, 키보드 300px에서 버튼 하단이 746px로 고정되어 기대 480px을 충족하지 못했다.
  프레임워크 오류가 없더라도 겹침을 놓치지 않도록 본문·버튼·토스트 경계와 실제 inset을 검사한다.
- 촬영용 프리뷰를 제품 수정 전에 5개 상태 × 배율 1/1.5/2로 확장하고 동결했다.
  SHA256은 `4b0ab767520f98b570a5741b1ca1f6cb5cbc4eaf6257005857765f9ebccc7cd3`이며 변경 전·후 같은 파일을 사용한다.
  큰 선택 사진은 최대 스크롤의 사진 하단 노출을 검사하고, 마지막 안내 텍스트는 전체 경계를 검사한다.
  BEFORE의 OS 키보드에 가린 버튼을 합성 탭으로 누르는 것은 실제 접근 가능 증거로 사용하지 않는다.
- 수정 후 집중 **98개 통과**(8초), 관련 회귀 **266개 통과**(20초), 전체 `flutter test --no-pub` **837개 통과**(1분 16초)다.
  `flutter analyze --no-pub`는 **문제 없음**(5.1초)이며 제품·테스트 포맷과 공백 검사도 통과했다.
  이전 작업의 741개 테스트나 기기 증거를 이번 성공으로 사용하지 않는다.
- 제품 변경 전에 OS 포함 원본 **90개**를 새로 확보하고 `before-gate.json`에 기준 커밋·제품/프리뷰 해시와 원본 해시를 기록했다.
  세 설정의 BEFORE 보고서는 각각 87개 기록·프레임워크 오류 0건·기존 동작 통과였지만 본문/버튼 겹침과 가짜 선 때문에
  `layoutPassed`·전체 `passed`는 `false`였다. 오류 토스트 한 건은 촬영 지연으로 사라져 기존 자료를 `.attempts`에 보존하고 재촬영했다.
  촬영 전·후 토스트 존재를 확인했고 전체 87개 동작 보고서를 덮지 않도록 재촬영 보고서를 별도로 남겼다.

| 기기·실제 창/여백 | 이번 AFTER 결과 |
| --- | --- |
| iPhone 16 / iOS 18.6, 393×852 논리 px·DPR 3·상단 59px/하단 34px | 84개 기록·오류 0건·네 완료 플래그 모두 `true`. 키보드 336→0px, 버튼 아래 간격은 일반 66px·키보드 표시 368px. 저장·실패/재시도·완료 탭·스크롤·닫기 성공. |
| Android 13/API 33 제스처, 392.7×783.3·DPR 2.75·상단 24px/하단 0px | 86개 기록·오류 0건·네 완료 플래그 모두 `true`. 키보드 약 274.909px. 실제 OS 입력으로 키보드 위 저장 버튼 중심과 닫기 버튼 하단을 눌러 저장 1회·닫기 성공. |
| 같은 Android 3버튼, 392.7×759.3·DPR 2.75·상단 24px/하단 0px | 84개 기록·오류 0건·네 완료 플래그 모두 `true`. 키보드 약 250.909px. 같은 실제 OS 탭 검사 성공. |

- Android의 3버튼 탐색은 OS 탐색 영역 때문에 Flutter 창 자체가 제스처보다 24px 짧다. 앱에 전달된 하단 여백은 둘 다 0px이므로
  OS 영역을 다시 더하지 않았다. 원래 제스처 탐색 값 `2`와 관련 오버레이 전체를 복원해 원본과 일치함을 확인했다.
  임시 adb 포워딩을 제거하고 에뮬레이터를 종료했으며 앱/AVD 데이터는 보존했다.
- 동작은 실제 저장 위젯·고정 콜백/파일 선택 대역과 Flutter 합성 입력을 사용했다. Android의 별도 `native-taps`는 실제 OS의
  `adb input tap`을 사용하지만 저장 응답은 같은 대역이다. 실제 서버·인증·AI/OCR·실기기·원격 CI 검증으로 보고하지 않는다.
- 기존 범위 밖 문제: 확대 글자에서 링크 입력의 ‘붙여넣기’ 문구가 기존 고정 버튼 안에서 줄바꿈·잘리는 현상을 변경 전 원본에서 확인했다.
  D01 원본·확대용 버튼 배치를 확보하지 못했으므로 디자인 확인 목록에 남기고 이번 하단 수정과 분리한다.
  Android 빌드의 기존 Kotlin 2.2.10 지원 종료 예정·Java native-access 경고는 수정 전후 동일하며 빌드는 모두 성공했다.
- [기본 화면 45쌍과 추가 상태 45쌍 비교](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/comparison-document.html)를 제공한다.
  원본이 있는 D06/D05/D09의 27건은 변경 전 → 변경 후 → Figma 3열이며 D01/D07의 18건은 Figma 미확보 사유를 표시한다.
  확대·키보드 전용 디자인은 만들지 않는다. 기본 45쌍은 같은 기종·창·데이터·배율·스크롤 0이며,
  끝까지 스크롤한 추가 비교는 본문 높이가 달라 숫자 offset은 달라도 같은 마지막 위치를 사용했음을 표시한다.
  원본 OS 화면 전체를 종횡비 그대로 같은 표시 폭으로만 보여주며 OS 영역을 자르거나 보정하지 않았다.
- 본문·안내·미리보기·마지막 항목의 **225개 노드**에서 크기·글자 크기/배율·최대 줄 수·말줄임 변경이 없음을 확인했다.
  실제 제출 URL·사진 파일명/바이트·선택 탭·콜백 수와 고정 프리뷰 해시도 보존했다.
  Android 확대 오류 촬영의 지연 재시도 2건은 `.attempts`에 별도 보존하고 최종 원본에서는 촬영 전·후 토스트 존재를 확인했다.
- AFTER 키보드·오류·스크롤 영상:
  [iOS](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/ios/after/layout-keyboard.mp4),
  [Android 제스처](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/android-gesture/after/layout-keyboard.mp4),
  [Android 3버튼](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/android-threebutton/after/layout-keyboard.mp4).
  각 설정의 `interaction.mp4`와 BEFORE 영상도 비교 문서에서 볼 수 있다.
  실제 Android OS 탭의 [제스처 보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/android-gesture/after/native-taps/report.json)·
  [3버튼 보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/android-threebutton/after/native-taps/report.json)는 저장 1회·완료 탭 고정·닫기를 확인한다.
- [최종 비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/comparison-qa.json)에서 기본/추가 각 45쌍의 조건 불일치 0건·토스트 36개 상태 누락 0건과 BEFORE 90개 원본 해시 불변을 확인했다.
  [영상 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/media-verification.json)는 이번 촬영 영상 14개 모두 전체 디코딩 종료 코드 0·오류 로그 0바이트다.
  브라우저에서 플랫폼/배율 전환·이미지 3개 로드·Figma 누락 시 이미지 2개와 사유 표시·콘솔 오류 0건을 확인했다.
  모든 Simulator·Emulator를 종료하고 데이터는 보존했다.
  읽기 전용 비교 서버 `127.0.0.1:8771`과 기존 비교 서버는 유지한다.
  최종 diff·문서 링크·공백·민감 정보와 생성 파일 제외 여부를 확인한 뒤 `fix: 저장 화면 하단 안전 영역과 버튼 겹침 정리` 한 커밋으로 저장한다.
  화면 증거·빌드 생성물·`AGENTS.md`는 커밋에 포함하지 않고 푸시·PR은 하지 않는다.


### 2026-10-15 — 붙여넣기 입력행의 확대 글자 높이 (해당 범위 적용·검증 완료)

- 기준 커밋은 `b0d0c71`이다. 사용자는 글자를 축소하지 않고 필요한 만큼 높이를 늘리고, URL 입력박스도 붙여넣기 버튼과 같은 높이로 확장하는 기준을 확정했다.
  기본·최소 44px, 붙여넣기 폭 64px·최대 두 줄·기존 14px/Medium·자간 −0.35px,
  URL 한 줄·기존 글자 크기·지우기 아이콘 18px·간격 8px과 세로 중앙 정렬을 유지한다.
  `IntrinsicHeight`와 공통 최소 44px·suffix 중앙 배치를 사용하고 지우기 아이콘의 기존 실효 탭 영역 48×44px을 보존한다. 붙여넣기 위아래 각 1px의 경계 여유를 둔다. 기본 44px은 유지하며 확대 자연 높이에 총 2px의 여유를 확보한다.
  배율별 높이 상수나 수동 글자 높이 계산·글자 축소·글꼴 줄 높이 재정의는 추가하지 않는다.
- 사진 비율/잘림·카테고리 편집·저장 화면 전체 맞춤은 후속이다. 기존 하단 회피량·저장/닫기 버튼·제출 입력·성공 탭 고정·재시도,
  공개 생성자·콜백·API·모델은 유지한다. Figma D01 `912:16502` 컨텍스트는 **20:21:07 KST / 11:21:07 UTC**, 원본 스크린샷은 같은 분에 재조회했지만 둘 다 Starter 호출 한도로 실패했다. 기존 D01 원본도 없어 Figma 비교 칸은 누락 사유를 표시한다.
- 제품 수정 전 비교 프리뷰를 확장하고 동결했다. SHA256은 `93390e39a9ffb71613cbc9a3c3df1dc2c33eebd7638af925f3d7390a935af4de`이다.
  `/paste-scene?scale=1|1.5|2&keyboard=0|1`은 여섯 장면에서 모바일 앱 `Clipboard.setData`와 실제 붙여넣기 버튼을 사용한다.
  Mac 클립보드 API는 사용하지 않는다. 같은 고정 URL·커서 끝·본문 스크롤 0을 변경 전/후에 유지한다.
  `/paste-run`은 붙여넣기·직접 입력·지우기·유효/무효 검증·키보드·스크롤·실패/재시도·완료 탭 고정·닫기를 검사하고 기존 `/run`은 유지한다.
- 실제 `RenderParagraph`의 전체 문구·줄 경계·폰트/배율·줄 수·버튼 내부 포함 여부와 URL/붙여넣기의 공통 높이·EditableText/지우기 아이콘 중앙을 기록한다.
  실제 저장 창 위젯 검사 22개는 FontLoader에 Pretendard를 로드했지만 버튼의 상속 스타일 family가 null이어서 테스트 기본 글꼴을 사용했다. 이 검사를 실제 Pretendard 렌더링 증거로 쓰지 않는다.
  추가 13개는 모두 Pretendard family를 명시한 분리 모델이다. 12개는 제품 버튼 스타일/자식의 family만 바꾼 폭/배율/플랫폼 조합이며 1개는 상속 행간 1.18·여백 없음·기존 고정 44px을 대조한다. 전체 저장 창·네이티브 상속 글꼴·Pretendard 분리 모델의 검증 범위를 구분한다. 네이티브 프리뷰는 `fontFamily: null`을 그대로 기록하며 제품 글꼴 설정을 바꾸지 않는다.
  최초 네이티브 시도의 글꼴 family 강제 판정 오탐을 별도로 보존하고 이 판정만 교정한 동결 소스로 모든 구성의 변경 전 화면을 재촬영했다. 기존 14px/Medium·자간·실제 배율과 줄 경계는 계속 검증한다.
  BEFORE는 새 정책 위반을 남기고 기존 동작을 계속 확인하며 AFTER는 엄격 판정해 `layoutPassed`·전체 `passed`에 합산한다.
- 제품 수정 전 `before-gate.json`으로 기준 제품·동결 fixture SHA와 변경 전 OS 원본 18개 확보를 확인했다. BEFORE 보고서는 iOS 24개·Android 제스처 30개(6개 재촬영 포함)·3버튼 24개 기록이며 모두 프레임워크 오류 0건·동작 통과·레이아웃/전체 판정 `false`다.
- [집중 회귀 테스트](../frontend/test/save_paste_layout_test.dart) **35개**·[관련 10개 파일 330개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/tests/related-green-final.log)(14초)·[전체 Flutter 테스트 872개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/tests/full-test.log)(50초)가 통과했다. [분석](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/tests/analyze.log)은 **문제 없음**(3.6초)이며 Dart 세 파일 포맷 검사는 **0개 변경**으로 통과했다. 중간 네이티브 AFTER는 공통 높이 60px에서 실제 줄 경계가 위로 약 0.408px 벗어나 실패했다.
  줄 높이 동작을 바꾸는 시도는 모두 제거하고 위아래 각 1px의 여유를 적용했다. Android 배율 1.5 단독 재검사는 공통 62px·모든 줄 경계 포함으로 통과했으며 수동 글자 측정·허용 오차 완화는 하지 않았다.
  중간 네이티브 pixel 대조에서는 지우기 탭 영역을 34px로 줄여 아이콘이 7px 이동하고 URL viewport가 14px 넓어진 문제를 발견했다. 기존 실효 48×44px으로 복원해 기본 가로 배치를 보존한다.
  이전 Android 3버튼 AFTER는 레이아웃 플래그가 통과했어도 가로 보존을 충족하지 못해 `.attempts/after-clear-hit-width`에 보존하고 모든 구성의 AFTER를 새로 촬영했다.
  중간 반복·단독 재검사나 이전 `b0d0c71`의 테스트·기기 성공은 최종 결과로 사용하지 않는다. 실제 서버·인증·운영 저장·실기기·원격 CI와 구분한다.
- 지우기 영역 48×44px을 복원한 최종 AFTER는 iOS·Android 제스처·3버튼 각각 **24개 기록·프레임워크 오류 0건**이며 `checksCompleted`·`behaviorPassed`·`layoutPassed`·전체 `passed`가 모두 `true`다.

| 실제 기기·창·여백 | 배율 1/1.5/2의 공통 높이 | 실제 키보드 inset |
| --- | --- | --- |
| iPhone 16 / iOS 18.6, 논리 393×852·DPR 3·상단 59px/하단 34px | 44/52/70px | 336px |
| Android 13/API 33 제스처, 392.7×783.3·DPR 2.75·상단 24px/하단 0px | 44/62/84px | 274.909px |
| 같은 Android 3버튼, 392.7×759.3·DPR 2.75·상단 24px/하단 0px | 44/62/84px | 250.909px |

- 위 높이는 실제 플랫폼 상속 글꼴·배율의 측정값으로 고정 목표값이 아니다.
  [18쌍 최종 비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/comparison-qa.json)는 조건 불일치 0건·BEFORE 해시 불변·fixture/최종 빌드 소스 일치·폰트/초안 변경 0건·입력/지우기 가로 기하 변경 0건·실제 줄 경계 포함을 확인했다.
  기본 배율의 채워진 URL 여섯 상태는 박스 크기/색상·지우기 아이콘 픽셀을 보존했다. 글자 raster/커서 깜박임 차이는 원본 그대로 기록하고 전체 픽셀 동일로 보고하지 않는다. 빈 URL은 위젯 검사·지우기 동작으로 확인했으며 별도 네이티브 빈 상태 픽셀 쌍은 촬영하지 않았다. 네이티브 플랫폼 글꼴 식별자는 미측정이며 Pretendard 실행 증거로 사용하지 않는다.
  [탐색 복원 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/android-navigation-restored.json)의 `matchesOriginal: true`로 원래 모드 2와 여섯 탐색 오버레이 일치를 확인했다. 임시 포워딩 8768을 제거하고 에뮬레이터와 iOS Simulator를 종료했으며 시뮬레이터/AVD 데이터는 보존했다.
- 새 증거 루트는 `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled`이며 기본 비교는 3개 기기/탐색 구성 × 배율 1/1.5/2 × 키보드 유무, 총 18쌍이다.
  [18쌍 비교 문서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/comparison-document.html)·[비교 manifest](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/comparison-manifest.json)·[전후 상태 검증](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/pair-verification.json)을 제공한다.
  각 비교는 변경 전/후 두 OS 원본과 D01 원본 미확보 사유를 표시한다. 누락 18건·완전한 세 원본 비교 0건이며 확대용 대체 디자인은 만들지 않았다.
- AFTER 동작 영상: [iOS](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/ios/after/interaction.mp4), [Android 제스처](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/android-gesture/after/interaction.mp4), [Android 3버튼](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/android-threebutton/after/interaction.mp4).
  [영상 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/media-verification.json)는 BEFORE/AFTER 여섯 개 모두 전체 디코딩 종료 코드 0·오류 로그 0바이트를 확인했다. 이전 작업 영상의 디코딩 결과를 이번 것으로 사용하지 않는다.
- 사진 비율/잘림·카테고리 편집 등 미정 디자인은 계속 보류한다. 이번 완료 범위는 붙여넣기/URL 입력행의 확대 표시와 대역 회귀이며 저장 화면 전체 디자인 맞춤으로 보고하지 않는다.
  화면 증거·빌드 생성물·로컬 `AGENTS.md`는 커밋에서 제외하고 푸시·PR은 수행하지 않는다.


### 2026-10-15 — Figma 붙여넣기 버튼 스타일 (해당 범위 적용·검증 완료)

- 기준 커밋은 `52132f0`이다. 이번 범위는 붙여넣기 버튼의 배경 `#FFFFFF`, 1px 실선 테두리 `#D1D1D1`, 글자 `#767676`, 반경 4px과 명시적 Pretendard 14px/Medium·자간 −0.35px을 최신 D01/D02/D03에 맞추는 작업이다.
  기존 폭 64px·기본/최소 44px·최대 두 줄·가운데 정렬·글자 축소 없는 공통 자연 높이와 URL 한 줄 입력·지우기 48×44px/아이콘 18px·간격 8px·검증 앞 5px을 유지한다.
  실제 문자가 새 테두리 안쪽 경계에 들어오는지 확인하고 배율별 높이 상수·수동 글자 높이 계산을 추가하지 않는다.
  공개 생성자·콜백·서버 API·데이터 모델·저장 시점·제출 입력·성공 탭 고정·재시도·하단 안전 영역은 유지하며 사진 비율/잘림·카테고리 편집·저장 화면 전체 맞춤·추천 API는 후속이다.
- 이번 [Figma 조회 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/figma/reference-manifest.json)은 D01 입력 전 `912:16502`·D02 유효 링크 `912:16682`·D03 무효 링크 `912:16712`의 초기 컨텍스트 **22:05:02 KST / 13:05:02 UTC**, 원본 **22:05:18 KST / 13:05:18 UTC** 확보와 구현 직전 재조회를 구분한다.
  현재 비교 기준은 구현 직전 컨텍스트 **22:33:18 KST / 13:33:18 UTC**·원본 **22:33:41 KST / 13:33:41 UTC**의 세 노드 조회 성공 결과다. 재조회 원본은 375×812px이며 초기 PNG와 바이트 해시가 같고, 초기 원본/컨텍스트는 `figma/initial-1305`에 별도 보존한다.
  이전 확대 작업의 Starter 한도 실패·D01 원본 누락·18건의 비교 제한은 당시 기록으로 그대로 보존한다. 이번 성공을 과거 작업의 원본 확보나 완전한 세 화면 비교 성공으로 소급하지 않는다.
- 제품 수정 전 [고정 프리뷰 manifest](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/fixture-manifest.json)를 만들었다. fixture SHA256은 `618a868d90cdc69308fd56d33a63f9457b32995dcace219c86236e6ff7e294bf`이며 변경 전·후에 같은 소스를 사용한다.
  `/paste-scene?kind=valid&scale=1|1.5|2&keyboard=0|1`의 6개 상태와 `kind=empty|invalid&scale=1&keyboard=0`의 두 기본 상태를 제공한다. `/paste-run`은 기존 붙여넣기·입력·지우기·검증·키보드·실패/재시도·완료 탭·스크롤·닫기를 검사한다.
  모바일 Clipboard와 실제 버튼·Flutter 합성 입력·메모리 저장 대역을 사용하며 Mac 클립보드 API·운영 서버·인증·실기기·원격 CI 검증과 구분한다.
- [수정 전 집중 재현](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/tests/paste-style-red.log)은 **40개 중 17개 통과·23개 실패**(13초)다. 실제 Dialog의 Pretendard 부재 13건, 새 1px 테두리 안쪽 글자 경계 초과 5건, 기존 노란 배경과 흰 배경 기준 차이 5건으로 분류한다.
  컴파일/타입/비동기 등 검사 자체 오류는 없지만 스타일 5건은 첫 배경색 비교에서 멈춰 이후 테두리·글자색·포커스/누름 상태 검사가 실행된 증거로 사용하지 않는다.
  실제 Dialog RenderParagraph의 명시적 Pretendard를 검사하도록 기존 회귀를 보강하고 분리 글꼴 모델 13개는 유지했다. 공개 `onPaste`는 필수 콜백이므로 비활성 모양은 실제 TextButton의 스타일/자식을 복제하고 `onPressed: null`로 만든 직접 모델에서 검사한다.
  [초기 검사/프리뷰 정적 분석](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/tests/fixture-analysis.log)은 2항목·문제 없음(2.4초)이며 전체 앱 분석 완료로 보고하지 않는다.
- 변경 전 원본은 iPhone 16/iOS 18.6·Android 13/API 33 제스처/3버튼에서 각각 8장, 총 24장을 새로 확보하고 [변경 전 게이트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/before-gate.json)에서 제품 원본·동결 fixture·24개 OS 원본 해시를 확인한 뒤 제품을 수정했다. 유효 링크 배율 1/1.5/2 × 키보드 유무 6개와 기본 입력 전/무효 두 상태의 데이터를 고정했다.
  BEFORE는 iOS 30개·Android 제스처 22개·3버튼 30개 기록에서 프레임워크 오류 0건이고 `checksCompleted`·`behaviorPassed`·`layoutPassed: true`, `stylePassed`·전체 `passed: false`다. 기존 기하 통과와 새 스타일 실패를 구분한다.
  제스처 최초 행동 검사는 오류 토스트 부재로 중단됐으나 저장 호출 1회·URL·컨트롤러는 유지됐고 프레임워크 오류도 없었다. 토스트 만료는 추정이며 확정하지 않는다. 최초 실패를 `.attempts`에 보존하고 원본 8장·상태 8개 해시를 유지한 채 fresh 앱 세션에서 행동을 재시도했다. [재시도 출처](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/android-gesture/before/retry-origin.json)는 13:26:21~13:28:56 UTC·154.6초·22개 기록과 `interaction-retry.mp4`를 구분한다.
  같은 조건으로 AFTER를 촬영해 **24쌍**을 변경 전 → 변경 후 → D01/D02/D03 순서로 제공하고 동작 영상을 첨부한다. 확대/키보드는 기본 Figma와 사용자 확정 기준을 구분하며 전체 화면 원본을 구현 에셋이나 대체 디자인으로 사용하지 않는다.
  증거 루트는 `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style`, 브라우저용 주소는 `http://127.0.0.1:8773/comparison-document.html`이다. 프리뷰 재현 명령은 [프론트 README](../frontend/README.md)의 이번 스타일 절에 기록했다.
- 첫 스타일 적용 후 [집중 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/tests/paste-style-first-green.log)는 40개 중 30개 통과·10개 실패로 새 1px 테두리 안쪽 경계 초과를 확인했다. 상하 내용 여유를 1px에서 2px로 늘려 테두리 안의 실제 글자를 보호하고 기본 44px·자연 높이·수동 글자 계산 없음 기준을 유지했다.
  최종 [집중 40개 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/tests/paste-style-green.log)는 모두 통과했다(3초). Dart 세 파일 형식 검사는 변경 0건(0.42초)이다. [최종 소스 manifest](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/final-implementation.json)는 제품 SHA256 `2b792fc4d1447d21f9129e32c27509a1cb213a7199b714f07b10b0c5d16aac91`·동결 fixture·검사 소스를 기록한다.
  [관련 10개 파일 335개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/tests/related-green.log)(17초)·[전체 Flutter 검사 877개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/tests/full-test.log)(49초)가 통과했고 [전체 분석](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/tests/analyze.log)은 문제 없음(3.3초)이다.
  Android AFTER APK(14.2초)와 iOS AFTER Xcode 빌드(28.5초)는 성공했고 제품·fixture·검사 소스 해시를 기록했다. 빌드 성공을 실행 성공으로 대신하지 않는다. 이전 `52132f0`의 전체 872개 테스트나 기기 성공을 이번 결과로 사용하지 않는다.
- 최종 [iOS AFTER](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/ios-final-result.json)·[Android 제스처/3버튼 AFTER](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/android-final-result.json)는 각각 OS 원본 8장·30개 기록·프레임워크 오류 0건이고 `checksCompleted`·`behaviorPassed`·`layoutPassed`·`stylePassed`·전체 `passed`가 모두 `true`다.
  세 구성의 입력행 높이는 배율 1/1.5/2에서 44/54/70px이며 Android의 명시적 Pretendard 적용 전 44/62/84px과 구분한다. 실제 글꼴에 따른 자연 높이로 고정 배율값을 구현한 것이 아니다.
  실제 창은 iOS 393×852·DPR 3·상하 여백 59/34px·IME 336→0px, Android 제스처 392.7×783.3·DPR 2.75·24/0px·IME 274.909→0px, 3버튼 392.7×759.3·DPR 2.75·24/0px·IME 250.909→0px다.
  [Android 탐색 복원](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/android-navigation-restored.json)에서 원래 mode 2·6개 오버레이의 `matchesOriginal: true`를 확인했다. [종료 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/android-final-result.json)은 앱 종료·포워딩 8768 제거·에뮬레이터 종료 코드 0·`emulator-5554` 부재와 AVD 데이터 보존을 기록한다.
  iOS도 앱 종료·Simulator Shutdown과 기기 데이터 보존을 확인했다. 자동 검사·세 구성의 기기 실행·24쌍 최종 비교·동작 영상 QA를 완료했다.
  [영구 증거 복사 검증](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/evidence-copy-verification.json)은 임시 작업 경로의 자료 270개·102,133,667바이트를 위 영구 루트에 모든 파일 해시 일치로 복사했음을 확인한다. 임시 원본·실패 시도와 정식 성공 기록의 출처를 유지한다.
- [24쌍 비교 문서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/comparison-document.html)는 모든 상태에서 변경 전 → 변경 후 → 실제 Figma 원본 3열을 제공한다.
  [최종 비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/comparison-qa.json)·[전후 상태 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/pair-verification.json)는 Figma 누락 0건·조건 불일치 0건·BEFORE 24개 이미지/24개 상태 해시 불변·동결 fixture/최종 빌드 소스 일치·실제 문자 경계의 테두리 안쪽 포함을 확인했다.
  의도한 색상/테두리/글꼴 변경 외 초안·커서·URL/지우기 가로 기하와 기본 44px·공통 자연 높이를 유지했다. 기본 배율 12쌍의 픽셀 대조는 의도한 버튼 외형과 원본 커서/선택 차이를 구분하며 원본을 보정하지 않는다. 확대/키보드 전용 디자인을 만들지 않고 기본 Figma와 사용자 확정 기준을 표시했다.
  실제 Dialog·네이티브 RenderParagraph의 효과적 `fontFamily: Pretendard`를 확인했지만 플랫폼의 실제 글꼴 파일 식별자를 따로 추출한 증거로 확대하지 않는다.
- AFTER 영상: [iOS](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/ios/after/interaction.mp4), [Android 제스처](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/android-gesture/after/interaction.mp4), [Android 3버튼](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/android-threebutton/after/interaction.mp4).
  [영상 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-style/media-verification.json)는 이번 BEFORE/AFTER 6개 영상 모두 전체 디코딩 종료 코드 0·오류 로그 0바이트·`allComplete: true`를 확인했다. 제스처 BEFORE는 성공한 `interaction-retry.mp4`이며 실패 시도 영상은 완료 근거에서 제외했다.
  이번 완료 범위는 붙여넣기 버튼 스타일과 기존 대역 회귀다. 사진 비율/잘림·카테고리 편집·저장 화면 전체 맞춤·추천 API는 후속이며 실제 서버·인증·운영 저장·실기기·원격 CI는 이번에 검증하지 않았다.
  최종 diff·문서 링크·공백을 확인한 뒤 `fix: 피그마 기준으로 붙여넣기 버튼 스타일 맞춤` 한 커밋으로 저장한다. 화면 증거·빌드 생성물·`AGENTS.md`는 제외하며 푸시·PR은 하지 않는다.

### 2026-10-15 — 저장 화면 1배율 글자·공통 상단 (해당 범위 적용·검증 완료)

- 기준은 `a54c387`이며 기존 미커밋 정책 문서의 **1배율 Figma 맞춤 우선** 결정을 보존한다. 이번에는 저장 화면 내부의 제목/닫기·링크/사진 탭·입력/결과의 ‘저장할 링크/사진’·URL/파일명·사진 선택 안내·링크 검증·하단 버튼을 맞춘다.
  저장 전용 스타일에 Pretendard와 확정된 굵기·자간·색상을 명시한다. 상단/입력 제목은 검정 `#000000`, 탭 자간은 −0.4px, CTA는 16px/SemiBold·줄 높이 22px·자간 0px·활성 노랑/비활성 흰 글자 기준이다. 나머지는 새 고정 줄 높이를 만들지 않는 AUTO 기준이다.
  상단 64px·닫기 아이콘/탭 영역 24px·좌우 16px/제목 간격 8px·탭 56px/밑줄 2·1px, 입력행 기본 44px과 자연 높이·붙여넣기 스타일·사진 안내 최소 89px·CTA 56px을 유지한다.
  전역 테마·공개 생성자/콜백/API·저장 시점·제출 입력 고정·완료 탭·키보드/하단 안전 영역은 변경하지 않는다. 기존 시스템 글자 배율과 확대 자동 검사를 유지하고 새 확대 수정·배율별 수동 촬영은 후속으로 둔다. 사진 비율/잘림·결과 미리보기 전체 타이포/배치·카테고리 편집·로딩 전용 디자인도 보류한다.
- 제품 수정 전 실제 Pretendard Regular/Medium/SemiBold를 로딩하고 실제 저장 Dialog를 사용하는 `save_base_typography_test.dart`를 추가했다. iOS/Android × 폭 320/375px × 빈 링크·유효·무효·사진 미선택·사진 선택·링크 결과·사진 결과 7상태, 총 28개 시나리오다.
  [최종 RED 로그](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/tests/base-typography-red.log)는 **0개 통과·28개 실패**(12초·종료 코드 1)다. 상단/입력 제목의 Roboto/색상, 탭 Roboto/상속 자간 0.25px, URL/파일명/사진 안내/검증의 Roboto와 CTA의 글꼴 미지정·자간 −0.4px·줄 높이 미지정/실측 16px·비활성 노란 글자를 역할별로 누적 확인했다.
  기존 기본 높이·간격·글자 경계는 실패하지 않았다. 스타일 판정 이후 실행되는 탭·저장·닫기 회귀는 이 RED 단계의 실행 완료로 주장하지 않는다.
  초기 InputDecorator 힌트의 상속 1.5 줄 높이를 제품 AUTO 지정으로 오판한 시도는 `tests/base-typography-red-initial-hint-probe.log`로 보존했다. 최종 검사는 제품의 `hintStyle.height`만 AUTO로 검사하며 CTA만 22/16을 명시 검증한다.
  [집중 검사 파일 단독 분석](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/tests/base-typography-test-analysis.log)은 문제 없음(11.8초)이고 전체 앱 분석 완료로 보고하지 않는다.
- 프리뷰의 EditableText 계측·탭 테두리 안쪽 중앙 판정·정적 초안 준비를 수정한 중간 시도와 Android 시스템 ANR 팝업이 섞인 캡처는 `tests`와 `android-gesture/before/.attempts`에 보존하고 정식 비교에서 제외했다. 이 준비 과정 동안 기준 제품 SHA256 `2b792fc4d1447d21f9129e32c27509a1cb213a7199b714f07b10b0c5d16aac91`은 유지했다.
  [최종 프리뷰 manifest](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/fixture-manifest.json)는 **2026-10-15 14:43:07 UTC**에 SHA256 `11ee1b11b54ee1133d8d3c80b625d9e216f5289d49603f5520eae55e3c3f5e9e`로 동결했다. 변경 전·후 동일 소스와 고정 데이터·1배율·스크롤 맨 위를 사용한다.
  [변경 전 게이트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/before-gate.json)는 **14:50:50 UTC**에 기준 제품 불변·동결 fixture·양 플랫폼의 새 OS 원본 14장을 확인한 뒤 통과했다. 두 플랫폼의 정식 원본은 직접 시각 확인했다.
  BEFORE는 플랫폼당 정적 7개 기록·프레임워크 오류 0건·`layoutPassed: true`·`stylePassed: false`다. 행동을 실행하지 않아 `checksCompleted`·`behaviorPassed`·전체 `passed`는 `false`이며 행동 실패로 분류하지 않는다.
  `/base-style-scene?kind=empty|valid|invalid|photo-empty|photo-selected|link|photo`는 7개 정적 상태, `/base-style-run`은 1배율 동작을 제공한다. 기존 `/run`·`/paste-run`의 확대 회귀 경로는 유지한다.
  BEFORE는 두 플랫폼의 새 정적 7장씩을 대상으로 하고 행동 완료나 영상 실행을 주장하지 않는다. AFTER는 같은 정적 7장씩과 기본 runner·플랫폼별 동작 영상을 확인한다. 정적 초안은 실제 TextField/`onChanged`로 고정하고 클립보드를 쓰거나 읽지 않으며 AFTER runner에서 모바일 클립보드를 한 번 따로 확인한다. 저장 위젯·Flutter 합성 입력·메모리 저장/사진 선택 대역이며 실제 OAuth·운영 서버·AI/OCR·실기기·원격 CI와 구분한다.
- 기준 Figma는 최신 261008의 D01 `912:16502`·D02 `912:16682`·D03 `912:16712`·D06 `912:16524`·D07 `912:16551`·D05 `912:16639`·D09 `912:16602`이다. [구현 직전 재조회](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/figma/reference-manifest.json)는 **2026-10-15 14:32:21~14:32:23 UTC**에 일곱 노드 모두 Starter MCP 호출 한도 응답을 받았다. Education(student/Full) 계정 선택/연결 상태를 재확인했으며 계획 단계 D01/D06의 조회 성공과 이번 구현 직전 실패를 혼동하지 않는다.
  정확한 보관 컨텍스트/PNG 여섯 개를 fallback으로 사용한다. 실제 보관 조회 시각은 D01/D02/D03 컨텍스트 13:33:18 UTC·PNG 13:33:41 UTC, D05 09:07:32 UTC, D06/D09 08:56:18 UTC다. 앱 BEFORE 원본은 현재 기준 커밋에서 새로 촬영하며 과거 앱 화면은 재사용하지 않는다.
  두 플랫폼 × 7상태의 **14쌍**을 변경 전 → 변경 후 → 해당 원본 순서로 제공한다. D07 원본/컨텍스트는 미확보이므로 사진 선택 상태 두 비교의 Figma 누락을 명시하고 대체 이미지를 만들지 않았다. 최종 비교는 완전한 세 화면 비교 12쌍과 Figma 누락 2쌍으로 구분한다. 과거 작업의 조회 성공·14/18/24쌍 비교 결과는 소급 변경하지 않는다.
  제품 적용 후 첫 집중 검사에서 TextField의 필수 `textBaseline` 단언을 확인했고 입력 스타일에 `TextBaseline.alphabetic`을 명시했다. 첫 실패는 `tests/base-typography-first-textfield-baseline-error.log`에 보존했다. 최종 [집중 28개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/tests/base-typography-green.log)는 모두 통과(3초)했다.
  [기존 관련 회귀 335개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/tests/related-green.log)는 통과(로그 14초·명령 18.06초)했고 [전체 Flutter 905개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/tests/full-test.log)도 통과(로그 47초·명령 50.94초)했다.
  [전체 분석](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/tests/analyze.log)은 문제 없음(로그 3.3초·명령 4.27초), [세 파일 형식 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/tests/format-check.log)는 변경 0건(로그 0.06초·명령 0.34초)이다. [실제 종료 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/automatic-checks.json)은 네 명령 모두 종료 코드 0을 기록했다.
  [최종 구현 manifest](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/final-implementation.json)는 제품 SHA256 `9be52797870f4df84e56c535584b9eff722001b3a765e03c945a7ef8dacc6f6c`·동결 fixture·검사와 빌드 소스를 기록한다. AFTER Android/iOS 빌드는 각각 로그 14.1/22.0초·명령 16.63/34.56초로 성공했다. 빌드 성공을 기기 실행 완료로 대신하지 않는다.
  [iOS AFTER](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/ios-after-result.json)와 [Android 제스처 AFTER](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/android-after-result.json)는 각각 새 정적 OS 원본 7장·28개 기록(캡처 14개·행동 시나리오 14개)·프레임워크 오류 0건이고 `checksCompleted`·`behaviorPassed`·`layoutPassed`·`stylePassed`·전체 `passed`가 모두 `true`다. 양쪽 정적 7개 모두 대상 글자/기하 통과와 OS 팝업 없음을 직접 확인했다.
  iPhone 16/iOS 18.6은 393×852·DPR 3·상하 여백 59/34px·IME 336→0px이고 Android 13/API 33 제스처는 392.7×783.3·DPR 2.75·24/0px·IME 274.909→0px이다. 모바일 Clipboard는 각 플랫폼 1건 검증했다.
  [iOS AFTER 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/ios/after/interaction.mp4)은 15:04:34~15:05:22 UTC·7,452,628바이트, [Android AFTER 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/android-gesture/after/interaction.mp4)은 14:59:16~15:00:47 UTC·4,742,691바이트다. 두 native 세션 모두 종료 코드 0·실행 오류 0건이며 검사/촬영은 2026-10-15~16 KST에 걸쳐 수행했다.
  iOS는 앱 종료·Simulator Shutdown·데이터 보존을 확인했다. [Android 정리 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/android-after-navigation-restored.json)은 원래 mode 2/여섯 탐색 오버레이의 `matchesOriginal: true`, 설정 변경 0건·앱 종료·8768 포워딩 제거·에뮬레이터 종료/AVD 데이터 보존을 확인했다.
  [iOS 원본 시각 확인](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/ios-after-visual-review.json)은 정적 7장·팝업 0건·대상 글자 잘림 없음을 확인했다. 스크롤 0의 링크 결과 카테고리 끝부분은 기존 viewport 밖이며 최대 스크롤 시 마지막 항목 노출은 별도 행동 검사로 확인한다. 이 전체 본문 배치를 이번 완료 범위에 포함하지 않는다.
  [14쌍 최종 비교](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/comparison-document.html)와 [브라우저](http://127.0.0.1:8774/comparison-document.html)를 제공한다. [비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/comparison-qa.json)·[전후 상태 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/pair-verification.json)는 조건 불일치 0건·BEFORE 원본 14장 불변·동결 fixture/최종 빌드 소스 일치·실제 90개 글자 역할의 스타일/최대 줄 수/AUTO/CTA 22px·기존 컨트롤 기하·부모 paint 경계 포함을 확인했다.
  원시 선택 경계가 paragraph 자체를 조금 벗어나는 값은 진단으로 보존했다. 실제 부모의 paint 경계와 말줄임 clip에 따라 잘림을 판정하며 그 자체를 넘침으로 오판하거나 수치/원본을 보정하지 않았다. 네이티브 글꼴 파일 식별자를 별도로 추출한 증거로 확대하지 않는다.
  [영상 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/media-verification.json)는 AFTER 두 영상(iOS 47.100초·Android 89.281878초)의 전체 디코딩 종료 코드 0·오류 로그 0바이트·`allComplete: true`를 확인했다. BEFORE 행동/영상은 실행하지 않았다.
  [브라우저 실행 확인](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography/browser-verification.json)은 실제 14개 조건 선택·원본 이미지 40개 로딩·D07 누락 안내 2건·플랫폼별 영상 `readyState: 4`/오류 0건과 기본 iOS/빈 입력 상태 복귀를 확인했다.
  이번 완료는 저장 화면 1배율 글자·공통 상단과 기존 대역 회귀이며 전체 저장 화면 맞춤은 미완료다. D07 원본 미확보와 사진 비율/잘림·미리보기 전체 배치·카테고리 편집 등 후속 범위를 유지한다. Android 3버튼/확대 배율의 새 수동 촬영은 이번 범위에서 제외했고 기존 확대 자동 회귀는 유지했다. 이전 877개 검사나 기기 성공을 이번 결과로 사용하지 않으며 실제 서버·OAuth·운영 저장·실기기·원격 CI는 미검증이다.
  증거 루트는 `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-base-typography`이고 재현 명령은 [프론트 README](../frontend/README.md)의 이번 절을 따른다.
  최종 diff·문서 링크·공백을 확인한 뒤 같은 `feature/figma-ui-alignment` 브랜치에서 한 커밋으로 저장한다. 화면 증거·빌드 생성물·`AGENTS.md`는 제외하고 푸시·PR은 하지 않는다.

### 2026-10-16 — 저장 결과 미리보기 1배율 글자 (해당 범위 적용·검증 완료)

- 기준은 `b082db8`이며 이번 대상은 최신 261008의 링크 결과 D05 `912:16639`·사진 결과 D09 `912:16602` 안의 ‘미리보기’ 제목·콘텐츠 제목·출처 세 역할이다. 미리보기 제목은 Pretendard 16/SemiBold/−0.4px/검정/AUTO, 콘텐츠 제목은 15/Medium/−0.375px/검정/행간 1.6, 출처는 14/Regular/−0.35px/`#767676`/행간 1.6으로 맞춘다.
  카드 최소 116px·패딩 8px·이미지 164×100px·이미지/글자 간격 16px·제목/출처 간격 8px·세로 중앙 정렬·자연 높이, 제목 최대 두 줄/출처 한 줄 말줄임과 글자 배율을 유지한다. 상단/탭·‘저장할’ 제목·URL/파일명·검증/CTA·키보드/OS 하단 여백·전역 테마·공개 API·저장 시점/제출 입력/완료 탭 정책은 변경하지 않는다.
  사진 비율/잘림·고정 링크 썸네일·카테고리 편집·결과 상단 80px과 전체 저장 화면 맞춤은 후속이다. 새 확대 대응/배율별 수동 촬영은 하지 않고 기존 확대 자동 회귀를 유지한다.
- 기존 `save_base_typography_test.dart`와 실제 Pretendard 세 굵기의 Dialog harness를 확장했다. 기존 iOS/Android × 폭 320/375 × 7상태 28개를 보존하고 결과 8조합에서 세 역할과 카드 기하를 검사한다. 명확한 한 줄 제목과 두 줄/한 줄로 말줄임되는 긴 제목/출처의 결과 8조합을 더해 총 36개다. 행간 1.6은 실효 TextStyle로 확인하고 글자 경계/실측 높이는 별도로 검사한다.
  [최종 RED](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/tests/base-typography-red.log)는 **20개 통과·16개 실패**(로그 4초/명령 7.19초·종료 코드 1)다. 새 결과 역할의 Roboto 상속·제목 색상·출처 행간 1.43을 재현했으며 기존 결과 8개와 긴 문구 결과 8개가 실패했다. 나머지 20개는 통과했고 기하 실패로 분류하지 않는다.
  첫 시도의 중괄호 린트 1건은 수정 후 `tests/initial-lint-attempt`에 보존했다. [준비 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/preparation-checks.json)는 검사/프리뷰 두 파일 분석 문제 없음(로그 1.4초/명령 2.37초)·형식 변경 0건(로그 0.05초/명령 0.37초)을 기록한다. 단독 준비 분석을 전체 앱 분석 완료로 보고하지 않는다.
- [Figma 출처 manifest](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/figma/reference-manifest.json)는 정확한 보관 원본/컨텍스트를 사용한다. 실제 조회 시각은 D05 **2026-10-15 09:07:32 UTC**, D09 **08:56:18 UTC**이며 출처 원본 [D05](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-scaled-layout/figma/D05-implementation.png)·[D09](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-scaled-layout/figma/D09-implementation.png)의 해시를 보존했다.
  이번 보관 자료의 해시/조회 시각 대조는 **16:42:41 UTC**에 수행했으며 새 Figma 조회 성공으로 취급하지 않는다. [이번 구현 직전 재조회](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/figma/implementation-refresh.json)는 **2026-10-15 16:48:38~16:48:39 UTC**에 D05/D09 모두 Starter MCP 호출 한도 응답을 받았다. 계정 진단은 별도로 보존하고 개인 정보는 문서에 싣지 않는다. 승인된 fallback으로 정확한 보관 원본의 기존 조회 시각/해시를 사용하며 이전 앱 화면을 새 BEFORE로 사용하지 않는다.
- [프리뷰 manifest](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/fixture-manifest.json)는 **2026-10-15 16:46:28 UTC**에 제품 SHA256 `9be52797870f4df84e56c535584b9eff722001b3a765e03c945a7ef8dacc6f6c` 불변과 fixture SHA256 `e8111186e355ed8a9147fb277c334d9fb2c4d328835fd6ebc76b4ba28363888c`를 기록했다. 고정 URL/파일명·콘텐츠/사진과 1배율·키보드 없음·스크롤 맨 위 조건을 변경 전·후에 맞춘다.
  기존 `/base-style-scene?kind=link|photo`를 사용하고 `/base-style-run?resultsOnly=1`로 결과의 탭 고정·스크롤·닫기·추가 저장 없음을 확인한다. 기존 전체 runner/확대 경로는 보존한다.
  iPhone 16/iOS 18.6과 Android 13/API 33 제스처의 두 결과, 총 **4쌍**을 새로 촬영해 변경 전 → 변경 후 → 실제 D05/D09 원본 순서로 제공한다. BEFORE는 정적 원본만, AFTER는 동일 정적 원본과 플랫폼별 동작 영상 2개를 확인한다. Android 3버튼/확대 배율의 새 촬영은 제외한다.
  [변경 전 빌드](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/before-build.json)는 Android 로그 22.5초/명령 25.52초·iOS 로그 34.9초/명령 69.3초로 성공했다. 빌드 성공을 기기 실행/화면 비교 완료로 대신하지 않는다.
  [iOS BEFORE](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/ios-before-result.json)·[Android BEFORE](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/android-before-driver-result.json)는 새 정적 원본 각 2장·총 4장의 직접 시각 확인에서 팝업 0건·프레임워크 오류 0건·`layoutPassed: true`·`stylePassed: false`를 기록했다. 행동/영상은 실행하지 않았으며 두 앱·가상 기기의 정리와 데이터 보존을 확인했다.
  [변경 전 게이트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/before-gate.json)는 **16:52:33 UTC**에 새 원본 4장·동결 fixture·제품 해시 불변을 확인한 뒤 통과했고 [제품 수정 시작](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/product-edit-start.json)은 **16:53:01 UTC**에 기록했다. 세 역할의 스타일만 적용한 후 [집중 36개 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/tests/base-typography-green.log)는 모두 통과(로그 4초/명령 6.79초)했다. 제품 한 파일의 형식 검사는 변경 0건(로그 0.03초/명령 0.42초)이다.
  [기존 관련 회귀 335개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/tests/related-green.log)는 통과(로그 19초/명령 22.32초)했고 [전체 Flutter 913개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/tests/full-test.log)도 통과(로그 55초/명령 58.98초)했다.
  [전체 분석](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/tests/analyze.log)은 문제 없음(로그 3.6초/명령 4.61초)이고 [세 파일 형식 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/tests/format-check.log)는 변경 0건(로그 0.07초/명령 0.41초)이다. [실제 자동 명령 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/automatic-checks.json)은 제품 형식 검사·집중·관련·전체·분석·최종 형식 검사 모두 종료 코드 0을 확인했다.
  [최종 AFTER 소스/빌드](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/final-implementation.json)는 제품 SHA256 `9022a734d31d21980060498a312f286fa788649de37b42ba67061904372ffbf3`와 동일한 동결 fixture/검사 소스를 기록했다. AFTER Android/iOS 빌드는 로그 15.4/23.5초·명령 17.93/37.06초로 모두 종료 코드 0이다. 빌드 성공을 기기 실행 완료로 대신하지 않는다.
  [iOS AFTER](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/ios-after-result.json)·[Android AFTER](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/android-after-driver-result.json)는 각각 새 OS 원본 2장·10개 보고서 기록(캡처 4개·행동 6개)·프레임워크 오류 0건이다. `stylePassed`·`layoutPassed`·`behaviorPassed`·`checksCompleted`·전체 `passed`가 모두 `true`다.
  실제 iPhone 16/iOS 18.6은 393×852·DPR3·상하 여백 59/34px, Android 13/API33 제스처는 392.7×783.3·DPR2.75·24/0px이다. 링크 최대 스크롤/마지막 항목 노출은 iOS 22px·Android 약21.727px에서 확인했다. 사진은 최대 스크롤 0px로 스크롤 불필요이며 무조건 실제 드래그 성공으로 기록하지 않는다. 완료 탭 고정·추가 저장 없이 닫기도 확인했다. 결과 두 상태 이외의 키보드/클립보드/확대 배율 새 기기 실행은 포함하지 않는다.
  양쪽 미리보기 제목의 실측 높이는 23→19px이고 카드/이미지 Y는 자연 본문 흐름에 따라 −4px 이동했다. 별도 위치 보정값은 추가하지 않았다. 출처의 실효 행간 1.6과 문단 실측 22px은 구분하며 계산상 22.4px을 고정 높이로 강제하지 않는다.
  [iOS AFTER 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/ios/after/interaction.mp4)은 17:00:29~17:00:41 UTC·2,128,724바이트이고 [Android AFTER 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/android-gesture/after/interaction.mp4)은 16:57:54~16:58:14 UTC·1,208,741바이트다. 두 native 세션은 정상 종료했고 iOS 앱 종료/Simulator Shutdown/데이터 보존을 확인했다.
  [Android 정리 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/android-after-navigation-restored.json)은 원래 mode2/여섯 오버레이 `matchesOriginal: true`·설정 변경0건·앱/에뮬레이터 종료·forward8768 제거·데이터 보존을 확인했다.
  [iOS 최종 시각 확인](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/ios-after-visual-review.json)은 새 원본 2장·팝업 0건·대상 글자 잘림/겹침 없음을 확인했다. [4쌍 최종 비교](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/comparison-document.html)와 [브라우저](http://127.0.0.1:8775/comparison-document.html)는 모두 변경 전 → 변경 후 → 실제 D05/D09 원본 순서다.
  [비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/comparison-qa.json)·[전후 상태 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/pair-verification.json)는 Figma 누락/조건 불일치 0건·BEFORE 원본 4장 불변·최종 빌드 소스/동결 fixture 일치·12개 미리보기 역할의 실효 스타일/행간·부모 안의 문단 경계·기존 카드/이미지 기하 상수 및 공통 스타일 보존을 확인했다. 원시 선택 상자는 글꼴 선택 경계의 진단값이며 실제 글자 잉크/paint나 잘림으로 단정하지 않는다.
  [실측 요약](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/final-evidence-summary.json)은 제목/카드 Y의 자연 이동 −4px과 출처의 실효 행간 1.6/문단 실측 22px을 구분한다. 위치 보정이나 고정 높이 추가 없이 자연 흐름을 유지했다.
  [영상 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/media-verification.json)는 이번 새 AFTER 두 영상(iOS 10.8초·Android 18.048989초)의 전체 디코딩 종료 코드 0·오류 로그 0바이트를 확인했다. 최종 재확인은 같은 작업의 동일 영상 SHA에 해당하는 성공 디코딩 결과를 재사용했으며 이전 작업의 영상은 사용하지 않았다. BEFORE 행동/영상은 실행하지 않았다.
  [브라우저 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography/browser-verification.json)는 네 조건의 실제 선택·원본 이미지 12개 로딩·양 영상 `readyState: 4`/오류 0건·iOS/링크 기본 상태 복귀를 확인했다.
  이번 완료는 저장 결과 미리보기 세 역할의 1배율 글자와 기존 회귀다. 사진 비율/잘림·고정 링크 썸네일·카테고리 편집·결과 상단 80px·저장 화면 전체 맞춤은 미완료다. API·저장 정책은 이번 변경 범위에서 제외하고 기존 연결을 유지했다. 이전 905개 검사나 과거 28개 기기 기록을 이번 913개 검사/새 4쌍 비교의 증거로 사용하지 않는다.
  재현 명령은 [프론트 README](../frontend/README.md)의 이번 절을 따른다. 증거 루트는 `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-typography`이며 메모리 저장/사진 선택 대역·Flutter 합성 입력을 실제 OAuth·운영 서버·실기기·원격 CI와 구분한다.
  최종 diff·문서 링크·공백을 확인한 뒤 같은 `feature/figma-ui-alignment`에서 한 커밋으로 저장한다. 화면 증거·빌드 생성물·`AGENTS.md`는 제외하고 푸시·PR은 하지 않는다.

### 2026-10-16 — 저장 결과 카테고리의 1배율 글자 (해당 범위 적용·검증 완료)

- 기준 커밋은 `108ef0f`이며 최신261008 D05 `912:16639`·D09 `912:16602`의 카테고리 제목·기존 상태 안내·실제 카테고리명 세 역할만 적용한다.
  제목은 Pretendard16/SemiBold/−0.4/검정/AUTO, 안내는14/Medium/−0.35/#767676/AUTO, 이름은16/Medium/자간0/검정/행간22÷16이다.
  기존 저장 전용 스타일을 재사용·확장하고 행55px·좌우16px·폴더28px·아이콘/이름8px·세로 중앙·한 줄 말줄임을 유지한다.
  처리 중/미분류/실제 분류 문구·분기와 ‘분류는 상세 화면에서 변경할 수 있어요.’의 기존 스타일은 유지한다.
  Figma의 자동분류 완료 예제를 고정 표시하지 않으며 카테고리 추가/제거·확정 시점(DEC-03)과 자동분류 정책(DEC-05), 사진 비율/잘림·전체 미리보기 배치·결과 상단80px·API는 제외한다.
- [구현 직전 Figma 재조회](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/figma/implementation-refresh.json)는 **2026-10-16 02:01:15~02:01:18 UTC**에 두 노드 모두 Starter MCP 호출 한도로 실패했다.
  [정확한 보관 원본 출처](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/figma/reference-manifest.json)의 D05 **2026-10-15 09:07:32 UTC**·D09 **08:56:18 UTC**를 승인된 fallback으로 사용한다. 개인 계정 정보는 기록하지 않으며 과거 앱 캡처를 새 BEFORE로 대신하지 않는다.
- 기존 `save_base_typography_test.dart`의 기본28건·긴 미리보기8건을 보존하고 새 카테고리32건을 추가했다. 실제 Pretendard·결과2종·iOS/Android 테마·폭320/375px·1배율에서 짧은/긴 이름, 미분류, YouTube queued/processing과 긴 안내를 검사한다.
  역할별 글꼴/행간·55px행/폴더/패딩/간격/중앙 정렬/말줄임과 실제 이름·상태 안내·기존 상세 변경 안내 보존을 확인한다.
  선택 상자는 진단값으로 분리하며 실제 문단·행·말줄임 clip과 최대 스크롤의 마지막 안내/본문 하단24px으로 잘림을 판정한다.
  `/base-style-scene?kind=link|photo`, `/base-style-run?resultsOnly=1`과 기존 기본/확대 runner를 유지하고 프리뷰의 신규 세 역할을 전체 스타일/레이아웃 판정에 연결했다.
- [준비 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/preparation-checks.json)는 검사/프리뷰 두 파일 분석·형식 검사를 통과했다. 초기 중괄호 린트 두 건과 출처 헬퍼 import 수정 전 기록은 `tests/initial-preparation-attempt`에 남겼다.
  [수정 전 최종 재현](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/red-checks.json)은 **68건 중20건 통과·48건 실패**(로그28초/명령36.41초)로 세 역할의 상속 글꼴/색상·이름 행간 차이를 확인했다. 선택 상자를 paint로 오판한 초기 시도는 `tests/initial-selection-diagnostic-attempt`에 별도 보존하고 실제 문단/행/말줄임 경계 검사는 유지했다.
- [변경 전 게이트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/before-gate.json)는 **02:04:05 UTC**에 `108ef0f` 제품 불변·동결 fixture·새 OS 원본4장을 확인한 뒤 통과했다. [제품 수정 시작](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/product-edit-start.json)은 **02:04:36 UTC**다.
  BEFORE는 iPhone16/iOS18.6·Android13/API33 제스처의 각 플랫폼에서 링크1장·사진1장, 총4장이다. 프레임워크 오류0건·`layoutPassed: true`·`stylePassed: false`이며 행동·영상은 실행하지 않았다.
  변경 전·후는 같은 데이터·1배율·키보드 숨김·스크롤0으로 맞춰 총4쌍을 새로 촬영했다. 새 확대 배율/3버튼 반복 촬영은 제외하고 기존 확대 자동 회귀는 유지한다.
- 첫 수정 후 집중 검사는 60건 통과·8건 실패(명령10.11초)였으며 원인은 넓은375px에서도 처리 중 안내가 무조건 두 줄이라는 검사 오판이었다. 제품 수정 없이 실제 Pretendard의 자연 줄바꿈(320px 두 줄·375px 한 줄)에 맞게 검사만 수정하고 `tests/initial-wrap-expectation-attempt`에 보존했다. 기존 문구·최대 줄 수 제한 없음·부모 경계와 native fixture/BEFORE 원본은 유지했다.
- 최종 [집중68건](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/tests/base-typography-green.log)은 통과(로그6초/명령9.82초), [관련335건](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/tests/related-green.log)도 통과(로그17초/명령20.33초)했다.
  [전체 Flutter945건](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/tests/full-test.log)은 통과(로그59초/명령62.29초)했고 [전체 분석](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/tests/analyze.log)은 문제 없음(로그3.9초/명령5.19초)이다.
  첫 형식 검사 차이는 `tests/initial-format-attempt`에 보존했다. 제품 formatter가 공백 한 건만 정리(로그0.03초/명령0.4초)한 뒤 [세 파일 형식 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/tests/format-check.log)는 변경0건(로그0.07초/명령0.35초)이다. [최종 자동 명령 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/automatic-checks.json)은 모두 종료코드0이며 의미 변경 없는 공백 정리만으로 테스트를 다시 반복하지 않았다.
  [AFTER 소스·빌드](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/final-implementation.json)는 제품·최종 검사·변경 전/후 동일한 fixture와 Android/iOS 바이너리 SHA를 기록했다. Android 빌드는 로그17.2초/명령19.91초·iOS 빌드는 로그30초/명령46.33초로 모두 종료코드0이며 실행 검증과 구분한다.
- [iOS AFTER](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/ios-after-result.json)·[Android AFTER](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/android-after-driver-result.json)는 각각 새 OS 원본2장·기록10건(캡처4건/동작6건)·프레임워크 오류0건이다. `stylePassed`·`layoutPassed`·`behaviorPassed`·`checksCompleted`·전체 `passed`가 모두 `true`다.
  실제 창은 iPhone16/iOS18.6의393×852·DPR3·상하59/34px, Android13/API33 제스처의392.7×783.3·DPR2.75·24/0px이다. 링크의 실제 드래그·최대 스크롤(iOS14px·Android약13.727px)·마지막 안내/본문하단24px·탭 고정·추가 저장 없는 닫기를 확인했다. 사진은 max0px로 드래그 성공으로 기록하지 않는다.
  카테고리 문단 높이는 양쪽 모두 제목23→19·안내21→17·이름24→22px이며 행/기존 안내Y는 자연스럽게−8px 이동했다. 위치 보정값은 추가하지 않았다. 고정 카테고리명은 Pretendard에서 한 줄에 들어가며 더 긴 이름의 실제 말줄임은 단위 검사로 확인했다.
  [iOS 원본 시각 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/ios-after-visual-review.json)와 Android 실행 기록은 팝업/대상 잘림/겹침이 없음을 확인했다. 처리 중/미분류 분기는 자동 검사로 확인했으며 이번 기기의4쌍은 고정된 분류됨 결과다.
- [4쌍 새 비교](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/comparison-document.html)와 [브라우저](http://127.0.0.1:8776/comparison-document.html)는 변경 전→변경 후→Figma 원본 순서다.
  [비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/comparison-qa.json)·[전후 상태 검증](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/pair-verification.json)은 완전한3열4쌍·Figma 누락/조건 불일치0건·BEFORE 원본4장 불변·fixture/최종 빌드 일치·이번 카테고리 역할12개의 스타일/행간·행 안의 문단/말줄임 경계·기존 행/폴더 기하 상수·상단/미리보기 스타일·기존 상세 변경 안내 문구/스타일 보존을 확인했다.
  [실측 요약](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/final-evidence-summary.json)은 AUTO와 이름22px 실측·행Y−8px의 자연 흐름을 구분한다. OS 창/안전 여백 차이를 원본 그대로 설명하고 대체 디자인은 만들지 않았다.
  [iOS AFTER 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/ios/after/interaction.mp4)은02:11:35~02:11:53UTC·2,019,274바이트, [Android AFTER 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/android-gesture/after/interaction.mp4)은02:12:40~02:13:08UTC·952,887바이트다.
  [영상 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/media-verification.json)는 두 새 영상(iOS14.96초/Android약25.87초)의 전체 디코딩 종료코드0·오류로그0바이트를 확인했다. BEFORE 행동/영상과 이전 작업의 영상은 사용하지 않았다.
  [iOS 정리](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/ios-after-driver-result.json)와 [Android 정리](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/android-after-navigation-restored.json)/실행 기록은 앱·Simulator/AVD 종료·데이터 보존, Android 원래mode2/여섯 오버레이 일치·설정 변경0건·포워딩8768 제거·adb 기기목록 비어 있음을 확인했다.
  [브라우저 검증](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography/browser-verification.json)은 실제 네 조건 선택·원본12개 로딩·Figma 누락0건·양 영상 `readyState: 4`/오류 없음·iOS/링크 기본 상태 복귀를 확인했다.
  이전913개 테스트와 이전12개 미리보기 역할 검사를 이번945개/새12개 카테고리 역할의 성공으로 사용하지 않는다. 새 클립보드/키보드·확대/3버튼 기기 동작은 이번 범위가 아니다.
  재현 명령은 [프론트 README](../frontend/README.md)의 이번 카테고리 절을 따른다. 증거 루트는 `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-typography`다.
  고정 사진 선택·메모리 저장 대역·Flutter 합성 입력 검증을 운영 서버·OAuth·실기기·원격 CI와 구분한다. 완료는 세 역할의1배율 글자에 한정하고 저장 화면 전체 맞춤·카테고리 편집은 후속으로 남긴다.
  같은 `feature/figma-ui-alignment`에서 최종 diff·문서 링크·공백을 확인해 한 커밋으로 저장하며 화면 증거·빌드 생성물·`AGENTS.md`는 제외하고 푸시·PR은 하지 않는다.


### 2026-10-17 — Figma Page 1 기준 전환과 후속 작업 정리 (문서만 갱신)

- 기준 커밋은 `1036398`이며 같은 `feature/figma-ui-alignment`에서 계획 문서·프론트 README·이 진행 기록만 갱신한다. 현재 디자인은 파일 `svNWsTFh8Ws1Mpt8XQIcrN`의 **[Page 1(`0:1`)](https://www.figma.com/design/svNWsTFh8Ws1Mpt8XQIcrN/?node-id=0-1) > [261007(`111:3379`)](https://www.figma.com/design/svNWsTFh8Ws1Mpt8XQIcrN/?node-id=111-3379)**로 전환한다.
- 구현 시작 시 **2026-10-16 17:29:14~17:29:17 UTC(2026-10-17 02:29:14~02:29:17 KST)**에 Page 1 메타데이터를 한 번 조회했다. [원본 XML](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/page1-reference-transition-20261017/page1-metadata.xml)과 [조회 시각·노드 목록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/page1-reference-transition-20261017/reference-manifest.json)을 보존했다. 화면 이름과 노드 구조를 확인했으며 URL의 `85:3222`는 이 메타데이터에 없다. 중복 화면명은 노드 ID와 설명으로 구분하고 불명확한 대응은 확인 필요로 남긴다. 이 구조 확인을 전체 본문 스타일이나 기기 화면 재검증으로 보고하지 않는다.
- 저장 화면의 새 대응은 D01 `111:4765`·D02 `111:4945`·D03 유효하지 않은 링크 `111:4975`·D06 `111:4787`·D07 `111:4814`·D05 `111:4902`·D09 `111:4865`다. D03 링크 정보 추출 실패 `142:4657`은 무효 URL과 별도 상태다. 화면별 전체 대응은 [Figma 화면 맞춤 계획](figma-ui-alignment-plan.md)을 따른다.
- 새 D07은 앞선 보관 확인 시각 **2026-10-16 17:22:34 UTC(2026-10-17 02:22:34 KST)**의 [정확한 원본 PNG](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/page1-reference-check-20261017/D07.png)·[컨텍스트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/page1-reference-check-20261017/D07-context.txt)와 [출처·SHA256](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/page1-reference-check-20261017/reference-manifest.json)을 사용한다. 이전 파일 `b2lmAo9VtbL6Qi0mzX5IMu`의 `261008` D07(`912:16551`) 원본/컨텍스트 미확보 기록과 비교 누락은 당시 사실로 보존한다. 새 원본을 과거 비교에 소급 삽입하지 않는다.
- 다음 코드 후보는 **D07 사진 프레임의 내부 치수**다. Figma의 외곽 343×437px·내부 311×405px·간격 16px에 비해 현재 Flutter `Container`의 패딩 16px와 테두리 1px가 합산되면 내부 309×403px·간격 17px이 되어 가로·세로 각각 2px 작다. 이는 원본/컨텍스트와 코드의 정적 분석 결과이며 기기 실측이나 수정 완료가 아니다. 후속 구현 시 새 변경 전/후 화면과 실제 경계 측정으로 검증한다. 사진 전체 보기·채우기·잘림 정책은 이 치수 후보와 분리해 결정 대기로 둔다.
- 이전 `261008`의 구현 범위·조회 시각·테스트 수·기기 결과·비교/영상은 위 당시 기록으로 유지한다. 해당 파일의 M 보완안도 이전 제안이며 현재 Page 1의 확정 범위로 간주하지 않는다. 과거 성공을 새 기준의 검증으로 바꾸지 않는다. 1배율 우선·기존 확대 구현/자동 회귀·콘텐츠 보존·저장 시점·제출 입력과 완료 탭 고정·OS 안전 영역 정책을 유지한다. 카테고리 편집·결과 전체 배치 등 기존 보류 항목을 유지하며 저장 화면 전체 맞춤 완료로 표시하지 않는다.
- 문서 검증 결과: 현재 화면표·중복 설명과 보류 목록의 고유 노드67개가 메타데이터에 존재한다. 변경 행의 로컬 링크40회·고유30경로와 D07 원본/컨텍스트 SHA256을 확인했고, 기존 계획 문서의 기기 검증 절·README 상세·이전 진행 기록이 보존된 것을 대조했다. 최종 diff·`git diff --check`도 통과했다. 제품 코드·공개 API·데이터 모델은 변경하지 않았으며 문서 전용이므로 Flutter 테스트·정적 분석·기기 실행·화면 촬영은 수행하지 않았다. 서버/시뮬레이터/에뮬레이터도 새로 시작하지 않았다. 화면 증거·빌드 생성물·`AGENTS.md`는 제외하고 한 커밋으로 저장하며 푸시·PR은 하지 않는다.


### 2026-10-17 — 사진 선택 프레임의 내부 크기·여백 (`4d46dfa` 기준, 해당 범위 적용·검증 완료)

- 현재 디자인은 파일 `svNWsTFh8Ws1Mpt8XQIcrN`의 Page 1(`0:1`) > 261007(`111:3379`), D07 사진 선택 후(`111:4814`)다. 이번 완료 범위는 사진 선택 프레임의 크기·16px 여백이며 사진 전체 보기/채우기/잘림 정책·카테고리 편집·결과 전체 배치는 별도 미정으로 유지한다. 1배율 우선·기존 확대 구현/자동 검사·제출 입력 고정·완료 탭 고정·기존 OS 안전 영역 정책은 유지한다.
- [구현 직전 Figma 조회](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/figma/reference-manifest.json)는 **2026-10-16 17:52:02~17:52:10 UTC(2026-10-17 02:52:02~02:52:10 KST)**에 D07 컨텍스트와 정확한 원본을 한 호출로 새로 확보했다. 호출 제한이나 보관 원본 fallback은 없었다. [원본 PNG](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/figma/D07.png)의 SHA256은 `6d39065266bd00e128045fc1ec1eec7f5a40d4edb98ac75d1eaff56db133016b`로 앞선 정확한 원본과 같으며 [새 컨텍스트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/figma/D07-context.txt)와 조회 시각은 이번 기록으로 구분한다. 이전 `261008` D07 원본 미확보와 과거 앱 비교는 변경하지 않는다.
- 기존 68개 검사를 유지하고 실제 Pretendard·1배율·iOS/Android 테마·폭320/375px·사진 바이트/에셋 fallback의 8개 프레임 검사를 추가했다. 외곽/내부/clip/LayoutBuilder/이미지 실제 경계, 사방 간격, 배경·테두리1px·모서리8px·crop/fit와 소스를 검사한다. 이미지가 clip보다 큰 기존 표현은 의도된 확대 구조로 구분한다. 프리뷰의 새 경계 검사는 스타일·레이아웃·전체 판정에 합산하며 기존 기본·결과 전용·확대 runner는 유지한다. `/base-style-scene?kind=photo-selected`와 새 `/photo-frame-run`을 사용한다.
- [수정 전 재현](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/tests/before-photo-frame-summary.json)은 **기존68개 통과·새8개만 예상 실패**다. 375px 폭의 내부309×403px(목표311×405px), 320px 폭254×403px(목표256×405px)과 사방17px(목표16px)의 차이를 실제 render bounds로 확인했으며 나머지 표현 검사는 통과했다. 최초 SDK 캐시 권한 오류는 `tests/environment-attempt-*`에 별도 보존하고 권한을 확보한 재실행으로 실제 RED를 기록했다.
- [변경 전 게이트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/before-gate.json)는 **17:57:12.927909 UTC**에 `4d46dfa` 제품 불변·동결 fixture/검사·새 OS 원본2장을 확인했다. [제품 수정 시작](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/product-edit-start.json)은 **17:57:13.019530 UTC**다. Android 첫 System UI ANR 시도는 `android-gesture/attempts/system-ui-anr`에 격리한 뒤 정상 상태로 새로 촬영했다. iOS/Android BEFORE 모두 외곽343×437px·내부309×403px·사방17px을 확인했으며 정적 후보를 실제 기기 프리뷰에서 재현한 결과다. BEFORE 목표치 실패를 원본 촬영 중단으로 처리하지 않았다.
- 제품 변경은 `SelectedPhotoPreview` 외곽 테두리를 `foregroundDecoration`으로 옮겨 기존 명시적 패딩16px에 합산되지 않도록 한 것뿐이다. 외곽437px·배경/색상/모서리·내부 테두리/clip과 이미지 위치−0.4067·높이1.6607·`BoxFit.fill`을 유지한다. 내부는 외곽 폭−32px·높이405px·사방16px이며 실제 기기 화면을375px로 강제하지 않는다. 공개 생성자·콜백·API·데이터 모델과 저장/닫기 정책은 변경하지 않는다.
- [집중76개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/tests/base-typography-green.log)는 통과(로그4초/명령7.41초), [관련335개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/tests/related-green.log)도 통과(로그13초/명령16.04초)했다. [전체 Flutter953개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/tests/full-test.log)는 통과(로그41초/명령43.96초), [분석](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/tests/analyze.log)은 문제 없음(로그3.4초/명령4.25초)이다. [세 Dart 파일 형식 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/tests/format-check.log)는 변경0건(로그0.07초/명령0.35초)이고 [자동 검사 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/automatic-checks.json)의 최종 종료코드는 모두0이다. 기존 확대 자동 검사를 유지했으며 과거945개 성공을 이번953개의 실행으로 사용하지 않는다.
- [iOS AFTER](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/ios-after-driver-result.json)·[Android AFTER](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/android-gesture/after/device-summary.json)는 각 **기록8건(정적/runner 캡처2건·동작6건)·프레임워크 오류0건**이며 `stylePassed`·`layoutPassed`·`behaviorPassed`·`checksCompleted`·전체 `passed`가 모두`true`다. 사진 선택/재선택·탭 왕복 시 사진 바이트와 링크 초안/컨트롤러 유지·새 바이트/`other-photo.png`의1회 제출·완료 탭 고정·닫기를 확인했다. D07/사진 결과의 최대 스크롤은 모두0px이므로 필요한 전체 영역 노출·무스크롤 분기를 확인했으며 실제 드래그 성공으로 보고하지 않는다.
  양쪽 모두 외곽343×437px는 유지되고 내부309×403→311×405px·사방17→16px로 바뀌었다. iPhone16/iOS18.6은 창393×852·DPR3·상하59/34px·외곽left25/top246px, Android13/API33 제스처는392.7×783.3·DPR2.75·24/0px·left약24.864/top211px로 외곽 위치도 동일하다. OS 창/안전 여백 차이를 원본 그대로 구분한다.
- [새2쌍 비교](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/comparison-document.html)와 [비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/comparison-qa.json)는 변경 전→변경 후→현재 Figma D07 원본3열2쌍·누락/조건 불일치0건·BEFORE 원본2장 불변·동결 fixture 일치·외곽 크기/위치·crop/fit 유지·내부가로/세로+2px·16px 여백을 확인했다. 같은 데이터·1배율·키보드 숨김·스크롤0이며 OS 표시를 제거하거나 대체 디자인/이전 앱 캡처를 넣지 않았다.
  새 AFTER 영상은 [iOS](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/ios/after/interaction.mp4)8.861667초·2,601,967바이트, [Android](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/android-gesture/after/interaction.mp4)14.535733초·1,804,959바이트다. [iOS 미디어 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/ios-after-media-verification.json)는 전체 디코딩 종료코드0·오류로그0바이트·키프레임 팝업 없음을 확인했다. 최초 기본 null muxer의 duplicate DTS는 가변 프레임 시각 양자화 경고였으며 원본 변경 없이 demux 시간 기준·프레임 passthrough로 전체 디코딩을 재검증했다. [Android 미디어 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/android-gesture/after/media-verification.json)도 같은 시간 기준으로 전체 디코딩 종료코드0·오류로그0바이트를 확인했다. [종합 미디어 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-photo-frame/media-verification.json)의 두 영상 모두`passed: true`이며 원본 재인코딩은 하지 않았다. 양 플랫폼 앱·Simulator/Emulator 종료·데이터 보존을 확인했고 Android 탐색 설정 변경0건·원래 모드/오버레이 일치·임시 포워딩 없음·adb 기기목록 비어 있음으로 정리했다.
- 재현 명령은 [프론트 README](../frontend/README.md)의 사진 선택 프레임 절을 따른다. 메모리 저장/사진 선택 대역·Flutter 합성 입력과 실제 OS 창을 사용하며 운영 API·OAuth·실기기·원격 CI는 검증 범위 밖이다. 새 배율별/3버튼/키보드 기기 촬영은 추가하지 않는다. 사진 비율/잘림·카테고리 편집·결과 전체 배치와 기존 보류 항목을 유지하고 저장 화면 전체 완료로 표시하지 않는다. 화면 증거·빌드 생성물·`AGENTS.md`는 제외하고 같은 `feature/figma-ui-alignment`에서 한 커밋으로 저장하며 푸시·PR은 하지 않는다.


### 2026-10-17 — 저장 결과 상단 여백 (`d1f13d4` 기준, 해당 범위 적용·검증 완료)

- 기준은 현재 파일 `svNWsTFh8Ws1Mpt8XQIcrN`의 Page 1(`0:1`) > 261007(`111:3379`), D05 링크 결과(`111:4902`)·D09 사진 결과(`111:4865`)다. 이번 대상은 탭 하단부터 결과 제목까지의 시작 여백이다. 저장 본문의 조건부 상단 패딩만 제거해 좌16·상32·우16·하24px로 통일했으며 입력은 기존32px, 결과 제목과 뒤따르는 본문은 스크롤0에서−48px 이동한다. 절대 좌표/개별 보정은 추가하지 않고 헤더/탭·본문 viewport·하단 버튼/안전 영역·키보드 회피·제출 입력/완료 탭 고정·저장/닫기 정책을 유지한다.
- [구현 직전 Figma 조회](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/figma/reference-manifest.json)는 **2026-10-16 18:22:34~18:22:41 UTC(2026-10-17 03:22:34~03:22:41 KST)**에 D05/D09를 각각 한 번 호출해 컨텍스트와 정확한 375×812px 원본을 확보했다. 호출 제한·fallback·누락은 없으며 이전 `261008` 파일 원본으로 대체하지 않았다. 두 원본/컨텍스트와 SHA256·실제 시각을 이번 증거에 보존한다.
- 기존76개 검사와 프리뷰에 실제 패딩·탭 하단/viewport/제목 경계·스크롤 위치·시작 간격을 추가하고 목표 검사를 레이아웃/전체 판정에 연결했다. 실제 Pretendard·iOS/Android 테마·폭320/375px·1배율의 [수정 전 재현](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/tests/focused-red-summary.json)은 **68통과·결과8건만 예상 실패**다. 시작32px은 스크롤0에서만 판정하며 스크롤을 초기화하거나 원시 위치를 보정하지 않는다. 최대 스크롤은 마지막 안내/본문 하단24px/CTA 비중첩으로 검사한다. 기존 D07 프레임·내부 배치·확대 회귀는 유지하고 새 route 없이 기존 scene/resultsOnly runner를 재사용한다.
- [BEFORE 게이트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/before-gate.json)는 **18:24:04 UTC**에 `d1f13d4` 제품 불변·동결 검사/fixture·새 OS 포함 원본4장을 확인했다. iOS/Android 각각 링크·사진을 같은 데이터·1배율·키보드 숨김·스크롤0으로 촬영했으며 모두 시작80px·스타일 통과·목표 레이아웃 실패·프레임워크 오류0건이다. BEFORE 실패가 촬영을 막지 않으며 이전 캡처를 재사용하지 않는다.
- [집중76개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/tests/base-typography-green.log)는 통과(명령9.47초), [관련335개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/tests/related-green.log)도 통과(23.6초)했다. [전체Flutter953개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/tests/full-test.log)는 통과(80.77초), [분석](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/tests/analyze.log)은 문제 없음(6.3초), [세 Dart 파일 형식](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/tests/format-check.log)은 변경0건(0.81초)이다. [자동 검사 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/automatic-checks.json)의 종료코드는 모두0이며 과거953건 성공을 이번 실행으로 대신하지 않는다. 기존 확대·D07 프레임·하단/입력 보존 회귀를 유지했다. [BEFORE빌드](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/before-build.json)·[AFTER빌드](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/final-implementation.json)는 iOS/Android 각각 종료코드0과 실제 소스/바이너리SHA를 기록하며 검사/fixture SHA가 동일하다. 빌드 결과와 native 실행 성공을 구분한다.
- [iOS AFTER](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/ios-after-driver-result.json)·[Android AFTER](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/android-gesture/after/driver-result.json)는 각각 **기록10건(정적/runner 캡처4건·동작6건)·프레임워크 오류0건**이다. 양쪽 [iOS 보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/ios/after/flutter/report.json)·[Android 보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/android-gesture/after/flutter/report.json)의 `stylePassed`·`layoutPassed`·`behaviorPassed`·`checksCompleted`·전체 `passed`는 모두 `true`다. 링크/사진 결과 진입·완료 탭 고정·최대 스크롤 분기·추가 저장 없는 닫기를 확인했다. AFTER의 두 결과는 모두 최대 스크롤0px이므로 무스크롤 상태/마지막 안내 노출로 기록하고 실제 드래그 성공으로 보고하지 않는다. 본문 패딩24px·추가 여유 공간과 viewport/CTA 경계를 구분했으며 겹침은 없다.
  iPhone16/iOS18.6은 창393×852·DPR3·상하59/34px·탭/viewport top179px·제목259→211px·CTA top730px, Android13/API33 제스처는 약392.7×783.3·DPR2.75·24/0px·탭/viewport144px·제목224→176px·CTA top약695.273px다. 두 결과 모두 시작80→32px과 뒤따르는 모든 본문 anchor−48px을 확인하고 내부 크기/상대 간격/글자·헤더/탭/viewport/CTA를 유지했다. Figma 원본은 탭170px·제목202px으로 간격32px이며 OS 여백에 따른 절대좌표 차이를 원본 그대로 설명한다.
- [새4쌍 비교](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/comparison-document.html)·[비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/comparison-qa.json)는 변경 전→변경 후→현재 Figma D05/D09의 완전한3열4쌍·누락/조건 불일치0건·BEFORE 원본4장 불변·검사/fixture SHA일치·본문−48px·내부/CTA 유지·스크롤0에 한정한 위치 판정을 확인한다. 같은 데이터·1배율·키보드 숨김·스크롤0의 OS 원본을 사용하며 대체 디자인/과거 앱 캡처/이전 파일 원본을 넣지 않았다.
  새 AFTER 영상은 [iOS](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/ios/after/interaction.mp4)13.16초·1,111,623바이트와 [Android](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/android-gesture/after/interaction.mp4)15.313511초·951,268바이트다. [미디어 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/media-verification.json)는 두 원본의 전체 디코딩 종료코드0·오류로그0바이트·시작/중간/끝 및0.5초 간격 표본의 팝업 없음·결과 진입/선택/닫기 장면·원본 재인코딩 없음을 확인했다. BEFORE는 정적 촬영만 수행했고 이전 영상을 재사용하지 않는다. iOS 앱/Simulator와 Android 앱/Emulator 종료·데이터 보존, Android 원래 제스처 mode2/여섯 오버레이 일치·탐색 설정 변경0건·8768 포워딩 제거·기기 목록 비어 있음을 실행 기록에 남겼다.
- 재현 명령은 [프론트 README](../frontend/README.md)의 저장 결과 상단 여백 절을 따른다. 완료는 결과 시작 여백에 한정하며 과거 ‘결과 상단80px 유지’는 당시 기록으로 보존하고 현재는32px을 적용한다. 사진 비율/잘림·미리보기 제목–출처 간격·카테고리 편집·결과 전체 배치는 계속 보류한다. 새 확대/3버튼/키보드 기기 촬영은 추가하지 않고 기존 확대 구현/자동 검사를 유지한다. 메모리 저장/사진 선택 대역·Flutter 합성 입력·실제 OS 화면을 운영 API·OAuth·실기기·원격 CI 검증과 구분하며 저장 화면 전체 맞춤 완료로 표시하지 않는다. 화면 증거·빌드 생성물·`AGENTS.md`는 제외하고 같은 `feature/figma-ui-alignment`에서 한 커밋으로 저장하며 푸시·PR은 하지 않는다.
- [최종 환경 정리](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-top-gap/cleanup-verification.json)는 **18:30:08 UTC**에 iPhone16 Shutdown·adb/Emulator/qemu 프로세스0건·8767/8768 listener 없음·포워딩 제거·adb 서버 종료·데이터 보존을 확인했다. 임시 비교 서버는 시작하지 않았다. 비교 HTML의 JS 문법·36개 파일 경로·PNG 직접 시각 검사는 확인했으나 브라우저 상호작용 실행은 이번에 검증하지 않았으며 native 앱 실행/영상 성공과 구분한다.


### 2026-10-17 — 저장 결과 미리보기 제목–출처 간격 (`a6dfb4e` 기준, 해당 범위 적용·검증 완료)

- 기준은 현재 파일 `svNWsTFh8Ws1Mpt8XQIcrN`의 Page 1(`0:1`) > 261007(`111:3379`), D05 링크 결과(`111:4902`)·D09 사진 결과(`111:4865`)다. 이번 대상은 두 문단 사이 간격 8→14px이며 카드 최소116px·내부8px·썸네일164×100px·이미지/텍스트16px·글꼴/행간·줄 수/말줄임·자연 높이/중앙 정렬을 유지한다. 결과 시작32px·하단 버튼/안전 영역·제출 입력/완료 탭 고정·저장/닫기와 공개 API/모델을 변경하지 않는다.
- 실제 Pretendard를 사용한 [수정 전 집중 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/tests/focused-red-summary.json)는 **122건 중74통과·48실패**다. 1배율24건·기존 확대24건에서 기존8px과 목표14px, 텍스트 묶음 높이6px 차이만 실패했으며 무관 실패는0건이다. 말줄임 없는 두 줄 사례8건을 추가했다.375px은 D05 원문,320px은 대역 제목을 사용해 링크/사진·iOS/Android에서 실제 두 줄·말줄임 없음과 기존 카드/중앙 정렬을 검사한다. 두 검사 소스를 포맷/동결했으며 제품 수정은 새 BEFORE 원본4장·기준 제품 불변 게이트를 확인한 뒤 수행했다.
- 새 기기 촬영은 기존 한 줄 제목 ‘저장 결과 확인’과 고정 데이터를 유지한다. Figma 예제와 다른 콘텐츠/줄 수이므로 절대 위치 전체의 일치를 주장하지 않는다. 새 경로 없이 기존 `/base-style-scene?kind=link|photo`·`/base-style-run?resultsOnly=1`을 재사용하며 새 배율별/3버튼/키보드 기기 촬영은 추가하지 않는다. 기존 확대 자동 검사와 D07/상단32px/하단/입력 보존 회귀는 유지한다.
- [이번 Figma 재조회](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/figma/reference-manifest.json)는 **2026-10-17 03:44:39~03:44:45 UTC(12:44:39~12:44:45 KST)**에 현재 파일 D05/D09를 각각 한 번 호출해 컨텍스트와 정확한375×812px 원본을 확보했다. 호출 제한·fallback·누락은 없으며 새 원본/컨텍스트의 SHA256·실제 조회 시각을 보존한다. 현재 Page1 보관본과 원본 SHA가 같아도 이번 새 조회로 구분하고 이전261008 이미지를 사용하지 않는다.
- [BEFORE 게이트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/before-gate.json)는 **2026-10-17 03:50:48 UTC(12:50:48 KST)**에 `a6dfb4e` 제품 불변·검사/fixture 동결·새 OS 포함 원본4장을 확인했다. 링크/사진 모두 간격8px·텍스트 묶음54px·카드116px·제목/출처 각 한 줄·스크롤/최대 스크롤0px·시작32px이며 스타일 통과·목표 레이아웃 실패·프레임워크 오류0건이다. iPhone16/iOS18.6은 창393×852·DPR3·안전 여백59/34px, Android13/API33 제스처는 약392.7×783.3·DPR2.75·24/0px이다. 제품은 이 게이트 뒤 제목/출처 사이 `SizedBox` 한 곳만8→14px로 변경했다.
- [iOS 초기 환경 시도](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/ios/attempts/xcode-first-launch.json)는 Xcode wrapper가 요구한 CoreSimulator1174.9.2와 기존1171.7 차이로 자동 최초 준비가 실행돼 첫 기기 목록120초·정리60초 시간 초과를 기록했다. 최초 캡처0장·제품 불변 상태였다. 표준 Xcode 진단에서 `Install Succeeded`와 버전 갱신을 확인한 뒤 표준 `xcrun simctl` 재시도로 BEFORE를 확보했다. 직접 native 읽기 진단만 했으며 우회 촬영·사용자 데이터 초기화·수동 설정 변경은 없었다. 환경 실패와 앱 프레임워크 오류0건을 구분한다.
- [집중84건](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/tests/base-typography-green.log)은 통과(12.39초), [관련335건](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/tests/related-green.log)도 통과(22.39초)했다. [전체Flutter961건](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/tests/full-test.log)은 통과(59.95초), [정적 분석](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/tests/analyze.log)은 문제 없음(6.85초), [네 Dart 파일 형식 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/tests/format-check.log)는 변경0건(0.39초)이다. [이번 자동 검사 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/automatic-checks.json)의 종료코드는 모두0이며 기존 확대·D07 프레임·상단32px·하단/입력 보존 검사를 유지한다. 이전953건 성공을 이번961건으로 바꾸지 않는다. [BEFORE빌드](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/before-build.json)·[AFTER빌드](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/final-implementation.json)는 iOS/Android 각각 성공했고 AFTER Android14.58초·iOS89.39초와 실제 제품/바이너리/동결 fixture·두 검사 SHA를 기록했다. 빌드 성공을 native 실행 성공으로 대신하지 않는다.
- Android 첫 AFTER는 자동 보고서10건 통과였으나 OS 원본 직접 검사에서 System UI 응답 없음 팝업이 확인돼 [환경 시도](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/android-gesture/attempts/system-ui-anr-first-after)에 원본/보고서/영상을 격리했다. 해당 자료는 성공 증거로 채택하지 않는다. 같은 APK/fixture/AVD·탐색 설정을 유지하고 빌드/테스트 및 iOS 종료 뒤 Android 단독으로 재촬영했으며 실제 정상 원본2장/영상만 최종 채택했다. 앱 프레임워크 오류0건을 OS 화면 정상의 대체 증거로 쓰지 않는다.
- 최종 [iOS 실행](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/ios-after-driver-result.json)·[Android 실행](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/android-gesture/after/driver-result.json)은 각각 **기록10건·프레임워크 오류0건**이다. [iOS 보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/ios/after/flutter/report.json)·[Android 보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/android-gesture/after/flutter/report.json)의 `stylePassed`·`layoutPassed`·`behaviorPassed`·`checksCompleted`·전체 `passed`는 모두`true`다. 결과 진입·완료 탭 고정·추가 저장 없는 닫기를 확인했으며 링크/사진의 최대 스크롤은 모두0px이므로 무스크롤 상태·마지막 안내 노출로 기록하고 실제 드래그 성공으로 보고하지 않는다.
- [실측 표](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/preview-gap-measurements.json)는 네 결과 모두 간격8→14px·텍스트 묶음54→60px·제목−3px/출처+3px·중앙 정렬과 나머지 좌표/크기/간격/글자 유지를 확인했다. iOS 링크 제목413→410px/출처445→448px·사진384→381px/416→419px, Android 링크378→375px/410→413px·사진349→346px/381→384px이다. 카드343×116px·이미지164×100px·카테고리 행343×55px·이미지/글자16px·미리보기 제목/카드16px·결과 시작32px·본문 명시적 하단24px과 헤더/탭/viewport/CTA는 유지했다. 하단 패딩과 viewport의 추가 빈 공간을 구분하며 마지막 안내는 완전히 노출되고 버튼과 겹치지 않는다.
- [새3열4쌍 비교](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/comparison-document.html)·[비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/comparison-qa.json)는 변경 전→변경 후→현재 Figma D05/D09 원본 순서의 완전한4쌍·누락/조건 불일치0건·BEFORE 원본 불변·검사/fixture SHA동일·간격/위치 변화와 나머지 배치 유지를 확인했다. 비교 PNG4장을 직접 확인했으며 OS 팝업은 없다. 촬영은 같은 데이터·1배율·키보드 숨김·스크롤0의 새 OS 원본이고 대체 화면을 만들지 않았다. 원본 창/안전 영역을 그대로 표시하며 한 줄 대역과 두 줄 Figma 예제의 간격만 대조하고 제목 절대 위치의 일치를 주장하지 않는다.
- 새 AFTER 영상은 [iOS](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/ios/after/interaction.mp4)9.65초·1,176,329바이트, [Android](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/android-gesture/after/interaction.mp4)14.441633초·925,712바이트다. [미디어 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/media-verification.json)는 두 원본 전체 디코딩 종료코드0·오류로그0바이트·원본 SHA불변을 확인했다. 0.5초 간격 iOS19개·Android29개 표본 직접 검사에서 결과 진입/탭 유지/닫기 장면과 OS 팝업 없음을 확인했다. 첫 Android 환경 실패 영상과 과거 영상은 사용하지 않는다.
- [최종 환경 정리](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-text-gap/cleanup-verification.json)는 **2026-10-17 03:58:28 UTC(12:58:28 KST)**에 iPhone16 Shutdown·Emulator/adb/qemu/Xcode 최초 준비 프로세스0건·8767/8768 listener 없음·포워딩 제거·원래 제스처 mode2/설정 변경0건·사용자 데이터 보존을 확인했다. 임시 비교 서버는 시작하지 않았다. 비교 HTML의 JS 문법·참조31개 경로·PNG 직접 시각 검사는 확인했으나 브라우저 상호작용 실행은 이번에 검증하지 않았다. native 앱 실행/영상과 구분하며 메모리 저장/사진 선택 대역·Flutter 합성 입력 검증을 운영 API·OAuth·실기기·원격 CI 증거로 사용하지 않는다.
- 이번 완료 범위는 제목–출처 간격에 한정한다. 과거8px 유지 기록과 앞선 작업의 성공/조회/촬영 시각은 보존하고 현재 간격은14px이다. 사진 비율/잘림·카테고리 편집·결과 전체 배치·한 줄 전용 Figma 미확인은 유지하며 저장 화면 전체 완료로 표시하지 않는다. 화면 증거·빌드 생성물·`AGENTS.md`는 제외하고 같은 `feature/figma-ui-alignment`에서 한 커밋으로 저장하며 푸시·PR은 하지 않는다.

### 2026-10-17 — 저장 결과 미리보기 제목 최대 폭 (`63800e6` 기준, 해당 범위 적용·검증 완료)

- Page 1 > 261007의 D05 `111:4902`·D09 `111:4865`에서 콘텐츠 제목에만 우측8px을 확보했습니다. [이번 Figma 조회](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/figma/reference-manifest.json)는04:16:05~04:16:11 UTC(13:16:05~13:16:11 KST) 총2회 성공·누락/fallback0입니다. 출처 폭·제목/출처 간격14px·글자·자연 높이/중앙 정렬·카드/이미지·시작32px·하단 정책과 저장 계약은 유지했습니다.
- [수정 전 재현](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/reproduction-test-summary.json) · [정정 후 기준 코드 재현](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/amended-reproduction-summary.json)는 **130건 중74통과·56실패**였습니다. [BEFORE 게이트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/before-gate.json)에서 제품 불변·새 OS원본4장·fixture/검사 동결을 확인한 뒤 제품을 수정했습니다. 이후 첫 GREEN의 선택 상자1.2px 초과 오판4건은 [검사 소스 정정](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/test-source-amendment.json)에서 실제 제약/레이아웃과 선택 영역 경계를 구분해 고쳤습니다. 허용 오차를 늘리지 않았고 기준 제품으로도 다시74/56을 확인했습니다. 기본 검사 SHA는6d4f95…→b6cc9b…로 변경됐으므로 전후 같다고 표시하지 않습니다. 이 검사 파일은 네이티브 컴파일에 포함되지 않으며 fixture82b806…·확대 검사95abe4…·BEFORE4원본은 그대로입니다.
- [자동 검사 요약](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/automatic-summary.json): 기본92건/8.26초·관련335건/16.85초·전체969건/46.79초 통과, 분석 문제 없음/4.31초·Dart4파일 형식 변경0건/0.35초입니다. 기존 확대 자동 검사는 유지하고 이전961건을 이번 실행으로 대신하지 않았습니다. [최종 빌드·소스 증명](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/final-implementation.json)의 Android14.8초·iOS67.51초 빌드 성공은 아래 native 실행과 구분합니다.
- [변경 전→변경 후→Figma 4쌍](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/comparison-document.html) · [비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/comparison-qa.json) · [실측 표](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/preview-title-width-measurements.json)에서 제목 최대 제약은147→139px·출처147→147px, 320px 자동 사례는92→84px·출처92px입니다. 기기의 기존 짧은 제목은 실제 문단 폭82.1074px·한 줄·경계가 불변이고 Figma는 두 줄 예제입니다. 글리프 픽셀 폭이나 전체 세로 위치를 맞췄다고 주장하지 않습니다. 카드343×116·이미지164×100·텍스트 묶음60px·간격14px·중앙·다른 경계/글자도 유지했습니다.
- [iOS 보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/ios/after/flutter/report.json)·[Android 보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/android-gesture/after/flutter/report.json)는 각각10기록·프레임워크 오류0건·`stylePassed`/`layoutPassed`/`behaviorPassed`/`checksCompleted`/전체 `passed: true`입니다. 결과 진입·탭 고정·추가 저장 없는 닫기를 확인했습니다. 네 상태의 최대 스크롤은0px이며 무스크롤·마지막 안내 완전 노출·본문 하단 최소24px·CTA 겹침 없음을 확인했습니다. 드래그 성공이나 새 확대/키보드/3버튼 촬영으로 보고하지 않습니다.

| 플랫폼 | 링크 결과 비교 | 사진 결과 비교 |
| --- | --- | --- |
| iOS | [링크 결과](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/comparison-ios-link.png) | [사진 결과](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/comparison-ios-photo.png) |
| Android 제스처 | [링크 결과](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/comparison-android-gesture-link.png) | [사진 결과](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/comparison-android-gesture-photo.png) |

- [iOS 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/ios/after/interaction.mp4)(9.426667초) · [Android 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/android-gesture/after/interaction.mp4)(13.778167초). [전체 디코딩](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/media-verification.json) · [직접 시각 검토](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/direct-visual-review.json)는 전체 디코딩 종료0·오류0바이트와 iOS20/Android29 표본 모두의 시각 확인을 구분합니다. 완전한3열4쌍·조건/Figma 누락0·팝업/목표 영역 잘림0이며 촬영 OS 원본은 보정하지 않았습니다. 시계와 iOS Dynamic Island 표시 차이는 보존했고 앱 geometry/inset은 같습니다.
- [최종 환경 정리](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/cleanup-verification.json)는04:30:15 UTC(13:30:15 KST)에 Simulator Shutdown·Emulator/adb0·8767/8768 리스너0·포워딩 제거·원래 설정/변경0·데이터 보존을 확인했습니다. [비교 문서 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/comparison-document-check.json)의 JS 문법·참조31개는 통과했으나 서버 미시작·브라우저 상호작용 미검증입니다. [영구 보존 증명](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-title-width/archive-provenance.json)은164개 파일의 복사/SHA 일치와 원본 미변경을 확인합니다.
- 이번 완료는 제목 최대 폭뿐입니다. 출처 최대 폭 원본 기준·한 줄 결과 세로 배치·사진 비율/잘림·카테고리 편집·결과 전체 맞춤과 API/OAuth/실기기/원격 CI 검증은 남겨 둡니다. 고정 선택기·메모리 저장·Flutter 합성 입력 검증을 운영 증거로 확대하지 않으며 과거 조회/검사/비교 기록을 보존합니다. 화면 증거·빌드·`AGENTS.md`는 커밋에서 제외하고 푸시/PR은 하지 않습니다.

### 2026-10-17 — 저장 결과 카테고리 시작 간격 (`fec6b66` 기준, 해당 범위 적용·검증 완료)

- 기준 `fec6b66`에서 제품은 미리보기 카드와 카테고리 제목 사이 `SizedBox` 한 곳만30→32px로 바꿨다. 스크롤0에서 카테고리 제목·상태 안내·행/이름·폴더·상세 변경 안내가 함께2px 내려간다. 제목139px·출처147px·간격14px·카드116px·이미지164×100px·글꼴·자연 높이/중앙 정렬·결과 시작32px·하단 배치는 유지한다. 처리 중·미분류·분류됨 문구와 읽기 전용 상태·상세 변경 안내·저장/닫기도 유지한다.
- [새 Figma 조회](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/figma/reference-manifest.json)는 Page 1 > 261007의 D05 `111:4902`·D09 `111:4865`를 총2회 성공 조회했다(2026-10-17 04:46:58~04:47:04 UTC / 13:46:58~13:47:04 KST). 정확한 원본·컨텍스트를 보존했으며 누락/fallback은 없다. [32px 좌표 근거](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/figma/gap-reference.json)는 기존 메타데이터의 카드 하단493px/카테고리 제목525px을 새 컨텍스트·원본과 교차 확인한 것이며 메타데이터를 다시 조회한 것은 아니다.
- [RED 재현](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/summary.json)은130건 중58통과·72실패(기본48·기존 확대24)로30px과32px 차이를 재현했다. [수정 전 게이트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/before-gate.json)의 새 OS원본4장 확보 후 제품을 수정했다. fixture·기본/확대 검사 SHA는 전후 모두 같고 검사 소스 정정은 없었다. [자동 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/automatic-summary.json): 기본92건(8.79초)·관련335건(17.16초)·전체 Flutter969건(47.12초) 통과, 분석 문제 없음(4.55초), Dart4파일 형식 변경0건(0.36초). 이전 작업의 검사/조회/촬영은 이번 성공으로 사용하지 않는다.
- [새 3열4쌍 비교](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/comparison-document.html) · [비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/comparison-qa.json) · [실측 표](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/category-start-gap-measurements.json)에서30→32px·카테고리 전체+2px을 스크롤0 기준으로 확인했다. 나머지 본문/헤더/탭/viewport/CTA와 미리보기·카테고리 내부 스타일/크기/간격은 같다. Figma·조건 누락0건이며 기기 한 줄 제목과 Figma 두 줄 예제의 전체 세로 배치가 같다고 주장하지 않는다. OS 영역/원본을 보정하거나 대체 디자인을 만들지 않았다.
- iPhone16/iOS18.6·Android13/API33 제스처 AFTER는 각각 기록10/10건·프레임워크 오류0건, `stylePassed`·`layoutPassed`·`behaviorPassed`·`checksCompleted`·전체 `passed: true`다. [iOS 보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/ios/after/flutter/report.json)·[Android 보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/android-gesture/after/flutter/report.json)에서 결과 진입·완료 탭 고정·추가 저장 없는 닫기를 확인했다. 최대 스크롤은 네 결과 모두0px이므로 무스크롤·마지막 안내 완전 노출·하단 최소24px·CTA 겹침 없음을 확인한 범위이며 실제 드래그 성공으로 보고하지 않는다.

| 플랫폼 | 링크 결과 비교 | 사진 결과 비교 |
| --- | --- | --- |
| iOS | [링크 결과](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/comparison-ios-link.png) | [사진 결과](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/comparison-ios-photo.png) |
| Android 제스처 | [링크 결과](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/comparison-android-gesture-link.png) | [사진 결과](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/comparison-android-gesture-photo.png) |

- [iOS 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/ios/after/interaction.mp4) 9.52167초/1,255,632바이트 · [Android 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/android-gesture/after/interaction.mp4) 13.1323초/948,355바이트. [전체 디코딩](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/media-verification.json)은 종료코드0·오류0바이트·원본 해시 불변, [직접 시각 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/direct-visual-review.json)는 iOS20·Android28개 표본 전부의 결과 진입/탭 고정/닫기와 OS 팝업·목표 영역 잘림/겹침 없음을 확인했다. 시계와 실제 OS 표시 차이는 보존하며 앱 geometry/inset과 원본 조건을 구분한다.
- [환경 정리](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/cleanup-verification.json)(2026-10-17 04:56:23 UTC / 13:56:23 KST)에서 Simulator Shutdown·Emulator/adb0·8767/8768 리스너0·설정 변경0·데이터 보존을 확인했다. [비교 문서 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-category-start-gap/comparison-document-check.json)는 JS 문법·참조31개만 검증했다. 서버를 시작하지 않았고 브라우저 상호작용은 미검증이다. 고정 선택기/메모리 저장·합성 입력 증거를 운영 API·OAuth·실기기·원격 CI 검증으로 확대하지 않는다.
- 완료는 카테고리 시작 간격32px에 한정한다. 안내를 제목 옆/아래에 놓는 상태별 기준·카테고리 편집·사진 비율/잘림·한 줄 결과의 세로 배치·출처 최대 폭 원본 기준·전체 맞춤은 보류한다. 기존 확대 자동 검사는 유지하고 새 확대/키보드/3버튼 기기 촬영은 추가하지 않는다. 과거 기록을 보존하며 화면 증거·빌드·`AGENTS.md`는 커밋에서 제외한다. 푸시/PR은 하지 않는다.
- 같은 `feature/figma-ui-alignment` 브랜치에서 `fix: 피그마 기준으로 저장 결과 카테고리 시작 간격 맞춤`으로 한 커밋에 저장한다.

### 2026-10-17 — 저장 결과 미리보기 시작 간격 (`b61a47d` 기준, 해당 범위 적용·검증 완료)

- 기준 `b61a47d`에서 링크 검증 문구→미리보기 제목 간격28→32px, 사진 파일명 박스→미리보기 제목 간격28→16px만 적용했다. 스크롤0에서 미리보기 제목 이후 카드·카테고리·마지막 안내 전체가 링크+4px/사진−12px 이동한다. 앞 입력/검증 블록·헤더·탭·본문 viewport·버튼은 같으며 결과 시작32px·카드→카테고리32px·제목139px/출처147px·제목–출처14px·카드116px·이미지164×100px·글자·자연 높이/중앙 정렬을 유지한다.
- [Figma 조회](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/figma/reference-manifest.json)는 Page 1 > 261007의 D05 `111:4902`·D09 `111:4865` 원본·컨텍스트를2회 성공 조회했다(2026-10-17 05:04:51~05:04:57 UTC / 14:04:51~14:04:57 KST, 누락/fallback0). [간격 좌표 근거](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/figma/gap-reference.json)는 기존 메타데이터를 새 원본·컨텍스트와 교차 확인했으며 메타데이터는 다시 조회하지 않았다. 사진은 앱의 현재 파일명 박스44px 다음 간격만 맞췄다. Figma의 앞 이미지89px와 다른 구조·사진 비율/잘림은 보류하므로 사진 전체 좌표가 같다는 판정은 하지 않는다.
- [RED 재현](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/summary.json) 130건 중74통과·56실패(기본32·기존 확대24)는 기존28px과 링크32px/사진16px의 차이만 재현했다. [제품 수정 전 게이트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/before-gate.json)의 새 OS원본4장을 먼저 확보했으며 fixture·기본/확대 검사 SHA는 전후 동일하고 검사 소스 정정은 없다. [자동 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/automatic-summary.json): 기본92건(13.85초)·관련335건(24.63초)·전체 Flutter969건(111.6초) 통과, 분석 문제 없음(5.14초), Dart4파일 형식 변경0건(0.45초). [최종 빌드](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/final-implementation.json)의 양 플랫폼 빌드도 성공했다(android 16.45초·ios 124.76초). 과거 검사·조회·촬영을 이번 성공으로 사용하지 않는다.
- [새 비교4쌍](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/comparison-document.html) · [비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/comparison-qa.json) · [실측 표](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/preview-start-gap-measurements.json): 같은 데이터·1배율·스크롤0·키보드0px의 완전한3열4쌍이며 Figma·조건 누락0건이다. 원본은 OS 영역을 포함해 무보정으로 보존했고 비교 표시만 종횡비대로 축소했다. 기기의 한 줄 제목과 Figma 두 줄 예제의 절대 위치·전체 세로 배치까지 같다고 판정하지 않는다.
- iPhone16/iOS18.6·Android13/API33 제스처 AFTER는 각각 기록10/10건·프레임워크 오류0건, `stylePassed`·`layoutPassed`·`behaviorPassed`·`checksCompleted`·전체 `passed: true`다. [iOS 보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/ios/after/flutter/report.json)·[Android 보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/android-gesture/after/flutter/report.json)에서 두 결과 진입·반대 탭을 눌러도 완료 탭 유지·추가 저장 없는 닫기를 확인했다. 최대 스크롤은 네 결과 모두0px이므로 무스크롤·마지막 안내 완전 노출·하단 최소24px·버튼 겹침 없음을 확인한 범위다.

| 플랫폼·결과 | 앞 블록→미리보기 | 이후 전체 이동(스크롤0) | 최대 스크롤 | 3열 비교 |
| --- | --- | --- | --- | --- |
| iOS 링크 | 28→32px | +4px | 0px | [변경 전 → 후 → Figma](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/comparison-ios-link.png) |
| iOS 사진 | 28→16px | -12px | 0px | [변경 전 → 후 → Figma](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/comparison-ios-photo.png) |
| Android 제스처 링크 | 28→32px | +4px | 0px | [변경 전 → 후 → Figma](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/comparison-android-gesture-link.png) |
| Android 제스처 사진 | 28→16px | -12px | 0px | [변경 전 → 후 → Figma](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/comparison-android-gesture-photo.png) |

- [iOS 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/ios/after/interaction.mp4) 9.35833초/1,246,375바이트 · [Android 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/android-gesture/after/interaction.mp4) 13.0768초/978,062바이트. [영상 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/media-verification.json)는 전체 디코딩 종료코드0·오류0바이트·원본 해시 불변이며 [직접 시각 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/direct-visual-review.json)에서 새 원본4장·비교4장과 iOS20개·Android28개 표본 전부를 확인했다. OS 팝업과 목표 영역 잘림/겹침은 없으며 시계 등 실제 OS 표시 차이는 원본 그대로 남겼다.
- [환경 정리](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/cleanup-verification.json)(2026-10-17 05:15:51 UTC / 14:15:51 KST): Simulator Shutdown·Emulator/adb0·8767/8768 리스너0·탐색 설정 변경0·데이터 보존. [비교 문서 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-preview-start-gap/comparison-document-check.json)는 JS 문법·참조31개만 검증했다. 비교 서버는 시작하지 않았고 브라우저 상호작용은 미검증이다. 고정 선택기·메모리 저장·합성 입력 증거를 API/OAuth·실기기·원격 CI 증거로 확대하지 않는다.
- 완료는 앞 블록과 미리보기 제목 사이 간격에 한정한다. 한 줄 결과 세로 배치·출처 최대 폭 원본 기준·사진 표시/잘림·카테고리 안내의 제목 옆/아래 배치와 편집·전체 맞춤은 보류한다. 문구·분류 상태·저장/닫기·기존 확대 자동 검사는 유지했고 새 확대/키보드/3버튼 기기 촬영은 추가하지 않았다. 화면 증거·빌드·`AGENTS.md`는 커밋에서 제외하며 푸시/PR은 하지 않는다.

### 2026-10-17 — 저장 결과 화면 단위 표현 (`c33a45d` 기준·승인 범위 적용·검증 완료)

- 기준 `c33a45d`에서 사진 결과의44px 파일명 표시를89px 요약으로 바꿨다. 바깥R8/패딩16px·내부 가용 폭×57px/R0·1px 전경 테두리 안에 제출 원본 bytes를 `Image.memory`의 중앙 `cover`로 표시하고 파일명은 접근성 이름으로 보존했다. 사진 미리보기 썸네일에만1px/R4 테두리를 적용했다. 카테고리는 기존 상태 문구를 유지한 자연 `Wrap`8/8/중앙과 정확한 SVG28.1942×23.965px·실제 색상으로 맞췄다.
- [Figma 조회](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-screen/figma/reference-manifest.json): Page 1 > `261007`의 D05 `111:4902`·D09 `111:4865` 컨텍스트/원본을2026-10-17 05:47:19~05:47:25 UTC(14:47:19~14:47:25 KST)에2회 성공 조회했다. fallback/누락0이며 [폴더 원본](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-screen/figma/save-result-folder.svg) SHA256은 `f60bee5b819eefc791ba045a9d2930dfeff67a37f0006527d6c3000321739b6e`다. 임시 Figma URL은 런타임에서 사용하지 않는다.
- 초기 집중검사는141통과/2실패였다. 새 사진 방향 검사가 디코딩 전 이미지를 읽는 보조 문제를 [검사 보강](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-screen/confirmation-decode-amendment.json)으로 고쳤으며 기대 디자인/bytes/clip은 유지했다. [동결 재시작](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-screen/strict-freeze-restart.json)에 따라 초기 BEFORE10장과 실패 자료를 `superseded-initial-freeze`에 원형 보존하고 제품을 기준으로 복원해 새 BEFORE10장을 다시 촬영했다. [최종 수정 전 게이트](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-screen/before-gate.json)는06:05:20 UTC(15:05:20 KST)에 통과했다. 최종 비교는 새 원본만 사용하며 재시작 이후 fixture·기본·확대·결과 검사 네 소스 SHA는 전후 동일하다.
- [최종 RED 재현](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-screen/summary.json)은143건 중72통과/71실패(기본56·확대12·결과3)로 이번 목표 차이만 재현했다. 초기 관련검사의329통과/8실패는 과거 시각 파일명 기대문2곳에 연결되어 [인증 검사 정비](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-screen/auth-result-assertion-amendment.json)에서 접근성 파일명·원본 bytes 검사로 바꿨다. 인증/HTTP 재시도/multipart 본문은 유지하고 별도 인증48건과 최종 관련 검사를 다시 통과했다.
- [자동 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-screen/automatic-checks.json): 집중143건(10.36초)·관련337건(30.66초)·전체971건(53.33초) 통과, analyze 문제0건(4.84초)·Dart7파일 형식 변경0건(0.46초). [AFTER 빌드](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-screen/final-implementation.json)는 iOS68.98초/Android26.66초·종료코드0이다. 과거 작업의 검사·조회·촬영을 이번 성공으로 사용하지 않았다.
- iPhone16/iOS18.6과 Android13/API33 제스처의 [iOS 보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-screen/ios/after/flutter/report.json)·[Android 보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-screen/android-gesture/after/flutter/report.json)는 각각25기록·프레임워크 오류0건, `stylePassed`·`layoutPassed`·`behaviorPassed`·`checksCompleted`·전체 `passed: true`다. 다섯 상태의 저장1회·반대 탭 고정·최대 스크롤·추가 저장 없는 닫기를 확인했다. 최대 스크롤은 양쪽 각5상태 모두0px이므로 실제 드래그는 실행하지 않았고 마지막 안내 완전 노출·최소 하단24px·버튼 겹침 없음을 확인했다.
- [새10쌍 비교](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-screen/comparison-document.html) · [비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-screen/comparison-qa.json) · [실측 표](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-screen/save-result-screen-measurements.json): 전후 OS원본 각10장·완전3열10쌍·조건/Figma 누락0건이다. 같은 데이터·1배율·스크롤0·키보드0px이며 OS 원본을 자르거나 보정하지 않았다. D05/D09 기본 원본을 쓰는 상태 비교로, 별도 미분류/처리 중 원본을 확보했다고 보고하지 않는다.

| 결과 상태 | iOS 변경 전 → 후 → Figma | Android 제스처 변경 전 → 후 → Figma |
| --- | --- | --- |
| 링크·분류됨 | [3열 비교](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-screen/comparison-ios-link-classified.png) | [3열 비교](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-screen/comparison-android-gesture-link-classified.png) |
| 링크·미분류 | [3열 비교](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-screen/comparison-ios-link-uncategorized.png) | [3열 비교](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-screen/comparison-android-gesture-link-uncategorized.png) |
| 링크·처리 중 | [3열 비교](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-screen/comparison-ios-link-processing.png) | [3열 비교](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-screen/comparison-android-gesture-link-processing.png) |
| 사진·분류됨 | [3열 비교](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-screen/comparison-ios-photo-classified.png) | [3열 비교](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-screen/comparison-android-gesture-photo-classified.png) |
| 사진·미분류 | [3열 비교](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-screen/comparison-ios-photo-uncategorized.png) | [3열 비교](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-screen/comparison-android-gesture-photo-uncategorized.png) |

- 본문375px 실측은 사진 요약343×89px·내부311×57px, 카드343×116px·썸네일164×100px·제목139px/출처147px·간격14px이다. 제약은 실제 카드 폭에서 파생하며 두 줄 고정 제목을 사용했다. 짧은 상태 그룹은44→19px, 처리 중은44px를 유지했다. 링크 짧은 상태의 행은−25px/처리 중은0px, 사진 미리보기는+45px/행은+20px로 움직여 본문 전체의 균일 이동으로 판정하지 않았다. 그룹→행16px·행55px·행→안내8px·기존 글자와 헤더/탭/본문 viewport/하단·저장 입력은 유지했다.
- [iOS 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-screen/ios/after/interaction.mp4) 25.0433초/3,365,326바이트 · [Android 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-screen/android-gesture/after/interaction.mp4) 33.8899초/2,270,055바이트. [영상 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-screen/media-verification.json)의 전체 디코딩 종료코드0·오류0바이트·원본 SHA 불변을 확인했다. [직접 시각 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-screen/visual-review.json)는 원본20장·비교10장과0.5초/끝 부근 표본120개(iOS51/Android69,6페이지)를 전부 확인해 OS 팝업/ANR·수정 영역의 의도하지 않은 잘림/겹침이 없었다. 모든 디코딩 프레임을 수동 검사했다고 주장하지 않는다.
- [환경 정리](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-screen/cleanup-verification.json)는06:12:26 UTC(15:12:26 KST)에 Simulator Shutdown·Emulator/adb0·8767/8768 리스너0·Android 탐색 설정 변경0·데이터 보존을 확인했다. [HTML 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-screen/html-verification.json)는 로컬 참조59개·JS 문법만 확인했으며 비교 서버와 브라우저 상호작용은 실행하지 않았다.
- 완료는 승인된 결과 표현5상태·1배율에 한정한다. D05의 결과 붙여넣기·카테고리 추가/제거는 기존 읽기 전용 결과 정책에 따라 추가하지 않았다. 사진 중앙 `cover`는 Figma 샘플과 잘림 위치가 다를 수 있는 승인 기준이다. 저장/입력·OS 정책과 기존 확대 자동 검사는 유지했다. D07 사진 표시·API 썸네일·카테고리 편집·원본 없는 전용 디자인·새 확대 기기 촬영은 후속이다. 고정 선택기/메모리 저장/합성 입력·Simulator/Emulator 증거를 운영 API/OAuth·실기기·원격 CI 증거로 확대하지 않는다.

## 콘텐츠 상세 화면의 1배율 표현 맞춤 — 2026-10-17

`bff0a7c` 기준으로 Page 1 > `261007`의 F02 기본(`111:3842`)·F03 전문 펼침(`111:3771`)·F04 연관 없음(`111:3909`)을 대조했다. 완료 범위는 상세의 흰 배경·상단·기본 글자·태그·카테고리와 연관 카드이며 실제 원문/미디어·추천 API 연결이나 상세 전체 기능 완료를 뜻하지 않는다.

사용자 확정으로 제목·요약의 3줄 제한/요약72px 고정을 제거해 전체 내용을 표시한다. 상단에는 실제 소속을 모두 Wrap8/8로 표시하고 연관 카드는 소속1개면 한 행, 2개 이상이면 배지 위/제목 아래8px으로 높이를 늘린다. ‘함께 보면 좋은 콘텐츠’와 범위를 명시한 ‘불러온 목록에 연관 콘텐츠가 없어요.’를 적용하고 미연결 추천을 약속하는 보조 문구는 추가하지 않는다.

- [Figma 조회 원본과 시각](/private/tmp/clipback-detail-alignment-20261017/figma/reference-manifest.json): 2026-10-17 **07:18:07~07:18:13 UTC / 16:18:07~16:18:13 KST**, 컨텍스트에 원본을 포함해3회 성공했다. 별도 스크린샷/메타데이터 재호출·보관본 fallback·누락은0이다.
- 실제 Pretendard·iOS/Android 테마 × 폭320/375px ×1배율의 새 검사16건은 수정 전4통과/12목표 실패를 재현한 뒤 **16통과**했다. [자동 검사](/private/tmp/clipback-detail-alignment-20261017/automatic-checks.json): 관련 **355건**(24.38초)·전체 **987건**(49.71초) 통과, 건너뜀0, `flutter analyze --no-pub` 문제0건(5.25초)이다. 기존 확대/저장 자동 검사를 삭제하거나 건너뛰지 않았다.
- [수정 전 게이트](/private/tmp/clipback-detail-alignment-20261017/before-gate.json) 통과 뒤 제품을 수정했다. 최종 fixture `dafe10b8c3dfd7e0c9f91e31ab07335f7cf293e6813603c5b915b5aa984699a2`와 새 검사 `910d87eb066c9bb083c86b8dc4ed1ebf36b3484bd32f2749a5604ad92632cada`는 전후 동일하다. 초기 무한 폭 JSON 진단·기대색/커버리지 보완 이전의 시도는 `.attempts/`에 보존하고 최종 비교에서 제외했다.
- 양 플랫폼에서 ios 28기록 / android-gesture 28기록, 프레임워크 오류0건이며 `stylePassed`·`layoutPassed`·`behaviorPassed`·`coveragePassed`·`checksCompleted`·전체 `passed: true`다. 각 상태의 스크롤0/고정 위치/최대 스크롤 기록을 합쳐 실제 역할·복수 소속·연관 카드2개와 실제 세로 순서의 누락도 검사했다.
- 펼침/접기·원문 시트/URL/닫기·북마크 상태·분류 변경·연관 제목 스크롤/카드 이동·이전/다음·저장 진입 후 추가 저장 없는 닫기·네 탭·뒤로가기를 합성 포인터로 실제 위젯에서 확인했다. 사진 inline/시트의 원본 bytes·contain·로컬 콜백1회와 캐시 재사용은 **로컬 `onReadAsset` 콜백** 검증이며 실제 HTTP 다운로드나 운영 서버·OAuth·실기기 증거가 아니다.


- 검증 종료 시 [정리 기록](/private/tmp/clipback-detail-alignment-20261017/cleanup-verification.json)으로 양쪽 앱·기기 종료, Android 포워딩 제거·기존 제스처 설정 일치/설정 변경0을 확인했다. 이번 비교 서버는 시작하지 않았다.
- [HTML 정적 검사](/private/tmp/clipback-detail-alignment-20261017/comparison-html-verification.json)의 로컬 참조54개와 JavaScript 문법은 통과했다. 브라우저 자동화는 `kernel assets` 파일 누락으로 초기화에 실패하여 HTML의 브라우저 렌더는 미검증이다. 실제 기기 원본·3열 PNG·네이티브 동작 결과와 구분한다.

- 기존 전역 Pretendard400/500/600 등록은 유지하고 공식1.3.9의 실제 Bold700을 상세 제목 전용 `PretendardDetail` 별칭으로 등록했다. [글꼴 출처/메타데이터](/private/tmp/clipback-detail-alignment-20261017/font-provenance.json)·[원본 에셋/양 플랫폼 번들/슬롯 검사](/private/tmp/clipback-detail-alignment-20261017/static-assets-verification.json)에 원본 back/more/link3개와 재사용 star/chevron의 검증을 기록했다. 라이선스도 번들에 포함했다. 최종 공백 검사에서 공식 라이선스22행의 행 끝 공백1개만 제거했으며, 촬영 번들과의 차이는 이 비표시 공백뿐이고 라이선스 본문·제품 렌더는 동일하다.
- [보존 검사](/private/tmp/clipback-detail-alignment-20261017/preservation-audit.json)에서 공개 생성자6개·사진 원본 controller/view/시트·선정 필터·mapper·공통 테마/배지/태그의 보존을 확인했다. 기존 회귀 검사는 상세 전용 아이콘 selector만 새 에셋에 연결하고 요청/인증/실패 복원·콜백 기대는 유지했다.

[새 비교 8쌍](/private/tmp/clipback-detail-alignment-20261017/comparison-document.html) · [iOS 동작 영상](/private/tmp/clipback-detail-alignment-20261017/ios/after/interaction.mp4) · [Android 동작 영상](/private/tmp/clipback-detail-alignment-20261017/android-gesture/after/interaction.mp4) · [환경 정리](/private/tmp/clipback-detail-alignment-20261017/cleanup-verification.json)

- 현재 연관 선정/순서는 불러온 목록의 같은 첫 카테고리 이름 기준이고, 페이지 표시는 ‘현재 위치 / 불러온 N개’ 의미를 유지한다. 실제 원문은 mapper에서 요약을 재사용하며 원본 링크 콜백은 열람 기록/시트다. F03 미디어 이미지를 구현에 삽입하지 않았다.
- 기존 좌우24px·실제 가용 폭을 사용한다. Figma 제목343px/부모327px의 초과 폭, F02/F04 하단 간격16px과 F03의8px 차이, 실제 원문/미디어/외부 실행·추천 계약과 새 확대 대응은 ‘디자인 확인 필요’로 유지했다. 기존 원본 이미지 컨트롤러/시트·저장 정책·공통 탭/OS 안전 영역은 보존했다.
- 실제 OS 원본을 자르거나 보정하지 않았다. iOS 창393×852/DPR3·상단59/하단34px, Android 창392.7×783.3/DPR2.75·상단24/하단0px이며 본문375px과 실제 viewport559/559.27px를 구분한다. 긴 대역 요약/원문은 Figma 예제와 내용·길이가 다르므로 전체 절대 좌표 일치를 뜻하지 않는다.
- 전문의 고정 위치는 BEFORE 스크롤0에서 보고된 초기 `maxScrollExtent`(sliver 추정값)/2로 정한 **iOS1415.0384615384617px / Android1414.902097902098px**를 전후 그대로 사용한다. 실제 전체 범위의 정확한 중간점이라고 보고하지 않으며 안정화한 최대 스크롤은 runner에서 별도로 기록한다.


## 카테고리 목록 화면의 1배율 맞춤 — 2026-10-17

기준 `36e9725`, Page 1 >261007의 E02(`111:4133`)·E03(`111:4160`)에서 상단/탭/정렬 행·일반 행·미분류 배너의 확정 표현을 적용했다. 원본SVG7개와 역할별 Pretendard를 사용하고 일반 행의 개수만 숨겼으며 실제 서버 집계/더보기 안내·실제 이름/날짜/분류색과 시각/ID/null 정렬을 유지했다. 미분류 배너는 실제 메타데이터 양수에만 표시한다. 설정→기존 관리·마이 진입을 유지하고 관리 복귀 탭/스크롤 보존·계정 세대 변경 초기화를 추가했다.

- [이번 Figma 기록](/private/tmp/clipback-category-archive-20261017/figma/reference-manifest.json): 08:24:09~08:24:15 UTC(17:24:09~17:24:15 KST), E02/E03 컨텍스트+원본2회 성공·누락/fallback0이다.
- 제품 수정 전 실제 앱 테마 누락을 보완하고 동결했다. 초기 빌드/시도는 `.attempts/theme-preflight/`이며 최종 촬영으로 사용하지 않았다. 최종 RED7통과/10목표 실패·예상 밖 실패0과 theme probe1통과 뒤 새 BEFORE4원본/[게이트](/private/tmp/clipback-category-archive-20261017/before-gate.json)를 확보했다. [동결 SHA](/private/tmp/clipback-category-archive-20261017/fixture-manifest.json)는 전후 동일하다.
- [자동 검사](/private/tmp/clipback-category-archive-20261017/automatic-checks.json): 집중72/관련246/전체1,008건 통과·건너뜀/오류0, `flutter analyze --no-pub` 문제0건이다. 실제 `ClipbackApp`에서 관리 복귀/마이 출처/계정 전환/OS뒤로가기4건도 확인했다. 기존 확대·상세·저장 검사를 유지했다. [API/기존 행 보존](/private/tmp/clipback-category-archive-20261017/preservation-audit.json)·[에셋 검사](/private/tmp/clipback-category-archive-20261017/static-assets-verification.json)를 남긴다.
- 완료는 확정된 카테고리 목록1배율이다. 정렬 메뉴/화살표·미선택 탭 굵기 충돌·원본 없는 로딩/오류/전체 빈 상태는 확인 필요로 남겼다. 전체/미분류 콘텐츠 목록·관리 화면 맞춤과 새 확대 대응은 후속이다. API/모델/CRUD·콘텐츠 보존 정책 변경은 없다.

- 첫 AFTER 동작 검사의 하단 ‘아카이브’ 선택자가 같은 이름의 상단 제목을 눌러 검증이 중단됐다. 제품 오류/통과로 처리하지 않고 `.attempts/nav-locator/`에 실패 원본·영상·리포트를 보존했다. 하단 바 내부로 합성 포인터 대상을 한정하는 검증 코드 한 줄만 수정하고, 기준 커밋 소스를 다시 적용해 BEFORE4원본을 새로 촬영한 뒤 동일 도구/데이터로 AFTER를 재검증했다. 렌더링·데이터·목표 판정은 바꾸지 않았으며 최초 성공 검사를 재촬영 결과로 사용하지 않는다.

- 검증 도구의 선택자 보완 후 최종 동결 소스로 전체1,008건과 분석0건을 다시 확인했다. [소스 일치 기록](/private/tmp/clipback-category-archive-20261017/automatic-source-stamps.json)에 실행 전후 제품/프리뷰/검사 SHA256을 남겼다. SDK 캐시 권한으로 시작 전 중단된0건 실행은 시도 로그에 보존하고 테스트 성공으로 합산하지 않았다.

- [최종 양 플랫폼 실측/동작](/private/tmp/clipback-category-archive-20261017/native-validation-summary.json)과 [동일 조건/동결 QA](/private/tmp/clipback-category-archive-20261017/pair-verification.json): 새 BEFORE/AFTER OS원본 각4장·완전3열4쌍, Figma/조건 누락0건이다. 같은 대역 데이터·1배율·키보드0·스크롤0을 유지하며 원본을 자르거나 OS 영역을 보정하지 않았다.
- iPhone16/iOS18.6: 창 Size(393.0, 852.0)·DPR3.0·OS상단59.0/하단34.0px, 30기록·프레임워크 오류0건·style/layout/behavior/coverage/checksCompleted/전체 passed:true다. 실제 키보드 inset336.0→0px, 관리 복귀 탭1·스크롤180.0→180.0px을 확인했다.
- Android13/API33 제스처(AVD `Clipback_Share_API_33`·`sdk_gphone64_arm64`): 창 Size(392.7, 783.3)·DPR2.75·OS상단24.0/하단0.0px, 30기록·프레임워크 오류0건·style/layout/behavior/coverage/checksCompleted/전체 passed:true다. 실제 키보드 inset약274.91→0px, 관리 복귀 탭1·스크롤180.0→180.0px을 확인했다.
- 양 플랫폼에서 미분류0/2 각각 스크롤하며 일반 행12개의 완전 노출·최대 스크롤 마지막 행, 합성 포인터8회 이동의 실제 드래그, 검색/탭 왕복·실제 미분류ID99/일반ID101·관리 복귀, 생성/수정/삭제 시트와 실제 키보드·입력 보존·취소, 메모리콜백 생성/수정/삭제 및 고정 데이터 복원, 저장 진입 후 추가 저장 없는 닫기·네 하단 탭 콜백을 확인했다. 기본1배율의 목록 확인이며 전용 확대/3버튼 촬영은 추가하지 않았다.
- 네이티브 호스트의 관리/다른 화면 이동은 제품 위젯과 Navigator/메모리 대역을 사용한다. 실제 루트 앱의 관리 출처/OS뒤로가기/계정 세대 분리는 별도 ClipbackApp 자동 검사로 확인했다. 합성 포인터·controller 입력/로컬 콜백은 실제 HTTP 저장·OAuth·운영 서버·실기기·원격 CI 증거가 아니다.
- Figma375×812·예시6행과 실제 OS 창/안전 여백·대역12행/이름/날짜/분류색은 다르다. 공통 하단 바의64px+OS여백 정책을 유지하므로 Figma고정96px와 같다고 보고하지 않는다. 확정된 구성요소의 치수·역할·색상/간격을 확인했으며 전체 절대 좌표 일치를 주장하지 않는다.
- [새3열 비교4쌍](/private/tmp/clipback-category-archive-20261017/comparison-document.html) · [비교 QA](/private/tmp/clipback-category-archive-20261017/comparison-qa.json) · [영상 전체 디코딩](/private/tmp/clipback-category-archive-20261017/media-verification.json) · [환경 정리](/private/tmp/clipback-category-archive-20261017/cleanup-verification.json). 초기 실패 자료를 최종 성공 자료로 재사용하지 않았다.
- [iOS AFTER 영상](/private/tmp/clipback-category-archive-20261017/ios/after/interaction.mp4): 39.570000초·[1178, 2556]px, 전체 디코딩 종료코드0/오류로그0바이트·동작 완료까지 녹화 유지 확인.
- [Android AFTER 영상](/private/tmp/clipback-category-archive-20261017/android-gesture/after/interaction.mp4): 81.898311초·[1080, 2220]px, 전체 디코딩 종료코드0/오류로그0바이트·동작 완료까지 녹화 유지 확인.
- 검증 후 앱/기기·이번8767/8768포워딩·서버를 정리했고 Android 탐색/IME와 iOS 키보드 설정을 보존했다. [HTML 참조/문법 검사](/private/tmp/clipback-category-archive-20261017/comparison-html-verification.json)는 정적 검사이며 이번에는 비교HTTP서버·브라우저 상호작용을 실행하지 않았다.


## 카테고리 관리 화면의 1배율 맞춤 — 2026-10-17

`70b2ab1` 기준으로 Page 1 > `261007`의 E04(`111:4569`) 관리 본화면을 맞췄다. 개별 행의 콘텐츠 개수는 사용자 확정으로 숨기며 상단 총수·서버 메타데이터·더보기의 실제 개수와 기존 삭제 안내는 유지한다. 완료는 관리 본화면의1배율이며 생성/수정/삭제 시트의 디자인·전체/미분류 콘텐츠 목록·새 확대 대응은 후속이다.

- [이번 Figma 조회](/private/tmp/clipback-category-management-20261017/figma/reference-manifest.json): **2026-10-17 09:29:08~09:29:13 UTC /18:29:08~18:29:13 KST**, E04 컨텍스트+375×812 원본1회 성공·별도 메타데이터/스크린샷 재호출·fallback/누락0이다. 다른 파일/노드나 이전 기기 이미지를 대체 원본으로 사용하지 않았다.
- 제품 변경은 CategoryManagementScreen 한 파일이다. 헤더64px·뒤로가기 원본24px/보이는 좌16px·제목 간격8px/시작48px을 맞추고 기존48px 터치 영역은 유지했다. 제목은 공통 AppText.sectionTitle을 재사용해 Pretendard18/SemiBold/−0.45/검정/AUTO다. 추가 버튼은 헤더에서52px 개수 행 오른쪽으로 옮겨 원본24px·보이는 우16px·기존48px 터치를 유지한다. 개수는 Pretendard14/Medium/−0.35/#767676/AUTO로 표시한다.
- 검증된 CategoryRow의 archiveStyle:true를 재사용해44px 행·행 사이16px·좌16/우6px·폴더40×34px·글자 앞12px·텍스트 최대156px·이름/날짜2px·더보기44px/원24px을 유지한다. 이름15/Medium/−0.375/#1A1A1A·날짜12/Regular/−0.3/#B5BDC3의 AUTO/한 줄 말줄임을 사용한다. 실제 이름/색/날짜 없음 문구·작업 중 안내/잠금은 보존하고 관리 행에는 새 탭 이동을 추가하지 않는다.
- 총 N은 전달된 목록에서 미분류를 제외한 카테고리 수이며 콘텐츠 수 합계나 새 전체 계정 집계가 아니다. 입력 순서를 그대로 사용하고 아카이브 최신순을 관리에 적용하지 않는다. 기존0개 표현을 유지하며 미조회/로딩/오류/빈 상태의 새 디자인은 만들지 않았다. 하단은 기존 SafeArea에서 실제 여백을 한 번 적용한다. 목록의 ValueKey는 측정용이며 관리 자체의 새 위치 복원/영속 저장을 추가하지 않는다.
- [원본 SVG/로컬/번들/실제 슬롯 검사](/private/tmp/clipback-category-management-20261017/static-assets-verification.json): back=detail-back24·add=archive-folder-plus24·folder=archive-category-folder40×34·more=archive-category-more19.2×18.4 네 원본이 기존 로컬 파일과 동일하여 새 에셋/등록 변경0이다. 폴더6색의 같은 도형을 확인했고 실제 분류색만 적용하며 나머지는 원색 무필터로 재사용했다. 전체 Figma 이미지/임시URL을 제품에 사용하지 않았다.
- [수정 전 게이트](/private/tmp/clipback-category-management-20261017/before-gate.json)로 새 OS원본2개·실제 테마·1배율/스크롤0/키보드0·제품 기준 소스를 확인한 뒤 수정했다. [동결 소스](/private/tmp/clipback-category-management-20261017/fixture-manifest.json)의 새 프리뷰 `cd3e21abdd8ff95a2d35a17977fa2776ea04ef4d6a1c6271017bfd37cea1c15b`·집중 검사 `6bdcf9647792fe87d2eec37631192a3e29037924142ae857f38bd9e7b1352913`와 기존 선택자 호환4파일은 전후 동일하다. 최종 RED47건=11통과/36목표 차이·예상 밖 실패0이다. 초기 프리플라이트 보완 전 시도를 최종 성공으로 사용하지 않는다.
- [이번 자동 검사](/private/tmp/clipback-category-management-20261017/automatic-checks.json): 집중 **119건**(14.64초), 관련 **216건**(17.31초), 전체 **1055건**(51.58초) 통과·건너뜀/오류0, flutter analyze --no-pub 문제0건(4.29초)이다. 집중 검사는 iOS/Android×폭320/375px×1배율×하단0/34/48px×카테고리0/1/12개와 실제 문단/아이콘/터치 경계를 확인했다. 기존 확대/삭제/저장/시트/복귀 검사를 삭제하거나 건너뛰지 않았다.
- [보존 감사](/private/tmp/clipback-category-management-20261017/preservation-audit.json)로 공개 생성자/콜백·미분류 제외/입력순서·액션의 실제 서버 개수 전달, 공통 행 기본값/아카이브 외형·API/모델/Repository/App 복귀·기존 에셋을 확인했다. 기존 회귀4파일은 새 키를 우선하고 구 선택자를 fallback으로 쓰도록 보완했으며 동작 기대는 유지했다.
- iPhone16/iOS18.6: 창Size(393.0, 852.0)·DPR3.0·OS상단59.0/하단34.0px, **20기록·프레임워크 오류0건·style/layout/behavior/coverage/checksCompleted/전체 passed:true**다. 실제 키보드 inset 약336.00→0px과 입력/컨트롤러·목록 보존을 확인했다.
- Android13/API33 제스처(AVD Clipback_Share_API_33·sdk_gphone64_arm64): 창Size(392.7, 783.3)·DPR2.75·OS상단24.0/하단0.0px, **20기록·프레임워크 오류0건·style/layout/behavior/coverage/checksCompleted/전체 passed:true**다. 실제 키보드 inset 약274.91→0px과 입력/컨트롤러·목록 보존을 확인했다.
- [네이티브 실측/동작](/private/tmp/clipback-category-management-20261017/native-validation-summary.json)·[독립 동일 조건 QA](/private/tmp/clipback-category-management-20261017/pair-verification.json): 스크롤하며12행을 모두 완전히 노출하고 입력 순서/최대 위치의 마지막 행·하단 여백·합성 포인터8회 실제 드래그를 확인했다. 추가/수정/삭제 취소와 실제 로컬 콜백1회씩·총수/이름/색의 재렌더·원본 콘텐츠/메타데이터 복원, 뒤로가기/재진입을 검증했다. 네이티브 호스트는 직접 reactive 렌더이고 실제 ClipbackApp의 진입 출처/모달 우선 OS뒤로가기/아카이브 탭·위치/계정 전환 분리는 별도 자동 검사다.
- 고정12개 대역/합성 포인터·controller 입력·메모리 CRUD를 실제 HTTP/영속 저장·OAuth·운영 서버·실기기·원격 CI 증거로 확대하지 않는다. 실제 OS 창/하단 여백과 Figma375×812·예시6개/이름/색/날짜는 다르며 전체 절대 좌표 일치를 주장하지 않는다. 원본을 자르거나 OS 안전 영역을 보정하지 않았다.
- [새 비교2쌍](/private/tmp/clipback-category-management-20261017/comparison-document.html)·[비교 QA](/private/tmp/clipback-category-management-20261017/comparison-qa.json): BEFORE/AFTER 새 OS원본 각2장·완전3열2쌍·Figma/조건 누락0이다. [HTML 검사](/private/tmp/clipback-category-management-20261017/comparison-html-verification.json)는 참조/문법 정적 검사이며 브라우저/비교HTTP서버는 실행하지 않았다.
- [iOS AFTER 영상](/private/tmp/clipback-category-management-20261017/ios/after/interaction.mp4): 28.966667초·[1178, 2556]px, 전체 디코딩 종료코드0/오류로그0바이트·동작 완료까지 녹화 유지 확인.
- [Android AFTER 영상](/private/tmp/clipback-category-management-20261017/android-gesture/after/interaction.mp4): 60.700344초·[1080, 2220]px, 전체 디코딩 종료코드0/오류로그0바이트·동작 완료까지 녹화 유지 확인.
- [환경 정리](/private/tmp/clipback-category-management-20261017/cleanup-verification.json): 사용한 앱/기기·포워딩/임시 서버를 정리하고 탐색/키보드 설정과 기기 데이터를 보존했다. 이전 검증 기록은 당시 근거로 유지한다.


## 카테고리 관리 시트와 삭제 팝업의 1배율 맞춤 — 2026-10-17

`886cdea` 기준으로 Page 1 > `261007`의 E08 더보기(`111:4236`)·E09 추가 전(`111:4287`)·E10 추가 입력(`111:4376`)·E11 수정(`111:4427`)·E12 삭제 확인(`111:4484`)의 시트·팝업 본체1배율을 적용했다. 아카이브와 관리의 기존 두 진입을 유지하며 배경 딤/블러 맞춤·자유 색상 선택기·새 확대 맞춤은 후속이다.

- [이번 Figma 원본/컨텍스트](/private/tmp/clipback-category-sheets-20261017/figma/reference-manifest.json): **2026-10-17 10:26:57~10:27:04 UTC /19:26:57~19:27:04 KST**, 5개 모두 성공했다. 구현 에셋 확인용 읽기를 총3회(하위 메타데이터1회·하위 컨텍스트1회·읽기 전용 원본 PNG 내보내기1회) 추가했으며 Figma 노드는 수정하지 않았다. planning 원본/이전 기기 캡처를 이번 비교로 대체하지 않았다.
- 더보기는 핸들50×5/상단8px·헤더 간격16px·폴더40×34px/글자 앞12px·이름15/Medium/−0.375·개수12/Regular/−0.3/문단 사이2px·텍스트 최대156px을 적용했다. 구분 영역 앞뒤16px/높이8px·옵션44px/아이콘20px/앞8px/16Medium−0.4·마지막32px+실제OS하단여백 한 번이다. 정상 본체223px이며 긴 실제 개수는 헤더/본문이 필요한 높이를 늘린다.
- 추가/수정은 기본 본문428px+max(키보드 inset,OS viewPadding)를 실제 top-safe 가용 높이로 제한하고 본문 스크롤과 CTA48px/좌우16px/아래32px을 분리했다. 폴더121×103px/시작60px·입력 앞32px·밑줄 앞8px/높이1px·팔레트 앞32px이다. 안내18/Medium·입력18/SemiBold/−0.45·버튼15/SemiBold/−0.375의 Pretendard/AUTO를 명시했다. Figma 키보드277px이나375px 폭을 OS 창에 강제하지 않는다.
- 삭제는 최대311px/화면 좌우 최소32px·내부 좌우16/상하32px/R16·경고32px 안 원본24px·간격8/8/36px·버튼44px/사이8px을 적용했다. 제목18SemiBold−0.45/AUTO, 본문14Medium−0.35/1.6, 버튼14SemiBold/22px을 명시한다. 실제 이름과 기존 콘텐츠 보존 안내, 중앙 배치와 자연 높이를 유지하고 매우 긴 내용은 실제 viewport 안에서 스크롤한다. Figma top200px/높이279px·콘텐츠 동반 삭제 문구를 적용하지 않았다.
- 사용자 확정 예외: 기존8색 RGB·기존 초기색·무지개 버튼의 고정 코랄 #FF6F61 선택 동작을 유지한다. E09 원본의 무지개 버튼 유무 및 팔레트 색상 차이, E12 보존 문구/자연 높이·중앙 위치, 기존 배경 효과를 전체 원본과 완전 일치로 보고하지 않는다. 실제 자유 색상 선택기는 구현하지 않았다.
- [원본/번들/실제 에셋 검사](/private/tmp/clipback-category-sheets-20261017/static-assets-verification.json): 기존 폴더2역할을 재사용하고 편집20/삭제20/경고24/선택 원30/밑줄327×1의 정확한 원본 SVG5개와 무지개 원본 노드38×32의 PNG1개를 등록했다. PNG는 SVG foreignObject 지원 문제 때문에 원본 노드를 scale3(114×96)로 내보낸 에셋이며 화면 캡처를 자른 이미지가 아니다. 선택 원은 원본 붉은색만 실제 선택색으로 치환하고 흰 체크를 보존한다. 밑줄은 실제 가용 폭/1px이며 원본 문서는 보존한다. 임시 URL/전체 화면 이미지를 제품에 쓰지 않았다.
- [보존 감사](/private/tmp/clipback-category-sheets-20261017/preservation-audit.json): 공개 생성자/필드·더보기 종료 후 수정/삭제를 여는 순서·콜백 인수·실제 ID/집계·추가/수정 payload·콘텐츠 분류 변경 UI·API/모델/App/전역 위젯을 보존했다. 기존 trim/공백 차단·자동 포커스·콜백 후 닫기를 유지하고 버튼/IME 연속 제출을 한 번으로 제한하는 폼 내부 가드만 추가했다. 기존 실패 처리를 새로운 폼 유지/재시도 정책으로 바꾸지 않았다.
- [새 BEFORE 게이트](/private/tmp/clipback-category-sheets-20261017/before-gate.json)·[동결 소스](/private/tmp/clipback-category-sheets-20261017/fixture-manifest.json): 제품 수정 전에 새로운 OS원본10장을 확보했다. 검사/프리뷰는 전후 동일하며 목표치 실패와 캡처 가능 여부를 분리했다. 초기 프리플라이트/수정 전 차이를 최종 성공으로 쓰지 않는다.
- [제품 변경 전 재현](/private/tmp/clipback-category-sheets-20261017/focused-before-summary.json): 같은56검사에서 14통과·42예상 실패, 예상 밖0건이었다. 입력 자동화의 중복 재탭/고정 포인터 시각을 고친 최종 동결 소스로 양 플랫폼 BEFORE를 다시 빌드·촬영했고, 편집 메뉴가 있던 선행 iOS 시도는 canonical 비교에서 제외했다. [입력 보조 교정](/private/tmp/clipback-category-sheets-20261017/input-helper-correction.json)은 제품·데이터·판정 기준을 바꾸지 않았다.
- [이번 자동 검사](/private/tmp/clipback-category-sheets-20261017/automatic-checks.json): 집중 **175/175**(19.21초), 관련 **216/216**(20.28초), 전체 **1111/1111**(62.99초), flutter analyze --no-pub **문제0건**(4.42초)이다. 건너뜀/오류0이며 기존 확대/카테고리 삭제/콘텐츠 보존/저장/상세/루트 앱 복귀·계정 분리 검사를 유지했다.
- 실제 Pretendard·iOS/Android×폭320/375px×1배율의5상태를 검사하고, 별도 하단0/34/48px×키보드0/300px·짧은 화면 cap/본문 스크롤·긴 이름/개수·빈값/trim·버튼/IME 중복·팔레트 밖 초기색/고정 코랄·두 진입·취소/복귀를 확인했다. 실제 RenderParagraph/RenderEditable와 에셋/paint viewport를 측정하고 논리 콘텐츠·의도한 말줄임/스크롤 밖 내용과 실제 잘림을 구분했다.
- 범위 밖 정적 재현: iOS 테마 폭375px·높이568px·OS하단48px·키보드300px에서 배경 CategoryArchiveView의 Column(category_widgets.dart:333)이35px 넘쳤다. [진단 원문](/private/tmp/clipback-category-sheets-20261017/shortcap-diagnostic.log)을 보존하고 목록은 변경하지 않았다. 폼 cap 단위 검사는 같은 실제 modal route를 여는 단순 호스트로 분리해 오류를 무시하지 않고 시트 자체를 검사한다. 일반 native 기기의 실제 목록/관리 배경 검증과 이 단위 호스트 검사를 구분한다.
- iPhone16/iOS18.6: 창Size(393.0, 852.0)·DPR3.0·OS상단59.0/하단34.0px·42기록, **style/layout/behavior/coverage/checksCompleted/전체 passed:true·프레임워크 오류0건**이다. 5상태의 실제 IME와 경계는 [이번 native 결과](/private/tmp/clipback-category-sheets-20261017/native-validation-summary.json)를 따른다.
- Android13/API33 제스처: 창Size(392.7, 783.3)·DPR2.75·OS상단24.0/하단0.0px·42기록, **style/layout/behavior/coverage/checksCompleted/전체 passed:true·프레임워크 오류0건**이다. 5상태의 실제 IME와 경계는 [이번 native 결과](/private/tmp/clipback-category-sheets-20261017/native-validation-summary.json)를 따른다.
- [새 비교10쌍](/private/tmp/clipback-category-sheets-20261017/comparison-document.html)·[독립 동일 조건 QA](/private/tmp/clipback-category-sheets-20261017/pair-verification.json): 플랫폼별 같은 데이터/1배율/상태/스크롤의 변경 전→후→Figma다. 추가/수정3상태는 실제 IME 양수, 더보기/삭제2상태는 IME0으로 촬영했다. 고정 일반2개+미분류/실제 집계37·콘텐츠2개와 Figma 예시 데이터·OS 창/키보드/안전 영역 차이를 표시했다. 원본 자르기·OS 보정·대체 디자인은 없다.
- 합성 포인터와 controller 입력·실제 native IME·메모리 콜백으로 추가/수정/삭제/취소·팔레트 드래그·입력/색/컨트롤러·다른 카테고리/마지막 미분류 이동·콘텐츠 ID/북마크 보존과 두 진입 복귀를 확인했다. 호스트 초기화는 로컬 대역 복원이며 실제 HTTP/영속 저장/운영 서버/OAuth/실기기/원격 CI 검증이 아니다. 실제 루트 앱의 복귀/계정 분리는 별도 자동 회귀다.
- [iOS AFTER 영상](/private/tmp/clipback-category-sheets-20261017/ios/after/interaction.mp4): 47.121667초·[1178, 2556]px, 전체 decode 종료0/오류로그0바이트·모든 행동 종료까지 녹화 유지 확인.
- [Android AFTER 영상](/private/tmp/clipback-category-sheets-20261017/android-gesture/after/interaction.mp4): 104.463422초·[1080, 2220]px, 전체 decode 종료0/오류로그0바이트·모든 행동 종료까지 녹화 유지 확인.
- [HTML 참조/문법 검사](/private/tmp/clipback-category-sheets-20261017/comparison-html-verification.json)는 정적 검사이며 브라우저·비교HTTP서버를 실행하지 않았다. [환경 정리](/private/tmp/clipback-category-sheets-20261017/cleanup-verification.json)로 이번 앱/기기·포워딩·임시 서버를 정리하고 탐색/IME 설정을 보존했다. 과거 기록은 당시 근거로 유지한다.

실제 고정 데이터의 표면 경계 실측(logical px, 소수 둘째 자리 반올림):

| 플랫폼·상태 | 표면 높이 변경 전 → 후 | 핵심 거리 변경 전 → 후 | 실제 IME |
| --- | --- | --- | --- |
| iOS E08 | 240→257 | 마지막 옵션 아래 58→66; 구분 영역 1→8 | 0 |
| iOS E09·E10·E11 | 741.24→764 | 키보드 위 버튼 여백 9.24→32 | 336 |
| iOS E12 | 286→301 | 버튼 48→44; 본문–버튼 18→36 | 0 |
| Android 제스처 E08 | 207→223 | 마지막 옵션 아래 24→32; 구분 영역 1→8 | 0 |
| Android 제스처 E09·E10·E11 | 681.45→702.91 | 키보드 위 버튼 여백 10.54→32 | 274.91 |
| Android 제스처 E12 | 290→301 | 버튼 48→44; 본문–버튼 18→36 | 0 |

더보기·폼의 실제 표면 폭은 양 플랫폼375px, 삭제 표면 폭은311px이다. 폼 표면 높이는 실제 IME 자리를 포함하며 이를 뺀 본문 기준은428px이다. 삭제 높이301px은 이 이름·보존 문구의 자연 높이 실측이며 고정 높이를 추가한 값이 아니다. 전체 경계·원본은 위 비교/상태 JSON을 따른다.


## 아카이브 전체보기의 1배율 맞춤 — 2026-10-17

`35c3f5b` 기준으로 Page 1 > `261007`의 E01(`111:4117`) 정상 전체보기 상단·탭·정렬/개수 행과 콘텐츠 카드를 적용·검증했다. 사용자 기준으로 실제 복수 소속을 모두 순서대로 보이며 긴 이름은 한 줄 말줄임, 줄이 늘면 카드 높이를 늘린다. 미분류 콘텐츠 목록·원본 없는 빈/로딩/오류 상태·새 확대 맞춤은 이번 완료 범위가 아니다.

- [이번 Figma 원본/컨텍스트](/private/tmp/clipback-archive-all-20261017/figma/reference-index.json): **2026-10-17 12:02:39 UTC /21:02:39 KST**에 E01 컨텍스트와 원본을 한 번 조회했다. 프레임은375×1102px, MCP PNG 원본은349×1024px이다. 누락/fallback0이며 원본을 늘리거나 스크롤별 대체 디자인을 만들지 않는다.
- 루트 전체보기에서 검증된 공통 카테고리 헤더64px·탭 외부64px/내부52px을 재사용하고 정렬/개수 행을52px로 맞췄다. 제목18SemiBold−0.45/검정, 탭16SemiBold−0.4, 정렬/개수14Medium−0.35/#767676의 Pretendard/AUTO다. 미선택 탭은 충돌하는 원본 기준을 임의 확정하지 않고 기존600을 유지한다.
- 한 행 카드는173px·좌우/상하16px이며 배지 영역은 최소22px/폭=카드−116px이다. Wrap8/8에 실제 `content.categories`의 이름·순서·tint/deep 색을 보존하고 긴 이름은 한 줄 말줄임한다. 추가 Wrap 높이만큼111px 본문 묶음을 함께 내린다. 제목16SemiBold/1.4·한 줄/최대폭min(311,카드−40), 요약15Regular/1.6·최대 두 줄/말줄임, 날짜14Regular/AUTO·아래16px을 적용한다.
- 원본 북마크28px·더보기24px을 시각 간격16px/오른쪽16px로 배치하고 각28px 탭 영역을 카드 전체 Stack 안에 둔다.22px 헤더 밖의 탭 영역이 잘리지 않도록 분리했으며 작업 중 잠금과 상태 안내를 유지한다. 구분선은 원본0.5px·실제 가용 폭이며 한 행 카드의 y127.5~128px에 표시한다. Figma의4px 슬롯과 실제 선 두께를 혼동하지 않는다.
- [원본/등록 감사](/private/tmp/clipback-archive-all-20261017/static-assets-verification.json): 검색1개는 기존 파일과 byte 동일, 설정/비선택 별2개는 기하/색이 같고 내부 clip ID 또는 XML 속성 순서만 달라 재사용했다. 선택 별·정렬 화살표·회색 더보기·구분선4개는 E01 원본 SVG를 그대로 등록했다. 모두 원색 무필터로 사용하고 전역 별/더보기 에셋을 덮어쓰지 않았다. 새 AFTER APK·iOS App.framework의7역할은 로컬 바이트/SHA·SVG root 크기와 일치했다. 원본과 byte 동일한5역할/비시각 XML만 다른2역할을 구분했다. 양 플랫폼 새 OS원본4장과 실제 SVG36회 관측에서 검색/설정24px·화살표16px·별28px·더보기24px·선335×0.5px 및 무필터를 확인했고 누락/불일치0이다. 양 기기의 실제 카드 폭은375px이며320px은 자동 검사 범위다.
- [보존 감사](/private/tmp/clipback-archive-all-20261017/preservation-audit.json): 기존 공유 카드 기본 본문과 정렬 팝업을 보존하고 표현 옵션 `archiveAllStyle=false`의 기본값은 유지한다. 검색·즐겨찾기·카테고리/미분류 목록에는 새 E01 표현을 적용하지 않는다. API/모델/Repository/FeedPage/루트 복귀·계정 정책과 기존 필수 생성 인수·콜백은 그대로다. API 목록의 개수는 ‘불러온 N개’이며 전체 통계999와 구별한다.
- [변경 전 게이트](/private/tmp/clipback-archive-all-20261017/before-gate.json): 제품 수정 전 같은6개 콘텐츠·1배율·키보드0·실제 스크롤0/300px의 새 OS원본을 플랫폼별2장씩 확보했다. [동결 프리뷰](/private/tmp/clipback-archive-all-20261017/fixture-manifest.json)의 canonical SHA는 `86d7babbdb13d5ff6eef5dcc548ba213001ea3b3ff06a6e8cdc1f47bfd5c0e12`다. 같은14개 집중 RED는5통과/9목표 차이이며 과거 검증을 이번 성공으로 사용하지 않는다.
- 선행 iOS 시도는 기존 native 공유 대기 안내가 헤더를 가려 비교에서 제외하고 [.attempts 진단](/private/tmp/clipback-archive-all-20261017/.attempts/native-pending-share-ios/attempt.json)에 원본을 보존했다. canonical 대역은 native 공유 채널을 메모리로 격리했으며 제품 공유 API/서비스는 변경하지 않았다. 초기 앱은 기존 native 공유 상태를 읽어 배너를 표시했다. mock 공유 자격 요청까지 확인됐지만 native 호출 완료 추적이 없어 실제 publish 완료 여부는 확인할 수 없다. 진단을 위해 기존 큐·자격 내용은 별도로 조회·출력·삭제하지 않았으며 자격 정보를 추정해 복원하지 않았다. 이후 canonical 채널 격리에서는 네이티브 위임0 계약을 적용했다.
- [이번 자동 검사](/private/tmp/clipback-archive-all-20261017/automatic-checks.json): 집중 **26/26**(5.420초), 관련 **309/309**(24.670초), 프리뷰 공유 격리 계약 **3/3**(2.576초), 전체 **1141/1141**(76.907초) 통과·건너뜀/오류0, `flutter analyze --no-pub` **문제0건**(3.1초)이다. 전체 검사 후 사용하지 않는 import 한 줄만 제거하고 최종 분석을 다시 통과했으며 런타임 로직은 바뀌지 않았다. 기존 확대·저장·페이지/복귀·분류/삭제 검사를 유지한다.
- 집중 검사는 실제 Pretendard·iOS/Android×폭320/375px×1배율의 글자/7역할 SVG·복수 배지/긴 이름·metadata 누락 ID와 빈 소속 fallback·기본 공유 카드 보존을 확인했다. 별도12개 회귀로 작업 중 잠금과28px 버튼의 중심/위1px/아래1px 탭을 확인하고, 공유 격리3개는 검증 도구가 기존 native 큐/자격 저장소를 읽거나 쓰지 않는 계약을 검사했다. AFTER 양 플랫폼 실행과 새 비교4쌍/영상2개·환경 정리도 아래 실제 결과로 확인했다. 자동 검사와 네이티브 실행 근거를 구분한다.
- 기기 프리뷰는 실제 ClipbackApp·API/Repository/ViewModel/복귀 동선에 in-process MockClient와 메모리 세션을 연결한다. 합성 포인터/controller·native IME 검증을 외부 HTTP·실제 OAuth·영속 저장·운영 서버·실기기·원격 CI 성공으로 보고하지 않는다.

- [양 플랫폼 실측/동작](/private/tmp/clipback-archive-all-20261017/native-validation-summary.json): iPhone16/iOS18.6은 창393×852px·DPR3·OS상단59/하단34px, Android13/API33 제스처(Clipback_Share_API_33, sdk_gphone64_arm64)는 창392.73×783.27px·DPR2.75·OS상단24/하단0px이다. 각 **33기록·style/layout/behavior/coverage/checksCompleted/전체 passed:true·프레임워크 오류0건**을 확인했다. 촬영4상태는 모두 실제1배율/IME0/스크롤0 또는300px이다.
- 실제 루트 앱에서 관리/검색/상세/카테고리 탭 왕복 후 전체보기 탭0·같은 FeedPage/버전/ID 순서·스크롤300px을 보존했다. 합성 포인터8회 이동의 실제 드래그, 최대 위치의 마지막 행과6행 모두 완전 노출, 북마크 PUT/복원, 더보기 열기/취소, 저장 진입/추가 저장 없는 닫기, 기존 최신순↔북마크 우선의 서버 대역 조회/순서·스크롤 초기화를 확인했다.
- [시점별 데이터/동일 조건 QA](/private/tmp/clipback-archive-all-20261017/pair-verification.json)는 복사된 `bookmarkedIds`/`rows.bookmarked`의 `[601,602]→[602]` 전이와 PUT2회, 실행 중 즉시 요구 조건·최종 원본 데이터 복원을 대조했다(ID 접두어는 `api-`). `snapshot.serverRecords`는 mutable list 참조이므로 과거 북마크 상태의 증거로 사용하지 않고 최종/정적 보존 확인에만 사용했다.
- 실제 전 행 방문 후 `maximum_scroll` 기록의 끝 위치는 iOS661.00px·Android660.73px이다. 최종 정렬 후 snapshot의 `maxScrollExtent`는 가변 높이 sliver의 지연 추정값이므로 이 실측 대신 사용하지 않는다. 부분 노출/cache 행과 완전 노출을 구별했고 배지2줄/3줄에서 본문·선·날짜가 함께 내려갔다.
- [새 변경 전 → 변경 후 → Figma 비교4쌍](/private/tmp/clipback-archive-all-20261017/comparison-document.html)·[비교 QA](/private/tmp/clipback-archive-all-20261017/comparison-qa.json): BEFORE 원본4장 불변, 동결 fixture/최종 빌드 소스 일치, 조건 불일치/원본 누락/팝업/대상 잘림0이다. [iOS 두 스크롤 비교](/private/tmp/clipback-archive-all-20261017/comparisons/ios-comparison-overview.png)·[Android 두 스크롤 비교](/private/tmp/clipback-archive-all-20261017/comparisons/android-gesture-comparison-overview.png)를 함께 제공한다.
- Figma375×1102px의 예제 이름/색/총6개·한 개 배지와 실제6개 대역/복수 소속·‘불러온6개’, OS 창/안전 영역은 다르다. 기존 공통 하단64px+실제 OS 여백을 유지해 Figma고정96px과 전체 좌표 일치를 주장하지 않는다. 원본을 자르거나 OS를 보정하지 않았고 스크롤300용/복수 소속용 대체 Figma를 만들지 않았다.
- [iOS AFTER 영상](/private/tmp/clipback-archive-all-20261017/ios/after/interaction.mp4): **22.688333초·1178×2556px**. [Android AFTER 영상](/private/tmp/clipback-archive-all-20261017/android-gesture/after/interaction.mp4): **33.047200초·1080×2220px**. [전체 디코딩 검사](/private/tmp/clipback-archive-all-20261017/media-verification.json)는2개 모두 종료0/오류로그0바이트이며 동작 완료까지 녹화를 유지했다.
- [환경 정리](/private/tmp/clipback-archive-all-20261017/cleanup-verification.json): 사용 앱 종료·기기 shutdown·이번 포워딩 제거·영상 종료를 확인하고 기기 데이터를 보존했다. 탐색/키보드 설정 변경0, Android 제스처 원상태와 iOS 키보드 원상태를 확인했다. [HTML 참조/문법 검사](/private/tmp/clipback-archive-all-20261017/comparison-html-verification.json)는4조건/원본12참조를 정적으로 검사한 결과이며 브라우저·비교HTTP서버는 실행하지 않았다. 새3버튼/확대 기기 촬영·운영 검증은 수행하지 않았다.

이번 고정 데이터의 실제 경계(logical px):

| 항목 | 변경 전 → 변경 후 | 확인 범위 |
| --- | --- | --- |
| 탭 외부/내부 높이 | 52/52 → 64/52 | 양 플랫폼·스크롤0 |
| 정렬/개수 행 높이 | 56 → 52 | 양 플랫폼 |
| 목록 viewport 시작 | iOS239 →239, Android204 →204 | 기존8px 분리 여백을 포함한 합계 높이 보존 |
| 한 행 카드/Wrap | 173/기존 첫 배지25 →173/22 | 소속1개·같은 줄의2개·긴 이름·미분류 fallback |
| 3개 소속 카드/Wrap | 173/첫 배지25 →203/52 | 실제2줄·본문/선/날짜+30px |
| 6개 소속 카드/Wrap | 173/첫 배지25 →233/82 | 실제3줄·본문/선/날짜+60px |
| 제목 폭/선 두께 | 335/1 →311/0.5 | 실제 카드375px·요약48px/최대2줄 유지 |
| 날짜 아래 여백 | 16 →16 | 전후/양 플랫폼 |

전체보기 정상 목록의 승인 범위만 완료다. 미선택 탭 굵기 확정·미분류 콘텐츠 화면·빈/로딩/오류의 새 디자인·시트 배경/자유 색상 선택·새 확대 맞춤은 보류한다. 과거 검사·촬영 결과는 이번 결과로 바꾸지 않는다.

## Figma 미분류 콘텐츠 목록·확인된 빈 상태1배율 — 2026-10-17

`9fce418` 기준으로 Page 1 > `261007`의 [E06 정상 미분류 목록](https://www.figma.com/design/svNWsTFh8Ws1Mpt8XQIcrN/?node-id=111-4525) (`111:4525`)·[확인된 빈 미분류](https://www.figma.com/design/svNWsTFh8Ws1Mpt8XQIcrN/?node-id=142-5097) (`142:5097`)의 **1배율 승인 영역**을 적용·검증했다. 다른 화면 전체와 새 확대 맞춤 완료를 뜻하지 않는다.

### 적용 범위와 유지한 정책

- 사용자 확정으로 미분류에서만 정렬/개수 행과 랜덤 보기 진입을 숨기고 설정을 기존 카테고리 관리로 연결했다. 기존 선택 정렬과 서버 조회·일반 카테고리의 정렬/랜덤 보기·뒤로의 카테고리 탭 복귀는 유지한다.
- 상단64px/좌우16px·뒤로/검색/설정24px·제목18 SemiBold/자간−0.45/검정/AUTO·아이콘 중심32.5px을 적용했다. 정상 첫 카드만 헤더 아래12px, 카드 사이8px이다. 기존 전체보기의 정렬된 카드 본문/아이콘을 재사용하고 미분류 시스템 배지만 표시용 ‘미분류’/57×22px/회색으로 바꿨다. 실제 ID·전체 소속/순서·제목/요약/날짜와 카드 동작은 보존한다.
- 실제 미분류 metadata ID와 현재 피드 필터가 일치하고, 조회 완료·오류/로딩/다음 페이지 없음·현재 items0인 경우에만 빈 원본을 표시한다. 전체 저장0이나 집계 누락으로 오판하지 않는다. 새 상자86×100px과 원본 크롭·기존 Pretendard Bold 별칭/24px 제목·16px 본문·16/8px 간격·CTA 없음, 본문 중앙−84px/본문 안 제한과 자연 높이 스크롤을 적용했다. 빈 본문에는 목록의12px을 더하지 않는다.
- [보존 감사](/private/tmp/clipback-unclassified-20261017/preservation-audit.json): 필수 생성 인수·콜백·REST/API·모델·Repository/ViewModel/App·공통 EmptyState/하단 바·네이티브 설정·기존 에셋/폰트를 보존했다. 공유 카드의 새 선택 옵션 기본값은 꺼짐이며 E01과 일반 카테고리/검색/즐겨찾기 기본 표현은 유지한다. 관리/검색/상세 단순 왕복은 기존 필터/위치를 유지하고, 분류 변경 성공 후 재조회는 기존처럼 위치0으로 초기화한다.

### 원본·재현·최종 검사

- [이번 Figma 컨텍스트/원본](/private/tmp/clipback-unclassified-20261017/figma/reference-index.json): **2026-10-17 13:07:48 UTC /22:07:48 KST**에 두 노드를 각각1회 조회해 컨텍스트와375×812 PNG를 확보했다. MCP2호출이며 별도 메타데이터/스크린샷 호출·fallback·대체 디자인은 없다. 정적 에셋10개는 반환 URL에서 별도로 내려받았다.
- [에셋/번들/실제 렌더 감사](/private/tmp/clipback-unclassified-20261017/static-assets-verification.json): 원본SVG9건 중6건은 byte동일, 설정2건의clip ID와 별1건의XML 속성 순서만 다른3건은 시각 구조가 동일하다. 새1254×1254 PNG는 원본 byte 그대로 등록했으며 홈의71×82 이미지를 대체 사용하지 않았다. 선택 별은 E01의 기존 확정 에셋을 재사용한다. 최종APK/Runner8역할의 원본/등록/바이트·기하·무필터와 실제6상태 관측을 재확인했다. 그림자의 alpha 효과와 원색 주 이미지를 구분한다.
- [새 변경 전 게이트](/private/tmp/clipback-unclassified-20261017/before-gate.json): 제품 수정 전 **새 canonical OS원본6장**을 확보했다. [동결 소스](/private/tmp/clipback-unclassified-20261017/fixture-manifest.json)의 fixture SHA는 `8e686531978ff0ab84f6f65f4a390cf663f011289f3546ff6249e648d96f7e86`이며 전후 동일하다. 실제 앱/메모리 API 대역의 미분류99·8개4+4페이지와 마지막1건 분류→확인0/다른 콘텐츠 보존을 사용했다.
- 초기28건은7통과/예상 목표차이21·예상밖0으로 재현했다. [이번 자동 검사](/private/tmp/clipback-unclassified-20261017/automatic-checks.json): 집중 **28/28**(6.864초), 관련 **451/451**(36.148초), 전체 **1169/1169**(93.141초) 통과·실패/건너뜀0이며 `flutter analyze --no-pub` **문제0건**이다. 기존 확대 자동 검사를 유지했다. 최종 전체 검사와 분석은 계측 교정 후 다시 실행했다. 별도 외부 진단2건은375×360/1배율의 iOS/Android에서250px 자연 그룹을139/208px 본문 안에서 끝까지 스크롤해 마지막 본문 전체 노출과 오류0을 확인했으며 전체 앱 검사 수에 합산하지 않는다.
- [계측 교정과 제외한 진단](/private/tmp/clipback-unclassified-20261017/.attempts/oracle-width-r1/oracle-amendment.json): 처음 프리뷰가 부모 텍스트 열192px과 자연 문단 폭을 같게 검사한 오류를 발견했다. 제품을 그 검사에 맞춰 늘리지 않고 열의 최대 제약192px·실제 문단의 포함/가운데 정렬로 교정했다. 이전 BEFORE6/부분AFTER2는 진단으로 보존·제외하고, 기준 제품을 안전 복원해 교정된 동일 fixture로 BEFORE부터 새로 촬영했다. [제품 복원 바이트 확인](/private/tmp/clipback-unclassified-20261017/temporary-baseline.json)으로 최종 제품6개가 이전 통과 구현과 byte동일함을 확인했다.

### 양 플랫폼 실행과 비교

- **iPhone16/iOS18.6**: Flutter 논리창 `Size(393.0, 852.0)`·DPR3.0·OS viewPadding 상59.0/하34.0px·IME0.0px, 36기록이다. 실제 최대 스크롤 관측은 829.000px이며 해당 시점 maxScrollExtent와 일치한다. style/layout/behavior/coverage/checksCompleted/전체 `passed:true`·프레임워크 오류0이다.
- **Android13/API33 제스처**: Flutter 논리창 `Size(392.7, 783.3)`·DPR2.75·OS viewPadding 상24.0/하0.0px·IME0.0px, 36기록이다. 실제 최대 스크롤 관측은 828.727px이며 해당 시점 maxScrollExtent와 일치한다. style/layout/behavior/coverage/checksCompleted/전체 `passed:true`·프레임워크 오류0이다.

| 플랫폼 | 첫 카드 시작 여백 전→후 | AFTER 카드·배지 | 빈 그룹·이미지 슬롯 | 제목 자연 폭 / 텍스트 열 최대 폭 |
| --- | --- | --- | --- | --- |
| iOS | 64→12px | 173px / 57×22px | 224×250px / 86×100px | 145.927px / 192px |
| Android | 64→12px | 173px / 57×22px | 224×250px / 86×100px | 145.927px / 192px |


- 두 기기의 화면 내부는 기존 PhoneFrame375px 상한을 유지하며320px은 자동 검사 범위다. 실제 OS 전체 원본과 Flutter 논리창/하단 inset의 차이를 구분한다.
- [실측·동작 요약](/private/tmp/clipback-unclassified-20261017/native-validation-summary.json)·[독립 동일 조건/API 대역 판정](/private/tmp/clipback-unclassified-20261017/pair-verification.json): 실제 배너ID99/4+4페이지·합성 포인터 드래그·8행 완전 노출/최대 스크롤·관리/검색/상세 왕복·북마크1회 변경/복원·더보기 취소·분류 실패/재시도(중복 제출 방지는 자동 App 회귀로 별도 확인)·마지막 한 건 분류 후 빈 화면/배너 제거·네 하단 탭·저장 진입/추가 저장 없는 닫기를 확인했다. native 공유는 첫 실행부터 메모리 채널로 격리해 위임0/미지원0이며 기존 큐·자격 내용을 조회/출력/삭제하지 않았다.
- [새3열 비교6쌍](/private/tmp/clipback-unclassified-20261017/comparison-document.html)·[비교 QA](/private/tmp/clipback-unclassified-20261017/comparison-qa.json): 양 플랫폼 정상0/300px·빈0의 새 전후 OS원본 각6장이다. 실제 데이터/1배율/IME0/스크롤을 맞췄으며 Figma누락/조건 불일치0이다. 스크롤300 전용 원본은 없으므로 같은 E06 전체 원본을 기준으로 설명한다. 예제 데이터·OS 창/상태/탐색 표시·실제 하단 여백 차이를 그대로 표시하며 원본 자르기/보정은 없다.

| 상태 | iOS | Android 제스처 |
| --- | --- | --- |
| 정상 목록·스크롤0 | [3열 비교](/private/tmp/clipback-unclassified-20261017/comparisons/ios-unclassified_list_scale_1_scroll_0.png) | [3열 비교](/private/tmp/clipback-unclassified-20261017/comparisons/android-gesture-unclassified_list_scale_1_scroll_0.png) |
| 정상 목록·스크롤300 | [3열 비교](/private/tmp/clipback-unclassified-20261017/comparisons/ios-unclassified_list_scale_1_scroll_300.png) | [3열 비교](/private/tmp/clipback-unclassified-20261017/comparisons/android-gesture-unclassified_list_scale_1_scroll_300.png) |
| 조회 완료된 미분류0 | [3열 비교](/private/tmp/clipback-unclassified-20261017/comparisons/ios-unclassified_empty_scale_1_scroll_0.png) | [3열 비교](/private/tmp/clipback-unclassified-20261017/comparisons/android-gesture-unclassified_empty_scale_1_scroll_0.png) |


- 개요: [iOS 3상태 비교](/private/tmp/clipback-unclassified-20261017/comparisons/ios-comparison-overview.png) · [Android 3상태 비교](/private/tmp/clipback-unclassified-20261017/comparisons/android-gesture-comparison-overview.png).
- 영상: [iOS AFTER](/private/tmp/clipback-unclassified-20261017/ios/after/interaction.mp4) · [Android AFTER](/private/tmp/clipback-unclassified-20261017/android-gesture/after/interaction.mp4). [미디어 검사](/private/tmp/clipback-unclassified-20261017/media-verification.json)는 두 원본의 동작 완료까지 녹화와 전체 디코딩 오류0을 확인했다. Android 첫 영상은 인코딩된 길이가 실행 구간보다0.596초 짧아 완료 범위 게이트를 통과하지 못했다. [제외한 영상 진단](/private/tmp/clipback-unclassified-20261017/.attempts/android-recording-tail-r1)으로 보존하고 제품/동결 fixture/정적 화면은 유지한 채 시작·종료 여유를 둬 동작 영상만 재촬영한 결과를 사용했다.
- [환경 정리](/private/tmp/clipback-unclassified-20261017/cleanup-verification.json)·[최종 자원 확인](/private/tmp/clipback-unclassified-20261017/final-resource-check.json): 앱/기기 종료·포워딩/임시 리스너 제거·탐색/키보드 원설정 일치·기기 데이터 보존을 확인했다. [HTML 참조/문법 검사](/private/tmp/clipback-unclassified-20261017/comparison-html-verification.json)는 정적 검사이며 비교 브라우저/HTTP서버 실행 성공으로 보고하지 않는다.
- 검증은 실제 ClipbackApp/Repository와 HTTP MockClient·메모리 세션·합성 포인터의 로컬 실행이다. 운영 서버·실제 OAuth·영속 저장·실기기·원격 CI·새 확대/3버튼 기기 촬영의 증거가 아니다. 미조회/로딩/오류·일반 목록의 미확정 빈 상태·정렬/미선택 탭 굵기·시트 배경/자유 색상·새 확대 맞춤은 보류한다.
