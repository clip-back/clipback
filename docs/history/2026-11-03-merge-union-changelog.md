# CHANGELOG·이력 목차의 동시 추가 충돌을 merge=union으로 자동 해결

최초 기록일: 2026-11-03 KST. 이슈 [#195](https://github.com/clip-back/clipback/issues/195), 시작 커밋 `d1ec34f`,
작업 브랜치 `chore/merge-union-changelog`.

## 문제와 결정

- 동시에 진행한 브랜치가 `CHANGELOG.md`의 `미배포` 절과 이 목차의 맨 윗줄에 각자 한 줄씩 넣으면 나중에 병합하는 쪽이 매번 충돌했다.
  푸는 방법은 늘 양쪽 줄을 모두 남기는 것이었다(#189 `3cb31db`, #209 `d0fb990`, #216 `b5b1ef8`).
- 2026-11-03 사용자 결정(#216 회고 8번): 저장소 루트 `.gitattributes`에 `CHANGELOG.md merge=union`, `docs/history/README.md merge=union`을 둔다.

## 변경 내용

- 루트 `.gitattributes`에 위 두 줄을 추가했다.
- [Git 협업 규칙의 문서 관리](../git-conventions.md#문서-관리)에 한 줄 안내를 넣었다. 병합 뒤 두 파일의 diff 확인, 같은 날짜 안 순서는 리뷰가 본다는 것,
  이 설정 전에 만든 작업 브랜치는 첫 main 병합에서 한 번 손으로 푼다는 것이다.

## 검증 (로컬, Git 2.39.1)

워크트리 밖 `/tmp` 임시 클론에서 과거 충돌을 다시 합쳤다. 작업 브랜치 쪽(ours)에 `.gitattributes`를 커밋한 뒤 상대 커밋을 합쳤다. 임시 클론은 확인 뒤 지웠다.

| 사례 | ours + theirs | 속성 없이 `merge-tree` | 속성 추가 뒤 `merge-tree` / `merge` | 손으로 푼 커밋과 두 파일 비교 |
| --- | --- | --- | --- | --- |
| #189 | `70ce7ff` + `37230f5` | exit 1 (두 파일 충돌) | exit 0 / exit 0 | `3cb31db`와 같음 |
| #209 | `98be030` + `0cccaaa` | exit 1 (목차 충돌) | exit 0 / exit 0 | `d0fb990`와 같음 |
| #216 | `30202bc` + `7086d81` | exit 1 (목차 충돌) | exit 0 / exit 0 | `b5b1ef8`와 같음 |

- 세 사례 모두 손으로 푼 커밋과의 전체 트리 차이는 `.gitattributes` 하나뿐이었다. 티켓 리뷰도 같은 세 사례를 따로 돌려 `git diff --exit-code`로 같음을 확인했다.
- 같은 줄을 양쪽이 다르게 고친 경우(`d1ec34f` 기준, `CHANGELOG.md` 작성 원칙 첫 줄에 A·B가 각각 다른 문구를 붙임):
  `merge-tree`·`merge` 모두 exit 0이고 충돌 없이 고친 두 줄이 모두 남았다. 병합 뒤 diff 확인이 필요한 이유다.
- 작업 브랜치 쪽에 속성이 없고 상대 쪽에만 있는 경우(#216 `30202bc` + 속성을 커밋한 `7086d81`): `merge-tree`·`merge` 모두 exit 1로 목차가 충돌했다.
  이 설정이 main에 들어가기 전에 만든 브랜치는 첫 main 병합에서 기존처럼 손으로 푼다.
- `git diff --check` 통과. 앱·백엔드 코드는 바뀌지 않아 `verify.py`는 돌리지 않았다.

## 미검증

- GitHub PR 화면의 병합 가능(충돌) 표시, 웹 병합·"Update branch" 버튼이 `union`을 따르는지는 PR을 연 뒤에만 볼 수 있어 아직 확인하지 않았다.
  따르지 않으면 그 사실만 적고 지금처럼 로컬 `git merge origin/main`으로 푼다.
