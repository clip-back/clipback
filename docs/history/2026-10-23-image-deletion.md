# 원본 이미지 삭제 기록과 정리 재시도

- 날짜: 2026-10-23
- 범위: 명세 #64의 하위 이슈 #69. 통합 브랜치 `feature/image-storage-integration`의
  `b2ee962`(Bucket 저장·조회 #65 통합) 기준에서 작업했다.
- 실행 환경: Python 3.12, 별도 PostgreSQL 17 테스트 DB `clipback_image_69`, 로컬 임시 파일,
  합성 자격 증명의 Moto S3 대역. 운영 사용자 데이터·Railway Bucket 자격 증명은 사용하지 않았다.

## 단계와 확인 방법

1. 독립 삭제 기록 후 DB 삭제 → 기존 인증 API에서 성공·503·404·원본 동일 바이트를 확인한다.
2. 영속 정리 큐와 재조정 → 저장소 실패·DB 커밋 불확실성·새 Python 프로세스의 재시도 명령으로 확인한다.
3. 복원 식별과 백업 잠금 계약 → 숫자 ID 재사용 보호와 실제 PostgreSQL shared/exclusive 잠금으로 확인한다.
4. 설정·운영 문서 → 잘못된 설정 거절, Alembic 일치, Ruff, 최종 diff로 확인한다.

## 변경 결과

독립 삭제 기록은 로컬 개발의 별도 파일 디렉터리 또는 운영의 독립 S3 Bucket에 보관한다.
API가 namespace를 자동 초기화하지 않으며 기록 쓰기와 읽기 확인을 마친 뒤에만 DB 삭제를
커밋한다. DB 삭제와 함께 FK cascade를 받지 않는 `image_deletions` 작업을 남긴다.
물리 정리는 백업과 공유하는 advisory lock을 사용하고, 실패 시 원본 참조를 다시 확인하며 재시도한다.
삭제 의도 이후 DB 커밋이 불확실한 경우도 독립 기록을 바탕으로 동일한 삭제로 수렴한다.

실패 업로드가 남긴 원본도 같은 DB 정리 큐에 기록한다. 특히 Idempotency-Key 없이 업로드한
원본의 DB 커밋 ACK가 유실될 때, 기존 코드는 커밋된 원본을 잘못 지워 GET 404를 만들었다.
DB 참조를 확인하고 커밋된 원본을 보존하도록 수정했다. 알려진 실패 PUT와 삭제 실패가 함께
발생해도 DB가 사용 가능하면 새 프로세스에서 정리를 재개한다.

기존 내부 FakeSession에 종속된 이미지 삭제 테스트 3개와 실패 업로드 테스트 2개는 실제
DB·인증 API·외부 파일/S3 장애·새 프로세스 검사로 대체했다. 링크 삭제와 다른 사용자의 접근
검사 등 관련 없는 기존 테스트는 유지했다.

## Red → Green 증거

- 누락된 독립 기록 상태에서 DELETE가 기존 204를 반환하는 실패를 재현했다. 변경 후 503이며
  원본 인증 GET은 동일한 바이트로 200이다.
- 새 프로세스 재시도 명령이 없어 종료 코드 2를 반환하는 실패를 확인한 뒤 명령을 추가했다.
  변경 후 영속 작업만 복구해 삭제된 원본을 정리하고 생존 콘텐츠는 보존한다.
- 실제 백업 shared 잠금 중 DELETE가 2초 제한에 걸리는 실패를 재현했다. 변경 후 논리 삭제는
  204로 완료하고 원본 정리는 잠금이 해제될 때까지 연기한다.
- 업로드 실패와 원본 정리 실패 후 파일이 영구히 남는 실패, 커밋 ACK 손실 뒤 이미 커밋된
  원본이 404가 되는 실패를 각각 재현했다. 변경 후 재시도 정리와 커밋 원본 보존을 확인했다.
- 별도 기록 설정 검증 6개가 `DID NOT RAISE`로 실패한 뒤 유효성 검사를 추가해 통과했다.
- 초기 순차 검증 구현은 삭제 12건에서 외부 Bucket GET이 요청당 9회에서 53회로 늘어나
  비용·지연 검사에 실패했다. foreground 쓰기를 head·tip·operation 직접 검증으로 바꾸어
  이력 수와 무관하게 요청 수가 일정한 검사를 통과했다. 복원의 전체 연결 검증은 유지했다.

## 실제 실행 검사

백엔드 디렉터리에서 `PYTHONPATH=.`와 전용 `TEST_DATABASE_URL`을 사용했다.

```bash
python -m pytest tests/services/test_content_service.py tests/services/test_upload_service.py \
  tests/integration/test_upload_and_isolation.py tests/integration/test_share_write_concurrency.py \
  tests/integration/test_image_deletion.py tests/test_config.py -q
```

- 최종 관련 검사 140개 통과. 이미지 삭제 API·재시도 검사만 16개 통과했다.
- Alembic `upgrade head` 및 `check`: 성공, 추가 미반영 작업 없음.
- `ruff check --no-cache .`: 통과.
- `git diff --check`: 통과. 신규 환경 변수 예시에는 실제 키를 넣지 않았다.

## 미검증·제한

실제 Railway 저장소·권한·배포·스케줄러는 변경하거나 검증하지 않았다. S3 ACK 손실과 장애는
SDK 경계의 합성 장애 및 Moto 동작이며 Railway 공급자 동작을 증명하지 않는다. 프론트엔드
변경이 없으므로 이 작업에서 모바일 실행 검증은 수행하지 않았다. 통합 후 전체 백엔드 검사와
모바일·실제 격리 복원 검증은 전체 검증 티켓 #74에서 수행한다.

PostgreSQL과 S3의 원자적 트랜잭션, 전체 독립 기록의 악의적 롤백 탐지, WORM을 제공하지 않는다.
원본 저장소와 DB가 함께 불가하면 정리 큐도 기록하지 못할 수 있으며 업로드는 실패를 유지한다.
삭제 기록은 메타데이터만 보존하고 자동 제거하지 않는다. 복원·운영 명령의 전체 이력 검증은
기록 수에 비례하는 I/O를 사용한다. 사용자 삭제 요청은 과거 전체 이력을 순회하지 않는다.
현재 동작·운영 명령은 [삭제 계약](../backend/image-deletion.md)에 유지한다.
