# 복구 지점 계약 2차: 읽기 전용 점검 모듈, `storage_key` 규칙, 객체 오류 코드

최초 기록일: 2026-11-02 KST. 기준은 [spec #183](https://github.com/clip-back/clipback/issues/183)과 티켓 #184다.
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
- 출력은 지금처럼 `indent=2`, 키 정렬 JSON이다. 최상위 오류 JSON도 같은 형식으로 출력한다.
- 모듈은 operator 이미지·API 이미지·`.dockerignore` 허용 목록에 넣지 않았다. 다른 모듈이 import하지 않는다.
- 운영 문서의 그 절 코드 블록을 `cd backend`와 실행 명령 한 줄로 바꾸고, 출력 설명과 종료 코드를 적었다.
  설정 파일 자리는 지금 자리표시자 `/absolute/private/backup-bucket.json`을 그대로 쓴다. 되돌리기 절차는 바꾸지 않았다.

### 구현자 판단

- **모듈 이름**: `scripts.recovery_point_audit`로 정했다(#183의 제안 이름).
- **receipt 두 번째 목록 조회의 실패**: 문서 코드처럼 receipt 키를 먼저 목록으로 받고, `read_retiring_points`가 다시 목록을 조회한다.
  두 번째 조회가 실패했는데 미확인 receipt가 하나도 없으면 칸을 정할 수 없으므로 최상위 오류로 보낸다.
  receipt가 있으면 첫 미확인 receipt 칸에 적힌다.
- **문서 명령 테스트의 실행 방식**: 정상·손상 출력은 문서에서 꺼낸 작업 폴더·환경 변수·모듈·인자로 같은 프로세스에서
  `runpy.run_module`로 실행한다. moto는 프로세스 안에서만 동작하므로, 합성 설정의 endpoint(`http://127.0.0.1:9000`)는
  `MOTO_S3_CUSTOM_ENDPOINTS`로 moto가 받게 했다. `python -m` 진입과 작업 폴더는 별도 smoke가 subprocess로 확인한다.
  smoke의 인터프리터는 문서의 `.venv/bin/python` 대신 테스트를 실행한 인터프리터다(CI에는 `backend/.venv`가 없다).
- **명령 블록 찾기**: 그 절에서 ` -m `을 담은 코드 블록이 정확히 하나여야 하고, 블록은 `cd <폴더>`와 명령 한 줄이어야 한다.
  되돌리기 절의 `sh` 블록은 ` -m `이 없어 대상이 아니다.
- **권한 오류**: 설정 파일 권한이 `0600`이 아닌 경우(`credentials_not_private`)와 상위 폴더를 읽을 수 없는 경우(`PermissionError`)를 둘 다 넣었다.

### 테스트

`backend/tests/deployment/test_recovery_point_audit.py`를 새로 만들었다. Bucket 출력 고정 테스트의 moto fixture와
지점 생성 함수를 import하고, 실제 `main()`의 출력과 종료 코드만 비교한다. `checked_at`은 형식을 확인한 뒤 자리표시자로 바꾼다.
모든 실행에서 허용한 읽기 요청 밖의 S3 요청을 거부하고, 거부된 요청이 없음과 출력에 Bucket 이름이 없음을 확인한다.

- 점검 출력: 정상, 계약 위반 지점, dump 없음(`NoSuchKey`)·`AccessDenied`(`ClientError`), 정규화되지 않은 키 5가지 ×
  `local`·`s3`(`passed`), receipt 이름 오류, receipt `AccessDenied`, receipt 사라짐, 본문 읽기 중단, receipt 충돌, v1 receipt,
  완료 지점 목록·receipt 목록 조회 실패, 설정 파일 없음·`0644`·상위 폴더 읽기 불가.
- 문서 명령: 문서에서 꺼낸 명령으로 정상·dump 없음 출력을 확인하고, 문서 작업 폴더에서 `python -m`을 실행하는 smoke가 있다.
- 시작 커밋에는 점검 모듈이 없어 기준 커밋 비교를 하지 않았다. 대신 시작 커밋 문서의 코드 블록을 같은 입력에 실행해 보았다.
  JSON을 출력한 입력(정상, 계약 위반, dump 없음·`AccessDenied`, receipt 이름 오류·`AccessDenied`·충돌·v1, 정규화되지 않은 키 10개)은
  모듈 기대값과 같았다. 나머지 네 입력(receipt 사라짐·본문 읽기 중단, 두 목록 조회 실패)은 JSON 없이 예외가 전파되었고,
  이것이 "#177 허용 변경"이다.
- 이 티켓의 완료 커밋이 #178·#179 티켓에서 점검 출력을 비교하는 기준이다.

### 변경 감지 확인

파일을 복사해 두고 변형을 하나씩 넣은 뒤 새 테스트 파일을 실행하고 복사본으로 되돌렸다.

| 변형 | 결과 |
| --- | --- |
| 문서 옵션명 변경(`--bucket-config-file`) | 3개 실패(문서 명령 출력 2, smoke) |
| 구현 옵션 제거 | 28개 모두 실패 |
| 문서 작업 폴더 변경(`cd backend/scripts`) | 1개 실패(smoke) |
| 종료 코드 항상 0 | 16개 실패 |
| `receipts` 필드 삭제 | 22개 실패 |
| `PutObject` 하나 보내기 | 23개 실패 |
| receipt 읽기의 `CheckError`가 아닌 예외를 다시 전파 | 2개 실패(receipt 사라짐, 본문 읽기 중단) |
| 문서 명령 블록을 둘로 | 3개 실패(블록이 하나가 아님) |
| 문서 명령 블록 삭제 | 3개 실패(블록을 찾지 못함) |
