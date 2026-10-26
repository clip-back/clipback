# 첫 운영 원본 백업·격리 복원 실행 체크리스트

상태: **2026-10-26 실제 운영 백업·격리 복원·명시적 서비스 재개 완료**.
신규 이미지 Bucket 저장 전환과 일일 백업 일정 설정, 해당 정기 명령의 수동 실행도 확인했다.
예약 시각의 자동 실행은 아직 미확인이고, `maintain` 보존 정리 서비스는 사용자 요청으로 보류했다.
따라서 **7일 보존·삭제 사본 정리가 자동 운영 중인 것은 아니다**.

상세 실행 식별자·시각·검증 범위는 [2026-10-26 운영 실행 기록](../history/2026-10-26-image-operator-production.md)에 보존한다.
운영 현황은 이 문서를 기준으로 읽고 과거 실행 계획은 당시 설계 자료로만 사용한다.
아래 개선 CLI는 저장소 구현 기준이며 **아직 운영에 배포·적용하지 않았다**.
운영 서비스의 기존 한 줄 래퍼와 설정은 그대로다. 새 명령으로 바꾸기 전에 새 이미지 배포를 확인한다.
이 문서 갱신으로 GitHub #97·#102의 상태를 변경하지 않았다.

## 확인된 운영 상태 (2026-10-26)

- [x] 기존 Volume 원본 식별·비공개 접근을 확인하고 첫 수동 백업을 생성했다.
- [x] Mac Docker에서 첫 백업의 DB·원본을 격리 복원하고 서비스 재개·임시 자료 정리를 확인했다.
- [x] 신규 저장을 Bucket으로 전환하고 기존 Volume 원본 열람을 유지했다.
- [x] Volume 18개·Bucket 1개를 포함한 혼합 백업을 생성하고 격리 복원·재개·정리를 확인했다.
- [x] `clipback-backup`의 Cron을 `0 0 * * *`(매일 09:00 KST), 재시작 정책을 `Never`로 설정했다.
- [x] `daily` 명령을 예약 외 수동 실행해 DB·이미지 백업과 정상 종료를 확인했다.
- [ ] 예약 시각에 자동 실행되는지 확인한다. 기록 시점의 다음 예약은 2026-10-27 09:00 KST다.
- [ ] `maintain` 정기 서비스: **보류**. 재개할 때 백업 사본 삭제 범위와 첫 실행 결과를 확인한다.
- [ ] 원본 물리 삭제 재처리의 정기 실행 및 기존 Volume 이미지 이관: 후속 작업이다.

아래 1~4절의 체크박스는 **다음 실행에도 사용할 절차 양식**이며, 위 완료 상태와 구분한다.
실패·연결 상실 대응 항목은 이번 성공 실행에서 장애를 발생시켜 검증했다는 뜻이 아니다.
다시 실행할 때 배포 버전·접속·권한·백업·점검 상태를 새로 확인한다.

## 역할과 실행 전 기록

에이전트는 통합 코드·이미지 빌드·검증 결과·명령과 오류 해석을 준비한다. 사용자는 Railway 콘솔에서
서비스·비밀값을 직접 설정하고 점검 시간을 안내한다. SSH 키·CLI 변경과 실제 운영 명령 실행은
준비가 완료된 뒤 별도 요청 범위에서 진행한다. 키·토큰·원본 파일명·사용자 본문을 채팅이나 Git에 넣지 않는다.

| 기록 | 실제 확인값 |
| --- | --- |
| 승인한 운영 실행 범위·시각·운영자 | 2026-10-26 사용자 승인에 따라 에이전트 실행, 콘솔 설정은 사용자 수행 |
| 배포할 통합 커밋 / 실제 배포 커밋 | `909ff63f11dea0af56832dbe5dc5fa4f4dd7f6a8` / 동일 커밋 확인 |
| API·운영자 이미지 revision / PostgreSQL major | 위 커밋 기준 / PostgreSQL 18 |
| 실제 DB migration head / 현재 신규 저장 backend | `202610260020` / `s3` (기존 Volume 유지) |
| 원본 식별자 등록·일치 / 내부 연결·공개 차단 | 확인 완료; 식별자·키 값은 기록하지 않음 |
| 수동 백업·복원 run ID | 첫 Volume 백업과 혼합 백업 모두 성공; 상세 ID는 실행 기록 참조 |
| 점검·복원·재개·정리 | 두 복원 모두 성공, 명시적 재개 후 `open`·readiness 200 확인 |

