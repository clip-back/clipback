# 카테고리 삭제와 콘텐츠 보존

- 최초 기록일: 2026-10-06
- 영역: 분류
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-35273fb0485d8ecf"></a>

### 2026-10-06 — PR 10 카테고리 삭제 안내와 화면 동작 일치

<a id="b-28ede49ad1852eaa"></a>

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
