# 콘텐츠 변경 상태 동기화

- 최초 기록일: 2026-10-06
- 영역: 상태
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-99a619afa013ada8"></a>

### 2026-10-06 — PR 8·9 콘텐츠 변경 상태 동기화 및 실패 복구

<a id="b-ddbf215f865e5042"></a>

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
