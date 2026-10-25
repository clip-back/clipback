# 이미지 local 유지 호환 배포 준비 구현·검증

2026-10-25, 명세 #93과 구현 티켓 #94–#96의 코드 준비 이력이다. 실제 Railway 설정·초기화·배포
완료 기록이 아니다. [준비 계획](../backend/image-storage-merge-preparation.md)과
[운영 체크리스트](../backend/image-storage-compatible-deployment.md)를 구분해 사용한다.

## 구현과 검증 소스

- #94 `d62c271471a31572978fe753a592fd799aaf02b5`: main `83b618a` 통합, 기존 revision을
  변경하지 않는 merge revision `202610250019`, 빈 DB·카테고리/이미지 분기 업그레이드 검증.
- #95 구현 `6961d91536ec2bee14f58cfd145b50185303a715`, 통합 `1d4773845bde05ddd17639e3092040e217f99e4e`:
  삭제 기록 전용 설정, DB/API 설정 없는 init·checkpoint, 기존 retry 설정 유지, 운영자 패키징과 Mac 안내.
- #96 `0fb05dcd3112b4581ca2ff565970f680341ed10a`: 동일 소스 API·운영자 이미지의
  초기화→local 이미지 API 통합 검사, CI 배포 검사 추가, 삭제 기록을 배포 전에 준비하는 운영 인계.

마지막 코드·테스트 커밋 `0fb05dc`의 깨끗한 소스에서 빌드한 이미지:

| 이미지 | 실제 image ID | OCI revision |
| --- | --- | --- |
| API | `sha256:c3752c954168e78ce14244129fb578be154cd13636e58df9ee0d71ded190dcc2` | `0fb05dcd3112b4581ca2ff565970f680341ed10a` |
| 운영자 | `sha256:007182acf9e3f3d5dafd19847fef36d61c2076aab5deab47829645d76a944e0c` | `0fb05dcd3112b4581ca2ff565970f680341ed10a` |

이 이력을 추가하는 문서 커밋은 위 검증 소스와 구분한다. 새 코드 변경이 생기면 위 결과를 새 코드의
검증 결과로 재사용하지 않는다.

## 실제 실행 결과

| 경계 | 결과 | 조건과 한계 |
| --- | --- | --- |
| #94 migration | **3 passed** | 실제 PostgreSQL, 빈 DB·카테고리·이미지 분기, 기존 자료·제출 기록 보존, 반복 upgrade·alembic check |
| #94 Flutter 전체 | **1,992 passed**, analyze 통과 | 호스트 통합 검사이며 실기기·공급자 검증 아님 |
| #94 backend 전체 | **1,125 passed / 20 skipped** | 실제 테스트 DB 사용, Docker opt-in은 이 실행에서 제외 |
| #95 Docker CLI | **11 passed**, 기본 진입점 별도 **1 passed** | HTTPS 합성 S3, 최소 설정, 기록 손상·권한·연결 오류·비밀값 비노출 |
| #95 기존 설정·저장소 | **32 passed** | API 설정 계약 유지 |
| #95 실제 DB 삭제·retry | **20 passed** | 격리 PostgreSQL16, 운영 데이터 아님 |
| #95 통합 전 backend | **647 passed / 490 skipped** | DB·Docker 미활성 broad run; 전체 DB 통과로 해석하지 않음 |
| #95 main 통합 후 | DB 삭제·retry **20 passed**, 설정 **32 passed**, Docker 핵심 **2 passed** | 운영자 이미지 재빌드 후 실행 |
| #96 최종 Docker | **14 passed**, 56.52초 | bootstrap 12개와 handoff 2개; 위 동일 소스 이미지 사용 |
| #96 최종 backend | **1,125 passed / 34 skipped**, 115초 | 실제 격리 PostgreSQL. 14개 신규 Docker skip은 위 별도 실행에서 통과, 나머지 20개 기존 opt-in은 이번 재실행 제외 |
| #96 정적·스키마 | Ruff·diff 검사·alembic check 통과 | workflow YAML도 파싱 확인 |

각 backend/Docker 실행에는 기존 FastAPI/Starlette testclient 폐기 예정 경고 1개가 있었다.
여러 실행의 통과 수를 하나의 실행 결과로 합산하지 않는다. #96은 Flutter 제품 코드를 바꾸지 않았다.

## 실패를 먼저 확인한 경계

- 병합 revision 추가 전 실제 PostgreSQL 검사는 `Multiple heads`로 실패했다. 추가형 병합 후
  세 시작점의 업그레이드와 자료 보존을 확인했다.
- 기존 운영자 이미지는 초기화 모듈이 없어 실패했다. 패키징·최소 설정 분리 후 실제 이미지에서 통과했다.
- #96은 이전 API image revision을 공급하면 자원을 만들기 전에 실패했다. 같은 깨끗한 커밋의
  API·운영자 이미지를 빌드한 뒤 통과했다.
- 최초 통합 시도는 기존 probe의 PNG가 업로드 검증에 맞지 않아 실패했다. 유효한 합성 PNG로
  시험 자료를 바로잡았으며 제품 결함 수정으로 기록하지 않는다.

최종 handoff는 실제 업로드·동일 원본 조회·타 계정 404·삭제 후 404·삭제 기록 namespace와
sequence 진행을 확인했다. 독립된 손상 시나리오에서는 checkpoint 실패와 삭제 503, 원본 유지가
확인됐고 readiness는 200이었다. 따라서 readiness만으로 운영 준비 완료를 판정하지 않는다.
OCR은 기존 미설정 fallback을 사용했고 외부 통신이 없는 합성 Docker 네트워크에서 실행했다.

## 리뷰와 남은 확인

- Standards 리뷰의 **P3 문서 상태 불일치 1건**: 준비 문서의 구현 전 표현을 현재 코드 완료·운영
  미실행 상태로 수정하고 이 영구 이력을 연결했다. 전체 diff의 spec 끝 빈 줄도 정리했다.
- Spec 리뷰: **발견 사항 0건**.
- **최종 원격 CI: 확인 대기.** 위 로컬 결과나 이전 PR 커밋의 CI를 최종 CI 성공으로 표시하지 않는다.
- 실제 Bucket 생성·키 입력·Mac 초기화·API 설정·PR 병합·운영 migration·기존 앱 검증은 미실행이다.
  부모 #93의 운영 확인은 체크리스트에서 별도로 추적한다.
- 백업·삭제 재처리의 운영 실행 경로와 스케줄, 실제 격리 복원, 신규 Bucket 저장, 기존 자료 이관도
  미실행이며 이번 코드 준비 완료에 포함되지 않는다.
