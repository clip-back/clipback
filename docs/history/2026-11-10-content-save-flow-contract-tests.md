# 콘텐츠 저장 재시도·실패 흐름 고정 테스트 (#321)

2026-11-09–10, 시작 커밋 `bd9047e`에서 기존 동작을 실제 실행으로 관측해 고정 테스트로 동결했다.
`git diff --quiet 906d253 bd9047e -- backend`로 backend가 상위 이슈 #320의 기준 코드 `906d253`과 같음을 확인했다.
상위 이슈 #320(콘텐츠 저장 재시도와 트랜잭션 책임 통합)의 첫 티켓이며, 앱 코드(`backend/app/`)·스키마·정책과 기존 테스트는 바꾸지 않았다.

## 관측 방법과 환경

- 로컬 PostgreSQL에 검사 전용 임시 DB를 만들어 `alembic upgrade head` 뒤 실행했다. 원본 저장소는 임시 폴더(local)와 moto S3 대역,
  메타데이터·AI·OCR은 기존 `external_responses` 대역이며 외부 HTTP는 차단된다. 운영 데이터·공급자 호출은 쓰지 않았다.
- 실행 명령: `cd backend && TEST_DATABASE_URL=<임시 DB> pytest -q tests/integration/test_content_save_flow_contract.py` (Python 3.12).
- 동결 절차: 기대값 표를 비운 채 실행해 실패 메시지의 관측 JSON을 그대로 표로 옮겼다. 손으로 값을 고치지 않았다.
  실패 분기는 local/S3 두 저장소의 관측이 모두 같아 한 표로 묶고 두 저장소에서 같은 표로 단언한다.
- 날짜·id는 존재·타입·형식을 단언한 뒤 자리표시자로 바꾼다. pydantic 오류 문서 URL은 `https://errors.pydantic.dev/<버전>/v/<type>` 형식을 단언한 뒤 버전을 바꾼다.
- 실패 주입은 아래 위치에만 건다. 저장 흐름의 내부 module 위치(라우트·`upload_service`·`content_service`·`share_receipt_*`)에는 묶지 않는다.

| 주입·관측 | 위치 | 쓰임 |
| --- | --- | --- |
| commit 거절·응답 유실·취소·연결 종료 | `AsyncSession.commit` (요청 세션의 첫 commit) | R13·R14·R16·R17·R18d·R24, 원자성 |
| rollback 완료·실패 | `AsyncSession.rollback` | 원 트랜잭션 종료 순서, R24 |
| 별도 연결 재확인 감지·실패 | `AsyncSession.execute`: 요청 세션이 아닌 세션의 `pg_advisory_xact_lock(` 실행(인자 = 제출 잠금 id) | 순서 검사, R16 |
| 원본 쓰기·삭제 실패 | `LocalStorageClient`·`S3StorageClient`의 `save_file`·`delete_file` | R18b·R18c, 원본 DELETE 실패 |
| 정리 helper 호출 수 | `cleanup_failed_upload` 함수 객체를 가리키는 `app.*` module의 모든 이름을 감싸 실제 helper를 실행 | R18a–R18d |
| 정리 작업 기록 실패 | `ImageDeletion`이 새로 들어간 세션의 commit | 정리 DB 실패 |
| 쓰기 뒤 실패 | `ImageUploadControl.observe`, `EventRepository.create`, 없는 카테고리 입력 | R18d |
| 원자성 | `share_receipts` INSERT를 실행한 연결의 commit 거절(SQLAlchemy `before_cursor_execute`) | 콘텐츠·기록 한 트랜잭션 |
| 제출 잠금 보유 확인 | 별도 NullPool 연결의 `pg_try_advisory_xact_lock` 후 즉시 rollback·종료 | 순서 검사 |

## 추가한 테스트

파일: `backend/tests/integration/test_content_save_flow_contract.py` (156개, 보조 파일 없음).

