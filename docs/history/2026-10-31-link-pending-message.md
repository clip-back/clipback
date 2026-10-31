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

통합 브랜치에서 2026-10-31에 실행했다. 작업 브랜치에서는 실행하지 않았다.

- 환경: iPhone 16 Pro / iOS 18.6 Simulator(1206×2622), Android Emulator AVD `Clipback_IG_Summary`
  (Medium_Phone과 같은 android-36 이미지·프로필) / Android 16 / 1080×2400·420dpi.
- 서버: 로컬 Homebrew PostgreSQL의 일회용 DB와 저장소 밖 대역 하네스로 띄운 실제 API.
  유튜브·인스타그램 요약을 켜고 메타데이터·AI 추천·요약 클라이언트를 고정 응답(요약은 끝나지 않는 대기)으로 바꿨다.
  실제 공급자·운영 서버·실제 OAuth·실기기·원격 CI는 사용하지 않았다.
- 실행 방법: 제품 진입점 `lib/main.dart`를 그대로 실행하고 사람의 탭 순서(새 게스트 → 저장 → 링크 붙여넣기 → 저장)만
  프로그램 입력으로 대신하는 저장소 밖 임시 드라이버를 사용했다. 드라이버·하네스는 커밋하지 않았다.
- 조건: 매 실행 전 앱 삭제(새 게스트), 글자 배율 1, 플랫폼별 같은 기기·링크·고정 메타데이터·스크롤 위치.
  링크는 `https://www.youtube.com/watch?v=IGscreen001`, `https://www.instagram.com/reel/IGscreen001/`.
- 변경 전은 `891dde9`, 변경 후는 `038f6b1`을 debug로 빌드했다. 이후 통합된 `fc260e2`는 백엔드 인스타그램 클라이언트의
  410 처리와 문서만 바꿨고 앱 코드와 하네스가 대역으로 바꾸는 경로에는 영향이 없다.
- Figma 기준: 파일 `svNWsTFh8Ws1Mpt8XQIcrN` D05 `111:4902`(375×812), 2026-10-31 13:41 KST 조회.

| 플랫폼·출처 | 변경 전 카테고리 문구 | 변경 후 카테고리 문구 |
| --- | --- | --- |
| iOS·Android 유튜브 | 동영상 정보를 처리 중이에요. 분류는 나중에 반영될 수 있어요. | 링크 정보를 처리 중이에요. 분류는 나중에 반영될 수 있어요. |
| iOS·Android 인스타그램 | 저장된 카테고리(처리 중 문구 없음) | 링크 정보를 처리 중이에요. 분류는 나중에 반영될 수 있어요. |

- 변경 후 서버 DB의 해당 인스타그램 작업은 `queued`였다. 저장 시 추천 카테고리(대역의 첫 후보)는 전후 같다.
- 인스타그램 처리 중 상태는 유튜브의 기존 처리 중 배치(카테고리 제목 아래 안내 줄)를 그대로 따르므로,
  변경 전 인스타그램 화면보다 폴더 행과 아래 안내문이 약 한 줄 내려간다. 새 배치는 추가하지 않았다.
- Figma와의 문구 외 차이(“+ 추가”·칩 삭제·붙여넣기 버튼 부재, 하단 안내문)는 변경 전후가 같아 이번 변경과 무관하다.
  Figma 프레임은 375×812 노치 기종이고 iPhone 16 Pro는 Dynamic Island 기종, Android는 상태바가 낮아 헤더·닫기 버튼
  위치가 다르다. 원본 화면은 보정하지 않았고 비교 이미지는 높이만 맞췄다.
- 글자 배율 확대(인스타그램 처리 중): iOS `accessibility-extra-extra-extra-large`에서 문구는 3줄로 잘리지 않았다.
  Android `font_scale 2.0`에서 문구는 2줄이고 폴더 행·안내문·닫기 버튼·상태바·제스처 영역 겹침이 없었다.
  iOS 최대 글자에서는 기존 요소의 문제(헤더 “콘텐츠 저장하기” 38px 넘침, 폴더 이름·닫기 글자 위아래 잘림,
  하단 안내문 마지막 글자가 닫기 버튼 경계에 걸림)가 보였다. 이번 변경과 무관한 기존 배치이며 고치지 않았다.
  같은 설정으로 첫 실행 안내를 시작하면 “게스트로 시작하기”에서 홈으로 넘어가지 않아, 첫 실행은 배율 1로 통과하고
  홈 도착 뒤 글자를 키워 저장 시트를 열었다. 이 첫 실행 문제의 원인은 확인하지 않았다.
- 스크린샷(변경 전·후 각 4장, 글자 확대 3장, 플랫폼·출처별 비교 4장)은 작업 세션의 Git 추적 밖 임시 폴더에 두었고
  커밋하지 않았다. 새 checkout에는 포함되지 않는다.
- 움직임이 중요한 변경이 아니어서 영상은 촬영하지 않았다.
