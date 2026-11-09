# 콘텐츠 저장 재시도·확정·원본 정리 판단을 저장 흐름 module로 이동 (#322)

2026-11-10, 시작 커밋 `4904464`. 상위 이슈 #320, [ADR 0010](../adr/0010-content-save-transaction-ownership.md)의 구현이다.
동작을 보존하는 리팩터링이며 사용자 기능·API 요청/응답·오류·DB 스키마·앱 동작은 바꾸지 않았다.
#321에서 동결한 고정 테스트([고정 테스트 기록](2026-11-10-content-save-flow-contract-tests.md))로 기준 `906d253`과 변경 후를 비교했다.

## 바꾼 구조

새 파일 `backend/app/services/content_save_flow.py`의 `ContentSaveFlow`가 세 저장 경로의 다음 일을 맡는다.

- 제출 키(`Idempotency-Key`)의 계정·키 잠금, 기존 처리 기록 확인(현재 콘텐츠 재조회·다른 입력 409·삭제된 콘텐츠 410)
- 콘텐츠·이벤트·요약 작업·원본 자산·관측 기록·처리 기록을 담은 저장 트랜잭션의 최종 commit/rollback
- 스크린샷 실패 원본의 정리 판단: 저장소 일시 장애(`StorageUnavailableError`)는 정리 뒤 503, 쓰기 뒤 실패는
  원 트랜잭션 rollback → (커밋을 시도한 키 있는 요청만) 별도 연결 재확인 → 필요 시 정리

| 진입점 | 호출자 | 하는 일 |
| --- | --- | --- |
| `save_link` | `POST /api/v1/contents` | 키 확인 뒤 `save_prepared_link` |
| `save_shared_link` | `POST /api/v1/contents/share` | 원래 공유 입력으로 키 확인 → `ShareIntakeService.prepare_link`(URL 해석) → `save_prepared_link` |
| `save_prepared_link` | 위 두 진입점 | 준비된 `ContentCreate`와 선택적 `SharedLinkContext`를 다시 검증하지 않고 저장·확정 |
| `save_screenshot` | `POST /api/v1/uploads/screenshots` | 파일 읽기 → 키 확인 → 형식·중단·한도·OCR → 원본 쓰기 → 관측 → `save_prepared_screenshot` |
| `save_prepared_screenshot` | `save_screenshot` | 저장한 원본·OCR 결과를 그대로 받아 저장·확정 |

기존 module은 준비와 반영만 한다.

- `content_service.py`: `save_link`/`save_screenshot`/`_save`를 `prepare_link`/`prepare_screenshot`(기존 try 앞의 정규화·URL 길이 검사·카테고리 결정·metadata 조립)과
  `write`(기존 try 안의 태그·콘텐츠·요약 작업·자산·이벤트·응답 구성, commit 없음)로 나눴다. 준비 단계 실패에는 지금처럼 rollback을 하지 않는다.
  콘텐츠 수정·삭제·열람 기록의 commit/rollback은 그대로 있다.
- `share_intake_service.py`: 키 처리와 저장 호출을 빼고 `prepare_link(payload)`가 (`ContentCreate`, `SharedLinkContext`)를 돌려준다. URL 선택·정규화·리다이렉트 해석은 그대로다.
- `upload_service.py`: `upload_screenshot`을 `read_screenshot`·`prepare_original`·`save_original`·`observe_saved_original`·`asset_for`로 나눴다. 정리 helper 호출은 흐름으로 옮겼다.
- `share_receipt_service.py`는 흐름에 합쳐 지웠다(`share_fingerprint`도 흐름으로 이동, 계산 불변).
  `PendingShareReceipt.commit_attempted`를 없애고 커밋 시도 여부는 흐름 내부 `_Submission`이 가진다.
  `ShareReceiptRepository.lock`·`committed_after_failure`의 SQL과 서명은 그대로다.
- 정리 실패·재확인 실패 로그 문구는 그대로이고 logger 이름만 `app.services.upload_service`에서 `app.services.content_save_flow`로 바뀌었다.

## 구조 확인

