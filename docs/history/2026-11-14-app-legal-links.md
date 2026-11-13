# 마이 고객지원에 처리방침·약관 링크와 오픈소스 라이선스 화면 추가, 영문 표기 huturu로 (#349)

2026-11-14, 브랜치 `feat/app-legal-links`. 앱 0.5.3 후보.
시작 커밋 `fc969b4`, 구현 커밋 `a2fbddc`, 문서 커밋 `19efffa`(전체 검증·변경 후 촬영 기준).
이 기록을 더한 커밋은 문서만 바꾼다.

## 문제

- Google Play 비공개 테스트와 App Store 심사는 앱 안에서 개인정보처리방침에 갈 수 있어야 한다. 마이 → 고객지원에는 '문의하기'와 '앱 버전'뿐이었다.
- 앱에 든 오픈소스 패키지와 글꼴의 라이선스를 볼 화면이 없었다.
- 앱 코드에 옛 영문 표기 `hutureu`가 남아 있었다(공개 표기는 `huturu`).

## 사용자 결정

- 2026-11-14 선택: 약관 줄 "A. Figma대로 한 줄", 라이선스 "A. Flutter 기본 화면 사용", 계정 삭제 링크 "넣지 않음", 글꼴 "Pretendard만 넣기". 실패 문구는 기존 문의하기 형식을 따른다.
- 2026-11-14 구현 중 "추천대로": 이슈 조사와 달리 `Assets.character2Png`는 홈 빈 화면(`home_screen.dart`)·검색 결과 없음(`search_screen.dart`)·공통 빈 상태(`empty_state.dart`) 3곳에서 쓰인다. 나머지 그림 상수 4개(logo, character1, character2, character1Png)는 쓰이지 않는다. 이름 바꾸기는 그대로 하고, 변경 후 그림이 보이는 화면을 플랫폼마다 1장씩 찍는다.

## 구현 (`a2fbddc`)

- 고객지원 순서: 문의하기 → 이용약관 및 개인정보 → 오픈소스 라이선스 → 앱 버전. 줄은 기존 `MyListTile` 그대로다.
- 이용약관 및 개인정보: `https://huturu-app.github.io/privacy`를 `url_launcher` 외부 앱 모드로 연다. OS 거절(false)·예외면 '이용약관 및 개인정보를 열지 못했어요. 다시 시도해 주세요.'를 앱 공통 스낵바로 보인다. 열기 요청이 끝나기 전 같은 링크의 두 번째 누름은 무시한다(`contact_form.dart`의 링크별 공통 열기, 문의하기도 같은 함수를 쓴다).
- 오픈소스 라이선스: `showLicensePage`에 설치 버전(`AppInfo.version`)을 넘긴다. 앱 이름은 앱 루트 제목 '허투루'다. Pretendard 라이선스(`assets/fonts/Pretendard-LICENSE.txt`)는 `lib/app/font_licenses.dart`가 앱 루트 `initState`에서 한 번 등록한다.
- `hutureu` → `huturu`: 그림 5개 `git mv`(내용 그대로), `assets.dart` 경로 5개, 테스트 예시 주소 6곳.

## 테스트

먼저 테스트를 바꿔 실패를 본 뒤 고쳤다(로그는 로컬 `.utmp/ticket-349/partial-*.log`, 저장소에 넣지 않음).

| 이슈 회귀 | 테스트 | 수정 전 |
| --- | --- | --- |
| 1 순서(회원·게스트) | `my_support_group_test.dart` `<label> My support group has no notice row`, `my_menu_decision_test.dart` `approved management and support groups omit category and notices`, J01 비교 fixture 순서 | 실패 |
| 2 처리방침 한 번 열기 | `my_legal_links_root_test.dart` `my privacy row opens the policy once without a sheet`(연타, 외부 앱 모드) | 실패(줄 없음) |
| 3 열기 실패 | `my privacy row <os-false|exception> shows message and retries on tap` | 실패 |
| 4 실패 문구 폭 320 | `privacy failure message <1.0|1.3>x width 320 is not clipped` | 실패 |
| 5 라이선스 화면 | `my licenses row opens the license page and returns to My`('허투루'·버전·Pretendard 전문, 뒤로 두 번, 스크롤 위치) | 실패 |
| 6 줄 이름 넘침 | `320px Pretendard menu and version fit scale <1.0|1.1|1.2|1.3>` | 실패(줄 없음) |
| 7 접근성 | `privacy and license rows are separate tappable nodes`. '앱 버전'은 기존 `version … has no tap action or navigation` | 실패 |

- Pretendard 등록 호출을 빼면 5가 실패하는 것을 확인했다.
- 바꾼 기존 테스트는 이슈의 허용 표 안이다(`my_menu_decision_test`, `my_support_group_test`, `support/my_preview.dart`, `my_screen_figma_test`의 새 두 줄 동작 단언 추가, `fixtures/sample_contents.dart`).
- 로컬 `frontend/build/unit_test_assets`가 이름 바꾸기 전 그림으로 남아 있어, 처음 돌린 넓은 테스트 묶음에서 175개가 새 그림을 못 찾았다. 그 폴더를 지우고 다시 돌리니 통과했다. Flutter가 폴더 단위 에셋의 파일 이름 변경을 테스트 묶음에 다시 반영하지 않은 것으로, 코드 문제가 아니다(CI는 새로 받는다).

## 검토

