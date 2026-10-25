# Railway 백엔드 배포 및 복구

이 문서는 **신규 환경**에서 수행할 설정 절차다. 저장소의 Docker 검증은 Railway 리소스를 생성하거나 실제 배포하지 않는다. API 한 인스턴스와 PostgreSQL 서비스, 각각의 영속 볼륨을 사용한다. API 볼륨 재연결 중 짧은 중단을 허용하며 무중단 배포를 보장하지 않는다.

## 운영 상태의 확인

이 문서는 설정·배포·백업·복구 절차입니다. 당시 배포 보고는 [과거 운영 기록](history/2026-09-21-railway-status.md)에 보존합니다.
실제 운영 환경의 상태는 [배포 기록](release-process.md)과 해당 실행의 근거로 확인합니다.
실제 운영 접속·설정 변경과 검증 결과는 해당 배포·작업 기록에서 확인합니다.

2026-10-22 운영 조회에서는 API가 `b169d93`, DB가 PostgreSQL 18인 것을 확인했습니다.
아래 신규 환경의 PostgreSQL 16 예시를 운영의 실제 버전으로 간주하지 않습니다.
백업 일정 활성화 요청은 현재 Hobby 워크스페이스의 Pro 전용 제한으로 거절됐으며,
실제 진행·미검증 상태는 [이번 작업 기록](history/2026-10-22-production-recovery.md)을 따릅니다.
같은 작업의 운영 정지 중 볼륨 내보내기와 재배포는 실패했고 기존 배포 재시작으로 복구했습니다.
완성된 운영 백업이나 재배포 검증 성공으로 표시하지 않습니다.

## 최초 설정

1. Railway 프로젝트에 PostgreSQL 서비스를 생성한다. 초기 버전은 CI와 동일한 PostgreSQL 16으로 맞추고 DB 데이터 볼륨을 유지한다. API와 같은 프로젝트·환경·리전에 둔다.
2. GitHub 저장소의 `main`을 API 서비스에 연결하고 **Root Directory `/backend`**를 지정한다. 이 경로의 `Dockerfile`을 빌드하며 Build/Start Command의 수동 override는 비워둔다.
3. API에 Volume을 추가하고 **Mount Path `/data`**를 지정한다. 기본 root 실행을 사용한다. replicas는 **1**로 유지한다.
4. 아래 Variables를 설정한 다음 **Pre-deploy Command `alembic upgrade head`**, **Healthcheck Path `/api/v1/health/ready`**, **Healthcheck Timeout `120`초**를 지정한다.
5. API의 Railway 기본 HTTPS 도메인을 생성한다. API는 Railway가 주입하는 `PORT`를 사용하며 DB는 내부 주소로만 연결한다. 외부 DB TCP 공개는 기본 구성에 포함하지 않는다.
6. 배포 로그에서 마이그레이션 성공과 준비 상태 200을 확인하고, 게스트 가입·소셜 로그인·스크린샷 업로드와 재조회로 실제 설정을 검증한다. GitHub 자동 배포의 Wait for CI를 활성화한다.

### Variables

| 변수 | 설정 |
| --- | --- |
| `APP_ENVIRONMENT` | `production` |
| `DATABASE_URL` | PostgreSQL 서비스의 내부 `DATABASE_URL` 참조. 서비스 이름이 `Postgres`라면 `${{Postgres.DATABASE_URL}}` |
| `STORAGE_ROOT` | `/data/screenshots` |
| `SECRET_KEY` | 생성한 충분히 긴 무작위 값. 재배포·복원 때도 유지해야 기존 토큰을 사용할 수 있음 |
| `OPENAI_API_KEY` | 실제 OpenAI 키 |
| `GOOGLE_CLIENT_IDS` | JSON 배열, 예: `["your-google-client-id"]` |
| `KAKAO_REST_API_KEY` | 실제 Kakao REST API 키 |
| `BACKEND_CORS_ORIGINS` | 모바일 전용이면 `[]`; 웹은 `["https://your-web.example"]`처럼 명시 |

나머지 AI/OCR timeout·모델 설정은 `backend/.env.example`의 기본값을 사용한다. Google·Kakao 설정은 현재 production 검증에서 필수다. `SECRET_KEY`와 공급자 비밀값을 Docker build argument, 코드, PR 또는 로그에 넣지 않는다. 실제 `.env`는 이미지에 포함하지 않는다.

`postgres://`와 `postgresql://` URL은 접두사만 `postgresql+asyncpg://`로 변환한다. 비밀번호의 `%25`, `%40` 등 percent encoding과 쿼리 문자열은 그대로 유지된다. 운영에서 기본 개발 DB 주소와 상대 저장 경로는 거부한다.

## 실행 및 상태 확인

