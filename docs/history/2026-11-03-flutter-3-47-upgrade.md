# Flutter 3.47.9 업그레이드

최초 기록일: 2026-11-03 KST. 이슈 [#209](https://github.com/clip-back/clipback/issues/209), 시작 커밋 `c75d806`,
작업 브랜치 `chore/flutter-3.47-upgrade`.

## 문제와 결정

- Flutter 3.44.9는 iOS를 빌드할 때마다 `frontend/ios/Runner.xcodeproj/project.pbxproj`의 `objectVersion`을 60에서 54로 바꿨다(#197·#198 작업에서 매번 되돌림).
  Flutter 3.47.0부터는 54 이상이면 그대로 둔다([flutter/flutter#186250](https://github.com/flutter/flutter/pull/186250)).
- 2026-11-03 사용자 결정: Flutter를 3.47.9로 올리고, 최소 Flutter 버전은 `frontend/pubspec.yaml`의 `environment`에 3.47.0 하한으로 둔다. FVM 같은 새 도구는 들이지 않는다.
- 2026-11-03 사용자 결정: Flutter 3.47.9 iOS 빌드가 바꾼 `IPHONEOS_DEPLOYMENT_TARGET` 13.0→15.0 세 줄을 이번 PR에 커밋한다.

## 변경 내용

- 이 Mac의 Flutter SDK(`/Users/leehyeongyu/flutter`)를 태그 3.44.9(`6b182d2c75`)에서 3.47.9(`c197ca5199`, Dart 3.13.7)로 옮겼다.
  되돌릴 때는 SDK 폴더에서 `git checkout 3.44.9`를 한다.
- `frontend/pubspec.yaml`: `environment`에 `flutter: ">=3.47.0"`을 더했다. `pubspec.lock`의 `sdks.flutter`도 `>=3.47.0`이 됐다.
- `frontend/pubspec.lock`: Flutter SDK가 정하는 `matcher` 0.12.20, `meta` 1.19.0, `test_api` 0.7.12, `vector_math` 2.4.4로 바뀌었다.
- `frontend/analysis_options.yaml`: Flutter 3.47 도구의 `AnalysisOptionsMigration`이 `flutter pub get` 때마다 `build/**`·`android/**`·`ios/**`·`web/**` 분석 제외를 넣는다.
  커밋하지 않으면 매번 다시 생겨 그대로 반영했다.
- `frontend/lib/features/content/view_models/detail_view_model.dart`: 새 analyze 경고 `unawaited_return_in_try_block`을 없애려고 `openToday`의 `return` 앞에 `await`를 붙였다.
  `_openTodayContent`는 자체 try/catch로 요청 오류를 처리하고 try 밖은 `notifyListeners()`뿐이라 동작은 같다고 판단했다.
- `frontend/android/settings.gradle.kts`: Flutter 3.47.9는 Kotlin Gradle 플러그인이 2.2.20 미만이면 Android 빌드를 막고 2.3.20 미만이면 경고한다.
  AGP 9.0.1이 함께 가져오는 2.2.10으로는 `flutter build apk`가 실패해, `org.jetbrains.kotlin.android` 2.3.20을 `apply false`로 선언했다. AGP·Gradle 버전은 그대로다.
- `frontend/ios/Runner.xcodeproj/project.pbxproj`: Flutter 3.47.9의 `IOSDeploymentTargetMigration`이 iOS 빌드 때 프로젝트 기본 설정 3줄의
  `IPHONEOS_DEPLOYMENT_TARGET` 13.0을 15.0으로 바꿔 반영했다. `objectVersion`은 60 그대로다.
  빌드된 Runner.app의 `MinimumOSVersion`은 이미 17.0이어서(Runner target이 Xcode 27.2 권장값 사용) 실제 지원 iOS는 바뀌지 않는 것으로 관찰했다.
  배포된 0.3.0 빌드의 값은 확인하지 않았다.
- [프론트 README](../../frontend/README.md)의 요구 버전 안내를 Flutter `>=3.47.0`으로 고쳤다.
- Android `minSdk`·`targetSdk`·`compileSdk`는 Flutter 기본값(24·36·36)이 3.44.9와 같아 바뀌지 않았다.

## 자동 검사

- 업그레이드 전 기준선(3.44.9): 앱만 실행했다. `verify.py --only app` `VERIFY result=PASS scope=app checks=3 failed=0`, `flutter test` 2020개 통과.
  이슈 완료 조건은 전체 `verify.py` 기준선이지만 백엔드 기준선은 남기지 않았다(스펙 대비 예외). 백엔드는 Flutter SDK를 쓰지 않고,
  이 브랜치에서 `backend/` 파일은 바뀌지 않았다(`git diff c75d806 HEAD -- backend` 0줄). 업그레이드 뒤 전체 검사는 아래와 같이 `scope=all`로 통과했다.
- 업그레이드 직후: `flutter test`는 통과했지만 `flutter analyze`가 위 경고 1건으로 실패했다.
- 3.44.9 사본 SDK로 `flutter pub get`을 하면 "requires Flutter SDK version >=3.47.0, version solving failed"로 종료 코드 1이다.
- 바꾼 경로 테스트: `test/view_models/content_view_models_test.dart` 37개, `test/today_root_test.dart` 10개 통과(정상 이동, 404 뒤 재시도, 요청 중 홈 이탈, 늦은 상세 응답 폐기 포함).
- 전체 검사(1차): `python3 ~/.heoturu-agents/verify.py --log-dir .utmp/ticket-209`을 `43bd536`에서 돌렸다.
  `VERIFY result=PASS scope=all checks=10 failed=0`, `flutter test --no-pub` 2020개 통과(건너뜀 0).
- 전체 검사(최종): main(`0cccaaa`, #198 병합)을 이 브랜치에 merge한 `d0fb990`에서 `python3 ~/.heoturu-agents/verify.py --log-dir .utmp/ticket-209/final`을 한 번 돌렸다.
  `VERIFY result=PASS scope=all checks=10 failed=0`. `flutter analyze --no-pub` 문제 없음, `flutter test --no-pub` 2031개 통과(건너뜀 0, #198이 바꾼 정렬 메뉴·문구 테스트 포함),
  백엔드 pytest 1896개 통과·46개 건너뜀(Docker·운영자 이미지가 필요한 테스트 45개, `CLIPBACK_IMAGE_TEST_S3_ENDPOINT`가 없어 건너뛴
  이미지 저장소 CLI 통합 테스트 1개. 모두 이번 변경과 무관). 화면은 merge 뒤 다시 찍지 않았다.

## 시뮬레이터·에뮬레이터 실행 (2026-11-03)

- 환경: iPhone 16 / iOS 18.6 Simulator(Xcode 27.2), Android Emulator `Medium_Phone` / Android 16 / 1080×2400. 한 번에 하나만 띄웠다. 서버·로그인은 쓰지 않았다.
- 실제 루트 앱을 홈 메모리 API(콘텐츠 4개)로 띄우는 임시 진입 파일(커밋하지 않음)로 debug 빌드했다. 글자 배율 1.0, 홈 스크롤 0에서 홈을 찍고,
  Orca 에뮬레이터 탭으로 아카이브 → 즐겨찾기 → 즐겨찾기의 콘텐츠 상세로 이동해 플랫폼마다 4장을 찍었다. 깨진 화면은 없었다.
- iOS 빌드 뒤 `git diff`에서 `project.pbxproj`의 바뀐 줄은 `IPHONEOS_DEPLOYMENT_TARGET` 3줄뿐이었고 `objectVersion`은 60이었다.
- Android 첫 빌드는 위 Kotlin 플러그인 버전 오류로 실패했고, 선언을 더한 뒤 성공했다. 빌드 경고로 `package_info_plus`가 Kotlin Gradle 플러그인을 직접 적용해
  앞으로의 Flutter에서는 빌드가 실패할 수 있다는 안내가 나온다. 패키지 업그레이드는 범위 밖이라 그대로 두었다.
- 아카이브에서 위로 스와이프한 뒤 `orca emulator ax`의 첫 카드 위치가 바뀌어 두 플랫폼 모두 스크롤이 움직이는 것을 확인했다. iOS 상세에서 뒤로 버튼은 즐겨찾기로 돌아갔다.
- 화면 자료는 저장소 밖 `.utmp/ticket-209/screens/`에 두었다(새 checkout에는 없다).

## 미검증 범위

- 릴리스 빌드(`flutter build ipa`·`appbundle`)는 돌리지 않았다. 다음 앱 후보 준비 때 확인한다.
- 실기기, 실제 서버, 3.44.9로 빌드한 앱과의 화면 비교는 하지 않았다.
