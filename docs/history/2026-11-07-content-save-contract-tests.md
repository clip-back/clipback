# 콘텐츠 저장 동작 고정 테스트 추가 (#278)

2026-11-07, 시작 커밋 `e060ebb`(main `901a3b1` + ADR 0009·용어 문서) 기준으로 구현하고 티켓 리뷰 반영과 전체 검증까지 마쳤다.
테스트 커밋은 `25a4f95`(고정 테스트 두 파일)와 `e5b20ea`(리뷰 반영)이고, 전체 검증의 기준 코드는 `e5b20ea`이다.
상위 이슈 #277(콘텐츠 저장 진입점 정리)의 첫 티켓으로, 앱 코드(`backend/app/`)와 기존 테스트는 바꾸지 않았다.

## 구현

- `backend/tests/integration/test_content_save_contract.py`: HTTP 고정 테스트 78행. 링크 `POST /contents`, 공유 `POST /contents/share`,
  스크린샷 `POST /uploads/screenshots`를 기존 통합 `api` fixture(실제 PostgreSQL, 가짜 메타데이터·AI·OCR, 외부 HTTP 차단)로 부른다.
  - #277 표의 76행(L01–L19, S01–S08, U01–U04, J1–J5, M1–M7, SH1–SH9, LEN1–LEN5, T1–T3, U-1·U-2, TY1–TY11, TS1–TS3)을 parametrize id로 둔다.
  - 변형 실험에서 실패하지 않은 변형을 잡으려고 두 행을 더했다. T4는 공유 `/p/` + `h`×400 URL과 사용자 카테고리로,
    첫 단계 자르기에서 `extracted_url`만 일부 잘리고 둘째 단계에서 `resolved_url`이 잘린다.
    M8은 `[사용자, 미분류, 접근 불가]`로, 존재 검사가 혼합 검사보다 먼저라 404다.
  - 성공 행은 응답 JSON 전체(`id`·`saved_at`·태그·첨부 id는 형식을 단언한 뒤 자리표시자, 카테고리는 id가 게스트의 실제 id인지 단언한 뒤 id만 자리표시자),
    DB 행 수 변화, `content_created` 이벤트의 `metadata_json` 전체 문자열, 요약 작업 종류와 적용 3개, 영수증 종류,
    메타데이터 요청 URL 목록, AI 호출 입력을 비교한다. 오류 행은 상태 코드, `detail` 전체(목록형은 `type`·`loc`),
    DB 행 수 변화 없음(콘텐츠·이벤트·요약 작업·영수증), 메타데이터 요청 URL 목록, AI 호출 목록을 비교한다.
  - 추천 카테고리 id는 DB 시퀀스에 따라 달라져 기대 `metadata_json`에 실제 id를 넣는다. T1·T2는 id 자릿수만큼 가장 긴 값이 더 잘린다.
- `backend/tests/services/test_content_save_baseline.py`: API로 닿지 않는 두 경우의 서비스 기준선 3건.
  추천 서비스 없음(링크, 공유 텍스트가 있는 공유 링크)은 카테고리와 이벤트 `metadata_json` 전체를, 정규화 뒤 URL 길이 재검사는
  422 `detail` 전체와 저장·이벤트·태그·커밋·메타데이터 요청·추천 호출이 없는 것을 고정한다.
