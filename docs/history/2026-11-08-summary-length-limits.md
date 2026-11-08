# 자동 요약 제목·요약 길이 상한을 한 곳으로 모으기 (#158)

2026-11-08, 시작 커밋 `99bdeef` 기준으로 구현하고 티켓 리뷰, 전체 검증까지 마쳤다. 코드 커밋은 `0d55ae2`이다. 서버만 바꿨고 동작은 바뀌지 않는다.
#158의 후보 4개 중 1번만 처리했다. 2–4번은 남아 있어 이슈는 열어 둔다.

## 사용자 결정

- 2026-11-02 분류 댓글: 이번에는 1번(길이 상한)만 한다. 2번(종류 목록)은 ADR 0003의 재검토 조건(세 번째 종류 추가) 때, 3번(`finish()` 인자)·4번(테스트 결합)은 보류한다.
- 2026-11-08 "1번 길이 상한만 (Recommended)": 제목 120자·요약 500자 상한이 세 곳에 따로 있는 것을 한 곳으로 모은다. 동작 변경 없음.

## 구현

- `backend/app/integrations/summary.py`: `MAX_TITLE_LENGTH = 120`, `MAX_SUMMARY_LENGTH = 500`을 두고 `validated_result()`가 두 값으로 판정한다.
- `backend/app/integrations/instagram_summary_client.py`·`youtube_summary_client.py`: 프롬프트의 "제목은 …자 이내." 문장과 YouTube 응답 스키마의 `title.maxLength`가 `MAX_TITLE_LENGTH`를 쓴다.
  - 인스타그램 `PROMPT`는 모듈 import 때 문자열이 정해진다.
  - YouTube 프롬프트는 `summarize()` 호출 때 조립되지만, `from app.integrations.summary import MAX_TITLE_LENGTH`로 가져온 이름은 import 때 값이 묶인다.
    그래서 import 뒤 `summary.MAX_TITLE_LENGTH`만 바꿔서는 두 client 모두 따라 바뀌지 않는다. 실행 중 값을 바꾸는 것은 요구 사항이 아니다.
