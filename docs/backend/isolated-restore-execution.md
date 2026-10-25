# Mac에서 실제 점검을 확인하는 격리 복원

이 문서는 #97의 첫 수동 백업 후 격리 복원 실행 경로다. [백업·복구 안내](backup-recovery.md)와
[점검 제어](image-maintenance.md)를 함께 따른다. 명령을 제공한 것은 실제 Railway 실행 완료의 증거가 아니다.

## 실행 위치와 권한

백업은 별도 Railway 운영자에서 PostgreSQL 18 도구로 생성한다. 복원 제어기는 Mac 호스트의
Python 개발 환경에서 실행하며 이 Mac의 Docker CLI로 격리 대상을 만든다. Docker socket을 운영
서비스에 공급하지 않는다. 호스트 제어기가 SSH 터널에 접속하므로 Docker Desktop host networking을
켜거나 격리 대상에 운영 네트워크를 연결할 필요가 없다.

Mac에는 명시적으로 공급한 다음 설정이 필요하다. `.env`를 자동 읽지 않으며 키와 설정 파일 내용을
채팅·Git·보고서에 넣지 않는다.

- `DATABASE_URL`: Mac의 `127.0.0.1` SSH 전달 포트로 접속하는 운영 PostgreSQL URL.
- `OPERATOR_CONTROL_URL`: Mac의 `127.0.0.1` SSH 전달 포트로 접속하는 비공개 운영 리스너 URL.
- `OPERATOR_CONTROL_KEY`: 원본 읽기 키와 구분된 점검 제어 키.
- 기존 `DELETION_LEDGER_*`: 최신 독립 삭제 기록을 읽는 데 필요한 설정. 운영 S3 endpoint는 HTTPS.
- `APP_ENVIRONMENT=production`: 운영 모드. AI·소셜 로그인 설정이나 원본/백업 Bucket 쓰기 키는 요구하지 않는다.

