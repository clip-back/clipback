# 사진 자동 요약도 핵심 한 줄과 요점 목록으로 만들기 (#315)

2026-11-09, 시작 커밋 `7f65603` 기준으로 구현하고 티켓 리뷰와 로컬 전체 검증까지 마쳤다. 코드 커밋은 `1207b28`이다.
서버만 바꿨고 API·DB·앱은 바뀌지 않는다. 실제 모델 표본은 사진 3건이 모두 시간 초과로 실패해 멈췄고, 이슈는 열어 둔다.

## 사용자 결정

- 2026-11-09 "서버가 같은 형식으로 (Recommended)": 사진 요약도 서버가 "핵심 한 줄 + • 요점"으로 만들어 저장한다. API·앱 변경 없음, 새로 저장하는 사진부터.
- "0–5개, 0개면 한 줄만 (Recommended)": 요점이 없으면 핵심 한 줄만 저장하고 요점을 지어내지 않는다.
- "사진 3건 (Recommended)": 긴 글·짧은 글·글자 없는 사진 각 1건, 최대 4회 호출로 제목 25자(#314)와 목록 형식을 함께 본다.
- 인스타그램 줄글 "넘어감 (Recommended)": 이번에는 사진만 고치고 인스타그램 표본에서 형식만 함께 기록한다.

## 구현

- `backend/app/integrations/summary.py`: 링크 요약의 정리·합치기를 판정 없는 `join_headline_and_points()`로 나눴다.
  핵심 한 줄이 비면 빈 문자열, 남은 요점이 없으면 핵심 한 줄만 돌려준다. 링크 요약의 `_joined_summary()`는 타입 검사 뒤 이 함수를 쓰고,
  결과에 줄바꿈이 없으면(핵심 한 줄이 비거나 요점이 0개) 전처럼 `invalid_response`다. 정리 순서는 그대로다.
- `backend/app/integrations/ocr_client.py`: 모델 응답용 `ScreenshotOCROutput(text, title, headline, points)`를 더했다.
  길이·개수 지시(핵심 한 줄 40자, 요점 60자, 최대 5개, 최소 개수 없음)는 인스타그램처럼 요청 스키마에만 둔다.
  `extract()`가 돌려주는 `ScreenshotOCRResult(text, title, summary)`는 그대로이고 `summary`만 합친 모양(500자에서 자름)이 된다.
  프롬프트의 요약 지시를 유튜브·인스타그램과 같은 뜻으로 바꾸고 옛 예시를 새 형식 예시로 바꿨다. 신뢰하지 않는 데이터·원문 언어·5000자·#314 제목 25자 문구는 유지했다.
- 문서: [자동 요약 안내](../youtube-summary.md)에 사진 OCR 요약 문단, [ADR 0005](../adr/0005-summary-headline-and-points-as-plain-text.md) 대상 범위,
  [용어집](../../GLOSSARY.md)의 핵심 한 줄·요점 정의, CHANGELOG `미배포 > 개선`의 `[서버]` 줄.

## 테스트

- 새 회귀 테스트(`backend/tests/integrations/test_ocr_client.py`): 목록 모양, 요점 0개면 핵심 한 줄만, 빈 핵심 한 줄은 요약만 빔,
  같은 답을 넣은 유튜브·인스타그램 요약과 같은 정리 결과(3가지 입력 × 2종류), 요청 스키마, 프롬프트 문구.
- 기존 테스트는 #315 허용 표 칸(모델 응답 대역, 기대 `summary`, `text_format`)만 바꿨다. 서비스·통합·링크 요약 테스트는 바꾸지 않았다.
- 구현 전 실패: 새 테스트를 더한 상태에서 11 failed. 구현 뒤 `test_ocr_client.py` 20 passed, 관련 소비자(`tests/integrations` 전체와 업로드·콘텐츠 서비스) 497 passed.

## 리뷰

- 티켓 리뷰(`7f65603..1207b28`): Standards 0건, Spec 0건. 검수자가 링크 요약 판정 전후를 180개 입력 조합으로 비교해 결과가 같음을 확인했다.

## 검증

2026-11-09, 기준 코드 `1207b28`(로컬, 대역 데이터). 이 문서를 더한 커밋은 문서만 바꾸며 코드가 `1207b28`과 같다.

- 전체 검증 `python3 ~/.heoturu-agents/verify.py`: `VERIFY result=PASS scope=all checks=11 failed=0`.
  백엔드 `pytest: 2341 passed, 47 skipped, 3 warnings in 222.91s (0:03:42)`.
  - pytest skip: 46 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
  - pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
- 이슈의 CI Backend Validation 명령과의 대조:
  - `ruff check app scripts alembic tests`, `python -m compileall app scripts alembic tests`: verify의 `backend:ruff`·`backend:compileall` 단계로 확인.
  - `pytest -q`, PostgreSQL을 쓰는 `pytest -q tests/repositories tests/integration`: verify가 로컬 PostgreSQL 검사 DB로 DB 테스트까지 포함한 전체 pytest로 확인.
  - `deptry .`(backend): verify에 없어 따로 실행해 통과(No dependency issues found).
- Docker가 필요한 deployment·운영자 복구 테스트(위 skip 46개)는 로컬에서 돌지 않았다. 이번 변경은 이 범위를 바꾸지 않았고, 원격 CI는 승인 후 PR 생성 뒤 확인한다.
- 운영 서버·실기기 검증은 하지 않았다. 배포 뒤 새로 저장한 사진의 상세 요약 모양은 사용자 확인 범위다.

## 실제 모델 표본 (실패로 멈춤)

2026-11-09, 코드 `1207b28`. DB 없이 `.utmp`의 일회용 스크립트로 실제 `OCRClient.extract()`와 `InstagramSummaryClient.summarize()`를 불렀다.
SDK 자동 재시도는 끄고(`max_retries=0`) 요청 직전에 호출 수를 파일에 먼저 세어, 중단되어도 같은 표본을 다시 부르지 않게 했다.
사진에 개인 대화가 있어 원문·OCR 텍스트·제목·요약 글은 남기지 않고 아래 수치만 옮긴다. 모델은 `gpt-5.4-nano-2026-03-17`.

| 표본 | 결과 | 제목 길이 | 요점 수 | 목록 형식 | usage(입력/출력) |
| --- | --- | --- | --- | --- | --- |
| 사진 긴 글 | `OCRClientTimeoutError` | — | — | — | 받지 못함 |
| 사진 짧은 글 | `OCRClientTimeoutError` | — | — | — | 받지 못함 |
| 사진 글자 없음 | `OCRClientTimeoutError` | — | — | — | 받지 못함 |

- 사진 호출 3회(승인 최대 4회). 세 건 모두 시간 초과라 합격 기준(글 있는 사진의 목록 형식, 짧은 글 요점 0–1개, 글자 없는 사진 빈 결과, OCR 실패 0건)을 확인하지 못했다.
  응답 전에 끊겨 usage가 없으므로 비용은 확인할 수 없다(요청이 과금됐을 수 있다).
- 이번 로컬 실행의 시간 제한은 `backend/.env`의 `OCR_TIMEOUT_SECONDS=5`(코드 기본값도 5초)였다. 이것이 원인 후보이지만 확인하지 않았고, 운영 값은 조회하지 않았다.
  운영에서도 늘 실패한다고 볼 근거는 없다.
- 반복 실패라 지시대로 시간 제한·프롬프트를 바꾸거나 다시 호출하지 않고 멈췄다. 같은 실행에서 인스타그램 3건의 요약 형식도 기록했다([#314 이력](2026-11-09-summary-title-target-length.md)): 모두 성공, 요점 5·4·3개, 목록 형식.
- 남은 사용자 결정: 사진 표본을 어떤 시간 제한으로 몇 회 더 실행할지(또는 미검증으로 둘지), 의미 보존·지어낸 요점 여부 판정. 판정 전에는 병합하지 않는다.
