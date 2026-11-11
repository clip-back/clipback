# 콘텐츠 상세 제목·요약 글씨 1px 키우고 문의하기를 구글 폼으로 열기 (#336)

2026-11-12, 브랜치 `fix/summary-font-and-contact-form`. 팀 앱 테스트 피드백 시트 28·18(앱 0.3.0)에서 왔다.
시작 커밋 `42480b3`, 구현 커밋 `ddc85cb`, 리뷰 반영 커밋 `0caaf03`(전체 검증·변경 후 촬영 기준).
이 기록의 검증·화면 절을 더한 커밋은 문서만 바꾼다.

## 문제

- 콘텐츠 상세의 ‘요약’·‘원본 이미지 보기’·‘함께 보면 좋은 콘텐츠’ 제목이 16px, 요약 본문이 15px로 Figma F02·F04(17·16px)보다 1px 작았다.
- 마이 → 문의하기와 로그인 실패 화면의 ‘문의하기’는 메일 주소와 ‘목데이터 기준 응답 시간…’ 정적 문구 시트만 열어 실제로 문의를 보낼 수 없었다.

## 사용자 결정

- 2026-11-11 팀 회의: [28] “지금 콘텐츠의 본문 요약 글씨 및 요약 내용 1px 키움 나머지는 나중에”, [18] “구글폼 링크 연결”, 답변 약속 없음. 폼 주소 `https://forms.gle/dGjWJc643ZwrXTrF7`(2026-11-12 사용자 제공).
- 2026-11-12 후속 선택: 범위 “상세 제목 셋 + 요약 본문”, 넘침 “최소 24, 커지면 같이”, 적용 범위 “마이와 로그인 실패 둘 다”, 여는 방식 “바로 폼 열기”, 실패 문구 ‘문의하기를 열지 못했어요. 다시 시도해 주세요.’.
- 2026-11-12 구현 중 결정
  - “실제 앱 글꼴 그대로”: 이슈는 실패 문구를 Pretendard로 확인하라고 했지만, 앱의 스낵바는 테마의 `textTheme` 병합 때문에 글꼴 이름이 ‘Roboto’다(앱 전체 스낵바 공통, iOS는 시스템 글꼴로 대체). 실제 앱 스타일 그대로 확인한다. 테스트에서는 글자당 1em 폭인 기본 테스트 글꼴로 그려져 실제 한글 글꼴보다 넓게 잰다. 스낵바 글꼴 자체는 이번 범위가 아니다.
  - “그대로 두고 기록”: 로그인 실패 화면(393×852)에서 실패 스낵바(y 784–852)가 맨 아래 ‘문의하기’(y 802–820)를 덮는다. 원본 링크와 같은 스낵바 방식을 유지하고, 스낵바가 사라진 뒤(약 4초) 다시 누르면 다시 열리는 것을 테스트한다.

## 구현 (`ddc85cb`)

- 상세(`detail_screen.dart`): 상세 제목 스타일 17px·자간 -0.425, 요약 본문 16px·자간 -0.4(줄 높이 1.6 그대로). ‘원본 이미지 보기’ 줄의 `SizedBox(height: 24)`를 `minHeight: 24`로 바꿨다.
- 문의(`lib/features/account/contact_form.dart`): 기존 원본 링크 외부 열기(`PlatformOriginalLinkOpener`, `url_launcher` 외부 앱 모드)로 폼을 연다. OS 거절(false)·예외는 실패로 본다. 열기 요청이 끝나기 전 누름은 무시한다.
  - 마이: 고객지원 ‘문의하기’ 줄이 폼을 열고, 실패하면 앱 공통 스낵바로 안내한다(화면이 사라졌으면 안내하지 않음).
  - 로그인 실패: 지금 실패일 때만 열고, 열기 요청이 끝날 때까지 다른 실패 동작(방법 선택·게스트)을 막는다. 끝난 뒤에도 같은 실패일 때만 안내한다. 실패 화면과 상태는 그대로 남고 로그인·게스트 요청은 생기지 않는다.
  - 문의 시트(`ContactSheet`)와 그 문구를 지웠다.

## 테스트

먼저 테스트를 바꿔 실패를 본 뒤 고쳤다(로그는 로컬 `.utmp/ticket-336/partial-*.log`, 저장소에 넣지 않음).

| 이슈 회귀 | 테스트 | 수정 전 |
| --- | --- | --- |
| 1 글자 크기·자간 | `detail_alignment_test.dart` `detail 1x <scene> <platform> width <width>`(12개), `photo original row <scale>x <platform>`의 17px 단언 | 실패(16·15px) |
| 2 ‘원본 이미지 보기’ 줄 | `photo original row 1.0x/1.1x/1.2x/1.3x <iOS·Android> keeps 17px text`(배율마다 따로, Pretendard): 줄 24/24/24/26, 글자 상자가 줄 안·실제 높이와 같음, 펼침·접힘 | 실패(1.3배 줄 24, 글자 상자 24 < 실제 25) |
| 3 긴 요약 1.3배·폭 320 | `long summary 1.3x <platform> width 320 shows every line` | 실패(15px) |
| 4 마이 → 폼 한 번 | `contact_form_root_test.dart` `my contact opens the form once without a sheet`(연타 포함, 외부 앱 모드) | 실패(시트) |
| 5 로그인 실패 → 폼 | `login_failure_navigation_test.dart` `contact opens form once and preserves same failure`, `OS back and stale failure callbacks…` | 실패(시트) |
| 6 열기 실패 | `my contact <os-false|exception> shows message…`, `contact <os-false|exception> shows message…`(로그인 실패, 안내가 사라진 뒤 다시 누름) | 실패(안내 없음) |
| 7 실패 문구 1.0·1.3배·폭 320 | `contact failure message <scale>x width 320 is not clipped` | 실패(안내 없음) |

