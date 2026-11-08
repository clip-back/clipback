# 주간 추천 방문 상태를 HomeWeeklyViewModel로 옮기기 (#294, #295, #296)

2026-11-08, 상위 스펙 #294의 두 티켓을 브랜치 `refactor/app-root-flow-state`에서 진행했다.
#295는 앱 코드를 바꾸기 전에 동작 고정 테스트를 추가했고(커밋 `02e5240`), #296은 앱 루트 View가 들고 있던 주간 추천 방문 상태를 새 `HomeWeeklyViewModel`로 옮겼다(커밋 `11d8ff8`).
그보다 먼저 용어집에 **주간 추천 방문**을 더했다(커밋 `964a054`, 회의 Q6).
최초 이력 추가 커밋 `4a1f501`은 문서만 바꿨다. 최초 전체 검증과 기기 실행의 기준 코드는 `11d8ff8`이며, 승인 뒤 main 병합의 최종 전체 검증은 아래에 별도로 기록한다.
사용자에게 보이는 동작은 바뀌지 않으므로 CHANGELOG `미배포`에는 적지 않았다.

## 사용자 결정

- 2026-11-08 기획 회의 Q1–Q11 "추천대로": 범위는 주간 추천 방문 하나다. 판정은 함수로 받아 그때그때 읽고(Q7), `ApiRequestScope`는 씌우지 않는다(Q3).
  계정 세대는 `AppViewModel.accountGeneration`을 그대로 쓴다. ViewModel만 따로 검사하는 단위 테스트는 두지 않는다(Q8). README는 한 문장만 고치고(Q9), ADR은 없다.
- 같은 날 스펙 리뷰 "추천대로": W7(인증 갱신 뒤 재전송)과 W8·W9·W8′(앱 제거 뒤 응답·예약)을 고정 대상에 더했다. 방문 끝에서 상태를 먼저 비운 뒤 `endWeeklyVisit`을 부르고, 실패 안내는 효과를 내기 전에 비우도록 순서를 바로잡았다.
- 고정 테스트와 기존 회귀 파일 7개는 #296에서 고치지 않는다(예외 없음).
- 화면 변화가 없어 변경 전·후·Figma 3면 비교와 영상은 하지 않는다(Q5). iOS Simulator와 Android Emulator에서 홈 카드 표시 → 카드 탭 → 그 카테고리 보관함 → 홈 복귀 카드 표시를 1회씩 확인하고 스크린샷을 남긴다.

## 구현 (#296)

- `frontend/lib/features/home/view_models/home_weekly_view_model.dart`(새 파일): 공통 `ViewModel` 기반. 생성자는 `ContentRepository`와 함수 네 개(`isHome`·`isVisible`·`accountGeneration`·`afterFrame`)를 받는다. 메서드는 `sync()`·`visibilityChanged()`·`exposureAction()`·`selectionAction(open)`, 읽기 값은 `items`다. Repository 변경 알림은 받지 않는다.
  - 방문 끝: 홈이 아니거나 계정 세대가 다르면 방문 토큰·진행 중 요청·미뤄 둔 실패를 먼저 비우고 `endWeeklyVisit`을 부른다.
  - 방문 시작: 계정 세대를 기억하고 `afterFrame`으로 첫 프레임 뒤 불러오기를 예약한다. 예약된 불러오기는 그때도 같은 방문일 때만 실행한다.
  - 실패 안내: 보이고 같은 방문일 때만, 미뤄 둔 실패를 비운 뒤 `emitEffect(MessageEffect(...))`로 낸다. 재시도는 같은 방문만 확인한다.
  - 노출·선택 콜백은 만들 때의 방문을 잡고, 호출할 때 방문과 보임을 다시 확인한다. 선택은 지금 Repository 값에 ID와 카테고리 ID가 모두 같은 항목이 있을 때만 `open`을 부른다.
  - 예약 콜백과 늦은 결과 처리는 dispose 여부를 먼저 본다.
