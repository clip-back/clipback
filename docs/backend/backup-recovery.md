# DB·이미지 백업의 격리 복원 검사

운영 백업의 읽기 전용 입력으로 새 로컬 Docker 자원에 복원하는 도구입니다.
운영 접속·서비스 중지·백업 다운로드·운영 복구 전환은 수행하지 않습니다.
운영 절차는 [Railway 안내](../railway-deployment.md), 실제 결과는
[작업 이력](../history/2026-10-22-production-recovery.md)을 따릅니다.

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
나열되지 않습니다. 동시 운영자는 서로 다른 ID를 사용해야 합니다. 보존 정리는 후속 정책을 따릅니다.

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
사용하지 않습니다. 다운로드 폴더는 새로 생성하며 기존 폴더를 덮어쓰지 않습니다. 결과의
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

운영 스케줄러에서 **매일 UTC 00:00에 daily**, **매시간 15분에 maintain**을 실행합니다.
두 명령은 PostgreSQL session lock `74264003`으로 직렬화하며 이미 실행 중이면 nonzero로 종료합니다.
수동 create도 같은 job lock을 사용해 GC와 부분 업로드가 경합하지 않게 합니다.
같은 UTC 날짜의 `daily-YYYY-MM-DD` 완료 지점은 다시 만들지 않습니다. 실패한 미완료 지점은
같은 날짜에 재시도할 수 있습니다. 스케줄러의 재시도와 nonzero 알림을 운영자가 설정해야 합니다.
명령이 실제 Railway Cron이나 알림을 자동 생성하지 않습니다. 첫 실행·최근 성공 시각·실패 알림을
확인한 뒤 운영 일정을 켭니다. 성공 시 최근 완료 snapshot 이후 최대 하루치 손실을 목표로 합니다.
최근 지점이 24시간보다 오래되면 `freshness_met: false`, 전체 `passed: false`입니다.

두 작업은 기존의 독립 삭제 기록 재조정과 영속 원본 정리 재시도도 먼저 실행합니다. 미처리 원본
정리 작업이 남으면 전체 성공으로 표시하지 않습니다. 일일 백업이 실패해도 시간별 정리는 별도로
실행해야 합니다. 백업/정리 장애가 계속되면 하루 복구 목표와 7일 제거 목표는 충족하지 못합니다.
따라서 작업 서비스의 원본 자격·local 공유 경로에는 이 정리에 필요한 삭제 권한도 있어야 합니다.
백업 자격과 별개이며 API에 백업 Bucket 삭제 권한을 주는 설정은 아닙니다.

완료 시각 기준 7일 이상인 복구 지점을 만료시키고, 사용자 삭제 intent 이후 **6일**이 지난 원본을
참조하는 지점도 만료시킵니다. DB commit이 불확실해 삭제 intent 이후에 생성된 지점에 그 원본이
남아 있는 경우도 포함합니다. 먼저 `gc/points/<id>.json`에 불변 원본 identity를 가진 작은 정리
receipt를 검증해 보관하고, 완료 manifest를 내린 뒤 지점 dump와 미참조 원본을 삭제합니다.
모든 정리가 확인된 뒤 receipt를 지웁니다. manifest 제거 후 실패해도 hash가 없던 legacy 삭제의
원본 연결과 기한을 잃지 않습니다. 정리 중인 ID는 새 지점으로 재사용하지 못합니다. 원본 삭제는
실제 HEAD 부재를 확인합니다. 변경 없는 원본은 hash별 한 사본을 지점 간 재사용합니다.
중단된 지점의 하루 이상 된 잔여 파일도 정리합니다. 삭제 기록은 복구에 필요하므로 지우지 않습니다.
유지할 지점의 dump·원본 존재와 크기를 HEAD로 확인하며 누락·크기 손상은 성공으로 보고하지
않습니다. 전체 바이트 SHA 검사는 게시 시와 복원 다운로드 시 수행합니다. 시간별 작업이 매번
모든 DB dump를 내려받지는 않으므로 같은 크기의 손상 검출은 다음 게시/격리 복원 검사와 구분합니다.

6일 기준은 시간별 재시도에 하루의 여유를 둡니다. 실제로 삭제 후 7일에 도달한 사본이 발견되면
정리를 마쳐도 그 실행은 `retention_overdue`와 `passed: false`로 목표 미충족을 보고합니다.
다른 살아 있는 원본이 정확히 같은 바이트를 참조하면 공통 사본 자체는 보존합니다. 삭제한 사용자의
과거 복구 참조는 제거됩니다. 다른 계정의 유효한 원본을 함께 지우지는 않습니다.

API 이미지는 operator 스크립트·pg_dump를 포함하지 않습니다. 스케줄용 전용 이미지는 source DB와
같은 주 버전으로 빌드합니다. 기본값은 17이며 실제 버전이 다르면 바꿉니다.

```sh
docker build -f backend/Dockerfile.operator --build-arg POSTGRES_MAJOR=17 \
  -t clipback-image-operator:SOURCE_SHA backend
```

