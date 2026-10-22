# FE 통합 계획과 당시 진행 규칙

- 최초 기록일: 2026-10-05
- 영역: 계획
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-220a2df5cfbf7d19"></a>

### FE 병합 전 수정 진행 현황

<a id="b-346b8c96ad16d44d"></a>

### 1. 목적과 현재 범위

<a id="b-d225898118a2fdb8"></a>

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

<a id="b-40b91bfc5723f4f6"></a>

이 문서는 FE 수정 계획과 실행 기록을 관리한다. 화면·실행 안내는
[프론트 README](../../frontend/README.md), 백엔드 구현 범위는
[백엔드 MVP 계획](../backend-mvp-plan.md)을 참고한다.

<a id="b-500e5be0bd58fb8e"></a>

### 기준 커밋

<a id="b-3b6fdf146a5d61ec"></a>

| 항목 | 기준 |
| --- | --- |
| 문서 준비 브랜치 | `docs/fe-merge-fixes-plan` |
| 출발점 | `origin/FE` — `41931119f5bfc58c3d1c6c09e2b1a82ba45221b3` |
| 비교 대상 | `origin/main` — `8c759d1f4a02f43966f4d692d0541d5feb74dcdc` |
| 2026-10-05 원격 확인 | FE 전용 3개 / main 전용 60개 커밋으로 분기됨 |

<a id="b-c36be4a0c0ae31ac"></a>

위 표는 최초 계획의 기준이다. 2026-10-06 동기화 브랜치는 FE `8f3f2f4`에 main `8c759d1`을 병합한다.
이후에는 동기화된 FE의 프론트·백엔드를 함께 검증하며, 최종 main 병합 전에도 최신 변경을 확인한다.
위 SHA와 과거 결과를 새 검증 결과로 재사용하지 않는다.

<a id="b-b81b963d643f5817"></a>

### 2. 브랜치·PR 진행 방식

<a id="b-ede71ba0eda8bf79"></a>

이 작업에서 합의한 흐름은 다음과 같다.

<a id="b-ca6c3fa5592083b3"></a>

1. 문서 준비 변경을 검토하여 FE에 반영한다.
2. 최신 `origin/FE`에서 해당 문제의 수정 브랜치를 만든다.
3. 실패 재현 테스트를 먼저 추가하고, 최소 수정 후 관련 검사를 실행한다.
4. 해당 PR의 상태·변경 내용·실제 검증 결과를 이 문서에 함께 기록한다.
5. 수정 PR은 **base `FE`**로 검토·병합한다. 병합 여부와 결과 커밋은 다음 작업 시작 시 기록한다.
6. 다음 수정은 갱신된 FE에서 시작한다. PR 2 → 3 → 4는 의존성을 지켜 순서대로 진행한다.
7. PR 3 이후 main을 FE에 먼저 동기화하고 통합 테스트한 뒤, 이후 수정은 동기화된 FE에서 시작한다.
8. 수정이 끝나면 최신 main과의 병합 결과를 다시 검증하고 **최종 `FE → main` PR**을 만든다.

<a id="b-f4fe9308496fc65c"></a>

[공통 Git 규칙](../git-conventions.md)의 PR base `main` 원칙에 대해,
이 FE 병합 준비 작업의 문서·수정 PR만 base `FE`를 사용하는 예외다. 최종 통합 PR의 base는 `main`이다.
PR 제목은 아래의 한글 Conventional Commits 형식을 사용하며, 하나의 PR에는 해당 수정과 회귀 테스트,
진행 문서 갱신만 포함한다. 2026-10-06 사용자 지시에 따라 앞으로 계획 구현은
검증·문서 기록·커밋·현재 작업 브랜치 푸시까지 진행한다. PR 생성·병합은 요청된 단계에서 수행한다.

<a id="b-8830ded9f8096417"></a>

### 3. 상태 관리

<a id="b-210ea4474ab98335"></a>

- **예정:** 수정과 재현 테스트를 시작하지 않음.
- **진행 중:** 재현 또는 구현 중이며 완료 조건을 아직 충족하지 않음.
- **검증 완료:** 해당 PR의 완료 조건을 검증했고, 결과와 미검증 범위를 기록함.
- **PR 생성:** 실제 PR 링크가 있으며 리뷰 또는 병합 대기 중.
- **FE 병합:** FE에 반영된 커밋과 확인 날짜를 기록함. main 통합 완료를 뜻하지 않음.

