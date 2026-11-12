# DB·이미지 백업의 격리 복원 검증

운영 백업의 읽기 전용 입력으로 새 로컬 Docker 자원에 복원하는 도구입니다.
운영 접속·서비스 중지·백업 다운로드·운영 복구 전환은 수행하지 않습니다.
운영 절차는 [Railway 안내](../railway-deployment.md), 실제 결과는
[작업 이력](../history/2026-10-22-production-recovery.md)을 따릅니다.

## 첫 수동 백업: 삭제·보존 정리 없는 종료형 명령

운영자 이미지는 기본 PostgreSQL 18 도구를 사용합니다. 실제 source DB major와 다르면
빌드 인자로 맞추며 버전 불일치 시 덤프를 시작하지 않습니다.

```sh
docker build -f backend/Dockerfile.operator -t clipback-image-operator:SOURCE_SHA backend
docker run --rm --env-file /absolute/private/operator.env \
  -v /absolute/private/backup-bucket.json:/run/backup.json:ro \
  clipback-image-operator:SOURCE_SHA manual \
  --backup-config-file /run/backup.json --backup-id UNIQUE_BACKUP_ID \
  --app-commit FULL_40_CHARACTER_SOURCE_SHA --origin production
```

운영 Volume 백업은 [식별된 비공개 원격 원본](image-operator-source.md)의 설정 세 값을
필수로 공급합니다. 별도 Railway 서비스에 같은 경로를 지정해도 API Volume을 공유하지 않습니다.
자산이 없어도 원본 식별 확인을 생략하지 않으며, 원격 설정 없이 빈 경로로 실행하면 실패합니다.
직접 로컬 파일을 읽는 합성 검증은 `APP_ENVIRONMENT=test` 또는 `local`에서만 수행합니다.

`operator.env`에는 `DATABASE_URL`, 절대 경로 `STORAGE_ROOT`, `STORAGE_BACKEND`, 원격 원본 설정과 사용 중인
원본/독립 삭제 기록 저장소의 설정만 공급합니다. 실제 DB·원본·삭제 기록의 접속 요건은 유지하되
`manual`·`daily`·`maintain`은 `SECRET_KEY`, AI·소셜 로그인 설정을 요구하지 않습니다.
앱 API는 기존 전체 설정 검증을 유지합니다. 비밀값을 argv·Git·보고서에 넣지 않습니다.
백업 Bucket 자격 파일은 기존 `0600`·실행 사용자 소유 규칙을 따릅니다.

`manual`은 live 삭제 기록과 연동한 exported DB snapshot 및 원본 물리 삭제 보호를 유지하며
복구 지점만 생성하고 종료합니다. `daily`도 백업 생성만 하며 같은 UTC 날짜의 완료 지점은 다시
생성하지 않습니다. `maintain`은 백업 보존 정리만 수행합니다. 원본 삭제 재처리는 별도
`python -m scripts.image_deletions retry`로 명시적으로 실행하며 이 명령의 기존 전체 설정
요건을 유지합니다. 백업을 시작했다는 이유로 삭제 재처리·보존 정리가 실행되지 않습니다.

종료형 Railway 서비스는 위 이미지의 start 인자로 `manual --backup-config-file ...`을
지정하고 자동 재시작 없이 종료 상태와 JSON 결과를 확인합니다. 공개 도메인·Cron은 추가하지
않습니다. API에는 백업 자격을 주지 않습니다. 이 문서는 서비스를 생성하거나 실행하지 않습니다.

성공 보고의 `passed`, `backup_id`, `asset_count`, `backup_created`는 생성 결과이며
`restore_verified: false`입니다. 격리 복원 성공을 의미하지 않습니다. 실패는 0이 아닌 종료
코드와 비밀값 없는 오류 분류를 남깁니다. `original_missing`, `original_read_failed`,
`original_hash_mismatch`, `database_dump_failed`, `operator_configuration_invalid` 등으로
구분하고, 실패한 지점의 완료 manifest는 게시하지 않습니다. 중간 보관본은 별도 정리 전까지
남을 수 있으며 수동 백업이 이를 지우지 않습니다.

## Bucket 원본의 수동 백업과 v2 복구 지점

`backend/scripts/image_backup.py`는 DB와 `local`·`s3` 원본을 함께 백업하는 **운영자 전용**
명령입니다. 원본과 다른 비공개 백업 Bucket을 준비하고, 별도 운영자 환경에서 실행합니다.
일반 API의 `Settings`에는 백업 자격 항목이 없으며 API 서비스에 이 자격 파일을 배포하지 않습니다.
동일 endpoint의 원본 Bucket을 백업 대상으로 쓰면 거부합니다. 실제 Railway 자격의 권한 분리는
배포 시 별도로 확인해야 하며 로컬 S3 대역 검사가 공급자 IAM을 검증하지는 않습니다.

백업 설정 파일은 저장소 밖 `0600`, 소유자는 실행 사용자여야 합니다. 필드는 다음과 같습니다.
자격을 argv·로그·manifest에 넣지 않습니다. HTTPS를 사용하며 로컬 대역 서버의 loopback HTTP만
검사용으로 허용합니다. `region` 기본값은 `auto`, `addressing_style` 기본값은 `virtual`입니다.

```json
{"endpoint_url":"https://PRIVATE_ENDPOINT","bucket":"PRIVATE_BACKUP_BUCKET","region":"auto","addressing_style":"virtual","access_key_id":"PRIVATE_VALUE","secret_access_key":"PRIVATE_VALUE"}
```

원본 API·worker·배치 등 **모든 쓰기 주체를 먼저 중지**하고 source DB·원본 환경을 명시합니다.
`--writers-frozen`은 실제 중지 사실에 대한 운영자 확인이며 명령이 서비스를 중지하지 않습니다.
시험 계정의 `content_id`, `asset_id`만 담은 별도 sample JSON을 준비합니다.
원본 DB와 같은 주 버전의 `pg_dump`를 사용합니다. 다르면 dump 전에 거부합니다.
다음 명령은 `backend/`에서 실행합니다.

