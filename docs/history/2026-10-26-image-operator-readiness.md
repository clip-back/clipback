# 원본 운영자 통합 검증과 첫 실행 인계

기준: #97, 하위 #98~#102. 이 기록의 #102 보완은 `a9a7f60`을 기반으로 한다.
실제 운영 실행은 수행하지 않았으며 #102와 부모 #97은 해당 증거 확보 전 열린 상태로 유지한다.

## 통합 준비

- 실제 점검 통합 검사가 CI에서 설정 누락으로 건너뛰어지지 않도록 PostgreSQL 18 migration job에
  별도 `clipback_maintenance100` 생성·migration과 `MAINTENANCE_TEST_DATABASE_URL`을 연결했다.
- 기존 PostgreSQL 16 배포·삭제 기록 초기화 검사는 유지했다. 별도 `operator-recovery` job은 같은
  커밋 라벨의 API·PostgreSQL 18 운영자 이미지로 새 운영 명령과 기존 복원 검사를 실행하도록 구성했다.
- lint·compile 범위에 운영 scripts를 포함했다. CI 설정 변경은 원격 CI 실행 성공을 뜻하지 않는다.
- [첫 운영 실행 체크리스트](../backend/image-operator-first-run.md)에 역할·설정·Volume 등록·내부 연결·공개
  차단·수동 백업·Mac 준비·점검·복원·재개·정리 및 미완료 판정 기준을 정리했다.

## 이 보완에서 실행한 검증

- YAML 구조, workflow shell 단계 21개와 내장 Python 문법, 실제 테스트 모듈 경로를 확인했다.
- 관련 문서 상대 링크 77개와 새 운영 체크리스트 shell 블록 6개의 문법을 확인했다.
- 실제 CLI의 `restore_execution`, `image_backup_jobs`, `maintenance` help가 문서의 명령과 맞는지 확인했다.
- 점검 통합 테스트 5개가 수집되는 것을 확인했다. 이 보완에서 전체 DB·Docker 검사를 중복 실행하지 않았다.
- `git diff --check`를 확인했다. 최종 통합 소스의 전체 DB·Docker 실행과 두 축 코드 리뷰는 통합 결과에
  별도 기록한다. 앞선 티켓별 결과는 [작업 이력 목차](README.md)의 각 기록을 따른다.

## 실제 운영 미완료 항목

실제 API·운영자 배포, 콘솔 변수 공급, Volume 식별 등록, Railway 내부 연결·공개 차단,
Mac CLI/SSH 준비, 운영 수동 백업 1회, 실제 쓰기 중단·격리 복원·명시적 재개와 임시 자료 정리는
모두 별도 운영 요청·실행 증거가 필요하다. 이 기록에는 해당 항목의 성공을 표시하지 않는다.

실패한 검증 결과나 코드/합성/CI 성공을 신규 Bucket 저장 전환·이관의 근거로 대신하지 않는다.
일일 일정·물리 삭제 재처리·보존 정리 가동은 후속 작업이다.