- [자동 요약 안내](../youtube-summary.md)의 분석 조건에 상한의 위치와 쓰는 곳 2줄을 더했다.
- 기존 두 프롬프트에는 500자 문구가 없었다(#203 이후). 이슈 본문의 "요약 500자 이내" 문장은 옛 프롬프트 기준이다.
  문구를 새로 넣으면 프롬프트가 바뀌므로 넣지 않았고, 요약 500자는 원래 `validated_result()` 한 곳에 있던 값에 이름만 붙였다.
- 범위 밖으로 둔 다른 120·500 상한: OCR(`ocr_client.py`), 콘텐츠 저장 모델·스키마(`models/content.py`, `schemas/content.py`), 카테고리 추천 입력(`category_recommendation_service.py`). 인스타그램 요청 스키마 `title`에 `maxLength`가 없는 것도 기존 그대로다.
- CHANGELOG `미배포`는 갱신하지 않았다. 동작 변화 없는 정리여서다.

## 테스트

- 추가: `tests/integrations/test_summary_length_limits.py`. 새 Python 프로세스에서 `summary.MAX_TITLE_LENGTH = 7`, `MAX_SUMMARY_LENGTH = 5`로 바꾼 뒤 client를 import해,
  두 프롬프트("제목은 7자 이내.", "120" 없음), YouTube 스키마 `title`(`{"type": "string", "maxLength": 7}` 전체 비교), `validated_result()`의 제목 7/8자·합친 요약 5/6자 경계가 함께 바뀌는지 본다.
  이름 바인딩이 import 때 정해지므로 같은 프로세스의 monkeypatch 대신 새 프로세스를 썼다.
- 기존 테스트의 기대값·이름·docstring은 바꾸지 않았다.
- 구현 전 실패: 새 테스트만 추가한 상태에서 1개 실패(인스타그램 프롬프트에 "제목은 120자 이내."). 상수 연결이 없어서 생긴 의도한 실패이며 제품 결함이 아니다.
- 변형 확인(작업자 실행): 한 곳씩 되돌린 변형 6개(인스타그램 프롬프트 120, YouTube 프롬프트 120, YouTube 스키마 120, 스키마 `maxLength` 삭제, 제목 판정 120, 요약 판정 500)를 새 테스트가 모두 실패로 잡았다. 파일은 복사본으로 되돌리고 같음을 확인했다.

## 동작 보존 확인

- 작업자: `99bdeef`의 `backend/app`을 `git archive`로 풀어 같은 비교 스크립트를 기준·변경 후에 각각 실행했다.
  두 프롬프트 전문과 SHA-256(인스타그램 `1667a986…eb41`, YouTube `beebca57…25fd`), YouTube 요청 스키마 전체, 인스타그램 `SummaryOutput` 스키마, `validated_result()` 16개 입력의 결과가 모두 같았다.
  첫 실행 두 번은 스크립트 실행 환경 문제(`uv` 없음, 작업 폴더의 `.env`를 읽어 설정 검증 실패)로 실패해 실행 위치와 환경 변수를 고쳤다. 제품 결함이 아니다.
- 검수자(직접 실행): 기준·HEAD의 `summary.py`를 메모리에 올려 12,096개 입력 조합의 결과(성공 dataclass 전체, 실패는 예외 타입·문구·code)가 같음을 확인했다. None·숫자·배열·객체·빈 문자열, 제목 120/121자, 합친 요약 500/501자, 잘못된 후보 목록을 포함한다.
  두 프롬프트 식의 바이트도 같았다. 첫 비교는 검수자 스크립트의 `json` 바인딩 누락으로 실패했고 스크립트만 고쳐 다시 실행했다. 제품 결함이 아니다.
- 검수자는 관련 테스트 3개 파일도 직접 실행했다: 153 passed, skip 없음.

## 리뷰

- 티켓 리뷰(`99bdeef..0d55ae2`): Standards 0건, Spec 0건.
  "두 프롬프트 모두 import 때 확정"이라는 작업자 설명을 위 구현 절의 구분(인스타그램은 문자열, YouTube는 이름 바인딩)으로 바로잡았다. 새 프로세스로 검사하는 방식과 단일 출처 확인에는 영향이 없다.

## 검증

2026-11-08, 기준 코드 `0d55ae2`(로컬, 대역 데이터). 이 문서만 더한 커밋은 코드가 `0d55ae2`와 같다.

- 전체 검증 `python3 ~/.heoturu-agents/verify.py`: `VERIFY result=PASS scope=all checks=11 failed=0`.
  백엔드 `pytest: 2325 passed, 47 skipped, 3 warnings in 218.47s (0:03:38)`. `ruff check app scripts alembic tests`는 verify의 `backend:ruff` 단계와 같다.
  - pytest skip: 46 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
  - pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
- 구현 중 부분 실행에서 DB가 없어 건너뛴 요약 테스트 98개는 이번 전체 실행에서 모두 돌았다(위 skip에 요약 테스트 없음).
- verify에 없는 `deptry .`(backend)를 따로 실행해 통과했다.
- Docker가 필요한 deployment·운영자 복구 테스트(위 skip 46개)는 로컬에서 돌지 않았다. 이번 변경은 이 범위를 바꾸지 않았고, 원격 CI는 PR 생성 뒤 확인한다.

## 묶음 최종 검증 (#157·#158)

2026-11-08, main의 #298(`ef9f6a8`)을 충돌 없이 합친 `3e679f2`에서 최종 검수자가 직접 실행했다. 이번 절을 추가한 커밋은 문서만 바꾸며 검증 대상 코드와 같다. [#157 이력](2026-11-08-instagram-httpx-timeout.md)의 티켓 검사와 위 #158 티켓 검사는 병합 전 증거다.

- main merge-base `ef9f6a8`부터 `3e679f2`까지 최종 검수: Standards 0건, Spec 0건. main 대비 콘텐츠 저장 endpoint·저장 테스트·프론트엔드 변경 없음.
- main에서 바뀐 저장 callback 소비처를 대조하고 전체 검사 전에 `flutter analyze --no-pub`를 실행: No issues found.
- `python3 ~/.heoturu-agents/verify.py`: `VERIFY result=PASS scope=all checks=11 failed=0`.
  - 백엔드 pytest: 2330 passed, 47 skipped, 3 warnings in 202.74s (0:03:22).
  - pytest skip: 46 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
  - pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
  - backend ruff/compileall, 테스트·maintenance DB upgrade/check, app pub-get/format/analyze/test 통과.
- backend의 `deptry .`를 별도로 실행: No dependency issues found.
- main과 최종 코드의 `validated_result()` 전체 결과 또는 예외를 12,096개 입력 조합으로 대조하고 두 프롬프트 바이트 동일을 다시 확인했다.
- `git diff --check` 통과. CHANGELOG는 main 대비 차이 없음. #157은 앱 표시·재시도 변화 없이 API·로그 분류만 바꾸며, #158은 동작 보존 정리이므로 제외했다.
- 화면 변경이 없어 최종 화면 검증·시뮬레이터·에뮬레이터·실기기 실행을 하지 않았다. 실제 공급자·운영 검증과 원격 CI도 미실행이다. 원격 `backend-validation.yml`은 승인 후 PR 생성 뒤 확인한다. Docker 복구 및 S3 skip은 통과로 세지 않는다.
- 서버 병합은 운영 배포로 이어진다. 병합 뒤 운영 확인은 이번 완료 조건에 포함하지 않는다.
