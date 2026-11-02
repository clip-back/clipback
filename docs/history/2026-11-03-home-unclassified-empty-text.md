# 홈 미분류 칩의 빈 화면 문구에서 "콘텐츠" 중복 제거

최초 기록일: 2026-11-03 KST. 이슈 [#189](https://github.com/clip-back/clipback/issues/189), 시작 커밋 `8592ffb`,
작업 브랜치 `fix/home-unclassified-empty-text`. 홈 필터 결과 없음 화면의 디자인과 상단 문구·"저장 방법 보기"·최근 카테고리는
[Figma 화면 맞춤 계획의 보류 항목](../figma-ui-alignment-plan.md#figma-pending-07)대로 범위 밖이다.

## 문제와 결정

- 홈에서 "분류가 필요한 콘텐츠" 칩을 골랐는데 해당 콘텐츠가 없으면 빈 화면 문구가 "분류가 필요한 콘텐츠 콘텐츠가 없어요"로 나왔다(0.3.0 팀 테스트 제보).
  홈의 필터 결과 없음 문구는 칩 이름 뒤에 "콘텐츠가 없어요"를 붙이는데, 서버의 `미분류` 카테고리는 앱에서 이름이 "분류가 필요한 콘텐츠"로 바뀌어 들어온다.
- 아카이브는 같은 경우를 이미 이름(`catUncategorized.name`)으로 판별해 "분류가 필요한 콘텐츠가 없어요"로 보여 준다.
  이슈의 수정 방향대로 홈도 같은 기준을 쓴다. 다른 카테고리는 `<이름> 콘텐츠가 없어요` 그대로다.
- 티켓 리뷰에서 일반 카테고리의 이름을 "분류가 필요한 콘텐츠"로 지으면 그 카테고리도 미분류 문구가 나온다는 지적이 나왔다(이름 대신 미분류 카테고리 ID로 판별하자는 제안).
  2026-11-03 사용자 결정: 반영하지 않고 지금대로 간다. 같은 이름 카테고리 문제(홈 칩 선택·아카이브 판별 포함)는 별도 이슈로 다룬다.

## 변경 내용

- `frontend/lib/features/home/home_screen.dart`: `HomeFilteredEmptyContent`가 칩 이름이 `catUncategorized.name`이면 "분류가 필요한 콘텐츠가 없어요",
  아니면 `'$label 콘텐츠가 없어요'`를 보여 준다.
- `frontend/test/home_alignment_test.dart`: `_panel` 도우미에 `categories` 인자(기본값은 기존 목록)를 더하고 테스트 2개를 넣었다.
  미분류 칩에서 결과가 없으면 `HomeFilteredEmptyContent` 안에 "분류가 필요한 콘텐츠가 없어요"가 하나 있고 "콘텐츠 콘텐츠"는 없다.
  여행 칩에서는 "여행 콘텐츠가 없어요"가 그대로 나온다.

## 자동 검사

- 재현 테스트 실패 확인(`frontend/`에서 `flutter test --no-pub test/home_alignment_test.dart --plain-name 'filtered empty category'`):
  수정 전 코드에서 미분류 테스트가 실패하고 여행 테스트는 통과했다.
- 수정 후 `flutter test --no-pub test/home_alignment_test.dart` 37개, `test/feed_pagination_test.dart` 67개 통과, `flutter analyze --no-pub` 문제 없음.
- 전체 검사: `python3 ~/.heoturu-agents/verify.py --log-dir .utmp/ticket-189`을 `674ad8a`에서 한 번 돌렸다.
  `VERIFY result=PASS scope=all checks=10 failed=0`. `flutter test --no-pub` 2021개 통과(건너뜀 0),
  백엔드 pytest 1896개 통과·46개 건너뜀(Docker·운영자 이미지·S3 엔드포인트가 필요한 테스트, 이번 변경과 무관).

## 시뮬레이터·에뮬레이터 실행 (2026-11-03)

- 환경: iPhone 16 / iOS 18.6 Simulator, Android Emulator `Medium_Phone` / Android 16(API 36) / 1080×2400 / 420dpi.
  한 번에 하나만 띄웠다. 서버·로그인은 쓰지 않았다.
- 화면: [홈 기본 프리뷰](../../frontend/test/support/home_base_alignment_preview.dart)의 메모리 API(콘텐츠 4개, 서버 `미분류` 카테고리에 속한 콘텐츠 0개)로
  실제 루트 앱을 띄우는 임시 진입 파일(커밋하지 않음)을 더해 debug 빌드했다. 메모리 API에 없는 주간 추천은 빈 목록으로 답했다.
  진입 파일이 칩 목록의 "분류가 필요한 콘텐츠" 칩에 포인터 이벤트를 넣고, 결과 없음 화면이 화면 가운데에 오게 스크롤한 뒤 찍었다. OS 입력 장치로 누른 것은 아니다.
- 변경 전은 화면 파일만 `8592ffb`로 잠시 바꾼 빌드, 변경 후는 `674ad8a` 빌드다. 앱 안에서 읽은 결과 없음 문구는
  변경 전 iOS·Android 모두 "분류가 필요한 콘텐츠 콘텐츠가 없어요", 변경 후 모두 "분류가 필요한 콘텐츠가 없어요"였다. 선택된 카테고리는 두 빌드 모두 서버 `미분류`였다.
- Android는 설치 뒤 기기에 있는 APK의 SHA-256이 해당 빌드 APK와 같은지 확인했다.
  에뮬레이터 저장 공간이 부족해 변경 전 앱을 지운 직후에는 변경 후 APK 설치가 실패했고(그때는 촬영하지 않음), 에뮬레이터를 다시 켠 뒤 설치했다.
  부팅 직후 뜬 시스템 UI 응답 없음 알림창이 문구를 가린 화면은 버리고, 알림창을 닫은 뒤 다시 찍었다.
- 비교 자료는 저장소 밖 `.utmp/ticket-189-screens/`에 두었다(새 checkout에는 없다).
  `compare-ios.png`, `compare-android.png`(왼쪽 변경 전·오른쪽 변경 후), 원본 스크린샷과 앱 안 문구 JSON `raw/`.
- Figma 기준 화면은 없다. 홈 필터 결과 없음은 전용 확정 노드가 없는 보류 항목이라([figma-pending-07](../figma-ui-alignment-plan.md#figma-pending-07))
  변경 전·후 2장으로 비교했다. 문구만 바뀌고 배치는 바뀌지 않았다.

## 미검증 범위

- 실기기, 실제 서버의 미분류 카테고리, OS 입력 장치로 누르는 실제 탭에서는 확인하지 않았다.
- 같은 이름의 일반 카테고리에서 나오는 문구는 확인하지 않았다(사용자 결정으로 별도 이슈).
