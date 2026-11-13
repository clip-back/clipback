# 화면 아래 안내(스낵바)가 쌓이지 않게 하고 글자를 Pretendard로 (#353, #354)

2026-11-14, 브랜치 `fix/snackbar-stack-font`. 앱 0.5.4 후보.
시작 커밋 `87d61c4`, 구현 커밋 `d8cff25`(#353)·`ff58e82`(#354), 리뷰 반영 `60c8f6a`, main(#350) 병합 `a67b3fc`(전체 검증·변경 후 촬영 기준).
이 기록을 더한 커밋은 문서만 바꾼다.

## 문제

- #353(팀 피드백 시트 74번): 홈 "오늘의 콘텐츠 보기 →"처럼 스낵바를 띄우는 버튼을 여러 번 누르면 안내가 줄을 서서 하나씩 차례로 떴다. '다시 불러오기'·'다시 시도' 버튼이 붙은 안내는 저절로 사라지지 않아, 그 뒤 안내는 사용자가 닫을 때까지 보이지 않았다.
- #354(시트 80번): 스낵바 글자가 앱 글꼴 Pretendard가 아니라 기기 기본 글꼴이었다. 앱 테마의 `textTheme`가 `MaterialApp` 바깥 기본 글자 묶음을 받아 `fontFamily: 'Pretendard'`를 덮고, 스낵바는 그 `bodyMedium`을 쓴다.

## 사용자 결정

- #353(2026-11-14 "추천대로", "나머지 모두 추천대로"): 새 안내가 오면 지금 떠 있는 안내를 내리고 새 안내를 보여 준다. 이전 안내는 `clearSnackBars()`로 퇴장 애니메이션(약 0.26초) 뒤 내려간다. 버튼 붙은 안내도 뒤 안내가 오면 밀려 사라진다. 앱의 모든 스낵바 표시 경로에 같은 규칙.
- #354(같은 날 같은 승인): 스낵바만 Pretendard로 고치고 테마 전체는 고치지 않는다. 안내 오른쪽 버튼(`SnackBarAction`) 글자는 범위 밖.

## 구현

- #353 `d8cff25`: 스낵바를 띄우는 두 곳(`clipback_app.dart` `_handleEffect`의 `MessageEffect`, `my_screen.dart` `_openExternal`)이 같은 전역 `ScaffoldMessenger`에서 `clearSnackBars()` 뒤 `showSnackBar()`한다. 회원 탈퇴 성공 뒤 `clearSnackBars()`는 그대로다.
- #354 `ff58e82`: 앱 테마에 `snackBarTheme.contentTextStyle = textTheme.bodyMedium.copyWith(fontFamily: 'Pretendard', color: colorScheme.onInverseSurface)`를 둔다. 크기 14·두께·줄높이·자간은 지금 기본값 그대로다. 앱 `textTheme`·`fontFamily` 줄과 버튼 글자는 바꾸지 않았다.

## 테스트

먼저 테스트를 바꿔 실패를 본 뒤 고쳤다(로그는 로컬 `.utmp/ticket-353/partial-*.log`, 저장소에 넣지 않음).

| 완료 조건 | 테스트 | 수정 전 |
| --- | --- | --- |
| #353 연타 뒤 마지막 안내만, 그 뒤 없음 | `snackbar_stack_root_test.dart` `five today taps leave only the last notice, then nothing` | 실패(5개가 차례로) |
| #353 버튼 안내 교체, 다른 안내가 없으면 남음 | `a notice with a button gives way to the next notice for good` | 실패(새 안내가 갇힘) |
| #353 퇴장 중 새 안내 | `a notice arriving during an exit drops the queued middle one`(가운데 안내 접수와 첫 안내 퇴장 상태 단언) | 실패 |
| #353 마이 경로 | `my privacy failure replaces the contact failure notice` | 실패 |
| #353 탈퇴 성공 뒤 J06 안내 없음 | 기존 `account_deletion_flow_test.dart` `a failure snackbar still showing does not follow a successful retry to J06` | (기존 통과) |
| #354 두 경로 글꼴·크기·색, 테마 `bodyMedium`·`labelLarge` 그대로 | `snackbar_font_root_test.dart` 마이 문의하기 실패, `MessageEffect`(오늘 추천 stage 0) | 실패(`Roboto`) |
| #354 버튼 글자 그대로 | `SnackBarAction label keeps the theme labelLarge font` | 실패(안내 글자 `Roboto`) |
| #354 Pretendard 넘침(두 문구 × 1.0·1.3배, 폭 320) | `Pretendard notice <no button|다시 불러오기> <1.0|1.3>x width 320 is not clipped` | 실패(`Roboto`) |

- 넘침 시험의 두 긴 문구는 실제 경로로 띄우기 어려워, 앱 루트의 실제 테마·전역 메신저에 앱과 같은 모양(`Text` + `SnackBarAction`)의 스낵바를 직접 띄워 잰다. 글꼴 단언은 실제 경로로 한다.
- 바꾼 기존 테스트는 #354 허용 표의 주석 두 곳(`contact_form_root_test.dart`, `my_legal_links_root_test.dart`)뿐이다. 단언은 그대로다.

## 검토

검수(Codex, `.utmp/review-353.md`): Standards 0개, Spec 중간 1개.

- 반영(`60c8f6a`): 퇴장 중 교체 시험이 셋째 안내 직전 상태를 단언하지 않았다. 오늘 추천 요청 2회와, 보이는 안내가 첫 안내이며 퇴장(`AnimationStatus.reverse`) 중임을 단언한다. 가운데 요청을 뺀 변형과 퇴장이 끝난 뒤 셋째를 낸 변형이 이 단언에서 실패하는 것을 확인했다.
- 검수가 `frontend/lib`의 스낵바 표시 지점을 전수 확인했다: 두 곳뿐이다.

## 검증

- `VERIFY result=PASS scope=all checks=11 failed=0`(`a67b3fc`).
  - CI App Validation 명령: `flutter pub get --enforce-lockfile`, `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze --no-pub`, `flutter test --no-pub`(+3522 All tests passed).
  - 백엔드: pytest 2640 passed, 49 skipped(48 `tests/deployment` Docker 복구 시험 조건, 1 `tests/integration` S3 주소 없음). 백엔드는 바꾸지 않았다.
- `git diff --check` 통과.

## 화면 확인

2026-11-14, iPhone 16 / iOS 18.6 Simulator(Simulator.app 없이 headless)와 `Medium_Phone` / Android 16 Emulator. 로컬 메모리 서버 대역(홈 비교용 데이터)이며 운영 서버·실제 로그인은 쓰지 않았다.
변경 전은 `87d61c4`의 앱 파일 2개(`clipback_app.dart`, `my_screen.dart`)로, 변경 후는 `a67b3fc`로 같은 촬영 진입 파일(`.utmp/ticket-353/state_preview.dart`)을 빌드했다. 진입 파일은 오늘 추천을 늘 stage 0으로 답하고, 첫 이번주 추천 조회만 연결 실패로 끝내 '다시 시도' 버튼 안내를 띄운다.
Figma 기준: 스낵바 원본 없음(`figma-ui-alignment-plan.md` "빈/오류는 기존 SnackBar", 사용자 결정 2026-11-14). 글꼴은 앱 글꼴 Pretendard에 맞춘다.

| 상태 | iOS | Android |
| --- | --- | --- |
| #354 버튼 안내 1.0·1.3배 | 안내 글자 `CupertinoSystemText` → Pretendard, 크기 14·색 그대로. 버튼 '다시 시도'는 두 빌드 모두 `CupertinoSystemText`. 1.3배에서 두 줄, 잘림 없음 | 안내 글자 `Roboto` → Pretendard. 버튼은 `Roboto` 그대로. 1.3배 두 줄, 잘림 없음 |
| #353 '오늘의 콘텐츠 보기 →' 5번(영상) | 변경 전: 안내 5개가 차례로 떠 마지막 탭 약 18.2초 뒤 끝. 변경 후: 누를 때마다 앞 안내가 내려가고 마지막 안내가 마지막 탭 약 4.9초 뒤 끝, 다시 뜨지 않음(탭 간격 약 1초) | 변경 전: 5개가 차례로, 약 22.3초 뒤 끝. 변경 후: 약 4.9초 뒤 끝, 다시 뜨지 않음(탭 간격 약 0.3초) |

- 시간은 앱 안 기록(`screens/<plat>-<before|after>-video.video.json`의 누름·스낵바 변화 시각)이다. 5번 누름은 '오늘의 콘텐츠 보기 →'가 하나뿐임을 AX로 확인한 뒤 probe의 버튼 가운데 좌표로 OS 탭을 보냈다.
- 겹침(y, 논리 pt): 버튼 iOS 208–228, Android 173–193. 스낵바 iOS 684–754(변경 후 686–754), Android 756–826(변경 후 758–826). 겹치지 않는다. 스낵바 높이가 2pt 줄어든 것은 글꼴 줄높이 차이다.
- 스낵바는 지금처럼 화면 아래 가운데 '+' 버튼과 하단 탭 위에 겹쳐 뜬다(위치는 이번 범위 밖, 바꾸지 않음).
- 기기 화면(393×852, 411.4×914.3)과 비교할 Figma 프레임은 없다.

### 증거(로컬, 저장소에 넣지 않음)

- 비교 이미지: `.utmp/ticket-353-screens/compare-{ios,android}.png`, 비교 영상: `compare-{ios,android}.mp4`.
- 원본·조건 JSON: `.utmp/ticket-353/screens/`.
