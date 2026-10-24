# 기존 원본의 검증 이관과 재개

작업 시작일은 2026-10-23, 최종 합성 실행 확인일은 2026-10-24입니다. 대상은 명세 #64의 #73이며,
기준 통합 브랜치는 `feature/image-storage-integration`입니다. 현재 운영 절차는
[원본 이관 안내](../backend/image-migration.md)에 한 번만 유지합니다.

## 변경

- `scripts.image_migration inspect`는 원본 위치·실제 바이트와 DB 크기/해시를 대조하며 NULL을
  보강하지 않습니다. 출력은 자산 ID·backend·상태·건수이고 원본·키·URL·자격을 포함하지 않습니다.
- `apply`는 실제 v2 materialized backup의 dump/archive 해시, 최신 삭제 반영 실제 복원 성공 보고서,
  backup ID·origin·manifest SHA-256을 확인합니다. 개별 자산이 해당 검증 세트에 같은 불변 키·
  크기·해시로 포함되어야 복사합니다. 변환·새 ID·한도 초과 자료 삭제는 하지 않습니다.
- 기존 `ImageDeletion`을 재사용해 PUT 전 대상 정리 intent를 DB에 commit합니다. 읽어 확인한
  동일 바이트만 자산 위치와 정리 작업 완료를 함께 commit합니다. 성공 여부가 불분명한 대상은
  살아 있는 참조를 보는 기존 worker가 정리하므로 커밋된 원본을 지우지 않습니다. 신규 스키마는 없습니다.
- 이관 job의 source identity는 남겨둔 local 사본의 durable 기록이기도 합니다. 실제 사용자 삭제만
  같은 identity의 local/S3를 정리하며, 일반 고아 대상 정리는 local 원본을 지우지 않습니다.
- copy 중 shared physical lock과 최종 ledger→physical try-lock→content 순서로 경합을 처리합니다.
  백업 중에는 busy로 반환하여 DELETE를 장시간 전역 대기시키지 않습니다. 전체 immutable ledger
  prefix는 잠금 밖에서 확인하고 bounded tip을 최종 재확인합니다. pending 삭제는 재연결하지 않습니다.
- #71의 shared identity를 사용합니다. 레거시 NULL 크기의 후속 보강·backend 이동은 같은 원본이고,
  양쪽 모두 알려진 크기/해시의 충돌과 다른 키·저장 시각은 보호합니다.
- `Dockerfile.operator`와 `.dockerignore`에 이관 모듈을 추가했습니다. 일반 API 이미지에는
  operator script나 백업 자격을 추가하지 않았습니다. local 일괄 삭제·운영 이관은 실행하지 않았습니다.

## API와 운영 도구 경계 검증

공유 root 가상환경, PostgreSQL 17의 합성 전용 `clipback_image_73` DB, local 임시 파일,
moto S3 대역을 사용했습니다. 외부 OCR·메타데이터·OAuth만 기존 합성 응답으로 대체했고,
실제 인증 API·DB·원본 보관/조회·삭제·운영 CLI 경계를 확인했습니다.

처음에는 변경 없는 검사 모듈 부재와 이관 함수 부재를 red로 확인한 뒤 각각 구현했습니다.
local 사본을 남겨둔 채 사용자 삭제 시 제거하지 못하던 실패를 재현해 durable alias 정리로 해결했습니다.
레거시 NULL stage 작업이 중단된 뒤 정상 이미지 업로드의 한도 집계가 size를 채우면 재개가
`0 migrated`가 되던 red도 재현했고 shared identity로 해결했습니다.

이관 전용 회귀는 9개 통과했습니다. 사전 검사 무변경, 부분 이관·혼합 조회·재개·재실행, 잘못된
복원 보고서 차단, PUT 중단 후 새 worker의 대상 정리와 local 보존, NULL size 보강 뒤 재개,
copy 중 DELETE, 최종 DB commit 응답 유실, 백업 lock 중 busy·DELETE 응답, DB 삭제 commit이
실패한 durable intent의 이관 차단·후속 정리를 포함합니다. 장애는 저장소 SDK/DB 외부 경계에
주입했고 클래스 내부 호출 횟수는 확인하지 않았습니다.

마지막 회귀를 포함한 위 관련 검사 합계는 **97 passed, 14.83초**였습니다. 유일한 경고는 기존
Starlette TestClient의 httpx deprecation이며 실패·skip은 없었습니다.

