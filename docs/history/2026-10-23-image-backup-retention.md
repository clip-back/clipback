# 일일 이미지 백업·7일 보존·최신 삭제 복원 구현

- 최초 기록: 2026-10-23, 스펙 #64의 #71
- 작업 기준: 통합 브랜치 `4d6b59b8dcf199cf28b38d0870c4ccfe3fa0ed21`
- 현재 실행·보존·복원 계약: [백업·복원 안내](../backend/backup-recovery.md)
- 합성 로컬 자료만 사용했으며 실제 Railway·운영 데이터·자격·스케줄·복구 전환은 변경하지 않았다.

## 구현

일일 UTC 지점 생성과 시간별 정리를 별도 operator 명령으로 연결했다. 수동 create도 같은 session
job lock으로 동시 실행을 막고 완료된 날짜의 재실행은 사본을 다시 만들지 않는다. 독립 삭제 기록의
namespace·head·tip만 bounded 조회해 checkpoint를 잡은 후 ledger lock을 풀고 전체 불변 prefix를
검증한다. 물리 정리 shared lock과 exported DB snapshot은 dump·사본 확인까지
유지한다. 기존 영속 원본 정리 retry도 작업에 포함했다.

7일 이상 지점과 사용자 삭제 intent 이후 6일이 지난 원본을 참조하는 지점을 만료시킨다.
미참조 hash 사본과 오래된 부분 지점을 정리하되 살아 있는 다른 원본이 공유하는 바이트는 보존한다.
7일에 도달한 사본을 늦게 정리한 실행도 overdue로 실패를 보고한다. 유지 지점의 존재·크기는
HEAD로 확인하며 byte SHA는 게시·다운로드 때 검증한다. ledger metadata는 지우지 않는다.

최신 삭제 복원은 source write freeze 확인과 shared ledger lock 안에서 live chain을 검증한다.
격리 복원의 원래 snapshot 기준을 먼저 비교하고 삭제를 적용한 뒤 API를 시작한다. owner·saved_at·
불변 원본 identity를 함께 대조해 숫자 ID 재사용을 보호한다. 빈 이미지 집합은 실제 계정 인증을
확인하며 이미지 GET은 skipped로 보고한다. 전용 operator Dockerfile은 source와 같은 주 버전
pg_dump와 작업 모듈을 포함한다. API에는 백업 자격을 추가하지 않았다.

## 검증

사용자가 합의한 운영 도구/인증 API 경계에서 red→green으로 확인했다.

- 보존 작업 부재, 빈 서비스 manifest 거부, 최신 checkpoint 검사 부재를 먼저 재현했다.
- 7일에 늦게 정리해도 성공으로 표시하던 문제를 실패 테스트로 재현해 overdue 보고로 수정했다.
- 현재 원본이 사라져도 유지 지점을 건강하다고 표시하던 문제를 재현해 HEAD 검증을 추가했다.
- 관련 단위/외부 S3 대역 검사: `test_image_backup.py`, `test_backup_restore.py`,
  `test_image_backup_retention.py` 합계 **60 passed**, 9.09초.
- Ruff scripts·변경 검사 파일 및 `git diff --check` 통과.

실제 Docker 검사는 PostgreSQL16·moto5.2.4·기준 SHA의 API 이미지
`clipback-retention-api:check` 및 전용 PG16 operator 이미지를 사용했다.
`RUN_DOCKER_RECOVERY_TESTS=1`, `CLIPBACK_RECOVERY_TEST_IMAGE`,
`CLIPBACK_RECOVERY_OPERATOR_IMAGE`를 명시해 `test_image_backup_docker.py`를 실행했고
**3 passed**, 190.90초였다.

- local/S3 혼합 원본의 DB+바이트 실제 복원, 인증 GET, 손상/누락 백업 거부
- 같은 숫자 ID를 가진 예전 삭제 intent가 다른 saved_at·불변 키의 원본을 지우지 않음
- pg_dump 프로세스를 멈춘 온라인 백업 중 실제 API DELETE가 3초 안에 204, 물리 원본은 보호
- live ledger head 누락 시 복원 거부 후 정상 기록 복구 시 삭제 적용
- 삭제 전 지점 복원 후 콘텐츠·binary·access descriptor 404, 원본 0건의 실제 users/me 인증
- 전용 operator 이미지 안에서 실제 pg_dump16.15로 빈 서비스 daily 완료, 중복 날짜 건너뛰기
- 동시에 실행한 job 거부, 6일 경계 사본 제거, 살아 있는 ledger 기록 보존

소유한 Docker 컨테이너·네트워크·볼륨 정리를 확인했다. 첫 실행은 마지막 fixture 설정의 JSON
배열 파싱 문제로 실패해 수정했고, 다음 실행은 가용 디스크 1GiB 보호 검사에 걸려 시작 전에
중단됐다. 안전 여유를 낮추지 않았으며 작업 소유 산출물 정리 후 정상 실행했다. 최종 단위 검사도
같은 공간 부족으로 한 차례 실패했으며 공간 확보 뒤 위 59개가 모두 통과했다.

Docker 본검사 후 유지 지점 HEAD 존재/크기 확인, 삭제 HEAD 확인, 수동 create/GC 직렬화 및
bounded tip 캡처를 추가했다. 최종 operator 이미지를 갱신해 같은 실제 Docker 모듈의 핵심
`old_point` 시나리오를 다시 실행했고 **1 passed, 2 deselected**, 76.84초였다. 과거 prefix 누락으로
backup manifest가 게시되지 않는 것과 수동 create도 실행 중 job을 거부하는 경우를 보완했다.
전체 통합 회귀와 모든 티켓을 합친 API 이미지 기준 검증은 통합 작업에서 이어간다.

마지막 부분 실패 검토에서는 manifest를 내린 뒤 원본 삭제가 실패한 경우 legacy(hash NULL)
삭제와 사본의 연결이 사라져 늦은 재시도를 성공으로 표시하던 문제를 추가 재현했다. 같은 Bucket의
작은 GC receipt를 먼저 영속 저장하고 확인된 정리가 끝나야 지우도록 수정했다. 최종 60개에는
manifest가 이미 사라진 뒤 하루가 지나 재시도해도 overdue를 놓치지 않는 검사가 포함된다.

## 경계

실제 Railway 권한·운영 cron·운영 중단/전환·공급자 장애 복구를 검증한 것은 아니다. 스케줄러와
nonzero 알림은 운영자가 별도로 활성화해야 한다. restore-check는 원래 쓰기 주체가 중지됐다는
운영자 확인을 전제로 하며 실제 중지를 자동 확인하지 않는다. 실제 전환까지 쓰기 중지를 유지한다.
계정 전체 손실과 악의적인 ledger 전체 rollback은 보장 범위가 아니다. 수동 다운로드 사본은
임시 폴더 수명과 운영 정책을 따르며 도구가 임의 사용자 디렉터리를 탐색·삭제하지 않는다.
