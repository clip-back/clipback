# 운영 데이터 영속성과 백업·복구 검증

- 최초 기록일: 2026-10-22 KST
- 기준: `main`의 `7d63a9ebb82f1ad04f6e774963a62ad6026ecda9`
- 브랜치: `chore/backend-backup-recovery-verification`
- 현재 안내: [Railway 운영](../railway-deployment.md) · [격리 복원 도구](../backend/backup-recovery.md)

## 승인 범위와 완료 판정

사용자는 운영 중단 최대 10분, 복구 위치는 이 Mac의 격리 Docker를 선택했다.
기존 실기기의 링크·사진 저장과 앱 재실행 복원은 사용자 확인 완료이며 이번 실행 증거로
다시 집계하지 않았다. 제품 코드·스키마·정책·화면·인증 동작은 변경하지 않았다.

**운영 백업·복구 전체 완료가 아니다.** 기본 백업 설정은 Pro 제한으로 거절됐다.
운영 중단·기존 배포 재시작·DB dump 확보는 수행했지만, 재배포와 일관된 이미지 사본 확보는
실패했다. 같은 세트의 운영 백업 복원은 수행하지 못했다. 각 상태를 별도로 구분한다.
운영의 `Restore`, DB/볼륨 교체·삭제, 새 코드 배포·migration은 수행하지 않았다.

## 운영 조회 결과

사용자가 지정한 프로젝트 URL을 기준으로 CLI 인증을 확인했다. 전역 CLI 4.5.6은 유지하고,
임시 작업 폴더의 Railway CLI 5.71.0을 사용했다. 저장소 디렉터리는 Railway에 연결하지 않았다.

| 항목 | 실제 조회 결과 |
| --- | --- |
| 프로젝트 | `clip-back` / `bab799fe-f392-4683-80ee-c4ed1b0186dc` |
| 환경 | `production` / `6e768551-bb2e-4408-9c50-0eb5c16373d3` |
| API | `clipback` / `77501417-3c76-4bc9-842f-a64a4086e63c` |
| DB | `Postgres` / `46194e98-82da-4874-8e7a-4425aa5f5500` |
| 공개 도메인 | `clipback-production.up.railway.app` |
| 실행 배포 | `a06d8a88-e165-44d3-bac9-eae4030187cf`, SUCCESS |
| 운영 소스 | `b169d9323820685eab9351880f846545d441d73a` |
| API 이미지 digest | `sha256:0c18e62e8a550e307e08ebbfb0a71116b52be848c7e585f45a152cfe5caea272` |
| 구성 | `/backend`, Dockerfile, replicas 1, readiness `/api/v1/health/ready` |
| 런타임 경로 | `STORAGE_ROOT=/data/screenshots`, 볼륨 마운트 `/data` |
| 요약 worker | 활성. API lifespan과 함께 실행됨 |
| DB 버전 | 내부 psql 읽기로 PostgreSQL `18.6` 확인 |
| migration | 내부 psql 읽기로 `202610120014` 확인. 변경하지 않음 |
| API 볼륨 | `fd67fe3e-93d8-47c8-9bd6-e1609138a802`, 인스턴스 `4f62077c-b184-460b-bd38-218a1daae038` |
| DB 볼륨 | `4ca7b92f-01f4-424e-940b-3d6f7c921a23`, 인스턴스 `ae21bacd-6ca9-4a00-9acc-e231cbdf8c61` |

프로젝트 status의 최초 조회에서는 API 약96MB·DB 약175MB, 각 볼륨 5000MB로 나왔다.
일시적 지표이며 백업 파일 크기로 사용하지 않는다. DB 메이저 버전은 신규 환경 문서의16을
추정해 적용하지 않고 실제18을 확인했다.

### 백업 기능 제한

공식 GraphQL의 `volumeInstanceBackupScheduleList`, `volumeInstanceBackupList`를 읽었으며
두 볼륨 모두 빈 목록이었다. 승인 범위의 `DAILY` 일정 설정을 각 볼륨에 요청했지만 모두 다음
응답으로 거절됐다.

> Manual backups and backup schedules are only available for Pro workspaces

