# 저장 화면 제출 상태를 ContentSaveSubmission으로 옮기기 (#288, #289, #290)

2026-11-08, 상위 스펙 #288의 두 티켓을 브랜치 `refactor/save-submit-viewmodel`에서 진행했다.
#289는 앱 코드를 바꾸기 전에 동작 고정 테스트를 추가했고(커밋 `3fdd1a2`), #290은 시트마다 만드는 제출 객체 `ContentSaveSubmission`으로 저장 화면의 제출 상태를 옮겼다(커밋 `80cb630`).
이 기록을 더한 커밋은 문서만 바꾼다. 전체 검증과 기기 실행의 기준 코드는 `80cb630`이다.
사용자에게 보이는 동작은 바뀌지 않으므로 CHANGELOG `미배포`에는 적지 않았다.

## 사용자 결정

- 2026-11-08 기획 회의 Q1–Q10 "모두 추천대로": 범위는 콘텐츠 저장 화면(`showContentSaveScreen`)의 링크·사진 제출이고, 공유 저장 시트는 범위 밖이다.
  앱 전체 `ContentSaveViewModel`로는 옮기지 않고, 시트마다 만들어 닫힐 때 `dispose`하는 작은 제출 객체를 둔다(Q2). 고정 테스트를 먼저 추가하고, 제출 객체만 따로 검사하는 단위 테스트는 두지 않는다(Q7). GLOSSARY·ADR은 바꾸지 않는다(Q8).
- 같은 날 스펙 리뷰 3건 "추천대로": G6–G9를 고정 대상에 더하고, dispose 취소 제거 변형의 필수 실패 대상을 같은 계정의 C1·G6으로 하며, 링크·사진의 계정 변경 처리 차이는 미확인 조사 후보로만 적는다.
- 화면 변화가 없어 변경 전·후·Figma 3면 비교는 하지 않는다(Q4). iOS Simulator와 Android Emulator에서 링크 저장·사진 저장을 1회씩 성공시키고 결과 화면 스크린샷을 남긴다.

## 구현 (#290)

- `frontend/lib/features/content/view_models/content_save_submission.dart`(새 파일): `ContentSaveSubmission`(`ChangeNotifier`)과 제출 내용 `PendingSave`, 저장 결과 `SavedSave`.
  - 생성자는 저장 콜백 두 개를 받는다. 읽기 값은 `isSaving`·`pending`·`saved`, 메서드는 `photoSelected(bytes)`·`submitLink(url)`·`submitPhoto(bytes, filename)`이다. 제출 메서드는 실패하면 보여 줄 문구를, 그 밖에는 null을 돌려준다.
  - 사진 제출 키는 첫 사진 제출 때 만들고 성공 전까지 재사용한다. 사진을 고를 때 지금 선택과 bytes가 다르면 비운다. 링크 제출에는 키가 없다.
  - 저장 결과가 있거나 저장 중이면 제출하지 않는다. 사진 제출마다 `ApiRequestScope`를 새로 만들고 그 `run` 안에서 사진 저장 콜백을 시작한다. 링크 제출은 요청 수명 없이 실행한다.
  - 오류 문구는 `ClipbackApiException`이면 그 문구, 그 밖에는 "저장하지 못했어요. 다시 시도해 주세요."다. `dispose`는 진행 중인 사진 요청을 끊고, 그 뒤 결과가 와도 상태를 바꾸거나 알리지 않는다.
- `frontend/lib/features/content/save_content_screen.dart`: 위젯의 제출 상태 필드와 직접 콜백 호출을 지우고 제출 객체를 부른다. 위젯은 알림마다 다시 그리며, 입력·탭·스크롤·파일 선택·오류 안내 3초 표시는 그대로 맡는다. 위젯 트리·문구·`ValueKey`는 바꾸지 않았다.
  - 성공 뒤 결과 탭 전환·스크롤 맨 위·타이머 취소는 제출 메서드가 끝난 뒤 위젯이 한다. 위젯은 제출 객체의 `saved`·`isSaving`을 읽어 지금과 같은 조기 반환을 한다(성공 뒤 이전 제출 콜백이 불려도 스크롤을 되돌리지 않기 위함).
- 제거 검색 두 개(`ApiRequestScope|newEventUuid|_photoSubmissionKey|_savedResult|_pendingSubmission|_isSaving`, `widget\.onAdd(Link|Screenshot)\(`)는 저장 화면 파일에서 모두 0줄이다(91bb8eb에서는 32줄·2줄).
- `frontend/README.md`: 위젯 관리 문단에 제출 객체 한 줄, 코드 구조 표의 `api_request_scope.dart` 줄에 "저장 화면 사진 저장의 닫기 취소"를 더했다.
- 바꾸지 않음: 저장 콜백 타입 두 개, `showContentSaveScreen`·`AddContentSheet` 생성 인자, `ContentSaveViewModel`, `ContentActions`, Repository·API 클라이언트, 저장 화면을 여는 화면 5곳과 앱 루트.

