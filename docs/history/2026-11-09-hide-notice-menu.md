# 운영 공지 준비 전까지 마이의 공지사항 메뉴 숨기기 (#311)

2026-11-09, 브랜치 `fix/related-content-and-notice-menu`. 팀 피드백 시트 30번(앱 0.3.0) 대응이다. 커밋 `a6d8fb9`, 검수 반영 `b4bcde2`.

## 사용자 결정

- 2026-11-09 "메뉴 숨김 (Recommended)": 운영 공지 기능이 준비될 때까지 마이의 공지사항 메뉴를 숨긴다.
- 같은 날 "줄과 그 연결만 지움 (Recommended)": 마이의 줄과 그 줄만 쓰던 연결(매개변수·앱 루트 전달)만 지운다. 공지 화면·경로·예제 데이터는 남긴다. 테스트는 화면을 직접 띄우도록 연결만 고치고, 마이 → 공지 → 뒤로 테스트 하나는 삭제한다.
- 조율 판단(2026-11-09, 사용자 확인 대기): 아래 접근성 노드 분리.

## 구현

- `frontend/lib/features/account/my_screen.dart`: 고객지원의 '공지사항' 줄, `onOpenNotices` 매개변수, `NoticeSheet` 대체 경로를 지웠다. 고객지원은 '문의하기 → 앱 버전'이다.
- `frontend/lib/app/clipback_app.dart`: `MyScreen`에 넘기던 `onOpenNotices` 한 줄을 지웠다.
- 접근성 노드 분리: 공지 줄을 지우자 고객지원 그룹에서 누를 수 있는 줄이 '문의하기' 하나만 남아, '문의하기 · 앱 버전 · 버전 값'이 탭 가능한 접근성 노드 하나로 합쳐졌다(기존 `my_menu_decision_test.dart`의 앱 버전 테스트 2개가 잡음). `MyListTile`을 `Semantics(container: true)`로 감싸 줄마다 노드를 따로 둔다.
  - 위젯 테스트(320×812 회원)의 노드: 변경 전 `dd34e0e`은 알림 설정·앱 권한·앱 버전·공지사항·문의하기(앱 버전이 그룹 노드에 붙어 공지사항보다 먼저 읽힘), 줄만 지운 상태는 알림 설정·앱 권한·'문의하기 앱 버전'(탭 가능), 분리 뒤는 알림 설정·앱 권한·문의하기·앱 버전(탭 없음). 다른 줄의 이름·탭 동작은 변경 전과 같다.
  - 실기기 VoiceOver·TalkBack 음성은 확인하지 않았다.
- 진입 없는 코드(지우지 않음): `NoticeListScreen`, `AppRoute.noticeList`와 앱 루트의 공지 화면 생성·`_noticeNavigation`·`_myNoticePageStorageBucket`, `NoticeSheet`, `mockNotices`, 공지 미리보기 도구 `frontend/test/support/notice_alignment_preview.dart`(마이에서 공지 줄을 눌러 들어가므로 진입 단계에서 멈춘다).

## 테스트

- 새 회귀 테스트 `frontend/test/my_support_group_test.dart`: 회원·게스트 그룹([알림 설정, 앱 권한], [문의하기, 앱 버전], '공지사항' 없음), 끝까지 스크롤(앱 버전이 마지막 줄), 줄 크기(네 줄 높이 같음, 고객지원 그룹 높이·폭 = 관리 그룹). 수정 전 코드에서는 4개 모두 실패했다.
- 이슈 허용 범위 안에서 고친 기존 테스트: `my_menu_decision_test.dart`(고객지원 기대값·이름), `my_screen_figma_test.dart`(공지 시트 항목 삭제, "three sheets"), `test/support/my_preview.dart`(승인 순서와 공지 진입 단계), `notice_list_figma_test.dart`(공지 목록 화면을 직접 띄움, 쓰지 않게 된 공유 채널 mock 정리), `phone_width_test.dart`(공지 목록을 마이 위에 직접 띄워 폭 확인), `session_restore_test.dart`(계정 관리 왕복만으로 통계 호출 수 2 → 3 → 4).
- 삭제: `frontend/test/notice_navigation_test.dart`(마이 → 공지 → 뒤로 이동 4개). 공지 진입을 되살릴 때 git에서 복원한다.

## 검토

- Codex 검수(`dd34e0e..a6d8fb9`, #310과 함께): 낮음 2건을 모두 반영했다(`b4bcde2`).
  - `notice_list_figma_test.dart`가 앱 루트를 띄우지 않게 되면서 쓰지 않게 된 공유 채널 mock을 지웠다.
  - 계획 문서 pending-17에 공지 목록의 진입이 지금 없다는 문장을 더했다.

## 검증

- 전체 검증(#310·#311 함께, 코드는 `b4bcde2`와 같은 작업 트리): `VERIFY result=PASS scope=all checks=11 failed=0`. 앱 테스트 3456개 통과, pytest `2330 passed, 47 skipped`.
  - skip: `tests/deployment` 46개(Docker 복구 시험 환경 변수·이미지 필요), `tests/integration` 1개(S3 이미지 시험 주소 필요).
- 기기 확인(2026-11-09, 로컬 메모리 데이터의 게스트 계정): iPhone 16 / iOS 18.6 Simulator, Medium_Phone / Android 16 Emulator.
  - 마이 맨 위(scrollOffset 0, 스크롤 범위 0)에서 변경 전 `dd34e0e`은 고객지원 공지사항·문의하기·앱 버전, 변경 후는 문의하기·앱 버전이다. 줄 높이·간격은 같고 그룹만 한 줄 짧아졌다. 두 플랫폼 같음.
  - 문의하기를 누르면 문의 시트가 열렸다(두 플랫폼).
  - 이슈 촬영 범위는 회원 로그인 데이터였으나 촬영용 메모리 서버가 게스트 계정을 준다. 회원·게스트의 메뉴 줄은 위젯 테스트로 확인했다.
  - Figma 기준 J01 `111:4707`(2026-11-09 03:47 KST 조회)과의 차이: 공지사항 줄 없음(이번 결정), 약관 줄 없음·메뉴 글자 14px(기존 current-16), 기기 화면과 프레임(375×842) 크기 차이는 보정하지 않았다.
