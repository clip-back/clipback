# 회원 탈퇴를 여러 번 누르면 알림이 이어서 뜨던 문제 수정

최초 기록일: 2026-11-03 KST. 이슈 [#190](https://github.com/clip-back/clipback/issues/190), 시작 커밋 `8592ffb`,
작업 브랜치 `fix/withdraw-snackbar-queue`. 회원 탈퇴 기능 자체는
[Figma 화면 맞춤 계획의 보류 항목](../figma-ui-alignment-plan.md#figma-pending-15)대로 범위 밖이다.

## 문제와 결정

- 마이 → 계정 관리에서 "회원 탈퇴"를 누를 때마다 `showSnackBar`로 알림("회원 탈퇴 API는 아직 제공되지 않습니다.")을 새로 띄웠다.
  `ScaffoldMessenger`는 알림을 대기열에 쌓아 하나씩 4초씩 보여 주므로, 누른 횟수만큼 알림이 이어서 떴다(0.3.0 팀 테스트 제보).
- 처음 수정은 이슈에 적은 대로 `hideCurrentSnackBar()` 뒤 `showSnackBar(...)`였다(`10f1b85`).
  티켓 리뷰에서 알림이 나타나거나 사라지는 애니메이션 중에 다시 누르면 새 알림이 여전히 대기열에 쌓인다는 지적이 나왔다.
  `hideCurrentSnackBar()`는 사라지는 애니메이션만 시작하고, 알림은 애니메이션이 끝나야 대기열에서 빠지기 때문이다.
- 2026-11-03 사용자 결정: `removeCurrentSnackBar()` 뒤 `showSnackBar(...)`로 바꾼다(`5429fbb`). 떠 있던 알림은 내려가는 애니메이션 없이 바로 바뀐다.
  대기열 전체를 비우는 `clearSnackBars()`는 앱 공통 알림까지 지우므로 쓰지 않았다.
- 탈퇴를 누르면 그때 떠 있던 앱 공통 알림도 바로 사라진다. "떠 있는 알림을 지운다"는 수정 방향에서 나오는 결과라 그대로 두었다.
  공통 알림(`clipback_app.dart`의 `MessageEffect`)이 쌓이는 문제는 이슈의 범위 밖이다.

## 변경 내용

- `frontend/lib/features/account/account_management_screen.dart`: 탈퇴 줄의 `onTap`이 `removeCurrentSnackBar()` 뒤 `showSnackBar(...)`를 부른다.
- `frontend/test/account_management_alignment_test.dart`: iOS·Android 테마마다 재현 테스트 3개를 더했다.
  연속으로 3번(`rapid`), 100ms 간격으로 3번(`gap100`), 첫 알림이 표시 시간 4초를 다 채우고 스스로 내려가는 중(첫 탭 뒤 4.4초, 4.5초)에
  2번 더(`exit`) 누른다. 탭 사이 시간은 50ms씩 프레임을 그리며 진행하고, `exit`는 두 번째 탭 직전에 첫 알림의 애니메이션이
  `AnimationStatus.reverse`인지 확인한다. 마지막 탭 직후 알림이 1개이고, 5초 뒤 없으며, 그 뒤 10초 동안 다시 나오지 않는지 본다.
- 최종 리뷰 반영(2026-11-03): 처음 커밋한 `exit`(`5429fbb`)는 4.3초를 `pump` 한 번으로 넘겨 프레임을 하나만 그렸다.
  그래서 등장 애니메이션이 그 프레임에서야 끝나고 표시 타이머가 그때 시작돼, 두 번째 탭은 첫 알림이 막 표시된 때(`completed`) 들어갔다.
  지금처럼 50ms씩 진행하게 고쳤다. 큰 `pump` 한 번으로 되돌린 변형에서는 새 단언이 `completed`로 실패하는 것을 확인했다.

방식별 비교(임시 위젯 하네스, 마지막 탭 뒤 알림이 처음 없어진 시간, 50ms 단위). 마지막 열은 첫 탭 뒤 4.1초(표시 중, 사라지기 직전)와 4.3초(사라지는 중)에 누른 두 경우다:

| 방식 | 0ms 간격 | 50–100ms 간격 | 300ms 간격 | 4.1·4.3초 뒤 |
| --- | --- | --- | --- | --- |
| 변경 전(`showSnackBar`만) | 13.8초 | 13.6–13.7초 | 13.2초 | 9.5–9.6초 |
| `hideCurrentSnackBar` 뒤 `showSnackBar` | 4.6초 | 9.2초 | 4.6초 | 9.4–9.5초 |
| `removeCurrentSnackBar` 뒤 `showSnackBar` | 4.6초 | 4.6초 | 4.6초 | 4.6초 |

## 자동 검사

- 재현 테스트 실패 확인(`frontend/`에서 `flutter test --no-pub test/account_management_alignment_test.dart --plain-name 'withdraw taps show one notice'`):
  화면 파일만 시작 커밋 `8592ffb`로 잠시 바꾸면 6개 모두 실패, `10f1b85`(`hideCurrentSnackBar`)에서는 `gap100`·`exit` 4개 실패.
  실패 단언은 모두 "5초 뒤 알림 없음"이다.
- 최종 리뷰 반영 뒤 같은 명령을 다시 돌렸다. 시작 커밋 화면에서 6개 모두, `10f1b85` 화면에서 `gap100`·`exit` 4개가 실패했다.
  실패 단언은 모두 "5초 뒤 알림 없음"이고, `exit`의 "사라지는 중" 단언은 두 코드 모두에서 통과했다.
- 수정 후 `flutter test --no-pub test/account_management_alignment_test.dart` 20개 통과(리뷰 반영 전후 모두).
  기존 "탈퇴를 한 번 누르면 알림 하나" 단언이 있는 compatibility matrix 테스트도 통과했다.
- 전체 검사: `python3 ~/.heoturu-agents/verify.py --log-dir .utmp/ticket-190`을 `5429fbb`와 같은 코드에서 한 번,
  최종 리뷰 반영(테스트 수정) 뒤 한 번 돌렸다. 두 번 모두 `VERIFY result=PASS scope=all checks=10 failed=0`이다.
  `flutter analyze --no-pub` 문제 없음, `flutter test --no-pub` 2025개 통과(건너뜀 0),
  백엔드 pytest 1896개 통과·46개 건너뜀(Docker·운영자 이미지·S3 엔드포인트가 필요한 테스트, 이번 변경과 무관).

## 시뮬레이터·에뮬레이터 실행 (2026-11-03)

- 환경: iPhone 16 / iOS 18.6 Simulator, Android Emulator `Medium_Phone` / Android 16(API 36) / 1080×2400 / 420dpi.
  한 번에 하나만 띄웠다. 서버·로그인은 쓰지 않았다.
- 화면: [계정 관리 프리뷰](../../frontend/test/support/account_preview.dart)의 실제 루트 앱과 메모리 API로 회원 계정 관리 화면을 띄웠다.
  여기에 탭 주입용 임시 진입 파일(커밋하지 않음)을 더해 debug 빌드했다. 이 파일은 앱 안에서 8769 포트로 요청을 받는다.
  요청마다 회원 탈퇴 줄 가운데에 포인터 이벤트를 넣고(프리뷰의 `/run`과 같은 방식), 마지막 탭 뒤 16초 동안 100ms마다 알림 문구가 있는지 잰다.
  OS 입력 장치로 누른 것은 아니다.
- 변경 전은 화면 파일만 `8592ffb`로 잠시 바꾼 빌드, 변경 후는 `5429fbb` 빌드다. 두 빌드의 kernel에 서로 다른 탈퇴 코드가 들어간 것을 확인했고,
  Android는 기기에 설치된 APK의 SHA-256이 변경 후 APK와 같은지도 확인했다.
- 녹화: iOS `simctl io recordVideo`, Android `screenrecord`.

마지막 탭 뒤 알림이 처음 없어진 시간(100ms 단위 측정). 변경 전·후 12번의 실행 모두 알림 문구는 한 번에 하나였고, 한 번 사라진 뒤 다시 나오지 않았다.

| 플랫폼 | 경우 | 변경 전 탭 시각 | 변경 전 | 변경 후 탭 시각 | 변경 후 |
| --- | --- | --- | --- | --- | --- |
| iOS | 연속 | 0·0.13·0.18초 | 13.6초 | 0·0.12·0.17초 | 4.6초 |
| iOS | 100ms 간격 | 0·0.16·0.30초 | 13.5초 | 0·0.15·0.29초 | 4.6초 |
| iOS | 사라지는 중 | 0·4.35·4.49초 | 9.2초 | 0·4.36·4.50초 | 4.6초 |
| Android | 연속 | 0·0.44·0.74초 | 14.5초 | 0·0.21·0.29초 | 4.8초 |
| Android | 100ms 간격 | 0·0.47·1.02초 | 13.2초 | 0·0.15·0.32초 | 4.8초 |
| Android | 사라지는 중 | 0·4.41·4.57초 | 9.6초 | 0·4.39·4.58초 | 4.7초 |

- 탭 시각은 첫 탭 기준이다. 기기 실행의 "사라지는 중"은 탭 시각으로 정했고, 탭 순간의 애니메이션 상태는 기록하지 않았다. 에뮬레이터가 느려 Android의 실제 탭 간격은 의도(0ms·100ms)보다 벌어졌다.
- Android 변경 후 첫 실행은 에뮬레이터 저장 공간이 부족해 설치에 실패한 채 변경 전 앱으로 돌았다.
  그 결과는 버렸고, 캐시를 비운 뒤 설치해 다시 찍은 것이 위의 변경 후 값이다.
- 바뀌는 모습: 사라지는 중에 누르면 내려가던 알림이 그 자리에서 없어지고 새 알림이 올라온다. Android 프레임에서는 그 사이에 알림이 없는 프레임 하나가 보인다.
- 비교 자료는 저장소 밖 `.utmp/ticket-190-screens/`에 두었다(새 checkout에는 없다).
  `compare-<ios|android>-<rapid|gap100|exit>.mp4`(변경 전·후 영상을 나란히), `compare-rapid-5s.png`(연타 뒤 같은 영상 시점의 변경 전·후, 왼쪽 iOS·오른쪽 Android),
  `frames-*-after-exit*.png`(사라지는 중 탭의 0.25초 간격 프레임), 원본 영상·스크린샷·측정 JSON `raw/`, 임시 진입 파일과 실행 스크립트.
- iOS 녹화는 화면이 바뀔 때만 프레임을 남겨, 화면이 멈춘 구간은 영상 길이에 들어가지 않는다. 시간은 위 앱 안 측정값을 기준으로 한다.
- Figma 기준 화면은 없다. 이 알림은 탈퇴 기능이 보류된 동안 쓰는 기존 SnackBar이고 디자인이 없다([figma-pending-15](../figma-ui-alignment-plan.md#figma-pending-15)).
  화면 배치는 바뀌지 않았다.

## 미검증 범위

- 실기기, OS 입력 장치로 누르는 실제 손가락 탭, 접근성 이동(VoiceOver·TalkBack 켬)에서는 확인하지 않았다.
- 실제 앱에서 공통 알림(`MessageEffect`)이 떠 있을 때 탈퇴를 누르는 경우는 리뷰어의 위젯 하네스로만 확인했다(공통 알림이 바로 사라짐).
