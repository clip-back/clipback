# 미분류 표시 이름 예약 (#191)

2026-11-07, 시작 커밋 `5abc52a` 기준으로 구현하고 티켓 리뷰(지적 0건)와 전체 검증까지 마쳤다.
코드 커밋은 `1d01c22`이고, 전체 검증의 기준 코드도 `1d01c22`이다.
사용자 결정 “191 1번으로 하자”에 따라 예약 이름 막기만 했다. 앱이 미분류를 `is_default`로 판별하도록 바꾸지 않았다.

## 구현

- 서버: `backend/app/services/category_service.py`의 `_check_name`이 이름 `분류가 필요한 콘텐츠`를 이름 중복과 같이 거절한다.
  카테고리 생성·이름 변경의 4경로(`Idempotency-Key` 있음·없음)가 모두 이 검사를 거친다.
  - `Idempotency-Key` 없음: 기존 중복과 같은 409 `{"detail": "Category already exists"}`.
  - `Idempotency-Key` 있음: 기존 중복과 같은 409 `category_name_exists`, 거절 영수증 기록.
- 이름은 정확히 같을 때만 막는다. 앞뒤 공백은 입력 스키마가 먼저 지운다. 이름 없이 색만 바꾸는 수정은 이름 검사를 거치지 않는다.
- 앱: 제품 코드를 바꾸지 않았다. 앱은 기존대로 `category_name_exists`를 받으면 “같은 이름의 카테고리가 있어요. 다른 이름을 입력해 주세요.”를 보여 준다.
  새 위젯 테스트는 이 기존 경로를 고정하는 용도라 수정 전 코드에서도 통과한다.

## 배포와 호환

- 응답 형식과 오류 코드는 바뀌지 않았다. 로컬 태그 `app-android-v0.4.0-b5`, `app-ios-v0.4.1-b10`의 코드에도
  `category_name_exists` → 같은 이름 오류 문구 연결과 카테고리 쓰기의 `Idempotency-Key` 전송이 있다.
  그래서 배포된 0.4.x 앱도 같은 문구를 보인다. 태그 코드로 확인한 근거이며 설치된 배포 앱을 실행해 확인하지는 않았다.
- 서버는 `main` 자동 배포를 따르므로 `main`에 병합되면 이 거절이 운영 서버에 바로 적용된다. DB 마이그레이션은 없다.
- 운영 DB에 이미 `분류가 필요한 콘텐츠` 이름의 일반 카테고리가 있는지는 확인하지 않았다(운영 DB 미연결).
  사람이 읽기 전용으로 조회해 병합 전에 확인해야 하며, 있으면 처리 방법을 따로 정한다.

## 검증

- 재현 테스트 `test_reserved_uncategorized_display_name_is_rejected_like_duplicate`(`backend/tests/integration/test_category_submissions.py`):
  수정 전 코드에서 생성 요청이 201로 성공해 실패했고, 수정 뒤 통과했다.
- 위젯 테스트(`frontend/test/category_reentry_test.dart`): 아카이브·카테고리 관리 × 생성·수정 4개. 서버 거절 응답에 같은 문구가 보이고 시트와 입력이 남는지 확인한다.
- 전체 검증(`1d01c22`): `VERIFY result=PASS scope=all checks=11 failed=0`. 앱 테스트 3198개 통과, pytest 2208 passed, 47 skipped.
  - `pytest skip: 46 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)`
  - `pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)`
- 미검증: 운영 DB 기존 카테고리 조회(사람이 병합 전 수행), iOS Simulator·Android Emulator 실행(화면 모양 변경 없음), 설치된 0.4.x 배포 앱 실행.

## 묶음 최종 검증 (#202·#191)

- #202·#191 묶음의 최종 리뷰 지적 두 건을 반영한 뒤(`f93835b`) 전체 검증을 다시 돌렸다. 이 묶음의 최종 전체 결과는 이 절에만 적는다.
  - 업데이트 내역: `main` 병합으로 두 줄이 과거 서버 배포 절에 들어가고 앱 항목이 겹친 것을 `main` 기준으로 되돌리고 두 줄만 `미배포 / 수정`에 두었다.
  - 기기 확인용 프리뷰(저장소 밖 작업 파일)의 경로를 고쳤다. 제품 코드는 바꾸지 않았다.
- 전체 검증(`f93835b`): `VERIFY result=PASS scope=all checks=11 failed=0`. 앱 테스트 3198개 통과, pytest 2208 passed, 47 skipped.
  - `pytest skip: 46 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)`
  - `pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)`
- 미검증은 위 검증 절과 같다. #202의 기기 확인은 [아이콘 버튼 스크린 리더 이름](2026-11-07-icon-button-semantics.md)에 적은 대로 아직 하지 않았다.
