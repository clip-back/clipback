# 첫 운영 원본 백업·격리 복원 실행 체크리스트

상태: 코드·합성 검증과 실제 운영 실행을 구분하는 인계 문서다. 아래 운영 체크 항목은 **미실행**이며,
배포·키 등록·서비스 중단·백업 실행은 검토 가능한 통합 결과를 확인하고 해당 운영 단계의 사용자
요청에 따라 진행한다. #102와 부모 #97은 실제 실행 증거가 확보되기 전까지 열린 상태로 유지한다.

범위는 기존 Volume 원본 접근 → 수동 백업 1회 → Mac 격리 복원 → 명시적 재개·정리다.
신규 Bucket 저장 전환·기존 이미지 이관·정기 실행·물리 삭제 재처리·보존 정리 가동은 후속 단계다.
일일 백업·최근 7일 복구 목표를 이미 운영 중이라고 표시하지 않는다.

## 역할과 실행 전 기록

에이전트는 통합 코드·이미지 빌드·검증 결과·명령과 오류 해석을 준비한다. 사용자는 Railway 콘솔에서
서비스·비밀값을 직접 설정하고 점검 시간을 안내한다. SSH 키·CLI 변경과 실제 운영 명령 실행은
준비가 완료된 뒤 별도 요청 범위에서 진행한다. 키·토큰·원본 파일명·사용자 본문을 채팅이나 Git에 넣지 않는다.

| 기록 | 실제 확인값 |
| --- | --- |
| 승인한 운영 실행 범위·시각·운영자 | 미기록 |
| 배포할 통합 커밋 / 실제 배포 커밋 | 미기록 / 미확인 |
| API·운영자 이미지 revision / PostgreSQL major | 미확인 / 미확인 |
| 실제 DB migration head / 기존 저장 backend | 미확인 / 미확인 |
| 원본 식별자 등록·일치 / 내부 연결·공개 차단 | 미실행 / 미실행 |
| 수동 백업 ID·완료 결과 / 복원 run ID | 미실행 / 미실행 |
| 점검 시작·종료 대기·복원·재개·정리 결과 | 미실행 |

앞선 조사 수량·DB 버전·접속 성공은 이번 실행의 확인값을 대신하지 않는다. 운영 DB 초기화·기존
삭제 기록 재초기화·기존 이미지 삭제는 준비 작업에 포함하지 않는다.

## 1. 같은 통합 버전 배포와 설정 준비

- [ ] 최종 통합 코드의 테스트·리뷰 결과와 실제 실행한 선택형 Docker 검사를 확인한다.
- [ ] API·요약 작업·운영 명령 모두 같은 통합 코드를 사용한다. 이전 배포 프로세스가 계속 변경하지 않도록 확인한다.
- [ ] 실제 DB 업그레이드가 단일 최신 head에 도달했는지 확인한다. 점검 schema 최초 추가는 `202610260020`이며 기존 업무 자료를 유지한다.
- [ ] API의 기존 Volume·`STORAGE_ROOT`·`STORAGE_BACKEND=local`을 유지한다. API에 백업 Bucket 키를 공급하지 않는다.
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
공개 도메인·Cron·원본 Volume·Docker socket을 붙이지 않는다. restart policy는 **Never**로 두고
수동 실행의 종료 코드와 결과를 확인한다. 실패한 작업을 자동 재시작으로 숨기지 않는다.
서비스 Root Directory를 `backend`로 지정했다면 Dockerfile 경로는 `Dockerfile.operator`로 설정한다.
API의 pre-deploy migration·HTTP start command·healthcheck를 운영자에 복사하지 않는다. DB migration은
먼저 API 배포에서 완료한다. 운영자 서비스의 자동 Git 배포도 비활성화해 코드 push가 백업 실행을
유발하지 않도록 하고, 검증한 버전의 수동 실행만 시작한다.

| 운영자 설정 | 공급 내용 |
| --- | --- |
| `DATABASE_URL` | 같은 운영 PostgreSQL의 실제 내부 연결 |
| `STORAGE_ROOT`, `STORAGE_BACKEND` | 명시적 절대 경로와 `local`; 이 경로를 실제 Volume mount로 취급하지 않음 |
| `OPERATOR_SOURCE_URL` | API의 실제 내부 주소와 운영자 포트 |
| `OPERATOR_SOURCE_ID`, `OPERATOR_READ_KEY` | API와 같은 원본 식별·읽기 권한 |
| `DELETION_LEDGER_*`, `APP_ENVIRONMENT=production` | 기존 독립 삭제 기록을 읽는 설정; 새 namespace 초기화 금지 |
| 원본 `S3_*` | 백업에 기존 S3 자산이 포함되는 경우에만 해당 원본을 읽는 설정 |
| 백업 설정 JSON | 원본과 다른 비공개 백업 Bucket의 endpoint·bucket·region·addressing_style·키 |
| `IMAGE_BACKUP_ID`, `IMAGE_BACKUP_APP_COMMIT` | 이번 고유 백업 ID와 실제 원본 API의 전체 40자 커밋 |

운영자에는 점검 제어 키·SSH 키·AI·소셜 로그인 비밀값을 요구하지 않는다. 서비스의 백업 설정 파일은
`0600`이어야 한다. Railway에서 파일을 미리 전달할 실행 경로가 없다면, 콘솔 비밀 변수
`BACKUP_BUCKET_CONFIG_JSON`으로 JSON을 공급하고 다음 start command로 실행 소유 임시 파일을 만든다.
Railway의 Docker [start command](https://docs.railway.com/deployments/start-command)는 이미지 ENTRYPOINT를 대체한다.
아래 Python 코드가 환경변수를 읽으므로 쉘에서 비밀값을 명령 인자로 펼치지 않는다. JSON 필드는
[백업 설정 계약](backup-recovery.md)을 따른다.

```sh
python -c '
import os, sys, tempfile
raw = os.environ.pop("BACKUP_BUCKET_CONFIG_JSON")
with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as config:
    config.write(raw)
    name = config.name
os.execvp(sys.executable, [sys.executable, "-m", "scripts.image_backup_jobs", "manual",
    "--backup-config-file", name,
    "--backup-id", os.environ["IMAGE_BACKUP_ID"],
    "--app-commit", os.environ["IMAGE_BACKUP_APP_COMMIT"], "--origin", "production"])
'
```

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