- `frontend/lib/app/app_dependencies.dart`: 선택 인자 `weeklyHome`·`weeklyVisible`(넘기지 않으면 `() => false`). 홈 ViewModel 옆에서 만들어 `featureViewModels`에 넣는다. `afterFrame`은 호출할 때 `WidgetsBinding`을 읽는다.
- `frontend/lib/app/clipback_app.dart`: 방문 필드 4개와 `_ownsWeekly`·`_loadWeekly`·`_showWeeklyFailure`를 지웠다(가변 필드 27 → 23). `_syncWeeklyHome`은 `sync()`와 추천 출처 지우기 한 줄만 남기고, 카드 선택 뒤에는 화면 이동만 한다. 보임 판정·가려짐 감시·생명주기 수신은 그대로다.
- `frontend/README.md`: "추천 상세 흐름은 …" 문장 뒤에 지정된 한 문장을 더했다.
- 제거 검색: 앱 View의 방문 상태·Repository 직접 호출 검색은 0줄(`02e5240`에서는 38줄), 새 ViewModel의 의존 방향 검색도 0줄이다.
- 바꾸지 않음: `ContentRepository`의 주간 추천 인터페이스·구현, API 클라이언트, 서버, `HomeScreen`의 인자·카드 레이아웃·노출 측정, 보관함·상세 ViewModel의 추천 출처, Today 방문 상태, GLOSSARY·ADR.

## 고정 테스트 (#295)

`frontend/test/weekly_visit_behavior_test.dart`, 테스트 12개. 실제 앱과 가짜 서버(`MockClient`)로 #294의 W1–W9와 W8′를 단언한다. 모든 행이 #294 표의 예상과 같았다.

| 행 | 관측값 |
| --- | --- |
| W1a | 저장 시트를 연 채 GET 실패: 안내 없음. 시트 화면은 `transitionDuration: Duration.zero`라 여러 프레임에 걸친 닫기 애니메이션이 없다. pop 직후(프레임 전)에는 `route.completed`가 아직 끝나지 않았고 안내도 없다. 첫 프레임에서 `route.completed`가 끝나고, 이때도 안내는 없다. 그 뒤 안내 1회. [다시 시도] 뒤 GET 2회, 같은 안내가 다시 뜨지 않음. 0이 아닌 길이의 애니메이션 동안의 동작은 검증 대상이 아니다 |
| W1b | 백그라운드 중 실패: 안내 없음. 복귀 뒤 안내 1회. [다시 시도]로 GET +1, 같은 안내가 다시 뜨지 않음 |
| W2 | A 홈 GET 대기 → 마이 → 계정 관리 → 로그아웃 → 게스트 B 로그인 → 홈. B GET 1회(전체 2회). B 홈이 뜬 뒤 A 응답을 완료해도 카드(A 항목) 미표시, 노출 수 변화 없음, 노출 요청은 모두 B 토큰 |
| W3 | 백그라운드 중 실패 → 마이 이동 → 복귀: 지난 실패 안내 없음. 홈 복귀 시 GET 2회(새 방문), 카드 2개 |
| W4 | 0ms·899ms: 스플래시, GET 0. 900ms(홈 마운트, 준비 완료 뒤 첫 프레임 전): GET 0. 다음 프레임 뒤 GET 1, 안정된 뒤에도 1 |
| W5 | 카드가 화면 밖인 393×300 크기, 새 방문도 같은 항목 ID. 옛 홈 위젯의 노출·선택 콜백을 홈에서 호출: 노출 0, 이동 없음. 대조로 지금 홈의 콜백은 노출 1, 보관함 이동 |
| W6 | 시트를 띄운 직후 프레임 없이 노출 콜백 호출: 노출 0. 대조로 시트를 닫은 뒤에는 1 |
| W7 | 첫 GET 401 → 갱신 1회 → 새 토큰으로 GET 재전송(GET 2회). 카드 2개, 추천 실패 안내 없음, 노출 항목당 1회, UUID 형식 확인 뒤 서로 다름 |
| W8a·W8b | GET 대기 중 앱 제거 뒤 성공·실패 완료: 새 요청 0, 새 노출 0, 안내 0, `takeException()` null, 비동기 오류 없음 |
| W8′ | 성공 응답을 제거 전에 완료: 카드 2개·노출 2회. 제거 뒤 관측값이 W8a와 같음(새 요청·노출·안내 0, 예외 없음) |
| W9 | 첫 불러오기가 다음 프레임으로 예약된 상태(W4의 900ms 경계)에서 앱 제거: GET 0, 노출·안내·예외 없음 |