검수(Codex, `.utmp/review-349.md`): Standards 0개, Spec 중간 1개.

- 반영(`19efffa`): 문서 갱신(frontend README, Figma 계획의 current/pending-16·43·DEC-06, 라이선스 '디자인 확인 필요' 항목, CHANGELOG)이 첫 커밋에 없었다.
- 문구 검토(better-writing 시험): 지적 없음.

## 검증

- `VERIFY result=PASS scope=all checks=11 failed=0`(`19efffa`).
  - CI App Validation 명령: `flutter pub get --enforce-lockfile`, `dart format --output=none --set-exit-if-changed lib test`(0 changed), `flutter analyze --no-pub`, `flutter test --no-pub`(+3511 All tests passed).
  - 백엔드: pytest 2640 passed, 49 skipped(48 `tests/deployment` Docker 복구 시험 조건, 1 `tests/integration` S3 주소 없음). 백엔드는 바꾸지 않았다.
- `git grep -n hutureu -- frontend` 0건. `assets.dart`의 새 경로 5개가 모두 실제 파일을 가리킨다.
- `git diff --check` 통과.

## 화면 확인

2026-11-14, iPhone 16 / iOS 18.6 Simulator(Simulator.app 없이 headless)와 `Medium_Phone` / Android 16 Emulator. 로컬 메모리 서버 대역(홈 비교용 데이터, 게스트 계정 표시)이며 운영 서버·실제 로그인은 쓰지 않았다. 처리방침 페이지는 실제 인터넷으로 열었다.
변경 전은 `fc969b4`의 앱 파일 4개(`clipback_app.dart`, `contact_form.dart`, `my_screen.dart`, `assets.dart`)로, 변경 후는 `19efffa`로 같은 촬영 진입 파일(`.utmp/ticket-349/state_preview.dart`)을 빌드했다. 두 빌드 모두 설치 버전(`0.1.0`, 저장소 `pubspec.yaml`)을 넘긴다.
Figma 기준은 J01 `111:4707`(375×842, 2026-11-14 00:50 KST 조회)이다.

| 상태 | iOS | Android |
| --- | --- | --- |
| 마이 고객지원 1.0배 | 변경 전 2줄 → 변경 후 4줄(문의하기·이용약관 및 개인정보·오픈소스 라이선스·앱 버전), 스크롤 없음 | 같음 |
| 마이 고객지원 1.3배(변경 후) | 4줄 모두 한 줄, 스크롤 없음 | 같음 |
| 이용약관 및 개인정보 누름 | Safari에 '허투루(huturu) 개인정보처리방침'(시행일 2026-11-14, 위쪽에 이용약관·계정·데이터 삭제 안내 링크). 상단 '허투루(으)로 돌아가기'로 같은 마이 복귀 | Chrome에 같은 페이지. 처음에는 Chrome 알림 안내 창이 덮어 'No thanks'로 닫았다(Chrome 첫 실행 안내). 뒤로 가기 두 번(첫 번째는 Chrome 탭 안내 말풍선을 닫음)으로 같은 마이 복귀 |
| 오픈소스 라이선스 | 'Licenses', '허투루', '0.1.0', 'Powered by Flutter'와 패키지 목록. 'Pretendard 1 license.'를 누르면 SIL OFL 1.1 전문. 머리 'Back' 두 번으로 마이 복귀 | 같음. 시스템 뒤로 가기 두 번으로 마이 복귀 |
| `character2Png`(변경 후) | 공통 빈 상태 위젯 단독 진입(`.utmp/ticket-349/asset_preview.dart`)에서 캐릭터 그림이 보인다. 앱 묶음에 `assets/figma/huturu-character-2.png`가 들어 있다 | 같음(APK 안 같은 경로) |

- `character2Png`는 '비었다고 확정하지 못한' 빈 상태(목록 오류 등)에서만 보여 대역 서버로 앱 화면을 만들지 못했다. 그래서 그 그림을 쓰는 실제 위젯 `EmptyStatePanel`을 앱 묶음으로 띄워 찍었다. 앱 흐름 안의 화면은 아니다.
- 열기 실패 스낵바는 시뮬레이터·에뮬레이터에서 실패를 만들 수 없어 찍지 않았다. 자동 테스트(회귀 3·4)로 확인했다.
- 라이선스 화면은 Figma 기준이 없어 변경 후만 찍었다([디자인 확인 필요](../figma-ui-alignment-plan.md#figma-pending-licenses)).
- 기기 화면(393×852, 411.4×914.3)과 Figma 프레임(375×842)의 크기·안전 영역 차이는 보정하지 않았다. Figma와의 남은 차이(공지사항 줄 숨김, 메뉴 14px, 라이선스 줄 추가)는 결정대로다.

### 증거(로컬, 저장소에 넣지 않음)

- 비교 이미지: `.utmp/ticket-349-screens/compare-{ios,android}.png`(변경 전·후·Figma).
- 원본·조건 JSON: `.utmp/ticket-349/screens/`.

## 범위 밖과 미검증

- 라이선스 화면 글자가 영어다(한국어 Material 번역 없음, 결정대로).
- RiaSans 글꼴 라이선스는 등록하지 않았다(사용자가 조건 확인 뒤 따로).
- 쓰이지 않는 그림 상수 4개(logo, character1, character2, character1Png)와 그 파일은 남겼다.
- VoiceOver·TalkBack 실제 음성과 실기기는 확인하지 않았다(이슈가 요구하지 않음).
