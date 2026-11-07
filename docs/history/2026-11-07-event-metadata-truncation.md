# 이벤트 metadata 1000자 자르기를 함수 하나로 합침 (#280)

2026-11-07, 시작 커밋 `69e6fc6`(#279 이력 문서 뒤) 기준으로 구현하고 티켓 리뷰와 전체 검증까지 마쳤다.
구현 커밋은 `97ba841`이고 전체 검증의 기준 코드도 `97ba841`이다. 상위 이슈 #277의 세 번째(마지막) 티켓이며 판단 근거는 ADR 0009다.
`content_created` 이벤트의 `metadata_json` 결과를 바꾸지 않는 리팩터링이다.

## 구현

- `backend/app/services/extraction_service.py`에 module 함수 `serialize_event_metadata`를 두었다.
  옛 두 반복문과 같은 규칙이다: `ensure_ascii=False`, 구분자 `(",", ":")`, 최대 길이 1000, 비어 있지 않은 문자열 값 중 가장 긴 것을 넘친 만큼 자르고,
  길이가 같으면 먼저 들어간 키를 자르며, 자를 문자열이 없으면 멈춘다. 넘겨받은 dict는 복사해서 쓴다.
- 최대 길이 상수 `MAX_EVENT_METADATA_LENGTH`는 이 module 하나에만 남겼다. 콘텐츠 저장 서비스가 이미 추출 서비스를 import하므로 이쪽에 두어 순환 import를 피했다.
- 두 시점 호출은 그대로다. 추출 서비스 `build_event_metadata_json`이 공유 metadata와 추출 3키를 자르고(첫 시점),
  콘텐츠 저장 서비스 `_build_event_metadata_json`이 그 결과에 카테고리 3키를 더해 다시 자른다(둘째 시점). 두 메서드의 이름·시그니처와 base JSON 파싱은 바꾸지 않았다.
- 새 package나 `app/core/`·`app/schemas/content.py` 변경은 없다.

## 테스트

- 테스트 파일은 바꾸지 않았다. HTTP 고정 테스트 `test_content_save_contract.py`, 서비스 기준선 `test_content_save_baseline.py`, 추출 서비스 단위 테스트 모두 그대로다.

## 티켓 기준 변경(사용자 결정)

- 이슈의 변형 조건은 "한 시점에서만 부르면 T1–T3 중 하나 이상 실패"였다. #278에서 첫 시점 자르기를 빼는 변형은 T1–T3이 통과하고 T4만 실패했다.
  조건을 "T1–T4 중 하나 이상 실패"로 맞추는 안을 조율이 물었고 사용자 결정 원문은 "응"이다. T4는 #278에서 고정한 그대로이며 고정 테스트 수정 허용이 아니다. 이슈 본문은 바꾸지 않았다.

## 리뷰

- 티켓 리뷰(`69e6fc6..97ba841`, Standards·Spec 두 축): 지적 0건. 두 시점 호출, 자르기 규칙, dict 복사의 영향 없음, 손상 base JSON 처리 보존을 코드와 대조해 확인했다.

## 검증

- 부분 검사(이 워크트리, 임시 DB): 고정 테스트 두 파일과 추출·콘텐츠 저장·공유 서비스 테스트 164 passed(고정 테스트 81 포함, skip 없음). 바꾼 두 파일 ruff 통과.
- 완료 조건 검색(`97ba841`): `backend/app`의 `while len(serialized)` 1곳(`extraction_service.py`), `MAX_EVENT_METADATA_LENGTH` 정의 1곳, 시작 커밋 대비 `backend/tests` diff 없음.
- 직접 대조: 시작 커밋의 두 옛 함수와 새 함수를 이상 입력(한글·`"`·`\`, 같은 길이 값, 숫자·None·bool·배열·중첩 객체, 빈 문자열, dict가 아닌 base JSON, 추천 결과 모든 조합)으로 돌려
  추출 서비스 54건, 콘텐츠 저장 서비스 13608건 모두 같은 문자열을 얻었다. 손상 JSON(`{`, `not json`)은 둘 다 JSONDecodeError다.
- 변형 실험(앱 파일을 복사해 두고 변형 → 고정 테스트 두 파일 → 복사본으로 복구, 복구 뒤 `git diff`가 변형 전과 같음):

  | 변형 | 결과 | 실패 |
  | --- | --- | --- |
  | 첫 시점에서 자르지 않음(둘째 시점만 호출) | 1 failed, 80 passed | T4 |
  | 둘째 시점에서 자르지 않음(첫 시점만 호출) | 4 failed, 77 passed | T1, T2, T3, T4 |
  | 길이가 같으면 나중 키를 자름 | 3 failed, 78 passed | T2, T3, T4 |

- 전체 검증(`97ba841`, 작업 트리 깨끗): `VERIFY result=PASS scope=all checks=11 failed=0`. pytest 2319 passed, 47 skipped. 앱 테스트 3225개 통과.
  - `pytest skip: 46 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)`
  - `pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)`
  - 두 고정 테스트 파일에는 skip이 없다.
- `backend/`에서 `deptry .`(0.25.1): `Success! No dependency issues found.`, 종료 코드 0.
- 미검증: PR의 Backend Validation(Docker deployment 작업 포함)은 push·PR 전이라 돌리지 않았다. 병합 뒤 운영 확인(#277의 사람 확인)은 이 티켓 범위가 아니다.
  화면 변경이 없어 iOS Simulator·Android Emulator는 실행하지 않았다.
