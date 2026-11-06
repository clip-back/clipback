# 링크 상세의 전문 보기 제거 (#201)

- 기록일: 2026-11-06 (KST).
- 이슈: [#201](https://github.com/clip-back/clipback/issues/201).
- 작업 디렉터리: `/Users/leehyeongyu/orca/workspaces/Clipback/link-original-open`.
- 시작 커밋: `e4baaa2`. 구현·전체 검증 기준: `bf8be9e48eaf56ea02c8e37e94720d32c5cdbfb5`.
- 검수: Standards 0건 / Spec 0건(`.utmp/review-201.md`). 리뷰 반영 수정 없이 전체 검증했다.

## 결정과 변경

2026-11-06 사용자 결정: "링크는 전문 보기 없애고 링크 버튼을 통한 링크로 이동하기 기능만 남기기로 했어".
배치 결정 A: 줄과 함께 구분선 하나와 그 여백도 뺀다.
이 결정은 2026-11-03의 "원본 링크 열기" 줄 교체 안을 대신했고, 그 안으로는 구현·커밋이 없었다.

- 링크 콘텐츠 상세: 요약 → 16px → 구분선 → 16px → 태그. "전문 보기" 줄, 펼친 글, 두 번째 구분선과 그 여백을 뺐다.
  원본은 날짜 줄 링크 버튼(`detail-original-button`)으로만 열며 외부 열기·성공 후 통계·실패 안내는 그대로다.
- 스크린샷 콘텐츠 상세: "원본 이미지 보기" 펼침과 링크 버튼의 원본 이미지 시트를 유지했다.
- 링크 전용이던 `FullContentPreview`와 그 글자 스타일을 삭제했다.
- 링크 전문 펼침을 기대하던 테스트 4개 파일과 미리보기 도구 4개(`test/support/detail_preview.dart`·`today_preview.dart`·`weekly_preview.dart`·`original_link_preview.dart`)를 새 동작에 맞췄다.
  사진 단언, 링크 성공 통계·실패 안내 단언은 바꾸지 않았다. 미리보기 상태의 `expanded` 키와 detail_preview의 링크 'expanded' 장면은 삭제했다.
- 현재 기준은 [화면 맞춤 계획](../figma-ui-alignment-plan.md#figma-current-19)과 [디자인 확인 필요](../figma-ui-alignment-plan.md#figma-pending-19)에 반영했다. 새 배치의 Figma 기준 노드는 없다.

## 자동 검증

- RED: `.utmp/ticket-201/partial-red.log`. 수정 전 코드에서 `original_link_screen_test.dart`의 링크 테스트가 "전문 보기" 없음 단언에서 실패했고 사진 테스트는 통과했다.
- GREEN: `.utmp/ticket-201/partial-green.log`. `flutter analyze --no-pub` 통과, 관련 테스트 7개 파일 75개 통과.

검수 뒤 clean인 위 기준 SHA에서 `busy.sh --wait`로 차례를 기다리고 전체 검증을 한 번 실행했다(2026-11-06 15:17–15:23 KST).

```sh
~/.heoturu-agents/busy.sh --wait && ~/.heoturu-agents/busy.sh && python3 ~/.heoturu-agents/verify.py --log-dir .utmp/ticket-201
```

실제 `verify-result.txt` 원문:

```text
pytest skip: 45 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=11 failed=0 logs=/Users/leehyeongyu/orca/workspaces/Clipback/link-original-open/.utmp/ticket-201/20261106T151706-0655ee024671
```

실제 백엔드 pytest 요약 및 앱 전체 테스트 최종 줄:

```text
2048 passed, 46 skipped, 3 warnings in 174.55s (0:02:54)
02:55 +3059: All tests passed!
```

- 콘솔: `.utmp/ticket-201/full-verify-console.log`. 결과: `.utmp/ticket-201/verify-result.txt`와 실행 폴더의 `verify-result.txt`.
- `verify-progress.json`의 모든 진행 이벤트는 위 기준 SHA, dirty=false다.
- 46 skip은 통과가 아니다. Docker deployment 45건과 전용 S3 endpoint가 필요한 CLI 통합 1건은 미실행이다.
- 후속 커밋은 문서뿐이며 제품·테스트 코드는 위 PASS SHA와 같아 전체 검증을 반복하지 않는다.

## 화면·외부 전환 확인

2026-11-06 15:24–15:38 KST 감독이 기기 잠금을 확보해 iOS 다음 Android 순서로 실행했다.
API·계정·공유 데이터는 기존 `original_link_preview.dart` 기반 대역이며, 실제 앱 루트와 실제 URL launcher를 사용했다.
진입 파일은 `.utmp/ticket-201/capture/state_preview.dart`, fixture 사전 테스트는 같은 폴더의
`state_preview_check_test.dart` 1개 통과다. 변경 전은 시작 SHA의 `detail_screen.dart`로 임시 빌드하고 원래 파일 복원을 확인했다.
제품 코드·fixture는 전체 PASS SHA와 같으며 촬영 뒤 변경은 기록 문서뿐이다.

| 항목 | iOS | Android |
|---|---|---|
| 기기 | iPhone 16 / iOS 18.6 | Medium_Phone / Android 16 API 36 |
| 논리 크기 | 393×852 | 411.4286×914.2857 |
| OS 안전 영역 상·하 | 59 / 34 | 24 / 24 |
| 상태 | 링크 상세, 사진 접힘·펼침·원본 이미지 시트 | 같은 4개 상태 |
| 조건 | 글자 배율 1.0, 스크롤 0, 입력 없음 | 동일 |
| 결과 | 전문 보기 제거, 사진 상태 유지, Safari 열기 | 전문 보기 제거, 사진 상태 유지, Chrome 열기 |

- `compare.py --manifest capture-manifest.json`의 4행 조건 검사가 양쪽 모두 통과했다. 플랫폼별 크기·OS/app 안전 영역·키보드 인셋·전체 스크롤·입력 출처를 비교했다.
- Figma 기준 노드는 없으므로(figma-pending-19) 승인된 배치와 변경 전·후 두 장을 비교했다. 원본 화면 보정은 하지 않았다. iOS 링크 최대 스크롤은 30→0으로 줄었고 비교 조건인 현재 스크롤은 0으로 같았다.
- 감독이 비교 이미지와 원본 화면을 열어 링크 줄 제거, 사진 펼침의 실제 이미지, 원본 이미지 시트, 외부 브라우저의 원본 URL 표시를 확인했다. 사용자 시각 판정은 별도로 남는다.
- 전후 JSON의 예상 밖 API 요청·Flutter 오류·비동기 오류는 모두 없었다. 프리뷰의 옛 `passed` 키는 PHASE가 정확히 `after`인 경우만 보는 필드여서 이번 `after-link` 판정에는 쓰지 않았다.
- 사진 펼침 직후 Android probe의 최대 스크롤은 이미지 레이아웃 전 값 0을 기록했지만, PNG에는 실제 이미지가 표시됐고 시트 단계에서는 1271.0682였다. 최대 범위는 비교 판정이 아닌 보고용 값이며 현재 offset은 두 단계 모두 0이다.
- 상단 링크 버튼에 앱 내부 포인터를 보내 실제 브라우저로 전환했다. iOS는 복귀 후 상세 유지와 원본 열기 metric 1회를 확인했다. Android는 Chrome 첫 실행 안내에서 계정 없이 진행하고 알림 안내를 거절한 뒤 원본 페이지를 확인했다. 운영 계정 로그인은 하지 않았다.
- Orca AX로 변경 후 링크 상세와 외부 브라우저 상태를 기록했다. Android 전면 Activity는 `com.android.chrome/...ChromeTabbedActivity`였다.
- Android 부팅 직후 System UI 응답 없음 창은 촬영 도구의 Wait 처리 뒤 해소됐고, 촬영 시 앱 전면 검사를 통과했다. Android 첫 영상은 종료 완료 전 복사해 `moov atom not found`로 배제했고, 15초 제한 녹화가 정상 종료된 뒤 다시 가져온 영상을 사용했다.
- iOS 영상 36.660초, Android 최종 영상 16.792644초의 유효 스트림과 브라우저 표시 프레임을 확인했다. 이 길이를 앱 성능 측정값으로 쓰지 않는다.
- 종료 후 기기·빌드 프로세스가 없는 것을 확인하고 잠금을 해제했다. 촬영 범위 4행×3분 + 전체 검사 약 6분의 18분 예산 안에서 마쳤다.

증거는 `.utmp/ticket-201/capture/`에 보존한다:

- `compare-ios.png`, `compare-android.png` 및 각각의 `-preview.png`.
- `screens/{ios,android}-{before,after}-{link,photo,photo-expanded,photo-sheet}.{png,json}`.
- iOS 외부 화면 `screens/ios-external-loaded.png`, 영상 `screens/ios-external.mp4`.
- Android 외부 화면 `screens/android-browser.png`, 영상 `screens/android-external-final.mp4`.
- AX·Activity·복귀 probe, 플랫폼별 빌드 로그와 빌드 해시는 같은 폴더에 보존했다.

## main 병합 뒤 최종 검증

최종 fetch에서 origin/main에 #245 `ea2825a`가 새로 있어 감독이 충돌 없는 merge-tree를 확인한 뒤 병합했다(병합 커밋 `3186804a69f0a1fa657b6c832bc9e90c2e85ab04`).
들어온 변경은 Android `ShareActivity`·iOS `ShareViewController`의 네이티브 공유 화면, 공유 UI 테스트, `share_send` 이미지, `frontend/tool/share_fixture_server.py`와 문서다. Flutter `lib/`·`test/`와 백엔드 변경은 없다.
fixture 서버의 `/__test/control` 새 키(`hold_save`·`release_save`)와 카테고리 응답의 `last_saved_at`은 추가 계약이다. Dart 소비자 `test/support/share_preview.dart`는 바뀌지 않았다.

병합 뒤 관련 검사(`.utmp/ticket-201/final-verify/partial-merge-related.log`): `flutter analyze --no-pub` 통과, `test/share`와 `original_link_screen_test.dart` 30개 통과, `share_fixture_server.py` 컴파일 확인.

이어서 clean인 병합 커밋에서 전체 검증을 한 번 실행했다(2026-11-06 15:45–15:51 KST).

```sh
~/.heoturu-agents/busy.sh --wait && ~/.heoturu-agents/busy.sh && python3 ~/.heoturu-agents/verify.py --log-dir .utmp/ticket-201/final-verify
```

실제 `verify-result.txt` 원문:

```text
pytest skip: 45 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=11 failed=0 logs=/Users/leehyeongyu/orca/workspaces/Clipback/link-original-open/.utmp/ticket-201/final-verify/20261106T154501-17375470e641
```

실제 백엔드 pytest 요약 및 앱 전체 테스트 최종 줄:

```text
2048 passed, 46 skipped, 3 warnings in 169.80s (0:02:49)
02:31 +3059: All tests passed!
```

- 콘솔: `.utmp/ticket-201/final-verify/full-verify-console.log`. `verify-progress.json` 진행 이벤트 24개는 모두 병합 커밋 SHA, dirty=false다.
- 46 skip은 통과가 아니다. Docker deployment 45건과 전용 S3 endpoint가 필요한 CLI 통합 1건은 미실행이다.
- 네이티브 공유 UI 테스트(XCUITest·Android instrumentation)는 전체 검증 범위 밖이며 이번 단계에서 실행하지 않았다.
- 위 화면·외부 전환 확인은 병합 전 `6f02a80` 기준이며 그대로 보존한다. 병합 뒤 최종 화면 촬영은 아직 하지 않았다(감독 후속).

## 남은 승인·범위

사용자 화면 판정과 PR 초안 승인 전이다. push·PR·GitHub 댓글/종료·배포는 하지 않았다.
원격 CI·실기기·운영 서버·실제 OAuth는 범위 밖이며 이번 결과로 대신하지 않는다.
회고 필요: 예 — 이전 아이콘 결정 중단, 작업자의 완료 보고 없는 대기 종료 2회, Android 영상 재촬영이 있었다.
