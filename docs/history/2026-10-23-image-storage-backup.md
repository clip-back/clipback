# DB·원본의 단일 Bucket 복구 지점

2026-10-23, 이미지 보관 명세 [#64](https://github.com/clip-back/clipback/issues/64)의
[#70](https://github.com/clip-back/clipback/issues/70) 구현 기록입니다.
기준 통합 commit은 `b5b41ca`이며 실제 운영 배포·원본 자료·Railway 자격은 사용하지 않았습니다.
현재 명령과 계약은 [격리 복원 안내](../backend/backup-recovery.md)를 따릅니다.

## 변경과 확인 경계

- 운영자 별도 자격 파일로 private 백업 Bucket에 DB dump와 실제 원본을 보관합니다.
- 원본과 같은 Bucket을 거부하고 API 설정에는 백업 자격을 추가하지 않습니다.
- 원본 SHA별 불변 사본을 재사용하고 manifest를 마지막에 게시합니다.
- exported DB snapshot과 원본 물리 삭제 lock을 공유하며 수동 쓰기 중지를 필수로 확인합니다.
- 기존 v1 입력을 유지하고 v2 Bucket 원본을 내부 Docker moto로 복원하여 실제 인증 GET을 검사합니다.
- 단일 지점 검사에 최신 삭제 반영·일일 실행·7일 보존 완료를 포함하지 않습니다.

## 검증

- TDD: 완료 지점 생성·재사용의 실패(`NotImplementedError`)를 확인한 뒤 통과시켰고,
  물질화 경계도 실제 미구현 실패를 확인한 뒤 원본·dump 검증을 추가했습니다.
- 관련 단위 검사 `tests/deployment/test_image_backup.py`와 `test_backup_restore.py`:
  **45 passed**. 정상·원본 누락/손상·미완료 지점·별도 Bucket·0600 자격·목적지 권한 거부·
  기존 archive/자원 소유권/정리 실패 경로를 포함합니다.
- `RUN_DOCKER_RECOVERY_TESTS=1`로 기존 v1 PostgreSQL **16·18 실제 Docker 검사 12 passed**
  (84.56초): 정상 인증 GET·손상 dump·잘못된 건수/이미지 해시/자격/revision을 확인했습니다.
- 신규 실제 Bucket v2 검사 **2 passed** (26.94초): 합성 PostgreSQL 16에서 exported snapshot의
  실제 `pg_dump`를 별도 moto Bucket에 저장하고, 같은 바이트의 local·S3 원본 2개가 보관본 1개를
  재사용함을 확인했습니다. 격리 DB·Bucket 복원, 인증 GET, 누락·손상 사본 거부를 확인했습니다.
- 합성 source는 호스트 CLI가 접근하도록 DB·moto를 loopback 포트로 연결했습니다.
  처음 source를 `--internal`로 만들었을 때 포트가 공개되지 않아 fixture를 수정했습니다.
  실제 복원 대상은 `--internal` 네트워크, 공개 포트 없이 실행했습니다.
- 자원은 이번 실행의 UUID/소유 라벨에 맞는 것만 제거했고 실행 후 잔여 컨테이너가 없었습니다.
- Ruff·`git diff --check`를 수행했습니다. 초기 앱 이미지는 API 소스
  `99375c84005f9568f9491cab9b6a11ba5d8723d7`로 빌드했으며 해당 라벨로 검사했습니다.

## 한계

실제 Railway Bucket/IAM, 운영 데이터, 배포, 공급자 전체 장애, 외부 공격에 의한 백업 재작성은
검증하지 않았습니다. S3 대역의 권한 거부 검사는 Railway 권한 설정의 증거가 아닙니다.
source 쓰기를 실제로 중지하는 책임은 운영자에게 있으며, `--writers-frozen`만으로 중지되지 않습니다.
이미지 0개·시험 sample 소실·최신 삭제 반영·7일 보존은 후속 #71에서 확장할 경계입니다.
v2 다운로드는 참조 원본만 담으며 v1의 미참조 파일 전체 보존과 구분합니다.
일반 API에 백업 자격을 주입하지 않는 구성을 유지해야 합니다.
