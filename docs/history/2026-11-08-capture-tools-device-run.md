# 기기 촬영 도구 safe_area_device_check·category_archive_preview 끝까지 실행 (#292)

2026-11-08, 시작 커밋 `de31a94`(main) 기준으로 구현하고 티켓 리뷰, 전체 검증, 두 플랫폼 기기 실행까지 마쳤다.
코드 커밋은 `ded4ffe`·`cc7d657`이고, 전체 검증과 최종 기기 실행의 기준 코드도 `cc7d657`이다. 이후 커밋은 문서만 바꿨다.
바꾼 코드는 테스트 지원 코드(`frontend/test/support/`)뿐이다. 앱 코드·화면·위젯 테스트 기대값은 바꾸지 않았다.

## 구현

- `category_archive_preview.dart`
  - 미분류(99)는 `unclassified-back`, 일반 카테고리(101)는 `category-content-back-hit`로 뒤로 간다. #273 전부터 99에서 null 검사로 실패했다.
  - 검색 '취소' 탭 뒤 `SearchScreen`이 트리에서 빠질 때까지 최대 20프레임 기다린 뒤 "Search close failed"를 검사한다.
- `safe_area_device_check.dart`
  - 01_home은 `home-header`를 재고 top = 안전 영역 + 8, 높이 56을 기대한다(위젯 테스트와 같은 기준).
  - 홈 스크롤은 `home-scroll` 안의 세로 Scrollable을 쓴다. 판정은 `checkHomeScroll`이 한다.
    - 범위(`maxScrollExtent`)가 0이면 "이 화면 크기에서 스크롤 없음"과 측정값을 결과 줄 `note="…"`와 `report.json`의 `notes`에 남기고 넘어간다.
    - 범위가 있으면 실제 스크롤이 0보다 커야 하고, 머리 top이 안전 영역 + 8 − 스크롤 양(±0.5)이어야 한다. 아니면 실패한다.
  - 05_search는 top = 안전 영역 + 16, 높이 44를 기대한다.
  - 10번은 `management-add`의 `IconButton`으로 카테고리 시트를 열어 끝까지 검사·촬영한다.
  - 관리 화면 뒤로 가기 뒤에는 마이가 아니라 아카이브로 돌아온 것을 기다린다.
  - 그 밖의 화면 기대값(03·04·06·07·08·09·11·12·14, 원본 이미지 시트, 랜덤 드래그)은 그대로다.
- `safe_area_preview.dart`(이 도구 전용 HTTP 대역): `GET /recommendations/weekly`(3개)와 `POST /recommendations/exposures`에 답한다.
  대역이 주간 추천에 답하지 않아 홈 내용이 짧아졌고, 그래서 iOS에서도 홈 스크롤 범위가 0이었다. 이 대역을 import하는 곳은 `safe_area_device_check.dart` 하나다.
