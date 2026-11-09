# 랜덤 보기 마지막 카드 뒤 카테고리 목록으로 자동 복귀 (#309)

2026-11-09, 팀 피드백 시트 68(앱 0.5.0, "5개를 다 봐도 빈 화면으로 남음")을 브랜치 `fix/feedback-small-batch`에서 고쳤다.
코드 커밋은 `7cbc7ca`이고 전체 검증·기기 실행의 기준 코드도 `7cbc7ca`이다. 이 이력과 문서 갱신을 더한 커밋은 문서만 바꾼다.

## 사용자 결정

- 2026-11-09 "자동으로 나가기 (Recommended)"(설명 "마지막 카드를 넘기면 카테고리 목록으로 자동으로 나갑니다. 새 디자인이나 문구가 필요 없는 작은 이슈입니다.").
  2026-10-18 확정([카드 다시보기 1배율 맞춤](2026-10-18-card-review.md)의 "소진 뒤 상단 유지, 새 완료 동작 추가 안 함") 중 소진 뒤 머무르는 동작만 바꾼다.
  처음부터 0개인 빈 상태와 새 완료 문구·버튼 보류는 그대로다.
- 2026-11-09 "촬영만 줄여서 올림 (Recommended)": 영상은 RV-05·RV-EXIT만 양 플랫폼, RV-01·RV-SHORT·RV-EMPTY는 자동 테스트로만 확인한다.

## 구현

- `frontend/lib/features/archive/category_card_review_screen.dart`: 마지막 카드의 넘김 전환(기존 240ms 타이머, `mounted` 확인 유지)이 끝나 완료 상태가 되면 `widget.onExit()`를 한 번 부른다.
  수동 나가기와 같은 콜백이라 루트 앱은 랜덤 보기만 끄고(`setRandomViewing(false)`) 선택 카테고리·정렬·피드·스크롤을 그대로 둔다.
- 별도 "이미 나감" 표시는 두지 않았다. 전환 중 나가기·시스템 뒤로가기는 카드 화면을 지워 늦은 타이머가 `mounted`에서 끝나고, 완료 뒤에는 카드가 숨겨져 추가 넘김이 없다.
  프레임 없이 타이머만 도는 경우 콜백이 두 번 불려도 `setRandomViewing(false)`가 같은 상태를 다시 쓸 뿐이라 추가 화면 이동은 없다(검수 확인).
- 바꾸지 않음: 넘김 거리·속도·시간, 문구·레이아웃, 공개 생성자·콜백, 0개 빈 상태, API·DB·네이티브.

## 테스트

- 새 루트 앱 테스트 `frontend/test/card_review_auto_exit_test.dart`(메모리 API, 393×852):
  - 콘텐츠 1–5개 각각: 마지막 넘김 200ms 시점에는 카드 화면 유지, 250ms 뒤 목록 복귀. 복귀 화면·카테고리·정렬·목록 id·스크롤이 진입 전과 같고 1초 뒤에도 같다.
  - 25개·정렬 변경·스크롤 380: 수동 나가기 결과와 자동 나가기 결과가 진입 전과 같고, 다시 랜덤 보기에 들어가면 카드 5장이 나온다.
  - 마지막 전환 중 나가기 버튼·시스템 뒤로가기: 목록으로 한 번만 돌아오고 예외가 없다.
- `frontend/test/card_review_alignment_test.dart`(이슈 허용 표 안):
  - `count 1`·`count 5`의 소진 뒤 상단 유지·카드/진행 없음·수동 나가기 단언을 자동 복귀 1회(200ms 0회, 250ms 1회, 1초 뒤 1회)로 바꾸고 이름을 `... auto exits once after last card`로 바꿨다. 2·3·4개를 더했다.
  - `count 0`은 공통 반복에서 떼어 이름·빈 상태·수동 나가기 1회를 유지하고 "1초 뒤 자동 0회"를 더했다.
  - 새로 마지막 전환 중 연속 드래그(자동 1회), 전환 중 화면 제거(0회·예외 없음)를 더했다.
