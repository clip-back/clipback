# 과거 백엔드·운영 현황 설명

- 최초 기록일: 미확인
- 영역: 현황
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: backend/README.md

<a id="b-108834d2c9a091af"></a>

See [Railway deployment and paired backup/restore](../railway-deployment.md)
for all required variables, dashboard settings, Docker persistence checks, and
recovery instructions. The user has reported Railway deployment. Live connectivity, provider login, backups,
and real-device persistence still require separate verification; this documentation
update did not inspect the deployed environment.

## 원문 출처: docs/backend-mvp-plan.md

<a id="b-c5eec4d182b5ccf9"></a>

### 1. 확인 기준

<a id="b-878229ca334e3cf6"></a>

기능별 현황은 2026-09-21 로컬 코드(`9fbadd8`)와 API·테스트·CI 구성을 대조해 정리했다.
이 문서의 **구현 완료**는 코드가 존재한다는 의미다. 2026-09-22에는 `5ca90b2`를 기준으로
메타데이터 DNS 리바인딩 수정을 적용하고 로컬 테스트를 재실행했다. 결과와 미검증 범위는 8절에 기록한다.
이후 PR #30이 머지된 `645046b`를 기준으로 피드 커서를 수정한 결과는 9절에 기록한다.
PR #31이 머지된 `ee73a68`을 기준으로 태그 동시 수정 문제를 검증·수정한 결과는 10절에 기록한다.
PR #32가 머지된 `f5d3e96`을 기준으로 URL 길이 검증을 수정한 결과는 11절에 기록한다.
추천 DB 준비·저장/열람 수집·Today·노출·Weekly API의 로컬 검증 결과는 12~16절에 기록한다.

<a id="b-dd97c07c1ca338fb"></a>

- 합의한 MVP 핵심 백엔드 API, 통합 테스트와 배포 구성이 구현되어 있다.
- 사용자는 Railway 배포 완료를 알렸다. 공개 URL, 운영 변수, 백업 설정과 실기기 동작은 별도 확인이 필요하다.
- 프론트 담당자가 백엔드 연결을 진행 중이다(사용자 전달). 이 체크아웃의 Flutter 화면은 mock 데이터와 로컬 상태를 사용하며, 실제 연동 완료 여부는 별도 확인이 필요하다.
- 별도 공유 테스트 앱은 제거했다. 이후 공유 흐름 검증은 프론트 앱에서 진행한다.
- 카테고리 개인화·수정·삭제는 MVP에 포함한다. 추가 기능 후보를 확정된 MVP 작업으로 간주하지 않는다.
