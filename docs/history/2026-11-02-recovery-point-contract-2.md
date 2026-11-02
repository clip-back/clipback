# 복구 지점 계약 2차: 읽기 전용 점검 모듈, `storage_key` 규칙, 객체 오류 코드

최초 기록일: 2026-11-02 KST. 기준은 [spec #183](https://github.com/clip-back/clipback/issues/183)과 티켓 #184·#185다.
출처는 #177·#178·#179이고, 브랜치 `fix/recovery-point-contract-2`(시작 커밋 `0ed414a`)에서 작업했다.
앞선 작업은 [복구 지점 manifest 검증 기준 통일](2026-11-02-recovery-point-manifest-contract.md)에 있다.

## 읽기 전용 점검 모듈(#184, 출처 #177)

### 사용자 결정

- 이 티켓은 동작을 옮기는 단계다. 문서 코드 블록이 JSON을 출력하던 입력의 출력은 그대로 둔다.
  완료 지점의 객체 없음은 `NoSuchKey`·`ClientError`, 정규화되지 않은 `storage_key`는 `passed`로 고정한다.
- 바꾸는 것은 #183의 "#177 허용 변경" 세 가지다.
  - `passed`가 거짓이면 종료 코드 1이다.
  - receipt 읽기 중 `CheckError`가 아닌 예외도 첫 미확인 receipt 칸에 예외 클래스 이름으로 적고, 나머지는 `not_checked`다.
  - 키를 특정할 수 없는 실패(설정 읽기, 완료 지점 목록, receipt 목록)는 최상위 `{"passed": false, "error": ...}`다.
    앞서 확인한 지점 결과는 싣지 않는다.
- 읽기 전용 확인은 허용한 읽기 요청(`ListObjectsV2`·`GetObject`·`HeadObject`) 밖의 S3 요청을 botocore 이벤트에서 거부하는 방식이다.

### 변경 내용

- `backend/scripts/recovery_point_audit.py`를 새로 만들었다. 운영 문서 "`maintain`이 `invalid_manifest`로 멈췄을 때" 절의
  코드 블록과 같은 순서로 완료 지점마다 `verify_backup`을 실행하고, 정리 receipt를 키 순서로 읽어
  같은 ID 완료 지점과의 충돌 → `format_version` → 계약 순서로 검사한다. receipt의 객체는 읽지 않는다.
- 설정은 `--backup-config-file`이 있으면 그 파일, 없으면 `BACKUP_BUCKET_CONFIG_JSON`이다(`image_backup`과 같다).
- `backend/scripts/recovery_point.py`의 `read_retiring_points`에 이미 받은 receipt 목록을 넘기는 선택 인자 `items`를 더했다. 인자가 없으면 지금처럼 목록을 조회한다.
- 출력은 지금처럼 `indent=2`, 키 정렬 JSON이다. 최상위 오류 JSON도 같은 형식으로 출력한다.
- 모듈은 operator 이미지·API 이미지·`.dockerignore` 허용 목록에 넣지 않았다. 다른 모듈이 import하지 않는다.
- 운영 문서의 그 절 코드 블록을 `cd backend`와 실행 명령 한 줄로 바꾸고, 출력 설명과 종료 코드를 적었다.
  설정 파일 자리는 지금 자리표시자 `/absolute/private/backup-bucket.json`을 그대로 쓴다. 되돌리기 절차는 바꾸지 않았다.

### 구현자 판단

- **모듈 이름**: `scripts.recovery_point_audit`로 정했다(#183의 제안 이름).
- **receipt 목록은 한 번만 조회**: 문서 코드는 receipt 키를 목록으로 받은 뒤 `read_retiring_points`가 목록을 다시 조회했다.
  두 번째 조회의 실패가 첫 receipt 칸에 적혀, 아직 읽지 않은 receipt를 실패로 보이게 했다(티켓 리뷰 P1).
  `read_retiring_points`에 이미 받은 목록을 넘기는 선택 인자 `items`를 더해 점검은 목록을 한 번만 조회한다.
  목록 조회 실패는 receipt 유무와 관계없이 최상위 오류이고, 첫 미확인 칸에는 receipt 이름·본문 읽기의 실패만 적힌다.
  `maintain`은 인자 없이 부르므로 지금처럼 함수 안에서 목록을 조회한다.
- **문서 명령 테스트의 실행 방식**: 정상·손상 출력은 문서에서 꺼낸 작업 폴더·환경 변수·모듈·인자로 같은 프로세스에서
  `runpy.run_module`로 실행한다. moto는 프로세스 안에서만 동작하므로, 합성 설정의 endpoint(`http://127.0.0.1:9000`)는
  `MOTO_S3_CUSTOM_ENDPOINTS`로 moto가 받게 했다. `python -m` 진입과 작업 폴더는 별도 smoke가 subprocess로 확인한다.
  smoke의 인터프리터는 문서의 `.venv/bin/python` 대신 테스트를 실행한 인터프리터다(CI에는 `backend/.venv`가 없다).
- **명령 블록 찾기**: 그 절의 코드 블록을 모두 `shlex`로 나눈다(줄 끝 `\` 이어 쓰기는 한 줄로 합친다). 나누지 못하는 줄이 있으면 실패한다.
  `-m` 단어나 `python`으로 시작하는 실행 파일 이름이 있는 블록이 정확히 하나여야 하고, 그 블록은 `cd <폴더>`와 명령 한 줄이어야 한다.
  처음에는 문자열 ` -m `으로 걸러 `python<TAB>-m`으로 쓴 두 번째 블록을 놓쳤다(티켓 리뷰 S1).
  되돌리기 절의 블록은 `git`·`docker` 명령뿐이라 대상이 아니다.
- **권한 오류**: 설정 파일 권한이 `0600`이 아닌 경우(`credentials_not_private`)와 상위 폴더를 읽을 수 없는 경우(`PermissionError`)를 둘 다 넣었다.

### 테스트

`backend/tests/deployment/test_recovery_point_audit.py`를 새로 만들었다. Bucket 출력 고정 테스트의 moto fixture와
지점 생성 함수를 import하고, 실제 `main()`의 출력과 종료 코드만 비교한다. `checked_at`은 형식을 확인한 뒤 자리표시자로 바꾼다.
모든 실행에서 허용한 읽기 요청 밖의 S3 요청을 거부하고, 거부된 요청이 없음과 출력에 Bucket 이름이 없음을 확인한다.

- 점검 출력: 정상, 계약 위반 지점, dump 없음(`NoSuchKey`)·`AccessDenied`(`ClientError`), 정규화되지 않은 키 5가지 ×
  `local`·`s3`(`passed`), receipt 이름 오류, receipt `AccessDenied`, receipt 사라짐, 본문 읽기 중단, receipt 충돌, v1 receipt,
  완료 지점 목록·receipt 목록 조회 실패, 설정 파일 없음·`0644`·상위 폴더 읽기 불가.
- receipt 목록 조회: receipt 있음·없음 각각에서 첫 조회 실패는 최상위 오류이고, 이후 조회를 모두 거부해도 결과가 정상이며 조회가 한 번뿐이다.
- 문서 명령: 문서에서 꺼낸 명령으로 정상·dump 없음 출력을 확인하고, 문서 작업 폴더에서 `python -m`을 실행하는 smoke가 있다.
- 시작 커밋에는 점검 모듈이 없어 기준 커밋 비교를 하지 않았다. 대신 시작 커밋 문서의 코드 블록을 같은 입력에 실행해 보았다.
  JSON을 출력한 입력(정상, 계약 위반, dump 없음·`AccessDenied`, receipt 이름 오류·`AccessDenied`·충돌·v1, 정규화되지 않은 키 10개)은
  모듈 기대값과 같았다. 나머지 네 입력(receipt 사라짐·본문 읽기 중단, 두 목록 조회 실패)은 JSON 없이 예외가 전파되었고,
  이것이 "#177 허용 변경"이다.
- 이 티켓의 완료 커밋이 #178·#179 티켓에서 점검 출력을 비교하는 기준이다.

### 변경 감지 확인

파일을 복사해 두고 변형을 하나씩 넣은 뒤 새 테스트 파일을 실행하고 복사본으로 되돌렸다.

리뷰 반영 뒤 32개 테스트 기준으로 모두 다시 실행했다.

| 변형 | 결과 |
| --- | --- |
| 문서 옵션명 변경(`--bucket-config-file`) | 3개 실패(문서 명령 출력 2, smoke) |
| 구현 옵션 제거 | 32개 모두 실패 |
| 문서 작업 폴더 변경(`cd backend/scripts`) | 1개 실패(smoke) |
| 종료 코드 항상 0 | 18개 실패 |
| `receipts` 필드 삭제 | 24개 실패 |
| `PutObject` 하나 보내기 | 27개 실패 |
| receipt 읽기의 `CheckError`가 아닌 예외를 다시 전파 | 2개 실패(receipt 사라짐, 본문 읽기 중단) |
| 문서 명령 블록을 둘로 | 3개 실패(블록이 하나가 아님) |
| 문서 명령 블록 삭제 | 3개 실패(블록을 찾지 못함) |
| 두 번째 명령 블록을 `python<TAB>-m`으로 추가 | 3개 실패(블록이 하나가 아님) |
| receipt 목록을 다시 두 번 조회 | 2개 실패(이후 조회 거부, receipt 있음·없음) |

## `storage_key` 정규화 규칙(#185, 출처 #178)

### 사용자 결정

- 폴더 검사는 asset별 순서(필드 → tar 경로 충돌 → archive 포함 여부, 그다음 asset)를 유지한다.
  모든 asset을 먼저 검사하도록 바꾸지 않는다(스펙 리뷰 P2).
- 게시 코드는 바꾸지 않는다. `maintain`은 아무것도 지우지 않고, `download`는 폴더를 만들지 않는다.
- 점검 모듈 테스트는 정규화되지 않은 키 경우의 기대값만 `invalid_manifest`로 바꾼다.
- 도메인 명칭은 "격리 복원 검증"을 쓰고 명령 이름은 그대로 쓴다(스펙 리뷰 S1).

### 변경 내용

- `backend/scripts/recovery_point.py`의 asset `storage_key` 검사에 "POSIX 경로로 정규화한 문자열과 같고 `.`이 아님"을 더했다.
  asset마다 필드를 검사하는 자리이므로 v1·v2, 게시 manifest·정리 receipt·다운로드 폴더에 모두 적용된다.
  tar 경로 충돌 검사와 archive 포함 확인은 바꾸지 않았다.
- 그 결과 [#175 변경 목록](2026-11-02-recovery-point-manifest-contract.md)의 예외 행(폴더에서 `u/./1.png`가 먼저인 tar 경로 충돌의
  `missing_asset`)이 없어졌다. 이제 첫 asset의 필드 검사에서 `invalid_manifest`다.
- 운영 문서(`docs/backend/backup-recovery.md`)의 v2 manifest 절에 규칙과 "업로드는 이런 키를 만들지 않으며 생기면 `maintain`이
  멈춘다"를 적고, tar 경로 설명에서 "정규화"를 뺐다. "`maintain`이 `invalid_manifest`로 멈췄을 때" 절의 첫 문단에 멈추는 원인을
  적었다. 되돌리기 기준 리비전은 그대로다.

### 구현자 판단

- **키 목록 공유**: 정규화되지 않은 키 5가지를 Bucket 테스트의 `UNNORMALIZED_KEYS`에 두고 폴더 테스트가 import한다.
  Bucket 테스트에서는 기존 `CORRUPTIONS`에 10가지(키 5가지 × `local`·`s3`)를 더해, 기존 신선·만료·receipt 테스트가 그대로 돌게 했다.
  점검 테스트의 같은 목록은 기대값만 바꾸라는 결정에 따라 그대로 두었다.
- **폴더 입력**: 폴더 테스트의 archive는 정규화한 경로로 저장하므로, 키만 정규화되지 않고 archive 이름은 맞는 폴더다.
  v1 폴더는 `local` asset 하나에 키를 넣었다.
- **점검 테스트 이름**: 기대값이 `passed`에서 `invalid_manifest`로 바뀌어 `test_audit_passes_an_unnormalized_storage_key`를
  `test_audit_reports_an_unnormalized_storage_key`로 바꾸고 docstring을 고쳤다. 입력은 그대로다.

### 테스트

- Bucket 출력 고정(`test_recovery_point_bucket_outputs`): 키 5가지 × `local`·`s3`에서 `verify`·`download`(폴더 없음)·
  `maintain`(신선·만료·receipt)이 `invalid_manifest`다. `TAR_COLLISIONS`의 `same_after_normalizing`은 기대값이 그대로이고,
  걸리는 이유가 키 규칙으로 바뀌었음을 주석에 적었다.
- 폴더 출력 고정(`test_recovery_point_folder_outputs`): 키 5가지 × `local`·`s3`의 v2 폴더와 5가지의 v1 폴더가 세 명령 모두
  `invalid_manifest`다. `same_after_normalizing` 행을 `invalid_manifest`로 바꾸고 예외 주석을 지웠다.
  단계 순서 테스트에 세 행을 더했다: DB 해시 불일치와 겹치면 `backup_hash_mismatch`, archive에 없는 정상 키가 앞이고
  정규화되지 않은 키가 뒤이면 `missing_asset`, 순서를 바꾸면 `invalid_manifest`.
- 점검 모듈(`test_recovery_point_audit`): 정규화되지 않은 키 10가지의 지점 결과가 `invalid_manifest`, 종료 코드 1이다.
- 기존 단위 테스트(`test_recovery_point`)는 고치지 않았고 그대로 통과한다.
- 시작 커밋 측정(구현 전, `a06a48b`에 새 테스트 파일을 복사해 실행): 폴더의 두 asset 순서는 모두 세 명령에서 `missing_asset`이었다.
  키 5가지는 `verify`·`maintain`이 성공, `download`가 `database.dump`·`images.tar`·`manifest.json`이 든 폴더를 남기고
  `missing_asset`, 폴더 세 명령이 `missing_asset`이었다.

### 변경 감지 확인

- 새·바뀐 Bucket·폴더 테스트를 시작 커밋 `a06a48b`의 임시 worktree에서 실행했다. 47개가 실패했고 모두 바뀌는 행이다
  (Bucket 신선·만료 20, receipt 10, 폴더 v2 10·v1 5, `same_after_normalizing`, 정규화되지 않은 키가 앞인 순서).
  "변경 없음" 행(Bucket의 `same_after_normalizing`, DB 해시와 겹침, 정상 키 누락이 앞인 순서)은 통과했다.
- 점검 모듈 테스트를 #184 완료 커밋 `45fd213`의 임시 worktree에서 실행했다. 정규화되지 않은 키 10개만 실패했다.
- 운영 코드를 복사해 두고 변형을 하나씩 넣은 뒤 세 테스트 파일을 실행하고 복사본으로 되돌렸다.

| 변형 | 결과 |
| --- | --- |
| `storage_key` 정규화 규칙 제거 | 57개 실패(시작 커밋 비교의 47개와 점검 10개) |
| `.` 허용(정규화 비교만 남김) | 11개 실패(`.` 키의 Bucket 6, 폴더 v2 2·v1 1, 점검 2) |