이미지의 작업 경로는 `/app`이다. 시작 스크립트는 선택한 신규 저장소를 확인한 뒤 `uvicorn`을 exec한다.
로컬 저장은 디렉터리 생성·임시 파일 쓰기·삭제를, Bucket 저장은 읽기 전용 객체 목록 조회를 확인한다. 기본 포트는 8000이며 Railway의 `PORT`가 우선한다. worker는 1개이고 reload는 사용하지 않는다.

DB migration은 pre-deploy에서만 실행한다. 이 단계에는 볼륨이 없으므로 이미지 파일을 생성하거나 확인하지 않는다. 실패하면 해당 배포를 중단한다. 현재 최초 배포는 빈 DB 기준이며, 향후 기존 데이터를 바꾸는 migration은 별도 배포 절차에서 이전 앱과의 호환성·쓰기 중단 여부를 검토한다.

- `/api/v1/health`: 기존 liveness 응답 `200 {"status":"ok"}` 유지.
- `/api/v1/health/ready`: DB `SELECT 1`과 선택한 저장소 확인 성공 시 200, 실패·3초 timeout 시 `503 {"status":"unavailable"}`. Bucket 선택 시 S3 공급자에 읽기 전용 목록 조회를 수행한다. AI/OCR·소셜 인증 공급자는 호출하지 않는다.
- Railway healthcheck는 배포 준비 상태 확인이다. 배포 후 계속 호출하는 장애 감시 도구가 아니다. stdout/stderr 및 Railway 리소스 지표로 로그·디스크 사용량을 확인한다.

## Bucket 원본 보관

