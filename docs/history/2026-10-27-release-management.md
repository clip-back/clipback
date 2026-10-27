# 버전 관리와 배포 후보 준비 구현

최초 기록일: 2026-10-27 (KST). 기준 커밋: `12ebf273c2b955658e79d688657171a9ab3cef57`.
관련 스펙: [#106](https://github.com/clip-back/clipback/issues/106), 티켓 [#107](https://github.com/clip-back/clipback/issues/107) → [#108](https://github.com/clip-back/clipback/issues/108) → [#109](https://github.com/clip-back/clipback/issues/109).

## 구현과 적용 범위

- 앱과 서버의 독립 버전 정책, 플랫폼별 후보 태그·불변 소스·후보 기록·재시도와 롤백 규칙을 기존 배포 절차와 양식에 반영했다.
- 서버와 앱 후보의 입력 검증·소스 SHA 연결·읽기 전용 태그 확인·기록 초안 생성을 같은 CLI에서 제공한다.
- 기존 기록을 덮어쓰지 않으며, 확인하지 못한 원격 태그와 스토어 이력을 미확인으로 남긴다. 초안 생성과 실제 산출물·운영 반영은 구분한다.
- 현재 사용 안내는 [배포 절차](../release-process.md), 기록 항목은 [배포 양식](../releases/TEMPLATE.md)을 따른다.

## 실행 환경과 검증

macOS 로컬 Python 3.12 가상환경과 임시 Git 저장소·bare 원격을 사용했다. DB 검사는 이번 작업만을 위한 PostgreSQL 16 컨테이너의 `clipback_release_test`에 수행했고 운영 데이터·자격을 사용하지 않았다.

구현 전 기준 검사:

| 검사 | 결과 |
| --- | --- |
| backend lint | 통과 |
| DB 미지정 일반 pytest | 662 passed, 529 skipped |
| 임시 PostgreSQL `alembic upgrade head`와 `alembic check` | 통과 |
| PostgreSQL 포함 전체 pytest | 1140 passed, 51 skipped |

PostgreSQL 전체 검사의 첫 실행은 도구의 60초 제한으로 중단됐다. 로그를 파일에 남기는 별도 프로세스로 다시 실행해 129.80초에 완료했다. 제품 실패로 판단하지 않았다.

CLI 테스트는 명령 실행 → 종료 코드·JSON 출력·생성된 기록의 경계에서 검증했다. 첫 서버·앱 시나리오가 각각 미구현 상태에서 실패한 뒤 구현해 통과했고, 입력 오류·태그 충돌·원격 실패·기록 보존·사용자 버전 간 빌드 번호 예약·수동 스토어 근거를 순서대로 검증했다. 최종 개별 CLI 검사는 48개(서버 16, 앱 32) 통과했다.

구현 커밋:

- `88541de`: #107 버전 정책과 수동 배포 기록 절차
- `888c1c4`: #108 서버 배포 후보 검사와 기록 생성
- `0d61af9`: #109 앱 플랫폼별 배포 후보 검사와 기록 생성
- `62e108b`: 리뷰에서 제안한 공통 기록 개요 중복 정리

현재 배포 절차와 양식의 상대 링크 10개가 존재함을 확인했다. 앱 사용자의 기능·동작에 영향을 주지 않는 운영 준비 도구이므로 사용자 변경 이력에서는 제외했다.

통합 검사:

| 검사 | 결과 |
| --- | --- |
| `ruff check app scripts alembic tests` | 통과 |
| `python -m compileall -q app scripts alembic tests` | 통과 |
| `alembic upgrade head`, `alembic check` | 통과 |
| PostgreSQL 포함 `pytest -q -rs` | 1188 passed, 51 skipped, 4 warnings (159.27초) |
| 현재 배포 절차·양식 상대 링크 | 10개 대상 존재 확인 |

51개 미실행은 실제 Docker 복구 이미지·S3 대역·별도 `MAINTENANCE_TEST_DATABASE_URL` 등 선택형 환경이 필요한 기존 검사다. 이번 작업은 API·DB·컨테이너를 변경하지 않았으며 새 CLI 48개는 모두 실행했다. 경고는 기존 FastAPI/httpx와 Alembic 설정 경고다.

규약·스펙 두 관점의 리뷰 결과, 명확한 규약 위반과 스펙 누락·잘못된 구현·범위 초과는 없었다. 규약 리뷰의 공통 개요 생성 중복 제안을 반영해 `record_overview()`로 모았으며, 보완 전후 CLI 48개가 각각 통과했다. 보완 diff와 이력 문서를 재검토한 규약 리뷰에도 미해결 사항이 없었다.

최종 코드 `62e108b`에서 lint·컴파일·마이그레이션·스키마 검사와 PostgreSQL 전체 검사를 다시 실행했다. 모두 성공했고 `pytest -q -rs`는 **1188 passed, 51 skipped, 4 warnings (138.91초)**였다. 이력 문서·목차를 포함한 상대 링크 149개가 존재하며 최종 `git diff --check`도 통과했다. 구현용 worktree·병합된 임시 브랜치와 이번 PostgreSQL 컨테이너를 정리했다.

## 미검증과 운영 경계

실제 스토어 업로드 이력·원격 운영 태그·Railway 배포를 이번 검증의 성공 근거로 사용하지 않았다. CLI 테스트의 원격은 로컬 bare 저장소이고 스토어 이력은 합성된 수동 근거다. 새 앱 빌드·iOS Simulator·Android Emulator·실기기·실제 OAuth·운영 공급자 검증은 실행하지 않았다. 앱 화면·동작, API·DB 스키마 변경이 없어 해당 실행은 이번 구현 범위에 포함하지 않는다.

로컬 통합 브랜치에만 구현했으며 푸시·PR·실제 후보 태그 생성·스토어 업로드·운영 배포는 수행하지 않았다. 실제 첫 적용의 버전·빌드 번호는 운영 이력 확인 후 별도로 결정한다.
