# 원본 이미지 삭제 기록과 정리 재시도

`DELETE /api/v1/contents/{id}`는 소유자의 기존 API를 사용한다. 원본 이미지가 있는 콘텐츠는
독립 삭제 기록 저장소에 삭제 의도를 쓰고 다시 읽어 확인한 뒤, 콘텐츠 삭제와 정리 작업을
같은 DB 트랜잭션으로 커밋한다. 성공한 신규 상세·원본 인증 요청은 404가 되며 보관량 계산에서
제외된다. 이미 발급한 서명 URL은 원본이 실제 삭제되거나 URL이 만료될 때까지 유효할 수 있다.
이미 없거나 다른 사람의 콘텐츠를 다시 삭제하면 기존 계약처럼 404를 반환한다.

## 독립 기록 설정과 초기화

운영 S3 원본에는 **원본 Bucket과 별개의 삭제 기록 Bucket**과 그 전용 설정을 사용한다.
일반 API에는 백업 Bucket의 자격 증명을 제공하지 않는다. 삭제 기록 Bucket에는 이미지 바이트를
넣지 않는다. Railway의 Bucket 자격 증명은 Bucket 단위이므로 API 자격 증명이 유출된 공격자에
대한 변경 불가능한 감사 기록이나 쓰기 전용 권한을 제공한다고 간주하지 않는다.

로컬 개발은 `DELETION_LEDGER_BACKEND=local`, `DELETION_LEDGER_ROOT=deletion-ledger`를 사용한다.
이 경로는 `STORAGE_ROOT` 밖에 있어야 하며 재시작 후 유지되는 경로를 지정한다. 운영 Bucket
원본에서 로컬 기록으로 자동 대체하지 않는다. S3 설정은 `.env.example`의 `DELETION_LEDGER_S3_*`를
사용하며 실제 공급자의 endpoint·region·addressing style·독립 자격 증명을 지정한다.

전용 저장소를 준비한 뒤 백엔드 디렉터리에서 한 번 초기화한다.

```bash
python scripts/image_deletions.py init --confirm-new-namespace
python scripts/image_deletions.py checkpoint
```

`init`은 빈 저장소에 UUID namespace와 sequence 0인 head를 만든다. 이미 namespace가 있는
저장소의 head가 없으면 초기화로 덮어쓰지 않고 실패한다. 데이터 손실 뒤 새 namespace를
만드는 것은 복구가 아니며, 이전 namespace를 참조하는 백업의 정상 복원으로 취급할 수 없다.
API는 누락된 기록을 빈 이력으로 자동 초기화하지 않는다. 초기화·checkpoint 검증은 배포 전
운영 확인 사항이며 일반 이미지 저장소의 readiness 통과가 이를 대신하지 않는다.

## 성공 응답과 부분 실패

- 독립 기록 쓰기·확인이 실패하면 503이며 성공으로 보고하지 않는다.
- PostgreSQL과 S3를 하나의 원자적 트랜잭션으로 묶지 않는다. 기록 확인 뒤 DB 커밋이 실패하면
  실패 응답이어도 삭제 의도가 남을 수 있다. 재시도 명령은 이를 실제 삭제로 수렴시킨다.
- DB에 삭제가 커밋되면 원본 삭제 실패와 무관하게 논리적 접근은 차단된다. 정리 작업은
  콘텐츠·사용자 FK cascade와 무관하게 남으며 프로세스 재시작 뒤에도 재시도한다.
- 원본 저장 PUT의 ACK 손실, 알려진 업로드 실패 뒤 정리 실패도 참조 확인 후 같은 정리 큐에
  기록한다. 커밋된 원본은 정리하지 않는다. DB까지 사용할 수 없어 큐를 쓰지 못하는 복합
  장애에서는 업로드 실패를 유지하고 원본을 보존하며 운영 확인이 필요하다.

## 운영 재시도

```bash
python scripts/image_deletions.py retry --limit 100
```

한 번의 명령은 최신 독립 기록을 검증하고, DB에 반영되지 않은 삭제 의도를 최대 지정 개수만큼
반영한 뒤 영속 정리 작업을 최대 지정 개수만큼 시도한다. 결과의 `reconciled`, `attempted`,
`pending`은 작업 수다. `pending > 0` 또는 작업 실패는 종료 코드 1이며 다음 실행에서 재시도한다.
스케줄러에서 반복 실행하거나 장애 해소 후 수동 실행한다. 명령 구현만으로 운영 스케줄을
생성하지는 않는다. 처리량보다 빠르게 쌓이는 큐와 마지막 성공 실행은 운영 점검 대상이다.

물리 정리는 DB advisory lock `74264001`의 exclusive transaction lock을 얻은 경우에만 수행한다.
백업의 shared session lock이 유지되는 동안에는 정리를 연기하여 스냅샷 원본을 보존한다.
정리 직전에 같은 backend/key를 참조하는 현재 원본이 있으면 삭제하지 않는다.

## 백업·복원에서 사용하는 계약

`DeletionLedger`의 동기 공개 경계는 `initialize`, `append`, `read_operation`,
`read_verified_checkpoint`, `read_verified_events`다. API에서는 블로킹 I/O를 별도 스레드로 실행한다.

checkpoint는 namespace·sequence·digest이며, 각 순번의 불변 event가 이전 digest와 연결된다.
namespace·head·연결된 event가 없거나 손상되면 검증에 실패한다. S3 List 결과만으로 삭제
기록이 완전하다고 판정하지 않는다. 쓰기는 PostgreSQL advisory transaction lock `74264002`로
직렬화하며 공급자의 미확인 conditional PUT 지원에 의존하지 않는다.

사용자 삭제 요청은 namespace·head·마지막 event와 해당 operation receipt를 직접 확인한다.
이전 삭제 개수에 비례해 저장소 GET 요청이 늘어나지 않는다. 중단된 마지막 event는 다음
쓰기에서 먼저 게시해 순번을 덮어쓰지 않는다. `read_operation`도 해당 영수증을 직접 확인하는
경계이며, 백업·복원의 전체 이력 검증을 대신하지 않는다. 전체 연결 검사는 명시적인
checkpoint·백업·복원·재조정에서 수행한다.

event에는 삭제 operation UUID, 소유자, 콘텐츠 ID·저장 시각·삭제 의도 시각, 각 원본의 불변
backend/key·SHA-256·크기를 기록한다. 과거 원본의 해시·크기는 null일 수 있다. 복원 후 숫자 ID가
재사용될 수 있으므로 ID만으로 삭제하지 않고 저장 시각과 원본 식별자까지 일치시킨다.
같은 operation의 재시도는 기존 삭제 시각을 사용하므로 보존 기간을 연장하지 않는다.

최신성은 오프라인 checkpoint나 digest만으로 증명할 수 없다. 복원은 삭제 쓰기를 중지하거나
`74264002` shared session lock을 유지한 상태에서 **현재 독립 저장소**의 checkpoint와 연결된
기록을 읽고 확인해야 한다. 전체 저장소가 악의적으로 과거 상태로 되돌아간 경우를 이 연결만으로
탐지할 수 있다고 주장하지 않는다. 원본·삭제 기록·백업의 실제 권한 분리도 공급자에서 별도 확인한다.

이 단계에서는 삭제 기록 메타데이터를 자동 삭제하지 않는다. 해당 삭제 이전 복구 지점을
인정하는 동안 유지해야 하며, 이미지 사본의 7일 제거 정책은 후속 백업 보존 작업에서 적용한다.
구현·검증 이력은 [원본 삭제 작업 이력](../history/2026-10-23-image-deletion.md)을 참고한다.
