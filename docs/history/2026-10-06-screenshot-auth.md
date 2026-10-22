# 스크린샷 인증 갱신과 재시도

- 최초 기록일: 2026-10-06
- 영역: 저장
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-ccf4944b5c72cc1f"></a>

### PR 4 시작 — 2026-10-06

<a id="b-90d89fe2be6b8aa0"></a>

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

<a id="b-0d16f38bdb899461"></a>

### PR 4 구현·검증 — 2026-10-06

<a id="b-69c09df223d13c79"></a>

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

<a id="b-234f86fb44ac680a"></a>

| 실제 Chrome 검증 구간 | API·DB 확인 결과 |
| --- | --- |
| 만료된 토큰으로 사진 저장 1회 | 업로드 `401 → 201`, 그 사이 refresh `200` 1회, 추가 게스트 0회 |
| 저장 후 DB·파일 확인 | 기존 사용자·세션 유지, 콘텐츠·첨부파일·저장 이벤트·파일 각각 1건, 원본 바이트 일치 |
| 앱 새로고침 | 기존 계정·저장 콘텐츠 복원, 카테고리·피드·프로필·통계 조회 200 |
| 전용 refresh 세션 만료 후 사진 저장 | 업로드 401 → refresh 401, 재업로드·추가 게스트 없음, 사진·계정·저장 버튼 유지 |
| 최종 실패 후 DB·파일 확인 | 기존 1건씩 유지, 신규 콘텐츠·첨부파일·이벤트·파일 없음 |

<a id="b-77bff286fdc965b3"></a>

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
