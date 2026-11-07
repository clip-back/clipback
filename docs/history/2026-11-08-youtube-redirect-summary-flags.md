# 리다이렉트로 YouTube가 된 링크의 자동 요약 제목·요약 반영 (#281)

2026-11-08, 시작 커밋 `907607e`(main) 기준으로 구현하고 티켓 리뷰와 전체 검증까지 마쳤다.
구현 커밋은 `baa91ce`이고 전체 검증의 기준 코드도 `baa91ce`다. #277이 남긴 "보존용 임시 분기"를 지우는 버그 수정이며 판단 근거는 ADR 0009다.

## 구현

- `backend/app/services/content_service.py`의 링크 저장(`save_link`)에서, 추출 뒤 URL이 YouTube로 바뀐 경우에만 사용자 입력 여부를
  보강된 제목·요약으로 다시 계산하던 임시 분기 4줄(주석 포함)을 지웠다. 이제 이 경우도 함수 앞에서 추출 전 원래 입력값으로 계산한 판정을 쓴다.
- 사용자 결정(A안): 요약 전 저장 값(추출 제목·설명)과 `content_created` 이벤트 metadata(추출 3키 + 카테고리 3키)는 그대로 두고,
  요약 작업의 `apply_title`·`apply_summary`만 바뀐다. 메타데이터 요청 1회, 저장 시 카테고리 추천 생략, 미분류, 정규화된 YouTube URL도 그대로다.
- `docs/adr/0009-content-save-entry-points.md`의 임시 분기 문장을 "#281에서 없앴다"로 맞췄다. 카테고리 추천 생략은 YouTube 공통 규칙이라 이 버그 설명에서 뺐다.
- API 요청·응답, 상태 코드, 오류 문구, DB 스키마 변경 없음. 마이그레이션·앱 변경 없음. 이미 저장된 콘텐츠·요약 작업은 소급해 바꾸지 않는다.

## 테스트

- HTTP 고정 테스트 `test_content_save_contract.py`(#278):
  - L11(`https://bit.ly/abc` → YouTube, 사용자 입력 없음): 요약 작업 `("youtube", False, False, True)` → `("youtube", True, True, True)`. 다른 단언은 그대로.
  - 새 행 L11b(같은 링크 + 사용자 제목 "내 제목"): `("youtube", False, True, True)`, 저장 제목 "내 제목", 요약 "추출 설명", metadata는 L11과 같다.
  - 기존 기대값 변경은 L11의 두 플래그뿐이다(사용자 결정). 파일 docstring은 그대로 두었다.
- 재현: 테스트만 바꾼 상태(수정 전 코드)에서 L11·L11b 2 failed. L11은 `apply_title`, L11b는 `apply_summary`에서 실패해 이슈의 "코드로 보면 거짓·거짓"을 확인했다.

## 리뷰

- 티켓 리뷰(`907607e..baa91ce`, Standards·Spec 두 축): 지적 0건. 요약 작업 플래그 소비자(`SummaryWorker.finish`)와 공유 저장 진입점까지 대조했고,
  새 행 이름 L11b와 ADR 문장 정리를 수용했다.

## 검증

- 부분 검사(이 워크트리, 임시 DB): 콘텐츠 저장 고정 테스트·요약 작업 생성·YouTube 요약·콘텐츠 API·콘텐츠 서비스·저장 기준선·공유 서비스 7개 파일 231 passed(skip 없음), `ruff check app tests` 통과.
- 전체 검증(`baa91ce`): `VERIFY result=PASS scope=all checks=11 failed=0`. pytest 2320 passed, 47 skipped. 앱 테스트 3368개 통과.
  - `pytest skip: 46 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)`
  - `pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)`
  - 고정 테스트 파일에는 skip이 없다. verify 중간에 이 문서 커밋에 들어간 `CHANGELOG.md`만 미커밋 상태였고 코드는 `baa91ce`와 같다.
  - verify의 backend 단계가 `ruff check app scripts alembic tests`와 전체 `pytest`를 포함한다.
- `backend/`에서 `deptry .`(0.25.1): `Success! No dependency issues found.`, 종료 코드 0.
- 미검증: PR의 Backend Validation(Docker deployment 작업 포함)은 push·PR 전이라 돌리지 않았다. 병합 뒤 운영 확인은 이 티켓의 완료 조건이 아니다.
  화면 변경이 없어 iOS Simulator·Android Emulator는 실행하지 않았다.
