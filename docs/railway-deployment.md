# Railway 백엔드 배포 및 복구

이 문서는 **신규 환경**에서 수행할 설정 절차다. 저장소의 Docker 검증은 Railway 리소스를 생성하거나 실제 배포하지 않는다. API 한 인스턴스와 PostgreSQL 서비스, 각각의 영속 볼륨을 사용한다. API 볼륨 재연결 중 짧은 중단을 허용하며 무중단 배포를 보장하지 않는다.

## 현재 진행 상태 (2026-09-21)

사용자는 Railway 배포 완료를 알렸다. 아래 절차는 신규 설치와 설정 점검을 위한 안내이며,
문서 갱신 과정에서 실제 서비스에 접속하거나 운영 설정을 변경하지 않았다.
공개 URL 연결, 실제 소셜 로그인, 이미지 영속성, 일일 백업 활성화 여부는 확인이 남아 있다.

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

이미지의 작업 경로는 `/app`이다. 시작 스크립트는 저장 디렉터리를 생성하고 임시 파일 쓰기·삭제가 성공해야 `uvicorn`을 exec한다. 기본 포트는 8000이며 Railway의 `PORT`가 우선한다. worker는 1개이고 reload는 사용하지 않는다.

DB migration은 pre-deploy에서만 실행한다. 이 단계에는 볼륨이 없으므로 이미지 파일을 생성하거나 확인하지 않는다. 실패하면 해당 배포를 중단한다. 현재 최초 배포는 빈 DB 기준이며, 향후 기존 데이터를 바꾸는 migration은 별도 배포 절차에서 이전 앱과의 호환성·쓰기 중단 여부를 검토한다.

- `/api/v1/health`: 기존 liveness 응답 `200 {"status":"ok"}` 유지.
- `/api/v1/health/ready`: DB `SELECT 1`과 저장소 파일 쓰기·삭제 성공 시 200, 실패·3초 timeout 시 `503 {"status":"unavailable"}`. 인증과 외부 공급자 호출은 없다.
- Railway healthcheck는 배포 준비 상태 확인이다. 배포 후 계속 호출하는 장애 감시 도구가 아니다. stdout/stderr 및 Railway 리소스 지표로 로그·디스크 사용량을 확인한다.

## 데이터 영속성 및 백업

API 서비스의 볼륨과 DB 서비스의 볼륨은 별개다. 재배포·컨테이너 재생성 시 두 볼륨을 유지한다. 볼륨이나 서비스를 삭제하는 작업은 일반적인 재배포 절차가 아니다.

실제 배포 단계에서 **두 볼륨의 Backups 탭에 일일 백업을 활성화**한다. 저장소 변경만으로 이 설정이 자동 활성화되지는 않는다. 각 자동 백업은 시점이 다를 수 있으므로 같은 시점의 DB·이미지 세트로 간주하지 않는다.

### 일관된 수동 백업

1. API를 중지하여 쓰기 요청을 차단한다. DB는 실행 상태로 유지한다.
2. DB 컨테이너 또는 내부 DB에 접근 가능한 환경에서 `pg_dump -Fc`로 DB dump를 만든다. 사용한 PostgreSQL 버전과 migration revision을 기록한다.
3. 같은 쓰기 중단 기간에 이미지 볼륨 `/data` 전체를 tar archive로 만든다. 중지된 API를 다시 시작하지 않고 볼륨 파일을 읽을 수 있는 Railway 볼륨 도구를 사용한다.
4. 두 파일을 동일한 백업 ID·시간·앱 커밋으로 묶고, 크기·해시와 `pg_restore --list`/`tar -tf` 결과를 확인한다. DB URL·SECRET_KEY는 manifest에 넣지 않고 별도 비밀 저장소에서 보존한다.
5. 백업을 원본 볼륨과 별개인 접근 제한된 위치에 보관한 뒤 API를 재개한다. dump에는 사용자 데이터와 인증 세션이 포함되므로 공개 저장소에 올리지 않는다.

### 복원과 롤백

1. 원본에 덮어쓰지 말고 별도의 빈 DB·이미지 볼륨을 준비한다.
2. 같은 백업 세트의 DB를 `pg_restore --exit-on-error`로 복원하고 archive를 이미지 볼륨의 `/data` 기준으로 푼다.
3. 백업과 호환되는 앱 커밋 및 같은 SECRET_KEY로 시작한다. 기존 토큰을 사용한 콘텐츠 조회, 이미지 바이트, 준비 상태를 검증한다.
4. 원래 API의 쓰기가 차단된 상태에서 연결을 검증된 복원 대상으로 전환한다. 검증 전 원본을 제거하지 않는다.

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
