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

**이 단일 지점 검사 결과는 `deletions_applied: false`입니다.** 일일 일정·7일 보존·최신 삭제 기록의
반영은 후속 복구 기능이 담당합니다. 이 명령만으로 운영 DB를 되돌리거나 서비스 트래픽을
전환하지 않습니다. 이번 실제 합성 검증과 한계는
[Bucket 백업 작업 이력](../history/2026-10-23-image-storage-backup.md)에 기록합니다.

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
- 네트워크는 `--internal`, API의 외부 공개 포트는 없으며 Docker exec 안의 localhost로만 검사합니다.
  요약 worker는 꺼지고 공급자 설정은 비활성 검사용 값입니다. 실제 운영의 공급자 키를 복사하지 않습니다.
- 테이블 건수·revision·전체 카테고리 관계 해시·모든 참조 이미지 해시와 시험 콘텐츠를 원본 기준과 대조합니다.
  시험 계정의 실제 인증 조회와 원본 이미지 바이트도 확인합니다.
- 입력 세트는 수정하지 않습니다. 추가 파일은 수만 보고하고 새 볼륨에 보존합니다.
  결과에는 통과 여부·고정 오류 코드·건수·소요 시간만 출력하며 SQL·토큰·HTTP 본문·컨테이너 로그는 출력하지 않습니다.
- 실패·정상 종료 모두 소유 라벨이 일치하는 이번 자원만 정리합니다. 정리에 실패하면 전체 `passed`는 false입니다.
  강제 프로세스 종료·호스트 장애 뒤에는 소유 라벨과 UUID를 대조해 남은 자원을 수동 확인해야 합니다.

성공 예시는 `passed`, `cleanup_passed`, `authentication_passed`, `image_bytes_passed`가 모두 true입니다.
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
검사합니다. 이 합성 fixture는 두 private Bucket을 가진 로컬 moto만 사용합니다.

16·18 각각 정상 복원, 손상 dump, 잘못된 테이블 건수·이미지 해시·자격·revision을 확인합니다.
운영 자료는 이 fixture로 사용하지 않습니다. 명시적 환경변수가 없으면 Docker 사례만 skip하므로
일반 pytest 통과를 실제 Docker 검사 실행으로 보고하지 않습니다.
