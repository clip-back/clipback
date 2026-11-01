---
status: accepted
---

# 복구 지점 manifest는 한 기준으로 검증하고, 격리 복원 probe는 독립 계약으로 남긴다

복구 지점의 키 배치(원본 보관본·지점 dump·manifest·정리 receipt), 식별자 형식, manifest 검증을
`backend/scripts/recovery_point.py`의 한 module로 모은다. 지금은 `verify`·`download`·`maintain`과
격리 복원 검사가 manifest를 서로 다른 엄격도로 검사한다. 그래서 같은 손상 manifest도 명령에 따라
`invalid_manifest`, 일반 오류(`backup_operation_failed`·`backup_job_failed`·`invalid_input_or_check_failed`),
`backup_hash_mismatch`로 다르게 보고된다. `verify`와 `maintain`은 복원할 수 없는 manifest를 성공으로
보고하기도 한다(예: 40자 SHA가 아닌 `app_commit`). 이를 하나로 통일하고, 손상 입력에서 바뀌는 오류 코드와
성공 → 실패(종료 코드 0 → 1) 전환은 동작 변경으로 명시해 받아들인다. 통일한 코드를 머지하기 전에 운영자가
그 코드로 운영 Bucket을 읽기 전용으로 확인한다. 완료 지점 전부는 `verify`로, 정리 중인 복구 지점의 receipt 전부는
이름·내용·완료 지점과의 충돌로 새 기준을 통과하는지 본다. receipt만 남은 지점은 `verify` 대상에 나타나지 않지만
보존 정리는 읽기 때문이다.
2026-11-01 설계 인터뷰에서 합의했으며, 구현 완료를 뜻하지 않는다.

## 검토한 대안

- **명령별 엄격도를 옵션으로 남겨 오류 코드를 그대로 유지하기**: 출력은 완전히 같지만 "올바른 manifest"의
  정의가 명령 수만큼 남는다. 또 module 인터페이스에 엄격도 옵션이 늘어 깊이가 사라진다. 지금의 차이는 의도한
  규칙이 아니라 검사하지 않은 필드가 `KeyError`로 새어 생긴 우연한 차이다. 운영 문서·CI·다른 스크립트 어디에도
  이 일반 오류 문자열로 분기하는 곳이 없었다. 반대로 의도된 명령별 규칙은 통일 대상이 아니라서 남긴다.
  보존 정리의 `retention_requires_v2` 우선 판정, 이관의 `migration_requires_v2_backup`, 내려받은 폴더의
  `format_version: 1` 허용이 여기에 해당한다.
- **`recovery_probe.py`도 새 module을 쓰게 하기**: probe는 백업 시점 리비전의 API 이미지 안에서 소스 문자열로
  실행된다. 그 이미지에는 새 module이 없을 수 있다. 그래서 probe 안의 `originals/sha256/` 키 문자열 중복은
  의도적으로 남긴다. 같은 이유로 probe가 import하는 `scripts.check_backup_restore.CheckError` 경로도
  공용 오류 module로 옮긴 뒤 다시 내보내 유지한다.

## 결과

새 module과 공용 오류 module은 API 이미지·operator 이미지·`.dockerignore` 허용 목록에 파일 단위로 추가해야 한다.
이 파일들이 이미지에 빠지면 이번 리비전 이미지로 하는 격리 복원이 import 오류로 깨진다. 이 실패는 비Docker 테스트로는
드러나지 않고, operator-recovery Docker 검사에서만 확인된다.
