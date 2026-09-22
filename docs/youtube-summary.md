# YouTube 공유 저장과 비동기 요약

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
| not_requested | 기존 콘텐츠 또는 YouTube가 아닌 콘텐츠 |
| queued / processing | 요약 중 표시. 기본 문구를 완성된 영상 요약으로 표시하지 않음 |
| completed | 요약 표시 |
| failed | 링크 유지, 요약 실패 안내 |
| skipped | 링크 유지, 요약 제외 안내 |

상세 GET을 약 3초 간격으로 조회하고 completed/failed/skipped/not_requested 또는 화면 이탈 시 중단한다.
상세 조회는 열람 횟수를 늘리지 않는다. 별도 상태·재요약 API는 없다.
직접 입력의 비어 있지 않은 제목·요약은 보존하고, 사용자가 선택한 카테고리는 자동 결과로 덮어쓰지 않는다.

오류 코드는 timeout, provider_error, invalid_response, configuration_error,
video_unavailable, duration_exceeded, live_not_supported, disabled로 제한된다.
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

`202609220011` 마이그레이션을 앱 시작 전에 적용한다. 콘텐츠·저장 이벤트·summary_jobs를
같은 트랜잭션에 생성한다. 기존 콘텐츠에는 작업을 만들지 않는다.
단일 API 인스턴스의 lifespan worker가 2초마다 조회하여 한 번에 하나를 처리한다.
외부 호출 동안 DB 연결과 잠금을 유지하지 않는다. 5분 점유와 토큰으로 오래된 결과를 차단한다.
YouTube 조회 10초, Gemini 120초이며 네트워크/시간초과/429/5xx만 30초 후 한 번 재시도한다.
점유 만료 후에도 총 시도 횟수는 최대 2회다. 프로세스 장애 시 공급자 호출의 정확히 한 번 실행은
보장하지 않는다. 회수 로그의 possible_duplicate_call과 공급자 청구 내역을 함께 확인한다.

최종 반영은 사용자→콘텐츠→작업 순서로 잠근다. 처리 중 동일 값의 분류 요청도 수동 선택으로 보존한다.
카테고리 삭제에 영향을 받은 콘텐츠는 자동 분류 대상에서 제외한다. 추천 카테고리가 사라졌으면
현재 분류를 유지한다. 실제 분류 변경만 기존 category_changed 이벤트로 남긴다.
삭제된 콘텐츠를 재생성하지 않으며 저장일·즐겨찾기·태그·누적 저장/열람 횟수는 변경하지 않는다.

기본 배포값:

```dotenv
YOUTUBE_SUMMARY_ENABLED=false
GEMINI_MODEL=gemini-3.5-flash-lite
GEMINI_API_KEY=
YOUTUBE_DATA_API_KEY=
```

활성화할 때 두 키가 없으면 시작을 거부한다. Google 로그인 토큰과 YouTube 서버 키는 별개다.
키는 Railway Variables에만 등록하며 저장소/로그에 넣지 않는다. replica=1, uvicorn workers=1 유지.
비활성 상태에서 신규 저장은 skipped/disabled이며 기존 대기 작업은 남겨 재활성화 후 이어간다.
비활성 상태에서 저장한 skipped 작업과 과거 콘텐츠는 자동 재처리하지 않는다.
환경 변수 변경을 위한 재시작 시 실행 중 작업은 만료 후 회수된다.

구조화된 로그 youtube_summary_claim/result/stale_result/worker_error를 사용한다.
pending_count, elapsed_seconds, error_code, model, usage를 집계해 대기량·실패율·시간·토큰 사용량을 확인한다.
원문 응답·키는 기록하지 않는다. 작업별 시도 usage도 DB에 보존한다. 응답을 받기 전 중단된 호출의
정확한 토큰 수는 알 수 없으므로 청구 내역으로 보완한다.

## 검증과 활성화

자동 테스트는 실제 PostgreSQL·HTTP 요청을 사용하고 공급자는 고정 응답으로 대체한다.
worker.run_once를 직접 호출하여 반복 루프·실제 유료 호출 없이 검증한다.
기존 CI migration job이 tests/repositories와 tests/integration 전체를 실행하므로 신규 테스트도 필수다.

```bash
TEST_DATABASE_URL=postgresql+asyncpg://... pytest -q
ruff check app alembic tests
python -m compileall -q app alembic tests
alembic upgrade head
alembic check
```

실제 키 등록·공급자 접근·한국어 일반 영상/Shorts 품질·처리 시간·청구 검증은 별도 운영 단계다.
먼저 제한된 검증 환경에서 확인한 뒤 운영 플래그를 활성화한다. 자동 테스트 성공을 실제 모델 접근
가능 여부나 영상 요약 정확성 검증으로 간주하지 않는다.

- [Gemini YouTube 입력](https://ai.google.dev/gemini-api/docs/generate-content/video-understanding)
- [Gemini 구조화 출력](https://ai.google.dev/gemini-api/docs/generate-content/structured-output)
- [YouTube videos.list](https://developers.google.com/youtube/v3/docs/videos/list)