앞선 조사 수량·DB 버전·접속 성공은 이번 실행의 확인값을 대신하지 않는다. 운영 DB 초기화·기존
삭제 기록 재초기화·기존 이미지 삭제는 준비 작업에 포함하지 않는다.

## 1. 같은 통합 버전 배포와 설정 준비

- [ ] 최종 통합 코드의 테스트·리뷰 결과와 실제 실행한 선택형 Docker 검사를 확인한다.
- [ ] API·요약 작업·운영 명령 모두 같은 통합 코드를 사용한다. 이전 배포 프로세스가 계속 변경하지 않도록 확인한다.
- [ ] 실제 DB 업그레이드가 단일 최신 head에 도달했는지 확인한다. 점검 schema 최초 추가는 `202610260020`이며 기존 업무 자료를 유지한다.
- [ ] API의 기존 Volume·`STORAGE_ROOT`를 유지한다. 첫 Volume 검증 당시 `STORAGE_BACKEND=local`이었으며 현재 신규 저장은 `s3`다. 재실행을 위해 `local`로 되돌리지 않는다. API에 백업 Bucket 키를 공급하지 않는다.
- [ ] [원본 읽기 준비](image-operator-source.md)에 따라 실제 Volume과 원본을 확인하고 식별자를 한 번 등록한다. 등록 전 빈 디렉터리를 만들거나 재시작 때 자동 등록하지 않는다.
- [ ] API에 `OPERATOR_SOURCE_ID`, 서로 다른 `OPERATOR_READ_KEY`·`OPERATOR_CONTROL_KEY`, `OPERATOR_PORT`·`OPERATOR_HOST`를 공급한다. API의 기존 `DATABASE_URL`은 점검 제어에도 사용한다.
- [ ] 실제 Railway 내부 주소·IPv4/IPv6 연결을 확인한다. 공개 도메인과 TCP 프록시가 운영자 포트를 가리키지 않는지 확인한다. 공개 앱 포트의 `/source`·`/maintenance` 거절도 확인한다.
- [ ] 앱 토큰·다른 읽기 키·다른 식별자와 읽기 키의 점검 제어 시도가 거절되는지 확인한다. 실제 원본 읽기는 크기·해시까지 검증한다.

API 컨테이너에서 Volume 등록을 실행할 때는 실제 확인한 값으로 다음 명령을 사용한다.
연결 도구의 현재 지원 범위를 먼저 확인하며 예전 CLI에 새 옵션이 있다고 가정하지 않는다.

```sh
python -m scripts.image_source register --root /data/screenshots \
  --source-id "$SOURCE_ID" --confirm-volume
```

등록 실패 후 무조건 재등록하거나 식별 파일을 삭제하지 않는다. 상세 실패 분류와 포트 계약은
[원본 읽기 안내](image-operator-source.md), 점검 명령은 [점검 제어](image-maintenance.md)가 기준이다.

## 2. 종료형 Railway 운영자와 수동 백업

운영자 서비스는 검증한 통합 커밋의 `Dockerfile.operator`로 PostgreSQL 18 이미지를 사용한다.
첫 수동 백업 준비 시 공개 도메인·Cron·원본 Volume·Docker socket을 붙이지 않는다. 현재 일일 일정은 아래 후속 설정을 따른다. restart policy는 **Never**로 두고
수동 실행의 종료 코드와 결과를 확인한다. 실패한 작업을 자동 재시작으로 숨기지 않는다.
실제 검증한 Railway 설정은 Root Directory `/backend`, Dockerfile 경로 `/backend/Dockerfile.operator`다.
API의 pre-deploy migration·HTTP start command·healthcheck를 운영자에 복사하지 않는다. DB migration은
먼저 API 배포에서 완료한다. 운영자 서비스의 자동 Git 배포도 비활성화해 코드 push가 백업 실행을
유발하지 않도록 하고, 검증한 버전의 수동 실행만 시작한다.

