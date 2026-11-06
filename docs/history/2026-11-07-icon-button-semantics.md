# 아이콘 버튼 스크린 리더 이름 (#202)

2026-11-07, 시작 커밋 `ff7e740` 기준으로 구현하고 티켓 리뷰 반영과 전체 검증까지 마쳤다.
코드 커밋은 `02fbbf4`(구현) → `070ede7`(리뷰 S1 반영)이고, 전체 검증의 기준 코드는 `070ede7`이다.
이 기록은 iOS Simulator·Android Emulator의 `orca emulator ax` 확인, 실제 VoiceOver·TalkBack 청취를 뜻하지 않는다. 기기 확인은 아직 하지 않았다.

## 구현

- 화면 모양은 바꾸지 않았다. `tooltip`은 길게 누를 때 말풍선이 떠서 쓰지 않고, 아이콘을 `Semantics(label:)`로 감싸 버튼 노드에 이름을 합쳤다.
  `SvgIconButton`에 `semanticLabel`(선택)을 더하고, 아카이브·즐겨찾기·분류 필요·전체보기 카드의 비공개 IconButton 래퍼에도 같은 방식으로 이름을 넣었다.
- 카테고리 행 더보기(`CategoryRow`의 기본·보관 스타일)는 바깥 행 InkWell에 이름이 섞이지 않도록 `Semantics(container: true, button: true, label: '더보기')`로 감쌌다.
  진행 중인 카테고리(`mutationLabel` 있음)에서는 이름은 남고 누르기 동작만 빠진다.
- 붙인 이름

| 화면 | 버튼 | 이름 |
| --- | --- | --- |
| 홈 | 상단 검색 / 알림 | 검색 / 알림 |
| 상세 | 상단 뒤로 / 더보기 | 뒤로가기 / 더보기 |
| 아카이브(카테고리) | 상단 검색 / 톱니 / 폴더+ | 검색 / 카테고리 관리 / 카테고리 추가 |
| 아카이브(카테고리)·카테고리 관리 | 카테고리 행 더보기 | 더보기 |
| 즐겨찾기 | 상단 검색 / 톱니 | 검색 / 카테고리 관리 |
| 분류 필요 | 상단 뒤로 / 검색 / 톱니 | 뒤로가기 / 검색 / 카테고리 관리 |
| 콘텐츠 저장 | 상단 닫기 | 닫기 |
| 콘텐츠 카드(기본·전체보기) | 더보기 | 더보기 |

- "뒤로가기"·"카테고리 관리"·"카테고리 추가"는 기존 화면의 문구(`notification_list_screen.dart`, `category_content_widgets.dart`, `category_management_screen.dart`)를 그대로 썼다.
- 이름을 정해야 해서 붙이지 않은 버튼

| 화면 | 버튼 | 동작 |
| --- | --- | --- |
| 상세 | 날짜 줄 링크 버튼(`detail-original-button`) | 링크 콘텐츠는 원본 링크를 밖에서 열고, 스크린샷은 원본 이미지 시트를 연다 |
| 상세 | 하단 이전 / 다음 | 이전·다음 콘텐츠로 이동 |
| 상세·콘텐츠 카드 | 즐겨찾기 별 | 즐겨찾기 켜기·끄기(켜짐 상태 표현도 정해야 함) |
| 검색 | 검색어 지우기, 최근 검색어 삭제 | 버튼 역할도 없음 |
| 콘텐츠 저장 | 링크 입력 지우기 | 입력 지우기 |

## 검증

- 재현 테스트 `frontend/test/icon_button_semantics_test.dart`: 수정 전 코드에서 홈·상세·아카이브·즐겨찾기·분류 필요·저장·카드 8개가 이름 없음으로 실패했고,
  리뷰 S1 반영 전 카테고리 행 두 스타일(진행 중 포함 4개)·아카이브 목록·카테고리 관리 화면 6개가 이름 없음으로 실패했다. 수정 뒤 14개 모두 통과했다.
- `flutter analyze --no-pub`: 문제 없음.
- 전체 검증(`070ede7`): `VERIFY result=PASS scope=all checks=11 failed=0`. 앱 테스트 3194개 통과, pytest 2207 passed, 47 skipped.
  - `pytest skip: 46 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)`
  - `pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)`
- 미검증: iOS Simulator·Android Emulator `orca emulator ax`, 실제 VoiceOver·TalkBack, 이미지로 보인 섹션 제목의 원인(범위 밖).
- #202·#191 묶음의 최종 전체 검증 결과는 [미분류 표시 이름 예약의 묶음 최종 검증](2026-11-07-reserved-category-name.md#묶음-최종-검증-202191)에 있다.
