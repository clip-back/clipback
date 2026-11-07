# 콘텐츠 저장 진입점 정리 최종 리뷰·검증 (#277)

2026-11-07, 상위 이슈 #277의 세 티켓을 마친 뒤 브랜치 전체를 최종 리뷰하고, main 병합 뒤(`66f6dab`) 다시 리뷰·전체 검증했다.
티켓별 구현·검증 수치는 각 이력에 있다:
[#278 고정 테스트](2026-11-07-content-save-contract-tests.md),
[#279 진입점 교체](2026-11-07-content-save-entry-points.md),
[#280 metadata 자르기 합치기](2026-11-07-event-metadata-truncation.md).

## main 대조

- 처음 최종 리뷰 때는 `origin/main`이 `901a3b1`(merge-base와 같음)이라 병합하지 않았다.
- PR 초안 직전 `git fetch origin`에서 `origin/main`이 `85c30e0`(#284, 카테고리 요청의 결과 판정을 `ApiRequestScope`로 통합)으로 전진해 merge commit `66f6dab`으로 합쳤다(rebase 없음).
  - 양쪽이 바꾼 문서: `GLOSSARY.md`는 main이 추가한 `늦은 응답` 항목을 원문 그대로 두고 이 브랜치의 저장 시 카테고리 추천 항목을 함께 둔다.
    `docs/history/README.md` 목차는 양쪽 행을 모두 남겼다.
  - 이 브랜치는 `frontend/`를 바꾸지 않아 병합 결과의 `frontend/`는 `85c30e0`과 같다(`git diff --stat 85c30e0 66f6dab -- frontend` 빈 출력).

## 최종 리뷰

- 높음·중간 지적 없음. 낮음 1건을 반영했다.
- `GLOSSARY.md`의 저장 시 카테고리 추천 설명이 "유튜브 영상 링크와 글자가 없는 스크린샷은 대상이 아니며, 이때는 자동 요약이 나중에 카테고리를 채울 수 있습니다"라서
  글자 없는 스크린샷도 후속 자동 요약 대상처럼 읽혔다. 스크린샷 저장(업로드·JSON)은 요약 작업을 만들지 않고 고정 테스트도 그렇게 고정한다.
  마지막 절을 "유튜브 영상 링크는 자동 요약이 나중에 카테고리를 채울 수 있습니다"로 바꿨다(커밋 `967ddb6`). 제품 코드·테스트는 바꾸지 않았다.
  같은 문장은 `GLOSSARY.md`·`docs/`·README에 이 한 곳뿐이었다.
- 병합 뒤 재리뷰(`66f6dab`, Standards·Spec): 지적 0건. GLOSSARY의 두 항목과 목차 행이 모두 한 번씩 보존됐음을 확인했다.

## 검증

- 병합 전 최종 검증(`967ddb6`)도 PASS였지만 main 병합 전 결과다. 아래가 병합 뒤 최종 결과다.
- main 변경(카테고리 요청 판정 계약) 관련 사전 검사(`66f6dab`):
  - `frontend/lib`의 `ApiRequestScope`·`settle(` 사용처 검색, 병합 결과 `frontend/` 차이 없음.
  - `frontend/`에서 `flutter analyze --no-pub`: `No issues found!`.
  - `flutter test --no-pub test/app/content_actions_category_request_test.dart test/data/api_request_scope_test.dart`: 143개 통과.
- 전체 검증(`66f6dab`, 작업 트리 깨끗): `VERIFY result=PASS scope=all checks=11 failed=0`. pytest 2319 passed, 47 skipped. 앱 테스트 3368개 통과.
  - `pytest skip: 46 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)`
  - `pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)`
- `backend/`에서 `deptry .`(0.25.1): `Success! No dependency issues found.`, 종료 코드 0.
- 미검증:
  - PR의 Backend Validation(Docker deployment 작업 포함)은 push·PR 전이라 돌리지 않았다.
  - 병합 뒤 사람 확인(#277 Further Notes): Railway 배포 커밋·상태와 `/api/v1/health/ready`, 실제 앱의 일반 웹 링크·YouTube 링크·인스타그램 공유·스크린샷 저장 4건,
    운영 SQL 콘솔의 `metadata_keys` 대조는 하지 않았다.
  - 화면 변경이 없어 iOS Simulator·Android Emulator는 실행하지 않았다.
