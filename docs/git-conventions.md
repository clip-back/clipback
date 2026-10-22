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
feat: 콘텐츠 저장 및 조회 추가
fix: 콘텐츠 카테고리 분류 오류 수정
docs: Git 협업 규칙 정리
chore: 로컬 PostgreSQL 실행 환경 추가
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

- 타입은 영어를 유지하고 summary는 한글로 작성하며 마침표를 붙이지 않습니다.
- 한 커밋은 가능한 하나의 의도만 담습니다.
- 커밋 제목은 72자 이내를 권장합니다.
- `.env`, `.venv`, 로컬 DB 데이터, 개인 설정 파일은 커밋하지 않습니다.
- 마이그레이션이 필요한 모델 변경은 Alembic migration 파일을 같은 PR에 포함합니다.

## Pull Request

PR 제목은 대표 커밋 메시지와 같은 형식을 사용합니다.

```text
feat: 콘텐츠 저장 및 조회 추가
```

PR 본문은 [저장소 PR 템플릿](../.github/pull_request_template.md)을 사용합니다.
아래 내용은 해당 템플릿과 동일하게 유지합니다.

```md
## 변경 사항

- 변경한 기능과 동작을 설명합니다.
- 변경이 필요한 이유를 설명합니다.
- 사용자 또는 개발자에게 미치는 영향을 설명합니다.

## 검증

- 실제 실행한 검증과 결과를 기록합니다. 예: 관련 pytest 통과
- 실행하지 않은 검증은 미실행으로 표시하고 이유를 적습니다.
- 운영 배포·실기기 검증 여부를 자동 테스트 결과와 구분합니다.

## 변경 이력

아래 항목 중 하나만 선택하고 반영한 항목 또는 제외 사유를 적습니다.

- [ ] 반영: 사용자에게 보이는 변경을 `CHANGELOG.md`의 `미배포`에 작성했습니다.
- [ ] 제외: 문서·테스트·동작 변화 없는 정리로 사용자 기능·동작에 영향이 없습니다.
- 반영한 항목 또는 제외 사유:
```

규칙:

- base 브랜치는 `main`으로 둡니다.
- PR은 draft가 아니라 바로 리뷰 가능한 상태로 올리는 것을 기본으로 합니다.
- 작업 범위가 아직 불확실하거나 테스트가 깨진 상태라면 draft로 올립니다.
- PR 제목과 본문은 한글로 작성합니다. 코드 식별자·명령·경로는 원문을 유지합니다.
- PR 본문에는 변경 내용과 실제 수행한 검증 명령·결과를 적습니다.
- DB 구조 변경이 있으면 migration 여부와 실행 결과를 적습니다.
- 작성자는 같은 PR에서 변경 이력을 반영하거나 제외 사유를 적고, 리뷰어는 실제 diff와 일치하는지 확인합니다.
- 변경 이력의 분류·적용 범위와 배포 기록은 [업데이트 내역과 배포 관리](release-process.md)를 따릅니다.
- 리뷰 반영 커밋도 같은 브랜치에 추가합니다.

## Merge

머지 커밋 또는 squash merge 메시지는 PR 제목과 동일하게 맞춥니다.

예시:

```text
feat: 콘텐츠 저장 및 조회 추가
```

본문을 넣을 수 있다면 한 줄 요약을 추가합니다.

```text
feat: 콘텐츠 저장 및 조회 추가

콘텐츠를 DB에 저장하고 상세·피드 조회를 제공합니다.
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

# 작업, 검증 후 변경 파일을 지정해 커밋
git add <files>
git commit -m "feat: 백엔드 예제 기능 추가"

git push -u origin feature/backend-example
gh pr create --base main --head feature/backend-example
```

## 문서 관리

- README는 현재 실행·구조·API 안내, 정책 문서는 현재 합의·범위·확인 필요 항목을 유지합니다.
- 상세 작업·검증·실패·미검증 기록은 [작업 이력](history/README.md)에 작업별로 한 번만 작성하고 다른 문서에서는 링크로 연결합니다.
- 과거 결과에 날짜·기준 커밋·검증 환경을 남기고 현재 코드 확인·새 실행·운영 배포를 구분합니다.
- 사용자 변경은 CHANGELOG, 실제 공개·배포 상태는 배포 기록에 남깁니다. 문서 정리만으로 해당 결과를 완료 처리하지 않습니다.

- README의 API·기능 안내는 요약과 상세 문서 연결로 구성합니다. 실행·구조가 바뀌면 README를 갱신하고, 상세 계약만 바뀌면 해당 기준 문서를 갱신합니다.
- 상세 설명은 [프론트 동작](frontend/behavior.md)·[프론트 개발·검증](frontend/development.md)·[백엔드 API](backend/api-contracts.md)·[백엔드 테스트](backend/testing.md)에서 관리합니다. 자동 분류·재발견·YouTube·디자인·운영의 전문 정책은 각 기존 문서를 따릅니다.
- 문서를 이동할 때 고유 본문·명령·검증 조건을 보존하고 상대 링크를 보정합니다. 기존 경로·제목 앵커에는 새 위치 안내를 남기며, 이관 기준과 대조 결과는 해당 작업 이력에 기록합니다.