Railway CLI의 실제 버전과 지원 명령을 확인하고 SSH 키 등록·터널 연결을 점검 전에 준비한다.
공식 문서의 [SSH local forwarding](https://docs.railway.com/cli/ssh)을 따른다. 예시의 서비스 식별자와
포트는 실제 준비 결과로 치환한다. SSH 키는 Mac에서만 사용하며 서버 백업 작업에 공급하지 않는다.

```sh
ssh -N \
  -L 127.0.0.1:19001:127.0.0.1:9001 \
  -L 127.0.0.1:15432:POSTGRES_PRIVATE_HOST:5432 \
  SERVICE_INSTANCE_ID@ssh.railway.com
```

설치된 구버전 CLI의 기능이 현재 문서와 다를 수 있으므로 위 명령의 지원·실제 연결을 먼저 검증한다.
새 공개 도메인·DB 공개 포트를 추가하지 않는다. 실제 SSH 세션은 서비스 쉘 권한이 있는 연결이며
제한된 원본 읽기 키와 같은 권한이라고 설명하지 않는다.

## 점검 전 준비

백업 지점을 별도 `0700` 임시 입력 폴더에 materialize한다. 원본 백업 Bucket과 운영 Volume은 그대로
보존한다. 입력 폴더는 사용자가 지정한 자료이므로 제어기가 임의 삭제하지 않는다. 제어기는 그중
필요한 manifest·DB dump·이미지 archive와 복원 인증 파일만 별도 실행 소유 폴더에 복사한다.
입력 다운로드 폴더의 최종 정리는 운영 체크리스트에서 별도로 확인한다.

백업 당시 존재한 계정의 유효한 복원 검증 자격을 기존 형식의 `0600` 파일로 준비한다. JSON 키는
`secret_key`, `access_token` 두 개다. 값은 명령 인자에 직접 넣지 않는다. 복원 인증에 필요한 이 자격만
격리 API에 사용하며 운영 DB·Bucket·점검 제어·SSH 접속 자격을 격리 대상에 전달하지 않는다.

필요한 백업 커밋의 revision 라벨이 있는 API 이미지, 같은 주 버전 `postgres:18` 및 Bucket 자산이
있다면 `motoserver/moto:5.2.4` 이미지를 미리 준비한다. 이미지를 자동 다운로드하지 않는다.
저장소 밖의 `0700` 실행 루트를 만든 뒤 backend 개발 환경에서 실행한다.

```sh
python -m scripts.restore_execution prepare \
  --backup-dir /absolute/private/downloaded-point \
  --credentials-file /absolute/private/restore-credentials.json \
  --image clipback-recovery:BACKUP_COMMIT \
  --run-root /absolute/private/restore-runs
```

`prepare`는 자격 파일의 소유자·권한, manifest·archive·해시·디스크 여유, 이미지 revision과 로컬 Docker
context, 비공개 제어 경로, 운영 DB·삭제 기록 연결을 검사한다. 실행 루트나 조상에 `.git`이 있으면
자료를 복사하지 않고 거절한다. 일반 서비스가 열린 상태에서 준비해야 하며 이 명령은 점검을 시작하지 않는다.
결과의 `run_id`와 `workspace`를 기록한다. 실행 폴더에는 작은 `0600` journal이 있으며 재시작·중복 실행으로
자동 복원을 계속하지 않는다.

## 점검과 복원

준비가 끝난 뒤 같은 `run_id`로 [점검 시작 명령](image-maintenance.md)을 수행한다. 신규 앱·변경 작업 차단과
최대 60초 동안 진행 중 작업의 종료 확인이 성공하여 `phase=frozen`이어야 한다. 실패하면 복원하지 않고
차단을 유지한 채 운영 상태를 확인한다. 수동 DB 변경 등 협력하지 않는 외부 쓰기도 중단해야 한다.

```sh
python -m scripts.restore_execution run --workspace /absolute/private/restore-runs/restore-RUN_HEX
```

`image_backup_jobs restore-check --workspace ...`도 같은 제어기를 사용한다. `--writers-frozen`만으로는
운영 복원을 실행할 수 없다. 실제 점검 상태·run ID·세대를 확인한 뒤 영속 복원 작업을 등록한다.
등록 응답을 놓쳐도 journal에 시도 사실이 남아 재개를 성공으로 처리하지 않는다. 직접 DB 터널에서도
같은 run·세대·복원 작업 ID를 확인한 뒤에만 삭제 기록 잠금을 잡고 자식을 실행한다. 제어 경로와
다른 DB에 연결된 경우 복원을 거절하고 작업 기록을 보존해 명시적 복구를 요구한다.

쓰기 중단을 확인한 뒤부터 전체 검증 예산은 최대 1,800초다. `--timeout-seconds`는 더 짧은 예산만
허용하며 단계마다 초기화하지 않는다. 제어기는 운영 DB의 삭제 기록 shared lock을 유지하면서 최신
체크포인트·이벤트를 검증한다. 자식 프로세스의 실제 Docker 복원은 격리 DB·원본의 snapshot 일치,
최신 삭제 반영, 인증된 원본 열람과 계정 격리를 확인한다. 복원된 사본의 점검 제어 기록만 초기화하며
운영 점검 상태는 바꾸지 않는다.

제어기는 실행 중 점검 상태·세대·복원 작업의 존재와 같은 DB 연결의 생존을 반복 확인한다. 제한 시간,
연결 단절, 잘못된 상태 또는 검증 실패에는 자식 프로세스 그룹을 종료·회수하고 실행 소유 라벨로 Docker
데몬의 컨테이너도 종료·확인한다. Docker CLI 프로세스가 끝났다는 사실만으로 컨테이너 종료를 판단하지 않는다.
알 수 없는 자식 생성/종료는 안전하게 끝난 것으로 표시하지 않는다.

실행 종료·컨테이너 상태와 원본 잠금 해제를 확인해야 복원 작업 기록을 종료한다. 확인할 수 없다면 기록과
점검 차단을 유지한다. 성공·실패 모두 서비스를 자동 재개하지 않는다. 30분은 전체 서비스 중단 시간이나
정리 시간 상한이 아니며 안전한 종료 확인·정리는 그 이후에도 필요할 수 있다.

## 보고서와 정리

실행 결과는 workspace 옆의 `restore-RUN_HEX.report.json`과 표준 출력으로 남긴다. 백업/run 식별자,
커밋·이미지·도구 버전, 검증 항목, 오류 분류, 자식 종료·잠금·복원 작업 종료·정리 결과를 기록한다.
키·토큰·사용자 본문·원본 파일명은 기록하지 않는다.

- `maintenance_verified`와 `live_deletion_ledger_verified`: 실제 점검·최신 삭제 기록을 확인한 검사 결과.
- `source_database_verified`: HTTP 점검 제어 경로와 직접 DB 터널이 같은 복원 작업을 가리키는지.
- `passed`: 검증과 필요한 종료·정리가 모두 확인됐는지. 실패 후 늦은 완료가 이를 성공으로 바꾸지 않는다.
- `restore_receipt_finished`: 서버의 복원 작업 종료가 확인됐는지. 거짓이면 재개 전에 추가 확인이 필요하다.
- `maintenance_resumed`: 항상 거짓이다. 재개는 운영자가 별도 수행한다.
- `cleanup_passed`, `child_stopped`, `executors_stopped`, `source_lock_released`: 정리와 안전한 종료 확인.

정상 종료와 확인된 실패는 해당 실행이 만든 임시 DB·이미지 사본·자격 사본·컨테이너·볼륨·네트워크를 정리한다.
자식의 임시 `runtime.env`도 실행 소유 임시 폴더 안에 만들어 강제 종료 뒤에 정리한다.
사용자가 제공한 입력 백업·인증 파일, 운영 원본과 백업 Bucket의 복구 지점은 삭제하지 않는다. 정리 실패나
복원 기록 종료 미확인 시 journal을 남긴다. 결과 보고서를 보고 입력 다운로드 폴더와 자격 원본의 보관/정리도
운영자가 확인한다. 대용량 사진·영상은 기본 증거로 만들지 않는다.

## 비정상 종료와 연결 상실 복구

자동 만료·자동 재개는 없다. 살아 있는 이전 제어기·자식 프로세스가 뒤늦게 작업하지 않는지 확인하고 종료한다.
journal의 controller/child PID와 실행 소유 Docker 라벨을 확인한다. PID가 아직 살아 있으면 정리 명령이
거절한다. PID 재사용 등으로 판단할 수 없는 경우 자동 우회하지 않고 운영자가 프로세스 실행 상태를 확인한다.

```sh
python -m scripts.restore_execution cleanup \
  --workspace /absolute/private/restore-runs/restore-RUN_HEX \
  --confirm-executors-stopped
```

이 명령은 지정한 실행 라벨의 자원만 확인·정리한다. 등록 응답 유실 시에도 권위 있는 서버 상태에서
같은 run의 복원 작업을 조회한다. 원본 잠금이 해제되고 실행 종료가 확인된 경우에만 복원 기록을 종료한다.
연결이 없거나 종료를 확인하지 못하면 journal을 보존하고 실패한다. 복원 기록 종료가 이미 확인된 실행의
남은 로컬 사본 정리는 서비스가 재개된 뒤에도 가능하다. 결과는 `.recovery.json`에 남긴다.

Mac을 잃은 경우에도 Railway 측의 [점검 상태·명시적 복구 명령](image-maintenance.md)으로 확인할 수 있다.
운영자는 이전 Mac 제어기·격리 컨테이너가 종료되어 더 늦게 실행하지 못하는지와 원본 DB 잠금 해제를
확인한 뒤 정확한 작업 ID로 복구한다. 단순 연결 부재나 시간 경과를 실행 종료의 증거로 사용하지 않는다.

마지막으로 운영 상태를 확인하고 같은 run의 명시적 `resume`을 실행한다. 기존 앱이 회복되는지 확인한
뒤 테스트를 재개한다. 검증 실패 후 서비스 재개와 백업 검증 재시도는 별도로 판단한다. 신규 Bucket 저장
전환·이미지 이관·정기 일정·삭제/보존 정리 가동은 이 단계에 포함하지 않는다.

## 합성·오프라인 도구의 구분

저수준 `check_backup_restore`는 운영 연결 없는 격리 도구다. `passed=true`여도
`maintenance_verified=false`, `live_deletion_ledger_verified=false`이며 운영 점검 완료를 뜻하지 않는다.
기존 `image_backup_jobs restore-check --synthetic-offline ... --writers-frozen`은 명시적으로 합성 백업만
허용하고 `maintenance_verified=false`, `synthetic_only=true`를 보고한다. 실제 운영 지점은 위 제어기로
검증하며 오래된 offline export를 최신 삭제 기록으로 간주하지 않는다.

### 실행 그룹 종료 확인

복원 리더 프로세스가 종료돼도 같은 실행 그룹의 자손이 남을 수 있습니다. 제어기는 실행 그룹 전체에 종료 신호를 보내고 남아 있으면 강제 종료한 뒤 그룹이 사라졌는지 확인합니다. 확인할 수 없으면 복원 기록·저널을 유지하며, 정리 명령도 이전 실행 그룹이 남아 있는 동안 완료로 표시하지 않습니다.
