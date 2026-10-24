# 기존 원본의 Bucket 이관

`backend/scripts/image_migration.py`는 기존 `local` 원본을 같은 불변 키로 비공개 S3 호환 Bucket에
복사하고, 원본 바이트를 확인한 자산 하나씩 DB의 보관 위치를 바꾸는 운영자 도구입니다.
콘텐츠·자산·사용자 ID를 새로 만들거나 원본을 변환하지 않습니다. 기존 한도 초과 자료도 지우지
않으며, 합계는 같은 원본의 실제 크기로 유지됩니다. 운영 이관 실행은 별도 배포 작업입니다.

## 사전 준비와 변경 없는 검사

먼저 local/S3 혼합 조회·삭제·백업을 지원하는 현재 백엔드와 스키마를 배포하고, 원본과 독립 삭제
기록의 실제 운영 설정을 확인합니다. `STORAGE_ROOT`는 API와 같은 실제 원본 디렉터리입니다.
S3 원본 설정과 독립 삭제 기록 설정은 API와 동일하게 지정하고 백업 자격은 API에 넣지 않습니다.

`backend/`에서 다음 명령으로 DB가 참조하는 모든 원본의 현재 위치·실제 크기·SHA-256과 알려진
DB 메타데이터를 대조합니다. NULL 크기·해시는 이 단계에서 쓰지 않습니다. 결과는 자산 ID·
backend·상태·건수만 포함하며 원본 바이트·파일 키·URL·자격·사용자 ID를 출력하지 않습니다.

```sh
YOUTUBE_SUMMARY_ENABLED=false .venv/bin/python -m scripts.image_migration inspect
```

`ready`는 읽을 수 있는 local 원본, `already_migrated`는 검증된 S3 원본입니다.
`original_missing`, `original_unavailable`, `original_metadata_mismatch`가 있으면 명령은 nonzero를
반환합니다. 잘못된 자산을 자동 수정하거나 참조 없는 파일을 찾아 삭제하지 않습니다.

## 백업과 실제 복원 검증

[DB·원본 백업 및 최신 삭제 반영 복원 검사](backup-recovery.md)에 따라 v2 복구 지점을 만들고
새 비공개 폴더로 materialize합니다. 최신 삭제를 반영하는 `restore-check`를 **실제 격리 실행**한
성공 JSON을 저장합니다. 기본 `check_backup_restore`의 삭제 미반영 성공만으로는 진행할 수 없습니다.

```sh
YOUTUBE_SUMMARY_ENABLED=false .venv/bin/python -m scripts.image_backup_jobs restore-check \
  --backup-dir /absolute/private/MATERIALIZED_BACKUP \
  --credentials-file /absolute/private/restore-credentials.json \
  --image LOCAL_COMPATIBLE_API_IMAGE --writers-frozen \
  > /absolute/private/restore-report.json
```

`--writers-frozen`은 검사 동안 원본의 실제 쓰기 중지에 대한 운영자 확인입니다. 도구는 쓰기를
중지하지 않습니다. 복원 검사 뒤 원본 서비스의 쓰기를 재개하고 이관할 수 있습니다. 이관은 현재
독립 삭제 기록을 다시 검증하므로 검사 후 삭제된 원본을 재연결하지 않습니다.

이관 도구는 dump·archive 전체 해시를 다시 검사하고, 보고서의 `passed`, `cleanup_passed`,
`authentication_passed`, `image_bytes_passed`, `live_deletion_ledger_verified`, `deletions_applied`가
모두 true인지 확인합니다. `backup_id`, `origin`, **materialized manifest SHA-256**까지 같아야 합니다.
이 보고서는 운영자가 보관한 실제 검사 결과이며 디지털 서명이나 독립 감사 증명이 아닙니다.
각 복사 대상은 해당 세트에 같은 자산·콘텐츠 ID, 불변 키, 크기·SHA로 포함되어야 합니다.
백업 이후 추가된 원본은 새 백업과 복원 검증을 준비한 다음 이관합니다.

## 일부 복사, 중단과 재개