| 운영자 설정 | 공급 내용 |
| --- | --- |
| `DATABASE_URL` | 같은 운영 PostgreSQL의 실제 내부 연결 |
| `STORAGE_ROOT`, `STORAGE_BACKEND` | 명시적 절대 경로와 현재 `s3` (첫 Volume 검증 당시 `local`); 이 경로를 실제 Volume mount로 취급하지 않음 |
| `OPERATOR_SOURCE_URL` | API의 실제 내부 주소와 운영자 포트 |
| `OPERATOR_SOURCE_ID`, `OPERATOR_READ_KEY` | API와 같은 원본 식별·읽기 권한 |
| `DELETION_LEDGER_*`, `APP_ENVIRONMENT=production` | 기존 독립 삭제 기록을 읽는 설정; 새 namespace 초기화 금지 |
| 원본 `S3_*` | 백업에 기존 S3 자산이 포함되는 경우에만 해당 원본을 읽는 설정 |
| 백업 설정 JSON | 원본과 다른 비공개 백업 Bucket의 endpoint·bucket·region·addressing_style·키 |
| `IMAGE_BACKUP_ID`, `IMAGE_BACKUP_APP_COMMIT` | 이번 고유 백업 ID와 실제 원본 API의 전체 40자 커밋 |

운영자에는 점검 제어 키·SSH 키·AI·소셜 로그인 비밀값을 요구하지 않는다.
개선 이미지에서는 `BACKUP_BUCKET_CONFIG_JSON`을 프로세스 환경에서 직접 읽으므로 임시 설정 파일과
콘솔 Python 래퍼가 필요 없다. JSON 필드는 [백업 설정 계약](backup-recovery.md)을 따른다.
파일 방식도 계속 지원하며, `--backup-config-file`을 지정하면 환경변수보다 우선한다.
설정 파일은 소유자가 실행 사용자이고 권한이 `0600`이어야 한다.

개선 이미지 배포 후 Railway Start Command:

```sh
python -m scripts.image_backup_jobs manual
```

`IMAGE_BACKUP_ID`와 `IMAGE_BACKUP_APP_COMMIT`은 환경변수에서 읽는다. 명시적인 CLI 인자로
덮어쓸 수 있다. `--origin` 기본값은 `production`이며 합성 검사는 `--origin synthetic`을 지정한다.
필수 설정 누락·잘못된 값은 비밀값 없는 오류 JSON과 실패 종료로 보고한다.

- [ ] 운영자에서 실제 원본 식별·읽기가 성공하고 PostgreSQL 도구 major가 원본 DB와 맞는지 확인한다.
- [ ] 수동 백업을 1회 실행한다. `passed=true`, 해당 `backup_id`, `backup_created=true`, `restore_verified=false`와 정상 종료를 확인한다.
- [ ] 누락·읽기·크기/해시·접속·권한 오류가 없는지 확인한다. 실패한 부분 산출물을 완료 지점으로 사용하지 않는다.
- [ ] 원본과 대기 중 삭제·기존 백업에 예상하지 않은 정리가 일어나지 않았는지 확인한다. `manual`은 삭제 재처리·보존 정리를 실행하지 않는다.
- [ ] 운영자 종료와 임시 실행 환경의 폐기를 확인한다. 백업 생성 성공을 복원 성공으로 기록하지 않는다.

## 3. 점검 전에 Mac 준비

Mac 복원 제어기는 호스트 Python과 로컬 Docker CLI를 사용한다. 새 host networking 설정이나
복원 대상의 운영망 연결은 필요하지 않다. [Mac 격리 복원 안내](isolated-restore-execution.md)의
최소 설정·SSH 터널·자격 파일 권한을 따른다.

