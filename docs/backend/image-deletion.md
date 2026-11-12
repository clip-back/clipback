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

### Mac Docker에서 운영 초기화

먼저 검증된 커밋의 운영자 이미지를 준비한다. 코드 준비가 끝난 뒤 실제 이미지 식별자와
해당 커밋을 운영 기록에 남기고, 초기화와 checkpoint에 같은 이미지를 사용한다. 원본 Bucket,
백업 Bucket, 운영 DB 연결이나 기존 Volume 마운트는 초기화에 필요 없다. 일반 API 이미지는
운영자 명령을 포함하지 않는다.

```bash
docker info
docker build -f Dockerfile.operator -t clipback-ledger-operator:validated .
```

빌드는 백엔드 디렉터리에서 실행한다. Docker 구동 확인과 빌드 성공은 실제 Railway 연결·권한
확인이 아니다. 이 초기화는 PostgreSQL 도구를 사용하지 않으며, 같은 이미지를 나중에 백업에
사용하려면 운영 DB major와 이미지의 PostgreSQL 도구 버전을 별도로 맞춰야 한다.

사용자가 저장소 밖의 보호된 환경 파일을 만들고 다음 항목을 직접 입력한다. 파일 권한은
소유자만 읽고 쓸 수 있는 0600으로 두며, 실제 값은 채팅·Git·명령 인자·실행 로그에 넣지 않는다.
endpoint·region·주소 방식·Bucket 이름은 실제 Bucket Credentials의 값을 사용한다.

| 환경 변수 | 값 |
| --- | --- |
| `APP_ENVIRONMENT` | `production` (초기화 도구의 기본값도 production) |
| `DELETION_LEDGER_BACKEND` | `s3` (초기화 도구의 기본값도 s3) |
| `DELETION_LEDGER_S3_ENDPOINT_URL` | 삭제 기록 Bucket의 HTTPS endpoint |
| `DELETION_LEDGER_S3_BUCKET` | 삭제 기록 Bucket의 실제 이름 |
| `DELETION_LEDGER_S3_REGION` | 공급자의 region |
| `DELETION_LEDGER_S3_ADDRESSING_STYLE` | 공급자의 `virtual` 또는 `path` |
| `DELETION_LEDGER_S3_ACCESS_KEY_ID` | 삭제 기록 Bucket 전용 키 |
| `DELETION_LEDGER_S3_SECRET_ACCESS_KEY` | 해당 비밀 키 |

초기화·checkpoint 명령은 프로세스 환경 변수만 읽으며 작업 디렉터리의 `.env`를 자동으로 읽지
않는다. API의 기존 `.env` 처리와 전체 운영 설정 검증은 유지된다. DB·로그인·AI 설정을 채워
넣거나 가짜 값으로 우회할 필요가 없다. 아래 파일 경로는 실제 보호된 파일 경로로 바꾼다.

```bash
docker run --rm --env-file /absolute/private/ledger-bootstrap.env \
  --entrypoint python clipback-ledger-operator:validated \
  -m scripts.image_deletions init --confirm-new-namespace

docker run --rm --env-file /absolute/private/ledger-bootstrap.env \
  --entrypoint python clipback-ledger-operator:validated \
  -m scripts.image_deletions checkpoint
```

첫 명령은 새 전용 저장소에만 실행한다. 두 명령 모두 종료 코드 0과 JSON의 namespace·sequence·digest를
확인하며, 새 저장소는 sequence 0이다. checkpoint 결과는 초기화 결과와 일치해야 한다.
이미 사용 중인 기록은 초기화하지 않고 checkpoint로 확인한다. 연결·권한·손상 오류는 종료 코드 1과
고정된 실패 안내를 반환하며 성공 JSON을 출력하지 않는다. 실패 원인을 해결하기 전에 배포를 진행하거나
새 namespace로 덮어쓰지 않는다. 실제 공급자 연결은 이 단계에서 별도로 확인한다.

로컬 개발용 초기화는 `APP_ENVIRONMENT=local`, `DELETION_LEDGER_BACKEND=local`,
`DELETION_LEDGER_ROOT`를 명시적으로 프로세스 환경에 제공한 뒤 기존 Python 명령을 사용할 수 있다.
API의 `STORAGE_ROOT` 밖에 있고 재시작 후 유지되는 경로를 사용한다.

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