- 바꾼 기존 테스트: 이슈 허용 표 안의 `detail_alignment_test`·`login_failure_navigation_test`·`my_screen_figma_test`·`phone_width_test`·`support/login_failure_preview.dart`. 문의 시트 삭제로 `support/my_preview.dart`·`notice_alignment_preview.dart`의 시트 목록과 `notification_alignment_preview.dart`의 시트 판별에서 문의하기를 뺐다.
- 실패 문구는 실제 앱 스낵바 스타일로 쟀다(위 결정). 테스트에서는 글자당 1em 폭인 기본 테스트 글꼴이라 실제 한글 글꼴보다 넓다.

## 검토

검수(Codex, `.utmp/review-336.md`): Standards 0개, Spec 중간 2개.

- 반영(`0caaf03`): 마이 미리보기 `/run`이 지운 문의 시트를 기다리던 것, 로그인 실패 미리보기가 열기 기록 대역을 늘 설치해 `/scene` 뒤 실제 브라우저가 열리지 않던 것. 대역은 `/run` 동안만 쓰고 끝나면 원래 launcher로 되돌린다.
- 반영하지 않음: OS가 열기 요청에 끝내 답하지 않으면 연타 보호가 풀리지 않는다(불확실 항목). 이슈가 시간 제한·취소를 정하지 않아 범위 밖으로 남겼다.
- 문구 검토(better-writing 시험): 지적 없음.

## 검증

- `VERIFY result=PASS scope=all checks=11 failed=0`(코드 `0caaf03`).
  - CI App Validation 명령: `flutter pub get --enforce-lockfile`, `dart format --output=none --set-exit-if-changed lib test`(0 changed), `flutter analyze --no-pub`, `flutter test --no-pub`(+3498 All tests passed).
  - 백엔드: pytest 2503 passed, 47 skipped(46 `tests/deployment` Docker 복구 시험 조건, 1 `tests/integration` S3 주소 없음). 백엔드는 바꾸지 않았다.
- `git diff --check` 통과.

## 화면 확인

2026-11-12, iPhone 16 / iOS 18.6 Simulator(Simulator.app 없이 headless)와 `Medium_Phone` / Android 16 Emulator. 로컬 메모리 서버 대역이며 운영 서버·실제 로그인은 쓰지 않았다.
변경 전은 `42480b3`의 바뀐 앱 파일 4개로, 변경 후는 `0caaf03`으로 같은 촬영 진입 파일(`.utmp/ticket-336/state_preview.dart`)을 빌드했다.
Figma 기준은 F02 `111:3842`(375×894)와 ‘전문 보기’ 줄 `111:3864`(2026-11-12 02:13 KST 조회)다.

| 상태 | iOS | Android |
| --- | --- | --- |
| 링크 상세(요약·연관 있음) 1.0배 | ‘요약’·‘함께 보면 좋은 콘텐츠’ 16→17px, 요약 15→16px. 맨 아래 스크롤 끝 128→136 | 같은 값 |
| 사진 상세 ‘원본 이미지 보기’ 1.0배 | 줄 24 그대로, 글자 상자 19→20 | 같음 |
| 사진 상세 ‘원본 이미지 보기’ 1.3배 | 줄 24→26, 글자 상자 24(실제 25에 눌림)→26(실제 26) | 같음 |
| 마이 → 문의하기 | 변경 전 시트 → 변경 후 Safari가 폼 주소를 열고, 상단 ‘허투루로 돌아가기’로 같은 마이 화면 복귀 | Chrome이 열리고 뒤로 가기로 같은 마이 화면 복귀 |
| 로그인 실패(HTTP 503) → 문의하기 | 변경 전 시트 → Safari, 복귀 뒤 같은 실패 화면, 소셜 발급 1회 그대로·게스트 0 | Chrome, 같은 결과 |

- 폼 주소는 브라우저에서 폼 대신 **Google 로그인 화면**으로 넘어간다. Mac에서도 `forms.gle` → `docs.google.com/forms/.../viewform` → `accounts.google.com` 로그인으로 이동한다. 폼이 응답자 로그인을 요구하도록 설정돼 있는 것으로 보이며 앱 밖(폼 설정) 문제다.
- 열기 실패 스낵바는 시뮬레이터·에뮬레이터에서 실패를 만들 수 없어 찍지 않았다. 자동 테스트(회귀 6·7)로 확인했다.
- 맨 아래 위치는 글씨가 커져 스크롤 끝이 달라 변경 전·후 비교 이미지에서 뺐다(iOS 원본만 남김). Android는 스와이프가 스크롤을 옮기지 않아 맨 아래를 찍지 않았다.
- 기기 화면(393×852, 411.4×914.3)과 Figma 프레임(375×894)의 크기·안전 영역 차이는 보정하지 않았다.

### 증거(로컬, 저장소에 넣지 않음)

- 비교 이미지: `.utmp/ticket-336-screens/compare-{ios,android}.png`(상세·사진·마이), `contact-{ios,android}.png`(문의 흐름).
- 원본·조건 JSON: `.utmp/ticket-336/screens/`.

## 범위 밖과 미검증

- 구글 폼이 응답자 Google 로그인을 요구한다(폼 설정 확인 필요).
- 앱의 모든 스낵바 글꼴이 Pretendard가 아니다(테마 `textTheme` 병합). 이번에는 고치지 않았다.
- 로그인 실패 화면에서 실패 스낵바가 ‘문의하기’를 약 4초 덮는다(결정대로 기록만).
- OS가 열기 요청에 답하지 않을 때 연타 보호가 풀리지 않는다.
- 실기기 확인은 이슈가 요구하지 않아 하지 않았다.
