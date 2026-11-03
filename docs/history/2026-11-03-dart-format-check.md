# Dart 전체 포맷 정리와 앱 CI 포맷 검사

## 기준과 변경

- 최초 기록일: 2026-11-03. 이슈: [#222](https://github.com/clip-back/clipback/issues/222).
- 기준 main: `7693ad6`. 포맷 정리 `fc711d6`, CI·README `529c1dc`.
- Flutter 3.47.9 / Dart 3.13.7에서 `frontend/lib` 104개와 `frontend/test` 174개, 총 278개 Dart 파일을 검사했다. 로컬 Flutter의 channel 표시는 `[user-branch]`이며 CI는 기존 stable 3.47.9를 유지했다.
- `frontend/`에서 `dart format lib test`를 실행했다. 실제 변경은 `test/fixtures/today_server.dart`, `test/support/today_preview.dart` 두 파일이며 formatter 출력만 별도 커밋에 담았다.
- 앱 CI에 의존성 설치 다음, analyze 전에 `dart format --output=none --set-exit-if-changed lib test`를 추가했다. 기존 트리거·경로 필터·SDK·analyze·test는 유지했다.
- README에 범위·검사 및 수정 명령·CI 순서와 개인 `verify.py`에 포맷 검사가 없다는 차이를 반영했다. 저장소 밖 개인 도구는 수정하지 않았다.
- 검수-222는 Standards·Spec 양쪽 모두 지적 0건이었다. 리뷰어가 기준 커밋의 두 파일에 formatter를 적용한 stdout과 HEAD 파일의 바이트 일치를 별도로 확인했다.

## 검증

아래는 이번 워크트리에서 실행한 로컬 결과다. 상세 로그는 `.utmp/ticket-222/`에 남겼다.

| 검사 | 결과 | 로그 |
| --- | --- | --- |
| 정리 전 전체 포맷 검사 | 종료 코드 1, 278개 중 2개 불일치 | `partial-format-before.log` |
| 전체 formatter 적용 | 종료 코드 0, 278개 중 2개 수정 | `partial-format-apply.log` |
| 임시 유효 Dart 입력을 넣고 같은 검사 실행 | 종료 코드 1, 임시 입력만 불일치; 279개 전체 SHA-256 전후 동일 | `partial-format-negative.log` |
| 임시 입력 제거 뒤 같은 검사 실행 | 종료 코드 0, 278개 중 불일치 0개; 전체 SHA-256 전후 동일 | `partial-format-after.log` |
| workflow 순서·기존 설정 보존·README 대조 | 통과, 임시 입력 제거 확인 | `partial-workflow.log` |
| 리뷰 전 `verify.py --only app` | pub get·analyze·앱 테스트 2112개 통과 | `partial-app.log`, `partial-app/` |
| 리뷰 후 전체 `verify.py` | 전체 10개 검사 통과 | `final/verify-result.txt`, `final/` |

리뷰 후에는 저장소 루트에서 `~/.heoturu-agents/busy.sh`가 출력 없이 종료 코드 0인 것을 확인한 뒤 다음 명령을 600초 제한으로 한 번 실행했다.

```sh
python3 ~/.heoturu-agents/verify.py --log-dir .utmp/ticket-222/final
```

백엔드 ruff·compileall, 두 전용 DB의 Alembic upgrade·check, pytest 및 앱 pub get·analyze·test가 통과했다.
앱 테스트는 `+2112: All tests passed!`였다. pytest 요약 및 skip 사유는 도구 출력 그대로다.

```text
2024 passed, 46 skipped, 3 warnings in 169.24s (0:02:49)
pytest skip: 45 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=10 failed=0 logs=/Users/leehyeongyu/orca/workspaces/Clipback/dart-format-check/.utmp/ticket-222/final
```

`git diff --check`도 통과했다. 검증 후 추가한 변경은 이 이력과 목차뿐이다.

## 미검증과 적용 순서

- 원격 App Validation은 push 뒤 확인한다. 로컬 전체 PASS를 원격 CI 성공으로 취급하지 않는다.
- 배포·복구 및 외부 S3 환경이 필요한 위 skip 항목은 실행하지 않았으며 이번 앱 포맷·CI 변경 범위 밖이다.
- 화면·동작 변경이 없는 formatter·CI 정리이므로 이슈의 제외 범위에 따라 시뮬레이터·에뮬레이터 실행·촬영은 하지 않았다.
- 사용자 동작 변화가 없어 [배포 절차](../release-process.md#변경-작성과-pr-리뷰)에 따라 CHANGELOG 미배포 항목을 추가하지 않고 PR에 제외 사유를 적는다.
- 사용자 결정대로 목록 전체 개수 구현 전에 이 포맷 정리·CI PR을 먼저 병합한다. 해당 기능 작업은 갱신된 main에서 포맷 검사를 다시 실행한다.
