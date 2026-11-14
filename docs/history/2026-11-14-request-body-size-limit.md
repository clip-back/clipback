# 서버 요청 본문 크기 상한 (#361)

2026-11-14, 브랜치 `fix/request-size-limit`. 시작 커밋 `84ff8b0`. 스펙은 이슈 #361.

구현 커밋 `bcba5ec`(최종 전체 검증 기준). 이 문서를 더한 커밋은 문서만 바꾼다.

## 구현

- `backend/app/middleware/body_size_limit.py`의 원시 ASGI 미들웨어를 `create_app`의 맨 바깥에 둔다.
  점검 모드 입장(DB 사용)보다 먼저 상한을 본다.
- 경로가 정확히 `/api/v1/uploads/screenshots`이면 `SCREENSHOT_MAX_BYTES` + 1MiB(기본 11MiB), 그 밖은 1MiB. 메서드와 관계없다.
- Content-Length가 상한을 넘으면 본문을 읽지 않고 413을 준다. 그 밖에는 앱이 읽는 본문을 세다가 넘는 순간 413을 준다.
  - 본문을 읽지 않는 응답(health, 404, 405, 점검 503)은 Content-Length가 없으면 지금과 같다. 점검 중에도 413이 되는 것은 Content-Length 초과뿐이다.
  - 맨 바깥이라 Content-Length 초과 413에는 CORS 헤더가 없다. 앱은 모바일만 쓴다.
- 413 본문: 사진 저장은 기존 `image_file_too_large`(`limit_bytes` 10485760), 그 밖은 새 `request_body_too_large`(`limit_bytes` 1048576).
- 새 환경 변수는 없다. 앱(`frontend/`)과 운영자 앱은 바꾸지 않았다.

## 숫자가 아닌 Content-Length (로컬 실측)

uvicorn 0.54.0(httptools 0.9.0, h11 0.16.0)으로 변경 전 앱을 띄워 확인했다.

- `abc`, `-1`, `1e3`, `+5`, `0x10`, 빈 값: 두 파서 모두 앱 전에 `400 Invalid HTTP request received.`
- 앞뒤 공백이 붙은 숫자: 앱까지 오고 숫자로 읽힌다.
- 같은 머리 두 줄·`5, 5`: httptools는 400, h11은 값 하나로 합쳐 넘긴다.

그래서 앱 쪽 400 처리는 두지 않았다.

## 테스트

새 파일 `backend/tests/api/test_request_body_limit.py`만 더했고 기존 테스트는 바꾸지 않았다.
실제 `create_app()`에 원시 ASGI 요청을 넣고, 응답과 앱이 읽은 본문 양만 본다.

- 두 경로에서 Content-Length 상한 + 1 → 413, 읽은 양 0. Content-Length 없는 초과 → 413, 읽은 양은 상한 + 한 조각 이하.
- 정확히 상한은 인증 단계(401)까지 가고, 상한 + 1은 413(길이 있음·없음 각각).
- 앱 최대 업로드(10MiB 파일, 카테고리 20개, 태그 10개 × 40자)와 가장 긴 JSON 필드 묶음이 상한 단계를 지나간다.
- 업로드 상한은 정확한 경로에만, 메서드와 관계없이 적용된다. `/api/v1/health`는 같다.

## 검증

- 리뷰 전 부분 검사: 미들웨어를 연결하지 않은 상태에서 새 테스트 9 failed, 7 passed(통과한 7건은 바뀌지 않아야 하는 경우). 구현 뒤 새 테스트 16 passed, 관련 API 66 passed, 기존 413 고정 테스트를 포함한 통합·서비스 묶음 238 passed(skip 0). `ruff`, `deptry`, `compileall` 통과.
- 리뷰: Standards 0건, Spec 0건. 고친 코드는 없고, 계약 문서에 본문을 읽지 않는 응답은 같다는 설명만 더했다.
- 최종 전체 검증(`bcba5ec`, 깨끗한 작업 트리):

```text
pytest: 2656 passed, 49 skipped, 3 warnings in 331.79s (0:05:31)
pytest skip: 48 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=11 failed=0
```

- `git diff --stat main -- frontend` 비어 있음.
- 미검증: Docker deployment·operator-recovery는 로컬에서 돌리지 않았다(원격 CI에서 확인).
  Railway 앞단을 거친 413 수신과 운영 저장 확인은 배포 뒤 확인 항목이다.

## PR 생성 전 main 반영

최신 main의 배포 기록 `d529d00`을 `ef836bc`로 병합했다. 변경은 배포 문서와 CHANGELOG뿐이며, 병합 때 되살아난 이미 배포된 항목의 중복을 정리했다. 최종 CHANGELOG 차이는 미배포의 #361 한 줄이다.

`bcba5ec`와 병합 후의 `backend/`, `frontend/`, `.github/` diff가 비어 있어 전체 검증 근거는 위 실행을 유지한다. 사용자 지시에 따라 변경된 문서 범위의 경로·내용과 `git diff --check`를 확인했다. 원격 CI 결과는 PR에서 별도로 확인한다.

## #360 병합 뒤 충돌 해소

main의 스낵바 수정 `de1eb1c`를 `0c889e9`로 병합했다. CHANGELOG의 #361 항목이 앱 배포 절에 놓인 것을 바로잡아, main 내용은 보존하고 `미배포`의 `개선`에 이 항목만 더했다. main 대비 프론트 diff는 없고 서버 코드는 직전 PR head와 같다.

공용 검사 차례를 기다린 뒤 `flutter analyze --no-pub`와 변경 범위의 `contact_form_root_test.dart`, `my_legal_links_root_test.dart`, `snackbar_font_root_test.dart`, `snackbar_stack_root_test.dart`를 실행했다. 분석 문제 없음, 테스트 22개 통과, 종료 코드 0이다. 전체 검사를 다시 실행한 결과는 아니며, 문서·공백 검사도 통과했다.

CI 대기 중 main에 #368(`617aa21`)이 추가되어 `a4241f9`로 병합했다. CHANGELOG는 main을 보존하고 미배포의 #361 항목만 추가된 상태임을 다시 확인했다. 공용 검사 차례 뒤 `flutter analyze --no-pub`와 `category_content_alignment_test.dart`, `home_alignment_test.dart`, `uncategorized_name_test.dart`, `unclassified_alignment_test.dart`, `weekly_root_test.dart`를 실행해 분석 문제 없음·237개 통과·종료 코드 0을 확인했다. main 대비 diff는 계속 #361의 7개 파일뿐이다.
