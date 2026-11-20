# 콘텐츠 자동 태그 (#433)

저장한 콘텐츠에 서버가 태그를 붙이는 작업의 이력입니다. [상위 이슈 #433](https://github.com/clip-back/clipback/issues/433)

## #435 시간별 정리와 격리 복원에서 고아 태그 제거

2026-11-20에 기준 커밋 `1e2e711`에서 구현을 시작했습니다. 링크·이미지 삭제와 이미지 삭제 기록 재적용은 고아 태그를 남겼습니다. 회원 탈퇴와 계정 삭제 기록 재적용은 계정의 태그를 CASCADE로 삭제했습니다. 로컬 `maintain` 연결에서 테스트 태그를 지울 수 있는지도 확인했습니다. [이슈 #435](https://github.com/clip-back/clipback/issues/435)

한 문장으로 정리하면, 그 문장의 스냅샷을 잡은 직후에 연결이 확정될 때 그 연결까지 지워지는 경합을 로컬 PostgreSQL에서 재현했습니다. 사용자 결정에 따라 PostgreSQL 기본 격리 수준인 `READ COMMITTED`의 한 트랜잭션에서 두 문장으로 정리합니다. 먼저 `FOR UPDATE SKIP LOCKED`로 후보를 잠그고, 다음 문장에서 연결을 다시 확인해 어디에도 붙지 않은 태그를 지웁니다. 저장 쪽은 마지막 조회에서 `FOR KEY SHARE`를 얻고, 그때 사라진 태그를 한 번 다시 만듭니다.

- 시간별 `maintain`은 복구 지점 보존 정리와 삭제 장부 파기를 마친 뒤 별도 트랜잭션에서 태그를 정리합니다. 결과는 `orphan_tags_deleted` 건수를 담고, 태그 정리 SQL이 실패하면 종료 코드 1입니다.
- 격리 복원은 모든 삭제 기록을 적용한 뒤 커밋 직전에 같은 두 SQL 문장을 실행합니다. 현재 재적용 스크립트가 과거 API 이미지 안에서 실행되므로 SQL 문자열을 유지하고 테스트로 두 사본을 비교합니다. [백업과 복원 운영 안내](../backend/backup-recovery.md)

### 검증과 남은 확인

- 구현 `bccb792`의 기준 실측 6건과 커밋 전 부분 검사 257건이 통과했습니다. PostgreSQL 두 세션에서 정리가 잡은 태그 재생성, 미확정 링크 보호, 정리 시작 직후 확정된 링크 보호, 두 번째 정리 0건을 확인했습니다. `SKIP LOCKED`·태그 재생성·두 번째 문장의 재확인을 각각 제거하면 대응하는 검사가 실패했습니다.
- 검수 반영 `e8dd50b`는 전역 건수에 대한 테스트 의존을 줄이고, 실행 순서와 격리 수준 전제를 문서에 명시했습니다. 부분 검사 73건, 다른 계정의 고아 태그를 미리 심은 검사 6건이 통과했습니다. 복원 SQL의 재확인만 제거한 변형에서 사본 비교 테스트가 실패했습니다.
- `e8dd50b`에서 전체 `verify.py`가 12단계 모두 통과했습니다. 백엔드 pytest는 2,762건 통과, 50건 건너뜀, 경고 3건입니다. Flutter 테스트도 통과했습니다.

```text
pytest: 2762 passed, 50 skipped, 3 warnings in 345.34s (0:05:45)
pytest skip: 49 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=12 failed=0
```

- Docker 데몬이 꺼져 있어 이 티켓 범위의 Docker 검사 3건(기존 다계정 복원, 과거 API 이미지의 태그 복원, 수동 백업)을 로컬에서 실행하지 않았습니다. PR CI의 `operator-recovery`에서 확인합니다. 수동 백업용 축약 스키마에 대한 정리 SQL은 로컬 PostgreSQL에서 확인했습니다.
- 운영 연결의 실제 권한과 첫 정리 실행은 사용자 확인 단계입니다.
