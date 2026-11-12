# 백업 보존 정리·원본 삭제 재시도 정기 실행 준비 (#339)

2026-11-12, 브랜치 `feat/backup-deletion-ops`. 시작 커밋 `1c8bf47`(이슈 B 결정 기록 ADR 0013·GLOSSARY "삭제 장부"),
구현 커밋 `21621eb`, main의 #338(`885d05a`)을 합친 커밋 `9295e5e`(최종 전체 검증 기준). 이 기록을 더하고 고친 커밋은 문서만 바꾼다.

## 문제

- 처리방침 초안은 "탈퇴·콘텐츠 삭제 뒤 백업은 최대 7일 뒤 삭제"라고 적지만, 백업 보존 정리(`maintain`)는 운영에서 보류였고
  원본 삭제 재시도(`retry`)는 정기 실행이 없었다.
- 백업 서비스의 자동 배포가 꺼져 있어 옛 이미지가 2026-11-08 탈퇴 기록을 읽지 못하고 11-09부터 백업이 실패했다.

## 사용자 결정

2026-11-12 회의(1차 "Q8 받음 / Q10 남아있음 / 나머지 추천대로", 2차 "모두 추천대로")와 회의 뒤 추가 결정. 원문은 GitHub #339 본문에 있다.

- `maintain`(매시간 15분)·`retry`(매시간 45분)를 별도 Railway Cron 서비스로 돌리고, 백업·정리·재시도 서비스는 main 자동 배포 + CI 통과 대기를 켠다.
- 실패는 Railway "Deploy Crashed" 메일로 안다.
- 복구 지점 보존 기준만 7일 − 1시간으로 줄이고, 기한 미충족 보고는 7일 그대로 둔다.
- retry 방식 "가: 스크립트 넣고 안전장치": API 이미지에 `scripts/image_deletions.py`를 넣고, Volume을 실제로 볼 수 있을 때만 Volume 원본을 지운다.

## 착수 전 확인 (`1c8bf47`)

이슈의 사실 전제를 원래 코드에서 확인했고 모두 이슈 서술과 같았다.

- API `backend/Dockerfile`에 `scripts/image_deletions.py`가 없다(운영자 이미지·`.dockerignore`에만 있음).
- 빈 폴더 루트의 `LocalStorageClient.delete_file`은 오류 없이 끝나고, Volume이 없는 곳의 `local` 정리 작업은 `completed=True`가 된다.
- 보존 상수만 7일 − 1시간으로 잠시 바꾸면 `test_image_backup_retention.py` 14개 중 `test_original_missing_from_account_record_leaves_with_seven_day_retention` 하나만 실패한다(파일은 복사본으로 되돌림).
- 이관 alias는 Bucket 원본을 먼저 지우고, Volume 삭제가 실패하면 작업이 남으며, 다음 재시도의 Bucket 삭제는 없는 객체 삭제로 오류 없이 끝난다.

## 구현 (`21621eb`)

- `scripts/image_backup_jobs.py`: `POINT_RETENTION = 7일 − 1시간`, 기한 미충족 보고는 새 `DELETION_DEADLINE = 7일`.
- `backend/Dockerfile`: `scripts/image_deletions.py` 복사.
- `app/core/config.py`에 `operator_source_id`(선택)를 두고, `cleanup_image_deletion`이 `local` 원본(이관 alias 포함)을 지우기 전에
  `SourceReader.identified_root`로 Volume 식별 파일을 확인한다. 값이 없으면 지금처럼 지우고, 식별 파일이 없거나 다르거나
  ID가 비었거나 형식이 틀리면 지우지 않고 `last_error=original_volume_unavailable`로 남긴다.
- 문서: `docs/backend/image-operator-first-run.md`(상태, 자동 배포, `maintain`·재시도 서비스 설정과 첫 실행 기준),
  `docs/backend/backup-recovery.md`, `docs/backend/image-deletion.md`, `docs/railway-deployment.md`, `CHANGELOG.md`.
  `docs/image-storage-policy.md`는 "최근 7일"·"최대 7일" 문구라 바꾸지 않았다.

## 테스트

먼저 테스트를 바꿔 실패(8 failed)를 본 뒤 구현했다.

- `test_image_backup_retention.py`: `test_retention_boundary_removes_old_points_and_unreferenced_bytes`(이름 변경, 7일 − 1시간 경계와 1초 새 지점 유지),
  `test_copy_removed_before_seven_days_is_not_reported_overdue`(새 테스트, 보고 기준 7일),
  `test_original_missing_from_account_record_leaves_with_point_retention`(이름 변경, 지점 나이 6일 22시간, 기대값 유지).
  보고에도 보존 기준을 쓰는 변형에서는 새 보고 테스트만 실패했다.
- `test_image_deletion.py`: 식별 파일 없음·불일치·디렉터리·빈 ID에서 Volume 원본이 남고 식별 뒤 재시도에서 지워짐, 미설정·일치는 지금처럼 지움,
  이관 alias에서 Bucket 선삭제 뒤 Volume 사본이 남고 다음 재시도가 없는 객체 삭제로 완료됨.
  구현 중 빈 ID가 줄바꿈만 든 식별 파일과 일치로 판정되는 것을 이 테스트가 잡아 형식 검사를 더했다.
- `test_deletion_bootstrap_docker.py::test_api_image_includes_original_deletion_retry_command`: API 이미지에서 `python -m scripts.image_deletions --help`가 0으로 끝남(Docker).

## 검증

main의 #338(`885d05a`, 마이 통계 응답·앱 소비자 변경)을 합친 `9295e5e`에서 2026-11-12 17:19–17:28 로컬 전체 검증:

```text
pytest: 2517 passed, 48 skipped, 3 warnings in 288.12s (0:04:48)
pytest skip: 47 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=11 failed=0
```

- verify에 없는 `deptry .`는 같은 커밋에서 따로 실행해 통과했다(`Success! No dependency issues found.`).
- 전체 검증 전에 같은 `9295e5e`에서 양쪽 관련 테스트(서버 통계·#339 삭제·보존, 앱 `user_repository_test`·`account_stats_regression_test`·`my_stats_label_layout_test`)와 `flutter analyze --no-pub`를 먼저 돌려 통과했다. 두 변경이 함께 바꾼 파일은 `CHANGELOG.md`와 이 목차뿐이다.
- 합치기 전 `21621eb`의 전체 검증(17:08–17:17)도 PASS였다. 위 수치가 최종 기준이다.
- **미검증**: Docker가 필요한 `deployment`·`operator-recovery` job(새 API 이미지 검사 포함)은 로컬에서 돌리지 않았다. PR CI로 확인한다.
- 운영 Railway·운영 DB에는 접속하지 않았다. Volume 분리는 저장소 구성과 로컬 대역(임시 폴더)으로만 확인했다.
- 병합 뒤 운영 설정과 첫 실행 확인은 이 작업의 완료 조건이 아니며, #339 본문의 "병합 뒤 운영 순서표"로 따로 기록한다.
