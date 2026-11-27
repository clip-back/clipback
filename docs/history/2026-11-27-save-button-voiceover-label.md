# 저장 화면 아래 버튼 이름 중복 읽기 (#492)

최초 기록일: 2026-11-27. 출처: 팀 피드백 시트 160번, 결정(2026-11-27 사용자 "160: 추천대로"): 중복 읽기만 고치고 꺼진 버튼의 "흐리게 표시됨"은 그대로 둔다. Android(TalkBack)도 같은 위젯이라 같이 고친다.

## 바꾼 것

- 앱: 콘텐츠 저장하기 화면 아래 버튼(`SaveFlowButton`)의 `Semantics`에 `excludeSemantics: true`와 `onTap: enabled ? onPressed : null`을 더했다.
  안쪽 `Text`가 바깥 이름에 다시 붙지 않아 '허투루에 저장하기'·'닫기'(처리 중)·'저장 완료'·'저장 중'이 한 번씩 읽힌다.
  `excludeSemantics`가 막는 `GestureDetector`의 tap 동작은 켜졌을 때만 바깥 노드에 다시 준다. 화면 글자·모양·손가락 탭은 그대로다.
- 새 테스트 `frontend/test/save_flow_button_semantics_test.dart`: 실제 루트 앱 홈의 + 버튼으로 저장 화면을 열고 메모리 서버(`LinkPendingServer`)가 저장 요청을 붙잡는다.
  빈·틀린 링크, 맞는 링크, 처리 중 '닫기', '저장 중', '저장 완료'에서 의미 노드 이름(완전 일치)·버튼·켜짐·tap 동작 유무·자식 의미 노드 없음을 단언한다.
  의미 tap으로 저장 요청 1건, '저장 완료' 의미 tap으로 저장 화면이 닫힌다. '저장 중'은 저장 대기 중 '사진 첨부' 탭으로 옮겨 만든다.

## 검증 (2026-11-27, 로컬)

- 새 테스트는 시작 커밋 `642a062`의 화면 코드에서 4건 모두 이름 단언으로 실패했다(`허투루에 저장하기\n허투루에 저장하기`, `닫기\n닫기`, `저장 완료\n저장 완료`). 고친 코드에서 4건 통과.
- 이슈 허용 표의 저장 관련 기존 테스트 27개 파일과 새 파일: 1,305건 통과. 바꾼 기존 테스트는 없다.
- 커밋 `d135cfc`에서 `python3 ~/.heoturu-agents/verify.py --log-dir .utmp/ticket-492`:
  `VERIFY result=PASS scope=all checks=12 failed=0`. Flutter 4,444건 통과.
  - `pytest: 3528 passed, 52 skipped, 3 warnings in 582.13s (0:09:42)`
  - `pytest skip: 51 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)`
  - `pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)`
- iPhone 16(iOS 18.6 Simulator)과 Medium_Phone(Android 16 Emulator, 약 411×914, 글자 배율 1.0)에서 실제 루트 앱과 메모리 서버로 다섯 상태를 만들고 접근성 트리를 덤프했다.
  iOS는 `orca emulator ax`(serve-sim AX), Android는 `uiautomator dump`의 `content-desc`다. 변경 전은 화면 파일만 `642a062`로 바꾼 빌드, 변경 후는 `d135cfc` 빌드다.

  | 상태 | 변경 전 이름 (양 플랫폼 같음) | 변경 후 이름 | 켜짐 (iOS `enabled` / Android `enabled`·`clickable`) |
  | --- | --- | --- | --- |
  | 빈 링크 | `허투루에 저장하기\n허투루에 저장하기` | `허투루에 저장하기` | 꺼짐 / false·false |
  | 맞는 링크 | `허투루에 저장하기\n허투루에 저장하기` | `허투루에 저장하기` | 켜짐 / true·true |
  | 처리 중 | `닫기\n닫기` | `닫기` | 꺼짐 / false·false |
  | 저장 중 | `저장 중\n저장 중...` | `저장 중` | 꺼짐 / false·false |
  | 저장 완료 | `저장 완료\n저장 완료` | `저장 완료` | 켜짐 / true·true |

  - 켜짐은 변경 전·후가 같다. 변경 후 맞는 링크 상태에서 OS 탭(iOS `orca emulator tap`, Android `adb shell input tap`)을 보내면 저장 요청 1건과 처리 중 '닫기'(꺼짐)로 바뀌었다.
  - 버튼 영역을 잘라 변경 전·후 원본 스크린샷을 픽셀 비교했다. 저장 중 상태의 돌아가는 진행 표시(iOS 24×14px, Android 45×29px)만 다르고 나머지 상태는 같다. 버튼 밖 차이는 상태 표시줄 시각과 처리 중 스켈레톤 반짝임이다.
  - Figma 비교는 모양이 바뀌지 않아 하지 않았다(기준 D05 `111:4902`, 버튼 `111:4917`).
  - 로컬 증거: `.utmp/ticket-492/screens/`(상태별 PNG·앱 상태 JSON·AX 덤프), `.utmp/ticket-492/ax-table.txt`, `.utmp/ticket-492/button-diff.txt`, `.utmp/ticket-492/compare-{ios,android}.png`.
- 실기기(사용자 확인, iPhone 13 iOS 27.2.1, `730aacf` 개발 빌드, VoiceOver):
  1. 빈 링크: "허투루에 저장하기" 한 번 + "흐리게 표시됨" — 통과.
  2. 맞는 링크: "허투루에 저장하기" 한 번, "흐리게 표시됨" 없음 — 통과.
  3. 두 번 탭: 저장이 한 번 시작되고 "닫기" 한 번 + "흐리게 표시됨" — 통과.
  4. 저장 완료: "저장 완료" 한 번, "흐리게 표시됨" 없음 — 통과.
  5. "저장 완료" 두 번 탭: 저장 화면이 닫히고 콘텐츠 하나 — 통과.
  6. 저장 중 '사진 첨부'로 옮긴 뒤 "저장 중": 못 봄. 운영 서버 저장이 빨라 사진 탭으로 옮길 시간이 없었다.
     첫 시도에서 들린 "닫기" 한 번 + "흐리게 표시됨"은 사진 탭으로 옮기지 않은 링크 탭 처리 중 상태의 이름으로, 코드상 그 상태 이름과 같다.
     "저장 중" 상태는 위 시뮬레이터·에뮬레이터 덤프와 루트 앱 위젯 시험(처리 중 '사진 첨부' 의미 tap → 사진 화면, 버튼 "저장 중")으로만 확인했다.
  - Android 실기기 TalkBack 결과는 없다.
- 검수: Codex 지적 2건(테스트를 루트 앱 흐름으로, 틀린 링크 진입 단언)과 Gemini 4 Neon 시험 검수의 자식 의미 노드 단언 1건을 반영했다. Neon의 실패 시 semantics 정리 지적은 판정에 영향이 없어 반영하지 않았다(반영본은 `try/finally`로 정리한다).