- `frontend/test/support/card_review_alignment_preview.dart`: 직접 하네스 `/run`의 `direct_complete`·`direct_complete_exit`를 `direct_complete_auto_exit`(자동 콜백 1회) 하나로 바꿨다. `kind=complete` 정적 장면과 G11 과거 증거는 그대로다. 이 `/run` 경로는 기기에서 다시 돌리지 않았다(미검증).
- 변경 전 실패: 같은 두 파일을 수정 전 코드로 돌려 12개 실패(모두 "자동 복귀 없음" 지점, 수동 나가기 비교는 통과), 수정 뒤 30개 통과. 관련 9개 파일(시스템 뒤로가기·콘텐츠 변경·상하 안전 영역·배율 이동·카테고리 목록 포함) 306개 통과, format·analyze 문제 없음.

## 전체 검사

- `7cbc7ca`에서 `python3 ~/.heoturu-agents/verify.py`: `VERIFY result=PASS scope=all checks=11 failed=0`.
  앱 단계는 CI App Validation의 4개 명령(`flutter pub get --enforce-lockfile`, `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze --no-pub`, `flutter test --no-pub`)과 같고, 앱 테스트 3460개 통과다.
  pytest `2330 passed, 47 skipped`(skip: `tests/deployment` 46건 Docker 복구 환경 필요, `tests/integration` 1건 S3 endpoint 필요).
- 로컬 실행 결과다. 원격 CI는 PR 뒤 확인한다.

## 기기 실행

로컬 대역 데이터(메모리 API, 카테고리 '일상'에 콘텐츠 25개, 최신순)로 실제 루트 앱을 띄웠다. 촬영 진입 파일은 작업 폴더 `.utmp/ticket-309/state_preview.dart`(커밋하지 않음)다.
입력은 OS 입력(`orca emulator gesture`·`tap`, Android 하나는 `adb shell input`)이고 글자 배율 1.0이다. 시각은 앱 안 `/log`(기기 시계 ms)로 쟀다. 운영 서버·실제 OAuth·실기기 검증은 하지 않았다.

| 상태 | iPhone 16 · iOS 18.6 Simulator | Medium_Phone · Android 16 Emulator |
| --- | --- | --- |
| RV-05 (목록 스크롤 → 랜덤 보기 → 5장 넘김) | 스크롤 170.7에서 진입, 마지막 카드 퇴장 시작 308ms 뒤 같은 목록·최신순·스크롤 170.7로 복귀 | 스크롤 255.6에서 진입, 퇴장 시작 513ms 뒤 같은 목록·최신순·스크롤 255.6으로 복귀 |
| RV-EXIT (마지막 카드 전환 중 나가기) | 퇴장 시작 1ms 뒤 나가기 탭, 92ms 뒤 목록으로 한 번 복귀, 2초 뒤에도 같은 목록·스크롤 | 퇴장 시작 10ms 뒤 나가기 탭, 353ms 뒤 목록으로 한 번 복귀, 이후 같은 목록·스크롤 255.6 |

- 두 플랫폼 모두 복귀 화면 스크린샷이 진입 전 목록과 같았다. 영상은 RV-05·RV-EXIT 플랫폼별 1개다.
- Android RV-EXIT은 에뮬레이터 프레임 간격이 커서 복귀가 탭 때문인지 240ms 타이머 때문인지 기록으로 가를 수 없다. 관측 결과(한 번만 복귀, 추가 이동 없음)만 적는다.
- 실패한 시도(보존, 결과로 쓰지 않음): iOS에서 따로 보낸 나가기 탭과 Android 시스템 뒤로가기 키는 입력 도구 지연(약 600–700ms)으로 자동 복귀 뒤에 도착해, 목록에서의 정상 동작(설정 버튼으로 카테고리 관리, 뒤로가기로 카테고리 목록)이 일어났다.
  Android에서 스와이프와 탭을 한 `gesture`로 보낸 시도는 두 번째 터치가 앱에 전달되지 않았다. 그래서 **Android 시스템 뒤로가기를 전환 중에 맞춘 기기 확인은 미검증**이며 루트 앱 위젯 테스트로만 확인했다.
- RV-01·RV-SHORT·RV-EMPTY는 결정대로 자동 테스트로만 확인했다. RV-EMPTY는 카드 화면에 0개를 직접 넣는 하네스로 확인했고, 루트에서는 콘텐츠 0개 카테고리에 랜덤 보기 버튼이 있는지 확인하지 않았다.
