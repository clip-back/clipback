# 게스트 발급과 하루 자동 요약 상한 (#400)

- 기록일: 2026-11-16
- 관련 이슈: [#400](https://github.com/clip-back/clipback/issues/400)
- 기준: `c3db38f`에서 시작한 구현. 아래는 첫 검수 전 부분 검사 기록이다.

## 변경

앱마다 게스트 발급 이동 창과 계정별 하루 자동 요약 수를 메모리에 둔다.
게스트 발급은 IP별·전체 상한을 발급 전에 예약하고 성공 확정 시각을 기록한다.
실패·취소는 예약을 반환하며 거절된 요청은 세지 않는다. 지난 시간 창의 기록은 다음 판정 때 버린다.
클라이언트 IP는 유효한 `X-Real-IP`를 정규화하고, 유효하지 않으면 연결 주소를 사용한다.

일반 링크와 공유 링크는 공통 저장 지점에서 새 `queued` 작업만 센다.
저장 시점의 계정 종류와 KST 날짜로 판정하며 초과 작업은 `skipped`·`daily_limit_exceeded`가 된다.
저장 성공 응답과 기존 요약 제외·재시도·삭제·계정 전환 계약은 유지한다.
DB 모델·마이그레이션·앱 코드는 변경하지 않았다.

## 첫 검수 전 검증

로컬 PostgreSQL의 새 전용 DB를 migration한 뒤 테스트 트랜잭션으로 검사하고 DB를 제거했다.
메타데이터·OCR·소셜 검증·요약 공급자는 테스트 대역이며 외부 서비스에 요청하지 않았다.

- 기준 코드에서 게스트 경계값 회귀가 실패했다: 상한 다음 요청이 429 대신 201이었다.
- 요약 구현 전 일반·공유 저장과 게스트·로그인 계정의 상한 회귀 4개가 실패했다.
- 게스트 구현 후 관련 인증 API 검사: `40 passed in 1.18s`.
- 최초 요약 부분 검사: `1 failed, 245 passed in 75.06s`. 새 계정 전환 테스트가 전환으로 폐기된 토큰을 재사용한 오류였으며, 전환 응답의 새 토큰을 사용하도록 수정했다.
- 최종 관련 부분 검사: `357 passed in 74.58s (0:01:14)`, skip 0, 종료 코드 0.
  새 회귀와 기존 인증·콘텐츠 API·콘텐츠 서비스·작업 생성·인증 흐름·요약 worker·저장 흐름 계약을 포함한다.
- 변경 파일 ruff 검사: `All checks passed!`, 종료 코드 0.
- fixture import 연결을 정리한 뒤 worker 재시도 단일 회귀: `1 passed, 10 deselected in 0.45s`, 종료 코드 0.
- 기존 테스트 변경은 공용 client fixture의 상한 상태 초기화뿐이며 기존 기대값·이름·설명은 유지했다.

## 남은 검증과 확인 범위

첫 검수 전 단계이므로 전체 CI 동등 검사·DB 전체 검사·Alembic check는 아직 실행하지 않았다.
iOS Simulator·Android Emulator의 새 안내 문구 및 글자 배율 확인도 아직 수행하지 않았다.
운영 배포·실제 OAuth·유료 요약 공급자는 검증하지 않았다.

Railway 공식 문서는 `X-Real-IP`를 클라이언트 IP 식별 헤더로 안내한다.
사용자 결정에 따라 이 헤더를 사용하되, 프록시의 헤더 덮어쓰기와 운영 IPv6 전달은 문서로 확인하지 못했다.
운영 환경의 해당 동작은 미검증이다.
근거: [Public Networking Specs & Limits](https://docs.railway.com/networking/public-networking/specs-and-limits),
[Edge Networking](https://docs.railway.com/networking/edge-networking).