## 테스트

- 고정 테스트(#289): `frontend/test/save_submission_behavior_test.dart`, 테스트 12개. #288 표의 G1–G9를 단언한다. G1·G4·G7–G9는 `AddContentSheet`에 가짜 콜백을, G2·G3·G5·G6은 실제 앱과 가짜 서버(`MockClient`)를 쓴다.
- 기존 회귀 6개 파일 `saved_content_confirmation_test`, `screenshot_auth_test`, `share/manual_save_preservation_test`, `link_pending_alignment_test`, `photo_pending_alignment_test`, `content_auto_category_test`와 고정 테스트는 #290에서 수정하지 않았다(`git diff --stat 3fdd1a2 80cb630 -- frontend/test` 빈 결과).
- #290 작업 중 바꾼 부분의 테스트: 고정 파일, 회귀 6개 파일, 저장 화면 레이아웃·자산 6개 파일(`save_base_typography`, `save_footer_layout`, `save_paste_layout`, `save_scaled_layout`, `save_search_safe_area`, `screenshot_asset`)을 함께 돌려 527개 통과.

## #289 고정 테스트의 실제 관측값과 main 대조 (#289 결과 댓글에서 옮김)

원문: [#289 댓글](https://github.com/clip-back/clipback/issues/289#issuecomment-6711736668). 9행 모두 #288 표의 예상과 같았다.

| ID | 실제 관측값 |
| --- | --- |
| G1 | 사진 A 실패 → B를 고르고 제출하지 않음 → A를 다시 고르고 제출: 두 키 모두 UUID 형식이고 서로 다르다 |
| G2 | 실제 앱에서 링크 요청 중 시트를 닫은 뒤 응답이 오면 저장한 콘텐츠(id 7)의 상세 화면이 보인다 |
| G3 | 사진 요청 중 계정이 바뀌면 로그아웃 때 시트가 닫힌다. 응답 뒤 상세 화면이 없고 새 계정 홈에도 없다 |
| G4 | 서버 오류가 아닌 실패는 링크·사진 모두 "저장하지 못했어요. 다시 시도해 주세요." |
| G5 | 링크 POST에는 `Idempotency-Key`가 없고, 사진 업로드에는 UUID 키가 있다 |
| G6 | 같은 계정에서 사진 요청 중 시트를 닫은 뒤 성공: 홈 목록에 없고 상세 이동·예외도 없다 |
| G7 | 실패 안내가 2999ms까지 보이고 3000ms에 사라진다. 다시 실패하면 그때부터 3초가 새로 시작된다 |
| G8 | 제출 대기 중 다른 탭으로 옮겨 스크롤한 뒤 성공: 제출한 탭과 제출 내용의 결과 화면이 보이고 스크롤은 0이다 |
| G9 | 성공 전에 얻은 붙여넣기 콜백을 성공 뒤 부르거나, 클립보드 응답보다 저장 성공이 먼저 와도 링크 입력과 결과가 바뀌지 않는다 |

- main 대조: 임시 워크트리(de31a94)에 같은 파일(`cmp` 동일)을 넣어 12개 모두 통과했다. de31a94의 `frontend/`는 91bb8eb와 같다(`git diff --stat 91bb8eb de31a94 -- frontend` 빈 결과). 임시 워크트리는 확인 뒤 지웠다.
- `3fdd1a2` 전체 검증: `VERIFY result=PASS scope=all checks=11 failed=0`, pytest `2320 passed, 47 skipped`, 앱 테스트 3380개 통과.

## 변형 실험

#289(원문은 위 댓글): 위젯 코드에 적용했다. #290: 같은 규칙을 새 제출 객체에 적용했다. 두 번 모두 앱 코드를 복사해 두었다가 되돌렸고, 고정 파일과 회귀 6개 파일을 실행했다.
#290은 매 실험 뒤 `cmp`로 복사본과 같음을, `git diff`로 API 파일이 원상태임을 확인했다(작업 폴더 `.utmp/ticket-290/mutation-*.log`, 변형 코드 `mut/apply.py`).

| 변형 | #289 실패 | #290 실패 |
| --- | --- | --- |
| 사진 키를 비우는 시점을 "제출 때 직전 제출 bytes와 비교"로 | G1 | G1 |
| 링크 저장도 요청 수명 `run` 안에서, 닫을 때 끊김 | G2 | G2 |
| 기본 문구를 빈 문구로 | G4 링크·사진 | G4 링크·사진 |
| 기본 문구를 오류 객체 문자열로 | G4 링크·사진 | G4 링크·사진 |
| 링크 저장 요청에 제출 키(API 계층, `SaveLinkCallback`에 키 인자가 없음) | G5 | G5 |
| 사진 저장 요청에서 키를 뺌 | 13개: S3 "timed out photo retries…", S4 409·410·수동 재시도 2개·원본 불량 4개, "photo selection locks…", "closed photo screen…", G1, G5 | 같은 13개 |
| 닫힐 때 사진 요청을 끊지 않음 | C1 "closed photo screen ignores late success and new screen gets new key", G6 (G3 통과) | C1, G6 |
| 사진 저장 콜백을 `run` 밖에서 시작 | C1(`screenshot_auth_test`), G6 | C1, G6 |

G3은 계정 변경 시 API·Repository·Action의 별도 세대 검사가 있어 dispose 취소 제거 변형의 필수 실패 대상이 아니다(스펙 리뷰 결정). 계정 변경 보존 검사로 남는다.

## 검증

- #290 리뷰(Codex 검수): Standards 0건, Spec 0건. 코드 수정 없음.
- 작업자 전체 검증(`80cb630`): `VERIFY result=PASS scope=all checks=11 failed=0`, pytest `2320 passed, 47 skipped, 3 warnings`, 앱 테스트 `+3380: All tests passed!`.
- 최종 리뷰(#288 범위) 재실행(`80cb630`): `VERIFY result=PASS scope=all checks=11 failed=0`
  - pytest: 2320 passed, 47 skipped, 3 warnings in 230.97s (0:03:50)
  - pytest skip: 46 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
  - pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
  - 앱 테스트: `flutter test --no-pub` `+3380: All tests passed!`
  - 백엔드는 바꾸지 않았다. 건너뛴 Docker 복구·S3 통합 테스트는 이 변경과 무관하며 CI·별도 환경 대상이다.
- CI App Validation의 4개 명령(`flutter pub get --enforce-lockfile`, `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze --no-pub`, `flutter test --no-pub`)은 verify의 앱 단계가 같은 문구로 실행했다.
- push·원격 CI·실기기·운영 서버 확인은 하지 않았다. 원격 CI는 PR 생성 뒤 실행한다.

## 기기 실행 확인

2026-11-08 04:43–04:52 KST, 감독이 최종 리뷰·전체 검증 뒤 실행했다. 실행한 앱의 코드는 `80cb630`과 같다. 시작 직전 `HEAD..origin/main`은 비어 있었다.

- 실행 구성: 실제 `ClipbackApp`, 저장 화면, `ContentSaveViewModel`, `ContentActions`, Repository, `ClipbackApi`에 앱 프로세스 안의 `MockClient` 메모리 서버를 붙인 로컬 대역이다. 링크 저장은 id 9001, 사진 저장은 id 9002로 답한다. 운영 서버·사용자 데이터는 쓰지 않았다.
- 입력: 링크는 Orca의 OS 탭과 ASCII 입력으로 `https://example.com/ticket-290`을 썼다. 미리 채운 값은 없다. 사진은 실제 OS 사진 선택기에서 시험 사진을 골랐다(파일 선택기 대역 없음).
  - 시험 사진: 촬영 키트 `make_position_photo.py --expected FULL`로 만든 300×900 PNG, 7958바이트, SHA-256 `03c98e90d757eae9ca525080ffa2e7b1185e9ba81d9d2188d1be6813b3208100`.
  - Android는 화면 키보드가 나왔다(입력 확인 아래쪽 inset 336.381, 문자열·초점·입력 출처 3표본 통과).
  - iOS는 하드웨어 키보드 경로라 화면 키보드가 나오지 않았다. 첫 입력 확인은 키보드 inset 0으로 시간 초과 실패했다(`ios-after-link-input.input.json`, 보존). 문자열·초점은 정확했고 입력 방법은 바꾸지 않았다. 화면 키보드 없음 조건(`link-input-hardware-keyboard`)으로 3표본 통과했다(`ios-after-link-input-hardware.input.json`). iOS 화면 키보드 배치는 확인하지 않았다.
- 글자 배율은 두 플랫폼 모두 1.0이다. 결과·상세 화면의 키보드 inset은 0이다.

| 플랫폼 | 기종·OS | 논리 크기(probe JSON) | 시나리오와 결과 |
| --- | --- | --- | --- |
| iOS | iPhone 16 Simulator, iOS 18.6 | 393×852 | 링크 입력 → 저장 → 결과 화면(콘텐츠 9001, 버튼 "저장 완료") → "저장 완료" → 상세 9001 → 홈 → 사진 첨부 → OS 선택기에서 시험 사진 → 저장 → 결과 화면(9002) → "저장 완료" → 상세 9002 |
| Android | Medium_Phone Emulator, Android 16(API 36) | 411.42857142857144×914.2857142857143 | iOS와 같은 순서와 결과 |

- 요청 기록(probe JSON): 링크 저장 요청 1회, `Idempotency-Key` 없음. 사진 업로드 1회, 키는 UUID 형식. 업로드 바이트와 결과 화면의 사진 바이트 모두 7958바이트이며 SHA-256이 시험 사진과 같다. 예상 밖 요청 목록은 8개 상태 모두 비어 있다.
  iOS 선택기는 파일 이름을 `image_83F5CC54-E931-4090-B114-58D1105AF903_1794080938.png`로 바꿔 넘겼고, Android는 `position-photo.png` 그대로였다. 상세의 원본 이미지 요청은 0회였다(원본 펼치기·내려받기는 이번 확인 범위 밖).
- 화면: 감독이 원본 PNG를 열어 결과 화면의 제출 내용과 "저장 완료" 버튼, 상세 화면 제목과 시트 닫힘, 키보드·OS 메뉴 없음을 확인했다. 원본 스크린샷은 보정하지 않았다.
- 증거: 작업 폴더 `.utmp/ticket-290/`(커밋하지 않음)의 `supervisor-device-results.md`, `capture-guide.md`, `capture-manifest.json`, `screens/`의 PNG와 같은 이름의 JSON이다.
  - iOS: `ios-after-link-result`, `ios-after-link-detail`, `ios-after-photo-result`, `ios-after-photo-detail`, 화면 기록 `ios-flow-log.json`
  - Android: `android-after-link-result`, `android-after-link-detail`, `android-after-photo-result`, `android-after-photo-detail`, 화면 기록 `android-flow-log.json`
  - 이미지는 아직 GitHub에 올리지 않았다. PR 본문에 첨부한다.
- 촬영 준비: 앱 코드는 바꾸지 않고 작업 폴더의 촬영 진입 파일만 만들었다. 촬영 보충 검수의 지적 2건(탭 후보를 하나로 줄여 중복을 숨김, 화면 기록이 시트 뒤 상세를 먼저 기록)을 반영했다. 반영 전 파일과 빌드 전 확인 로그는 `pre-review/`에 두었고, 반영 뒤 빌드 전 확인은 두 플랫폼 모두 18개 통과·탭 검사 5개 통과였다(`preflight-<plat>-after.review-fix.log`).
- 제한: 회의 결정에 따라 변경 전 촬영, 3면 비교, 영상은 없다. 글자 배율 1.0만 확인했다.

## 동작 보존 증거에서 제외하는 것 (#288)

아래 항목은 이번에 고정하지 않았으며, "동작 변경 없음" 주장에도 넣지 않는다.

- 링크 요청 중 계정이 바뀐 경우의 처리. Action의 링크·사진 후처리 분기는 다르지만 실제 API·Repository에도 계정 검사가 있어 전체 동작 차이는 미확인이다. 링크 저장 경로의 코드는 바뀌지 않았다.
- 레이아웃·글자 배율·안전 영역. 기존 레이아웃 테스트(`save_footer_layout_test`, `save_scaled_layout_test`, `save_paste_layout_test`, `save_search_safe_area_test`, `save_base_typography_test`, `link_pending_alignment_test`, `photo_pending_alignment_test` 등)가 그대로 통과하는 것으로 갈음한다.
- 파일 선택기 자체의 동작과 링크 형식 검사(350ms). 위젯에 그대로 남는 코드다.

## 범위 밖 후보 (고치지 않음, #288 Out of Scope)

1. 링크 저장 요청 중에 시트를 닫아도 저장이 계속되고, 끝나면 상세 화면으로 이동한다(G2로 고정한 현재 동작).
2. 요청 중 계정 변경 때 링크와 사진의 처리 차이(조사 후보). 회의 당시 코드 읽기로는 "사진은 오류, 링크는 결과 반환"으로 예상했으나, 스펙 리뷰에서 링크도 Repository `_save`와 API 인증 세대 검사를 거친다는 것을 확인했다. 계정이 어느 대기 지점에서 바뀌는지에 따라 달라지며 미확인이다.
3. 링크 저장에는 제출 키가 없어, 응답이 끊긴 뒤 다시 시도하면 같은 링크가 두 번 저장될 수 있다(코드 읽기 기준, 재현하지 않음).
