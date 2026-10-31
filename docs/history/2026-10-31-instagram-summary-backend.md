# 인스타그램 요약 백엔드 구현과 리뷰 수정

최초 기록일: 2026-10-31 KST. 기준은 [명세 #127](https://github.com/clip-back/clipback/issues/127)과
티켓 #128~#131이다. 통합 브랜치 `feat/instagram-summary`(리뷰 시작 `56a29d5`)의 코드 리뷰 지적을
`feat/instagram-summary-review`에서 고쳤다. 프론트 문구 변경(#132)은
[저장 결과 처리 중 문구를 링크 정보로 통일](2026-10-31-link-pending-message.md)에 따로 기록한다.

## 변경 범위

| 티켓 | 내용 | 커밋 |
| --- | --- | --- |
| [#128](https://github.com/clip-back/clipback/issues/128) | 요약 작업에 `kind`·`target_id`를 두어 유튜브·인스타그램 공용으로 일반화, 종류별 켜짐 | `c77bb51` |
| [#129](https://github.com/clip-back/clipback/issues/129) | 인스타그램 링크 저장 시 캡션 기반 요약(OpenAI), 설정 `INSTAGRAM_SUMMARY_ENABLED`(기본 꺼짐) | `32384ec` |
| [#130](https://github.com/clip-back/clipback/issues/130) | 페이지 응답 판정(게시물 ID 일치·로그인 화면)과 차단 진단 로그 | `02944c3` |
| [#131](https://github.com/clip-back/clipback/issues/131) | 대표 이미지 1장을 요약 근거에 추가, 시도 1회 90초 상한 | `f794ffe` |

### 리뷰 수정(이번 기록에서 실행)

- 대표 이미지 단계 로그: 캡션이 있고 이미지만 실패하면 로그에 남지 않던 문제를 고쳤다.
  `youtube_summary_result`에 `image`(`used`, `reason`, `http_status`)를 더한다. 페이지 판정을 통과한 인스타그램 시도에만 붙고
  유튜브 로그와 페이지 단계 실패 로그는 그대로다. 이미지 주소·서명 토큰·응답 원문은 남기지 않는다.
- 미사용·중복 정리(동작 불변): `PageMeta.names` 제거, 문자열 `http_status_NNN` 되파싱을 `http_status` 필드로 대체,
  `INSTAGRAM_HOSTS`와 게시물 경로 판정을 `app/services/link_url.py`로 통합.
- 이름: `content_service.py`의 `instagram_kind`를 `post_type`(함수 `instagram_post_type`)으로, 테스트 이름의 cover image를 대표 이미지(representative image)로 바꿨다.
- 문서: [요약 문서](../youtube-summary.md)의 진단 로그 절에 `image` 필드와 해석을 반영하고, [CHANGELOG](../../CHANGELOG.md) 미배포에 유튜브 처리 중 문구 변경을 추가했다.
  인스타그램 요약 자체는 기본 꺼짐이라 켜는 #133에서 기록한다.

## 자동 검사

각 티켓(#128~#131) 구현 시 실행한 결과는 해당 커밋 시점의 것이며 이 기록에서 재실행하지 않았다.
아래는 2026-10-31 `feat/instagram-summary-review` worktree(`backend/`, Python 3.12)에서 실제로 실행한 결과다.

- 테스트 먼저 작성해 실패를 확인한 뒤 구현했다: `tests/integrations/test_instagram_summary_image.py`의 이미지 단계 로그 테스트 10건이
  구현 전에 실패했다.
- 추가한 테스트
  - 이미지 단계 로그: 사용, HTTP 403·404·429·503, 형식 불일치(GIF), 이미지 아님, 10MB 초과, `og:image` 없음, 내부망 주소, 5초 초과,
    OpenAI 실패 시에도 기록, 페이지 단계 실패에는 없음. 이미지 주소·서명 토큰·호스트·응답 원문이 로그에 없음을 함께 확인.
  - `tests/integration/test_instagram_summary.py`: 끈 시점에 대기 중이던 작업이 남아 있다가 다시 켜면 `run_once`로 처리됨(명세 US28),
    작업별 시도의 토큰 사용량이 DB `usage`에 저장됨(명세 US35, 재시도 포함 2회).
  - `tests/integrations/test_metadata_client.py`: 실패한 페이지의 `http_status` 필드.

| 검사 | 결과 |
| --- | --- |
| `ruff check app scripts alembic tests` | 통과 |
| `pytest -q --ignore=tests/deployment` | 1208개 통과, 1개 skip(`CLIPBACK_IMAGE_TEST_S3_ENDPOINT`가 필요한 로컬 S3 CLI 테스트), 경고 3건. 점검 게이트 테스트 포함 |
| `python -m compileall app scripts alembic tests` | 통과 |
| `alembic upgrade head` + `alembic check` | 통과(`No new upgrade operations detected.`) |
| `git diff --check` | 통과 |

- 테스트 DB는 이 worktree 전용 PostgreSQL 로컬 DB와 점검 테스트용 로컬 DB다. 도커 PostgreSQL은 사용하지 않았다.
- `tests/deployment`는 이 머신에서 멈추는 테스트가 기준선부터 있어 제외했고, 이번 변경과 관련된 배포 테스트는 없다.

## 미검증 범위

- 실제 인스타그램 페이지·이미지 서버와 실제 OpenAI는 호출하지 않았다. 모든 검증은 대역(MockTransport, 클라이언트 대역)이다.
  서버 IP 차단 여부, 실제 응답 형식, 실제 요약 품질, 실제 토큰 사용량은 운영 확인 티켓 #133에서 확인한다.
- 프론트엔드와 공유 확장은 이 기록의 범위가 아니다.
