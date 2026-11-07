# 콘텐츠 저장을 링크 저장·스크린샷 저장 진입점으로 교체 (#279)

2026-11-07, 시작 커밋 `cd283cf`(#278 고정 테스트 추가 뒤) 기준으로 구현하고 티켓 리뷰와 전체 검증까지 마쳤다.
구현 커밋은 `91362c6`이고 전체 검증의 기준 코드도 `91362c6`이다. 상위 이슈 #277의 두 번째 티켓이며 판단 근거는 ADR 0009다.
요청·응답·상태 코드·오류 문구, DB 스키마, 이벤트 metadata, 요약 작업 플래그는 바꾸지 않는 리팩터링이다.

## 구현

- `backend/app/services/content_service.py`
  - 생성 함수 `create_content`를 없애고 링크 저장 `save_link`, 스크린샷 저장 `save_screenshot`, 공통 내부 저장 `_save`,
    카테고리 결정 `_decide_categories`로 나눴다. 옛 인자 `user_provided_title`·`user_provided_summary`·`event_metadata_json`·`recommendation_shared_text`는 없어졌다.
  - 공유 정보 타입 `SharedLinkContext`(공유 텍스트, 공유 앱, 플랫폼, MIME, 첨부 수, 추출한 URL, URL 출처)를 이 module에 두었다.
  - 추출 서비스를 생성자 인자로 받고, 받지 않으면 기본값을 만든다. 업로드 조립부(`uploads.py`)는 바꾸지 않았다.
  - 링크 저장은 URL 필수 검사, 처음 URL의 YouTube 정규화, 그 밖의 링크 추출·보강, 보강 뒤 YouTube 정규화, 사용자 입력 판정, 공유 metadata와 공유 텍스트 추천을 맡는다.
    사용자 입력 판정은 추출 전 원래 입력값으로 하고, 리다이렉트로 YouTube가 된 링크만 "보존용 임시 분기"로 보강된 값을 쓴다(별도 버그 이슈에서 제거).
    YouTube 공유에는 공유 metadata와 공유 텍스트를 쓰지 않는다. JSON 스크린샷은 정규화·추출·추천·요약 작업을 건너뛰고 사용자 카테고리는 검증해 쓴다.
  - 스크린샷 저장은 업로드가 만들던 저장 요청, OCR metadata 직렬화, 추천 입력(OCR 글자)을 안에서 만든다.
  - 공통 내부 저장의 태그·콘텐츠·요약 작업·첨부·이벤트·영수증·커밋·롤백 본문은 옛 함수와 같다. 이벤트 metadata 1000자 자르기 두 함수는 이름·본문 그대로 두 시점에서 부른다(합치기는 #280).
- 호출부: 링크 라우트는 링크 저장만 부른다. 공유 저장 서비스는 URL 고르기·YouTube 정규화·`/share/` 해석·저장 요청 생성 뒤 공유 정보와 함께 링크 저장을 부른다.
  업로드 서비스는 생성 함수 호출만 스크린샷 저장 호출로 바꿨다. 이번 변경으로 미사용이 된 import와 공유 metadata 조립 함수를 정리했다.
- `app/core/exceptions.py`·`app/main.py`·`app/models/**`·`app/**/__init__.py`·`app/schemas/content.py`는 바꾸지 않았다.

## 트랜잭션 경계

시작 커밋과 대조했다. 새 DB 세션이나 중간 커밋은 없다. 영수증 add → flush → `commit_attempted` 표시 → commit 순서가 공통 내부 저장에 그대로 있다.
공유·업로드의 멱등 키 잠금과 replay 판단은 그대로 URL 해석·추출·AI·OCR·원본 저장보다 먼저다. 공유 추출은 링크 저장 안으로 옮겨졌지만 잠금 뒤에 일어난다.

## 테스트

- 고정 테스트: HTTP 고정 테스트 `test_content_save_contract.py`는 바꾸지 않았다. 서비스 기준선 `test_content_save_baseline.py`는 생성 함수 호출 줄 3개와 import 한 줄만 바꿨다.
- `tests/services/test_content_service.py`의 생성 테스트를 링크 저장·스크린샷 저장 기준으로 옮기고 이름 접두어를 바꿨다.
  링크 저장이 안에서 추출하므로 이벤트 metadata 전체를 비교하던 두 테스트에는 추출 3키가 붙었다. 옛 `event_metadata_json` 인자 테스트는 공유 정보를 넘기는 테스트로 바꿨다.
  카테고리 결정 표에 없던 AI 실패, 추천 서비스 없음, YouTube(AI·메타데이터 요청 없음) 세 행을 더했다.
- `tests/api/test_contents.py`·`tests/services/test_share_intake_service.py`·`tests/services/test_upload_service.py`의 가짜 콘텐츠 서비스를 새 진입점으로 바꿨다.
  가짜 서비스는 진입점이 하는 보강·조립을 같은 방식으로 해 기존 단언의 기대값을 그대로 둔다. 기록 속성 이름만 `metadata_json`·`shared_text`로 바꿨다.
- 그 밖의 `tests/integration/` 파일은 바꾸지 않았다.

## 티켓 기준 변경(사용자 결정)

구현 전 질문에 조율이 전달한 사용자 결정 원문은 "추천대로"다.

- 공유 저장 서비스의 YouTube 판별: 완료 조건은 "공유 저장 서비스에 `is_youtube_url` 호출이 남지 않는다"였지만, #277은 URL 고르기·`/share/` 해석 단계를 공유 저장 서비스에 그대로 두게 했다.
  이 단계의 판별을 없애면 YouTube 공유가 422 `Only Instagram URLs are supported`로 바뀐다. 그래서 URL 고르기 단계의 판별 1회는 남기고, 그 뒤 저장 준비용 판별·추출 호출만 없앴다.
  완료 조건은 "URL 고르기 단계 밖 판별 0회"로 확인했다.
- 옛 인자 이름 검사: `event_metadata_json`은 #280에서 합칠 `build_event_metadata_json`·`_build_event_metadata_json` 이름에 들어 있어 문자열 검색으로는 0회가 될 수 없다.
  네 이름을 낱말 단위 `git grep -nw`로 확인하고 두 함수 이름은 그대로 두었다.
- 서비스 기준선 import: 호출 줄만 바꿀 수 있는 파일이라 `SharedLinkContext` import 한 줄을 더하는 것을 예외로 허용받았다. 입력·기대값·단언은 그대로다.

## 리뷰

- 티켓 리뷰(`cd283cf..91362c6`, Standards·Spec 두 축): 지적 0건. 트랜잭션 경계, 구현자 설계 판단 8개, 고정 테스트 허용 줄을 코드와 대조해 확인했다.
  가짜 서비스가 보강 로직을 일부 복제하므로 그 테스트만으로 제품 동작을 보이지는 못하고, 실제 서비스를 지나는 고정 테스트와 서비스 테스트가 함께 덮는다고 적었다.

## 검증

- 부분 검사(이 워크트리, 임시 DB): 바꾼 테스트 6파일 177 passed(고정 테스트 81 포함, skip 없음). 저장 경로를 지나는 기존 테스트
  (`test_summary_job_creation`, `test_mobile_share`, `test_upload_and_isolation`, `test_content_url_length`, `test_content_category_validation`, `test_extraction_service`) 123 passed. ruff 통과.
- 시작 커밋 `cd283cf` export(`git archive`로 작업 폴더의 `.utmp/base-cd283cf`에 풂, 대체 검증): 고정 테스트 두 파일(바꾸기 전 판) 81 passed.
  로드한 코드가 풀어 둔 경로의 `app/services/content_service.py`이고 생성 함수가 있는 판임을 출력해 확인했다.
- 완료 조건 검색(`91362c6`): `.create_content(` 0회, 옛 인자 네 이름 낱말 단위 0회, `def create_content`는 라우트 함수뿐,
  링크 라우트·공유 저장 서비스의 `enrich_link`·`apply_to_payload` 0회, 공유 저장 서비스의 `is_youtube_url`은 URL 고르기 단계 1회, `/share/` 해석의 메타데이터 요청 남음, 보존용 임시 분기 주석 있음.
- 전체 검증(`91362c6`, 작업 트리 깨끗): `VERIFY result=PASS scope=all checks=11 failed=0`. pytest 2319 passed, 47 skipped. 앱 테스트 3225개 통과.
  - `pytest skip: 46 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)`
  - `pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)`
  - 두 고정 테스트 파일에는 skip이 없다.
- `backend/`에서 `deptry .`(0.25.1): `Success! No dependency issues found.`, 종료 코드 0.
- 미검증: PR의 Backend Validation(Docker deployment 작업 포함)은 push·PR 전이라 돌리지 않았다. 병합 뒤 운영 확인(#277의 사람 확인)은 이 티켓 범위가 아니다.
  화면 변경이 없어 iOS Simulator·Android Emulator는 실행하지 않았다.
