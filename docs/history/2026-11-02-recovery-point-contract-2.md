# 복구 지점 계약 2차: 읽기 전용 점검 모듈, `storage_key` 규칙, 객체 오류 코드

최초 기록일: 2026-11-02 KST. 기준은 [spec #183](https://github.com/clip-back/clipback/issues/183)과 티켓 #184·#185·#186이다.
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
- 같은 운영 문서의 제목과 본문에 남아 있던 "격리 복원 검사" 세 곳을 용어집 명칭 "격리 복원 검증"으로 바꿨다(티켓 리뷰 S1).
  이 제목·앵커를 가리키는 링크나 테스트는 없다. 과거 이력 문서와 `CHANGELOG.md`의 기존 항목은 기록이므로 그대로 두었다.

### 구현자 판단

- **키 목록 공유**: 정규화되지 않은 키 5가지를 Bucket 테스트의 `UNNORMALIZED_KEYS`에 두고 폴더 테스트가 import한다.
  Bucket 테스트에서는 기존 `CORRUPTIONS`에 10가지(키 5가지 × `local`·`s3`)를 더해, 기존 신선·만료·receipt 테스트가 그대로 돌게 했다.
  점검 테스트의 같은 목록은 기대값만 바꾸라는 결정에 따라 그대로 두었다.
- **폴더 입력**: 폴더 테스트의 archive는 정규화한 경로로 저장하므로, 키만 정규화되지 않고 archive 이름은 맞는 폴더다.
  v1 폴더는 `local` asset 하나에 키를 넣었다.
- **점검 테스트 이름**: 기대값이 `passed`에서 `invalid_manifest`로 바뀌어 `test_audit_passes_an_unnormalized_storage_key`를
  `test_audit_reports_an_unnormalized_storage_key`로 바꾸고 docstring을 고쳤다. 입력은 그대로다.
  티켓 리뷰 P1은 "기대값만 바꾼다"는 범위를 넘었다고 지적했다. 이 결정은 다른 경우의 기대값을 건드리지 말라는 뜻으로 보고
  이름을 유지했다. `passes` 이름과 "#178 전까지 받아들임" docstring을 두면 `invalid_manifest`를 단언하는 테스트의 설명이 거짓이 된다.
  pytest node ID가 바뀌지만 이 이름으로 테스트를 지정하는 실행기는 저장소에 없다.

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

## 완료 지점 객체의 오류 코드(#186, 출처 #179)

### 사용자 결정

- 완료 지점의 객체를 읽다 난 모든 S3 응답 오류(`ClientError`)는 `backup_object_missing_or_unavailable`이다.
  `download`의 원본 보관본 `AccessDenied`도 같다.
- 변환은 `verify`·`download` 경로에서만 한다. `maintain`과 게시(`create`·`daily`)는 지금 값을 유지한다.
- `ClientError`가 아닌 botocore 오류(연결 실패 등)와 응답 본문 읽기 중단은 지금처럼 일반 오류(`backup_operation_failed`)다.
- 점검 모듈 테스트는 dump 없음·`AccessDenied`의 기대값만 바꾼다. #185에서 바꾼 기대값과 폴더 출력 고정 테스트는 바꾸지 않는다.

### 변경 내용

- `backend/scripts/image_backup.py`
  - `verify_backup`: dump·원본 보관본의 크기·해시를 확인하다 난 `ClientError`를 `backup_object_missing_or_unavailable`로 바꾼다.
  - `materialize_backup`(`download`): dump 내려받기의 `ClientError`와 원본 보관본 읽기의 없음(`FileNotFoundError`)·
    `backup_store_unavailable`을 같은 코드로 바꾼다. 실패했을 때 폴더가 남는 동작은 그대로다.
  - 공용 adapter 메서드(`read`·`download_verified`·`verify_object`)는 바꾸지 않았다. 게시가 같은 메서드를 쓴다.
- `backend/scripts/recovery_point.py`의 `point_unchanged`: 다시 읽은 manifest가 없으면 바뀐 것(거짓)으로 본다.
  `verify`는 `backup_point_changed`를 보고한다. 그 밖의 S3 오류는 지금처럼 `backup_store_unavailable`이다.
  되돌리기 절차가 찾는 `def point_unchanged` 문자열은 그대로다.
- 읽기 전용 점검은 `verify_backup`을 그대로 부르므로 dump 없음·`AccessDenied`의 지점 결과가 `NoSuchKey`·`ClientError`에서
  `backup_object_missing_or_unavailable`로 바뀌었다.
- 운영 문서(`docs/backend/backup-recovery.md`)의 "손상 manifest의 오류 코드" 절에 객체 없음·S3 오류(`maintain`은 만료 지점만
  참조하는 객체를 확인하지 않음), 재조회 없음 `backup_point_changed`, 없는 지점 ID `backup_operation_failed`를 적었다.
  점검 출력 설명의 예외 이름 예시(`NoSuchKey`)는 더 이상 나오지 않아 `FileNotFoundError`(receipt 사라짐)로 바꿨다.

### 구현자 판단

- **변환 위치**: 세 변환을 모두 명령 함수(`verify_backup`·`materialize_backup`)에 두었다. `verify_object`는 `verify`만 쓰지만,
  adapter 메서드는 하나도 바꾸지 않는 쪽이 "공용 메서드는 바꾸지 않음"을 확인하기 쉽다.
- **원본 보관본 읽기**: `download`는 공용 `read`를 그대로 쓰고, `read`가 S3 오류를 알리는 두 형태(`FileNotFoundError`,
  `backup_store_unavailable`)를 잡아 바꾼다. `read`가 이 둘을 내는 것은 `ClientError`에서뿐이고, 본문 읽기 중단은 그대로 지나간다.
- **재조회 없음**: #183 결정대로 `point_unchanged`가 거짓을 돌려주게 했다. 이 함수의 단위 테스트(`test_recovery_point`)는
  지금까지 없으면 `FileNotFoundError`를 단언했으므로 마지막 단언을 `is False`로 바꿨다. 새 경우를 더하지는 않았다.
- **Docker 테스트**: `test_image_backup_docker.py`의 원본 보관본 삭제 경우가 `FileNotFoundError`를 기대했다.
  이제 `materialize_backup`이 `backup_object_missing_or_unavailable`을 내므로 기대값을 바꿨다. 로컬에서는 Docker가 없어 실행하지 않았다.
- **본문 읽기 중단·연결 실패 테스트**: 수용 기준의 "지금처럼 일반 오류"를 고정하려고 Bucket 출력 고정에 네 경우를 더했다.
  변환을 `ClientError`보다 넓히는 변형을 잡는다.

### 테스트

- Bucket 출력 고정(`test_recovery_point_bucket_outputs`)
  - dump 없음, 원본 보관본 없음, 각각의 `GetObject`·`HeadObject` `AccessDenied` × 신선·만료 지점: `verify`·`download`가
    `backup_object_missing_or_unavailable`이다. `download`가 남긴 폴더는 dump 실패면 빈 폴더, 원본 보관본 실패면
    `database.dump`·`images.tar`다. 같은 입력의 `maintain`은 지금 값이다(보존 지점과 함께 참조하는 원본 보관본과 보존 지점의
    dump는 같은 코드, 만료 지점의 dump 없음은 성공, 만료 지점의 dump `AccessDenied`는 `backup_cleanup_unverified`).
  - 보존 지점이 다른 원본 보관본을 쓰는 독립 입력(스펙 리뷰 P1): 만료 지점만 참조하는 원본 보관본이 없으면 성공
    (`expired_points: 1`, `removed_originals: 1`), `AccessDenied`이면 `backup_cleanup_unverified`다.
  - `test_verify_reread_of_a_removed_manifest`를 `backup_point_changed`로 바꾸고 docstring을 고쳤다.
    재조회 `AccessDenied`(`backup_store_unavailable`), 없는 지점 ID(`backup_operation_failed`, 폴더 없음),
    첫 manifest 읽기 `AccessDenied`(`backup_store_unavailable`, 폴더 없음)를 고정했다.
  - dump·원본 보관본의 연결 실패(`EndpointConnectionError`)와 본문 읽기 중단(`ReadTimeoutError`): `verify`·`download`가
    `backup_operation_failed`다.
  - 게시(`publish_backup`, 스펙 리뷰 P4): 아래 시작 커밋 측정값을 고정하고, Bucket 키 목록으로 manifest가 게시되지 않았음을 확인한다.
    정상 게시의 키·바이트 고정 테스트는 그대로다.
- 점검 모듈(`test_recovery_point_audit`): dump 없음·`AccessDenied`의 지점 결과(문서 명령 테스트의 dump 없음 포함)만 바꿨다.
- 시작 커밋 측정(`509c5cb`, 구현 전 측정 스크립트로 실제 호출)
  - 객체 없음·`AccessDenied`, 재조회, 없는 지점 ID, 첫 manifest 읽기는 #183 "현재 동작 측정"과 같았다.
  - 만료 지점만 참조하는 원본 보관본: 없음은 성공(`expired_points: 1`), `AccessDenied`는 `backup_cleanup_unverified`.
  - 게시: dump 업로드 뒤 다시 읽기의 없음은 `NoSuchKey`, `AccessDenied`는 `ClientError`로 `CheckError`가 아니다.
    `create`는 `backup_operation_failed`, `daily`는 `backup_job_failed`로 보고한다(두 명령의 `main()` 변환은 코드로 확인).
    기존 원본 보관본 읽기의 `AccessDenied`는 `CheckError("backup_store_unavailable")`다. 세 경우 모두 manifest는 게시되지 않았다.

### 변경 감지 확인

- 새·바뀐 Bucket·게시 테스트 21개와 같은 범위의 기존 테스트 2개(재조회 JSON 아님, 정상 게시)를 `a06a48b`와 시작 커밋 `509c5cb`의
  임시 worktree에서 실행했다. 두 커밋 모두 같은 9개가 실패했고 모두 바뀌는 행이다(객체 실패 8개의 `verify`·`download`, 재조회 없음).
  실패한 8개에서도 `maintain`은 같았고, "변경 없음" 행(재조회 `AccessDenied`, 없는 지점 ID, 첫 manifest 읽기, P1 독립 입력,
  연결 실패·본문 읽기 중단, 게시 3개)과 기존 2개는 통과했다. 게시 코드(`image_backup.py`)는 두 커밋 사이에 바뀌지 않았다.
- 점검 모듈 테스트를 #184 완료 커밋 `45fd213`의 임시 worktree에서 실행했다. 13개가 실패했다. #185의 정규화되지 않은 키 10개를
  빼면 이 티켓이 바꾼 3개(dump 없음·`AccessDenied`, 문서 명령의 dump 없음)뿐이다.
- 운영 코드를 복사해 두고 변형을 하나씩 넣은 뒤 Bucket·점검·단위 테스트 세 파일을 실행하고 복사본으로 되돌렸다.

| 변형 | 결과 |
| --- | --- |
| `verify` 객체 오류 변환 제거 | 11개 실패(Bucket 객체 실패 8, 점검 3) |
| `download` 원본 보관본 읽기의 변환 제거 | 4개 실패(원본 보관본 없음·`AccessDenied` × 신선·만료) |
| 재조회 없음을 다시 일반 오류로 | 2개 실패(재조회 없음, `point_unchanged` 단위 테스트) |
| 공용 `download_verified`에서 변환 | 2개 실패(게시 dump 다시 읽기의 없음·`AccessDenied`) |
| 공용 `read`에서 변환 | 4개 실패(게시 원본 보관본 `AccessDenied`, 재조회·첫 manifest 읽기 `AccessDenied`, 점검 receipt `AccessDenied`) |
| `verify`가 `ClientError` 대신 모든 예외를 변환(추가) | 4개 실패(연결 실패·본문 읽기 중단) |
| `download` dump 내려받기의 변환 제거(추가) | 4개 실패(dump 없음·`AccessDenied` × 신선·만료) |