이 이미지의 entrypoint는 `python -m scripts.image_backup_jobs`입니다. 스케줄러의 start command로
위 `daily` 또는 `maintain` 인자들을 지정합니다. 원본 DB·Bucket·삭제 기록 환경은 작업 서비스에,
`0600` 백업 자격은 작업 사용자 소유의 별도 파일로만 공급합니다. API 서비스에는 백업 자격을
주지 않습니다. 전용 이미지는 백업 작업용이며 Docker socket/CLI를 운영 서비스에 연결하지 않습니다.
이미지는 `YOUTUBE_SUMMARY_ENABLED=false`를 기본 제공해 AI worker와 해당 API 키를 요구하지
않습니다. `APP_ENVIRONMENT=production`의 기존 SECRET_KEY·저장 경로·소셜 인증 등 보안 검증은
그대로 적용됩니다. OPENAI_API_KEY를 포함한 기존 production 검증도 유지됩니다. source API의
필요한 운영 설정을 명시적으로 공급하고 검증을 우회하지 않습니다. 백업은 AI API를 호출하지 않습니다.

## 최신 삭제 기록을 반영한 격리 복원

원본 API·worker·다른 쓰기 작업을 실제로 중지한 뒤 최신 독립 삭제 기록에 접속 가능한 운영자
환경에서 실행합니다. `--writers-frozen`은 운영자의 중지 확인이며 도구가 서비스 중지를 검증하거나
자동 수행하지 않습니다. 기존 다운로드 명령으로 새 `0700` 임시 폴더에 지점을 받습니다.

```sh
YOUTUBE_SUMMARY_ENABLED=false .venv/bin/python -m scripts.image_backup_jobs restore-check \
  --backup-dir /absolute/private/TEMPORARY_POINT \
  --credentials-file /absolute/private/restore-credentials.json \
  --image clipback-recovery:BACKUP_SHA --writers-frozen
```

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

`live_deletion_ledger_verified: true`는 이 격리 검사 구간의 결과입니다. 도구는 트래픽을 열지 않으며
종료 시 lock을 반환합니다. 실제 복구 전환까지 쓰기 중지를 유지해야 합니다. 중간에 쓰기를 재개했다면
최신 기록을 다시 적용·검증해야 합니다. 한 공급자/계정 전체 손실, 악의적인 전체 ledger rollback을
탐지하는 기능은 아닙니다. 실제 Railway 권한·스케줄·운영 복구 전환은 별도로 검증합니다.

복원 다운로드는 운영자 임시 사본입니다. 성공·실패 모두 종료 후 해당 임시 폴더를 제거하고,
7일을 넘겨 보관하지 않습니다. 도구는 임의 위치의 사용자 파일·다른 백업을 탐색해 삭제하지 않습니다.

## 준비와 실행

저장소 루트에서 실행합니다. Docker는 이 Mac의 Unix socket을 사용하는 로컬 context여야 합니다.
백업과 같은 PostgreSQL 주 버전의 공식 `postgres:<major>` 이미지와, 백업 SHA의 제품 코드로 빌드한
백엔드 이미지를 미리 준비합니다. 도구는 이미지를 자동 다운로드하거나 migration을 실행하지 않습니다.
PostgreSQL 18부터 바뀐 공식 이미지의 볼륨 루트도 구분합니다.

이미지에는 `org.opencontainers.image.revision=<백업의 전체 40자리 SHA>` 라벨이 필요합니다.
라벨만 임의로 바꾸어 호환성을 주장하지 말고, 해당 SHA의 소스를 별도 디렉터리에서 빌드합니다.
빌드에 `.env`나 운영 백업을 포함하지 않습니다. 원래 운영 이미지와 소스 재빌드 이미지의 digest는
다를 수 있으며 같은 바이너리로 보고하지 않습니다.

```sh
python3 backend/scripts/check_backup_restore.py \
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
인증 검사 실패이며 복원 성공으로 간주하지 않습니다.

```json
{"secret_key": "PRIVATE_VALUE", "access_token": "PRIVATE_VALUE"}
```

## 백업 manifest 계약

`format_version: 1`에서 다음 필드를 사용합니다. 일반 DB dump만 보고 expected 값을 만들지 말고,
**원본 쓰기가 중지된 같은 구간**에 원본 DB와 내보낸 이미지의 기준 자료를 확보합니다.

| 필드 | 값 |
| --- | --- |
| `backup_id` | 영문·숫자·점·밑줄·하이픈으로 된 세트 식별자 |
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

`test_multiuser_image_restore_docker.py`는 먼저 생긴 타인 원본이 있는 환경에서 살아 있는 표본,
삭제 후 동일 계정의 대체 원본, 그 계정의 원본이 모두 삭제된 경우를 실제 복원합니다.
`test_postgres_restore_ready_docker.py`는 PostgreSQL 16·18 초기화 SQL을 지연시켜 임시 Unix 서버를
최종 준비로 오인하지 않는지 실제 TCP 연결과 격리 복원으로 검증합니다.

16·18 각각 정상 복원, 손상 dump, 잘못된 테이블 건수·이미지 해시·자격·revision을 확인합니다.
운영 자료는 이 fixture로 사용하지 않습니다. 명시적 환경변수가 없으면 Docker 사례만 skip하므로
일반 pytest 통과를 실제 Docker 검사 실행으로 보고하지 않습니다.