- main 대조: 같은 테스트 파일을 main `c55242c`(`frontend/`가 이 브랜치와 같음) 임시 워크트리에서 돌려 12개 모두 통과했다. 임시 워크트리는 확인 뒤 지웠다.
- `02e5240` 전체 검증: `VERIFY result=PASS scope=all checks=11 failed=0`, pytest `2320 passed, 47 skipped`, 앱 테스트 3392개 통과.

## 변형 실험

#295는 앱 루트 View 코드에, #296은 같은 규칙을 새 ViewModel에 적용했다(준비 완료 조건만 앱 View가 넘기는 `weeklyHome` 판정에서 뺐다).
두 번 모두 파일을 복사해 두었다가 되돌리고 `cmp`로 원상태를 확인했다. #296 로그는 작업 폴더 `.utmp/ticket-296/partial-mutation-*.log`, 변형 코드는 `.utmp/ticket-296/mutate.py`다(커밋하지 않음).

| 변형 | #295 실패 | #296 실패 |
| --- | --- | --- |
| (필수) 실패 안내를 보임과 상관없이 즉시 냄 | W1a, W3 | W1a, W3 |
| (필수) 노출·선택 콜백이 호출 시점의 지금 방문을 씀 | W5 | W5 |
| (필수) 방문 시작 조건에서 준비 완료를 뺌 | W4, W9 | W4, W9 |
| (필수) 노출 콜백이 보임 확인을 뺌 | W6 | W6 |
| (필수) 노출 콜백이 마지막으로 전해 받은 보임 값을 씀 | W6 | W6 |
| (필수) 실패 안내에서 [다시 시도]를 뺌 | `weekly_root_test` "failed/empty query hides entire section; owned manual retry only" | 같은 테스트 |
| (필수) 실패 안내 문구를 바꿈 | 같은 테스트 | 같은 테스트 |
| (참고) 미뤄 둔 실패를 안내를 낸 뒤에 비움 | 실패 없음 | 실패 없음 |
| (참고) 예약 콜백·늦은 결과 처리의 dispose(#295는 `mounted`) 확인을 뺌 | 실패 없음 | 실패 없음 |
| (참고) 방문의 계정 세대 비교를 뺌 | 실패 없음(W2 통과) | 실패 없음(W2 통과) |

검수가 남긴 해석의 한계:

- W1a는 시트 전환 시간이 0인 화면의 `route.completed` 경계를 검사한다. 0이 아닌 길이의 닫기 애니메이션 동안의 동작은 확인하지 않았다.
- 즉시 안내 변형에서 W1b가 통과했다. 백그라운드(paused) 중에는 프레임이 그려지지 않아 즉시 낸 안내가 복귀 전 화면에 나타나지 않는다. W1b만으로는 안내를 낸 시점을 구별하지 못한다. 필수 실패는 W1a와 W3가 잡았다.
- 지금 방문 변형은 노출과 선택을 함께 바꿨고, 첫 실패는 노출 단언이었다. 선택만 바꾼 변형은 따로 실행하지 않았다.
- 참고 변형 3개가 통과했다는 것은 이 고정 테스트가 그 세 가드를 따로 잡지 못한다는 기록이다. 구현에는 요구된 순서와 가드가 있다.

## 검증

- #295 리뷰(Codex 검수): Standards 0건, Spec 0건. 위 해석의 한계 4건을 기록했다.
- #296 리뷰(Codex 검수): Standards 0건, Spec 0건. 코드 수정 없음.
- #296 작업자 관련 검사(`11d8ff8` 커밋 전): 고정 파일과 회귀 7개 파일(`weekly_root_test`, `weekly_visibility_test`, `data/weekly_repository_test`, `notification_navigation_test`, `share/share_lifecycle_test`, `splash_share_startup_test`, `home_alignment_test`) 합계 314개 통과. 고정·회귀 파일의 diff는 비어 있다(`git diff 02e5240 HEAD -- frontend/test`).
- #296 작업자 전체 검증(`11d8ff8`): `VERIFY result=PASS scope=all checks=11 failed=0`, pytest `2320 passed, 47 skipped`, 앱 테스트 `+3392: All tests passed!`.
- 최종 리뷰(#294 범위 `c55242c...11d8ff8`, Codex 검수): Standards 0건, Spec 0건. 리뷰어가 전체 검증을 다시 실행했다(`11d8ff8`): `VERIFY result=PASS scope=all checks=11 failed=0`
  - pytest: 2320 passed, 47 skipped, 3 warnings in 218.97s (0:03:38)
  - pytest skip: 46 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
  - pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
  - 앱 테스트: `flutter test --no-pub` `+3392: All tests passed!`
  - 백엔드는 바꾸지 않았다. 건너뛴 Docker 복구·S3 통합 테스트는 이 변경과 무관하며 CI·별도 환경 대상이다.
  - 검사별 로그는 작업 폴더 `.utmp/review-294-verify/20261108T163508-819d7fdc1fd1/`(커밋하지 않음).
- CI App Validation의 4개 명령(`flutter pub get --enforce-lockfile`, `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze --no-pub`, `flutter test --no-pub`)은 verify의 앱 단계가 같은 문구로 실행했다.
- 리뷰어는 main 대조·변형 실험·촬영 전 확인을 다시 실행하지 않고 작업자 로그와 대조했다.
- push·원격 CI·실기기·운영 서버 확인은 하지 않았다. 원격 CI는 PR 생성 뒤 실행한다.

### PR 승인 뒤 main 병합·전체 검사(최종)

- 2026-11-08 사용자가 PR 초안과 양 플랫폼 원본 화면을 확인하고 "승인"했다. 승인 본문과 이미지 6칸을 보존하며, 이미지는 사용자가 PR 생성 뒤 첨부한다.
- push 직전 main이 `f52660b`(#297, PR #299)로 전진했다. `git merge-tree --write-tree origin/main HEAD`로 충돌 없음을 확인한 뒤 `f1a8936`으로 병합했다. 주간 추천 인터페이스와 겹치는 변경은 없었다.
- `git diff origin/main -- CHANGELOG.md`는 비어 있고, 이력 목차에는 두 작업의 항목이 각각 한 번씩 남았다. 승인 본문은 변경하지 않았다.
- 병합 코드 `f1a8936`에서 전체 검증을 새로 실행하고 종료 코드 0을 회수했다: `VERIFY result=PASS scope=all checks=11 failed=0`.
  - 앱: CI와 같은 4개 명령 모두 통과, `flutter test --no-pub` 3414개 통과.
  - pytest: 2320 passed, 47 skipped, 3 warnings in 216.99s (0:03:36).
  - pytest skip: 46 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
  - pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
  - 로그: `.utmp/pre-pr-294-verify/20261108T170139-d0a67e60d788/`.
- 이 결과를 기록한 후속 커밋은 이 문서만 바꾼다. 기기 화면은 앞서 승인받은 `11d8ff8` 실행 증거이며, main 병합 뒤 기기를 다시 실행한 결과로 표시하지 않는다. 원격 CI 결과는 PR에서 별도로 확인한다.

## 기기 실행 확인

2026-11-08 16:47–16:52 KST, 감독이 최종 리뷰·전체 검증 뒤 실행했다. 실행한 앱의 코드는 `11d8ff8`과 같다. 시작 직전 `HEAD..origin/main`은 비어 있었다(main `c55242c`).

- 실행 구성: 실제 `ClipbackApp`, `AppDependencies`, `HomeWeeklyViewModel`, Repository, `ClipbackApi`에 앱 프로세스 안의 `MockClient` 메모리 서버를 붙인 로컬 대역이다. 응답은 지연 없이 고정이다.
  - 주간 추천 응답: 카드 2개, 8101(카테고리 102 '여행', 많이 저장한)과 8102(카테고리 101 '일상', 자주 본). 방문마다 같은 항목 ID다.
  - 카드는 실제 `HomeScreen`이 받은 `weeklyItems`로만 그렸다. 화면을 따로 만들거나 ViewModel을 거치지 않는 경로는 쓰지 않았다.
  - 운영 서버·실제 OAuth·사용자 데이터는 쓰지 않았다.
- 입력: 카드와 보관함 헤더의 뒤로가기를 화면 정보(probe)의 탭 후보 좌표로 OS 탭했다(접근성 라벨 선택이 아님). 누르기 전 확인에서 두 대상 모두 후보 1개, 화면 안, 눌림 가능이었다.
- 글자 배율은 두 플랫폼 모두 1.0이다. 키보드는 나오지 않았다.

| 플랫폼 | 기종·OS | 논리 크기·배율(probe JSON) | 안전 영역 |
| --- | --- | --- | --- |
| iOS | iPhone 16 Simulator, iOS 18.6 | 393×852, devicePixelRatio 3 | 위 59, 아래 34 |
| Android | Medium_Phone Emulator, Android 16(API 36) | 411.42857142857144×914.2857142857143, devicePixelRatio 2.625 | 위 24, 아래 24 |

두 플랫폼 모두 같은 흐름과 결과였다(probe JSON 기준).

| 단계 | 화면 | 주간 추천 GET | 노출 기록 |
| --- | --- | --- | --- |
| 홈 시작 | 홈, 카드 8101/102·8102/101 | 1 | 첫 방문 2건 |
| 카드 8101 OS 탭 | 보관함 카테고리 102 '여행', 콘텐츠 602·604 | 1 | 늘지 않음 |
| 뒤로가기 OS 탭 | 홈, 같은 카드 2개 | 2 | 두 번째 방문 2건 |

- 노출 UUID 4개는 서로 다르다(방문당 2개, 새 방문은 새 UUID). 예상 밖 요청 목록은 6개 상태 모두 비어 있다. 감독이 두 플랫폼 JSON을 대조했다.
- 노출을 어느 방문에 묶을지는 "노출 요청이 왔을 때까지 받은 GET 수"로 정했다. 지연 없는 대역에서의 귀속이며, 늦게 온 노출의 방문 귀속 증거로 넓히지 않는다.
- 화면: 감독이 원본 PNG 6장을 직접 열어 홈의 '여행'·'일상' 추천 카드, '여행' 보관함 제목과 콘텐츠 2개, 복귀한 홈의 같은 카드를 확인했다. 원본 스크린샷은 보정하지 않았다. 사용자 시각 판정은 아직 받지 않았다.
- 빌드: iOS·Android 모두 촬영 전 확인을 통과한 뒤 빌드했다. 설치본이 그 빌드와 같은지 확인했다(iOS kernel 접두 `5b4c7eea553f`, Android APK SHA-256 접두 `c0c1e3ad4ecd`, 감독 기록).
- 기기 차례:
  - iOS: 처음 잡은 잠금(16:42:47)에서 headless 시뮬레이터라 등록할 Simulator 앱 프로세스가 없음을 발견했다. 기기를 끄고 잠금을 푼 뒤 조율에 물었다. 조율이 등록을 생략하되 배타 잠금과 설치·빌드 전 다른 작업 확인은 유지하도록 승인했다. 잠금 16:47:25 KST 획득, 16:49:10 KST 해제. 끝난 뒤 기기를 껐다.
  - Android: 잠금 16:49:21 KST 획득, 16:52:25 KST 해제. 새로 부팅한(cold boot) 에뮬레이터 프로세스를 잠금에 등록했다. 끝난 뒤 에뮬레이터를 껐다.
- 도구 사용 오류 1회(iOS): 도착 확인 명령의 인자 형식을 잘못 줘 사용법 오류로 끝났다. 카드 탭은 이미 성공한 상태였다. 다시 누르지 않고 지금 화면 정보를 확인한 뒤 올바른 형식으로 도착을 확인했다. 원본 화면·앱 코드는 바꾸지 않았다.
- 증거: 작업 폴더 `.utmp/ticket-296/`(커밋하지 않음)의 `device-results.md`, 촬영 진입 파일 `state_preview.dart`·`state_preview_check_test.dart`, `screens/`의 PNG와 같은 이름의 JSON이다.
  - iOS: `ios-after-home-start`, `ios-after-archive`, `ios-after-home-return`, 도착 확인 `ios-archive-target.json`·`ios-home-return-target.json`, 화면 구조 `ios-home-return-ax.json`
  - Android: `android-after-home-start`, `android-after-archive`, `android-after-home-return`, 도착 확인 `android-archive-target.json`·`android-home-return-target.json`, 화면 구조 `android-home-return-ax.json`
  - `ios-after`·`android-after`는 설치 확인용 첫 홈 화면이다. 왕복 시작 홈은 다시 띄운 같은 빌드의 `*-after-home-start`다.
  - 이미지는 아직 GitHub에 올리지 않았다. PR 본문에 첨부한다.
- 촬영 준비: 앱 코드는 바꾸지 않고 작업 폴더의 촬영 진입 파일만 만들었다. 빌드 전 확인(같은 왕복을 위젯 테스트로 실행)은 12개 통과, 탭 검사 5개 통과였다(`partial-capture-preflight-after.log`, 플랫폼별 `preflight-<plat>-after.log`).
- 제한: 회의 결정에 따라 변경 전 촬영, 3면 비교, 영상은 없다. 글자 배율 1.0만 확인했다.

## 동작 보존 증거에서 제외하는 것 (#294)

아래 항목은 이번에 고정하지 않았으며, "동작 변경 없음" 주장에도 넣지 않는다.

- 카드의 보이는 면적 측정(50% 기준)과 카드 레이아웃·글자 배율. 홈 화면 위젯 쪽 코드이고 바뀌지 않았다. 기존 `weekly_visibility_test`, `home_alignment_test`가 그대로 통과하는 것으로 갈음한다.
- Repository의 요청·응답 처리 자체. 바뀌지 않았다. 기존 `data/weekly_repository_test`가 그대로 통과하는 것으로 갈음한다.
- 최종 인증 실패 뒤 추천 안내 유무. 세션 무효화 처리와 방문 종료의 순서에 따라 달라진다. 대표 401 시나리오는 갱신 성공(W7) 하나로 두었다.
- 방문의 계정 세대 비교가 단독으로 관측되는지. 계정이 바뀌면 화면도 로그인으로 바뀌어 방문이 먼저 끝날 수 있다. W2는 계정 변경 보존 검사로만 두었다(참고 변형에서 실패 없음).

## 범위 밖 후보 (고치지 않음, #294 Out of Scope)

1. Today 방문 상태 분리(다음 순서 1번 추천).
2. 권한 안내 시도 분리.
3. 마이↔공지 스크롤 보존과 보관함 저장 버킷 분리.
4. 종료 확인·저장 배너.
5. 주간 추천 요청에 제한 시간이 없음(`ApiRequestScope`를 씌우지 않음, Q3).
6. 계정 세대 값이 두 개(`AppViewModel.accountGeneration`과 `ContentRepository.accountVersion`이 같은 뜻인지 확인하지 않음).
7. 앱 루트의 "아직 같은 계정·같은 화면인가" 판정 반복.
8. 조사 기록의 변경 횟수 차이.
