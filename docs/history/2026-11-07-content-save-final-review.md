# 콘텐츠 저장 진입점 정리 최종 리뷰·검증 (#277)

2026-11-07, 상위 이슈 #277의 세 티켓을 마친 뒤 브랜치 전체(`901a3b1..967ddb6`)를 최종 리뷰하고 전체 검증했다.
티켓별 구현·검증 수치는 각 이력에 있다:
[#278 고정 테스트](2026-11-07-content-save-contract-tests.md),
[#279 진입점 교체](2026-11-07-content-save-entry-points.md),
[#280 metadata 자르기 합치기](2026-11-07-event-metadata-truncation.md).

## main 대조

- `git fetch origin` 뒤 `origin/main`은 `901a3b1`이고 `HEAD..origin/main`은 비어 있다. merge-base도 `901a3b1`이라 main 병합이 필요 없었다.

## 최종 리뷰

- 높음·중간 지적 없음. 낮음 1건을 반영했다.
- `GLOSSARY.md`의 저장 시 카테고리 추천 설명이 "유튜브 영상 링크와 글자가 없는 스크린샷은 대상이 아니며, 이때는 자동 요약이 나중에 카테고리를 채울 수 있습니다"라서
  글자 없는 스크린샷도 후속 자동 요약 대상처럼 읽혔다. 스크린샷 저장(업로드·JSON)은 요약 작업을 만들지 않고 고정 테스트도 그렇게 고정한다.
  마지막 절을 "유튜브 영상 링크는 자동 요약이 나중에 카테고리를 채울 수 있습니다"로 바꿨다(커밋 `967ddb6`). 제품 코드·테스트는 바꾸지 않았다.
  같은 문장은 `GLOSSARY.md`·`docs/`·README에 이 한 곳뿐이었다.

## 검증

- 전체 검증(`967ddb6`, 작업 트리 깨끗): `VERIFY result=PASS scope=all checks=11 failed=0`. pytest 2319 passed, 47 skipped. 앱 테스트 3225개 통과.
  - `pytest skip: 46 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)`
  - `pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)`
- `backend/`에서 `deptry .`(0.25.1): `Success! No dependency issues found.`, 종료 코드 0.
- 미검증:
  - PR의 Backend Validation(Docker deployment 작업 포함)은 push·PR 전이라 돌리지 않았다.
  - 병합 뒤 사람 확인(#277 Further Notes): Railway 배포 커밋·상태와 `/api/v1/health/ready`, 실제 앱의 일반 웹 링크·YouTube 링크·인스타그램 공유·스크린샷 저장 4건,
    운영 SQL 콘솔의 `metadata_keys` 대조는 하지 않았다.
  - 화면 변경이 없어 iOS Simulator·Android Emulator는 실행하지 않았다.