<a id="b-c1153e336d7b5def"></a>

아래 번호는 작업 식별자이며 GitHub PR 번호가 아니다. 브랜치·PR 링크는 실제 생성 후 채운다.

<a id="b-7009bd44dadb1543"></a>

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

<a id="b-db99947bcb53c794"></a>

### 4. PR별 수정 범위와 완료 조건

<a id="b-467fb3cd4c247685"></a>

코드 위치는 기준 FE의 함수·클래스 이름이다. 작업 시작 시 최신 코드에서 다시 확인한다.
공통 대상 파일은 [main.dart](../../frontend/lib/main.dart)와
[clipback_api.dart](../../frontend/lib/clipback_api.dart)다.

<a id="b-9f1d68ffc653352f"></a>

### PR 1 — `fix: 일시적인 조회 실패 시 기존 세션 보존`

<a id="b-f7ea68bc7c1bc134"></a>

- 위치: `main.dart`의 `_restoreSession()`.
- 수정: 네트워크 오류·503·응답 파싱 실패를 인증 만료와 구분한다. 조회 실패만으로 저장된 세션을
  삭제하거나 새 게스트를 생성하지 않고, 오류 안내와 재시도 경로를 제공한다.
- 완료 조건: 카테고리 조회가 한 번 실패해도 기존 토큰이 유지되고 `/auth/guest` 호출이 없다.
  재시도 성공 시 같은 계정의 데이터를 불러오며, 실제 인증 만료 처리와 구분된다.

<a id="b-23af909dbc44322f"></a>

### PR 2 — `fix: 갱신된 인증 토큰 영속 저장`

<a id="b-49933f565b2f9608"></a>

- 위치: `clipback_api.dart`의 `refreshSession()`, `ApiSessionStorage`, `main.dart`의 세션 저장 호출부.
- 수정: refresh 성공 시 새 access·refresh token을 영속 저장한다. `_loadRemoteData()`를 실행해야만
  저장되는 구조를 해소한다.
- 완료 조건: 카테고리 생성 중 401 → refresh → 생성 성공 후 저장소에 새 토큰이 남는다.
  앱 재시작 후 같은 계정으로 복원되고, 저장 실패를 검증 성공으로 취급하지 않는다.

<a id="b-ac2b789a9b66cc2b"></a>

### PR 3 — `fix: 동시 인증 오류의 토큰 갱신 중복 방지`

<a id="b-96a9ff08770e4b4c"></a>

- 위치: `clipback_api.dart`의 `_request()`, `refreshSession()`.
- 수정: 여러 요청이 하나의 진행 중인 refresh를 공유한다. 이전 access token으로 보낸 요청의
  401이 늦게 도착하면 이미 갱신된 토큰으로 재시도한다.
- 완료 조건: 상세 조회·열람 기록·클릭 기록이 동시에 401을 받아도 refresh는 한 번만 호출되고
  모두 성공한다. 늦은 401과 refresh 실패 후의 다음 요청도 처리되며, 무한 재시도가 없다.

<a id="b-163616ee607f5953"></a>

### PR 4 — `fix: 스크린샷 업로드 인증 갱신과 재시도 처리`

<a id="b-b5936781f1fc9db1"></a>

- 위치: `clipback_api.dart`의 `uploadScreenshot()`, `main.dart`의 `_runSaveRequest()`.
- 수정: multipart 업로드도 공통 refresh 경로를 사용하고, 재시도할 요청을 새로 구성한다.
  저장 중 401을 새 게스트 생성으로 처리하는 fallback을 제거한다.
- 완료 조건: 유효한 refresh token과 만료된 access token으로 업로드해도 같은 계정으로 저장된다.
  재전송 파일·카테고리·태그가 유지되고 `/auth/guest` 호출이 없다. 인증 복구 실패 시에는 오류를 안내한다.

<a id="b-55a9691590b8348e"></a>

### PR 5 — `fix: 콘텐츠 저장 시 자동 분류 적용`

<a id="b-55bf48ea25ea7ffe"></a>