| 테스트 | 대상 | 사례 |
| --- | --- | --- |
| `test_upload_failure_branches_keep_original_cleanup_contract` | R18b·R18c·R18d·R16, 정리 DB/원본 DELETE 실패 | 15 실패 × 키 유무 × local/S3 = 60 |
| `test_pre_write_rejection_never_reaches_storage_or_cleanup` | R18a, R09·R10·R12 본문 | 손상·빈·과대 파일, 중단, 한도 × 키 유무 × local/S3 = 20 |
| `test_rejected_commit_ends_original_transaction_before_verification` | 원 트랜잭션 종료 → 재확인 → 정리 순서, R13 | 1 |
| `test_commit_failure_outside_normal_rollback_keeps_observed_branch` | R24 rollback 실패·연결 종료·서버 task 취소 | 6 |
| `test_replay_returns_current_content_and_keeps_conflict_and_deleted_bodies` | R03·R04·R05 경로별 | 3 |
| `test_receipts_are_written_only_for_keyed_saves` | 키 유무별 처리 기록 수, R07 | 3 |
| `test_fingerprint_input_variants_keep_replay_or_conflict` | fingerprint 변형 입력 | 25 |
| `test_one_key_cannot_cross_save_kinds` | 서로 다른 종류의 같은 키(R04)와 같은 종류 재사용(R02) | 9 |
| `test_screenshot_decision_order_for_overlapping_conditions` | 재사용·중단·한도·빈/손상 파일·키 충돌 순서 | 10 |
| `test_overlapping_pre_validation_errors_keep_http_result` | 복수 사전 오류(R07·R22·R24), 키 미소비 | 16 |
| `test_content_and_receipt_commit_together` | 콘텐츠와 처리 기록의 원자성 | 3 |

## R01–R24 대응

`기존`은 #320에 적힌 기존 테스트의 단언 범위, `보강`은 이번 파일의 동결 관측이다. 테스트 이름은 위 표의 함수와 사례 id다.

| ID | 대응 | 근거와 관측 |
| --- | --- | --- |
| R01 | 기존 + 보강 | `test_content_create_idempotency::test_same_key_replays_one_content_without_new_work`; 기록 종류·수는 `test_receipts_are_written_only_for_keyed_saves` |
| R02 | 기존 + 보강 | R01, `test_mobile_share`; 같은 종류 재사용은 `test_one_key_cannot_cross_save_kinds[<종류>-<종류>]` |
| R03 | 보강 | 즐겨찾기·태그·카테고리·열람·제목(DB 갱신) 변경 뒤 같은 키 재시도: 201, 응답 = 현재 `GET /contents/{id}`, 새 외부 호출·행 없음 |
| R04 | 기존 + 보강 | 409 `{"detail": "Idempotency key belongs to another input"}` 본문 전체를 세 경로와 종류 6조합에서 단언 |
| R05 | 기존 + 보강 | 410 `{"detail": "Previously saved content was deleted"}` 본문 전체를 세 경로에서 단언 |
| R06 | 기존 | `test_key_conflict_delete_and_user_isolation`, `test_mobile_share::test_receipt_replay_conflict_delete_and_user_isolation` |
| R07 | 기존 + 보강 | 스크린샷 잘못된 키 422 본문(`P06`), 키 없는 저장 두 번 = 콘텐츠 2·기록 0 |
| R08 | 기존 | `test_share_write_concurrency::test_concurrent_shares_serialize_before_external_work`·`test_concurrent_main_link_saves_with_one_key_keep_one_content` |
| R09 | 기존 + 보강 | 빈 파일 422 `Screenshot file cannot be empty`, 과대 413 `image_file_too_large` 본문 |
| R10 | 기존 + 보강 | 손상 이미지 415 `Unsupported or invalid screenshot image`; 순서 `O2`·`O8`·`O9` |
| R11 | 기존 + 보강 | `test_image_storage_controls::test_operator_pause_blocks_only_new_images_and_resume_allows_retry`; `O6` |
| R12 | 기존 + 보강 | 중단·한도 본문 전체; 둘 다 참이면 중단 우선(`O1`) |
| R13 | 기존 + 보강 | `D2`·`D4`(키 있음): 500, helper 1회, 정리 작업 1(완료), 실패 원본 삭제, 재시도 뒤 각 1; 순서 검사 |
| R14 | 기존 + 보강 | `D5-key`: 500, helper 0회, 정리 작업 0, 원본 보존, 재시도 201 같은 콘텐츠·원본 1 |
| R15 | 기존 | `test_retry_winning_before_commit_verification_cleans_only_failed_attempt` (변형 V10으로 실패 확인) |
| R16 | 보강 | `V1-key`·`V2-key`: 재확인 연결 실패 → 500, helper 0회, 정리 작업 0, 원본 보존 |
| R17 | 기존 + 보강 | `D5-nokey`: 500, helper 1회(참조 확인으로 반환), 정리 작업 0, 원본 보존, 기록 0 |
| R18a | 보강 | 쓰기 전 거절 10종: save_file 0, helper 0, 정리 작업 0, OCR 0, 새 원본·행 0, 같은 키 재시도 201 |
| R18b | 보강 | `B1`·`B2` |
| R18c | 보강 | `C1`–`C4` |
| R18d | 보강 | `D1`–`D7`, `V1`·`V2` |
| R19 | 기존 + 보강 | `test_image_deletion::test_failed_upload_original_cleanup_is_retried_after_storage_recovers`; `C4`·`D7`의 미완료 정리 작업 |
| R20 | 기존 + 보강 | `test_empty_ocr_photo_replay_preserves_original_and_default_content`; `FP03` |
| R21 | 기존 | `test_content_save_contract`의 모든 CASES |
| R22 | 기존 + 보강 | `test_mobile_share`; 인증 실패와 다른 오류가 겹치면 401(`P01`·`P03`·`P04`·`P07`) |
| R23 | 기존 | `test_pause_waits_for_admitted_save_then_retry_after_resume_has_one_original`, `test_main_and_native_concurrent_writes_cannot_overrun_remaining_space` |
| R24 | 보강 + 미확인 2 | 아래 R24 절 |

