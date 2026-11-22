# 요약이 끝난 콘텐츠의 홈·아카이브 목록 반영 (#460)

- 이슈: #460(팀 피드백 시트 144). 기준 커밋 `be12e77`.
- 사용자 결정(2026-11-22): Q1 "앱 복귀·화면 재진입 때 한 번", Q2 "홈·아카이브 둘 다", Q3 상세에서 복귀 때 "읽지 않음", 실패 경로 "이전 카드 유지, 실패 경로 진단".

## 변경

- 앱 복귀와 다른 화면에서 홈·아카이브로 들어올 때, 불러온 홈·아카이브 목록에 `queued`·`processing` 항목이 있으면 목록을 한 번 다시 읽는다(`frontend/lib/app/clipback_app.dart`). 복귀 때는 공유 처리가 끝난 뒤 읽는다. 그 사이 앱 상태나 계정이 바뀌었거나, 공유 처리 중·상세·로그아웃·계정 전환 중이면 읽지 않는다. 주기 폴링은 없다(DEC-03 유지).
- 저장소에 배경 다시 읽기(`ContentRepository.refreshInBackground`)를 따로 두었다. 기존 `beginRefresh`·`refresh`(공유 영수증, 저장·변경 뒤)는 바꾸지 않았다.
  - 새로고침 번호·목록 세대를 올리지 않는다. 다른 읽기(추가 쪽·새로고침)가 진행 중이면 시작하지 않는다.
  - 오류 줄이 떠 있는 목록과 아직 읽지 않은 목록은 대상이 아니다(공유 실패 안내·다시 시도 보존).
  - 목록과 카테고리를 모두 읽은 뒤 전부 성공했을 때만 함께 반영한다. 하나라도 실패하면 아무것도 바꾸지 않아 처리 중 표시가 남고 다음 진입에서 다시 읽는다.
  - 기다리는 동안과 실패 때 스피너·오류 줄·안내가 없다. 그동안 요청한 다음 쪽은 다시 읽기가 끝난 뒤 이어서 읽는다.
- 문서: `docs/frontend/behavior.md`, `CHANGELOG.md` 미배포 개선.

## 진단과 검수

- 첫 구현은 기존 `refreshExternal`을 불렀다. 503이면 홈 카드가 오류 줄로 가려지고, 아카이브 목록 끝에도 오류 줄이 붙었다. 기다리는 동안에도 스피너가 보였다. 저장소는 항목을 남기고 `page.error`·`page.loading`만 세웠고, 위젯이 그 분기로 카드를 가렸다(코드 확인 + 위젯 재현, 작업 파일 `diagnosis-503.md` D1–D4).
- 검수 7건(카테고리만·일부 목록만 실패 시 복구 불가, 공유 오류 덮어쓰기, 진행 중 다음 쪽 폐기, 효력이 끝난 복귀, 테스트 대역의 메서드 무시, 기기 없는 판정의 종료 코드, 전환 예외 미기록)을 반영했다. 수정 전 실패는 검수 재현 로그와, 새 루트 테스트를 검수 대상 커밋 `5c8a9d9`의 `lib`로 돌린 결과로 대조했다.

## 검증 (2026-11-22, 로컬)

- 전체 검사: `VERIFY result=PASS scope=all checks=12 failed=0`(커밋 `a77b7ce`). pytest `3027 passed, 50 skipped`. 앱 테스트 `+3989: All tests passed!`.
  - `pytest skip: 49 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)`
  - `pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)`
- 새 테스트: `frontend/test/list_refresh_root_test.dart` 15개(실제 `ClipbackApp` + 메모리 서버), `frontend/test/data/content_background_refresh_test.dart` 7개.
  - 기준 커밋에서 1·2·8은 실패하고 3–7은 통과했다.
  - 검수 대상 커밋 `lib`에서는 12·13·14가 실패했다.
- 촬영(iOS Simulator·Android Emulator): 변경 전 4행(`home-reentry`·`home-resume`·`archive-count`·`home-stay`)은 감독이 찍었다. 그 기기 기록에 양 플랫폼 모두 백그라운드 → 복귀(`paused`→`resumed`)가 남아 있다.
- 미검증:
  - 변경 후 양 플랫폼 촬영(기기 단계).
  - 아카이브 카테고리 행은 개수를 그리지 않는다. 일상 개수는 행에 전달된 값으로만 확인했고, 화면에 보이는 개수는 미분류 배너뿐이다.
  - 실제 운영 서버의 503.