- 위치: `main.dart`의 `AddContentSheet`, `_addLinkContent()`, `_addScreenshotContent()`.
- 수정: 사용자 선택이 없으면 `category_ids: []`를 보낸다. 첫 카테고리 강제 지정과 그 이름을
  태그로 자동 주입하는 동작을 제거하고, 결과 표시는 실제 서버 응답을 따른다.
- 완료 조건: 선택 없는 링크·사진 저장은 자동 분류 경로를 사용하고, 명시적 선택은 유지된다.
  YouTube의 비동기 분류와 분류 실패 시 미분류 처리를 성공한 자동 분류로 잘못 표시하지 않는다.
  기존 카테고리 접근 권한·복수 분류·미분류 혼합 거절 계약은 유지한다.
  `###`처럼 카테고리로는 유효하지만 태그 정규화 시 빈 값이 되는 이름도 저장되는지 회귀 검증한다.

<a id="b-fb0a9c724ada6270"></a>

### PR 6 — `fix: 피드 커서 기반 추가 조회 구현`

<a id="b-9647957a46164cf8"></a>

- 위치: `main.dart`의 `_loadRemoteData()`, `_searchContents()`와 목록 화면, `ClipbackApi.readFeed()`.
- 수정: `next_cursor`로 추가 조회하며, 검색·분류·북마크 조건이나 계정이 바뀌면 해당 목록과 커서를
  초기화한다. 같은 콘텐츠가 중복 표시되지 않도록 한다.
- 완료 조건: 101개 이상 저장한 계정의 오래된 보관·검색·분류·북마크 항목에 접근할 수 있다.
  조건 변경 중 늦게 도착한 응답이 다른 목록에 섞이지 않고, 마지막 페이지에서 추가 요청이 멈춘다.
  현재 로드 수를 전체 개수로 표시하거나 누적 저장 수와 혼용하지 않는다.

<a id="b-37821f0d3b29c154"></a>

### PR 7 — `fix: 저장한 스크린샷 원본 재조회 지원`

<a id="b-e5c9039d52748f65"></a>

- 위치: `main.dart`의 `_contentFromApi()`, `ContentItem`, 상세·원문 화면, `ClipbackApi.readAsset()`.
- 수정: API의 자산 정보를 화면 모델에 보존하고, 인증된 다운로드로 원본을 표시한다.
  선택 직후 메모리에 남아 있는 이미지에만 의존하지 않는다.
- 완료 조건: 저장 확인창을 닫은 뒤 또는 앱을 재시작한 뒤에도 원본 이미지가 보인다.
  토큰 갱신 후 조회, 다른 사용자 자산 접근 거절, 다운로드 실패 안내를 확인한다.

<a id="b-973d25bd1bd385ab"></a>

### PR 8·9 — `fix: 콘텐츠 변경 상태 동기화 및 실패 복구`

<a id="b-b22e6ae786d9abf9"></a>

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

<a id="b-bc2e8a628fcc772f"></a>

### PR 10 — `fix: 카테고리 삭제 안내와 화면 동작 일치`

<a id="b-c981c1c5a6af33c4"></a>

- 위치: `main.dart`의 카테고리 삭제 대화상자와 삭제 처리.
- 수정: 콘텐츠까지 영구 삭제된다는 안내를 바로잡고, 삭제 중 콘텐츠를 목록에서 잘못 제거하는
  동작을 서버 계약에 맞춘다. 백엔드의 콘텐츠 보존 정책은 변경하지 않는다.
- 완료 조건: 카테고리를 삭제해도 콘텐츠는 보존된다. 마지막 분류가 없어지면 미분류로 이동하고,
  다른 분류가 있으면 유지된다. 실패 시 원래 화면 상태가 복구된다.

<a id="b-bc7cef544064b29a"></a>

### 5. 검증과 최종 완료 조건

<a id="b-5a1e4907e83f8638"></a>

### 각 수정 PR

<a id="b-db14b35ea2d1dc81"></a>

- 해당 결함의 실패 재현 → 수정 후 통과를 확인하고, 회귀 테스트를 같은 PR에 포함한다.
- `frontend/`에서 `flutter analyze`와 `flutter test`를 실행한다.
- 루트에서 `git diff --check`와 최종 diff를 확인한다.
- 화면 변경은 `flutter run`으로 검증한 기기·브라우저·시나리오를 기록한다.
  확인하지 못한 환경은 미검증으로 남긴다.
