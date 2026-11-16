# 게스트 발급과 하루 자동 요약 상한 (#400)

- 기록일: 2026-11-16
- 관련 이슈: [#400](https://github.com/clip-back/clipback/issues/400)
- 기준: `c3db38f`에서 시작한 구현과 검수 반영 코드 `a861481`. 전체 검증은 `a861481`의 clean 상태에서 실행했고, 이후 변경은 이력 문서뿐이다.

## 변경

앱마다 게스트 발급 이동 창과 계정별 하루 자동 요약 수를 메모리에 둔다.
게스트 발급은 IP별·전체 상한을 발급 전에 예약하고 성공 확정 시각을 기록한다.
실패·취소는 예약을 반환하며 거절된 요청은 세지 않는다. 지난 시간 창의 기록은 다음 판정 때 버린다.
클라이언트 IP는 유효한 `X-Real-IP`를 정규화하고, 유효하지 않으면 연결 주소를 사용한다.

일반 링크와 공유 링크는 공통 저장 지점에서 새 `queued` 작업만 센다.
저장 시점의 계정 종류와 KST 날짜로 판정하며 초과 작업은 `skipped`·`daily_limit_exceeded`가 된다.
저장 성공 응답과 기존 요약 제외·재시도·삭제·계정 전환 계약은 유지한다.
DB 모델·마이그레이션·앱 코드는 변경하지 않았다.

## 검수 반영

요약 카운터는 DB 세션의 숨은 상태 대신 저장 요청에서 서비스 생성자에 명시적으로 전달한다.
일반·공유 링크와 업로드 저장 흐름이 같은 앱 카운터를 받으며, 공용 DB dependency는 원래대로 유지한다.
테스트 시계는 이 모듈의 함수만 바꾸도록 분리했고 IP 정규화를 보완했다.
운영 안내는 요약 배포 단락으로 옮겼다. 기존 API 테스트 4곳은 대역의 인자 연결만 바꿨으며
기존 기대값·이름·설명은 유지했다.

## 검증

로컬 전용 PostgreSQL DB 두 개를 새로 준비해 migration과 검사를 수행하고 제거했다.
메타데이터·OCR·소셜 검증·요약 공급자는 테스트 대역이며 외부 서비스에 요청하지 않았다.

- 기준 코드에서 게스트 경계값 회귀가 실패했다: 상한 다음 요청이 429 대신 201이었다.
- 요약 구현 전 일반·공유 저장과 게스트·로그인 계정의 상한 회귀 4개가 실패했다.
- 검수에서 추가한 IP 회귀 2개도 수정 전 실패를 확인한 뒤 반영했다.
- 검수 반영 부분 검사: `250 passed in 69.42s (0:01:09)`, skip 0, 종료 코드 0.
- 변경 파일 ruff 검사: `All checks passed!`, 종료 코드 0.
- 전체 검사: 백엔드 ruff·compileall·deptry, 두 DB의 Alembic upgrade/check,
  DB 테스트를 포함한 전체 pytest, 앱 pub-get·format·analyze·test 모두 통과했다.
- 백엔드: `2743 passed, 49 skipped, 3 warnings in 333.78s (0:05:33)`.
- 앱: `3766`개 통과, `All tests passed!`.
- `VERIFY result=PASS scope=all checks=12 failed=0`, 원 실행 종료 코드 0.

검증 도구가 출력한 skip 요약 원문:

```text
pytest skip: 48 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
```

Docker 배포·운영자 복구 48개는 로컬 미실행이며 원격 CI 대조 예정이다.
S3 CLI 통합 1개는 로컬 미실행(S3 대역 미설정), 원격 CI 대조 예정이다.
새 상한 테스트와 기존 auth·contents·summary 대상 테스트에는 skip이 없다.

## 확인 범위

감독 화면 확인 예정.
운영 배포·실제 OAuth·유료 요약 공급자는 검증하지 않았다.

Railway 공식 문서는 `X-Real-IP`를 클라이언트 IP 식별 헤더로 안내한다.
사용자 결정에 따라 이 헤더를 사용하되, 프록시의 헤더 덮어쓰기와 운영 IPv6 전달은 문서로 확인하지 못했다.
운영 환경의 해당 동작은 미검증이다.
근거: [Public Networking Specs & Limits](https://docs.railway.com/networking/public-networking/specs-and-limits),
[Edge Networking](https://docs.railway.com/networking/edge-networking).
