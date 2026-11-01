# 백엔드 CI의 백업·복구 Docker 검사를 관련 변경과 야간 실행으로 한정

최초 기록일: 2026-11-01 KST. 기준은 [이슈 #144](https://github.com/clip-back/clipback/issues/144) 본문과
"결정" 댓글이다. 브랜치 `ci/backend-validation-paths`(main `551bf32` 기준)에서 작업했다.

## 결정 (사용자 확인 2026-11-01)

- main push에서도 `operator-recovery`·`deployment`를 경로 기준으로 건너뛴다. 누락은 야간 실행에서 잡는다.
- 야간 전체 실행은 매일 04:00 KST(`0 19 * * *` UTC)에 한다. 수동 실행도 전체를 실행한다.
- Python 3.11 테스트는 유지한다. `lint`·`test`·`migration`은 계속 항상 실행한다.
- 조사 결과 Docker 테스트가 쓰는 `app` 모듈이 사실상 전체여서(아래 "import 추적"), 다음 조합을 택했다.
  - `operator-recovery`: 이슈 후보 경로, 운영 스크립트가 import하는 모듈, 컨테이너 기동 경로, workflow 파일이
    바뀔 때만 실행한다. 일반 API·요약 worker 변경이 컨테이너 안에서 일으키는 회귀는 야간 실행에서 발견하는 위험을 수용한다.
  - `deployment`: `backend/` 아래 파일이나 workflow 파일이 바뀌면 항상 실행한다. 컨테이너 기동·lifespan 문제를 PR에서 잡는다.
  - 목록은 workflow에 손으로 적는다.

## 변경 범위

- `.github/workflows/backend-validation.yml`
  - `schedule`(`0 19 * * *`) 트리거 추가.
  - `changes` job 추가: `dorny/paths-filter`를 v4.0.3 커밋 `ceb8a2b8f2d89434be7ff52d3de7ec3738c5cc9d`로 고정했다.
    PR은 GitHub API로 변경 파일을 받으므로 job 권한에 `pull-requests: read`를 더했고, main push는 git으로
    직전 커밋과 비교하므로 push에서만 checkout한다. 예약·수동 실행에서는 판정 단계를 건너뛴다.
  - `deployment`·`operator-recovery`: `needs: changes`와 `if`(예약·수동 실행이거나 해당 판정이 `true`) 추가.
  - 기존 concurrency·timeout·이미지 버전은 바꾸지 않았다.
- `git diff` 스크립트 대신 paths-filter를 쓴 이유: PR·push의 비교 기준(PR base, push 직전 커밋)과 얕은 checkout의
  추가 fetch를 직접 다루지 않아도 되고, 규칙을 glob 목록으로 읽을 수 있다. 외부 action 의존은 커밋 SHA 고정으로 제한했다.
- [백엔드 테스트 안내](../backend/testing.md#원본-운영자점검복원-통합-검사)에 job별 실행 조건을 추가했다.
- CHANGELOG: 사용자에게 보이는 동작 변화가 없어 추가하지 않았다.

## import 추적

Docker 테스트가 실행하는 API 이미지는 `scripts/start.sh` → `scripts/serve.py` → `uvicorn app.main:app`으로 전체 API와
요약 worker를 띄우고, 테스트는 `/api/v1/auth/guest`·`/contents`·`/uploads/screenshots`·`/health/ready`를 호출한다.
그래서 이 경로까지 따라가면 범위가 `app` 전체가 된다.

2026-11-01 이 worktree의 `backend/`에서 AST로 `app.*`·`scripts.*` import(문자열 `"app.main:app"` 같은 참조 포함)를
이행적으로 따라간 결과다. 패키지의 `__init__.py`도 포함한다.

| 진입점 | 도달한 `app` 모듈 |
| --- | --- |
| 운영 스크립트(아래 표의 `scripts/*`) | 44 / 109 |
| + 컨테이너 기동 경로(`app/operator.py`, `core/storage_health.py`, `core/logging.py`, `core/operator_source_config.py`, `middleware/maintenance.py`, `api/operator_maintenance.py`, `api/v1/endpoints/health.py`) | 57 / 109 |
| + Docker 테스트, `scripts/serve.py`, `app/main.py` 전체 | 105 / 109 |

마지막 줄을 기준으로 필터를 만들면 backend PR에서 거의 건너뛰지 못하므로, 둘째 줄의 57개 모듈에
`app/main.py` 파일 자체만 더해 `operator_recovery` 목록을 만들었다. 요약 worker(`services/summary_worker.py`),
일반 API endpoint, 인증·추천·업로드 서비스, 외부 요약·OCR·메타데이터 클라이언트는 목록에 없다.
Docker 테스트 파일이 직접 import하는 `app` 모듈(`core.config`, `db.session`, `integrations.storage_client`,
`models.content`, `models.content_asset`, `services.maintenance`)과 `scripts` 모듈은 모두 목록 안에 있다.

진입점별 직접 import:

| 진입점 | 직접 import하는 `app` 모듈 | 직접 import하는 `scripts` 모듈 |
| --- | --- | --- |
| `scripts/maintenance.py` | `services.maintenance` | - |
| `scripts/restore_execution.py` | `core.deletion_ledger_config`, `integrations.deletion_ledger` | `check_backup_restore`, `image_backup_jobs` |
| `scripts/image_backup.py` | `core.config`, `db.session`, `integrations.deletion_ledger`, `integrations.storage_client`, `services.maintenance` | `check_backup_restore`, `image_backup_jobs`, `operator_runtime`, `recovery_probe` |
| `scripts/image_backup_jobs.py` | `db.session`, `integrations.deletion_ledger`, `services.maintenance` | `check_backup_restore`, `image_backup`, `operator_runtime`, `restore_execution` |
| `scripts/image_storage_admin.py` | `db.session`, `integrations.storage_client`, `models.content`, `models.content_asset`, `models.image_storage_control`, `models.user`, `services.image_storage_control`, `services.maintenance` | `image_backup` |
| `scripts/image_migration.py` | `db.session`, `integrations.deletion_ledger`, `integrations.storage_client`, `models.content`, `models.content_asset`, `models.image_deletion`, `repositories.content_repository`, `services.image_deletion_service`, `services.maintenance` | `check_backup_restore` |
| `scripts/image_deletions.py` | `core.deletion_ledger_config`, `db.session`, `integrations.deletion_ledger`, `services.image_deletion_service`, `services.maintenance` | - |
| `scripts/recovery_probe.py` | `core.config`, `db.session`, `integrations.storage_client` | `check_backup_restore` |
| `scripts/recovery_deletions.py` | `db.session`, `integrations.deletion_ledger`, `integrations.storage_client`, `repositories.content_repository`, `services.image_deletion_service` | - |
| `scripts/check_backup_restore.py` | - | - |
| `scripts/operator_runtime.py` | `core.deletion_ledger_config`, `integrations.operator_source`, `integrations.storage_client` | - |
| `scripts/image_source.py` | `integrations.operator_source` | - |
| `scripts/check_deployment.py` | - | - |
| `app/operator.py` | `api.operator_maintenance`, `core.operator_source_config`, `integrations.operator_source` | - |
| `app/core/storage_health.py` | `core.config`, `integrations.storage_client` | - |
| `app/middleware/maintenance.py` | `services.maintenance` | - |
| `app/api/operator_maintenance.py` | `services.maintenance` | - |
| `app/api/v1/endpoints/health.py` | `api.deps`, `core.config`, `core.storage_health`, `integrations.storage_client` | - |

`models`는 패키지 `__init__.py`가 모든 모델을 import해 전체(19개)가 포함되므로 `backend/app/models/**`로 적었다.
`middleware`도 파일이 하나뿐이라 디렉터리로 적었고, 빈 패키지 `__init__.py`는 `backend/app/**/__init__.py` 하나로 묶었다.
그 밖의 경로: `backend/Dockerfile*`, `.dockerignore`, `pyproject.toml`, `alembic.ini`, `alembic/**`, `scripts/**`,
`tests/deployment/**`, `tests/conftest.py`(Docker 테스트도 이 conftest 아래에서 돈다), workflow 파일.

`tests/conftest.py`는 호스트 pytest 프로세스에서 `app.main`을 import한다. 그 import가 깨지는 변경은 항상 도는
`test` job이 잡으므로 `app.main`의 import 범위 전체는 목록에 넣지 않았다.

### 목록이 낡을 위험

목록은 workflow에 손으로 적혀 있어, 운영 스크립트나 기동 경로가 새 `app` 모듈을 import하면 갱신해야 한다.
갱신하지 않으면 해당 모듈만 바꾼 PR·main push에서 `operator-recovery`가 건너뛰어진다.
이때 안전장치는 매일 04:00 KST 예약 실행이며, 회귀는 최대 하루 늦게 발견된다. 운영 스크립트의 import를 바꾸는 PR은
`backend/scripts/**`를 함께 바꾸므로 그 PR 자체에서는 검사가 돈다. 다시 계산할 때는 아래 스크립트를 `backend/`에서
`python3 closure.py <운영 스크립트들> <기동 경로 모듈들>`로 실행해 위 표의 둘째 줄과 비교한다.

```python
import ast, pathlib, re, sys

def modpath(m):
    p = pathlib.Path(m.replace('.', '/') + '.py')
    if p.exists():
        return p
    p = pathlib.Path(m.replace('.', '/')) / '__init__.py'
    return p if p.exists() else None

def imports(path):
    text = path.read_text()
    out = set()
    for n in ast.walk(ast.parse(text)):
        if isinstance(n, ast.Import):
            out |= {a.name for a in n.names}
        elif isinstance(n, ast.ImportFrom) and n.module and n.level == 0:
            out |= {n.module} | {f'{n.module}.{a.name}' for a in n.names}
    out |= set(re.findall(r'["\']((?:app|scripts)(?:\.\w+)+)', text))
    return {m for m in out if m.split('.')[0] in ('app', 'scripts')}

seen, stack = set(), [pathlib.Path(a) for a in sys.argv[1:]]
while stack:
    p = stack.pop()
    if p in seen:
        continue
    seen.add(p)
    for m in imports(p):
        parts = m.split('.')
        for i in range(1, len(parts) + 1):
            mp = modpath('.'.join(parts[:i]))
            if mp and mp not in seen:
                stack.append(mp)
print(*sorted(str(p) for p in seen if str(p).startswith('app/')), sep='\n')
```

## 로컬 검증

2026-11-01 이 worktree에서 실행한 결과다.

- `actionlint 1.7.12`(Homebrew로 설치): `actionlint .github/workflows/backend-validation.yml` 오류 없음.
- PyYAML 파싱: 트리거 `pull_request`·`push`·`schedule`·`workflow_dispatch`, 각 job의 `needs`·`if`·기존 timeout 확인.
  두 필터의 모든 패턴이 저장소의 실제 파일과 하나 이상 일치함을 확인했다(오타 없음).
- 경로 판정: 고정 커밋의 paths-filter 소스 `src/filter.ts`·`src/file.ts`를 그대로 받아, lock 파일과 같은
  `picomatch@2.3.1`·`js-yaml@4.1.0`으로 `tsx`에서 실행했다. workflow 파일에서 `filters` 입력을 읽어 `Filter.match`에
  아래 변경 목록을 넣었고 10건 모두 기대와 일치했다.

| 변경 | deployment | operator-recovery |
| --- | --- | --- |
| 요약 worker만 (`app/services/summary_worker.py`) | 실행 | 건너뜀 |
| `backend/Dockerfile` | 실행 | 실행 |
| `backend/scripts/maintenance.py` | 실행 | 실행 |
| 대상 app 모듈 (`app/services/maintenance.py`) | 실행 | 실행 |
| 대상 app 모듈 (`app/models/content.py`) | 실행 | 실행 |
| docs만 (`docs/backend/testing.md`, `docs/history/README.md`) | 건너뜀 | 건너뜀 |
| frontend만 (`frontend/src/App.tsx`) | 건너뜀 | 건너뜀 |
| workflow 파일 | 실행 | 실행 |
| API endpoint만 (`app/api/v1/endpoints/contents.py`) | 실행 | 건너뜀 |
| `backend/README.md`만 | 실행 | 건너뜀 |

`deployment`는 `backend/**` 전체를 보므로 `backend/README.md`·`.env.example`만 바뀌어도 돈다. 제외 규칙을 넣으면
필터 방식이 복잡해져 단순한 쪽을 택했다.

앱·백엔드 코드를 바꾸지 않아 pytest·Docker 검사는 실행하지 않았다.

## 미검증과 병합 후 확인

원격 Actions 실행은 PR이 필요해 확인하지 않았다. 병합 후 다음을 확인한다.

- 이 변경의 PR과 main push: workflow 파일이 바뀌었으므로 `deployment`·`operator-recovery`가 모두 실행된다.
  PR에서 `changes` job이 `pull-requests: read`로 변경 파일을 받는지 본다.
- 다음 backend 외 PR(frontend·docs만): 두 job이 건너뛰어지고 전체 시간이 `migration` 수준(약 3분)인지 본다.
- 다음 백업·복구와 무관한 backend PR(예: 요약 worker): `deployment`만 돌고 `operator-recovery`는 건너뛰어지는지 본다.
- 무관 변경의 main push: 두 job 판정이 push 직전 커밋 기준으로 나오는지, Railway의 "CI 통과 후 배포"가
  건너뛴 job을 막힘 없이 처리하는지 본다.
- 수동 실행(`workflow_dispatch`)과 첫 예약 실행(04:00 KST): 모든 job이 실행되는지 본다.

## 남은 위험

- 예약 실행은 main push와 같은 concurrency 그룹(`refs/heads/main`)을 쓰고 `cancel-in-progress: true`다.
  04:00 KST에 main push 실행이 진행 중이면 예약 실행이 그것을 취소하거나 반대로 취소될 수 있다.
  concurrency는 이번 범위에서 바꾸지 않았다.
- 야간 실행 실패를 누가 확인할지는 이슈의 "확인할 점"으로 남아 있다. GitHub 기본 알림은 예약 workflow의
  실패를 workflow의 cron 구문을 마지막으로 수정한 사용자에게 보낸다.
- main에 필수 검사를 켜면 건너뛴 job이 어떻게 보고되는지 다시 정해야 한다(이슈 "확인할 점").
- `tests/deployment/test_image_migration_docker.py`는 workflow 어느 job에서도 실행되지 않는다. 이번 범위에서 고치지 않았다.