- [프론트 개발 문서](../frontend/development.md#ios-simulator-키보드-설정)에 홈 스크롤 note 설명과 iOS Simulator 키보드 설정 방법을 적었다.
  설정을 끄기 전 원래 값(1·0·키 없음)을 기록하고, 실행 뒤 YES·NO·delete 중 원래 값에 맞는 명령으로 되돌린 다음 다시 읽어 비교한다.

## 사용자 결정

| 항목 | 결정 원문 | 적용 |
| --- | --- | --- |
| 진행 방식 | "이슈 하나로 고치기 (Recommended)" | 1·2를 이 이슈에서 고치고 3·4는 원인부터 확인한다. `frontend/test/support/`만 수정 |
| iOS 키보드 검사(4) | "(가) 안내에 설정 적기" | 실행 안내에 시뮬레이터 설정을 적었다. 도구의 `viewInsetsBottom > 0` 검사는 그대로다 |
| Android 홈 스크롤 | "범위 0이면 기록 후 통과" | 이슈 원문 "스크롤 양이 0이면 실패"를 범위가 있을 때로 좁혔다. 범위 0이면 기록한다. Medium_Phone은 그대로 쓴다 |
| 기기 차례 확인 | "잠금 주인 예외 명시" | 기기 잠금 주인은 `busy.sh` 출력이 자기가 띄운 qemu-system·시뮬레이터뿐일 때만 진행한다. `busy.sh`는 고치지 않았다 |

## 3·4 원인 확인

- 3. iOS 검색 닫기 실패: 도구 결함이다.
  - '취소' 탭 직전 검색 route는 진입 전환이 끝난 상태였다. 탭 위치의 hit test 경로에 '취소' 글자와 `TextButton`이 모두 있었고, IgnorePointer·AbsorbPointer는 없었다.
  - 탭 뒤 `onClose`가 불렸다(`searchBack` 기록). 원래 검사 시점에 route는 닫힘 전환 중이었다(`AnimationStatus.reverse`, 값 0.233, iOS 전환 500ms). 그 뒤 두 번의 확인 안에 화면이 빠졌다.
  - Android는 같은 단계를 통과했다. 시간만 늘리지 않고 화면이 빠질 때까지 기다리도록 고쳤다.
- 4. iOS `create_keyboard_input` 실패: 시뮬레이터 환경 때문이다.
  - 실패 시 포커스와 입력값은 맞았고 `viewInsetsBottom`만 0.0이었다.
  - 시뮬레이터 안 `com.apple.keyboard.preferences`가 `HardwareKeyboardLastSeen = 1`, `AutomaticMinimizationEnabled = 1`이었다.
  - 같은 시뮬레이터에서 `AutomaticMinimizationEnabled`만 NO로 바꾸고 재부팅하자 키보드 높이가 336.0이 됐고 `/run`이 끝까지 통과했다. Android는 원래 통과했다.
  - 이 Mac의 Xcode 27.2에는 Simulator.app이 없어 시뮬레이터를 헤드리스로 띄웠다.

## 리뷰

- 티켓 리뷰(`de31a94...cc7d657`): Standards 0건, Spec 낮음 1건, 실행 보조 파일 중간 1건. 둘 다 반영했다.
  - 낮음: 문서의 복원 명령이 늘 YES였다. 원래 값 1·0·키 없음 세 경우의 복원 명령과 복원 뒤 읽어 비교하는 방법을 적었다.
  - 중간: 기기 차례 확인 도우미(작업 폴더, 비추적)가 `busy.sh` 실행 실패를 빈 출력, 즉 쉬는 상태로 보고 진행했다.
    종료 코드·stdout·stderr를 남기고, 0 + 빈 출력만 쉬는 상태로 본다. 1 + "PID 이름" 목록은 자기 기기 예외를 검사하고, 그 밖은 중단하도록 고쳤다.
    실패 코드(1 + 빈 출력, 3), 실행할 수 없는 명령, stderr, 자기 기기와 Gradle이 섞인 출력, 다른 잠금, verify, 모르는 줄을 대역 명령으로 재현해 각각 중단·대기를 확인했다.
  - 리뷰가 확인한 사실: `card_review_safe_area_preview.dart`는 자체 대역을 쓴다. 작업 중 "공유 대역을 쓴다"고 적은 판단은 파일 이름 검색이 주석에 걸린 오탐이었다.

## 검증

- 경계 시험(작업 폴더, 비추적): `checkHomeScroll`에서 범위 0은 note와 값을 남기고 통과한다. 범위 69·스크롤 0과 머리 불일치는 실패하고, 머리 0.4 차이는 통과한다(4개).
  판정 세 줄을 각각 바꾼 변형 3개는 모두 해당 시험에서 실패했다.
- 전체 검증(`cc7d657` + 미커밋 `docs/frontend/development.md`): `VERIFY result=PASS scope=all checks=11 failed=0`.
  pytest 2320 passed, 47 skipped. 앱 테스트 3368개 통과.
  - `pytest skip: 46 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)`
  - `pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)`
  - verify 앱 단계가 앱 CI와 같은 4개 명령이다: `flutter pub get --enforce-lockfile`, `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze --no-pub`, `flutter test --no-pub`.
- 기기 실행(`cc7d657`, 메모리 HTTP 대역과 앱 안 합성 포인터·텍스트 입력. 운영 서버·실제 OAuth·실기기·사람의 탭은 아니다)
  - 기기:
    - iOS: iPhone 16 Simulator(`C8B8639A-FB99-4C2F-9544-96F9B8B94D43`), iOS 18.6, 논리 393×852, 안전 영역 59.
    - Android: `Medium_Phone` Emulator(`emulator-5554`), Android 16 / API 36, 1080×2400, 논리 411.4×914.3, 안전 영역 24.
  - 명령은 `frontend/`에서 실행했다.
    - `flutter run --no-pub -d <ID> -t test/support/safe_area_device_check.dart`
    - `flutter run --no-pub -d <ID> -t test/support/category_archive_preview.dart --dart-define=CATEGORY_ARCHIVE_PHASE=after`
    - 뒤의 도구는 Android만 `adb -s emulator-5554 forward tcp:8767 tcp:8767`을 한 뒤 `curl -s http://127.0.0.1:8767/run`을 실행했다.

| 도구 | iOS | Android |
| --- | --- | --- |
| safe_area_device_check | `SAFE_AREA_DEVICE PASS screens=15`, 10번 포함. 01_home top 67·높이 56. 홈 범위 69, 실제 스크롤 69, 머리 top −2(= 67 − 69). 05_search top 75·높이 44. 10번 키보드 인셋 336 | `SAFE_AREA_DEVICE PASS screens=15 note="home: 이 화면 크기에서 스크롤 없음 (max=0.0 viewport=802.2857142857143 headerTop=32.0)"`, 10번 포함. 01_home top 32·높이 56. 05_search top 40·높이 44. 10번 키보드 인셋 336.38 |
| category_archive_preview `/run` | 오류 없음. `report.json` `passed: true`, 기록 28개(검색 왕복, `open_category_99`·`101`, `create_keyboard_input` 인셋 336 포함) | 오류 없음. `passed: true`, 기록 27개(같은 항목, 인셋 336.38) |

- iOS 키보드 설정 근거
  - 실행 전 원래 값 1을 기록했다. NO로 바꾸고 재부팅한 뒤 읽은 값은 0이었다.
  - 실행 뒤 YES로 되돌리고 재부팅해 읽은 값은 1(원래 값과 같음)이었다. plist도 첫 확인 때 백업과 같았다(자동 갱신 시각 1개 제외).
- 수정 전 재현(`de31a94` 도구 사본)
  - safe_area_device_check는 두 플랫폼 모두 01_home에서 실패했다(iOS top 67.5·높이 56, Android 32.5·56. 기대는 안전 영역·64).
  - category_archive_preview는 iOS가 "Search close failed", Android가 1206행 null 검사에서 실패했다.
- 화면: 두 플랫폼 01_home·05_search·10_category_sheet_keyboard PNG를 열어 각 상태를 확인했다.
  - 도구는 앱 화면만 그리므로 OS 키보드는 PNG에 없다. 키보드 높이는 측정값으로 확인했다.
  - 앱 화면은 바뀌지 않아 변경 전·후·Figma 비교는 하지 않았다.
- 기기 차례: 기기 잠금을 잡고 실행했다. 단계마다 `busy.sh` 원문을 남겼다. iOS는 빈 출력(종료 0), Android는 직접 띄운 qemu PID 하나뿐(종료 1)일 때만 진행했다.
  끝난 뒤 시뮬레이터 종료, `adb emu kill`, `./gradlew --stop`("1 Daemon stopped"), 잠금 반납, `busy.sh` 빈 출력을 확인했다.
- 미검증: PR의 앱 CI(app-validation)는 push·PR 전이라 돌리지 않았다.
  문서의 "키가 없으면 does not exist 오류" 경우는 대역 `simctl`로만 시험했다. 이번 시뮬레이터에는 키가 있었다.

## 범위 밖 발견

- 두 도구 실행 화면 위쪽에 "공유 저장을 준비하지 못했어요. 다시 시도해 주세요." 알림이 떠 있다. 05_search에서는 검색 머리를 가린다(측정값에는 영향 없음). 원인은 확인하지 않았다.
- `busy.sh --owner`는 자기 기기 잠금만 빼고, 그 주인이 띄운 에뮬레이터 프로세스는 여전히 실행 중으로 낸다. 회고 제안으로 남겼다.
