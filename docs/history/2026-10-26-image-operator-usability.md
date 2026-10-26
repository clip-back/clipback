# 이미지 운영 도구 사용성·검증 개선

기록일: 2026-10-26. 운영 문서 PR #104 이후 회고에서 승인한 다섯 가지 개선을 구현했다.
이번 작업은 Railway 서비스 설정·Cron·운영 자료를 변경하지 않았다. `maintain` 가동은 계속 보류다.

## 변경

1. `image_backup_jobs`가 `BACKUP_BUCKET_CONFIG_JSON`을 직접 소비한다. 콘솔 Python 래퍼와 임시
   자격 파일 없이 `python -m scripts.image_backup_jobs daily`로 실행한다. 커밋과 수동 백업 ID는
   환경변수 기본값을 사용하며 기존 파일·명시적 인자 방식은 유지한다.
2. `MaintenanceSettings`·`MaintenanceRuntime`을 분리했다. `maintain`은 DB·삭제 기록·백업 Bucket만
   요구하고 원본 S3·Volume·읽기 키를 요구하지 않는다. 생성 명령의 원본 식별·설정 검증은 유지한다.
3. 현재 운영 상태와 실행 기준은 첫 운영 체크리스트로 모았다. 과거 계획과 전환 문서에서 이 기준으로
   연결하고, 작업 종료 때 상세 이력과 완료·미확인·보류 상태를 갱신하도록 명시했다.
4. `image_backup verify`가 완성된 복구 지점의 DB·이미지를 스트리밍으로 읽어 크기·SHA-256을 확인한다.
   로컬 DB·이미지 사본은 만들지 않는다. 삭제 checkpoint 존재와 최신 삭제 기록 검증·격리 복원을 구분한다.
5. 로컬 `operator_status`가 Railway Cron 최근 5개 실행과 GitHub PR·CI 상태를 필요한 필드만 출력한다.
   공급자 stderr·전체 메타데이터를 출력하지 않으며 실패는 비밀값 없는 JSON과 비정상 종료로 반환한다.

## 검증

- `ruff check app scripts alembic tests`, `compileall`, `git diff --check`, 변경 문서 상대 링크 확인 통과.
- 임시 PostgreSQL 18의 별도 업무·점검 DB에 최신 migration 적용 후 전체 검사:
  **1,144 passed, 46 skipped**. 선택형 Docker 등은 기본 실행에서 제외되며 아래 관련 Docker 검사를 별도 실행했다.
  기존 Alembic `path_separator` 누락 deprecation 경고 3개는 이번 변경 범위 밖이다.
- 신규 CLI·설정·혼합 객체 손상·상태 출력 시험: **10 passed**.
  마지막 상태 조회 실패의 stderr 비노출 시험은 전체 검사 수집 후 추가해 이 묶음에서 별도 확인했다.
- 실제 빌드한 PostgreSQL 18 운영자 이미지의 수동·짧은 일일 명령·검증·최소 설정 보존 정리:
  **1 passed**. 기존 미처리 원본은 유지하고 백업의 불필요한 사본만 정리되는지 확인했다.
- 새 API 테스트 이미지와 운영자 이미지의 원격 원본·잘못된 식별자/권한 보호: **2 passed**.
- Docker 시험 컨테이너·네트워크와 전체 DB 시험의 임시 PostgreSQL 컨테이너를 종료·정리했다.
- 새 상태 도구로 실제 Railway Cron 이력과 PR #104 결과 조회 성공. 이 조회는 작업 실행이나 병합을 하지 않는다.
- 새 `verify` 명령으로 기존 `daily-2026-10-26` 복구 지점을 실제 공급자에서 읽기 전용 확인:
  Volume 18개·Bucket 1개 및 DB, 20개 객체 / 11,230,275바이트 크기·SHA-256 모두 일치.
  `restore_verified=false`, `live_deletion_ledger_verified=false`로 출력했다.

기본 검사의 초기 TLS 4건 실패는 샌드박스의 loopback bind 금지였고 권한을 허용해 통과했다.
원격 원본 Docker 검사의 초기 실패는 재사용한 과거 복원용 이미지의 파일 권한으로 비루트 실행이
불가능했기 때문이다. 현재 checkout에서 API 이미지를 다시 빌드한 뒤 동일 시험이 통과했다.
제품 원본 파일이나 운영 자격의 권한을 완화하지 않았다.

기존 `operator-recovery` CI가 해당 Docker 테스트 파일을 이미 실행하므로 별도 중복 CI를 만들지 않았다.
새 개선 코드의 원격 CI·운영 이미지 배포는 아직 실행하지 않았다. 실제 운영 서비스는 기존 명령을
유지하며, 새 짧은 명령·최소 설정은 개선 이미지 배포 확인 후 적용해야 한다.