- [ ] 실제 백업 커밋에 맞는 revision 라벨의 API 이미지를 준비한다. 로컬 빌드 시 `--label org.opencontainers.image.revision=BACKUP_COMMIT`을 제공한다.
- [ ] 같은 주 버전의 PostgreSQL 이미지와 필요한 Bucket 대역 이미지를 미리 준비한다. Docker 가동·context·여유 공간을 확인한다.
- [ ] 현재 Railway CLI 지원과 SSH 키 등록을 확인한다. Mac의 127.0.0.1에서만 운영 포트·DB private 주소로 터널을 열고 실제 연결을 확인한다. SSH 자격은 서버 운영자에 공급하지 않는다.
- [ ] Mac 전용 실행 환경에 loopback `DATABASE_URL`, `OPERATOR_CONTROL_URL`, 제어 키, 독립 삭제 기록 읽기 설정, `APP_ENVIRONMENT=production`을 공급한다. 설정 내용을 출력하지 않는다.
- [ ] 저장소 밖의 `0700` 위치에 백업 지점을 내려받고, 검증 계정의 기존 형식 `0600` 복원 자격 JSON을 준비한다. 백업 Bucket 읽기 설정 파일도 저장소 밖 `0600`으로 둔다.

Mac의 backend 개발 환경에서 필요한 명령은 다음과 같다. 아래 경로는 실제 보호된 절대 경로로 치환한다.
백업 설정 파일을 읽는 `download`에는 API·AI 설정이나 원본 Volume mount가 필요하지 않다.

```sh
python -m scripts.image_backup --backup-config-file /absolute/private/backup-bucket.json \
  download --backup-id BACKUP_ID --directory /absolute/private/NEW_DOWNLOAD_DIRECTORY
python -m scripts.restore_execution prepare \
  --backup-dir /absolute/private/NEW_DOWNLOAD_DIRECTORY \
  --credentials-file /absolute/private/restore-credentials.json \
  --image clipback-recovery:BACKUP_COMMIT --run-root /absolute/private/restore-runs
```

- [ ] `prepare`가 성공하고 `run_id`·`workspace`를 반환했는지 확인한다. 원본 데이터·설정 값을 보고서에 복사하지 않는다.
- [ ] 서버 측 `python -m scripts.maintenance status`가 사용 가능하고, Mac 상실 시 실행할 위치·담당자를 확인한다.
- [ ] 수동 DB 수정·이전 스크립트·외부 배치 등 점검 경계를 따르지 않는 쓰기를 중단할 준비를 마친다.

## 4. 점검·격리 복원·명시적 재개

참여자 점검 안내만으로 쓰기 중단을 판정하지 않는다. 준비 결과의 **같은 run ID**로 서버 측 명령을 실행한다.
이 단계의 운영 실행 요청·시간을 확인한 뒤 시작한다.

```sh
python -m scripts.maintenance start --run-id RUN_ID
```

- [ ] 새 일반 API가 503이며 기존 요청·백그라운드 작업이 종료돼 최대 60초 안에 `phase=frozen`인지 확인한다.
- [ ] 진입 실패·기한 초과에는 복원하지 않는다. 차단을 유지하고 진행 중 작업·운영 상태를 확인한다. 재시작으로 차단을 풀지 않는다.
- [ ] 쓰기 중단을 확인한 뒤 Mac에서 다음 명령을 실행한다. 검증 전체는 최대 30분이며 자동 재개 시간이 아니다.

```sh
python -m scripts.restore_execution run --workspace /absolute/private/restore-runs/restore-RUN_HEX
```

