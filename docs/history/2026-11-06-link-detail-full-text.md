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

## 화면 확인과 남은 일

**화면 확인 미완료.** iOS Simulator·Android Emulator에서 링크 콘텐츠 상세의 변경 전(`e4baaa2`)·후 화면,
날짜 줄 링크 버튼으로 외부 앱·브라우저가 실제로 열리는지, 스크린샷 콘텐츠 상세가 그대로인지는 아직 확인하지 않았다.
Figma 기준 노드가 없으므로(figma-pending-19) 변경 전·후 2장 비교로 한다.
이 자동 검증을 기기·CI·실기기·운영 검증으로 보고하지 않는다. 기기 실행·촬영·push·PR·GitHub 댓글/종료·배포는 하지 않았다.