설정 성공·첫 백업 성공으로 기록하지 않았다. 플랜 업그레이드, PITR·새 bucket·새 유료 서비스 생성,
운영 볼륨 Restore 등은 하지 않았다. 이 제한 때문에 예약 백업 활성화는 미완료다.

### 접근과 자동 승인 검토

- 초기 CLI는 미연결·Unauthorized였고 사용자가 프로젝트를 제공한 뒤 인증 접근이 확인됐다.
- 볼륨/SSH 읽기에는 등록 키가 없어 작업 전용 키와 agent를 준비했다. 기존 SSH 파일·agent는 바꾸지 않았다.
- 임시 공개키 등록이 자동 승인 검토에서 계정 범위의 인증 설정 변경이라는 이유로 거절됐다.
  사용자가 **현재 Railway 개인 계정에 이번 작업 동안 등록 후 삭제**를 명시적으로 승인한 뒤 등록했다.
- 임시 키로 API의 경로·SHA·worker 설정과 DB 버전·revision만 읽었다. 볼륨 루트 목록 읽기까지 확인했다.
  목록 내용이나 개인 파일 경로는 로그에 출력하지 않았다.
- 운영 변수/자격·DB·이미지 내보내기와 시험 게스트/이미지 준비를 합친 사전 점검 명령은 자동 승인 검토가
  민감 자료와 운영 쓰기를 포함한다는 이유로 거절했다. **명령은 실행되지 않았다.**
  자료 내보내기·별도0600 자격 보관·전용 시험 데이터 생성에 대한 명시적 확인을 요청했다.
  SSH 키 승인만으로 이 거절을 우회하지 않았다.
- 이후 사용자가 **운영 자료 내보내기·시험 데이터 생성**도 명시적으로 허용했다.
  앞서 정리했던 전용 SSH 접근과 Docker를 다시 준비해 아래 운영 검증을 진행했다.

## 실제 운영 중단·복구 결과

### 사전 점검

- API가 실행 중인 상태의 볼륨 사본을 비공개 임시 위치로 내려받았다. 실제 파일10,839,685바이트,
  전송13.564초였다. 이 사본은 **일관된 백업이 아닌 전송 확인용**이며 실패한 DB dump와 조합하지 않았다.
- 별도 SSH DB 터널로 PostgreSQL18·revision을 읽었다. 비밀값은 로그에 출력하지 않았다.
- 운영 API로 전용 게스트와 고정 PNG 시험 콘텐츠1개를 생성했다. ID·자격은 비공개 파일에만 보관했다.
- 기존 배포가 SUCCESS·`canRedeploy=true`인 것과 같은 이미지를 재사용하는 공식 재개 경로를 확인했다.
  그러나 공식 플랫폼 장애/배포 제한을 중단 전에 확인하지 못했고, 실행 중 읽기 성공을
  정지 중에도 독립적으로 읽을 수 있다는 충분한 근거로 취급한 사전 점검의 오류가 있었다.

### 중단과 실패

- `deploymentStop`으로 고정한 API 배포와 worker를 중지한 뒤 다른 DB 클라이언트가 없는지 확인했다.
- 같은 중단 중 PostgreSQL18의 `pg_dump -Fc --no-owner --no-acl` 결과79,697바이트를 확보했다.
- **API가 중지된 상태의 볼륨 다운로드는 실패했다.** 이미지 archive와 원본 비교 manifest를 완성하지 못했다.
  실행 중 목록/다운로드 성공이 정지 중 내보내기 성공을 보장하지 않는다. 같은 방법으로 재시도하지 않았다.
- 즉시 원래 배포 이미지의 `deploymentRedeploy(..., usePreviousImageTag:true)`를 요청했으나
  `Deploys have been paused due to an upstream issue` 응답으로 거절됐다.
