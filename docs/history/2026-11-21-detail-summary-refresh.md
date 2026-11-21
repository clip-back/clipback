# 상세가 '요약 중'에서 바뀌지 않는 문제 — 처리 중 상세 다시 읽기 (#444)

최초 기록일: 2026-11-21 KST. 브랜치 `fix/detail-summary-refresh`(main `96745b3` 기준).
기준은 [이슈 #444](https://github.com/clip-back/clipback/issues/444) 본문과 같은 날 사용자 결정(Q1–Q6 추천안, 세 번째 GET 시각 정정,
저장소 응답 순서 보호 허용, Android 저장 행 확인 뒤 재촬영)이다. 팀 피드백 시트 137.

## 변경 범위

- `DetailViewModel`: 열린 상세의 요약 상태가 `queued`·`processing`인 동안만 3초마다 `refreshDetail`로 다시 읽는다.
  다음 읽기는 앞선 응답이 끝난 뒤 예약한다. 완료·실패·`skipped`·`not_requested`, 닫기·이동·삭제·계정 변경·정리,
  방문(상세 핸들)당 100회에서 멈춘다. 횟수는 같은 방문 안에서 멈췄다 다시 시작해도 이어진다. 상세를 열 때의 기존 읽기 1회는 횟수 밖이다.
  오류 회차는 안내 없이 횟수에 넣고 계속한다(`93e6290`, 검수 반영 커밋).
- 백그라운드(앱 상태가 `resumed`가 아닌 동안)에는 쉬고, 복귀하면 진행 중인 읽기가 있어도 바로 새로 읽는다.
  `ClipbackApp`이 앱 상태 변화와 시작 시 현재 상태를 상세 모델에 전달한다.
- `RemoteContentRepository.refreshDetail`: 같은 상세의 읽기는 보낸 순서대로만 반영한다. 이미 반영된 읽기보다 먼저 보낸 응답
  (늦게 온 진입 읽기·카테고리 메타데이터 갱신 읽기·복귀 전 읽기)은 버린다. 그 밖의 저장소·API·서버는 바꾸지 않았다.
- 화면 모양·문구는 그대로다. [앱 동작 문서](../frontend/behavior.md)와 [Figma 화면 맞춤 계획](../figma-ui-alignment-plan.md) DEC-03,
  CHANGELOG 미배포 '개선'에 반영했다.
- 기존 테스트는 이슈 허용 칸 1행(`content_auto_category_test`의 YouTube 저장 테스트 이름·요청 수·완료 단언)만 바꿨다.

## 검증

모두 이 Mac(macOS 26.6.2, arm64)의 로컬 실행이다. 원격 CI·실기기·운영 서버 검증은 이 절에 없다.

- 변경 전 실패 확인: 새 상세 화면 모델 테스트 19개(첫 커밋 전), 검수 회귀 테스트 6개와 검수 재현 3건(반영 전)이 해당 단언에서 실패했다.
- 로컬 전체 검사(검수 반영 작업 트리, `93e6290` 위): `VERIFY result=PASS scope=all checks=12 failed=0`.
  서버 pytest `2885 passed, 50 skipped`, 앱 테스트 `+3967: All tests passed!`. skip 사유는 verify 출력 원문이다.

  ```text
  pytest skip: 49 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
  pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
  ```

- 화면(이 기록 시점): 변경 전 촬영은 시작 커밋 `96745b3` 빌드로 iPhone 16(iOS 18.6) Simulator 5/5행,
  Medium_Phone(API 36) Emulator 4/5행을 확보했다. Android 저장 직후 행은 prefill이 저장 POST 전에 실패해 미검증이다.
  변경 후 촬영은 아직 하지 않았다.
