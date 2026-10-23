# DB·원본의 단일 Bucket 복구 지점

2026-10-23, 이미지 보관 명세 [#64](https://github.com/clip-back/clipback/issues/64)의
[#70](https://github.com/clip-back/clipback/issues/70) 구현 기록입니다.
기준 통합 commit은 `b5b41ca`이며 실제 운영 배포·원본 자료·Railway 자격은 사용하지 않았습니다.
현재 명령과 계약은 [격리 복원 안내](../backend/backup-recovery.md)를 따릅니다.

## 변경과 확인 경계

- 운영자 별도 자격 파일로 private 백업 Bucket에 DB dump와 실제 원본을 보관합니다.
- 원본과 같은 Bucket을 거부하고 API 설정에는 백업 자격을 추가하지 않습니다.
- 원본 SHA별 불변 사본을 재사용하고 manifest를 마지막에 게시합니다.
- exported DB snapshot과 원본 물리 삭제 lock을 공유하며 수동 쓰기 중지를 필수로 확인합니다.
- 기존 v1 입력을 유지하고 v2 Bucket 원본을 내부 Docker moto로 복원하여 실제 인증 GET을 검사합니다.
- 단일 지점 검사에 최신 삭제 반영·일일 실행·7일 보존 완료를 포함하지 않습니다.

## 검증

작성 중입니다. 최종 실행 수치와 실제 Docker 결과는 구현 commit의 후속 검증 후 갱신합니다.
