# 에이전트 스킬 저장소 설정

최초 기록일: 2026-10-23 (KST). 사용자가 승인한 설정 초안을 적용한 문서·이슈 라벨 작업입니다.

## 기준과 변경 범위

- 기준 커밋: `19bfb43c0dbc95f08584151d65bc7a2f87b363ea`.
- 작업 브랜치: `docs/agent-skills-setup`.
- 작업 전 `git status --short`와 staged·unstaged diff가 모두 비어 있었습니다.
- GitHub Issues를 이슈·명세 저장소로 선택하고 기본 triage 역할 5개를 그대로 사용하도록 승인받았습니다.
- [이슈 관리](../agents/issue-tracker.md), [라벨 매핑](../agents/triage-labels.md),
  [도메인 문서 읽기 규칙](../agents/domain.md)을 추가했습니다.
- README의 협업 안내에서 설정 문서를 찾을 수 있도록 연결했습니다.
- 로컬 `AGENTS.md`의 기존 본문을 보존하고 `Agent skills` 블록을 한 번 추가했습니다.
  이 파일은 기존 Git 제외 규칙을 유지하며 커밋 대상에서 제외했습니다.
- 도메인 문서는 single-context 구조로 설정했습니다. 용어와 결정이 확정될 때 작성하도록
  `GLOSSARY.md`, `GLOSSARY-MAP.md`, `docs/adr/`는 생성하지 않았습니다.

## GitHub 라벨 반영

대상: [clip-back/clipback 라벨](https://github.com/clip-back/clipback/labels).

- `gh label list --repo clip-back/clipback --limit 200 --json name,color,description`으로 전후를 조회했습니다.
- 없는 라벨 4개만 `gh label create`로 생성했습니다:
  `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`.
- 기존 `wontfix`를 포함한 라벨 9개의 이름·색상·설명을 전후 비교하여 모두 보존했음을 확인했습니다.
- 반영 후 설정된 역할 5개가 모두 존재하고 전체 라벨이 13개임을 확인했습니다.

## 실제 확인과 미검증

- 환경: macOS의 저장소 루트, GitHub CLI `2.97.0`.
- `gh issue create/view/list/edit/comment/close --help`와 `gh pr view --help`를 각각 조회하여
  문서에 적은 옵션과 JSON 필드가 설치된 CLI에서 지원됨을 확인했습니다.
- 상대 문서 링크의 대상, `AGENTS.md`의 설정 파일 참조 3개, 파일 끝 개행과 줄 끝 공백을 확인했습니다.
- 로컬 `AGENTS.md`를 수정 전 사본과 비교하여 기존 본문 보존과 안내 블록 중복 없음을 확인했습니다.
- `git check-ignore`와 `git ls-files`로 `AGENTS.md`가 제외·미추적 상태임을 확인했습니다.
- 최종 diff와 `git diff --check`로 변경 범위와 공백 오류를 확인했습니다.
- 문서·라벨 설정만 변경했으므로 앱 테스트, iOS Simulator, Android Emulator는 실행하지 않았습니다.
- 이슈 생성·댓글·하위 이슈·의존 관계의 실제 쓰기는 검증용으로 실행하지 않았습니다.
  해당 명령은 CLI 도움말과 대조한 것이며 실제 트래커 워크플로 성공을 뜻하지 않습니다.
- 원격 CI, 운영 서버, OAuth, 실기기 검증은 이번 작업 범위에 포함하지 않았습니다.
- 사용자 기능·동작 변경이 없어 `CHANGELOG.md` 반영 대상에서 제외했습니다.

이후 설정은 `docs/agents/*.md`를 직접 수정할 수 있습니다.
설정 스킬의 재실행은 이슈 트래커를 바꾸거나 처음부터 재설정할 때 사용합니다.