```sh
YOUTUBE_SUMMARY_ENABLED=false .venv/bin/python -m scripts.image_migration apply \
  --backup-directory /absolute/private/MATERIALIZED_BACKUP \
  --restore-report-file /absolute/private/restore-report.json --limit 100
```

`--limit`는 이번 실행에서 시도할 local 자산 수입니다. 생략하면 모든 검사 가능한 local 원본을
시도합니다. `ready`가 남으면 다음 실행으로 이어갑니다. 이미 S3인 자산은 복사하지 않습니다.
중간 실패는 자산별 상태로 보고하며 정상 완료된 다른 자산의 전환을 되돌리지 않습니다.
명령을 종료하거나 재실행해도 콘텐츠·원본·사용량을 중복 생성하지 않습니다.

복사 전에 기존 `image_deletions`에 대상 정리 작업을 commit하고, 실제 PUT 후 다시 읽은 바이트를
원본과 대조합니다. DB 전환과 해당 정리 작업 완료는 같은 transaction입니다. PUT 또는 commit
응답이 유실되면 참조 확인을 하는 기존 정리 worker가 pending 대상을 재시도합니다. 성공 여부가
불분명하다고 원본 객체를 바로 지우지 않습니다. 원본 local 파일은 복사 실패 시에도 보존됩니다.
다른 바이트가 같은 대상 키에 있으면 덮어쓰지 않고 `target_original_conflict`로 남깁니다.

운영자 중복 이관은 SESSION advisory lock `74264005`로 거부합니다. 복사 동안 physical shared lock
`74264001`이 원본·대상 정리를 지연합니다. 최종 전환은 ledger `74264002` → physical try-lock →
콘텐츠 row 순서로 확인하며, 백업이 physical lock을 보유하면 `backup_or_cleanup_busy`로 빠르게
돌아와 사용자 삭제를 전역 대기시키지 않습니다. ledger 전체 prefix는 잠금 밖에서 검증하고
최종 잠금 안에서는 bounded tip만 대조합니다. 그 사이 새 삭제가 있으면 `deletion_ledger_changed`로
재시도합니다. 영속 삭제 intent가 남은 콘텐츠는 `deletion_pending`으로 전환을 막습니다.

원본 키·소유자·저장 시각은 identity를 유지합니다. NULL 크기/해시 보강이나 local→S3 이동은 같은
원본이며, 양쪽 모두 알려진 크기/해시 충돌이나 새 원본 키·저장 시각은 다른 원본으로 보호합니다.
이관 완료 후 사용자가 삭제하면 durable migration 기록을 통해 S3와 남겨둔 local 사본을 함께
정리합니다. 다른 살아 있는 참조가 있으면 물리 파일을 지우지 않습니다.

## 전환 이후

각 구간의 기존 인증 이미지 GET·새 access API와 실제 원본 SHA를 확인합니다. 이관과 복원 검증
전 local 파일을 일괄 삭제하지 않습니다. 이 도구에는 일괄 local 삭제 명령이 없으며 의도적으로
남긴 사본의 공간은 사용자가 삭제할 때까지 사용합니다. 별도 정리 정책 없이 디렉터리를 지우지 않습니다.

S3 자산이 생긴 뒤에는 Bucket을 읽지 못하는 과거 백엔드로 단순 rollback하거나 storage metadata
스키마를 내려서는 안 됩니다. 문제가 있으면 혼합 조회가 가능한 버전을 유지하고 신규 이미지 저장
중단·이관 중단 후 원인을 확인합니다. 이 명령은 실제 Railway 자격·권한, 운영 데이터, 배포·서버 중지·
복구 전환을 대신 검증하지 않습니다.

`Dockerfile.operator`에는 이관 모듈도 포함됩니다. 기본 entrypoint는 백업 작업이므로 컨테이너에서
쓸 때는 `--entrypoint python IMAGE -m scripts.image_migration ...`으로 선택하고 같은 원본 디렉터리와
검증된 비공개 백업·보고서를 mount합니다. 실제 합성 검증은
[이관 작업 이력](../history/2026-10-23-image-storage-migration.md)에 기록합니다.
