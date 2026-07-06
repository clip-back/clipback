# Git Conventions

Clipback 팀의 브랜치, 커밋, PR 작성 규칙입니다.

## Branch

기본 브랜치는 `main`입니다. 기능 개발은 항상 별도 브랜치에서 진행합니다.

브랜치 이름은 아래 형식을 사용합니다.

```text
<type>/<scope-or-summary>
```

권장 타입:

| Type | 용도 | 예시 |
| --- | --- | --- |
| `feature` | 새 기능 개발 | `feature/backend-content` |
| `fix` | 버그 수정 | `fix/category-duplication` |
| `docs` | 문서 작업 | `docs/git-conventions` |
| `chore` | 설정, 의존성, 개발환경 정리 | `chore/backend-env` |
| `refactor` | 동작 변경 없는 구조 개선 | `refactor/content-service` |
| `test` | 테스트 추가 또는 수정 | `test/content-feed` |

규칙:

- 한 브랜치는 하나의 작업 주제만 담습니다.
- 브랜치 이름은 영어 소문자와 `-`를 사용합니다.
- 백엔드 작업은 가능하면 `backend`를 scope에 포함합니다.
- 이미 PR이 열린 브랜치에는 관련 없는 작업을 섞지 않습니다.

## Commit

커밋 메시지는 Conventional Commits 형식을 따릅니다.

```text
<type>: <summary>
```

예시:

```text
feat: implement content persistence
fix: align content classification with categories
docs: add git conventions
chore: add local postgres compose
```

권장 타입:

| Type | 용도 |
| --- | --- |
| `feat` | 사용자 또는 API 관점의 기능 추가 |
| `fix` | 버그 수정, 잘못된 동작 교정 |
| `docs` | 문서만 변경 |
| `chore` | 빌드, 설정, 의존성, 개발환경 변경 |
| `refactor` | 동작 변화 없는 코드 구조 개선 |
| `test` | 테스트 추가 또는 수정 |
| `style` | 포맷팅처럼 동작과 무관한 스타일 변경 |
| `ci` | GitHub Actions 등 CI 설정 변경 |

규칙:

- summary는 영어 소문자로 시작하고 마침표를 붙이지 않습니다.
- 한 커밋은 가능한 하나의 의도만 담습니다.
- 커밋 제목은 72자 이내를 권장합니다.
- `.env`, `.venv`, 로컬 DB 데이터, 개인 설정 파일은 커밋하지 않습니다.
- 마이그레이션이 필요한 모델 변경은 Alembic migration 파일을 같은 PR에 포함합니다.

## Pull Request

PR 제목은 대표 커밋 메시지와 같은 형식을 사용합니다.

```text
feat: implement content persistence
```

PR 본문은 기본적으로 아래 템플릿을 사용합니다.

```md
## Summary

- What changed.
- Why it changed.
- User or developer impact.

## Validation

- cd backend && .venv/bin/python -m pytest -q
- cd backend && .venv/bin/python -m compileall app alembic tests
- cd backend && .venv/bin/alembic check
```

규칙:

- base 브랜치는 `main`으로 둡니다.
- PR은 draft가 아니라 바로 리뷰 가능한 상태로 올리는 것을 기본으로 합니다.
- 작업 범위가 아직 불확실하거나 테스트가 깨진 상태라면 draft로 올립니다.
- PR 본문에는 변경 내용과 검증 명령을 반드시 적습니다.
- DB 구조 변경이 있으면 migration 여부와 실행 결과를 적습니다.
- 리뷰 반영 커밋도 같은 브랜치에 추가합니다.

## Merge

머지 커밋 또는 squash merge 메시지는 PR 제목과 동일하게 맞춥니다.

예시:

```text
feat: implement content persistence
```

본문을 넣을 수 있다면 한 줄 요약을 추가합니다.

```text
feat: implement content persistence

Persist saved contents and serve detail/feed responses from the database.
```

규칙:

- 머지 전 PR의 validation 항목이 통과했는지 확인합니다.
- merge 메시지는 `feat:`, `fix:`, `docs:` 같은 타입을 유지합니다.
- 여러 PR을 한 번에 묶어 머지하지 않습니다.
- 머지 후 로컬 `main`을 최신화한 뒤 다음 브랜치를 생성합니다.

## Recommended Flow

```bash
git switch main
git pull --ff-only origin main
git switch -c feature/backend-example

# work, test, commit
git add <files>
git commit -m "feat: implement backend example"

git push -u origin feature/backend-example
gh pr create --base main --head feature/backend-example
```