- [ ] 보고서의 `passed`, `maintenance_verified`, `live_deletion_ledger_verified`, `source_database_verified`를 확인한다. 원본 열람·최신 삭제 반영·계정 격리 결과를 기록한다.
- [ ] `child_stopped`, `executors_stopped`, `source_lock_released`, `restore_receipt_finished`, `cleanup_passed`를 확인한다. 미확인 항목을 성공으로 바꾸지 않는다.
- [ ] 실패·연결 단절·시간 초과에는 결과 보고서와 잔여 journal을 확인한다. 이전 실행이 종료된 뒤에만 [정리·복구 명령](isolated-restore-execution.md#비정상-종료와-연결-상실-복구)을 사용한다.
- [ ] Mac 상실 시 서버의 `maintenance status`로 확인한다. 원본 잠금과 이전 실행 종료를 확인한 **해당 작업만** `recover --confirm-executor-stopped`로 복구한다. 단순 연결 부재·시간 경과를 종료 증거로 삼지 않는다.
- [ ] 운영 상태와 실행 종료·잠금 해제가 확인되면 같은 run ID를 명시적으로 재개한다. 남은 작업 기록이 있거나 상태가 불명확하면 재개 완료로 기록하지 않는다.

```sh
python -m scripts.maintenance status
python -m scripts.maintenance resume --run-id RUN_ID
```

- [ ] `phase=open`과 기존 앱의 원본 열람·일반 요청 회복을 확인하고 참여자 테스트를 재개한다.
- [ ] 이번 실행의 임시 사본·컨테이너·볼륨·네트워크와 잔여 journal 정리를 확인한다. 입력 다운로드·복원 자격 원본은 자동 삭제 대상이 아니므로 운영자가 이번 실행 소유 자료를 확인해 별도로 정리한다.
- [ ] 비밀값 없는 결과 보고서를 남긴다. 정리 실패·미확인 재개는 숨기지 않는다. 운영 원본·백업 Bucket의 복구 지점은 정리하지 않는다.

검증 실패 후 서비스 재개 가능 여부와 백업 검증 재시도는 별도로 판단한다. 이번 운영 검증이
성공하기 전에는 신규 Bucket 저장 전환·이관을 진행하지 않는다.

## 완료 증거

코드/합성 검증, 실제 공급자 연결, 실제 수동 백업·복원·재개를 각각 기록한다. `prepare` 성공이나
S3 대역·CI 성공만으로 실제 운영 완료를 체크하지 않는다. 큰 사진·영상 대신 아래 작은 보고서를 남긴다.

| 증거 | 미실행 시 표기 |
| --- | --- |
| 통합 커밋·이미지 revision·실행한 검사/실행하지 않은 검사 | 코드 검증 대기 |
| 실제 Volume 식별·내부 연결·공개 차단·권한 분리 | 실제 연결 미검증 |
| 백업 ID·완료 결과·원본 바이트 검증 | 백업 미실행 |
| run ID·점검 진입·복원 결과·종료/잠금/기록 정리 | 복원 미실행 |
| 명시적 재개·기존 앱 확인·Mac 임시 자료 정리 | 운영 완료 미확인 |

실제 단계가 모두 확인돼야 #102와 #97을 완료 처리한다. 후속 일일 일정·삭제/보존 정리·신규 Bucket
전환·이관의 착수 조건과 담당자를 다음 작업에 인계한다.

## 일일 백업과 보존 정리 CLI (개선 이미지 배포 후)

현재 운영 중인 `clipback-backup`의 Cron은 `0 0 * * *` (UTC 00:00 / KST 09:00),
Restart Policy는 `Never`다. 새 이미지 배포를 확인한 뒤 다음 명령으로 교체할 수 있다.
이 문서 변경만으로 운영 명령을 교체하지 않는다.

```sh
python -m scripts.image_backup_jobs daily
```

- `BACKUP_BUCKET_CONFIG_JSON`과 `IMAGE_BACKUP_APP_COMMIT`, 기존 DB·삭제 기록·원본 S3·Volume 원격 읽기 설정을 유지한다.
- ID는 `daily-YYYY-MM-DD`(UTC)로 생성한다. `IMAGE_BACKUP_ID`는 사용하지 않는다.
- `IMAGE_BACKUP_APP_COMMIT`은 실제 원본 API 커밋과 맞추고 API 버전 변경 시 확인한다.
- 같은 날짜의 완료 지점이 있으면 `backup_created=false`로 종료할 수 있다.
- `restore_verified=false`는 생성만 수행했다는 뜻이다. 별도 격리 복원 성공으로 바꾸지 않는다.
- 예약 외 실행과 예약 시각 자동 실행을 구분한다. 첫 자동 실행의 완료 지점과 종료를 확인한다.

`maintain`은 **보류** 상태다. 재개 승인과 개선 이미지 배포 후 별도 서비스에서 다음 명령과
매시간 15분 Cron `15 * * * *`, Restart Policy `Never`를 사용한다.

```sh
python -m scripts.image_backup_jobs maintain
```

필요한 변수는 다음뿐이다. 기존 API·백업 서비스의 동일한 DB·삭제 기록·백업 Bucket을 참조한다.

```text
APP_ENVIRONMENT=production
DATABASE_URL
BACKUP_BUCKET_CONFIG_JSON
DELETION_LEDGER_BACKEND=s3
DELETION_LEDGER_S3_ENDPOINT_URL
DELETION_LEDGER_S3_BUCKET
DELETION_LEDGER_S3_REGION
DELETION_LEDGER_S3_ADDRESSING_STYLE
DELETION_LEDGER_S3_ACCESS_KEY_ID
DELETION_LEDGER_S3_SECRET_ACCESS_KEY
```

개선 `maintain`에는 `STORAGE_*`, 원본 `S3_*`, `OPERATOR_*`, `IMAGE_BACKUP_*`, AI·로그인 키가
필요 없다. DB는 점검 상태와 중복 실행 잠금에 사용한다. 백업 생성의 원본 검증은 그대로 유지한다.
첫 실행은 `passed=true`, `freshness_met=true`, `retention_overdue=0`,
`deletion_records_pruned=0`과 종료를 확인한다.

이 작업은 7일 이상 된 복구 지점과 참조되지 않는 백업 사본을 실제로 삭제한다. 사용자 삭제 후
6일이 지난 이미지를 포함한 복구 지점은 7일 기한 전에 정리 여유를 확보하려고 전체가 조기 제거될 수 있다.
삭제 기록 자체와 운영 원본의 물리 삭제 재처리는 대상이 아니다. 보류 중에는 7일 자동 정리가 보장되지 않는다.

## 읽기 전용 결과 확인과 기록

backend 디렉터리에서 설치된 Python 환경을 사용한다. 공급자 CLI 인증은 사용자의 기존 인증을 쓴다.
다음 명령은 실행·배포·병합을 하지 않고 필요한 필드만 출력한다.

```sh
python -m scripts.operator_status cron --service clipback-backup --environment production
python -m scripts.operator_status pr 104
```

Cron은 최근 5개 실행의 ID·상태·시각·소요 시간을 반환한다. PR은 커밋·충돌·리뷰 판정·CI 상태를 반환한다.
전체 서비스 메타데이터·시작 명령·공급자 stderr는 출력하지 않는다. 상태 조회 실패를 성공이나 빈 목록으로
바꾸지 않는다. PR 최종 diff·리뷰 본문은 필요할 때 별도로 읽고 공백 검사는 `git diff --check`를 사용한다.

백업 설정만 공급해 원본과 DB의 크기·SHA-256을 스트리밍으로 검사한다. 운영 DB 접속이나
로컬 DB·이미지 다운로드는 필요 없다. 아래 ID는 확인할 실제 복구 지점으로 바꾼다.

```sh
python -m scripts.image_backup verify --backup-id BACKUP_ID
```

파일 설정을 쓰는 경우:

```sh
python -m scripts.image_backup --backup-config-file /absolute/private/backup.json verify --backup-id BACKUP_ID
```

검증 결과는 저장소별 이미지 수·검증 객체 수·바이트 수·커밋·migration·삭제 checkpoint 포함 여부를
기록한다. 최신 운영 삭제 기록 검증과 격리 복원은 수행하지 않으며 해당 결과는 `false`다.
검사 도중 정리된 복구 지점은 실패할 수 있다. 성공은 검사 당시의 결과이며 이후 보존을 보장하지 않는다.

운영 작업 완료 시 [상세 이력](../history/README.md)에 비밀값 없는 결과를 저장하고 이 문서 상단의
확인 날짜·완료·미확인·보류 상태를 함께 갱신한다. 임시 경로의 보고서만을 유일한 증거로 남기지 않는다.
