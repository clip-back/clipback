# 공유 메뉴에서 미지원 사이트 주소만 여러 개 오면 미지원 사이트 안내 (#398)

2026-11-16, 브랜치 `fix/share-multilink-message`. 시작 커밋 `ce05582`, 구현 커밋 `f92d7c5`. 이후 이 작업의 변경은 문서와 main 병합(`f0b8da1`, `e2f0ff8`)뿐이며 이 작업의 제품·테스트 코드는 `f92d7c5`와 같다.

## 문제

- 출처: 팀 피드백 시트 106번(#367 실기기 진단 중 발견).
- 실기기 iPhone 13(iOS 27.2), TestFlight 0.6.1(15)에서 사파리로 Google 이미지 검색 화면을 열고 공유 → 허투루를 고르면 "공유할 수 없어요 / 한 번에 링크 하나만 공유해 주세요." 안내가 떴다(3번 재현). 넘어온 주소는 모두 google.com이라 사용자가 봐야 할 안내는 "Instagram 또는 YouTube 링크만 저장할 수 있습니다."다.
- 원인(iPhone 16 Simulator, iOS 18.6에서 확인): Google 이미지 미리보기에서 사파리 공유를 하면 `public.url` 항목 2개(`google.com/imgres?…`, `google.com/search?…#sv=…`)가 넘어온다. `ShareInputNormalizer.singleURL`이 지원 사이트 검사보다 먼저 주소 개수를 보고 `multipleLinks`를 던졌다. 텍스트 경로(iOS `ShareStore.createLink`, Android `ShareInput`)도 개수를 지원 사이트보다 먼저 봤다.
- 실기기의 실제 항목 구성은 TestFlight 빌드에 디버거가 붙지 않아 보지 못했다(같은 화면·같은 문구·같은 코드라 같은 원인으로 추정).

## 사용자 결정

- 2026-11-16 "추천대로":
  - ① 판정 순서: 링크가 여럿인데 지원 사이트 링크가 하나도 없으면 미지원 사이트 안내를 띄운다. 지원 사이트 링크가 섞여 있으면 지금처럼 "한 번에 링크 하나만" 안내를 띄운다.
  - ② 적용 범위: iOS URL 항목 경로·텍스트 경로와 Android 텍스트 경로에 모두 적용한다.
- 안내 문구는 바꾸지 않는다. 기존 테스트는 바꾸지 않는다(이슈 허용 표 모든 칸 "없음").

## 바꾼 것

- `frontend/ios/ShareCore/ShareModels.swift` `singleURL`: 같은 주소·같은 YouTube 페이지면 처음 주소를 쓰는 단계는 그대로 두고, 그 뒤에 "지원 host(`ShareStore.supportedHost`) 주소가 하나도 없으면 `unsupportedLink`" 단계를 더했다. 그 밖은 `multipleLinks`.
- `frontend/ios/ShareCore/ShareStore.swift` `createLink`: 링크 개수 검사 앞에 "링크 2개 이상이고 지원 host가 없으면 `unsupportedLink`" 검사 하나.
- `frontend/android/.../share/ShareInput.java`: 두 번째 링크가 있으면 나머지 링크까지 모두 host를 보고, 지원 host가 있으면 "한 번에 링크 하나만", 없으면 미지원 사이트 안내. host 목록은 `supportedHost(Uri)`로 뽑아 링크 하나 검사와 함께 쓴다(목록 그대로).
- 그대로인 것: 안내 문구, `ShareViewController.swift`, 링크 하나의 길이·계정 정보·포트 검사.
- 새 테스트:
  - iOS `ShareStoreTests.swift`: `testSeveralLinksWithoutSupportedHostAreUnsupported`(실측 Google 주소 2개 URL 항목, example.com+example.org URL 항목, 같은 텍스트), `testSeveralLinksWithSupportedHostStayMultipleLinks`(지원 주소가 섞인 URL·텍스트, 파일 주소, 같은 주소 두 번 등 결과가 그대로인 입력).
  - Android `ShareActivityTest.java`: `testSeveralUnsupportedLinksAreRejectedAsUnsupported`, `testSupportedLinkAmongSeveralIsRejectedAsMultiple`(알림창 문구, [닫기] 뒤 보관 0건).
- 문서: `frontend/ios/ShareVerification/README.md`, `docs/frontend/behavior.md`, `CHANGELOG.md` 미배포 수정.

## 바뀐 기존 테스트

없다. 이슈 허용 표의 기존 단언(`ShareStoreTests.swift`, `ShareActivityTest.java`, `ShareUITests.swift` `testSafariSharesPreparedYouTubePage`)은 결정 후 규칙에서도 모두 참이며 바꾸지 않고 통과했다.

## #329 순서 제약 확인

- #329(iOS 두 공유 화면 통합, 열림)가 옮기는 생명주기 줄을 이슈의 `rg` 명령으로 확인했다. `ShareStore.swift`의 `mark`·`discard`, `ShareViewController.swift`의 mark/discard·자격·취소 줄이다.
- 이 작업이 바꾼 줄은 `ShareModels.swift` `singleURL`, `ShareStore.swift` `createLink`의 받기 검사(177–179행), `ShareInput.java`, 새 테스트뿐이다. `ShareViewController.swift`는 바꾸지 않았다. 겹치지 않아 #329 병합 전에 진행했다.

## 검사

- 부분 검사(iOS `ShareStoreTests`: iPhone 16 Simulator, iOS 18.6 / Android `ShareActivityTest` 전체: Medium_Phone Emulator, Android 16):

| 실행 | iOS | Android |
| --- | --- | --- |
| 테스트만 바꾼 코드(변경 전) | 19건 중 3건 실패, 결과가 달라지는 행만 | 20건 중 1건 실패, `testSeveralUnsupportedLinksAreRejectedAsUnsupported` |
| 변경 후 | 19건 통과 | `OK (20 tests)` |
| 변형: 새 단계 삭제 | 달라지는 행 3건 실패 | `testSeveralUnsupportedLinksAreRejectedAsUnsupported` 실패 |
| 변형: "지원 주소가 하나라도 없으면" | 섞인 입력 행 3건 실패 | `testSupportedLinkAmongSeveralIsRejectedAsMultiple` 실패 |

- 변형은 파일 복사본으로 되돌리고 원본과 같은지 확인했다.
- 코드 리뷰(`ce05582..f92d7c5`): Standards·Spec 지적 0건.
- 전체 검증(`f92d7c5`): `VERIFY result=PASS scope=all checks=12 failed=0`.
  - `pytest: 2667 passed, 49 skipped, 3 warnings in 321.17s`
  - `pytest skip: 48 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)`
  - `pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)`
- 이 문서 커밋은 문서만 바꾸므로 전체 검사를 반복하지 않았다(근거 커밋 `f92d7c5`).
- 전체 검사(최종, main `c3db38f`(#397)를 합친 `e2f0ff8`): `VERIFY result=PASS scope=all checks=12 failed=0`.
  - `pytest: 2719 passed, 49 skipped, 3 warnings in 323.93s`
  - pytest skip 두 줄은 위와 같다.
- 그 전에 main `4261b35`(배포 기록 문서)만 합친 `0fead30`에서는 전체 검사가 두 번 연속 `VERIFY result=FAIL scope=all checks=12 failed=1 failed_checks=backend:pytest`였다. 실패는 `tests/integrations/test_summary_result_validation.py::test_headline_and_points_are_cleaned_and_joined[instagram-point-lf]`(`SummaryError: timeout`) 한 건이다. 이 작업은 backend를 바꾸지 않았고, 그 파일만 따로 5번 돌리면 모두 통과했다. 원인은 확인하지 않았고 별도로 진단한다.

## 화면 확인

로컬 대역 데이터(공유 fixture 서버)로 확인했다. 화면은 기존 OS 알림창이며 새 디자인이 없어 Figma 기준 화면은 없다(`docs/figma-ui-alignment-plan.md`의 공유 알림창 OS 유지).

| 상태 | 플랫폼·기기 | 변경 전 | 변경 후 | 판정 |
| --- | --- | --- | --- | --- |
| 사파리 Google 이미지 미리보기 공유 | iPhone 16 Simulator, iOS 18.6 | "한 번에 링크 하나만 공유해 주세요." | "Instagram 또는 YouTube 링크만 저장할 수 있습니다.", [닫기] 뒤 저장 대기 수 그대로 | 통과 |
| 사파리 YouTube 공유(`testSafariSharesPreparedYouTubePage`) | 같음 | 저장 완료 | 1회차 실패(아래), 2회차 저장 완료 | 통과(1회차 실패 기록) |
| 텍스트 `https://example.com/a https://example.org/b` | Medium_Phone Emulator, Android 16, 1080×2400, 글자 배율 1.0 | "한 번에 링크 하나만 공유해 주세요." | "Instagram 또는 YouTube 링크만 저장할 수 있습니다." | 통과 |
| 텍스트 `https://youtu.be/dQw4w9WgXcQ https://example.com/a` | 같음 | "한 번에 링크 하나만 공유해 주세요." | 같음 | 통과 |

- Google 미리보기는 실제 Google 페이지(네트워크)를 열었다. Android 보관 0건은 같은 APK의 `ShareActivityTest` 전체 통과로 확인했다.
- YouTube 변경 후 1회차: 저장 버튼 대기에서 실패했고 화면에 "한 번에 링크 하나만 공유해 주세요." 알림창이 있었다. 같은 빌드로 다시 돌린 2회차는 통과했다. 바뀐 코드에서 이 안내가 나오려면 서로 다른 주소 중 지원 host 주소가 있어야 하고, 그런 입력은 변경 전 코드에서도 같은 안내다. 그래서 이번 변경이 만든 결과는 아니라고 판단했다(아래 범위 밖 발견).
- 비교 이미지(변경 전·후, Figma 칸은 위 이유로 비움): `.utmp/ticket-398/screens/compare-ios.png`, `.utmp/ticket-398/screens/compare-android.png`.

## 범위 밖 발견

- iOS Simulator 사파리 YouTube 공유가 한 번 "한 번에 링크 하나만 공유해 주세요."로 거절됐다(위 1회차). 그때 사파리가 넘긴 항목은 디버거로 보지 않아 원인은 확인하지 못했다.

## 미검증

- 실기기 iPhone 13(iOS 27.2)에서 사파리 Google 이미지 미리보기 공유 때 미지원 사이트 안내가 뜨는지: 사용자 확인 대기.
- 원격 CI: PR 생성 뒤 확인한다.
- Docker가 필요한 deployment 테스트는 CI에서만 돈다(위 pytest skip 48건).
