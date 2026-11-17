# 공지에 사용 안내 글 2개 — 공지 상세, 마이 공지 줄, 홈 알림 버튼·허투루 픽 카드 (#420)

2026-11-17, 브랜치 `feat/notice-guides`. 시작 커밋 `03406d4`, 구현 커밋 `2c0f62c`, 검수 반영 커밋 `c3e226b`.

## 문제

- 처음 쓰는 사용자에게 사용법을 알려 주는 곳이 없었다. 공지 목록(K01)은 예제 제목 3개만 보이고 눌러도 열리는 글이 없었으며, 마이의 공지사항 줄은 #311로 숨겨 들어가는 길도 없었다. 서버 공지 API는 없다.
- 디자인 담당이 Figma에 사용 안내 공지 2개와 목록·상세 화면, 홈 "이번주 허투루 픽"의 활용법 카드를 그렸다(파일 `svNWsTFh8Ws1Mpt8XQIcrN`, 2026-11-17 17:22 KST 조회).

## 사용자 결정

이슈 #420 본문의 결정 1–6, 추가 결정 Q1–Q10("공지는 모두 추천대로 하자"), 추가 결정 2 R1–R4("추천대로").

- 서버 없이 앱 안 고정 공지 2개만 둔다(📌 "허투루 100% 활용법", 📌 "허투루 사용이 처음이라면?", 게시일 `2026. 11. 23`). 예제 공지와 옛 `NoticeSheet`는 지운다(결정 1·3·4, Q7·Q10).
- 마이 고객지원 맨 앞 공지사항 줄을 다시 보인다(결정 2).
- 홈 허투루 픽 끝에 노란 "공지사항 / 허투루 100% 활용법" 카드를 늘 두고, 누르면 활용법 상세가 열린다. 뒤로가기는 홈이며 홈 상태는 그대로다(결정 5, Q1–Q5).
- 공지 목록은 Figma `423:4464` 값, 상세는 `423:4520`·`425:4491` 서식이다(Q6). Figma 본문 중 앱과 다른 3곳은 고쳐 쓰고 "디자인 확인 필요"에 기록한다(Q8). 목록 행은 "고정 공지, 제목, 게시일" 버튼 하나로 읽는다(Q9).
- 홈 알림(종) 버튼은 공지 목록을 홈 위에 겹쳐 열고, 상세 → 목록 → 홈으로 돌아온다. 알림 화면 위젯은 진입 없이 남기고 루트 연결과 종 버튼의 시트 대체 경로는 지운다. 버튼 이름 "알림"은 그대로다(결정 6, R1–R4).

## 바꾼 것

- `frontend/lib/features/account/notices.dart`(새): 공지 상수 2개와 마지막 안내 줄. 목록·홈 카드·상세가 같은 상수를 쓴다.
- `frontend/lib/features/account/notice_list_screen.dart`: `423:4464` 값의 행(📌·게시일 위·제목·오른쪽 화살표, 행 최소 82·사이 5), 행 전체 버튼과 스크린리더 이름, 목록 스크롤 `PageStorageKey`. 헤더는 상세와 함께 쓰는 `NoticeHeader`로 뺐다.
- `frontend/lib/features/account/notice_detail_screen.dart`(새): 흰 배경, 헤더 뒤로가기만, 본문 좌우 24·위 8·아래 32·묶음 사이 28. 제목은 콘텐츠 상세 제목과 같은 `PretendardDetail` Bold 25, 나머지는 Pretendard. 줄 수 제한 없이 자연 줄바꿈하고 세로로 끝까지 스크롤한다.
- `frontend/lib/app/clipback_app.dart`: 새 경로 `AppRoute.noticeDetail`. 연 공지와 돌아갈 곳(목록 또는 홈), 홈에서 열었는지를 기억한다. 홈(종·카드)에서 연 목록·상세는 홈을 남긴 채 겹치는 기존 `IndexedStack` 둘째 칸(옛 알림 화면 자리)에 그려 홈 스크롤·추천 방문이 그대로 남는다. 마이에서 연 것은 마이로 돌아가고, 마이 ↔ 목록 ↔ 상세 사이 PageStorage 버킷을 유지한다. 열기·뒤로 콜백은 빌드 시점의 계정 세대·인증 시점을 잡는 기존 보호를 쓴다. `AppRoute.notificationList`와 그 연결을 지웠다.
- `frontend/lib/features/home/home_screen.dart`: `onOpenNotice`가 있으면 허투루 픽 끝에 공지 카드(133×120, `#FFD75C`, 테두리 없음, 모서리 8, 라벨 14·제목 16 두 줄 고정)를 그리고, 추천이 0개여도 섹션을 보인다. 카드는 추천 노출 측정 대상이 아니다. 종 버튼의 `NotificationSheet` 대체 경로를 지웠다.
- `frontend/lib/features/account/my_screen.dart`: 고객지원 맨 앞 공지사항 줄(`onOpenNotices`). `settings_sheets.dart`에서 `NoticeSheet`·`mockNotices` 삭제.
- 문서: `frontend/README.md` 마이 메뉴 절, `docs/figma-ui-alignment-plan.md`의 `figma-current-06`·`-16`·`-17`·`-42`, `figma-pending-06`·`-11`·`-16`·`-17`·`-42`와 "디자인 확인 필요" 새 항목 2개(`figma-pending-notice-wording`, `figma-pending-bell-destination`), `CHANGELOG.md` 미배포 추가 한 줄.
- 새 테스트 `frontend/test/notice_guides_test.dart`(25개, 실제 Pretendard): 공지 데이터와 Q8 문구, 목록 스크린리더·폭 320/375 × 배율 1.0/1.3 줄바꿈, 상세 서식·간격, 두 글 × 폭 × 배율 끝까지 스크롤, 상세 스크린리더 순서, 헤더·OS 뒤로, 홈 카드 크기·글자·말줄임·탭·노출 0, 루트 흐름 3개(마이 → 목록 → 상세 → 마이, 종 → 목록 → 상세 → 목록 → 홈, 카드 → 상세 → 홈).

