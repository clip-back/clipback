# 링크 메타데이터와 인스타그램 응답 압축 처리 (#397)

- 기록일: 2026-11-16
- 관련 이슈: [#397](https://github.com/clip-back/clipback/issues/397)
- 기준: `ce05582`에서 시작한 구현 커밋 `77344a0`과 아래 검수 반영 코드. 전체 검증은 검수 반영 뒤, 이력 문서 추가 전에 실행했다.

## 변경

링크 메타데이터, 인스타그램 게시물 페이지와 대표 이미지는 공통 수신 경로에서 응답 압축을 판정한다.
요청은 `Accept-Encoding: gzip`을 사용한다. 응답 헤더의 여러 줄과 쉼표를 합쳐 공백과 대소문자를
정규화하고 빈 값과 `identity`를 제외한다. 압축 없음과 gzip 한 겹을 허용하며 다른 압축은 본문을
읽기 전에 `unsupported_encoding`으로 처리한다.

gzip을 풀 때 출력량을 남은 본문 한도에 맞춰 제한하고, 한도 초과 조각은 본문에 붙이지 않는다.
gzip 종료 뒤에는 추가 조각을 읽지 않고 이미 받은 본문으로 성공한다. 손상되거나 완결되지 않은
gzip은 `request_failure`로 처리한다. 기존 크기 한도, 시간 제한, 리다이렉트와 재시도 정책은 유지한다.

메타데이터를 받지 못한 일반 링크의 저장은 유지한다. 인스타그램 페이지의 `unsupported_encoding`은
재시도 없는 `provider_error`이며, 대표 이미지의 같은 실패는 캡션만으로 요약을 계속하고
`image.reason`에 남긴다. 현재 계약은 [자동 요약 안내](../youtube-summary.md#인스타그램-진단-로그)에 기록했다.

## 검수 반영

- 측정용 테스트 출력을 제거했다.
- 압축 토큰 정규화 식은 동작과 가독성을 유지하기 위해 그대로 두었다.
- gzip 종료 후 읽기를 멈추도록 보완했다. 세 공개 메서드 각각에서 기존 성공 결과와 본문을 유지하고
  후속 조각을 읽지 않는지 회귀 테스트로 확인했다.
- 기존 테스트의 기대값, 이름, 설명과 fixture는 변경하지 않았다.

## 검증

로컬 대역 응답으로 검사했으며 실제 외부 사이트에는 요청하지 않았다.

- 최초 회귀에서 기준 코드의 메모리 상한 단언 실패를 확인한 뒤 구현했다.
- 검수 반영 전 종료 처리 회귀: `3 failed, 46 deselected in 0.10s`. 성공과 본문 단언은 통과했고,
  추가 수신을 막는 단언에서 실패했다.
- 검수 반영 후 변경 파일 ruff: `All checks passed!`.
- 관련 소비자와 새 회귀: `452 passed in 2.88s`.
- 전체 검사: 백엔드 ruff, compileall, deptry, 일반·maintenance 검사 DB의 Alembic upgrade/check,
  pytest 및 앱 의존성, 포맷, 분석, 전체 테스트 통과.
- 전체 백엔드 pytest: `2719 passed, 49 skipped, 3 warnings in 333.39s (0:05:33)`.

```text
pytest skip: 48 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=12 failed=0
```

main(`4261b35`, 문서만 변경)을 합친 `70c70bc`에서 전체 검사를 다시 실행했다(최종).

- 전체 백엔드 pytest: `2719 passed, 49 skipped, 3 warnings in 348.28s (0:05:48)`.
- skip 줄은 위와 같고, 결과는 `VERIFY result=PASS scope=all checks=12 failed=0`.

## 확인 범위

화면과 앱 코드는 변경하지 않았으므로 시뮬레이터·에뮬레이터 촬영은 하지 않았다.
Docker 기반 배포·운영자 복구 검사와 로컬 S3 endpoint가 필요한 검사는 위 skip에 포함된다.
원격 CI와 실제 운영 배포, 인스타그램 `/share/`의 실제 압축 응답, 운영 환경의 메모리 설정과 재시작은
이번 로컬 검증에 포함하지 않았다. 운영자 전용 수신 경로 등 이슈의 범위 밖 코드는 변경하지 않았다.