운영에서는 API 이미지로 만든 별도 Railway Cron 서비스가 매시간 45분에 `python -m scripts.image_deletions retry`를
실행하고, 종료 코드 1이면 Railway "Deploy Crashed" 메일이 온다. 설정은
[운영 실행 체크리스트](image-operator-first-run.md#원본-삭제-재시도-서비스)를 따르며, 운영 적용은 병합 뒤 확인하기 전이다.
`OPERATOR_SOURCE_ID`가 설정돼 있으면 Volume 원본(`local`, 이관된 원본의 Volume 사본 포함)은 `STORAGE_ROOT`의
`.clipback-source-id`가 그 값과 맞을 때만 지운다. 값이 비었거나 형식이 틀려도 지우지 않는다. Volume이 없는 이 서비스에서는 지우지 않고
`last_error=original_volume_unavailable`로 남긴다. 이관된 원본은 Bucket 쪽을 먼저 지우므로, 다음 재시도의
Bucket 삭제는 없는 객체 삭제로 오류 없이 끝난다. 남은 Volume 원본은 API 컨테이너 안에서 같은 명령을 한 번
실행해 마저 지운다. `OPERATOR_SOURCE_ID`가 없는 로컬 개발·테스트 환경은 확인 없이 지운다.
계정 탈퇴 기록(아래 계약 절)은 확정된 탈퇴 요청이다. 기록의 계정 번호와 계정 생성 시각이 둘 다 맞는
계정이 아직 남아 있으면(기록 뒤 DB 삭제 실패) 이 명령이 마저 지우고, 지운 계정 수를 `deleted_accounts`로
보고한다. 번호만 같고 생성 시각이 다른 계정은 지우지 않는다. 반영한 삭제 의도와 지운 계정을 합쳐
`--limit`까지 처리한다.
재처리는 초기화와 달리 전체 API 설정 검증 및 DB·원본 접근이 필요하다. 초기화용 Mac 컨테이너에는
이 접근이 없으므로 그대로 재처리 실행 환경으로 간주하지 않는다. 스케줄러에서 반복 실행하거나
장애 해소 후 수동 실행한다. 명령 구현만으로 운영 스케줄을 생성하지는 않는다. 처리량보다 빠르게 쌓이는 큐와 마지막 성공 실행은 운영 점검 대상이다.

물리 정리는 DB advisory lock `74264001`의 exclusive transaction lock을 얻은 경우에만 수행한다.
백업의 shared session lock이 유지되는 동안에는 정리를 연기하여 스냅샷 원본을 보존한다.
정리 직전에 같은 backend/key를 참조하는 현재 원본이 있으면 삭제하지 않는다.

## 운영자 계정 삭제

```bash
python scripts/image_deletions.py delete-account --user-id <계정 번호> --confirm-irreversible
```

`python -m scripts.image_deletions delete-account ...` 형태도 같다. 계정 하나를 앱의 회원 탈퇴와 같은
처리(`delete_account`: 공급자 연결 정리 → 삭제 장부 기록 → DB 삭제 → 원본 삭제)로 지운다. 탈퇴 사유
기록은 남기지 않는다. 재처리처럼 전체 API 설정(DB·장부·저장소·Apple·카카오 어드민 키)이 필요하고,
서비스 점검 중이면 실행되지 않는다. 되돌릴 수 없으므로 `--confirm-irreversible`이 필수다.

| 결과 | 종료 코드 | 출력 |
| --- | --- | --- |
| 삭제 성공 | 0 | 표준 출력 JSON 한 줄 `{"deleted": true, "pending_original_cleanup": <수>}` |
| 계정 없음(이미 지워짐 포함) | 1 | 표준 오류 `Account not found; nothing was deleted`, DB 변화 없음(점검 admission도 정상 종료) |
| 장부·DB 실패, 점검 중, 설정 오류, 그 밖의 오류 | 1 | 표준 오류 `Account deletion failed; no successful completion is confirmed` |
| 계정 번호 없음·숫자 아님·0 이하, 확인 옵션 없음 | 2 | 표준 오류 사용법 안내, DB 변화 없음 |

`pending_original_cleanup`은 이번 삭제에서 아직 지우지 못한 원본 정리 작업 수다. 0이 아니어도 계정
삭제는 끝났고, 남은 정리는 `retry`가 맡는다. 실패 문구에는 비밀값·연결 문자열을 넣지 않는다. 장부 기록 뒤
DB 삭제가 실패하면 기록은 확정된 탈퇴 요청으로 남으므로, 같은 명령을 다시 실행하면 같은 기록을 재사용해
지운다(`retry`도 남은 계정을 마저 지운다).

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

회원 탈퇴는 같은 순번 체인에 `kind: "account_deletion"` event 하나를 쓴다([ADR 0008](../adr/0008-account-deletion-ledger-record.md)).
event에는 operation UUID, 계정 번호, 계정 생성 시각, 삭제 의도 시각, 그 계정 이미지 콘텐츠들의 삭제 정보
(콘텐츠 ID·저장 시각·원본 backend/key·SHA-256·크기)를 담고 이메일·이름은 넣지 않는다. 이미지 콘텐츠가
없으면 목록이 비어 있다. operation UUID는 계정 번호와 생성 시각에서 정하므로, 기록 뒤 DB 삭제가 실패해
다시 시도하면 이미지 목록이 달라도 처음 기록을 그대로 쓴다. 계정 삭제는 삭제 직전 DB에 있는 그 계정의
이미지 콘텐츠마다 기존 이미지 삭제와 같은 형태의 정리 작업을 만든다. 작업 operation은 탈퇴 기록의
operation·콘텐츠 ID·저장 시각에서 정해지므로 재시도·복원 반영을 반복해도 늘지 않는다. 이 기능 이전
event(이미지 삭제)는 형식이 그대로이며 함께 검증된다. 이 기능 이전 서버는 새 event를 읽지 못하므로
탈퇴가 한 번이라도 일어난 뒤에는 그 서버로 되돌리지 않는다([Railway 배포](../railway-deployment.md#복원과-롤백)).

최신성은 오프라인 checkpoint나 digest만으로 증명할 수 없다. 복원은 삭제 쓰기를 중지하거나
`74264002` shared session lock을 유지한 상태에서 **현재 독립 저장소**의 checkpoint와 연결된
기록을 읽고 확인해야 한다. 전체 저장소가 악의적으로 과거 상태로 되돌아간 경우를 이 연결만으로
탐지할 수 있다고 주장하지 않는다. 원본·삭제 기록·백업의 실제 권한 분리도 공급자에서 별도 확인한다.

이 단계에서는 삭제 기록 메타데이터를 자동 삭제하지 않는다. 해당 삭제 이전 복구 지점을
인정하는 동안 유지해야 하며, 이미지 사본의 7일 제거 정책은 후속 백업 보존 작업에서 적용한다.
구현·검증 이력은 [원본 삭제 작업 이력](../history/2026-10-23-image-deletion.md)을 참고한다.