- 그 뒤 [Railway 공식 상태](https://status.railway.com/)에서 플랫폼 장애와 Hobby 배포 재개 제한을 확인했다.
  이 공지는 이번 검증 당시의 상태이며 추후의 장애 상태로 간주하지 않는다.

### 복구와 보존 확인

- 새 배포를 생성하지 않는 `deploymentRestart`1회가 수락되어 원래 배포를 재시작했다.
- 실제 readiness200, 기존 배포 ID·SHA·이미지 digest 유지, `deploymentStopped=false`·SUCCESS를 확인했다.
- 준비 시작의 UTC 초 단위 시각 `2026-10-22T10:12:36Z`와 readiness 관측 `10:14:59.524Z` 사이의
  **보수적 중단 구간 상한은144초**다. 준비 시간도 포함하며 실제 최초502부터200까지의 정확한
  연속 측정치는 아니다.10분 제한 이내 복구됐지만 재배포 검증 성공으로 표시하지 않는다.
- 재개 후 시험 계정의 인증 콘텐츠/이미지 GET을 확인했다. 같은 콘텐츠·자산 ID와 제출한 PNG 바이트가
  유지됐다. 저장 시각·카테고리 등의 완성된 사전 manifest 대조는 미검증으로 남긴다.
- 확보한 DB 파일은 로컬 PostgreSQL18의 `pg_restore --list`를 통과했다. **DB 목록 검사만** 통과했으며
  운영 DB의 실제 복원이나 DB·이미지 동시 복원 성공이 아니다.
- `production-20261022T101236Z` 폴더에 DB 단독 파일과 `INCOMPLETE.json`을0700/0600으로 보관했다.
  완성된 `manifest.json`·`images.tar`는 없고 복원 도구의 성공 입력으로 사용하지 않았다.
  자격은 별도 `Clipback/backup-secrets/`의0600 파일로 분리했다. 비밀값·개인 데이터는 Git에 넣지 않았다.
- 최초 실패 보고서는 유지하고, 수동 재시작 복구 결과를 별도 보고서에 기록했다.
  `/private/tmp/clipback-backup-recovery-20261022/production-capture-result.json`과
  `production-recovery-result.json`은 다른 단계를 기록한다.

## 구현과 로컬 검증

`check_backup_restore.py`와 비공개 기준 자료를 만드는 `recovery_probe.py`를 추가했다.
기존 `check_deployment.py`·제품 API·Dockerfile·CI 정의는 유지한다.

- 운영 URL·DB 주소를 입력받지 않고 고정 입력 파일과 자격 파일, revision 라벨의 로컬 이미지만 사용한다.
- archive 경로/종류·중복·해시·참조 이미지, private 자격·로컬 Docker·동일 주 버전을 확인한다.
- 새 자원에만 복원하고 인증 콘텐츠/이미지 GET과 전체 건수·revision·분류 관계·이미지 해시를 대조한다.
- 외부망과 공급자·요약 worker를 차단한다. 실패/성공 모두 소유 라벨을 확인해 이번 자원만 정리한다.
- 원본 백업 불변, 미참조 파일 보존, 오류 출력의 비밀값 제거와 cleanup 실패 시 전체 실패를 검사한다.

| 실행 | 실제 결과 |
| --- | --- |
| 새 단위 검사 | 37 passed |
| 실제 Docker 합성 복원 | PostgreSQL16·18 각각6건, 합계12 passed / 80.30초 |
| 전체 백엔드 pytest | 새 전용 PostgreSQL16에서1023 passed·12 skipped / 75.36초 |
| 전체의12 skip | opt-in Docker 사례. 별도 위 명령으로12개를 모두 실행했으며 skip을 성공으로 집계하지 않음 |
| DB 준비·schema 비교 | 임시 테스트 DB의 `alembic upgrade head`, `alembic check` 통과 |
| Ruff | `ruff check app alembic scripts tests` 통과 |
| 컴파일 | `python -m compileall -q app alembic scripts tests` 통과 |
| 기존 Docker 검사 | 컨테이너 재생성 뒤 동일 인증·콘텐츠·이미지 확인, 새 볼륨의 paired restore 모두 통과 |
| 운영 백업 입력 | 사용하지 않음. 위 데이터는 모두 합성 자료 |
| 원격 CI | 푸시하지 않았으므로 이번 변경의 원격 실행 없음 |
| Flutter·기기·Figma | 화면/앱 변경이 없어 이번 범위에서 실행하지 않음 |

pytest는 현재 설치된 Starlette/httpx 조합의 기존 deprecation warning1건을 출력했다.
실행 초기 PostgreSQL16 전용 검사6건과1022건 전체 검사 뒤, 운영18 지원·최종 입력 검사를 반영해
위 최종12건/1023건을 재실행했다. 최초 이미지 라벨의 전체 SHA 오기를 실제 `git rev-parse HEAD`로
바로잡고 일치 검사 이후의 이미지로 검증했다. 운영 데이터 오류나 운영 배포 변경은 아니다.

실행 환경은 Python3.12, Docker29.9.2이다. Docker는 이번 작업에서 실행했다.
작업 폴더는 `/private/tmp/clipback-backup-recovery-20261022/`이며 제품 비밀값을 담은 자료는
커밋에 포함하지 않았다. 소스 재빌드 이미지와 실제 Railway 이미지 digest의 차이를 구분했다.

## 남은 운영 검증

- 플랫폼 장애·배포 제한이 없고, **서비스 정지 중의 독립 볼륨 읽기**가 지원되는 경로를 확정한 뒤에만
  같은 중단 구간의 논리 DB dump·이미지 사본과 원본 기준을 다시 확보할 수 있다.
- 재개 경로·내보내기 예상 시간·다른 쓰기 부재가 확보되지 않으면 중단하지 않는다.
- 운영 재개10분 제한과 원래 배포 SHA·시험 콘텐츠/이미지 유지 여부를 실제로 측정한다.
- `origin=production` 세트의 로컬 복원·인증·전체 대조를 수행하고 검증된 세트를 비공개 위치에 보존한다.
- Pro 백업 기능은 별도 플랜 결정이 필요하다. 수동 dump 성공으로 자동 백업 완료를 대신하지 않는다.

재배포 요청이 실패하고 기존 배포 재시작으로 복구했으므로 신규 서버 배포 완료 기록을 만들지 않았다.
미검증을 성공이나 운영 복구 전체 완료로 표시하지 않는다. 푸시·PR은 하지 않는다.

## 정리와 전달

추가 승인 전 중간 정리 시점에는 기존 운영 배포가 SUCCESS·`deploymentStopped=false`였고
아직 중단하지 않은 상태였다. 추가 승인 후에는 위와 같이 실제 중단·실패·재시작을 수행했다.
현재 결과를 중간 정리 시점의 상태로 덮어쓰지 않는다. 두 기본 백업 일정은 여전히 미설정이다.

중간 정리에서 첫 임시 공개키·agent·파일·이미지 태그를 정리한 뒤 추가 승인으로 다시 준비했다.
작업 종료 시 재등록한 임시 공개키를 해제하고 키 목록에서 부재를 확인했다. 소유 agent·키 파일·
DB 터널·임시 원본 파일 사본·중복 자격 파일도 정리했다. 시험 데이터 식별 정보는 미완성 세트의
별도0600 파일로 보존했으며, 운영 시험 게스트·콘텐츠는 임의로 삭제하지 않았다.
검사 소유 라벨의 컨테이너·네트워크·볼륨이 모두 없음을 확인하고 이번에 만든 이미지 태그만 삭제했다.
실행 중인 다른 컨테이너가 없어서 이번에 시작한 Docker Desktop도 종료했다.
DB 단독 미완성 세트와 별도 자격 파일은 비공개 위치에 보존했다. 기존 Docker 이미지·볼륨은 유지했다.
최종 공개 readiness를 OS curl의 TLS 검증을 유지한 상태로 다시 확인해200을 받았다.
일반 Python의 CA 저장소 오류 때문에 한 차례 공개 readiness 확인이 실패했으며,
TLS 검증을 끄지 않고 OS curl로200을 확인했다. 운영 API의 인증서 장애로 보고하지 않는다.

현재 앱 동작이나 제품 설정을 바꾸지 않는 검사 도구·문서 작업이므로 CHANGELOG에서는 제외한다.
문서 링크·최종 diff·공백과 민감 정보 패턴을 검사하고 작업 파일만 커밋한다.
`AGENTS.md`·기존 사용자 변경·개인 설정·검증 생성물은 커밋에 포함하지 않는다.
