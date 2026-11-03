# 앱 pub get·analyze·test 원격 검사 워크플로 추가

최초 기록일: 2026-11-03 KST. 기준은 [이슈 #136](https://github.com/clip-back/clipback/issues/136) 본문과
2026-11-03 댓글(#209 회고 1번, 본문의 Flutter 버전 기준을 대신함)이다. 브랜치 `ci/app-validation`(main `2477a99` 기준),
PR [#215](https://github.com/clip-back/clipback/pull/215).

## 결정 (사용자 확인 2026-11-03)

- Flutter 버전은 FVM 같은 새 도구 없이 워크플로 값(`flutter-version: 3.47.9`, `channel: stable`)으로 고정한다.
- CI의 `pub get`에 `--enforce-lockfile`을 붙인다. 잠금파일과 어긋난 PR을 잡기 위해서다.
  로컬 `verify.py`(저장소 밖 개인 도구)의 app:pub-get도 같은 옵션으로 맞췄다.
- CHANGELOG 누락 검사, `flutter build web`, iOS·Android 빌드와 시뮬레이터·에뮬레이터 실행, #140 2단계는 범위 밖이다.

## 변경 범위

- `.github/workflows/app-validation.yml`(`name: App Validation`)
  - 트리거: main 대상 `pull_request`와 main `push`(경로 `frontend/**`, 이 워크플로 파일), `workflow_dispatch`.
    main에는 브랜치 보호와 ruleset이 없어(이슈 댓글의 2026-11-03 확인) 워크플로 수준 `paths:`로 건너뛰어도 필수 검사가 막히지 않는다.
  - `permissions: contents: read`, PR별 concurrency(`cancel-in-progress: true`)는 백엔드 워크플로를 따랐다.
  - `subosito/flutter-action`을 v2.23.0 커밋 `1a449444c387b1966244ae4d4f8c696479add0b2`로 고정하고 `cache: true`로
    Flutter SDK와 pub 캐시(키에 `pubspec.lock` 해시 포함)를 쓴다.
  - 단계: `flutter --version`, `flutter pub get --enforce-lockfile`, `flutter analyze --no-pub`, `flutter test --no-pub`(작업 디렉터리 `frontend`).
- `frontend/README.md` 기본 검증 절에 워크플로 안내와, 리뷰 때 CI 통과로 로컬 앱 검사를 대신할 수 있다는 안내를 넣었다.
- 3.47.9 확인: 공식 릴리스 목록 `https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json`
  (2026-11-03T05:00:56Z 조회)에서 3.47.9는 stable이고 현재 stable이며, 해시 `c197ca5199`가 로컬 SDK와 같다.

## 검증

- 로컬: `actionlint` 통과, `git diff --check` 통과.
  `python3 ~/.heoturu-agents/verify.py --only app`은 `VERIFY result=PASS scope=app checks=3 failed=0`이고,
  pub get 로그 첫 줄에서 `--enforce-lockfile` 사용을 확인했다. `flutter test --no-pub` 2031개 통과.
- 원격 CI(PR #215, 시간은 run의 createdAt·updatedAt, UTC):

| 확인 | 커밋 | 결과 | run |
| --- | --- | --- | --- |
| 첫 실행 | `e65a325` | 성공. 로그에 `Flutter 3.47.9 • channel stable`, analyze `No issues found!`, `2031 tests passed.` (05:16:10Z–05:22:56Z) | [41582919133](https://github.com/clip-back/clipback/actions/runs/41582919133) |
| 일부러 실패 | `0308f97` 실패하는 임시 테스트 추가 | 실패. Test 단계만 실패(`Expected: <2>`, `Actual: <1>`), 앞 단계는 성공 (05:23:34Z–05:28:08Z) | [41583645991](https://github.com/clip-back/clipback/actions/runs/41583645991) |
| 되돌림 | `9e7c414` (`git revert`) | 성공. 3.47.9 표시, analyze 문제 없음, `2031 tests passed.` (05:29:13Z–05:35:20Z) | [41584181758](https://github.com/clip-back/clipback/actions/runs/41584181758) |

## 미검증

- 앱 경로를 바꾸지 않는 PR·push에서 앱 작업이 돌지 않는지는 확인하지 못했다. 워크플로가 main에 들어가기 전에는
  다른 PR·push에 이 워크플로가 없고, `pull_request` 경로 필터는 PR 전체 diff를 보는데 이 PR에는 `frontend/`와 워크플로 변경이 들어 있다.
  병합 뒤 앱 경로를 바꾸지 않는 첫 main push 또는 PR에서 확인하고 #136 댓글로 남긴다.
