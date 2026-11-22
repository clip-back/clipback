# 콘텐츠 저장 단계별 소요 시간 기록 (#458)

2026-11-22에 `be12e77`을 기준으로 구현했습니다. 첫 구현은 `d2546bb`, 검수 반영과 전체 검증의 기준은 `dd5d404`입니다.

## 변경

- 링크 정보 읽기, 인스타그램 공유 주소 풀기, 저장 시 카테고리 추천, 사진 OCR의 호출마다 INFO 수준의 `content_save_step` JSON 줄을 기록합니다. 필드는 `event`, `step`, `elapsed_seconds`, `status`, `failure_reason`입니다. 단조 시계로 잰 초를 소수 셋째 자리로 반올림하고, 호출을 생략하면 해당 줄도 생략합니다.
- 카테고리 추천은 AI 호출이 끝날 때 시간을 확정합니다. 추천 카테고리가 저장 전 재조회에서 사라지면 최종 `content_created` metadata와 같은 `uncategorized` / `error`를 기록합니다. 응답의 미분류와 이벤트의 추천 카테고리 ID를 보존합니다.
- 새 로그에는 URL·콘텐츠·태그·사용자 정보·예외 메시지·공급자 응답 원문을 담지 않습니다. 기존 OCR 오류 로그는 #458에서 범위 밖으로 정했습니다.
- README의 콘텐츠 저장 절에 로그 계약을 추가했습니다. 링크 정보 읽기와 공유 주소 풀기는 각각의 서비스에서 호출 시간, 로거, 422 변환 시점을 관리하며 공용 함수가 JSON 형식을 정합니다.

## 검증

- 구현 전 새 HTTP 계약 검사에서 로그가 필요한 17건이 실패했습니다. 검수 반영 전에는 일반 링크·공유 링크·사진 저장에서 전용 PostgreSQL의 추천 카테고리를 재조회 직전에 삭제했을 때 3건이 `ai` / `null`과 기대값의 차이로 실패했습니다.
- 검수 반영 후 부분 검사 334건과 변경 파일 Ruff가 통과했습니다. 재조회에 합성 시계로 5초를 더해도 AI 호출의 0.123초가 한 줄에 기록됐으며, 호출 생략과 분류·OCR 오류의 로그도 확인했습니다. 기존 저장 계약 테스트는 수정하지 않았습니다.
- 아래 네 변형을 각각 실행했을 때 새 HTTP 계약 검사 1건씩이 의도한 단언에서 실패했습니다. 변형은 매번 원복했습니다.

| 변형 | 실패 단언 |
| --- | --- |
| `failure_reason` 필드 삭제 | 키 집합이 다섯 필드와 일치 |
| `status`를 다른 값으로 변경 | 단계별 상태와 실패 사유가 기대값과 일치 |
| 링크 정보 읽기 호출 뒤에 측정 시작 | 관측된 0.000초 대신 기대하는 0.123초 기록 |
| 합성 제목 표식을 별도 INFO 로그로 출력 | 수집 로그와 표준 출력·오류에 표식이 없음 |

### 전체 로컬 검증

`git fetch origin` 뒤 `origin/main`은 `be12e77`이었으며, 깨끗한 `dd5d404`에서 전체 검사를 한 번 실행해 종료 코드 0을 확인했습니다. Flutter 테스트는 3,967건이 통과했습니다.

```text
pytest: 3054 passed, 50 skipped, 3 warnings in 401.91s (0:06:41)
pytest skip: 49 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=12 failed=0
```

테스트에는 가짜 공급자 응답을 사용했습니다. 원격 CI는 PR 승인 뒤 감독 단계입니다. 사진 저장 한 건과 일반 링크 저장 한 건의 Railway 로그는 배포 뒤 사용자가 읽기 전용으로 확인합니다.
