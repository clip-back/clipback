# 공지를 서버에서 내려받기 (#486)

최초 기록일: 2026-11-26. 출처: 팀 피드백 시트 167번, 결정 1–5 모두 A(2026-11-26 사용자 "모두 A로 게시 (추천)").

## 바꾼 것

- 서버: 인증 없는 `GET /api/v1/notices`가 `backend/app/notices.json`을 돌려준다. 서버가 시작할 때
  `app/schemas/notice.py` 규칙(키 누락·타입·빈 문자열·빈 목록·실제 날짜 아님·모르는 키)으로 읽어 어긋나면 시작하지 않는다.
  점검 중에는 503(`service_maintenance`). 첫 파일은 앱 안 공지 2개와 같은 글·순서·게시일이다.
- 앱: 공지 목록 진입(마이 공지사항 줄·홈 종 버튼) 때만, 진입 화면을 그린 뒤 한 번에 하나씩 요청한다.
  진입 화면은 마지막으로 받은 목록(처음에는 앱 안 2개)이고, 실패·형식 오류(공지 하나라도 규칙 위반이면 응답 전체)면 조용히 그 목록을 둔다.
  상세는 누른 공지를 그대로 보이고, 목록을 닫은 뒤·로그아웃 뒤 도착한 응답은 다음 진입에 보인다. 홈 활용법 카드는 그대로다.
- 촬영 진입 K01: `/scene?kind=…&notices=same|added|fail`로 공지 응답을 고르고, 상태 JSON에 활성 모드·상세 실측을 남긴다.
- 계약·운영: [API 계약의 공지](../backend/api-contracts.md#공지), [백엔드 README 공지](../../backend/README.md#공지).

## 검증 (2026-11-26, 로컬)

- 커밋 `7eae777`에서 `python3 ~/.heoturu-agents/verify.py --log-dir .utmp/ticket-486`:
  `VERIFY result=PASS scope=all checks=12 failed=0`.
  - `pytest: 3528 passed, 52 skipped, 3 warnings in 477.36s (0:07:57)`
  - `pytest skip: 51 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)`
  - `pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)`
- 새 테스트: 백엔드 `tests/api/test_notices.py`(공개 응답·점검 503·OpenAPI·운영 파일 변형 4종·규칙 위반·달력 경계),
  앱 `test/notice_server_test.dart`(파싱, 최초 파일 동결 사본 `test/fixtures/notices_initial.json` ↔ 앱 상수, 순서 대조 표의 루트 흐름,
  📌 없는 행·단계 0개 상세의 폭 320·360·393 × 글자 1.0·1.3배, 실제 Pretendard).
- 바뀐 기존 테스트는 이슈 허용 표 안: `notice_guides_test.dart`·`notification_navigation_test.dart`의 요청 수 단언(더한 1건이 `GET /api/v1/notices`),
  대역 `NoticeServer`·`HomeBaseServer`·`ArchiveAllServer`(GET 공지 응답), K01 진입.
- iPhone 16(iOS 18.6 Simulator, 393×852)과 Medium_Phone(Android 16 Emulator, 약 411×914)에서 K01 메모리 서버로 이슈 촬영 표 5행을 확인했다. 변경 전 기준은 `643ffaf`, 변경 후 앱 코드는 전체 검증을 마친 `7eae777`이다.
  - 마이와 홈 종에서 열면 기존 두 행이 표시된다. 변경 전에는 공지 요청 0건, 변경 후에는 진입마다 GET 1건이었다. 종에서 들어간 뒤 뒤로가면 홈으로 돌아왔다.
  - 공지 경로만 503으로 설정한 변경 후 장면은 GET 1건, 기존 두 행과 안내 없는 목록을 보였다. 변경 전 대응 장면은 사용자 결정에 따라 요청 0건과 두 행으로 기록했다.
  - 세 번째 공지는 고정 핀 없이 표시됐고, 단계 없는 상세의 실제 배율 1.0·1.3에서 제목과 본문 및 맺음말을 확인했다. 이 상태들은 시작 커밋에 없으며, 단계 없는 상세와 일반 행을 위한 별도 Figma 디자인도 없다.
  - Figma 목록 `423:4464`·상세 `423:4520`은 2026-11-26 16:53 KST에 조회했다. 기기 화면은 OS 안전 영역을 포함한 원본이다. 비교는 그대로 비례 축소했다.
  - iOS 첫 기본 목록 AX 조회가 503이었다. 앱 상태를 다시 확인하고 해당 장면에서 1회 재조회해 두 제목을 확인했다. 실제 기기 오류 재시도는 없었다.
  - 로컬 증거는 `.utmp/ticket-486/compare-{ios,android}.png`, `.utmp/ticket-486/after-{ios,android}/notice-navigation.mp4`와 같은 폴더의 장면별 PNG·상태 JSON·AX다.
- CI·운영 배포·실기기는 이번 실행 범위 밖이다. wheel 설치본의 `notices.json` 포함 여부는 실행 미검증이다.