## 원본 쓰기 실패 관측값 (R18b–R18d, R16)

키 있음/없음, local/S3 모두에서 관측했다. `정리`는 해당 요청 storage_key의 `ImageDeletion` 행이다(삭제 성공 뒤에도 완료 행이 남는다).

| 사례 | 응답 | helper | 정리 작업 | 실패 시도 원본 | 같은 요청 재시도 |
| --- | --- | --- | --- | --- | --- |
| B1 save_file 일반 OSError(쓰기 전) | 500, OSError 전파 | 0 | 0 | 없음 | 201, 원본 1 |
| B2 일반 OSError(부분 바이트 쓴 뒤) | 500, OSError 전파 | 0 | 0 | 부분 바이트 잔존 | 201, 원본 2(부분 잔존) |
| C1 StorageUnavailableError(쓰기 전) | 503 `Image storage is temporarily unavailable` | 1 | 1 완료 | 없음 | 201 |
| C2 StorageUnavailableError(부분 쓰기 뒤) | 503 | 1 | 1 완료 | 삭제됨 | 201 |
| C3 C2 + 정리 작업 기록 commit 실패 | 503 | 1(예외) | 0 | 부분 잔존 | 201, 원본 2 |
| C4 C2 + 원본 DELETE 실패 | 503 | 1 | 1 미완료 `original_cleanup_unavailable` | 부분 잔존 | 201, 원본 2 |
| D1 전송 관측 실패 | 500, RuntimeError | 1 | 1 완료 | 삭제됨 | 201 |
| D2 이벤트 쓰기 실패 | 500, RuntimeError | 1 | 1 완료 | 삭제됨 | 201 |
| D3 없는 카테고리(쓰기 뒤 404) | 404 `Category not found` | 1 | 1 완료 | 삭제됨 | 같은 입력이라 다시 404 |
| D4 commit 거절 | 500, ConnectionError | 1 | 1 완료 | 삭제됨 | 201 |
| D5 commit 응답 유실(키 있음) | 500 | 0 | 0 | 보존(커밋됨) | 201 같은 콘텐츠, 원본 1 |
| D5 commit 응답 유실(키 없음) | 500 | 1(반환) | 0 | 보존(참조됨) | 201 새 콘텐츠, 원본 2 |
| D6 D2 + 정리 작업 기록 commit 실패 | 500 | 1(예외) | 0 | 잔존 | 201, 원본 2 |
| D7 D2 + 원본 DELETE 실패 | 500 | 1 | 1 미완료 | 잔존 | 201, 원본 2 |
| V1 commit 거절 + 재확인 실패(키 있음) | 500, 재확인 ConnectionError | 0 | 0 | 보존 | 201, 원본 2 |
| V2 응답 유실 + 재확인 실패(키 있음) | 500 | 0 | 0 | 보존 | 201 같은 콘텐츠, 원본 1 |

