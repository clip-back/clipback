# 홈에서 Figma에 없는 "최근 카테고리" 영역 제거

최초 기록일: 2026-11-03 KST. 이슈 [#197](https://github.com/clip-back/clipback/issues/197), 시작 커밋 `8109eca`,
작업 브랜치 `fix/home-remove-recent-categories`. 콘텐츠가 없는 홈의 "저장 방법 보기" 버튼, 칩 결과 없음 화면의 디자인, 상단 문구는
[Figma 화면 맞춤 계획의 보류 항목](../figma-ui-alignment-plan.md#figma-pending-07)대로 범위 밖이다.

## 문제와 결정

- 홈 목록이 비면(저장한 콘텐츠 없음, 칩 결과 없음, 로딩 중, 오류) "최근 저장한 콘텐츠" 아래에 "최근 카테고리" 제목과 카테고리 두 줄이 나왔다.
  두 줄은 전체 카테고리의 앞 2개였고, 어느 줄을 눌러도 아카이브의 카테고리 탭이 열렸다. 날짜는 고정 문구 `2020. 3. 10. 오후 11:56`이었다(0.3.0 팀 테스트 제보 3건).
- Figma C01 `111:3584`와 C02 `111:3681`(2026-11-03 조회)에는 이 영역이 없다.
- 2026-11-03 사용자 결정: "최근 카테고리 영역은 없애주고". 어떤 상태에서도 이 영역을 그리지 않는다. 나머지 홈 구성은 그대로 둔다.

## 변경 내용

- `frontend/lib/features/home/home_screen.dart`: `HomeContentPanel`에서 최근 카테고리 영역을 지우고, 이 영역에만 쓰던 `hasSavedContent` 인자를 뺐다.
  패널 맨 아래 32px 여백은 콘텐츠가 있는 홈에도 있던 값이라 남겼다.
- `frontend/lib/shared/category/category_widgets.dart`: 앱에서 더 쓰이지 않는 `CategoryHomeRow`를 지웠다.
- 테스트·미리보기: `home_alignment_test.dart`에 상태 5개(콘텐츠 있음, 저장한 콘텐츠 없음, 칩 결과 없음, 로딩 중, 오류) 테스트를 넣었다.
  각 상태에서 "최근 카테고리"와 고정 날짜가 없고, 상단 안내·이번주 허투루 픽·최근 저장한 콘텐츠·칩과 상태별 목록 표시(카드, 빈 문구, 로딩, 오류 문구)가 남는지 본다.
  `scaled_navigation_layout_test.dart`의 `CategoryHomeRow` 전용 테스트와 `home_base_alignment_preview.dart`의 최근 카테고리 탭 확인 단계를 지웠다.
- [Figma 화면 맞춤 계획](../figma-ui-alignment-plan.md)의 DEC-07과 [figma-current-06](../figma-ui-alignment-plan.md#figma-current-06)에서 최근 카테고리 유지 기록을 지웠다.
- 이번 변경 전부터 쓰이지 않던 `ClipbackApi.listRecentCategories`와 백엔드 `/api/v1/categories/recent`는 그대로 두었다.

## 자동 검사

- 재현 테스트 실패 확인(`frontend/`에서 `flutter test --no-pub test/home_alignment_test.dart --plain-name "home has no recent categories"`):
  수정 전 코드에서 저장한 콘텐츠 없음·칩 결과 없음·로딩 중·오류 4개가 "최근 카테고리" 부재 단언에서 실패하고, 콘텐츠 있음은 통과했다.
- 수정 후 홈 관련 4개 파일(`home_alignment_test.dart`, `scaled_navigation_layout_test.dart`, `home_base_alignment_test.dart`, `top_safe_area_test.dart`) 89개 통과,
  `flutter analyze --no-pub` 문제 없음.
- 전체 검사: `python3 ~/.heoturu-agents/verify.py --log-dir .utmp/ticket-197`을 `23fc0ee`에서 한 번 돌렸다.
  `VERIFY result=PASS scope=all checks=10 failed=0`. `flutter test --no-pub` 2020개 통과(건너뜀 0),
  백엔드 pytest 1896개 통과·46개 건너뜀(Docker·운영자 이미지·S3 엔드포인트가 필요한 테스트, 이번 변경과 무관).

## 시뮬레이터·에뮬레이터 실행 (2026-11-03)

- 환경: iPhone 16 / iOS 18.6 Simulator, Android Emulator `Medium_Phone` / Android 16 / 1080×2400. 한 번에 하나만 띄웠다. 서버·로그인은 쓰지 않았다.
- 화면: [홈 기본 프리뷰](../../frontend/test/support/home_base_alignment_preview.dart)의 메모리 API(빈 홈은 콘텐츠 0개, 콘텐츠 홈은 4개)로
  실제 루트 앱을 띄우는 임시 진입 파일(커밋하지 않음)을 더해 debug 빌드했다. 메모리 API에 없는 주간 추천은 빈 목록으로 답해 "이번주 허투루 픽"은 화면에 없다.
  비교는 두 가지다.
  - 맨 아래 비교(`compare-ios.png`, `compare-android.png`): 진입 파일이 홈 세로 스크롤을 맨 아래로 내린 뒤 찍었다. 빈 홈은 변경 전 iOS에서만 스크롤 길이가 27pt라
    `scrollOffset`이 변경 전 27pt, 변경 후 0pt로 다르다. Android 빈 홈과 두 플랫폼의 콘텐츠 홈은 변경 전·후 모두 스크롤 길이가 0이라 0pt로 같다.
  - 맨 위 비교(`compare-ios-empty-top.png`): 최종 리뷰 지적으로 iOS 빈 홈만 변경 전·후 모두 `scrollOffset` 0에서 다시 찍었다.
    이 비교에서는 상단 안내부터 빈 문구까지 변경 전·후 위치가 같고, 변경 전에만 아래쪽에 "최근 카테고리"가 보인다.
  - 글자 배율은 iOS 맨 위 촬영에서 앱 안에서 1.0으로 읽었다(시뮬레이터 글자 크기 설정은 기본값). 맨 아래 촬영은 배율을 기록하지 않았고,
    두 기기 모두 글자 크기 설정을 바꾸지 않았다. 같은 촬영에서 앱 안에서 읽은 안전 영역은 위 59pt·아래 34pt(393×852pt)다. Figma 프레임은 375×910이고 상태 표시줄이 더 낮게 그려져 있어,
    같은 높이로 맞춘 비교 이미지에서 상단 위치가 앱과 다르다. 비교를 위해 원본 화면을 보정하지 않았다.
- 변경 전은 화면 파일 2개(`home_screen.dart`, `category_widgets.dart`)만 `8109eca`로 잠시 바꾼 빌드, 변경 후는 `23fc0ee` 빌드다.
  앱 안에서 읽은 "최근 카테고리" 글자는 변경 전 빈 홈에서 iOS·Android 모두 있었고, 변경 후 빈 홈과 콘텐츠 홈(변경 전·후)에서는 없었다.
- Android는 설치 뒤 기기에 있는 APK의 SHA-256이 해당 빌드 APK와 같은지 확인했다.
- iOS 빌드가 `frontend/ios/Runner.xcodeproj/project.pbxproj`의 `objectVersion`을 60에서 54로 바꿔 놓아, 빌드 뒤 원래대로 되돌렸다(커밋하지 않음).
- Orca 에뮬레이터 명령(`orca emulator attach·gesture·ax`)도 시험했다. 두 플랫폼 모두 `ax`가 허투루 앱의 문구를 읽었고,
  변경 전 빈 홈에서는 "최근 카테고리"와 두 줄을 찾고 변경 후에는 찾지 못했다. iOS에서 스와이프 한 번에 홈이 27pt 움직이는 것을 `ax` 좌표로 확인했다.
- 비교 자료는 저장소 밖 `.utmp/ticket-197-screens/`에 두었다(새 checkout에는 없다).
  `compare-ios.png`, `compare-android.png`(상태마다 변경 전·변경 후·Figma 기준, 맨 아래), `compare-ios-empty-top.png`(iOS 빈 홈, 맨 위),
  원본 스크린샷과 앱 안 상태 JSON, Orca `ax` 결과 `raw/`.
- 빈 홈에서 변경 후 화면에는 영역이 사라진 자리만큼 흰 패널이 짧아지고 그 아래 회색 배경이 보인다. 콘텐츠 홈은 변경 전부터 같은 모습이다.
  Figma C01·C02는 흰 패널이 하단 탭까지 이어진다. 이 차이는 이번 범위에서 고치지 않았다.

## 미검증 범위

- 실기기, 실제 서버, 주간 추천이 있는 홈에서는 확인하지 않았다.
- 칩 결과 없음·로딩 중·오류 상태의 화면은 찍지 않았다. 해당 상태는 자동 테스트로만 확인했다.