```sh
YOUTUBE_SUMMARY_ENABLED=false .venv/bin/python -m scripts.image_backup \
  --backup-config-file /absolute/private/backup-bucket.json create \
  --backup-id UNIQUE_BACKUP_ID --sample-file /absolute/private/sample.json \
  --app-commit FULL_40_CHARACTER_SOURCE_SHA --origin production --writers-frozen \
  --pg-dump /absolute/path/to/pg_dump
```

명령은 PostgreSQL shared session advisory lock `74264001`을 잡고, exported repeatable-read
snapshot을 원본 목록·건수 조회와 `pg_dump`가 공유하게 합니다. 같은 lock을 따르는 원본 물리 삭제와
경합하지 않지만, 초기 수동 경로에서 쓰기 중지 요구를 대신하지 않습니다. 원본은 재인코딩하지 않고
실제 바이트의 크기·SHA-256을 확인합니다. DB 메타데이터가 있으면 그것과도 대조합니다.

백업 Bucket에는 다음을 보관합니다.

- `originals/sha256/<sha256>`: 변경 없는 바이트를 복구 지점 간 재사용하는 불변 보관본
- `points/<backup_id>/database.dump`: 해당 snapshot의 DB dump
- `points/<backup_id>/manifest.json`: 모든 사본을 다시 읽어 확인한 **후 마지막으로** 게시하는 완료 표식

서비스 원본은 기존의 계정별 저장 요청·키를 유지합니다. 이 재사용은 백업 내부 최적화입니다.
완료된 backup ID는 덮어쓰지 않습니다. 중간 실패의 원본 보관본·dump는 남을 수 있으나 완료 지점으로
나열되지 않습니다. 완료 표식은 이름이 정확히 `manifest.json`인 객체뿐이며, `manifest.json` 없이
`manifestXjson`처럼 비슷한 이름의 객체만 있는 지점도 중단된 지점으로 보고 하루 뒤 정리합니다.
동시 운영자는 서로 다른 ID를 사용해야 합니다. 보존 정리는 후속 정책을 따릅니다.

v2 manifest는 v1의 기준 메타데이터에 `assets[].content_id`, `storage_backend`, `backup_key`와
`database.backup_key`, 선택적 `deletion_checkpoint`를 추가합니다. 비밀값·접속 URL은 포함하지 않습니다.
`backup_key`는 원본 해시와 대응합니다. 기존 `format_version: 1` 입력도 계속 읽습니다.
v2는 DB에서 참조하는 원본만 보관하며 미참조 파일까지 보존하는 기존 v1 archive와 구분합니다.

복원 검사는 먼저 새 비공개 폴더에 완료 지점을 내려받습니다.

```sh
YOUTUBE_SUMMARY_ENABLED=false .venv/bin/python -m scripts.image_backup \
  --backup-config-file /absolute/private/backup-bucket.json download \
  --backup-id UNIQUE_BACKUP_ID --directory /absolute/private/NEW_DOWNLOAD_DIRECTORY
```