검색 결과(`.utmp` 작업 로그 기준, 명령은 #322 이슈의 제거 검색):

- `commit_attempted`·`committed_after_failure` 해석과 저장 commit/rollback은 `content_save_flow.py`에만 있다. 라우트·공유 접수·업로드에는 없다.
- `content_service.py`에 남은 `session.commit()`은 `update_favorite`·`delete_content`·`update_categories`(2곳)·`update_tags`·`record_view`다.
- import 방향: `content_save_flow` → `content_service`·`share_intake_service`·`upload_service`·`share_receipt_repository`·`image_deletion_service`.
  `share_intake_service`·`upload_service`는 `content_service`의 자료형(`SharedLinkContext`·`PendingContentAsset`)만 쓰고 흐름을 부르지 않아 순환이 없다.
- 실제 공유 접수는 `save_shared_link` → `save_prepared_link`를 한 번 거치며, 잠금·fingerprint는 URL 해석 전 원래 공유 입력으로 한 번만 수행한다.
  실제 업로드는 `save_screenshot` → `save_prepared_screenshot`을 거친다.

## 테스트 연결 변경

동결 파일 9개(`test_content_save_flow_contract.py` 등)는 바꾸지 않았다(SHA-256이 #321 기록과 같음).
아래 변경은 import·호출 수신자·fixture 연결뿐이며 테스트 이름·docstring·입력·기대값·단언은 바꾸지 않았다(변경 줄에 `assert`·`def test_`·docstring 0줄).

| 파일 | 변경 | 근거 |
| --- | --- | --- |
| `tests/services/test_content_save_baseline.py` | import 1줄, `build_service`가 `ContentSaveFlow(ContentService(...))` 반환, 호출 3줄 `save_link` → `save_prepared_link` | #320·#322의 허용 수정 |
| `tests/services/test_content_service.py` | 저장 호출 25줄을 `ContentSaveFlow(service).save_prepared_link`/`save_prepared_screenshot`으로, import 1줄 | 2026-11-10 사용자 결정 "추천대로" |
| `tests/services/test_share_intake_service.py` | `ContentSaveFlow(..., share_intake=ShareIntakeService(...)).save_shared_link` 경유, 가짜 콘텐츠 서비스의 기록을 `prepare_link`/`write`로 나누고 무동작 세션 연결 | 같은 결정(실제 흐름 경유 안) |
| `tests/services/test_upload_service.py` | `UploadService` 생성자의 `content_service` 인자 제거, 업로드 호출 7곳을 `ContentSaveFlow(content_service, uploads=service).save_screenshot`으로, 가짜의 기록을 `prepare_screenshot`/`write`로 나누고 무동작 세션 연결 | 같은 결정 |
| `tests/api/test_contents.py` | 가짜 콘텐츠 서비스의 보강·기록을 `prepare_link`/`write`로 나누고 무동작 세션 연결(라우트가 실제 흐름 경유) | 같은 결정 |
| `tests/api/test_uploads.py` | 업로드 라우트 사례 2곳의 monkeypatch 대상 `_build_upload_service` → `_build_save_flow`, 가짜 메서드 이름 `save_screenshot` | 같은 결정 |

## 기준과 변경 후 비교

기준은 `git worktree add --detach .utmp/ticket-322/wt-906d253 906d253`(HEAD `906d2538d045bc2e1f1a81c3588dde8c6a9f1c3a`)으로 만든 격리 워크트리이며,
`906d253`에 없는 동결 새 파일 `test_content_save_flow_contract.py` 하나만 복사했다(10개 파일 SHA-256이 #321 기록과 같음). 비교 뒤 `git worktree remove`로 지웠다.
두 트리를 같은 venv(Python 3.12)·같은 환경 변수·검사 전용 임시 DB(로컬 PostgreSQL, 실행마다 생성·삭제)·같은 인자로 실행했다.

```sh
pytest -q -rA -p no:cacheprovider tests/integration/test_content_save_flow_contract.py \
  tests/integration/test_content_save_contract.py tests/services/test_content_save_baseline.py \
  tests/integration/test_content_create_idempotency.py tests/integration/test_share_write_concurrency.py \
  tests/integration/test_mobile_share.py tests/integration/test_image_quota.py \
  tests/integration/test_image_storage_controls.py tests/integration/test_image_deletion.py \
  tests/integration/test_upload_and_isolation.py
```

| 실행 | 기준 `906d253` 워크트리 | 변경 후 |
| --- | --- | --- |
| 1차 | 1 failed, 316 passed | 317 passed |
| 2차 | 317 passed | 317 passed |

2차는 테스트 ID 317개와 결과가 두 트리에서 같고, 변경 후 1·2차도 서로 같다.
직접 호출 세 사례(`test_content_save_baseline.py`)는 기준에서는 `ContentService.save_link`, 변경 후에는 `ContentSaveFlow.save_prepared_link`로 같은 입력·단언을 실행해 통과했다.

1차 기준의 실패는 `test_upload_and_isolation.py::test_bucket_readiness_checks_selected_store_without_writing_local_volume`(준비 상태 503)이다.
이 검사는 3초 제한 안에 DB·S3 대역을 확인하며 바꾼 코드를 거치지 않는다. 같은 파일 단독 실행은 기준·변경 후 각 5회 모두 통과했다.
비교 전에 쓴 `git archive` 사본 실행에서도 첫 묶음에서 같은 1건이 실패하고 재실행에서 통과했다(이 사본 결과는 기준 비교 근거로 쓰지 않는다).
원인은 확인하지 않았고 기준 묶음 실행에서만 간헐적으로 관측됐다.

서비스·API 단위 테스트(`pytest -q tests/services tests/api`, DB 없음): 441 passed. 변경 전 연결 상태에서는 60 failed, 381 passed였다.

## 변형 실험

변경 후 코드에 한 번에 하나씩 규칙 위반을 넣고 지정 고정 테스트를 돌린 뒤 되돌렸다. 되돌린 뒤 매번 `backend/app` 모든 파일의 SHA-256이 변형 전과 같았다. 테스트는 바꾸지 않았다.

| 변형 | 바꾼 곳 | 실패한 고정 테스트 |
| --- | --- | --- |
| V01 재사용 요청에서 OCR 다시 실행 | 흐름: 키 확인 앞 OCR | 재시도 현재 콘텐츠[screenshot], fingerprint `FP01`–`FP06` |
| V02 재사용 요청에서 콘텐츠 다시 저장 | 흐름: 일반 링크 재사용 분기 | `test_same_key_replays_one_content_without_new_work`, 재시도 현재 콘텐츠[content], 종류 충돌 `content-*` |
| V03 응답 필드 삭제 | `ContentRead.last_viewed_at` | `test_content_save_contract` 40개, 재시도 현재 콘텐츠 3개 |
| V04 자동 요약 플래그 변경 | `write`의 `apply_title=True` | `test_content_save_contract[L10·L11b·L14]` |
| V05 metadata 자르기 한 단계로 | 추출 metadata 직렬화 | `test_content_save_contract[T4]` |
| V06 재사용보다 저장 중단 검사 먼저 | 흐름: 키 확인 앞 중단 검사 | `test_image_storage_controls` 2개, 순서 `O6`·`O7`·`O8`·`O10` |
| V07 키 충돌보다 형식 검사 먼저 | 흐름: 키 확인 앞 형식 검사 | 순서 `O2` |
| V08 일반 OSError에 정리 추가 | 흐름: `save_original`의 `except OSError` 정리 | 원본 쓰기 실패 `B1`·`B2` 8개 |
| V09 커밋된 원본 삭제 | 흐름: 재확인 결과 커밋이면 삭제 | `test_screenshot_retry_and_cleanup_follow_actual_commit[commit_ack_lost-*]`, `D5-key-*` |
| V10 다른 재시도 성공만으로 실패 원본 보존 | 재확인이 기록 존재만 비교 | `test_retry_winning_before_commit_verification_cleans_only_failed_attempt` |
| V11 콘텐츠와 처리 기록 분리 커밋 | 흐름 `_commit`: 기록 추가 전 commit | 원자성 3개 |
| V12 원 rollback 전에 재확인 | 흐름 `_commit`: 실패 시 rollback 생략 | 순서 검사: `commit_attempted:lock_held` → `verification_lock_requested`에서 10초 제한 초과 |
| V13 최종 commit 누락 | 흐름 `_commit`: commit 삭제 | `test_content_save_baseline`의 commit 단언 2개 |
| V14 재확인 전 원 세션 종료 | 흐름: 재확인 전 `session.close()` | rollback 미완료 동결 검사(10초 안에 끝나 실패) |
| V15 제출 잠금 제거 | `ShareReceiptRepository.begin`의 잠금 | 실제 서버 `content-`·`screenshot-while_server_running` |
| V16 준비된 링크 입력 재검증 | `save_prepared_link`에서 `ContentCreate.model_validate` | `test_url_from_unvalidated_copy_is_rechecked_after_normalization` |
| V17 공유 준비 맥락 손실 | `save_shared_link`가 `share=None` 전달 | `test_content_save_contract`의 공유 사례 12개(`S*`·`SH*`·`T2`–`T4`) |
| V18 공유 fingerprint를 준비된 입력으로 계산 | 흐름: URL 해석 뒤 준비된 입력으로 키 확인 | fingerprint `FS02`–`FS04` |

V18에서 함께 돌린 `test_concurrent_shares_serialize_before_external_work`(3개)는 통과했다. 이 변형은 링크 정보 보강보다 잠금이 앞서는 순서를 바꾸지 않기 때문이며, fingerprint 고정 테스트가 실패를 잡았다.

## 검사 범위와 CI 대조

- 바꾼 파일은 `backend/app`의 서비스 5개(새 파일 1개·삭제 1개 포함)·라우트 2개·`share_receipt_repository.py`, 위 테스트 6개, `backend/README.md`, 이 문서와 이력 목차다.
  `backend-validation.yml`의 `deployment` 필터(`backend/**`) 대상이며 `operator_recovery` 필터 목록에 해당하는 파일은 없다.
- 위 결과는 부분 검사다. 저장소 전체 검사·`deptry`·원격 CI는 리뷰 반영 뒤 수행한다.