이 코드는 원본 저장소 전환을 지원하지만 설정 변경이나 실제 Railway 검증을 수행하지 않는다.
신규 Bucket은 비공개로 만들고, Credentials의 값을 서버 변수에만 연결한다.
[Railway 공식 연결 안내](https://docs.railway.com/storage-buckets#connecting-to-your-bucket)를 기준으로 설정한다.

| 변수 | 설정 |
| --- | --- |
| `STORAGE_BACKEND` | 신규 원본을 Bucket에 저장할 때 `s3`; 기본값 `local` |
| `S3_ENDPOINT_URL` | Credentials의 base endpoint. 운영은 HTTPS 필수 |
| `S3_BUCKET` | Credentials의 실제 `BUCKET` 값. 화면 표시 이름과 구분 |
| `S3_REGION` | Credentials의 region. 기본 `auto` |
| `S3_ADDRESSING_STYLE` | Credentials의 URL style. 신규 기본 `virtual`, 구형 Bucket이나 격리 S3 환경은 필요하면 `path` |
| `S3_ACCESS_KEY_ID` · `S3_SECRET_ACCESS_KEY` | 해당 Bucket 전용 서버 비밀값 |

먼저 추가형 DB migration과 로컬·Bucket을 함께 읽는 백엔드를 배포한다. 기존 자산은 `local`로 남고,
신규 자산은 저장 위치·원본 크기·SHA-256을 기록한다. `STORAGE_ROOT=/data/screenshots`와 원래 볼륨은
기존 로컬 자산이 남아 있는 동안 유지한다. 새 저장 설정만 바꿔도 기존 파일이 이관되지는 않는다.

SDK는 event loop 밖에서 실행하며 connect/read timeout과 재시도 상한을 둔다.
준비 상태의 읽기 전용 목록 조회는 원본 저장·다운로드·삭제 성공을 증명하지 않으므로,
운영 전환 전 별도 테스트 계정의 합성 이미지로 업로드·동일 바이트 재조회·삭제를 확인한다.
실제 Bucket 검증, 기존 파일 이관, Bucket을 포함한 백업·복원 확인 후에 원래 볼륨 정리를 검토한다.
아래 로컬 볼륨 백업 절차만으로 Bucket 원본이 백업된 것으로 판단하지 않는다.
## 카테고리 제출 복구 배포 순서

신규 앱을 배포하기 전에 서버의 카테고리 제출 API와 migration `202610250015`를 먼저 적용합니다.
이 migration은 `category_submissions`를 추가하며 기존 키 없는 생성·수정 호출도 유지합니다.
같은 계정·같은 제출 키의 성공/거절 재사용과 계정 격리를 배포 환경에서 확인한 뒤 앱을 배포합니다.
처리 기록은 카테고리 삭제 뒤에도 유지하므로 백업·복원에 DB 기록을 함께 포함합니다.
현재 저장소의 로컬 테스트와 빌드는 운영 적용을 뜻하지 않습니다. 실제 배포 SHA·migration·검증은
[배포 기록](release-process.md)에 별도로 남깁니다. 상세 계약은 [API 안내](backend/api-contracts.md#카테고리-생성수정-제출-복구)를 따릅니다.

## 데이터 영속성 및 백업

현재 기존 Volume 원본의 첫 실제 백업·격리 복원은 [운영 실행 체크리스트](backend/image-operator-first-run.md)를 따른다.
새 비공개 원본 읽기·영속 점검·Mac 복원 제어를 검증하고 명시적으로 재개하는 절차다.
아래 이전 Volume 내보내기/중단 검증의 시간 제한과 방법을 새 점검 실행에 그대로 적용하지 않는다.
과거 실행 결과는 해당 작업 이력의 증거로 보존한다.

Bucket 원본을 사용하는 새 이미지 보관은 [전용 운영 작업의 일일 백업·7일 보존·삭제 반영 복원](backend/backup-recovery.md#일일-백업과-시간별-보존-작업)을 기준으로 한다.
별도 operator 이미지에 source DB와 같은 pg_dump 주 버전 및 daily/시간별 maintain 일정을
설정하고, 원본 API에는 백업 자격을 주지 않는다. 아래 Railway 볼륨 자체의 백업과 구분하며,
코드 구현만으로 실제 일정·권한·복구 전환이 검증되거나 설정된 것은 아니다.

API 서비스의 볼륨과 DB 서비스의 볼륨은 별개다. 재배포·컨테이너 재생성 시 두 볼륨을 유지한다. 볼륨이나 서비스를 삭제하는 작업은 일반적인 재배포 절차가 아니다.

실제 배포 단계에서 **두 볼륨의 Backups 탭에 일일 백업을 활성화**한다. 저장소 변경만으로 이 설정이 자동 활성화되지는 않는다. 각 자동 백업은 시점이 다를 수 있으므로 같은 시점의 DB·이미지 세트로 간주하지 않는다.

현재 계정/플랜에서 지원되는지 먼저 확인한다. Pro 제한 등으로 활성화가 거절되면 미완료로 기록하고
자동 업그레이드·다른 스케줄로 우회하지 않는다. 수동 DB dump·이미지 사본은 별도 복구 수단이며
Railway 기본 백업의 활성화·복원 성공과 구분한다.

### 이번 검증의 운영 중단 기준

- 공개 도메인에 대응하는 프로젝트·환경·API·DB·볼륨과 실제 배포 ID·SHA를 고정한다.
- [Railway 공식 상태](https://status.railway.com/)와 계정의 배포 제한을 중단 전에 확인한다.
  플랫폼 장애·배포 중지 중에는 점검 중단을 시작하지 않는다. `canRedeploy=true`만으로 재개를 보장하지 않는다.
- 같은 배포 이미지로 재개할 경로와 API 중지 중의 볼륨 읽기 경로를 먼저 확보한다.
  기존 Railway CLI에 `volume files`가 없으면 작업 전용 CLI로 확인하며 전역 설치는 바꾸지 않는다.
- API와 lifespan 요약 worker를 함께 정상 종료하고 다른 앱 쓰기가 없음을 확인한다. DB는 계속 실행한다.
- 중단은 최대 10분이며 8분부터는 백업을 취소하고 기존 배포 재개에 집중한다.
  재개 경로나 시간 예산이 확인되지 않으면 중단하지 않는다.
- 실행 중인 API에서의 `volume files` 성공을 정지 중 읽기 검증으로 간주하지 않는다.
  이번 CLI5.71.0의 운영 정지 중 내보내기는 실패했으므로 같은 방법의 운영 재시도는 보류한다.
- 기존 배포 재개 실패 시 새 코드 배포를 시도하지 않는다. 기존 배포의 공식 Restart 경로로
  복구를 우선하고, 원래 배포/이미지·readiness와 실제 중단 시간을 확인한다. 실패·제한 초과는 따로 기록한다.
- 최신 커밋 배포·새 migration·운영 Restore·복구 DB로의 전환은 이 검증에 포함하지 않는다.

### 일관된 수동 백업

1. API를 중지하여 쓰기 요청을 차단한다. DB는 실행 상태로 유지한다.
2. DB 컨테이너 또는 내부 DB에 접근 가능한 환경에서 `pg_dump -Fc`로 DB dump를 만든다. 사용한 PostgreSQL 버전과 migration revision을 기록한다.
3. 같은 쓰기 중단 기간에 이미지 볼륨 `/data` 전체를 tar archive로 만든다. 중지된 API를 다시 시작하지 않고 볼륨 파일을 읽을 수 있는 Railway 볼륨 도구를 사용한다.
4. 두 파일을 동일한 백업 ID·시간·앱 커밋으로 묶고, 크기·해시와 `pg_restore --list`/`tar -tf` 결과를 확인한다. DB URL·SECRET_KEY는 manifest에 넣지 않고 별도 비밀 저장소에서 보존한다.
5. 백업을 원본 볼륨과 별개인 접근 제한된 위치에 보관한 뒤 API를 재개한다. dump에는 사용자 데이터와 인증 세션이 포함되므로 공개 저장소에 올리지 않는다.

별도 로컬 Docker에서 원본을 변경하지 않고 검사하는 도구·manifest·자격 파일·검사 범위는
[격리 복원 안내](backend/backup-recovery.md)를 따른다. 백업은 저장소 밖의 비공개 폴더에 보관하고,
비밀값은 manifest·로그와 분리한다. 보관 기간은 이미지 정책을 따르며 복원 검사용 임시 다운로드는
종료 후 제거한다. 오래된 사본을 무기한 유지하지 않는다.

### 복원과 롤백

1. 원본에 덮어쓰지 말고 별도의 빈 DB·이미지 볼륨을 준비한다.
2. 같은 백업 세트의 DB를 `pg_restore --exit-on-error`로 복원하고 archive를 이미지 볼륨의 `/data` 기준으로 푼다.
3. 원래 API·worker·모든 쓰기를 차단한 채 live 독립 삭제 기록의 최신성을 확인하고 삭제 전 DB/원본 기준을 비교한 뒤 삭제 intent를 적용한다. 숫자 ID만으로 대상을 정하지 않는다. [삭제 반영 격리 복원](backend/backup-recovery.md#최신-삭제-기록을-반영한-격리-복원)을 따른다. 기록을 검증할 수 없으면 트래픽을 열지 않는다.
4. 그 뒤 호환 앱 커밋·같은 SECRET_KEY로 시작하고, 기존 토큰의 콘텐츠·원본 조회와 삭제된 콘텐츠/이미지의 404, 준비 상태를 검증한다. 쓰기 차단을 전환까지 유지한다. 재개했다면 최신 삭제를 다시 반영한다.
5. 연결을 검증된 복원 대상으로 전환한다. 검증 전 원본을 제거하지 않는다. 이 저장소의 격리 검사 도구는 운영 전환을 직접 수행하지 않는다.

코드 롤백은 이전 이미지를 실행하는 것이며 DB·이미지 복원과 다르다. 개인화 migration `202609070010`은 downgrade를 거부한다. 필요하면 배포 전 DB·이미지 세트와 호환되는 앱을 함께 복원한다. 서로 다른 시점의 DB·이미지를 임의 조합하지 않는다.

## 로컬·CI 검증

저장소 루트에서 Docker가 실행 중인 상태로:

```sh
docker build -t clipback-backend:check backend
docker pull postgres:16
python3 backend/scripts/check_deployment.py --image clipback-backend:check
```

이 스크립트는 UUID 이름의 내부 Docker 네트워크와 임시 볼륨만 만든다. 새 DB 마이그레이션과 `alembic check` 후 실제 API 가입·수동 분류 콘텐츠 저장을 실행하고, 대응 이미지 자산과 파일을 준비한다. OCR·메타데이터를 호출하지 않으며 런타임 네트워크의 외부 연결도 차단한다.

API·DB 컨테이너 재생성 후 같은 토큰·콘텐츠 ID·이미지 바이트를 확인한다. 이어 API를 중지하고 DB dump와 이미지 archive를 새 볼륨에 복원해 같은 검증을 반복한다. 종료 시 스크립트가 만든 컨테이너·네트워크·볼륨과 임시 백업만 정리한다. 기존 개발 DB와 로컬 저장 파일은 사용하지 않는다.

CI는 이 검증을 별도 `deployment` job에서 필수 실행한다. 로컬 Docker 검증 성공은 실제 Railway의 변수·볼륨·도메인·백업 설정 완료를 의미하지 않는다.

참고: [Dockerfile](https://docs.railway.com/builds/dockerfiles), [pre-deploy](https://docs.railway.com/deployments/pre-deploy-command), [volumes](https://docs.railway.com/volumes), [healthchecks](https://docs.railway.com/deployments/healthchecks), [backups](https://docs.railway.com/volumes/backups).

## YouTube 비동기 요약 배포

신규 summary_jobs 마이그레이션을 pre-deploy에서 적용한다. 기본 `YOUTUBE_SUMMARY_ENABLED=true`이며 Gemini·YouTube API 키를 등록한 뒤 배포한다. 키 없이 배포하려면 명시적으로 `false`를 설정한다.  단일 replica/worker를 유지한다. 키 등록, 작업 복구, 실제 영상 검증 및 활성화 절차는 [YouTube 운영 문서](youtube-summary.md)를 따른다. 기존 Instagram·OCR 설정은 변경하지 않는다.

<details>
<summary>이전 문서 링크와 제목 호환</summary>

- <a id="현재-진행-상태-2026-09-21"></a>[현재 진행 상태 (2026-09-21)](history/2026-09-21-railway-status.md#b-61d9aa56364d48bc)

</details>