키 없는 V1·V2는 재확인을 하지 않아 각각 D4·D5 키 없음과 같다. 일반 OSError(B1·B2)는 helper·정리 작업이 없고 부분 원본을 남기는 기존 동작으로 동결했다.

## 원 트랜잭션 종료 순서와 R24

정상 rollback 가능한 commit 거절(키 있음)의 사건 순서는 아래와 같고, 실패 요청과 같은 키 재시도가 각각 10초 안에 끝난다.

`commit_attempted:lock_held` → `original_rollback_done:lock_free` → `verification_lock_requested` → `verification_lock_acquired` →
`cleanup_entered` → `original_rollback_done:lock_free`(helper의 rollback)

| 사례 | 관측 |
| --- | --- |
| rollback이 실제 rollback 뒤 예외(키 있음) | 같은 순서로 재확인·정리, 500(RuntimeError), 정리 작업 1 완료, 재시도 201 |
| 같은 사례 키 없음 | 재확인 없이 helper 정리, 500 |
| commit 직전 원 backend 종료(키 있음/없음) | rollback은 예외 없이 끝나고 잠금 해제, 키 있으면 재확인 뒤 정리, 500(InternalError) |
| 서버 task 안 CancelledError(키 있음/없음) | rollback·재확인·helper 없음, 원본 잔존(정리 작업 0), 세션 종료로 잠금 해제, 재시도 201·원본 2 |

미확인 2건:

- rollback이 서버 트랜잭션을 끝내지 못한 채 예외를 내는 경우: 임시 탐색에서 재확인이 원 연결의 제출 잠금을 기다려 요청이 10초 안에 끝나지 않았다
  (`commit_attempted:lock_held` → `original_rollback_raised:RuntimeError` → `verification_lock_requested`에서 멈춤).
  인위 주입으로만 재현되며, 새 복구 동작이나 기대값을 정하지 않고 동결을 보류했다.
- 클라이언트 HTTP 대기 시간 초과: 시험 transport(`httpx.ASGITransport`)는 요청을 같은 task에서 실행해 클라이언트 취소가 곧 서버 취소가 된다.
  서버 task 취소와 같다고 가정하지 않고 미확인으로 남긴다.

## 순서 조합과 fingerprint 변형

| #320 순서 입력 | 사례 | 관측 |
| --- | --- | --- |
| 완료 키 + 저장 중단 | `O6` | 201 같은 콘텐츠 |
| 새 이미지 + 중단 + 한도 초과 | `O1` | 409 `image_uploads_paused` |
| 다른 입력에 쓴 키 + 손상 이미지 | `O2` | 409 키 충돌(415 아님) |
| 쓴 키 + 빈/과대 파일 | `O3`·`O4` | 422 / 413 |
| 완료 키 + 한도 초과 | `O5` | 201 같은 콘텐츠 |
| 완료 키 + 중단 + 콘텐츠 삭제 | `O7` | 410 |
| 새 손상 이미지 + 중단 / 한도 | `O8`·`O9` | 415 |
| 다른 입력 키 + 중단 + 한도 | `O10` | 409 키 충돌 |

모든 조합에서 OCR·새 원본·새 행은 0이다. 같은 키 동시 저장(R08)과 commit 성공 뒤 응답 유실(R14·R17), T4 두 단계 자르기(R21)는 기존 테스트로 확인한다.

fingerprint 변형(같은 키로 두 번째 요청):

- 같은 콘텐츠 201: 링크 기본값 생략/명시(`FL01`), HttpUrl 정규화로 같은 URL(`FL02`), 카테고리 숫자 문자열(`FL04`), 태그 선행 `#`·전각 `＃`·전각 문자·탭·NBSP·줄바꿈·casefold 중복(`FL06`–`FL10`),
  즐겨찾기 `"yes"`(`FL12`), 공유 기본값 생략/명시(`FS01`), 공유 태그 `#`(`FS06`), 스크린샷 파일명·MIME 주장만 변경(`FP01`), 스크린샷 태그 `#`·casefold 중복(`FP05`·`FP06`).