## 바뀐 기존 테스트

이슈 허용 표의 "바뀜" 행 범위에서 고쳤다.

| 테스트 | 바꾼 것 | 근거 |
| --- | --- | --- |
| `my_support_group_test`·`my_menu_decision_test`·`support/my_preview.dart` | 고객지원 목록 맨 앞에 공지사항, 줄 수 4 → 5, "공지 없음" 단언 뒤집기와 이름 | 허용 표, 결정 2 |
| `notice_list_figma_test`·`fixtures/notice_alignment_fixture.dart`·`notice_list_content_test` | 공지 2개·`423:4464` 판정·누르면 상세. 낮은 화면 높이 360 → 250(공지 2개는 360에서 스크롤되지 않음) | 허용 표, 결정 3·Q6 |
| `phone_width_test` | 새 생성 인자, 상세 폭 행 추가, 종 → 공지 목록 화면 이름. 두 시트 행이 빠져 빈 반복이 된 "auxiliary sheets" 테스트 삭제 | 허용 표, Q10·R3 |
| `weekly_root_test`·`weekly_one_visit_test` | 추천 실패·빈 응답·시간 초과 때 섹션 + 공지 카드만 보임, 알림 대신 공지 목록에서 돌아옴 | 허용 표, Q2·R1 |
| `weekly_root_test` 104행 | `find.text('공지사항')` findsNothing → findsOneWidget | 허용 표 밖 1건, 감독 승인(결정 5·Q1·Q2로 홈에 카드가 생김) |
| `notification_navigation_test`·`system_back_navigation_test`·`notification_list_figma_test` | 찾는 화면을 공지 목록으로, C03 판정은 화면 단독 렌더로 | 허용 표, R1·R3 |
| `support/notice_alignment_preview.dart` | 옛 시트 경로 삭제, 공지 2개 상세 왕복 기록 | 허용 표(삭제된 데이터를 참조해 컴파일에 필요) |

## 검수

검수-420(`2c0f62c`): Standards 0, Spec 낮음 1. `c3e226b`에서 반영했다.

- 낮음: `frontend/README.md`가 홈 카드로 연 상세의 뒤로가기도 목록 경유로 적었다 → "종 버튼으로 열면 상세 → 목록 → 홈, 카드로 열면 상세 → 홈"으로 나눴다. 앱 동작 변경 없음.

## 검증

- 전체 검증(로컬, HEAD `c3e226b`, 작업 트리 clean): `VERIFY result=PASS scope=all checks=12 failed=0`. app 단계(pub-get·format·analyze·test)가 이슈 완료 조건의 앱 세 명령에 해당하며 앱 테스트 +3889 모두 통과. 서버 pytest 2751 passed, 49 skipped.
  - `pytest skip: 48 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)`
  - `pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)`
- 원격 CI는 실행하지 않았다(push 전).