```sh
PYTHONPATH="$PWD" YOUTUBE_SUMMARY_ENABLED=false \
  TEST_DATABASE_URL=postgresql+asyncpg://clipback_image@127.0.0.1:55464/clipback_image_73 \
  DATABASE_URL=postgresql+asyncpg://clipback_image@127.0.0.1:55464/clipback_image_73 \
  /Users/leehyeongyu/Desktop/project/Clipback/backend/.venv/bin/python -m pytest \
  tests/integration/test_image_migration.py tests/integration/test_image_deletion.py \
  tests/integration/test_image_quota.py tests/deployment/test_image_backup.py \
  tests/deployment/test_image_backup_retention.py tests/deployment/test_backup_restore.py -q --tb=short
```

전체 backend Ruff와 `git diff --check`를 통과했습니다. 기존 017 head에 `alembic check`를 실행해
`No new upgrade operations detected`를 확인했습니다. 새 스키마·migration 파일을 만들지 않았습니다.

## 실제 Docker·HTTP 이관과 격리 복원

`test_image_migration_docker.py`는 **1 passed, 167.84초**였습니다. 실제 PostgreSQL 16 `pg_dump`,
로컬 HTTP moto 5.2.4의 원본·삭제 기록·백업 Bucket, 실제 API 컨테이너와 별도 internal 복원 자원을
사용했습니다. 외부 Railway·운영 DB·실제 사용자 계정을 사용하지 않았습니다.

API 이미지는 실제 확인한 revision `79a13ba25ff13990a1538fad942674fa6a264d00`의 `app/` 소스로
`clipback-migration-api:check`를 빌드했습니다. Host 운영 CLI는 이 작업트리 소스로 실행했습니다.
원본 DB·파일은 해당 작업이 만든 자원만 사용했고 fixture를 다른 모듈에서 새로 준비했습니다.

```sh
RUN_DOCKER_RECOVERY_TESTS=1 CLIPBACK_RECOVERY_TEST_IMAGE=clipback-migration-api:check \
  YOUTUBE_SUMMARY_ENABLED=false PYTHONPATH="$PWD" \
  /Users/leehyeongyu/Desktop/project/Clipback/backend/.venv/bin/python -m pytest \
  tests/deployment/test_image_migration_docker.py -q --tb=short
```

검증한 관찰 결과:

1. legacy NULL인 local 2개와 S3 1개, 합계 3개 원본을 실제 dump와 함께 백업했습니다.
2. 최신 독립 삭제 기록을 확인한 실제 격리 복원에서 인증·모든 바이트가 같았고, 그 manifest SHA에
   대응하는 실제 성공 JSON만 이관 gate로 전달했습니다.
3. 실제 CLI `inspect`는 local ready 2개를 보고했습니다. `apply --limit 1` 뒤 1개만 이동하고,
   mixed local/S3의 기존 인증 binary GET은 ID·저장 시각·원본 SHA가 모두 같았습니다.
4. 새 프로세스로 다시 실행해 나머지 1개를 이동하고 추가 재실행은 0개였습니다. local 사본은
   여전히 2개였으며, 같은 API 원본 바이트와 자산 ID를 유지했습니다.
5. 실제 API DELETE 204 뒤 원본 Bucket 객체와 local PNG 모두 0개였습니다.
6. 이관 **전** local 자료를 가진 백업을 최신 삭제 기록으로 실제 복원했을 때 해당 콘텐츠·binary·
   access descriptor는 404였고, 원본 0개·`image_get_skipped:true`였습니다. 정상 `users/me` 인증은
   계속 검증했으며 없는 이미지를 다운로드했다고 보고하지 않았습니다.

소유 라벨 `clipback.recovery.owner`의 컨테이너·네트워크·볼륨 목록이 모두 빈 것을 확인했습니다.
`clipback-migration-operator:check`도 PostgreSQL 16 기반으로 실제 빌드하고
`docker run --rm --entrypoint python ... -m scripts.image_migration --help`가 inspect/apply를
표시하며 정상 종료하는 것을 확인했습니다. 운영 설정·자격을 사용한 operator 실행 검증은 아닙니다.

## 한계와 남은 운영 작업

실제 Railway Bucket 권한·스토리지 비용·원격 CI·운영 배포·운영 데이터 이관·cron·복원 cutover는
실행하지 않았습니다. Flutter 화면을 바꾸지 않아 이 작업의 native 실행은 필요하지 않았고, 통합
앱 검증은 #74 범위입니다. 원본 bytes seed는 합성 fixture이며 실제 OCR 업로드 공급자 검증은 아닙니다.
검증된 local 사본을 일괄 제거하는 기능은 포함하지 않습니다. 실패는 개별 상태·nonzero로 남기고,
일반 삭제 worker 및 명시적인 새 백업·복원 검증 후 재개합니다. Bucket 미지원 과거 버전으로의
단순 rollback은 금지한다는 현재 운영 안내를 남겼습니다.
