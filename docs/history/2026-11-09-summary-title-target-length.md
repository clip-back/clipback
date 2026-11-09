# 자동 제목을 공백 포함 25자 안팎·핵심 대상으로 요청하기 (#314)

2026-11-09, 시작 커밋 `b191e43` 기준으로 구현하고 티켓 리뷰, 로컬 전체 검증까지 마쳤다. 코드 커밋은 `c3c342e`이다.
서버 프롬프트만 바꿨고 API·DB·앱은 바뀌지 않는다. 실제 모델 표본 확인은 자료를 기다리고 있어 이슈는 열어 둔다.

## 사용자 결정

- 2026-11-09 "프롬프트 목표 25자 (Recommended)": 유튜브·인스타그램 프롬프트에 공백 포함 25자 안팎·핵심 대상만 지시를 넣는다. 서버 120자 검사는 그대로다.
- 2026-11-09 "사진 제목까지 넓힘": 사진(OCR) 저장 제목에도 같은 25자 목표를 넣는다.
- 함께 정한 해석: 프롬프트의 기존 "120자 이내" 문구는 두고 25자 목표를 더한다. 응답 스키마의 제목 설명은 손대지 않는다. 새로 저장하는 콘텐츠부터 적용한다.

## 구현

- `backend/app/integrations/youtube_summary_client.py`·`instagram_summary_client.py`: 기존 `제목은 {MAX_TITLE_LENGTH}자 이내.` 문장 앞에
  `제목은 공백 포함 25자 안팎으로, 핵심 대상만 담는다.`를 더했다. 상한 문장은 글자 그대로라 상한 값 한 곳(#158)을 따르는 동작이 유지된다.
- `backend/app/integrations/ocr_client.py`: 영어 시스템 프롬프트의 제목·요약 생성 문장 뒤에
  `Keep the title to 공백 포함 25자 안팎 (about 25 characters including spaces) and name only the 핵심 대상 (the core subject).`를 더했다.
  사진 프롬프트에는 원래 상한 문구가 없어 새로 넣지 않았다. 기존 요약 지시 문장은 줄 나눔만 바뀌고 문자열은 같다.
- 바꾸지 않은 것: `MAX_TITLE_LENGTH`·`validated_result()`·`MAX_OCR_TITLE_LENGTH`·사진 제목 120자 자르기, 세 경로의 응답 스키마, 핵심 한 줄·요점·사진 요약 지시, 웹 링크 경로.
- [자동 요약 안내](../youtube-summary.md)의 YouTube 분석 조건, 상한 설명, 인스타그램 절에 25자 목표(상한 아님)를 적었다. 사진 OCR 제목 지시를 설명하는 문서는 없었다.
- CHANGELOG `미배포 > 개선`에 `[서버]` 줄을 더했다.

## 테스트

- #314 허용 표대로 기존 테스트 세 개의 문구 단언만 늘렸다. 스키마 비교·경계·오류 코드 단언은 그대로다.
  - `test_youtube_summary_client.py::test_gemini_is_asked_for_a_headline_and_points`, `test_instagram_summary_client.py::test_gpt_is_asked_for_a_headline_and_points`:
    문구 목록에 "공백 포함 25자 안팎", "핵심 대상", "제목은 120자 이내."를 추가.
  - `test_ocr_client.py::test_extract_uses_canonical_mime_and_fixed_operational_options`: 시스템 프롬프트에 "공백 포함 25자 안팎", "핵심 대상" 단언 추가.
- `test_summary_length_limits.py`는 상한 문장을 그대로 둬서 바꾸지 않고 통과한다.
- 구현 전 실패: 테스트만 바꾼 상태에서 세 테스트 모두 새 문구가 없어 실패(3 failed). 구현 뒤 관련 5개 파일 238 passed.

## 리뷰

- 티켓 리뷰(`b191e43..c3c342e`): Standards 0건, Spec 0건. 검수자가 관련 5개 파일을 직접 실행해 238 passed를 확인했다.

## 검증

2026-11-09, 기준 코드 `c3c342e`(로컬, 대역 데이터). 이 문서를 더한 커밋은 문서만 바꾸며 코드가 `c3c342e`와 같다.

- 전체 검증 `python3 ~/.heoturu-agents/verify.py`: `VERIFY result=PASS scope=all checks=11 failed=0`.
  백엔드 `pytest: 2330 passed, 47 skipped, 3 warnings in 227.44s (0:03:47)`.
  - pytest skip: 46 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
  - pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
- 이슈의 CI Backend Validation 명령과의 대조:
  - `ruff check app scripts alembic tests`, `python -m compileall app scripts alembic tests`: verify의 `backend:ruff`·`backend:compileall` 단계로 확인.
  - `pytest -q`, PostgreSQL을 쓰는 `pytest -q tests/repositories tests/integration`: verify가 로컬 PostgreSQL 검사 DB를 만들어 DB 테스트까지 포함한 `pytest -q -rs` 전체로 확인.
  - `deptry .`(backend): verify에 없어 따로 실행해 통과(No dependency issues found).
- Docker가 필요한 deployment·운영자 복구 테스트(위 skip 46개)는 로컬에서 돌지 않았다. 이번 변경은 이 범위를 바꾸지 않았고, 원격 CI는 승인 후 PR 생성 뒤 확인한다.
- 실제 공급자·운영 서버·실기기 검증은 하지 않았다. 서버 병합은 운영 배포로 이어지며, 배포 뒤 새로 저장한 제목 길이와 상세 화면 줄 수는 사용자 확인 범위다.

## 실제 모델 표본 (미실행)

- 실제 모델 호출 0회. 유튜브 3·인스타그램 3건(사용자 승인, 최대 8회·약 0.10달러)과 #315 쪽 사진 3건 제목 길이 확인이 남았다.
- 미실행 사유: 2026-11-09 기준 자료가 일부만 도착했다(인스타그램 3건·사진 2건 준비, 유튜브 Gemini 키와 글자 없는 사진 대기).
  같은 자료로 중복 호출하지 않도록 #315 구현·검수를 마친 코드에서 함께 실행할 예정이다.
- 합격 기준(6건 중 5건 이상 공백 포함 20–30자, 의미 보존은 사용자 판정, `invalid_response` 0건)과 사용자 판정은 아직 없다. 판정 전에는 병합하지 않는다.