- 409 키 충돌: 카테고리 순서(`FL03`·`FS05`·`FP04`), 카테고리 중복(`FL05`), 태그 표시 대소문자(`FL11`), 빈 제목과 null(`FL13`), 공유 URL 앞뒤 공백(`FS02`),
  공유 글 차이(`FS03`), 같은 대상의 url/raw_text(`FS04`), 마지막 바이트 변경(`FP02`), 같은 바이트 + 다른 카테고리(`FP03`).
- 사전 오류는 키를 쓰지 않는다: 잘못된 태그(`""`·`None`·숫자)·카테고리(`None`·`"abc"`) 422 뒤 같은 키의 올바른 입력은 201(`P11`–`P16`).
  잘못된 키와 다른 요청 오류가 함께면 헤더·본문 오류를 한 목록으로 돌려주고(`P02`·`P05`·`P08`), 스크린샷 빈 파일·빈 태그는 키 오류만 보인다(`P09`·`P10`).

## 직접 호출 세 사례 동결과 이관 대응

`backend/tests/services/test_content_save_baseline.py`의 세 테스트는 바꾸지 않았다. #320의 대응표대로 후속 구조 이동 티켓은 아래만 바꿀 수 있다.

- 20–26행 import: 새 흐름 import 추가만. 기존 `ContentService`·`SharedLinkContext` import 유지.
- 119–131행 `build_service`: 같은 `contents.session`을 쓰는 새 흐름을 조립해 반환하는 부분만.
- 139·157·179행의 `service.save_link(...)`: 호출 수신자와 준비된 링크 내부 진입점 이름만. 인자(`user_id`·`payload`·`share=SharedLinkContext(...)`)는 그대로.
- 제목·요약이 있는 공유 준비 입력을 `ContentShareCreate`로 재생성하지 않고, 2048자 초과 URL의 `model_copy` 객체를 HTTP schema로 재검증하지 않는다.
  FakeSession·입력·기대값·`committed` 단언·이름·docstring은 바꾸지 않는다.

## 동결 파일과 후속 구조 이동 티켓의 허용 수정