실제 원본·DB의 크기·해시가 다르거나 사본이 없으면 실패하며, 부분 다운로드를 완료 입력으로
사용하지 않습니다. manifest가 [v2 복구 지점 manifest](#v2-복구-지점-manifest) 계약에 어긋나면
폴더를 만들기 전에 `invalid_manifest`로 실패하므로 폴더가 남지 않습니다.
다운로드 폴더는 새로 생성하며 기존 폴더를 덮어쓰지 않습니다. 결과의
`database.dump`, `images.tar`, `manifest.json`을 아래 기존 격리 검사 명령에 전달합니다.
tar에는 local 원본은 `screenshots/<key>`, Bucket 원본은 `s3/<key>`로 담습니다.
검사는 입력을 바꾸지 않고 내부 Docker moto Bucket에 원본을 복원한 뒤 실제 인증 GET과 모든
원본 해시를 확인합니다. `motoserver/moto:5.2.4` 이미지를 사전에 준비해야 하며 외부 endpoint는
받지 않습니다. Bucket 대역은 HTTP 때문에 `APP_ENVIRONMENT=test`로 실행합니다.

**이 단일 지점 검사 결과는 `deletions_applied: false`입니다.** 삭제 상태를 보장하려면 아래의
일일 백업·보존과 최신 삭제 기록 복원 경로를 사용합니다. 이 명령만으로 운영 DB를 되돌리거나 서비스 트래픽을
전환하지 않습니다. 이번 실제 합성 검증과 한계는
[Bucket 백업 작업 이력](../history/2026-10-23-image-storage-backup.md)에 기록합니다.

기존 local 원본을 Bucket으로 옮길 때에는 실제 최신 삭제 반영 복원 검사를 먼저 완료하고
[원본 이관 절차](image-migration.md)의 manifest SHA로 묶인 성공 보고서를 사용합니다.

## 일일 백업과 시간별 보존 작업

`scripts.image_backup_jobs`는 운영자 전용입니다. 원본 API와 동일한 DB·원본 저장소 및 독립된
삭제 기록 환경을 사용하고, 백업 Bucket 자격 파일만 별도로 받습니다. 원본이 local이면 API와
실제 같은 원본 디렉터리를 공유해야 합니다. 복사해 둔 오래된 디렉터리를 지정하면 안 됩니다.
원본·삭제 기록·백업 Bucket이 모두 준비되어야 하며 누락된 삭제 기록을 빈 기록으로 초기화하지 않습니다.

이 경로는 API를 중지했다고 가정하지 않습니다. 삭제 기록 shared SESSION lock `74264002`를
먼저 잡고 원본 물리 정리 shared SESSION lock `74264001`을 잡아 DB snapshot을 내보냅니다.
namespace·head·tip만 읽어 checkpoint를 잡은 직후 삭제 기록 lock을 풀고, 그 불변 prefix 전체를
검증합니다. 긴 이력 검증과 전체 백업 때문에 DELETE 응답이 SQL lock에서 기다리지 않게 합니다.
DB dump와 원본 사본 확인이 끝날 때까지 물리 정리 lock만 유지합니다. 변경 불가능한
원본 키, 같은 exported DB snapshot, 이 lock을 따르는 물리 정리가 온라인 일관성의 전제입니다.
이전 코드나 수동 운영자가 lock 없이 원본을 지우는 동안의 일관성을 보장하지 않습니다.

```sh
YOUTUBE_SUMMARY_ENABLED=false .venv/bin/python -m scripts.image_backup_jobs daily \
  --backup-config-file /absolute/private/backup-bucket.json \
  --app-commit FULL_40_CHARACTER_SOURCE_SHA --origin production \
  --pg-dump /absolute/path/to/pg_dump

YOUTUBE_SUMMARY_ENABLED=false .venv/bin/python -m scripts.image_backup_jobs maintain \
  --backup-config-file /absolute/private/backup-bucket.json
```

Railway Cron 서비스에서 **매일 UTC 00:00에 daily**, **매시간 15분에 maintain**을 실행합니다.
두 명령은 PostgreSQL session lock `74264003`으로 직렬화하며 이미 실행 중이면 nonzero로 종료합니다.
수동 create도 같은 job lock을 사용해 GC와 부분 업로드가 경합하지 않게 합니다.
같은 UTC 날짜의 `daily-YYYY-MM-DD` 완료 지점은 다시 만들지 않습니다. 실패한 미완료 지점은
같은 날짜에 재시도할 수 있습니다. 실패는 종료 코드 1이며, Railway가 "Deploy Crashed" 메일을 보냅니다.
운영자는 Railway Notifications에서 이 메일이 켜져 있는지 확인합니다. 명령이 Railway Cron이나 알림을
자동 생성하지 않습니다. 정기 작업이 아예 돌지 않을 때(Cron 꺼짐 등)는 메일이 오지 않습니다.
고정 오류 코드(`invalid_manifest` 등)로 끝나면 출력은 지금처럼 `passed`·`error` 두 키입니다. 그 밖의
예외로 끝나면 `error`는 `backup_job_failed`이고, `exception`(예외 클래스 이름)과 `cause`(직접 원인의
클래스 이름, 없으면 `null`)를 함께 출력합니다. 예: `{"cause": "ReadTimeoutError", "error": "backup_job_failed",
"exception": "LedgerUnavailableError", "passed": false}`. 메시지·URL·키·Bucket 이름은 출력하지 않습니다.
`daily`·`manual`·`maintain`은 삭제 기록을 읽을 때 연결 3초·응답 10초 제한으로 객체마다 최대 4번(첫 시도와
재시도 3번) 시도합니다. 계속 응답이 없으면 객체 하나에 최대 52초 뒤 그 실행 전체가 실패합니다. API의 삭제
처리와 다른 운영 명령(`restore-check`·`image_backup create` 등)은 연결 1초·응답 2초, 1번 시도 그대로입니다.
서비스 설정과 첫 실행 확인은 [운영 실행 체크리스트](image-operator-first-run.md#일일-백업과-보존-정리-cli-개선-이미지-배포-후)를 따릅니다. 성공 시 최근 완료 snapshot 이후 최대 하루치 손실을 목표로 합니다.
최근 지점이 24시간보다 오래되면 `freshness_met: false`, 전체 `passed: false`입니다.

백업 생성(`daily`)·백업 보존 정리(`maintain`)·원본 삭제 재처리(`image_deletions retry`)는
각각 별도 명령입니다. 백업 생성에 원본 삭제 권한을 부여할 필요는 없습니다. 원본 삭제 재처리는
API 이미지로 만든 별도 Railway Cron 서비스가 매시간 45분에 실행합니다([원본 삭제](image-deletion.md#운영-재시도)).
실제 정기 일정·실패 알림·복원 검증 전에는 일일 복구 및 7일 제거 목표를 운영 중이라고 표시하지 않습니다.

완료 시각 기준 **7일 − 1시간** 이상인 복구 지점을 만료시키고(매시간 정리여도 지점이 7일을 넘기지 않게),
사용자 삭제 intent 이후 **6일**이 지난 원본을 참조하는 지점도 만료시킵니다. DB commit이 불확실해 삭제 intent 이후에 생성된 지점에 그 원본이
남아 있는 경우도 포함합니다. 먼저 `gc/points/<id>.json`에 불변 원본 identity를 가진 작은 정리
receipt를 검증해 보관하고, 완료 manifest를 내린 뒤 지점 dump와 미참조 원본을 삭제합니다.
모든 정리가 확인된 뒤 receipt를 지웁니다. manifest 제거 후 실패해도 hash가 없던 legacy 삭제의
원본 연결과 기한을 잃지 않습니다. 정리 중인 ID는 새 지점으로 재사용하지 못합니다. 원본 삭제는
실제 HEAD 부재를 확인합니다. 변경 없는 원본은 hash별 한 사본을 지점 간 재사용합니다.
중단된 지점의 하루 이상 된 잔여 파일도 정리합니다. 삭제 기록은 복구에 필요하므로 지우지 않습니다.
유지할 지점의 dump·원본 존재와 크기를 HEAD로 확인하며 누락·크기 손상은 성공으로 보고하지
않습니다. 전체 바이트 SHA 검사는 게시 시와 복원 다운로드 시 수행합니다. 시간별 작업이 매번
모든 DB dump를 내려받지는 않으므로 같은 크기의 손상 검출은 다음 게시/격리 복원 검증와 구분합니다.

6일 기준은 시간별 재시도에 하루의 여유를 둡니다. 실제로 삭제 후 7일에 도달한 사본이 발견되면
정리를 마쳐도 그 실행은 `retention_overdue`와 `passed: false`로 목표 미충족을 보고합니다.
이 보고 기준은 복구 지점 보존 기준과 달리 7일 그대로입니다.
다른 살아 있는 원본이 정확히 같은 바이트를 참조하면 공통 사본 자체는 보존합니다. 삭제한 사용자의
과거 복구 참조는 제거됩니다. 다른 계정의 유효한 원본을 함께 지우지는 않습니다.

회원 탈퇴 기록에 든 원본도 같은 6일 조기 정리와 7일 기한 초과 보고 대상입니다. 탈퇴 기록 뒤 DB 삭제가
실패하고 다시 시도하기 전에 저장된 이미지는 기록에 없으므로 이 대상이 아니며, 그 원본을 담은 지점은
완료 시각 기준 7일 − 1시간 보존 기준으로 사라지고 기한 초과로 보고되지 않습니다. 링크 콘텐츠·계정 DB 행과 같은 처리입니다.

API 이미지는 operator 스크립트·pg_dump를 포함하지 않습니다. 스케줄용 전용 이미지는 source DB와
같은 주 버전으로 빌드합니다. 기본값은 18이며 실제 버전이 다르면 바꿉니다.

```sh
docker build -f backend/Dockerfile.operator --build-arg POSTGRES_MAJOR=18 \
  -t clipback-image-operator:SOURCE_SHA backend
```

이 이미지의 entrypoint는 `python -m scripts.image_backup_jobs`입니다. 스케줄러의 start command로
위 `daily` 또는 `maintain` 인자들을 지정합니다. 원본 DB·Bucket·삭제 기록 환경은 작업 서비스에,
`0600` 백업 자격은 작업 사용자 소유의 별도 파일로만 공급합니다. API 서비스에는 백업 자격을
주지 않습니다. 전용 이미지는 백업 작업용이며 Docker socket/CLI를 운영 서비스에 연결하지 않습니다.
이미지는 `YOUTUBE_SUMMARY_ENABLED=false`를 기본 제공합니다. 백업·보존 명령의 최소 설정은
위 수동 백업 안내를 따릅니다. API와 실제 원본 삭제 재처리의 기존 전체 설정 요건은 유지합니다.

## 최신 삭제 기록을 반영한 격리 복원

운영 복원은 [Mac 점검 확인·제한 시간 내 격리 복원](isolated-restore-execution.md)의
`prepare → 점검 확인 → run → 명시적 재개` 절차를 사용합니다. 실제 점검 상태·실행 ID·세대를
검증하고 최신 삭제 기록 lock을 유지하며 전체 검증을 최대 30분으로 제한합니다. 자식과 Docker
데몬 자원의 종료가 확인되기 전에는 복원 작업을 종료하거나 재개 성공으로 표시하지 않습니다.

`--writers-frozen`만으로 운영 복원을 실행할 수 없습니다. 기존 호출 형식은
`--synthetic-offline`을 함께 지정한 합성 백업 시험에만 허용합니다. 해당 모드는
`maintenance_verified: false`, `synthetic_only: true`이며 실제 점검의 증거가 아닙니다.
저수준 오프라인 복원 도구 역시 실제 점검이나 최신 삭제 기록을 확인했다고 표시하지 않습니다.

원본 DB의 shared SESSION lock `74264002`를 검사 전체에 유지한 채 live head와 연결된 모든 기록을
직접 검증합니다. 같은 namespace, backup checkpoint 이후로 후퇴하지 않은 sequence와 유효한
과거 prefix가 필요합니다. 누락·손상·다른 namespace·후퇴한 기록, checkpoint 없는 v1/v2 지점은
삭제 보장 복원에 실패합니다. 오래된 offline export만으로 최신성을 주장하지 않습니다.

격리 DB·원본을 복원한 직후 **삭제 전 snapshot 기준을 먼저 비교**합니다. 그 뒤 owner·content ID·
saved_at·불변 원본 키가 일치하는 최신 삭제를 적용하고 나서 API를 시작합니다. local/S3는
보관 위치이며 legacy NULL size/hash 보강도 새 원본으로 보지 않습니다. hash/size가 양쪽 모두
알려진 경우의 충돌은 다른 원본으로 보호합니다. 실제 복원된 backend로 물리 정리합니다. 숫자 ID가
재사용된 다른 원본은 지우지 않습니다. 삭제된 콘텐츠·binary·access descriptor의 인증 GET이
404인지 확인합니다. 원본이 하나도 없으면 실제 `users/me` 인증 조회는 확인하되 이미지 GET은
`image_get_skipped: true`, `image_bytes_passed: false`로 보고합니다. 빈 서비스나 삭제된 시험
sample 때문에 일일 백업이 중단되지 않으며, 남은 원본이 있으면 새 sample을 고릅니다.

회원 탈퇴 기록([ADR 0008](../adr/0008-account-deletion-ledger-record.md))도 기록 순서대로 같은 단계에서
반영합니다. 계정 번호와 계정 생성 시각이 둘 다 맞는 계정만 이미지·링크 콘텐츠, 이벤트, 추천 기록,
계정 소유 카테고리, 태그, 세션, 소셜 연결과 함께 지웁니다. 번호가 재사용된 다른 계정은 남깁니다.
그 계정의 이미지 콘텐츠마다 이미지 삭제와 같은 정리 작업을 만들어 물리 정리하고, 지운 콘텐츠는 삭제된
콘텐츠 목록에 들어갑니다. 반영 소스는 백업 시점의 옛 API 이미지에서 돌기 때문에 그 이미지의 기록 검증이나
새 모듈 없이 탈퇴 기록을 직접 처리합니다. 그래서 이 기능 이전에 만든 복구 지점도 복원할 수 있습니다.

탈퇴 기록을 반영한 복원은 다음처럼 판정합니다. 반영 전 snapshot이 manifest와 맞는지 보는 사전 검사는 그대로입니다.

- 반영 전에 복원된 DB에서 탈퇴 기록과 계정 번호·생성 시각이 둘 다 맞는 계정을 찾아 둡니다. 이 계정이 이번 반영으로 지운 계정입니다.
- 반영 뒤 API와 별개로 DB를 직접 읽어, 지운 계정 번호의 계정 행과 그 계정을 참조하는 모든 표의 행이 0개인지 확인합니다.
  콘텐츠·이벤트·추천·카테고리·태그·세션·소셜 연결이 여기에 들어갑니다. 하나라도 남으면 실패입니다.
- 자격 파일의 접근 토큰 계정이 지운 계정이면 `users/me`와, 그 계정 것을 포함한 삭제 콘텐츠·원본·access descriptor
  경로가 모두 401이어야 통과합니다. 200이면 실패입니다. 토큰 계정은 같은 `secret_key`로 서명을 확인하고 API 인증과 같은 claim 규칙(`sub`·`sid`·`exp`)을 통과한 토큰의 계정 번호로 정합니다.
  이때 원본 열람 확인은 건너뛰고 `image_get_skipped: true`, `image_bytes_passed: false`로 보고합니다.
- 토큰 계정이 지워지지 않았으면 기존처럼 그 계정의 인증·콘텐츠·원본 열람과 삭제 경로의 404를 확인합니다.
- 모든 계정이 지워진 복구 지점도 토큰 계정의 401과 DB 0개 확인으로 통과하며, 원본 열람은 건너뛴 것으로 보고합니다.

결과에는 `deleted_account_count`(이번 반영으로 지운 계정 수)와 `token_account_deleted`(토큰 계정이 지워져
401을 확인했는지)가 더해집니다. 원본 열람까지 확인하려면 탈퇴하지 않은 계정의 토큰을 자격 파일에 넣습니다.
[이미지 이관](image-migration.md)에 쓰는 복원 결과는 `image_bytes_passed: true`가 필요하므로 이 경우에 해당합니다.

`live_deletion_ledger_verified: true`는 이 격리 검사 구간의 결과입니다. 도구는 트래픽을 열지 않으며
종료 시 lock을 반환합니다. 실제 복구 전환까지 쓰기 중지를 유지해야 합니다. 중간에 쓰기를 재개했다면
최신 기록을 다시 적용·검증해야 합니다. 한 공급자/계정 전체 손실, 악의적인 전체 ledger rollback을
탐지하는 기능은 아닙니다. 실제 Railway 권한·스케줄·운영 복구 전환은 별도로 검증합니다.

복원 다운로드는 운영자 임시 사본입니다. 성공·실패 모두 종료 후 해당 임시 폴더를 제거하고,
7일을 넘겨 보관하지 않습니다. 도구는 임의 위치의 사용자 파일·다른 백업을 탐색해 삭제하지 않습니다.

## 준비와 실행

`backend/`에서 module로 실행합니다(`python3 -m scripts.check_backup_restore`). 이 도구는
`scripts.operator_errors`·`scripts.recovery_point`를 import하므로 파일 경로로 직접 실행하지 않습니다.
Docker는 이 Mac의 Unix socket을 사용하는 로컬 context여야 합니다.
백업과 같은 PostgreSQL 주 버전의 공식 `postgres:<major>` 이미지와, 백업 SHA의 제품 코드로 빌드한
백엔드 이미지를 미리 준비합니다. 도구는 이미지를 자동 다운로드하거나 migration을 실행하지 않습니다.
PostgreSQL 18부터 바뀐 공식 이미지의 볼륨 루트도 구분합니다.

이미지에는 `org.opencontainers.image.revision=<백업의 전체 40자리 SHA>` 라벨이 필요합니다.
라벨만 임의로 바꾸어 호환성을 주장하지 말고, 해당 SHA의 소스를 별도 디렉터리에서 빌드합니다.
빌드에 `.env`나 운영 백업을 포함하지 않습니다. 원래 운영 이미지와 소스 재빌드 이미지의 digest는
다를 수 있으며 같은 바이너리로 보고하지 않습니다.

```sh
cd backend
python3 -m scripts.check_backup_restore \
  --backup-dir "/absolute/private/backups/BACKUP_ID" \
  --credentials-file "/absolute/private/secrets/restore-credentials.json" \
  --image clipback-recovery:BACKUP_SHA
```

`--backup-dir`에는 `manifest.json`, `database.dump`, `images.tar`가 필요합니다.
`images.tar`는 API 볼륨 `/data`의 **내용**을 기준으로 하므로 `screenshots/<storage_key>`를
포함합니다. 이미지 디렉터리 하나만 다른 깊이로 묶지 않습니다.
백업 세트는 `/Users/leehyeongyu/Library/Application Support/Clipback/backups/<backup-id>/`처럼
저장소·공유 폴더 밖에 보관합니다. 디렉터리는 `0700`, 파일은 `0600`으로 제한합니다.
검증된 세트는 보존하며 이 도구는 기존 백업을 삭제하지 않습니다.

별도의 `0600` 자격 파일은 아래 두 필드만 가집니다. 실제 값을 명령행·문서·로그에 넣지 않습니다.
같은 `SECRET_KEY`와 백업 안에 남아 있는 유효한 **시험용 게스트 access token**을 사용합니다.
도구는 token 재발급·세션 갱신·소셜 인증을 하지 않습니다. 유효기간 초과는 새 백업 준비가 필요한
인증 검사 실패이며 복원 성공으로 간주하지 않습니다. 토큰 계정이 그 뒤 탈퇴했다면 삭제 기록을 반영하는 복원에서
401 확인으로 통과하지만 원본 열람은 건너뜁니다(위 "탈퇴 기록을 반영한 복원" 판정).

```json
{"secret_key": "PRIVATE_VALUE", "access_token": "PRIVATE_VALUE"}
```

## 백업 manifest 계약

`format_version: 1`에서 다음 필드를 사용합니다. 일반 DB dump만 보고 expected 값을 만들지 말고,
**원본 쓰기가 중지된 같은 구간**에 원본 DB와 내보낸 이미지의 기준 자료를 확보합니다.

| 필드 | 값 |
| --- | --- |
| `backup_id` | 영문·숫자·점·밑줄·하이픈 1~100자로 된 세트 식별자. `.`·`..`는 쓸 수 없음 |
| `origin` | 운영 자료는 `production`, 합성 테스트 자료는 `synthetic` |
| `captured_at` | 시간대를 포함한 ISO 8601 기준 시각 |
| `app_commit` | 원본 배포의 전체 40자리 SHA |
| `postgres_major` | 원본 DB의 PostgreSQL 주 버전 |
| `database`, `images` | 각각 고정 `file` 이름, `size_bytes`, `sha256` |
| `migration_revisions` | 정렬한 `alembic_version.version_num` 배열 |
| `tables` | public schema의 실제 테이블별 정확한 행 수 |
| `category_links_sha256` | `[content_id, category_id]` 정렬 배열의 정규 JSON SHA-256 |
| `assets` | ID순의 `id`, `storage_key`, `size_bytes`, `sha256` 배열 |
| `sample` | 시험 `content_id`, `asset_id`, `saved_at`, `category_ids`, `content_sha256` |
| `extra_file_count` | 선택적 미참조 파일 수. 파일을 삭제하거나 성공 여부의 근거로 사용하지 않음 |

해시는 소문자 64자리입니다. JSON 정규화는 `sort_keys=True`, `separators=(',', ':')`,
`ensure_ascii=True`입니다. 비밀값·접속 URL 필드는 manifest에 허용하지 않습니다.

`backend/scripts/recovery_probe.py`는 이 기준 자료의 `migration_revisions`·`tables`·
`category_links_sha256`·`assets`·`sample`·`extra_file_count`를 생성합니다.
`sample.content_sha256`는 콘텐츠 ID·유형·출처·제목·요약·원본 URL·즐겨찾기·저장/열람 시각의
projection이며 시각은 UTC ISO로 정규화합니다. 실제 콘텐츠 문구 대신 해시를 보관합니다.

원본 capture는 사용 중인 배포의 DB·파일 사본을 읽을 수 있는 비공개 환경에서
`DATABASE_URL`, `STORAGE_ROOT`를 명시하고 `YOUTUBE_SUMMARY_ENABLED=false`로 실행합니다.
입력 JSON은 stdin의 `{"sample":{"content_id":1,"asset_id":1},"verify_api":false}` 형태입니다.
원본 API는 중지되어 있으므로 이 모드에서는 HTTP를 사용하지 않습니다.
출력은 `0600` 파일로만 받고 DB·이미지 파일 크기/해시와 배포 정보를 추가해 manifest를 구성합니다.
`verify_api=false`는 원본 자료 생성용이며 복원 도구는 항상 실제 인증 GET까지 확인합니다.
원본 capture나 probe를 일반 테스트 DB 준비·migration 명령과 혼용하지 않습니다.

### v2 복구 지점 manifest

백업 Bucket의 `points/<backup_id>/manifest.json`과 정리 receipt `gc/points/<backup_id>.json`은
`format_version: 2` 게시 manifest입니다. 위 표에서 `images`를 빼고 아래 필드를 더합니다.
`download`는 이 manifest에 `images` 항목만 더해 다운로드 폴더의 `manifest.json`으로 씁니다.

| 필드 | 값 |
| --- | --- |
| `format_version` | `2` |
| `backup_id` | 읽으려는 지점의 ID와 같은 값 |
| `database.backup_key` | `points/<backup_id>/database.dump` |
| `assets[].content_id` | 양의 정수 |
| `assets[].storage_backend` | `local` 또는 `s3` |
| `assets[].backup_key` | `originals/sha256/<sha256>` |
| `deletion_checkpoint` | 선택. 생성 시점의 삭제 기록 checkpoint |

게시 manifest와 다운로드 폴더의 manifest는 복구 지점 module(`backend/scripts/recovery_point.py`)의
같은 기준으로 검사합니다.

- 위 두 표에 없는 최상위 필드는 거부합니다. 게시 manifest의 `images`도 거부합니다.
  `extra_file_count`·`deletion_checkpoint`만 생략할 수 있습니다.
- 필수 필드가 없거나 JSON 형식이 다르면(문자열 자리의 null·숫자·불리언·배열·객체 등) 거부합니다.
- `database.size_bytes`는 양의 정수, asset `size_bytes`는 0 이상의 정수입니다.
  해시는 소문자 64자리 문자열이고 `captured_at`·`sample.saved_at`에는 시간대가 있어야 합니다.
- asset `id`는 서로 다른 양의 정수입니다. `storage_key`는 빈 값·절대 경로·`..`·역슬래시가 없는 상대 경로이며,
  POSIX 경로로 정규화한 문자열과 글자가 같고 `.`이 아니어야 합니다. 따라서 `u/./1.png`·`./u/1.png`·`u//1.png`·`u/1.png/`·`.`은
  거부합니다. 업로드는 `screenshots/<user_id>/<uuid4 hex>.<확장자>` 형식의 키만 만들어 이런 키가 생기지 않으며,
  생기면 `maintain`이 `invalid_manifest`로 멈춥니다.
  `sample`은 asset이 없을 때만 `null`이며, 있으면 `sample.asset_id`가 asset 목록에 있어야 합니다.
- asset의 tar 경로(`local`은 `screenshots/`, `s3`는 `s3/` 뒤에 `storage_key`를 붙인 POSIX 경로)가
  다른 asset과 같거나 한쪽이 다른 쪽의 상위 경로이면 거부합니다. `download`가 한 archive에 함께 담을 수 없기 때문입니다.
- `format_version: 1` 다운로드 폴더는 계속 읽으며 v2 전용 검사(`database.backup_key`, asset의 v2 필드,
  tar 경로 충돌)는 하지 않습니다.

### 손상 manifest의 오류 코드

계약에 어긋난 manifest는 모든 명령에서 `invalid_manifest`(종료 코드 1)입니다. 명령별 순서는 다음과 같습니다.

- `verify`·`download`·`maintain`은 Bucket 객체를 읽기 전에 manifest를 검사합니다.
  계약 위반과 객체 크기·해시 불일치나 객체 없음이 함께 있어도 `invalid_manifest`입니다.
  `download`는 다운로드 폴더를 만들기 전에 검사하므로 손상 manifest로는 폴더가 생기지 않습니다.
- 완료 지점의 dump나 원본 보관본이 없거나 읽을 때 S3 오류가 나면 `verify`·`download`와 `maintain`의 보존 지점 확인이
  모두 `backup_object_missing_or_unavailable`입니다. `maintain`은 만료 지점만 참조하는 객체를 확인하지 않고 정리하며,
  지운 뒤 없어졌음을 확인하지 못하면(예: 읽기 권한 없음) `backup_cleanup_unverified`입니다.
- `verify`는 객체를 확인한 뒤 manifest를 다시 읽어 처음 읽은 값과 비교합니다. 다르거나 JSON으로
  읽을 수 없거나 없으면 `backup_point_changed`이고, 다시 읽을 때 그 밖의 S3 오류가 나면 `backup_store_unavailable`입니다.
  다시 읽은 manifest에는 계약 검사를 하지 않습니다.
- 없는 지점 ID로 `verify`·`download`를 실행하면 `backup_operation_failed`이고, `download`는 폴더를 만들지 않습니다.
- `maintain`은 완료 지점 manifest를 모두 읽은 뒤 정리 receipt마다 이름(`invalid_gc_receipt`), JSON 객체,
  같은 ID 완료 지점과의 충돌(`gc_receipt_conflict`)을 확인합니다. 그다음 지점마다 `format_version`이 2가
  아니면 `retention_requires_v2`, 계약 위반이면 `invalid_manifest`입니다. 하나라도 실패하면 아무것도 지우지 않습니다.
- 격리 복원 검증·`restore-check`·`restore_execution prepare`는 최상위 필드 → DB·이미지 파일의 항목·크기·해시
  → archive 안전 검사 → asset마다 필드·tar 경로 충돌·archive 포함 여부(`missing_asset`) → `sample` → 디스크 여유
  순서로 검사해 먼저 걸린 코드를 보고합니다. 예를 들어 DB 해시 불일치와 asset 계약 위반이 겹치면
  `backup_hash_mismatch`입니다. `image_migration apply`는 모든 실패를 `migration_precondition_or_storage_unavailable`로 보고합니다.
- `.`·`..` 같은 형식 밖 지점 ID 인자는 `invalid_backup_id`(`manual`의 `--backup-id`는 `backup_id_required`),
  형식 밖 이름의 정리 receipt는 `invalid_gc_receipt`입니다. `points/./`·`points/../` 아래 객체는
  완료 지점으로 세지 않고 중단된 지점처럼 하루 뒤 정리합니다.

### `maintain`이 `invalid_manifest`로 멈췄을 때

`maintain`은 완료 지점 manifest나 정리 receipt 하나라도 위 계약(필드 기준, `storage_key` 정규화 규칙 포함)에
어긋나면 멈춥니다. 원인 지점은 출력하지 않습니다. 멈춘 실행은 아무것도 지우지 않았으므로 아래 순서로 확인합니다.

1. `maintain`과 같은 리비전의 `backend/`에서 아래 읽기 전용 점검 모듈로 실패한 완료 지점·정리 receipt를 찾습니다.
   완료 지점마다 `verify`를 실행하고, 정리 receipt는 이름·충돌·내용만 검사합니다. receipt만 남은 지점은
   객체 일부가 이미 지워졌을 수 있어 객체를 확인하지 않습니다. Bucket에 쓰지 않습니다.
2. 실패한 지점·receipt의 처리(보존, 별도 정리)는 운영자가 따로 결정합니다. 이 절차는 운영 지점을 고치거나 다시 게시하지 않습니다.
3. 결정 전까지 정리를 멈추지 않으려면 아래 되돌리기를 **멈춤을 확인한 날 안에** 실행합니다.
   삭제된 이미지의 백업 사본은 삭제 후 6일에 정리하며, 7일을 넘기면 `retention_overdue`로 보고됩니다.

```sh
cd backend
YOUTUBE_SUMMARY_ENABLED=false .venv/bin/python -m scripts.recovery_point_audit --backup-config-file /absolute/private/backup-bucket.json
```

`--backup-config-file`을 빼면 `BACKUP_BUCKET_CONFIG_JSON`을 읽습니다. 점검 모듈은 운영자 로컬 `backend/`에서만
실행하며 operator 이미지에는 들어 있지 않습니다. 출력은 JSON 하나입니다.

- `points`는 완료 지점 ID별, `receipts`는 정리 receipt 키별 결과이며 `passed`가 아니면 오류 코드입니다.
  오류 코드가 아닌 실패는 예외 클래스 이름입니다(예: 목록을 확인한 뒤 receipt가 사라지면 `FileNotFoundError`).
- receipt는 키 순서로 읽습니다. 읽기가 멈추면 그 receipt에 원인을 적고, 뒤의 receipt는 확인하지 못한
  `not_checked`입니다.
- 모든 지점·receipt가 `passed`이면 `"passed": true`이고 종료 코드 0, 하나라도 아니면 `"passed": false`이고 종료 코드 1입니다.
- 설정 파일 읽기, 완료 지점 목록이나 receipt 목록 조회처럼 지점·receipt를 특정할 수 없는 실패는
  `{"passed": false, "error": "<오류 코드 또는 예외 클래스 이름>"}`만 출력하고 종료 코드 1입니다.
  앞서 확인한 지점 결과는 싣지 않으므로 원인을 고친 뒤 다시 실행합니다.
- 출력에는 Bucket 이름·자격·설정 파일 경로가 없습니다.

**되돌리기**: operator 이미지와 운영자 로컬 CLI를 이 검사 기준이 들어오기 직전 main 리비전으로 되돌립니다.
그 리비전까지는 이 절의 검사가 없어 이전 동작으로 정리를 이어 갑니다. 리비전은 `point_unchanged`를 처음 추가한
커밋의 부모이며, 별도 checkout에서 이미지를 다시 만듭니다.

```sh
CHANGE=$(git log --reverse --format=%H -S 'def point_unchanged' origin/main -- backend/scripts/recovery_point.py | head -n 1)
git worktree add --detach /absolute/private/clipback-rollback "$CHANGE^"
cd /absolute/private/clipback-rollback
docker build -f backend/Dockerfile.operator --build-arg POSTGRES_MAJOR=18 \
  -t "clipback-image-operator:$(git rev-parse HEAD)" backend
```

스케줄러의 `maintain`·`daily` 서비스 이미지를 이 태그로 바꾸고, 로컬 CLI는 이 checkout의 `backend/`에서 실행합니다.
두 서비스는 main 자동 배포가 켜져 있어 다음 병합 때 되돌린 이미지를 덮으므로, 되돌리는 동안 자동 배포를 끕니다.
되돌린 뒤 처음 `maintain`이 성공하는지 확인합니다. 실패한 지점의 처리를 결정한 뒤 최신 리비전으로 돌아옵니다.

## 도구가 확인하는 것

- 입력 파일 크기·해시, 참조 이미지 존재, archive 경로·파일 종류·중복 검사를 자원 생성 전에 수행합니다.
  절대 경로·상위 경로·링크·장치·FIFO·sparse 파일을 거부합니다.
- 로컬 context와 이미지 revision을 확인한 뒤 UUID 이름과 소유 라벨을 붙인 새 네트워크·볼륨·컨테이너만 만듭니다.
- PostgreSQL 주 버전을 확인하고 새 빈 DB에 `pg_restore --no-owner --no-acl --exit-on-error`로 복원합니다.
  원래 DB의 역할·소유자·ACL 재현은 이번 검사의 범위가 아닙니다.
  공식 이미지의 초기화 임시 서버는 Unix socket만 열리므로 `pg_isready -h 127.0.0.1`로
  최종 TCP 서버를 기다립니다. 임시 서버의 준비 완료를 복원 가능한 상태로 취급하지 않습니다.
- 네트워크는 `--internal`, API의 외부 공개 포트는 없으며 Docker exec 안의 localhost로만 검사합니다.
  요약 worker는 꺼지고 공급자 설정은 비활성 검사용 값입니다. 실제 운영의 공급자 키를 복사하지 않습니다.
- 테이블 건수·revision·전체 카테고리 관계 해시·모든 참조 이미지 해시와 시험 콘텐츠를 원본 기준과 대조합니다.
  시험 계정의 실제 인증 조회와 원본 이미지 바이트도 확인합니다.
- 입력 세트는 수정하지 않습니다. 추가 파일은 수만 보고하고 새 볼륨에 보존합니다.
  결과에는 통과 여부·고정 오류 코드·건수·소요 시간만 출력하며 SQL·토큰·HTTP 본문·컨테이너 로그는 출력하지 않습니다.
- 실패·정상 종료 모두 소유 라벨이 일치하는 이번 자원만 정리합니다. 정리에 실패하면 전체 `passed`는 false입니다.
  강제 프로세스 종료·호스트 장애 뒤에는 소유 라벨과 UUID를 대조해 남은 자원을 수동 확인해야 합니다.

성공 예시는 `passed`, `cleanup_passed`, `authentication_passed`, `image_bytes_passed`가 모두 true입니다.
최신 삭제 기록 적용 후에도 살아 있는 시험 원본은 유지합니다. 시험 원본이 삭제됐다면 실제 인증
계정이 소유한 다른 원본만 대체 시험 대상으로 선택합니다. 그 계정에 원본이 없으면 타인의 원본이
남아 있더라도 인증과 삭제한 경로의 404를 확인하고 `image_get_skipped: true`,
`image_bytes_passed: false`로 보고합니다. 모든 남은 원본의 해시 검증과 특정 계정의 HTTP 원본
재조회 성공은 별개이며, 서비스 전체 자산 수가 0보다 크다는 이유로 이미지 GET 성공을 보고하지 않습니다.
`origin=synthetic` 결과를 운영 백업 검증으로 바꾸어 보고하지 않습니다.
실행 시간은 측정한 로컬 복원 시간이며 운영 서비스 전환까지의 보장된 RTO가 아닙니다.

## 자동 검사

`backend/`에서 개발 의존성을 설치한 뒤 단위 검사를 실행합니다.

```sh
.venv/bin/pytest -q tests/deployment/test_backup_restore.py
.venv/bin/pytest -q tests/deployment/test_image_backup.py
```

실제 Docker 검사는 합성 계정 2개·이미지·미참조 파일을 가진 원본 DB와 백업을 별도로 준비합니다.
사전에 revision 라벨이 있는 로컬 백엔드 이미지와 `postgres:16`, `postgres:18`을 준비한 뒤 실행합니다.

```sh
RUN_DOCKER_RECOVERY_TESTS=1 \
CLIPBACK_RECOVERY_TEST_IMAGE=clipback-backup-recovery:check \
  .venv/bin/pytest -q tests/deployment/test_backup_restore_docker.py
```

같은 환경변수로 `tests/deployment/test_image_backup_docker.py`를 실행하면 실제 PostgreSQL 16
dump, local·Bucket 원본, 내용별 백업 재사용, 격리 Bucket 복원과 인증 GET, 누락·손상 사본을
검사합니다. 이 합성 fixture는 원본·백업·독립 삭제 기록용 세 private Bucket을 가진 로컬 moto만 사용합니다.
전용 일일 작업 이미지도 검사하려면 source DB와 같은 `POSTGRES_MAJOR=16`으로
`Dockerfile.operator`를 빌드하고 그 이미지를 `CLIPBACK_RECOVERY_OPERATOR_IMAGE`에 지정합니다.
기본 주 버전 17 이미지를 이 fixture에 지정하면 `pg_dump_version_mismatch`로 의도적으로 실패합니다.
실제 운영 이미지는 fixture 버전이 아니라 실제 source DB 주 버전과 맞춥니다.

`test_multiuser_image_restore_docker.py`는 먼저 생긴 타인 원본이 있는 환경에서 살아 있는 표본,
삭제 후 동일 계정의 대체 원본, 그 계정의 원본이 모두 삭제된 경우를 실제 복원합니다.
`test_legacy_account_deletion_restore_docker.py`는 계정 탈퇴 기능 이전 리비전으로 만든 API 이미지를
`CLIPBACK_LEGACY_API_IMAGE`로 받아, 그 이미지로 만든 복구 지점에 현재 반영 소스·probe로 탈퇴 기록을 반영합니다.
지운 계정의 토큰(401), 살아 있는 계정의 토큰(원본 열람), 모든 계정이 지워진 경우를 실제 복원하고,
계정 행이 남은 DB에서는 probe가 실패하는지 확인합니다. CI는 고정한 이전 main 리비전에서 이 이미지를 빌드합니다.
`test_postgres_restore_ready_docker.py`는 PostgreSQL 16·18 초기화 SQL을 지연시켜 임시 Unix 서버를
최종 준비로 오인하지 않는지 실제 TCP 연결과 격리 복원으로 검증합니다.

16·18 각각 정상 복원, 손상 dump, 잘못된 테이블 건수·이미지 해시·자격·revision을 확인합니다.
운영 자료는 이 fixture로 사용하지 않습니다. 명시적 환경변수가 없으면 Docker 사례만 skip하므로
일반 pytest 통과를 실제 Docker 검사 실행으로 보고하지 않습니다.

기존 API Volume의 원격 백업은 [운영 원본의 비공개 읽기](image-operator-source.md)를 따른다. 원격 원본 경로 준비와 실제 Railway 연결 증거를 분리한다.


## 격리 복원 전 전체 점검

신규 이미지 저장 중단만으로 전체 쓰기가 멈추지는 않습니다. 새 [영속 점검 제어](image-maintenance.md)의 실행·종료 대기·명시적 재개를 사용하며 실제 운영 검증은 별도 단계입니다.
