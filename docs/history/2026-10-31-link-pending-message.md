# 저장 결과 처리 중 문구를 링크 정보로 통일

최초 기록일: 2026-10-31 KST. 시작 소스는 `32384ec`(통합 브랜치 `feat/instagram-summary`), 작업 브랜치는 `feat/instagram-summary-132`이다.
실행 기준은 [명세 #127](https://github.com/clip-back/clipback/issues/127)과 티켓
[#132](https://github.com/clip-back/clipback/issues/132)이다.
현재 동작 기준은 [Figma 화면 맞춤 계획](../figma-ui-alignment-plan.md#figma-current-34)을 따른다.

## 변경 범위

- 저장 결과의 처리 중 안내 조건을 '유튜브이고 `queued`·`processing`'에서
  '유튜브 또는 인스타그램이고 `queued`·`processing`'으로 넓혔다. 출처는 기존과 같이 `sourceLabel`로 판별한다.
- 문구를 ‘동영상 정보를 처리 중이에요. 분류는 나중에 반영될 수 있어요.’에서
  ‘링크 정보를 처리 중이에요. 분류는 나중에 반영될 수 있어요.’로 바꿨다(사용자 결정 #127 Q11·Q18). 화면 배치는 바꾸지 않았다.
- Figma 기준은 D05 `111:4902`이며 문구 차이만 승인 예외다. 공유 확장 화면은 범위 밖이다.

## 자동 검사

- `frontend/test/content_auto_category_test.dart`
  - 유튜브·인스타그램 × `not_requested`·`queued`·`processing`·`completed`·`failed`·`skipped` × 미분류·서버 분류:
    `queued`·`processing`에서만 새 문구를 표시한다.
  - 웹 링크·틱톡의 `queued`·`processing`에서는 새 문구를 표시하지 않는다.
  - 구현 전 새 테스트와 갱신한 기대값에서 10개가 실패하는 것을 확인한 뒤 구현했다.
- `frontend/test/save_base_typography_test.dart`와 `frontend/test/support/save_result_preview.dart`의 처리 중 문구 기대값을 갱신했다.
- 2026-10-31 작업 브랜치: `(cd frontend && flutter analyze --no-pub)`, `(cd frontend && flutter test --no-pub)`,
  `git diff --check` 결과는 아래 표에 적는다.

| 검사 | 결과 |
| --- | --- |
| `flutter analyze --no-pub` | 문제 없음 |
| `flutter test --no-pub` | 2018개 통과 |
| `git diff --check` | 통과 |

## 시뮬레이터·에뮬레이터 실행

통합 후 기록 예정. 작업 브랜치에서는 iOS Simulator·Android Emulator를 실행하지 않았고,
변경 전·후·Figma D05 비교와 글자 배율 확대 확인도 아직 하지 않았다.