| 파일 | SHA-256 | 허용 수정 |
| --- | --- | --- |
| `backend/tests/integration/test_content_save_flow_contract.py` | `b6494e75993dad1352fd2e27038f438acb6f3d26a1db5298814717264e06a7ba` | 없음. 아래 결합 조건이 깨지면 고치지 말고 보고 |
| `backend/tests/integration/test_content_save_contract.py` | `87fddf6d1b6742a88984f512db97923fe63b0f1050da69151daee638822e2d75` | 없음(#278 제한 유지) |
| `backend/tests/services/test_content_save_baseline.py` | `79bf908b886ee1ac9e7f5dfec4dcedd12ababa47c5db6da55a70c3a24829f6e0` | 위 절의 import·`build_service`·호출 줄 |
| `backend/tests/integration/test_content_create_idempotency.py` | `328e769bb2e2852a01e3414f6f0fd88679ddc0ba5c915d9d6bbada5e41bca628` | 없음 |
| `backend/tests/integration/test_share_write_concurrency.py` | `3af5ee01dbedeb36645166e972b56db9bae9b1a3a3adf25748046d46984b2f28` | `ShareReceiptRepository.lock`·`committed_after_failure`가 다른 곳으로 옮겨질 때만 24행 import, 74·83행 `lock` 감싸기, 295·311행 `committed_after_failure` 감싸기의 대상 이름. barrier·관측값·기대값 불변 |
| `backend/tests/integration/test_mobile_share.py` | `83bd35daad84c33c4d270d0162dd99db7ec36e63e77bfb2e6f479adc78102032` | 없음 |
| `backend/tests/integration/test_image_quota.py` | `e78a8b9e5c708273f832d814fffe16c170cc70b5a75fc18eeb399dc9d8f0c463` | 없음 |
| `backend/tests/integration/test_image_storage_controls.py` | `7fcfd2db7e1e5e33fa9fdb5c317f4c23f01ffe022feacf9449c0886ee675ec84` | 없음 |
| `backend/tests/integration/test_image_deletion.py` | `bfe2e2d6dfa9bb165331b8f42c01392fab239b0b51e4c957fe7dfb130a908aa1` | 없음 |
| `backend/tests/integration/test_upload_and_isolation.py` | `c980a722f68bcf17afd99bfd17a9a959630c58448f69a7fdc2c8e9fb6dc8b834` | 없음 |

새 파일이 구조 이동 뒤에도 같은 결과를 내려면 다음 조건이 유지되어야 한다. 바뀌면 테스트를 고치지 않고 보고한다.

- 저장 요청은 `get_db` 세션 하나에서 진행하고, 콘텐츠 저장 commit이 그 세션의 첫 commit이다.
- 커밋 실패 재확인은 새 `AsyncSession`에서 `AsyncSession.execute`로 `pg_advisory_xact_lock(...)`을 같은 잠금 id로 실행한다(잠금 키 계산 불변).
- 정리 helper는 `app.services.image_deletion_service.cleanup_failed_upload` 함수 객체를 module 이름으로 불러 쓴다.

## 변형 실험

변형은 제품 파일을 임시 사본으로 남긴 뒤 한 곳만 바꿔 지정 테스트를 돌리고, 사본으로 되돌려 `git diff --quiet -- backend/app`을 확인했다. 테스트는 바꾸지 않았다.

| 변형 | 바꾼 곳 | 실패한 고정 테스트 |
| --- | --- | --- |
| V01 재사용 요청에서 OCR 다시 실행 | `upload_service` 키 확인 앞에 OCR | 재시도 현재 콘텐츠[screenshot], fingerprint `FP01`–`FP06` |
| V02 재사용 요청에서 콘텐츠·이벤트 다시 저장 | 일반 링크 라우트 재사용 분기 | `test_same_key_replays_one_content_without_new_work`, 재시도 현재 콘텐츠[content], 종류 충돌 `content-*` |
| V03 응답 필드 삭제 | `ContentRead.last_viewed_at` 제거 | `test_content_save_contract` 성공 행 40개, 재시도 현재 콘텐츠 3개 |
| V04 자동 요약 플래그 변경 | `apply_title=True` | `test_content_save_contract[L10·L11b·L14]` |
| V05 두 단계 metadata 자르기를 한 단계로 | 추출 metadata 직렬화의 자르기 생략 | `test_content_save_contract[T4]` |
| V06 재사용보다 저장 중단 검사 먼저 | 키 확인 앞에 중단 검사 | `test_image_storage_controls` 2개, 순서 `O6`·`O7`·`O8`·`O10` |
| V07 키 충돌보다 손상 이미지 검사 먼저 | 키 확인 앞에 형식 검사 | 순서 `O2` |
| V08 일반 OSError에 정리 helper 추가 | `save_file`의 `except OSError` 정리 | 원본 쓰기 실패 `B1`·`B2` 8개 |
| V09 커밋된 원본 삭제 | 재확인 결과 커밋이면 원본 삭제 | `test_screenshot_retry_and_cleanup_follow_actual_commit[commit_ack_lost-*]`, `D5-key-*` |
| V10 다른 재시도 성공만으로 실패 원본 보존 | 재확인이 기록 존재만 비교 | `test_retry_winning_before_commit_verification_cleans_only_failed_attempt` |
| V11 콘텐츠와 처리 기록을 다른 트랜잭션으로 | 기록 추가 전 commit | 원자성 3개 |
| V12 원 rollback 전에 별도 연결 재확인 | 저장 실패 시 rollback 생략 | 순서 검사: `commit_attempted:lock_held` → `verification_lock_requested`에서 10초 제한 초과 |
| V13 최종 commit 누락 | 저장 commit 삭제 | `test_content_save_baseline`의 commit 단언 2개 |

V01·V07 실행 때 fingerprint 사례 id는 번호(`[19]`–`[24]`)였고, 같은 사례를 이후 `FP01`–`FP06` 이름으로 바꿨다(입력·기대값 동일).
변형 뒤 매번 `git diff --quiet -- backend/app`이 깨끗했다.

## 검사 범위와 CI 대조

- 바꾼 파일은 `backend/tests/integration/test_content_save_flow_contract.py`(새 파일)와 이 문서·이력 목차다.
  `backend-validation.yml`의 `deployment` 필터(`backend/**`) 대상이고 `operator_recovery` 필터 목록에는 해당하지 않는다.
  Docker deployment 검사는 CI에서만 돈다.
