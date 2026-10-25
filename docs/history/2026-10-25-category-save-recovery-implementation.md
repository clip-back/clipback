# 카테고리 입력 보존과 실패 복구 구현

2026-10-25, [스펙 #86](https://github.com/clip-back/clipback/issues/86)의 하위 이슈 #87~#91을
선행 관계대로 구현하는 기록입니다. 정책·디자인은 [확정 정책](../frontend/category-save-recovery.md),
구체적인 계약과 검증 경계는 [구현 명세](../frontend/category-save-recovery-spec.md)를 따릅니다.

아래 단계별 대기·미검증 표현은 해당 단계 당시의 기록입니다. 현재 통합 결과는
[최종 공유 완료 검증](#최종-공유-완료-검증)을 따릅니다.

## #87 생성 입력과 같은 제출 재확인

기준은 통합 브랜치 `feature/category-save-recovery`의 `2dd5a52`입니다.

- 생성은 공통 비동기 결과 콜백을 통해 성공·거절·미확인을 구분합니다. 수정·삭제와 프리뷰의 기존 콜백은 유지합니다.
- 서버는 추가형 migration `202610250015`로 계정별 제출 키·내용 지문·원래 결과를 보관합니다.
  카테고리 변경과 기록을 함께 커밋하고, 재확인은 후속 수정·삭제를 되돌리지 않습니다.
- 생성 시트는 이름·색상을 유지하며 전체10초·대기 잠금·미확인 재확인·확정 거절 뒤 새 제출을 제공합니다.
  성공 뒤 목록 조회는 별도이고, 후속 조회 실패의 전용 복구는 #89에서 완성합니다.

### TDD와 자동 검증

- 서버의 첫 HTTP+PostgreSQL 검사는 기존 응답에 `submission`이 없어 실패했고, 새 저장 계약을 구현한 뒤 통과했습니다.
- 실제 앱+HTTP 대역+메모리 세션 검사는 성공 전 저장 안내가 없어 실패했고, 비동기 시트 연결 뒤 통과했습니다.
- 생성 통합 검사는 전체10초·늦은 응답·같은 키·거절 뒤 새 키·이름·색상 보존·40자 및 한글 조합·닫기 확인·
  관리 화면·인증 갱신 포함 예산·후속 조회 비대기를 확인합니다.
- 실제 PostgreSQL 검사는 독립 연결의 동시 제출, 계정·입력 격리, 성공/거절 재사용, 이후 수정·삭제 보존,
  커밋 전 실패와 커밋 응답 유실, 카테고리 삭제 뒤 기록 유지와 계정 FK 삭제를 확인합니다.
- 관련 서버 검사70개 통과, 전체 서버 검사1,030개 통과·Docker 복원12개 미실행(옵트인 전용 검사).
  `alembic upgrade head`, `alembic check`, `ruff check app alembic tests`, Python `compileall` 통과.
- Flutter 전체1,848개 통과. 마지막 단순화 뒤 관련 카테고리55개를 다시 통과했고 `flutter analyze`도 통과했습니다.

### 실행 증거와 당시 남은 검증

이 단계는 로컬·HTTP 대역 및 전용 PostgreSQL 검증입니다. iOS Simulator·Android Emulator의
변경 전/후/Figma 비교와 실제 키보드·드래그·뒤로가기·확대 동작은 별도 네이티브 검증 담당에서 준비합니다.
자동 검사 결과로 네이티브 실행 성공이나 운영 서버 배포를 대신하지 않습니다.
실제 OAuth·운영 서버·실기기와 원격 CI는 이 단계에서 실행하지 않았습니다.

## #88 수정 입력과 같은 수정 제출 재확인

기준은 통합 브랜치 `feature/category-save-recovery`의 `74c5f94`입니다.

- 아카이브·관리의 실제 수정 시트는 현재 이름·색상으로 시작하고 공통 비동기 결과 계약을 사용합니다.
  입력 검증·대기 잠금·전체10초·결과 미확인·같은 키 재확인·닫기 확인을 생성과 공유합니다.
  삭제된 대상은 초안을 잠근 채 승인 문구와 ‘목록으로 돌아가기’를 제공합니다.
- 수정 PATCH에 선택적 제출 키를 연결했습니다. 기존 키 없는 부분 수정과 소유권·이름 검증은 유지하며,
  작업 종류·대상·내용·전송 필드 존재를 비교해 계약 충돌을 분리합니다.
- 수정과 성공 기록은 같은 트랜잭션에 확정하고, 확정 거절도 기록해 같은 키로 새 쓰기가 실행되지 않게 합니다.
  성공 재확인은 과거 스냅샷을 반환하되 이후 수정·삭제를 다시 쓰지 않으며 현재 목록을 덮지 않습니다.
- 새 수정 제출은 낙관적 표시를 저장 증거로 사용하지 않습니다. 종료한 요청은 scope·계정 검사 뒤 적용하며,
  성공 시트 닫기와 카테고리 목록·콘텐츠 후속 조회를 분리합니다.

### TDD와 자동 검증

- 첫 서버 HTTP 테스트는 수정 응답에 `submission`이 없어 실패했고 keyed PATCH와 결과 기록 뒤 통과했습니다.
- 실제 앱 테스트는 서버 대기 중 수정 시트에 저장 안내가 없어 실패했고 공통 비동기 시트 연결 뒤 통과했습니다.
  삭제 대상도 승인 문구가 없는 실패를 확인한 뒤 안내·목록 복귀를 구현했습니다.
- 수정 앱 검사는 현재 값·정상 저장·명확한 거절 뒤 새 키·초안/색상 유지·code point40/41자·중복 제출·
  전체10초·인증 갱신 포함 시간·같은 키/내용 재요청·늦은 응답·잘못된 성공/충돌/네트워크 응답·닫기 확인을 다룹니다.
- PostgreSQL HTTP 검사는 수정의 순차/독립 연결 동시 재확인, 종류·대상·내용·필드 존재 충돌,
  계정과 소유권 격리, 거절 보존, 이후 수정·삭제 보존, commit 전 실패와 commit 응답 유실을 확인합니다.
- 관련 서버78개와 전체 서버1,038개가 통과했습니다. Docker 격리 복원12개는 opt-in 조건으로 미실행했고,
  기존 Starlette deprecation 경고1개가 있었습니다. `alembic upgrade head`·`alembic check`(새 작업 없음),
  `ruff check app alembic tests`, Python `compileall`이 통과했습니다.
- Flutter 관련 카테고리67개·전체1,860개가 통과했고, 이후 추가한 수정 인증 누적10초 검사1개도 통과했습니다.
  `flutter analyze --no-pub`는 문제 없음입니다. 후속 통합 뒤의 추가 검증은 아래에 이어 기록합니다.

### #89 통합과 추가 검증

- 통합 `7c05075`를 자체 브랜치의 `0587ef9`로 병합했습니다. 수정 성공도 `refreshCategoriesAfterSave`를 사용하며,
  콘텐츠 후속 조회는 `refresh(..., includeCategories: false)`의 독립 수명으로 유지합니다.
  신규 수정의 확인값 적용은 기존 카테고리 조회 세대를 무효화해 오래된 GET의 덮어쓰기를 막습니다.
- 실제 앱의 후속 GET 실패에서 콘텐츠 수7이0으로 바뀌는 실패를 재현했습니다. `CategoryRead`에는 목록 집계가 없으므로
  확인된 이름·색상만 기존 `CategorySummaryRead`에 적용하도록 고쳤습니다. 과거 성공 재확인은 값 대입을 하지 않습니다.
- 저장 성공 뒤 목록 실패 안내가 없던 재현도 공통 후속 조회 연결로 통과했습니다. 시트는 먼저 닫고 콘텐츠 수7을 유지하며,
  스낵바의 수동 재시도는 카테고리 GET만 실행합니다.
- 통합 후 `flutter test --no-pub --concurrency=1`로 카테고리·목록 복구·배치·Action·Repository 관련242개를 통과했습니다.
- 이후 #89의 공개 조회 수명 보정까지 `b97eefae`를 포함한 `a652b74`에서 최종 검증했습니다.
  수정·목록 복구·자동 분류·공유·Action·Repository 관련167개와 전체 Flutter1,892개가 통과했습니다.
  전체 명령은 `flutter test --no-pub --concurrency=1`이며 9분31초가 걸렸고, `flutter analyze --no-pub`는 문제 없음입니다.
- 같은 코드의 `flutter build web --no-pub`도190.4초에 통과했습니다. 기존 Cupertino font-family 안내와
  Wasm dry run 안내가 있었으며, 웹 브라우저 실행이나 Wasm 제품 배포를 확인한 것으로 보고하지 않습니다.
  네이티브 실행 기준 통합 `2b7c5c6`과 제품 tree가 같으며, 실행 종료 후 문서만 바뀐 최신 `ff219806`까지 포함했습니다.
- 통합 전 추가 단일 검사의 한 실행은 compiler `output.dill` 쓰기에서 `OS Error 28`로 중단됐습니다.
  이는 제품 assertion 실패와 구분한 환경 실패이며 통과로 집계하지 않았습니다. 해당 프로세스를 종료하고 이번 worktree의
  재생성 가능한 build145MB와 실패한 compiler의 명시된 임시 폴더만 정리했습니다. 위 통합 재검사는 정리 후 결과입니다.

### 실행 증거와 당시 남은 검증

이 단계의 실행 증거는 로컬 실제 앱·HTTP 대역과 전용 PostgreSQL입니다. iOS Simulator·Android Emulator의
키보드·대기·미확인·대상 없음·확대·이동과 변경 전/후/Figma 비교는 통합 네이티브 검증 담당이 기록합니다.
별도 담당의 양 플랫폼 core28/28 통과는 통합 담당이 확인했으며, 기종·OS·화면 증거와 상세 시나리오는 네이티브 기록을 따릅니다.
이 구현 담당은 네이티브 세션을 사용하지 않았으며, 자동 테스트를 네이티브 실행 증거로 대신하지 않습니다.
실제 OAuth·운영 서버·실기기·원격 CI는 실행하지 않았습니다.

## #89 저장 후 카테고리 목록 복구

시작 기준은 통합 브랜치 `feature/category-save-recovery`의 `74c5f94`입니다.
아래 최종 자동 검사는 #89 제품 보정 `3767394`의 tree 기준이며, 검사 뒤 최신 통합 `2b7c5c6`을 포함했습니다.
이후 합친 #88 수정 구현의 검증과는 구분합니다.

- 확정된 생성 성공은 시트를 닫고 `ContentActions.refreshCategoriesAfterSave`에서 카테고리 GET을 별도로 시작합니다.
  수정 연결과 콘텐츠 후속 조회는 #88 범위입니다. 조회·스낵바 재시도는 각각 인증 갱신 포함 전체10초이며 저장 대기를 연장하지 않습니다.
- 실패·무응답은 마지막 목록과 닫힌 시트를 유지하며 승인된 저장 완료·목록 갱신 실패 스낵바를 표시합니다.
  **다시 불러오기**는 카테고리 GET만 실행합니다. 공통 콘텐츠·프로필·통계 갱신에 연결하지 않습니다.
- 카테고리 GET만 엄격하게 디코딩합니다. 정상 빈 배열은 성공이며 빈 HTTP 본문·JSON null·잘못된 배열/항목·
  필수 `content_count`/`last_saved_at` 누락은 실패입니다. 기존 정상 HTTP 대역은 서버의 `CategorySummaryRead`에 맞췄습니다.
  생성·수정의 `CategoryRead`와 카테고리 밖의 공통 디코더 계약은 유지합니다.
- 공통·전용 카테고리 조회가 같은 세대·소유권 검사를 사용합니다. 새 조회·변경·계정 교체 뒤의 오래된 목록과
  늦은401을 막되 기존 공통 refresh의 콘텐츠·통계 및 공유 인증 갱신의 다른 소유자는 유지합니다.
  원래 제출의 성공 스냅샷은 현재 서버의 존재·이름·색상과 구분합니다.
- `CategoryReadSuperseded`로 같은 계정에서 대체된 조회를 구별해 재조회 결과를 성공으로 오인하지 않습니다.
  이전 계정의 늦은 정상 응답 무시와 실제 HTTP의 `ClipbackApiException` 오류 계약은 유지합니다.

### TDD와 자동 검증

- 실제 앱·HTTP 대역·메모리 세션에서 후속 GET503 뒤 실패 스낵바 부재, 빈 HTTP 본문의 잘못된 빈 목록 처리,
  필수 집계 필드 누락, 새 저장 뒤 늦은 공통 조회가 새 항목을 지우는 경쟁, 늦은401의 인증 갱신과
  이전 변경의 표시 정리가 새 유효 조회를 무효화하는 경쟁을 각각 재현한 뒤 수정했습니다.
- 신규 실제 앱 검사30개 통과. 공개 오류 계약 보정 뒤 기존 Repository·공유·실제 앱 묶음56개를
  기존 테스트 기대값 변경 없이 통과했고 정적 검사도 통과했습니다.
- `frontend/`에서 `flutter test --no-pub --concurrency=2`: **1,878개 통과**(198초).
  `flutter analyze --no-pub`: No issues. `flutter build web --no-pub`: 성공(36초), Wasm dry run 성공.
  웹 빌드는 CupertinoIcons 폰트 안내를 출력했으며 실제 브라우저 실행을 대신하지 않습니다.
- 변경 파일의 Dart format, `git diff --check`, Markdown 로컬 링크·민감/생성 파일 포함 여부 확인을 통과했습니다.
- 중간 검사에서는 nullable 요약 필드를 받지 못한 기존 대역 타입, 공유 공개 예외의 잘못된 성공 변환,
  이전 계정 정상 응답 무시의 차이를 발견했습니다. 타입과 요청 경계를 보정한 뒤 위 전체 검사를 통과했습니다.
- 중간의 두 Flutter 검사는 디스크 부족(`OS Error 28`)으로 listener/cache를 쓰지 못해 중단됐습니다.
  이 환경 실패는 통과로 집계하지 않았으며, 생성된 캐시를 정리한 뒤 파일 병렬도를 제한해 재실행했습니다.

### 실행 증거와 당시 남은 검증

이 단계의 앱 검사는 로컬 HTTP 대역입니다. 백엔드 코드는 바꾸지 않아 DB·마이그레이션 검사를 새로 실행하지 않았습니다.
iOS Simulator·Android Emulator의 변경 전/후/Figma 비교·스크린샷·영상은 별도 네이티브 검증 담당이 통합 코드에서 확인합니다.
이 담당의 자동 테스트로 네이티브 실행·실제 OAuth·운영 서버·실기기·원격 CI 검증을 대신하지 않습니다.

## #90 시트 닫기·현재 서버 값으로 재진입

- 작업 기준: `2991607e18de1fbd953cecb2fab32fa3db166972`, 브랜치 `feature/category-sheet-reentry-90`.
  #88·#89 검증 종료 뒤 생성·수정의 닫기·재진입만 구현했다. backend 제품 API/모델/마이그레이션은 바꾸지 않았다.
- 아카이브/관리의 생성·수정은 `CategoryPrepareCallback` → `prepareEditor` → 카테고리 전용 조회에서
  인증 갱신 포함 별도 전체10초를 적용한다. 성공한 현재 조회 이후 생성은 빈 이름·기본 색상, 수정은 서버의 현재 이름·색상으로 연다.
- `CategoryServerSnapshot`은 낙관적 표시로 조정하기 전 서버 원본과 read/account 소유권을 반환한다.
  새 공통 조회·mutation·계정 교체로 대체된 결과는 Action의 호출 전까지 다시 확인하며, 이전 bool이나 표시 목록을 원본 증거로 쓰지 않는다.
  기존 `loadCategories`의 late-success 무시와 `CategoryReadSuperseded` 구분·다른 콘텐츠 조회 보호를 유지한다.
- 준비 조회 실패는 마지막 목록과 일반 최신정보 실패 스낵바를 유지한다. 재시도는 카테고리 GET만 실행한 뒤
  원래 화면·계정이 유효할 때 새 시트를 연다. 현재 서버에서 대상 ID가 없으면 기존 대상 삭제 안내로 열고 같은 이름의 다른 ID로 대체하지 않는다.
- 편집/거절의 직접 닫기는 초안·키를 버린다. 미확인의 닫기 확인·계속 확인하기·같은 키와 내용·대기 잠금은 유지한다.
  닫은 뒤 새 시트/새 앱에서 이전 초안·키를 복원하거나 자동 전송하지 않는다. 늦은 성공·거절은 새 시트와 목록을 바꾸지 않는다.

### TDD와 자동 검증

- 실제 앱+HTTP 대역+메모리 세션 첫 red: 서버 이름·색상을 바꾼 뒤 수정 진입해도 이전 ‘공부’로 열린다.
  현재 원본 준비 경계 구현 후 green. `ticket-90-red-first.log`와 `ticket-90-green-first.log`에 보존했다.
- `category_reentry_test.dart` 신규33개: 두 진입 위치×생성/수정의 편집·거절 직접 닫기, 미확인 닫기 확인,
  같은 키 유지/새 키 시작·색상 폐기·GET만 재시도 뒤 열기·10초 인증 대기·새 앱·늦은 성공/거절·현재 상태 유지,
  낙관적 overlay와 원본/대상 부재 구분·같은 이름 다른 ID·공통 조회 대체·이전 화면 스낵바를 검증했다.
- 최종 관련 검사: `flutter test --no-pub --concurrency=1 test/category_reentry_test.dart test/category_list_recovery_test.dart test/category_delete_test.dart test/app/content_actions_test.dart test/data/content_repository_test.dart test/share/share_lifecycle_test.dart test/content_auto_category_test.dart` **200 passed**.
  `flutter analyze --no-pub`: **No issues found**. 로그 `ticket-90-related-final.log`, `ticket-90-analyze-final.log`.
- 기존 #89 이전 GET 대 새 저장 테스트의 HTTP 대역은 첫 후속 GET만 보류하도록 좁혔다. 새 재진입 GET까지 모두
  보류해 새 시트가 열리지 않는 fixture 문제였으며, 과거 결과가 최신 목록을 덮지 않는 최종 기대는 바꾸지 않았다.
- 실제 FastAPI HTTP+독립 PostgreSQL 세션/실제 commit에서 생성·수정 원래 키 성공 재확인, 이후 이름·색상 수정·삭제,
  같은 이름의 대체 ID, 새 키의 대상 없음, 카테고리 삭제 뒤 기록3개 보존과 계정 삭제 뒤0개를 확인했다.
  제출 관련 **17 passed**. backend 전체 **1040 passed / 12 skipped**(Docker 복원 opt-in), 기존 Starlette warning1, 105.58초.
- 예약한 전용 테스트 DB(port15486)만 사용하고 fixture가 만든 계정/카테고리/기록을 정리한 뒤 예약을 해제했다.
  `alembic upgrade head`, `alembic check`(새 operations 없음), `ruff check app alembic tests`, `python -m compileall -q app alembic tests` 통과.
  로그 `ticket-90-backend-related.log`, `ticket-90-backend-full.log`, `ticket-90-migration.log`.
- 중간 의존성 미준비·작업 경로 착오·대역 색상/변수명·lint와 독립 연결 PID assertion의 fixture 오류는 보정했다.
  순차 요청만으로 pool의 다른 연결을 보장한다고 가정하지 않고 실제 동시 GET으로 독립 연결을 확인했다. 이 오류를 제품 red나 통과로 집계하지 않았다.
- 최종 diff와 `git diff --check`, 문서 경로·명령 일치·민감/생성 파일 포함 여부를 확인했다.

### 실행 증거와 당시 남은 검증

- iOS Simulator·Android Emulator의 변경 전/후/Figma·팝업·키보드·드래그·뒤로가기·확대·짧은 높이는 native 전담 검증에서 기록한다.
  이 구현 담당은 기기를 실행하거나 화면 증거를 대체 제작하지 않았다.
- 프론트 전체 suite/web 빌드는 #90/#91 통합 뒤 root의 공유 최종 실행으로 수행한다. 이 시점의 관련 검사를 전체 검사로 보고하지 않는다.
  실제 OAuth·운영 서버·실기기·원격 CI·push/PR/issue 변경은 수행하지 않았다.

### #91 통합 뒤 재검증

- 최신 통합 `60fe05cdc8a1138f5117418ac8a88ff8a073c585`를 merge `c108f97c857d370da019edf57368673073816258`로 포함했다.
  README·중앙 이력은 양쪽 추가 내용을 보존했고, 공통 opener/원본 snapshot과 #91 stale 무시·현재 form route만 닫기를 확인했다.
- #90의 최종 관련7개 파일에 `test/category_auth_recovery_test.dart`를 더한8개 파일 **226 passed**(46초),
  `flutter analyze --no-pub` **No issues**(3.1초). 로그 `ticket-90-91-related.log`, `ticket-90-91-analyze.log`.
  backend 제품/테스트는 통합 전1040개 실행과 동일하며 재실행하지 않았다. 전체 Flutter/web·native는 root 공유 최종 검증을 따른다.

## #91 공유 인증 갱신과 계정 전환의 카테고리 수명 보호

### 변경과 red → green

- 실제 `ClipbackApp`·HTTP 대역·메모리 세션의 공개 화면 콜백으로, 결과 미확인 생성 시트와 닫기 확인창을 연 뒤
  게스트 계정 연결을 완료했습니다. 새 계정으로 초기화돼도 기존 시트가 남는 실패를 재현했습니다.
  `CloseTransientRoutesEffect`를 로그인 선택 전용 경로에서 실제 계정 초기화의 공통 경계로 옮겨 둘을 함께 정리합니다.
  같은 계정의 토큰 갱신과 로그아웃 시도의 일반 실패는 계정 초기화가 아니므로 초안과 제출을 유지합니다.
- 생성·수정의 현재 최종401이 로그인 복구로 시트를 닫은 직후, 아직 닫힘 애니메이션 중인 폼의 늦은 `stale` 결과가
  다시 `Navigator.pop`을 호출해 첫 route까지 제거하는 실패(`_history.isNotEmpty`)를 재현했습니다.
  이전 계정 결과는 추가로 닫지 않고, 성공도 해당 폼의 route가 현재일 때만 닫도록 제한했습니다.
- 공통 인증 갱신의 독립 scope·소유자 집합과 기존 직렬 토큰 저장은 그대로 유지합니다.
  카테고리 호출자의 전체10초가 먼저 끝나면 해당 대기만 끝나며, 다른 현재 요청이 소유한 갱신은 계속합니다.
  이미 유효한 갱신이 시작한 토큰 저장을 취소·롤백하지 않고, 끝난 카테고리 시도는 재전송·화면 반영을 하지 않습니다.
- 현재 README·동작·정책·ADR의 미구현 표현을 적용된 계약으로 맞추고, 서버 API와 migration `202610250015`를
  신규 앱보다 먼저 적용하는 배포 순서를 운영 안내에 연결했습니다. 운영에 적용했다는 의미는 아닙니다.

### 이 단계의 검증

- 신규 `test/category_auth_recovery_test.dart`의 실제 앱 검사26개를 통과했습니다.
  생성·수정·같은 제출 재확인·저장 후 GET의 인증 포함 전체10초, 단독 소유자 만료 뒤 늦은200/401,
  검색과 공유한 갱신 성공/503, 느린 토큰 저장 뒤 같은 키·내용의 수동 재확인, 로그아웃 실패/완료,
  미확인 시트·닫기 확인창과 잠긴 저장 시트의 실제 종료, 새 계정 초안 뒤의 늦은 쓰기·인증,
  갱신 거절/재요청의 현재 최종401 복구와 자동 게스트 발급 없음까지 확인했습니다.
- 초기 대역 작성에서 입력 반영 프레임 누락과 잘못된 소셜 upgrade 경로를 수정했습니다.
  이 대역 준비 오류와 위 두 제품 회귀의 red → green은 구분합니다.
- `frontend/`에서 `flutter test --no-pub --concurrency=1`로 아래14개 파일의 관련 검사 **431개**를 통과했습니다(65초).
  `category_auth_recovery_test`, `category_delete_test`, `category_list_recovery_test`, `category_sheet_alignment_test`,
  `session_restore_test`, `session_refresh_test`, `session_persistence_test`, `social_login_test`,
  `data/session_repository_test`, `app/app_view_model_test`, `app/content_actions_test`, `data/content_repository_test`,
  `share/share_lifecycle_test`, `content_auto_category_test`입니다. 이전 계정 GET·스낵바, 홈15초, 마이 통계 마지막 확인값과
  기존 콘텐츠·공유 복구도 이번 실행에 포함했습니다.
- 새 테스트 조건문의12개 lint 안내를 수정한 뒤 `flutter analyze --no-pub`는 No issues였습니다.
  변경 Dart format, 문서7개 로컬 경로, `git diff --check`와 민감·생성 파일 제외를 확인했습니다.
  전체 검사·제품 빌드·양 플랫폼 실행은 아래 공유 완료 검증과 구분합니다.

### 증거 경계

이 단계의 앱 검사는 로컬 HTTP·SDK 대역과 메모리 세션입니다. 실제 OAuth는 수행하지 않았습니다.
백엔드 제품·테스트·migration 소스는 변경하지 않았고 DB를 사용하지 않았습니다.
기존 서버의 계정 격리·권한·동일 키 처리 결과 검증은 선행 #87/#88과 최종 공유 서버 검사에서 구분합니다.
전체 프론트·백엔드·빌드·migration은 #90/#91을 모두 통합한 뒤 root가 한 번 실행하는 공유 완료 검증으로 진행합니다.
iOS Simulator·Android Emulator의 기종·OS·시나리오와 변경 전/후/Figma·스크린샷·영상은 별도 네이티브 담당의 기록을 따릅니다.
이 구현 담당은 기기를 실행하지 않았으며, 이 자동 검사로 네이티브 실행을 대신하지 않습니다.
운영 배포·운영 서버·실기기·원격 CI는 수행하지 않았습니다.

## 최종 통합 리뷰와 최소 정리

리뷰 기준은 `d98d2b32f276d271efd613f4d0447168304a88cd...23ece30e1180d0a6de796d110c9c28040698de2c`의
31개 커밋·46개 변경 파일입니다. 반영 작업은 깨끗한 `23ece30`에서 시작한
`feature/category-review-fixes`에서 수행했습니다.

### 두 검토 축과 반영

- Standards 검토는 문서 규칙 위반1건과 선택적 중복 판단2건을 남겼습니다.
  Figma 계획의 카테고리 생성·수정 복구 상태를 ‘제품 미적용’에서 ‘구현 적용·통합 검증 진행 중’으로 맞추고,
  승인 시안인 디자인 기준과 실제 실행 결과를 구분하며 이 구현 이력을 연결했습니다.
- 생성·수정의 동일한 서버 거절 코드 해석만 작은 private 변환 함수로 추출했습니다.
  생성의 카테고리 후속 조회와 수정의 별도 콘텐츠 후속 조회는 각각의 기존 흐름을 유지합니다.
- 재진입·목록 복구·인증 복구 세 테스트 파일의 메모리 세션 저장 대역만 `test/support/`에 공유했습니다.
  초기 합성 세션, 쓰기·삭제 횟수, 삭제 시 세션 제거를 유지하고, 인증 검사의 쓰기 대기는
  횟수 증가 후 gate를 기다린 다음 세션에 적용하는 순서를 유지합니다. HTTP 서버 대역은 각 파일에 그대로 둡니다.
- Spec 검토는 누락·부분 구현0개, 요청 밖 동작0개, 명세와 다른 동작0개였습니다.
  이는 소스·기존 통합 테스트·기록의 읽기 전용 대조이며 실제 실행 완료 판정과 구분합니다.
- 이번 변경은 동작 변화 없는 추출과 문서 상태 정정이므로 새 private 구현 검사를 만들지 않았습니다.
  기존 실제 `ClipbackApp`·HTTP 대역·메모리 세션 경계의 기대값을 바꾸지 않고 재실행해 동등성을 확인합니다.

### 자동 검증과 실행 경계

- 리뷰 전 `23ece30`에서 통합 담당이 실행한 `flutter test --no-pub --concurrency=2`는
  **1,951 passed**(3분04초)였습니다. 반영 담당이 `final-flutter.log`의 종료 결과를 확인했습니다.
- 반영 뒤 `frontend/`에서 `flutter test --no-pub --concurrency=1 test/category_reentry_test.dart test/category_list_recovery_test.dart test/category_auth_recovery_test.dart test/app/content_actions_test.dart`는
  **91 passed**(27초)였습니다. 로그는 `review-fixes-related.log`입니다.
- 미사용 import까지 정리한 최종 파일에서 `flutter test --no-pub --concurrency=2`는
  **1,951 passed**(3분02초), `flutter analyze --no-pub`는 **No issues**(2.4초)였습니다.
  리뷰 전후 테스트 수와 기존 기대값을 유지했습니다. 로그는 `review-fixes-flutter-full.log`, `review-fixes-analyze.log`입니다.
- 첫 정적 분석에서 저장 대역 추출로 미사용이 된 API import3개를 찾아 제거했습니다.
  정리 후 위 전체 검사를 다시 실행했고 변경 Dart5개 파일의 format은 추가 변경이 없었습니다.
- 같은 최종 코드의 `flutter build web --no-pub`는 **성공**(31.3초)했고 Wasm dry run도 통과했습니다.
  기존 CupertinoIcons 폰트 누락 안내와 Wasm 빌드·테스트 권고가 있었으며, 웹 브라우저 실행이나 Wasm 제품 배포를
  확인한 결과로 보지 않습니다. 로그는 `review-fixes-web.log`입니다.
- 두 변경 문서의 로컬 링크177개 존재, 변경 Dart5개 format, 최종 diff와 `git diff --check`,
  민감 정보·생성 파일 제외를 확인했습니다. 이번 정리는 새 사용자 동작이 없어 별도 CHANGELOG 항목을 추가하지 않았습니다.
- 새 작업 트리에 의존성 설정이 없어 첫 `--no-pub`는 테스트 시작 전에 중단됐습니다.
  `flutter pub get --enforce-lockfile`로 기존 잠금 파일 그대로 준비한 뒤 위 검사를 통과했습니다.
  이 환경 준비 실패는 제품 assertion 실패나 통과 수치에 포함하지 않았습니다.
- backend tree는 선행 전체 **1,040 passed / 12 skipped**와 같은
  `9257a0fc8e3581a3fd4ff1bed5de60271e7109a7`임을 확인했습니다. 이번 정리에서는 backend 소스·테스트·migration을
  변경하지 않아 DB 전체 검사를 중복 실행하지 않았습니다.
- 이 리뷰 반영 단계에서는 네이티브 빌드·시뮬레이터·에뮬레이터를 실행하지 않았습니다.
  이후 같은 최종 소스에서 수행한 양 플랫폼 실행과 변경 전/후/Figma·화면·영상은 아래 최종 공유 검증에 기록합니다.
  앞 단계 네이티브 결과와 최종 코드의 새 실행은 구분합니다.
- 실제 OAuth·운영 서버·운영 배포·실기기·원격 CI는 실행하지 않았으며 push·PR·이슈 변경도 수행하지 않았습니다.

## 최종 공유 완료 검증

최종 제품 소스는 통합 커밋 `204f1d0156c4dcaa70c853a78c3ad3194ba2d883`입니다.
frontend tree `6d6373c6296d2246488383120f78a421da7ebb9e`,
backend tree `9257a0fc8e3581a3fd4ff1bed5de60271e7109a7`에서 검증했습니다.
이 절은 통합 담당과 네이티브 담당이 수행한 실제 결과를 모은 최종 기록이며,
문서 완료 작업에서 코드·테스트·빌드·운영 설정을 바꾸거나 제품 검사를 재실행하지 않았습니다.

### 자동 검사·리뷰·빌드

- 최종 Flutter 전체 **1,951 passed**(3분02초), 관련 **91 passed**(27초),
  `flutter analyze --no-pub` **No issues**(2.4초), `flutter build web --no-pub` **성공**(31.3초)입니다.
  위 리뷰 절에 명령·로그와 기존 폰트/Wasm 안내를 기록했습니다. 브라우저 실행·Wasm 배포 증거는 아닙니다.
- 동일한 backend tree의 전체 **1,040 passed / 12 skipped**를 유효한 서버 결과로 확인했습니다.
  미실행12개는 Docker 복원의 명시적 opt-in 검사이고 기존 Starlette 경고1개가 있었습니다.
  실제 FastAPI HTTP·독립 PostgreSQL 세션의 제출 복구 검사 **17 passed**와 구분합니다.
- 최종 통합에서 `ruff check app alembic tests`, `python -m compileall -q app alembic tests`,
  `alembic upgrade head`, `alembic check`를 통과했습니다. 추가 생성할 migration operations는 없었습니다.
- 보정 delta를 재검토한 Standards는 원래 지적3개 해결·잔여 **0건**, Spec은 누락·부분0/범위 밖0/불일치0을
  유지했습니다. 두 검토는 읽기 전용 소스 검토이며 자동 검사나 기기 실행을 대신하지 않습니다.
- 실제 제품 진입점 `lib/main.dart`의 debug 빌드는 iOS Simulator **33.5초**, Android APK **40.2초**에
  각각 성공했습니다. 이는 제품 빌드 확인이며 해당 진입점으로 운영 API·공급자를 사용해 실행한 결과는 아닙니다.
- 실제 `ClipbackApp`에 HTTP·SDK 경계 대역과 메모리 저장소를 넣은 네이티브 검증용 빌드는
  iOS **59.2초**, Android **29.3초**에 성공했습니다. 위 제품 빌드와 구분되는 두 빌드이며 순차 실행했습니다.
  소스·출력 해시와 시각은 `final-builds/product-{ios,android}.json`, `final-builds/harness-{ios,android}.json`에 보존했습니다.

### 양 플랫폼의 새 실행

Flutter **3.44.9 / Dart 3.12.2**에서 iOS Simulator **iPhone 16 Pro / iOS 18.6**와
Android Emulator **Clipback_Share_API_33 / Android 13(API 33), dpi440**을 사용했습니다.
세로 원본은 iOS1206×2622px(402×874dp), Android1080×2220px(전체 디스플레이392.7273×807.2727dp)입니다.
Android 정상 비교의 실제 Flutter 앱 영역은392.7273×783.2727dp로 변경 전후 같았습니다.
기존 iOS 한국어 키보드와 Android Gboard 영어 키보드 설정을 유지했습니다.

| 최종 시나리오 | iOS | Android | 증거 디렉터리 |
| --- | --- | --- | --- |
| #90 현재 서버 값·재진입·닫기·실제 프로세스 재시작 | 21/21 | 21/21 | `{ios,android}/final-90` |
| #90 준비 조회 전체10초·인증·늦은 응답·GET만 재시도 | 8/8 | 8/8 | `{ios,android}/final-90-extra` |
| #91 공유 인증·토큰 저장·계정 전환·최종401 | 42/42 | 42/42 | `{ios,android}/final-91` |
| 실제 가로 화면1·2배율·IME·동작 잠금·미확인 닫기 | 13/13 | 13/13 | `{ios,android}/final-landscape` |
| 생성 회귀 | 25/25 | 25/25 | `{ios,android}/final-create-regression` |
| 수정 회귀 | 28/28 | 28/28 | `{ios,android}/final-88-regression` |
| 저장 성공 후 목록 복구 회귀 | 68/68 | 68/68 | `{ios,android}/final-89-regression` |
| 합계 | **205/205** | **205/205** | 플랫폼별 원본PNG140개·MP4 57개 |

이 결과는 최종 `204f1d0`에서 새로 실행했으며 이전 #87~#89의 통과 수치를 재사용하지 않았습니다.
OS 프로세스를 실제 종료·재실행한 뒤 합성 서버의 행·제출 결과·요청 기록만 검증용 journal로 이어 확인했습니다.
제품이 초안·이전 제출을 보관한 것이 아니며 시작 시 자동 POST/PATCH 없이 새 폼을 여는 것을 확인했습니다.
검색·계정의 동시 이벤트는 폼·확인창이 열린 상태에서 공개 화면 콜백으로 주입했고 실제 공급자 SDK 호출은 경계 대역으로
종료했습니다. 모달 뒤 버튼을 실제 탭했다거나 실제 OAuth를 수행했다고 보지 않습니다.
렌더링·OS 키보드·드래그·Android 시스템 뒤로가기·OS 방향 전환·프로세스 재시작은 실제 로컬 동작입니다.

가로 화면에서 iOS는874×402dp(2622×1206px), 좌우 안전 영역62dp·하단21dp,
IME219dp·가시 하단183dp에서 생성·수정1/2배율 모두 버튼 하단151dp까지 접근했습니다.
Android는807.273×368.727dp(디스플레이2220×1080px, OS 영역 포함), 상단 안전 영역24dp,
IME224.364dp·가시 하단144.364dp에서 버튼 하단1배율123.455dp·2배율125.727dp를 확인했습니다.
처리 중 뒤로가기·헤더 드래그 잠금과 미확인 닫기·계속 확인도 통과했습니다.

최초 iOS 가로 검사 도구는 한 번만 드래그해 버튼까지 도달하지 못한 결과를 남겼습니다.
실제 가시 영역 안에서 여러 번 드래그한 새 실행은 접근을 확인했고 제품·컴파일된 검증 앱은 바꾸지 않았습니다.
최초 원본은 `ios/final-landscape-single-drag`에 별도 보존했습니다. 이를 제품 실패나 통과 수치에 포함하지 않았으며,
계측하지 않은 최대 스크롤 범위를 추정해 채우지 않았습니다.

### 화면·영상 증거와 비교 경계

영구 증거 루트는 `$CODEX_HOME/visualizations/2026/10/22/01a16370-b415-77f3-a86a-160b5b4f0a56/category-save-recovery`입니다.
이 절의 증거 경로는 해당 루트 기준이며, 최종 비교 갤러리는 `comparison-final.html`입니다.
원본 화면·영상·JSON과 Figma E10 `111:4376`·E11 `111:4427`의 원본을 함께 보존합니다.
두 노드의 새 조회 시각은2026-10-25 04:01:19 UTC이며 정확한 소수초는 `figma/111-4376.json`, `figma/111-4427.json`을 따릅니다.
Figma375×812px와 실제 기기의 OS 안전 영역·화면 크기 차이를 설명하며 원본을 잘라 맞추거나 보정하지 않았습니다.

`final-summary.json`에 소스와 플랫폼별 합계·단계별 manifest·영상 길이·정상 비교 치수를 보존했습니다.
갤러리는 양 플랫폼×아카이브/관리×생성/수정의 정상 화면8쌍을 변경 전·변경 후·Figma의3열로 나란히 보여 줍니다.
정상 비교는 같은 viewport·데이터·IME·이름/색상·글자1배율·스크롤0을 맞췄습니다.
시트·손잡이·폴더·이름 입력·팔레트의 경계 차이는0이고, 기본 버튼은 상단+1dp 외 위치·폭·높이가 같았습니다.
갤러리의 로컬 참조159개가 모두 존재함을 확인했습니다.

`final-media-qa.json`에서 최종PNG280개의 manifest 해시 일치, MP4 **116개**의 원본 해시·스트림·길이 검사를
확인했습니다. 영상116개는 최종57개×양 플랫폼과 별도 최초 진단2개를 포함합니다.
길이는4.9051~42.066667초로 Android 녹화 제한에 도달한 파일은 없었습니다.
대표 재진입·가로 영상4개는 전체 디코딩 exit0이었습니다. ffmpeg null 출력의 timestamp-mux 안내는 남겼고,
원본 packet DTS 검사에서는4개 모두 비증가0개였습니다. 원본을 다시 인코딩하지 않았습니다.
정상 비교에 사용한 변경 전PNG8개와 Figma PNG2개도 보존 원본과 byte 단위로 같았습니다.

변경 전 기준은 제품 `d98d2b3`·문서 HEAD `2dd5a52`에서 코드 수정 전에 확보했습니다.
일부 원래 상태는 보존한 원본 바이너리로 나중에 다시 촬영했고 자체 소스·촬영 시각을 구분했습니다.
원래 생성은 POST 뒤 카테고리 GET을 하지 않아 동등한 저장 성공·GET503 실패 화면이 없으며 다른 동작으로 대신 만들지 않았습니다.
새 복구·가로·재진입·인증 상태에는 전용 변경 전/Figma 프레임이 없으므로 승인 정책 시안을 기준으로 표시하고 누락을 명시했습니다.

### 관찰한 배경 레이아웃과 제외 범위

- 원래 카테고리 행의2배율 **23px 넘침**은 변경 전과 최종 화면 양쪽에서 확인했습니다.
- Android 최종 실제 가로 화면의 IME 전환에서 배경 `ArchiveScreen`의 Column은 **7.6px**,
  배경 `CategoryArchiveView`의 Column은 **5.1/12px** 넘침을 기록했습니다.
  해당 배경 구조는 기준 소스와 비교해 콜백 연결 외 같지만 동일 가로 조건의 변경 전 실행 화면은 없습니다.
  따라서 변경 전에도 같은 가로 문제가 재현됐다고 단정하지 않습니다. 앞의2배율 행 관찰과도 구분합니다.
- 긴2배율 스낵바는 기존 승인 스타일을 유지합니다. iOS는 본문 폭 약125.35dp·높이292dp와 옆의201.65×48dp
  재시도 버튼으로 큰 공간을 차지했습니다. Android는 본문 약205.909×169dp와 아래의210.220×48dp 버튼을
  확인했습니다. 전체 문구·재시도 동작은 접근 가능했습니다.
- 이 배경 관찰은 전경 `CategoryFormSheet`의 가로 화면 **13/13** 통과와 구분하며 이번 생성·수정 복구의 미완료 범위가 아닙니다.
  배경 행·Column 크기 조정과 큰 글자·짧은 높이·IME의 스크롤 정책은 전용 디자인 확인 뒤 별도 작업으로 남겼습니다.
  [디자인 확인 필요](../figma-ui-alignment-plan.md#figma-pending-category-background-layout)에 간단히 연결했고 제품 레이아웃을 추가 변경하지 않았습니다.

검증 뒤 양 기기는 세로·글자1배율·Home·키보드0·폼 없음·journal 비활성으로 복원한 화면과 상태를 보존했습니다.
이후 검증 앱 프로세스와 자체 adb18887 전달·18886/18887 제어 포트만 종료하고 검증 journal을 제거했습니다.
`final-resource-cleanup.json`과 `{ios,android}/final-restored-state.json`, `{ios,android}/final-restored-home.png`에 기록했습니다.
Simulator·AVD·사용자 데이터·원본 바이너리와 증거는 보존했습니다. 전용 임시 DB 컨테이너는 통합 담당이 종료·제거를 확인했습니다.

문서 완료 확인은 두 변경 문서의 로컬 링크179개·증거 경로·내용 대조와 최종 `git diff --check`로 수행했습니다.
변경은 문서2개뿐이며 frontend/backend tree가 위 검증 소스와 같음을 확인했습니다.

로컬 자동·DB·네이티브 검증을 완료했습니다. 실제 OAuth·운영 서버·운영 배포·실기기·원격 CI는 실행하지 않았습니다.
문서 완료 작업에서는 push·PR·이슈·통합 브랜치 변경을 수행하지 않았습니다.