- 이후 티켓은 HTTP 고정 테스트의 import 경로 한 줄, 서비스 기준선의 생성 함수 호출 줄만 바꿀 수 있다(#277).

## 티켓 기준 변경(사용자 결정)

- 조율이 전달한 사용자 결정 원문은 "응"(Q1·Q2 모두 추천안)이다.
- Q1: 서비스 기준선의 추천 서비스 없음은 지금 호출에 실제 호출부와 같은 이벤트 metadata(링크: 추출 3키, 공유: 공유 6키 + 추출 3키)와
  공유 텍스트를 넘기고, 그 키들 + 카테고리 3키(`error`) 전체 문자열을 고정한다. 메타데이터 요청은 테스트에서 가짜로 바꾼다.
  다음 티켓이 호출 줄만 새 진입점으로 바꾸면 그 안에서 추출 키가 붙으므로, 기획이 측정한 3키 문자열로는 기대값을 지킬 수 없어서다.
  "공유 텍스트가 있는 저장"은 공유 링크 경로로 정했다. 기획 측정과 같은 입력(`event_metadata_json` 없이 부름)도 다시 실행해 링크·공유 모두
  `{"category_assignment_method":"uncategorized","recommended_category_id":null,"category_recommendation_failure_reason":"error"}`를 확인했다.
- Q2: 기준 커밋 임시 워크트리 대신 `git archive 901a3b1 backend`를 작업 폴더의 `.utmp/base-901a3b1`에 풀고 두 파일을 복사해 별도 임시 DB로 돌렸다(임시 워크트리 대체 검증).
  `901a3b1..e060ebb` 차이는 `GLOSSARY.md`와 ADR 0009 문서 2개다.

## 리뷰

- 티켓 리뷰(`e060ebb..25a4f95`): Standards S1·Spec P1(같은 원인) 중간 1건. 저장 응답의 카테고리를 이름으로만 바꿔 `color`·`is_default`를 비교에서 버렸다.
- 반영(`e5b20ea`): 카테고리 객체 전체를 비교하고 id만 자리표시자로 바꾼다. `color`·`is_default`는 main `901a3b1` export에서 관측한 값
  (`취업` `#4F46E5`·`true`, `미분류` `#6B7280`·`true`)으로 고정했다. 이 정규화는 성공 39행 전부(링크 18, JSON 스크린샷 4, 공유 13, 업로드 4)가 함께 쓴다.

## 검증

- 기획 측정 대조: 76행의 상태·요청 URL·AI 입력·응답·`metadata_json`·요약 작업·영수증·행 수 변화가 main `901a3b1` 측정 결과와 같았다.
- 부분 검사(이 워크트리, 임시 DB): 두 파일 81 passed(HTTP 78 + 서비스 3), skip 없음. ruff 통과.
- main `901a3b1` export(대체 검증): 리뷰 반영 뒤 두 파일 81 passed. 로드한 코드가
  `.utmp/base-901a3b1/backend/app/services/content_service.py`와 `app/schemas/category.py`(풀어 둔 경로)임을 같은 프로세스에서 출력해 확인했다.
- 변형 실험: 앱 파일을 복사해 두고 잠시 바꾼 뒤 두 파일을 돌리고, 복사본으로 되돌린 뒤 `git diff --quiet -- app`을 매번 확인했다. 13개 모두 실패했다.

  | 변형 | 실패 |
  | --- | --- |
  | 공유 metadata 키 하나 빼기(`mime_type`) | 12 |
  | `apply_title` 반대로 넣기 | 18 |
  | YouTube 공유에 공유 키 넣기 | 1(S03) |
  | 자르기 제거(두 곳) | 4(T1–T4) |
  | 두 단계 자르기를 한 단계로 합치기(추출 단계 자르기 제거) | 1(T4) |
  | 길이가 같을 때 나중 키 고르기(두 곳) | 3(T2·T3·T4) |
  | JSON 스크린샷을 사용자 카테고리 없이 미분류로 저장 | 3(J1·J2·J3) |
  | 카테고리 존재 검사와 혼합 검사 순서 바꾸기 | 1(M8) |
  | 카테고리 검증을 추출 앞으로 옮기기(링크 라우트) | 7 |
  | 응답 카테고리 `color` 필드 삭제 / 값 변경(None) | 각 39(성공 행 전부) |
  | 응답 카테고리 `is_default` 필드 삭제 / 값 뒤집기 | 각 39(성공 행 전부) |

  처음 76행으로 돌렸을 때 "두 단계를 한 단계로"와 "존재·혼합 검사 순서"는 실패하지 않았다(종료 코드 0). T1–T3은 첫 단계에서 값이 비거나 긴 값이 하나뿐이었고,
  M1·M2는 접근 가능한 카테고리가 미분류 하나라 혼합 검사가 먼저 와도 걸리지 않았다. 그래서 T4·M8을 더했고, 두 행도 main export에서 통과한다.
- 전체 검증(`e5b20ea`과 같은 작업 트리): `VERIFY result=PASS scope=all checks=11 failed=0`. pytest 2316 passed, 47 skipped. 앱 테스트 3225개 통과.
  - `pytest skip: 46 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)`
  - `pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)`
  - 두 고정 테스트 파일에는 skip이 없다.
- `backend/`에서 `deptry .`(0.25.1): `Success! No dependency issues found.`, 종료 코드 0.
- 미검증: PR의 Backend Validation(Docker deployment 작업 포함)은 push·PR 전이라 돌리지 않았다. 병합 뒤 운영 확인(#277의 사람 확인)은 이 티켓 범위가 아니다.
  화면 변경이 없어 iOS Simulator·Android Emulator는 실행하지 않았다.
