# 카테고리 입력 보존과 실패 복구 구현

2026-10-25, [스펙 #86](https://github.com/clip-back/clipback/issues/86)의 하위 이슈 #87~#91을
선행 관계대로 구현하는 기록입니다. 정책·디자인은 [확정 정책](../frontend/category-save-recovery.md),
구체적인 계약과 검증 경계는 [구현 명세](../frontend/category-save-recovery-spec.md)를 따릅니다.

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

### 실행 증거와 남은 검증

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

### 실행 증거와 남은 검증

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

### 실행 증거와 남은 검증

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

### 실행 증거와 남은 검증

- iOS Simulator·Android Emulator의 변경 전/후/Figma·팝업·키보드·드래그·뒤로가기·확대·짧은 높이는 native 전담 검증에서 기록한다.
  이 구현 담당은 기기를 실행하거나 화면 증거를 대체 제작하지 않았다.
- 프론트 전체 suite/web 빌드는 #90/#91 통합 뒤 root의 공유 최종 실행으로 수행한다. 이 시점의 관련 검사를 전체 검사로 보고하지 않는다.
  실제 OAuth·운영 서버·실기기·원격 CI·push/PR/issue 변경은 수행하지 않았다.

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
