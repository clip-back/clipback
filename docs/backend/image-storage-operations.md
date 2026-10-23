# 이미지 사용량과 신규 저장 중단

이미지 원본·백업·전송 비용은 서버·DB·AI 비용과 구분해 확인한다. 월 1만 원은 초기 설계 목표이며
실제 청구액이나 자동 비용 상한이 아니다. 저장을 중단해도 이미 보관한 파일의 비용은 계속 발생한다.
실제 요금은 Railway의 사용량·청구 자료와 대조한다.

## 운영 명령

배포와 같은 코드·마이그레이션을 적용한 비공개 운영 환경의 `backend/`에서 실행한다.
`DATABASE_URL`, 원본 `STORAGE_*`·`S3_*` 설정은 운영 환경에서 주입하며 비밀값을 명령행에 넣지 않는다.
API 서버에는 백업 자격증명을 주입하지 않는다. 보고 명령만
[별도 백업 Bucket의 0600 자격 파일](backup-recovery.md#bucket-원본의-수동-백업과-v2-복구-지점)을 사용한다.

```sh
python -m scripts.image_storage_admin report --backup-config /private/backup-store.json --month 2026-10
python -m scripts.image_storage_admin pause
python -m scripts.image_storage_admin resume
```

`--month`를 생략하면 현재 UTC 월을 조회한다. 명령은 JSON을 출력하고 성공은 종료 코드 0,
검증·저장소·DB 오류는 1을 반환한다. 원인에 포함될 수 있는 키·토큰·서명 URL·사용자 콘텐츠를
로그에 노출하지 않도록 실패 시 고정 오류 코드만 출력한다. 공개 관리 API나 새 앱 화면은 없다.

## 보고 수치

| 항목 | 의미 |
| --- | --- |
| `accounts` | 계정 ID별 현재 접근 가능한 원본의 논리적 크기·장수. 이메일·이름·이미지 내용은 제외 |
| `logical_originals` | 계정별 논리적 원본 합계. 사용자가 삭제한 이미지는 즉시 제외 |
| `physical_storage.local_originals` | 로컬 원본 디렉터리의 실제 파일 크기·개수. 미참조 파일도 포함 |
| `physical_storage.bucket_originals` | 원본 Bucket의 모든 객체 크기·개수. 삭제 재시도 대기·미참조 객체도 포함 |
| `physical_storage.backup` | 별도 백업 Bucket의 모든 객체 크기·개수. DB dump·manifest·불완전 지점도 포함 |
| `observed_transfers.original_upload_local/s3` | 성공 커밋된 원본 쓰기 횟수·payload 크기. S3 항목이 API에서 Bucket으로 쓴 관측값 |
| `observed_transfers.proxy_download` | API가 원본 응답을 준비한 횟수·payload 크기. 수신 완료 보장은 아님 |
| `observed_transfers.direct_access_grant/proxy_access_grant` | 접근 정보 발급 건수. 이미지 다운로드 횟수·전송 바이트로 환산하지 않음 |
| `provider_transfer_bytes`, `backup_transfer_bytes`, `actual_cost_krw` | 이 계측으로 알 수 없어 `null`. 공급자 자료로 별도 확인 |

크기는 바이트로 출력한다. 파일 시스템·Bucket 순회와 DB 조회가 원자적인 스냅샷은 아니므로
동시 저장·삭제에 따라 시점 차이가 생길 수 있다. 로컬 디렉터리가 없거나 Bucket이 설정되지 않으면
해당 물리 수치는 `null`이다. 크기가 없는 과거 원본은 해당 저장소에서 크기를 확인하며, 확인에
실패하면 전체 명령이 실패한다. 알 수 없는 크기를 0으로 취급하지 않는다.

전송 집계는 UTC 일별 익명 카운터를 월 단위로 합산한다. 파일명·저장 키·해시·계정별 전송 이력은
기록하지 않는다. 실패 후 롤백된 쓰기, 공급자 재시도, HTTP·TLS 오버헤드, 직접 Bucket 다운로드는
포함하지 않는다. 따라서 실제 네트워크 전송량의 완전한 측정이나 청구 금액 추정으로 보고하지 않는다.

## 중단과 재개

`pause`는 이미 허용한 원본 저장의 DB 커밋·롤백을 기다린 뒤 상태를 커밋한다. 이후 새 이미지 저장은
OCR·원본 쓰기 전에 HTTP 409와 `detail.code=image_uploads_paused`로 거절한다.
이미 진행 중인 저장은 성공할 수 있으며, 명령이 끝나기 전 상태를 즉시 중단된 것으로 보고하지 않는다.
진행 중 요청이 멈춰 있으면 명령도 기다리므로 운영 환경의 DB 명령 제한 시간을 적용하고 재시도한다.
응답이 유실되면 같은 명령을 재실행해도 안전하다.

상태는 DB에 남아 API 재시작·다중 인스턴스에 공통으로 적용된다. 완료된 공유의 동일 키 재전송은
기존 저장 결과를 돌려주며 새 자료를 만들지 않는다. 키의 입력이 바뀌면 기존 충돌 규칙을 유지한다.
기존 이미지 열람·삭제와 링크 저장은 계속 가능하다. 본앱과 iOS·Android 공유는 기존 오류 영역에서
잠시 후 재시도하라는 사유를 보여주고, 선택한 이미지나 공유 초안을 보존한다.

`resume` 이후에는 다시 계정별 한도에 따라 저장할 수 있다. 자동 금액 차단·알림 채널·별도 사용량
화면은 추가하지 않는다. 백업·원본 삭제 재시도 작업은 이 스위치와 독립적으로 계속 운영한다.
