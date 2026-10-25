# PR #75 local 유지 호환 배포 체크리스트

이 문서는 #93의 운영 인계 절차다. 코드·합성 검사 완료와 운영 배포 완료를 구분한다.
실제 Railway 자원·비밀값·DB·Volume을 자동 변경하는 도구가 아니다. 실행자는 단계별 결과를
아래 표에 기록하고 실패한 단계에서 멈춘다. PR 병합은 준비 완료 후 별도 요청에 따른다.

## 1. 코드와 동일 소스 이미지 준비 — 에이전트

- 최신 main 통합, 단일 Alembic head `202610250019`, 빈 DB와 두 분기 업그레이드 증거를 확인한다.
- 최종 PR 커밋의 CI·코드 리뷰를 확인한다. 과거 커밋의 성공을 재사용하지 않는다.
- 같은 깨끗한 커밋에서 API와 운영자 이미지를 빌드하고 commit·image ID를 기록한다.
  아래 명령은 저장소의 `backend/`에서 실행한다. 검증된 커밋을 먼저 체크아웃해야 한다.

```bash
git status --short
git rev-parse HEAD
docker info
# 예시는 합성 검증 PG16용이다. 실제 백업 도구 빌드는 운영 DB major에 맞춘다.
docker build --label "org.opencontainers.image.revision=$(git rev-parse HEAD)" \
  -t clipback-compatible-api:validated .
docker build --build-arg POSTGRES_MAJOR=16 \
  --label "org.opencontainers.image.revision=$(git rev-parse HEAD)" \
  -f Dockerfile.operator -t clipback-ledger-operator:validated .
docker image inspect --format '{{.Id}} {{index .Config.Labels "org.opencontainers.image.revision"}}' \
  clipback-compatible-api:validated clipback-ledger-operator:validated
```

작업 트리가 변경된 상태라면 깨끗한 커밋의 증거로 기록하지 않는다. 두 image ID는 서로 달라도
되지만 revision은 검증할 동일 커밋이어야 한다. 이후 명령에는 기록한 운영자 image ID를
사용해 태그 변경으로 다른 이미지가 실행되지 않게 한다.

## 2. 삭제 기록 준비 — 사용자, 병합 전

1. Railway에 **새 비공개 삭제 기록 전용 Bucket**을 만든다. 원본·백업 Bucket과 분리한다.
2. Bucket Credentials의 실제 endpoint·Bucket 이름·region·주소 방식과 전용 키를 확인한다.
   화면 표시 이름을 실제 Bucket 이름으로 추정하지 않는다.
3. [삭제 기록 초기화 안내](image-deletion.md)의 환경 변수 표대로 Mac의 보호된 파일을 작성한다.
   파일 권한은 0600으로 두고 Git·채팅·공유 로그에 올리지 않는다.
4. 필요한 변수는 `APP_ENVIRONMENT=production`, `DELETION_LEDGER_BACKEND=s3`와
   `DELETION_LEDGER_S3_ENDPOINT_URL`, `DELETION_LEDGER_S3_BUCKET`, `DELETION_LEDGER_S3_REGION`,
   `DELETION_LEDGER_S3_ADDRESSING_STYLE`, `DELETION_LEDGER_S3_ACCESS_KEY_ID`,
   `DELETION_LEDGER_S3_SECRET_ACCESS_KEY`다. DB·로그인·AI·원본·백업 키는 넣지 않는다.
5. Docker 구동을 확인하고, 검증된 image ID와 실제 보호된 파일 경로로 아래 자리표시자를 바꿔 실행한다.

```bash
docker run --rm --env-file /absolute/private/ledger-bootstrap.env \
  --entrypoint python sha256:VERIFIED_OPERATOR_IMAGE_ID \
  -m scripts.image_deletions init --confirm-new-namespace

docker run --rm --env-file /absolute/private/ledger-bootstrap.env \
  --entrypoint python sha256:VERIFIED_OPERATOR_IMAGE_ID \
  -m scripts.image_deletions checkpoint
```

**통과:** 두 명령 종료 코드 0, 같은 namespace·sequence·digest, 새 저장소 sequence 0.
**중단:** 연결·권한·설정·기록 오류, 성공 JSON 부재, 결과 불일치. 실제 공급자 접속 검증은 이 단계의
실행 결과로 남긴다. 합성 S3 테스트 성공만으로 대신하지 않는다. 기존 namespace는 init 없이
checkpoint만 실행하며 손상된 기록을 새 namespace로 덮어쓰지 않는다.

