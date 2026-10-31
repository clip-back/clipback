# YouTube 공유 저장과 비동기 요약

이 문서는 YouTube의 저장·요약과 함께 YouTube·인스타그램이 공유하는 요약 작업·worker 구조를 다룬다.
인스타그램 대상·근거·설정은 [인스타그램 자동 요약](#인스타그램-자동-요약)에 있다.

## API와 프론트 연동

`POST /api/v1/contents/share`의 `url` 또는 `raw_text`에 YouTube 링크를 전달한다.
직접 입력은 기존 `POST /api/v1/contents`의 `original_url`을 사용한다. 인증과 `201` 응답은 동일하다.
`201`은 저장 완료이며 영상 분석 완료를 뜻하지 않는다. 동일 영상의 반복 저장도 별도 콘텐츠다.

허용 호스트는 `youtube.com`, `www.youtube.com`, `m.youtube.com`, `youtu.be`이며,
일반 `/watch?v=`, `/shorts/`, `/live/`, 짧은 링크를 지원한다. 11자리 영상 ID를 검증한다.
채널·Clip·영상 ID 없는 재생목록은 422. source/source_app보다 URL 검증을 우선한다.
저장 URL은 watch 형식으로 정규화하고 유효한 t/start 시간은 초 단위 t로 보존한다.
si/list 등은 제거하며 Gemini에는 재생 시점 없는 전체 영상 URL을 전달한다.

저장·상세·피드·수정의 ContentRead에는 다음 필드가 항상 포함된다.

```json
{"summary_status":"queued","summary_error_code":null}
```

| 상태 | 화면 처리 |
| --- | --- |
| not_requested | 기존 콘텐츠 또는 요약 대상이 아닌 콘텐츠(YouTube·인스타그램 링크가 아닌 콘텐츠) |
| queued / processing | 요약 중 표시. 기본 문구를 완성된 영상 요약으로 표시하지 않음 |
| completed | 요약 표시 |
| failed | 링크 유지, 요약 실패 안내 |
| skipped | 링크 유지, 요약 제외 안내 |

상세 GET을 약 3초 간격으로 조회하고 completed/failed/skipped/not_requested 또는 화면 이탈 시 중단한다.
상세 조회는 열람 횟수를 늘리지 않는다. 별도 상태·재요약 API는 없다.
직접 입력의 비어 있지 않은 제목·요약은 보존하고, 사용자가 선택한 카테고리는 자동 결과로 덮어쓰지 않는다.

오류 코드는 timeout, provider_error, invalid_response, configuration_error,
video_unavailable, duration_exceeded, live_not_supported, disabled와
인스타그램용 content_unavailable, unsupported_content, insufficient_content로 제한된다.
일시 장애 재시도 대기 중에는 queued와 직전 오류 코드가 반환될 수 있다.

## 분석 조건

YouTube Data API videos.list로 공개 상태·길이·라이브 여부를 먼저 확인한다.
공개된 1~1,200초 완료 영상만 분석한다. 일반 영상과 Shorts를 지원하며 종료된 라이브도 같은 조건이다.
비공개·일부 공개·접근 제한·삭제 영상은 video_unavailable, 20분 초과는 duration_exceeded,
진행 중/예정 라이브는 live_not_supported로 제외한다. 정보를 확인할 수 없으면 유료 분석을 시작하지 않는다.

Gemini에 공개 URL을 입력하며 영상/대본을 직접 다운로드하거나 저장하지 않는다.
제목 120자, 요약 500자 이내의 한국어 정보형·명사형 문장을 요청하고 결과를 검증한다.
영상·캡션·카테고리 이름은 명령으로 신뢰하지 않는다. 출력은 title/summary/category_id만 사용한다.
사용자 카테고리 후보에 없는 ID는 무시한다. 제목/설명만을 영상 요약으로 대체하지 않는다.

## 작업·운영

`202609220011`·`202610310021` 마이그레이션을 앱 시작 전에 적용한다. 콘텐츠·저장 이벤트·summary_jobs를
같은 트랜잭션에 생성한다. 기존 콘텐츠에는 작업을 만들지 않는다.

summary_jobs는 자동 요약 작업의 공용 테이블이다. `kind`(`youtube`/`instagram`)가 작업 종류이고
`target_id`가 종류별 대상 식별자다. YouTube는 11자리 영상 ID를 담으며, 기존 행은 `202610310021`에서
`kind=youtube`, 기존 `video_id` 값의 `target_id`로 이관되었다. 대기열·점유·재시도·오래된 결과 차단·잠금 순서는
종류와 무관하게 같다. worker는 종류별 켜짐 여부를 판단해 켜진 종류의 작업만 가져가고, 꺼진 종류의 작업은
상태 변경 없이 남겨 둔다. 처리할 때는 작업 종류에 맞는 요약 클라이언트를 고른다. 구현된 종류는 YouTube와 인스타그램이다.
단일 API 인스턴스의 lifespan worker가 2초마다 조회하여 한 번에 하나를 처리한다.
외부 호출 동안 DB 연결과 잠금을 유지하지 않는다. 5분 점유와 토큰으로 오래된 결과를 차단한다.
YouTube 조회 10초, Gemini 120초, 인스타그램 페이지 5초, OpenAI 60초이며 네트워크/시간초과/429/5xx만 30초 후 한 번 재시도한다.
점유 만료 후에도 총 시도 횟수는 최대 2회다. 프로세스 장애 시 공급자 호출의 정확히 한 번 실행은
보장하지 않는다. 회수 로그의 possible_duplicate_call과 공급자 청구 내역을 함께 확인한다.

최종 반영은 사용자→콘텐츠→작업 순서로 잠근다. 처리 중 동일 값의 분류 요청도 수동 선택으로 보존한다.
카테고리 삭제에 영향을 받은 콘텐츠는 자동 분류 대상에서 제외한다. 추천 카테고리가 사라졌으면
현재 분류를 유지한다. 실제 분류 변경만 기존 category_changed 이벤트로 남긴다.
삭제된 콘텐츠를 재생성하지 않으며 저장일·즐겨찾기·태그·누적 저장/열람 횟수는 변경하지 않는다.

기본 배포값:

```dotenv
YOUTUBE_SUMMARY_ENABLED=true
GEMINI_MODEL=gemini-3.5-flash-lite
GEMINI_API_KEY=
YOUTUBE_DATA_API_KEY=
```

기본 활성 상태에서 두 키가 없으면 시작을 거부한다. 키 없이 실행하려면 `YOUTUBE_SUMMARY_ENABLED=false`를 명시한다. 기존 Railway 변수에 `false`가 남아 있으면 기본값보다 우선하므로 `true`로 바꾸거나 제거한다. Google 로그인 토큰과 YouTube 서버 키는 별개다.
키는 Railway Variables에만 등록하며 저장소/로그에 넣지 않는다. replica=1, uvicorn workers=1 유지.
비활성 상태에서 신규 저장은 skipped/disabled이며 기존 대기 작업은 남겨 재활성화 후 이어간다.
비활성 상태에서 저장한 skipped 작업과 과거 콘텐츠는 자동 재처리하지 않는다.
환경 변수 변경을 위한 재시작 시 실행 중 작업은 만료 후 회수된다.

구조화된 로그 youtube_summary_claim/result/stale_result/worker_error를 사용한다. 이벤트 이름은 작업 종류와 관계없이 같고, claim/result의 `kind`(`youtube`/`instagram`)로 구분한다.
pending_count, elapsed_seconds, error_code, model, usage를 집계해 대기량·실패율·시간·토큰 사용량을 확인한다.
원문 응답·키는 기록하지 않는다. 작업별 시도 usage도 DB에 보존한다. 응답을 받기 전 중단된 호출의
정확한 토큰 수는 알 수 없으므로 청구 내역으로 보완한다.

## 인스타그램 자동 요약

결정 근거는 [ADR 0002](adr/0002-instagram-summary-caption-and-image.md), 용어는 [GLOSSARY](../GLOSSARY.md)의
자동 요약·요약 근거를 따른다. 요약 근거는 공개 게시물 페이지의 캡션이며(대표 이미지와 페이지 응답 판정은 후속 작업),
영상·음성은 분석하지 않으므로 릴스 요약을 영상 요약이라고 부르지 않는다.

- 대상: 공유 저장(`POST /contents/share`)과 직접 입력(`POST /contents`)으로 저장에 성공한 `/reel/`, `/p/`, `/tv/` 링크.
  같은 트랜잭션에서 작업(`kind=instagram`, `target_id`=정규화 URL)을 만든다. 기존 콘텐츠에는 만들지 않는다.
  `/stories/`는 저장하되 `skipped`/`unsupported_content`다.
- 저장 동작(링크 정규화, 공유 저장의 `/share/` 해석과 실패 시 422, 직접 입력의 `/share/` 422, 메타데이터로 제목·요약 채우기,
  저장 시 카테고리 추천)은 유지한다. 공유 텍스트(`raw_text`)는 작업에 보관하지 않고 요약 입력으로도 쓰지 않는다.
- 반영 규칙은 YouTube와 같다. 사용자가 직접 입력한 제목·요약과 선택한 카테고리는 보존하고,
  저장 시 자동 추천된 카테고리는 결과가 다르면 교체하며 `category_changed`를 남긴다. 저장 시 메타데이터로 채워진 제목·요약은 교체한다.
- 요약 시점에 공개 게시물 페이지를 다시 받는다(메타데이터 수집의 내부망 차단·리다이렉트·응답 크기·시간 제한 재사용).
  `og:description`(없으면 `og:title`)의 `"…"` 부분을 캡션으로 쓰며, 캡션이 없으면 GPT를 호출하지 않고
  `skipped`/`insufficient_content`다. 캡션은 서버에 보관하지 않는다.
- OpenAI Responses API 구조화 출력(`title`/`summary`/`category_id`), `store=False`, SDK 자동 재시도 없음, 60초 상한.
  제목 120자·요약 500자와 후보 ID를 검증하고, 캡션·카테고리 이름은 명령으로 신뢰하지 않는다.
  OpenAI 401/403은 `configuration_error`, 429/5xx/네트워크/시간 초과는 30초 뒤 한 번 재시도하는 `provider_error`/`timeout`,
  그 밖의 형식 오류는 `invalid_response`다.
- 인스타그램 페이지 응답은 429/5xx/네트워크/시간 초과만 재시도하고, 그 밖의 비정상 응답은 재시도 없이 `failed`/`provider_error`다.
  `content_unavailable`(비공개·삭제·로그인 필요 판정)과 게시물 ID 일치 확인은 후속 작업에서 추가하며,
  그 전에는 로그인 화면 같은 비게시물 응답을 구분하지 못하므로 운영에서 켜지 않는다.
- 로그는 같은 `youtube_summary_*` 이벤트에 `kind=instagram`으로 남는다. 실패한 `provider`는 단계(`instagram` 페이지,
  `openai`)이고 `http_status`·`retryable`·`usage`를 함께 기록한다. 캡션·요청 URL·응답 원문·키는 기록하지 않는다.

설정:

```dotenv
INSTAGRAM_SUMMARY_ENABLED=false
INSTAGRAM_SUMMARY_MODEL=gpt-5.4-nano-2026-03-17
```

기본값은 꺼짐이다. 키는 기존 `OPENAI_API_KEY`를 쓰며, 켠 상태에서 키가 없으면 시작을 거부한다.
꺼진 상태에서 저장한 인스타그램 링크는 `skipped`/`disabled`이고 다시 켜도 재처리하지 않는다.
이미 대기 중인 작업은 끄는 동안 남아 있다가 다시 켜면 이어서 처리된다. YouTube와 인스타그램은 켜고 끄기가 서로 독립이며
하나의 대기열·단일 worker를 공유한다. 서버 IP 차단 여부와 요약 품질은 운영 환경에서 별도로 확인한 뒤 켠다.

## 검증과 활성화

자동 테스트는 실제 PostgreSQL·HTTP 요청을 사용하고 공급자는 고정 응답으로 대체한다.
worker.run_once를 직접 호출하여 반복 루프·실제 유료 호출 없이 검증한다.
기존 CI migration job이 tests/repositories와 tests/integration 전체를 실행하므로 신규 테스트도 필수다.

```bash
TEST_DATABASE_URL=postgresql+asyncpg://... pytest -q
ruff check app alembic tests
python -m compileall -q app alembic tests
YOUTUBE_SUMMARY_ENABLED=false alembic upgrade head
YOUTUBE_SUMMARY_ENABLED=false alembic check
```

실제 키 등록·공급자 접근·한국어 일반 영상/Shorts 품질·처리 시간·청구 검증은 별도 운영 단계다.
운영 배포 전에 두 키를 등록하고 제한된 환경에서 실제 영상을 확인한다. 자동 테스트 성공을 실제 모델 접근
가능 여부나 영상 요약 정확성 검증으로 간주하지 않는다.

- [Gemini YouTube 입력](https://ai.google.dev/gemini-api/docs/generate-content/video-understanding)
- [Gemini 구조화 출력](https://ai.google.dev/gemini-api/docs/generate-content/structured-output)
- [YouTube videos.list](https://developers.google.com/youtube/v3/docs/videos/list)

### Railway 실패 진단 로그

앱 시작 시 `app` 로거의 INFO 출력을 활성화한다. HTTP 라이브러리의 요청 URL 로그는 활성화하지 않는다.
`youtube_summary_result`의 오류는 WARNING으로 출력하며 콘텐츠 ID, 모델, `provider`
(`youtube` 또는 `gemini`. 인스타그램은 실패 단계인 `instagram` 또는 `openai`), `http_status`, 허용된 Google 오류 식별자 `provider_status`,
`retryable`을 포함한다. 네트워크 오류처럼 HTTP 응답이 없으면 상태 코드는 null이다.
키·요청 URL·응답 원문·공급자 오류 메시지는 기록하지 않는다.

예를 들어 `provider=gemini`, `http_status=429`, `provider_status=RESOURCE_EXHAUSTED`라면
Gemini 사용량 제한을 확인한다. `400`이나 `404`만으로 모델·요청·영상 중 원인을 확정하지 않는다.
`youtube_summary_worker_error`는 예외 종류만 남긴다.

이 로그는 수정 배포 이후 실행에 적용된다. 이미 failed가 된 작업은 자동 재실행하지 않으므로
동일 링크를 새 콘텐츠로 저장하여 새 ID의 로그를 확인한다. API의 공개 오류 코드는 변경하지 않는다.