- 인증·저장 계약은 최신 main 백엔드와 대조한다. 대역을 사용한 HTTP·위젯 테스트와
  실제 PostgreSQL HTTP 통합 검증은 구분한다. DB 검증에는 폐기 가능한 전용 테스트 DB만 사용한다.

<a id="b-3ec7c5881338ae9b"></a>

### SDK와 잠금파일

<a id="b-f4d037b347d3ebb3"></a>

기준 FE의 `pubspec.lock`은 Dart `>=3.12.0 <4.0.0`, Flutter `>=3.44.0`을 요구한다.
작업 시작 시 실제 SDK와 잠금파일 요구 조건을 확인하고, 잠금파일 그대로 검증할 수 있는 환경을 사용한다.
의존성을 재해석했다면 변경된 환경을 명시하고 원본 잠금파일 검증으로 보고하지 않는다.

<a id="b-97fb55cf619ef8f0"></a>

```bash
# frontend/에서 실행: 실제 버전과 결과를 아래 실행 기록에 남긴다.
flutter --version
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
flutter build web --no-pub
```

<a id="b-e298d15dd6fe3a71"></a>

### 최종 FE → main 통합

<a id="b-1fef433a6bcebfdf"></a>

- 10개 수정의 상태·PR 링크·병합 커밋을 확인한다.
- 최신 main과 FE의 병합 충돌뿐 아니라 병합 결과의 API 계약·회귀 테스트를 확인한다.
- 웹 빌드와 대상 플랫폼의 저장 → 검색·분류·북마크 → 재열람 → 삭제 흐름을 검증한다.
- 로컬 테스트, GitHub Checks, 실제 API·CORS·외부 AI·실기기 결과를 각각 기록한다.
  실행하지 않은 항목은 이유와 다음 확인 작업을 남기며 완료로 표시하지 않는다.

<a id="b-e68cb490aec07661"></a>

### 6. 실행 기록

<a id="b-f53677da4e3ff87a"></a>

### 문서 준비 — 2026-10-05

<a id="b-ab8cc06d84e158ff"></a>

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

<a id="b-43e6861c02dab1f1"></a>

### 문서 PR 생성 — 2026-10-05

<a id="b-13abfb99039c8ef8"></a>

- 상태: PR 생성, FE 병합 대기. 수정 PR 1~10은 모두 미착수.
- PR: [#36 — docs: FE 병합 전 수정 진행 문서 추가](https://github.com/clip-back/clipback/pull/36).
- 브랜치: `docs/fe-merge-fixes-plan` → `FE`. 문서 준비 커밋 `e6d04b3`을 origin에 푸시했다.
- 변경: 진행 문서와 프론트 README 두 파일만 포함하며, 기존 사용자 `AGENTS.md` 변경은 제외했다.
- 검증: 상대 링크와 FE 대비 변경 범위 확인, `git diff --check origin/FE...HEAD` 통과.
- GitHub Checks: PR 생성 직후 조회 시 검사 기록 없음. 로컬 문서 검증과 구분한다.
- 미실행: 문서만 변경하여 앱 테스트·빌드·운영·실기기 검증은 미실행. PR 병합도 미실행.
- 다음 작업: 문서 PR의 FE 병합 확인 후 최신 FE에서 PR 1용 수정 브랜치를 만든다.

<a id="b-d15e18e4c7fad86e"></a>

### 문서 PR FE 병합 확인 — 2026-10-05

<a id="b-27bcecdfea0b7224"></a>

- PR [#36](https://github.com/clip-back/clipback/pull/36)은 2026-10-05 16:29 KST에 FE에 병합되었다.
- 병합 커밋: `57488ab8fbd90b8d1332b1bb444c5490cb77f3b1`.
- 위 병합 커밋이 현재 수정 브랜치 `fix/fe-session-restore`의 출발점이다.

<a id="b-f135890f640c3df7"></a>

### 다음 작업 기록 양식

<a id="b-5d44a9e47827d921"></a>

작업할 때마다 아래 양식을 복사해 날짜별로 추가하고, 3절의 상태 표도 함께 갱신한다.
실제 토큰·키·사용자 데이터는 기록하지 않는다.

<a id="b-ea0d59fb9bbe1b24"></a>

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