## 3. 점검과 API 설정 — 사용자

- 테스트 참여자에게 잠시 이용 중단을 안내한다. 실제 서버 쓰기 차단 기능을 켰다고 간주하지 않는다.
- 기존 API·배포 커밋, Volume 연결과 저장 경로를 기록한다. 테스트 자료를 유지하고 DB 초기화나 일괄 삭제를 하지 않는다.
- API의 `STORAGE_BACKEND=local`, `STORAGE_ROOT=/data/screenshots` 및 기존 Volume을 유지한다.
- API에는 위에서 검증한 `DELETION_LEDGER_BACKEND=s3`와 동일한 `DELETION_LEDGER_S3_*`를 적용한다.
  기존 API의 DB·인증 등 필수 설정은 유지한다. 초기화 전용 설정으로 전체 API 설정을 대체하지 않는다.
- 원본 S3 저장을 켜지 않고 백업 키를 API에 넣지 않는다.
- 설정 저장·적용이 별도 배포를 일으키는지 콘솔에서 확인하고, 발생한다면 배포 대상 커밋과 완료를 확인한다.
  미완료·실패한 설정 배포가 있으면 다음 병합을 진행하지 않는다.

## 4. 별도 요청에 따른 병합·배포 확인 — 사용자와 에이전트

- 초기화 결과·최종 CI·리뷰를 확인한 뒤 별도 병합 요청에 따라 진행한다.
- 자동 pre-deploy `alembic upgrade head` 성공과 실제 배포 커밋을 확인한다.
- 단일 head `202610250019`를 확인한다. 이미 배포된 revision의 부모를 바꾸거나 stamp로 덮지 않는다.
- `/api/v1/health/ready` 성공을 확인한다. 이 응답은 삭제 기록 초기화나 기능 완료를 증명하지 않는다.

## 5. 기존 앱 기능 검증 — 사용자, 에이전트는 결과 정리

- 유지한 이전 이미지가 올바른 계정에서 열리는지 확인한다. 다른 계정에 노출되면 실패다.
- 검증용 새 이미지를 저장하고 같은 원본을 다시 조회한다. 원본 무결성 결과와 사용한 앱 버전을 기록한다.
- 검증용 이미지만 삭제하고 상세·원본에 다시 접근할 수 없는지 확인한다. 임의의 기존 자료는 삭제하지 않는다.
- Mac에서 같은 `checkpoint` 명령을 실행해 삭제 기록 진행과 검증 성공을 확인한다.
- 영속 정리 작업 상태는 DB를 읽을 수 있는 승인된 운영 환경에서 확인한다. API 논리 삭제와
  원본의 물리 삭제 완료를 구분하고 확인하지 못한 물리 정리를 완료로 적지 않는다.
- 모든 필수 기능 검증이 통과하면 테스트를 재개한다. 실패하면 점검을 유지하고 수정·재검증한다.
  DB 변경이 적용됐을 수 있으므로 무조건적인 과거 버전 복귀나 DB 초기화를 하지 않는다.

## 실행 기록

| 단계 | 담당 | 상태 | 실제 결과·시각·증거 |
| --- | --- | --- | --- |
| 코드·동일 커밋 이미지·CI·리뷰 | 에이전트 | 결과 이력 참조 | 커밋·API/operator image ID |
| 실제 Bucket 생성·초기화·checkpoint | 사용자 | 미실행 | 비밀값 제외 |
| 점검 안내·API 변수·Volume 확인 | 사용자 | 미실행 | 설정 적용 배포 여부 |
| 별도 병합·자동 migration·배포 | 사용자/에이전트 | 미실행 | 배포 커밋·revision |
| 기존 앱 이미지 기능·삭제 기록·정리 상태 | 사용자/에이전트 | 미실행 | 논리 삭제/물리 정리 구분 |
| 테스트 재개 | 사용자 | 미실행 | 실패 항목 없을 때 |

신규 Bucket 저장·정기 백업·이관은 이 체크리스트 완료에 포함되지 않는다. 후속 단계에서는
실제 원본/백업 Bucket, 기존 local Volume에 접근하는 백업·삭제 재처리 실행 경로, 스케줄·실패 알림,
실제 격리 복원을 별도로 확인한다. Mac 초기화 컨테이너는 DB·원본에 접근하지 않으므로 재처리
운영 환경을 대신하지 않는다. 기존 Volume 사본은 이관만으로 자동 삭제하지 않는다.
