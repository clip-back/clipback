# 콘텐츠 삭제 전 확인 창 (#238)

## 변경

시작 커밋 `bdc95fc`에서 모든 기존 콘텐츠 관리 메뉴의 삭제에 확인 단계를 추가했다.
카테고리 삭제 모달의 치수·글꼴·색을 콘텐츠 전용 위젯에 재사용하고 카테고리 제품 코드는 변경하지 않았다.
승인 문구·Figma 노드·예외는 [화면 맞춤 계획](../figma-ui-alignment-plan.md#콘텐츠-삭제-확인-238)에 기록했다.
관리 시트를 닫은 뒤 확인 창을 열며, 취소·바깥 탭·뒤로가기는 요청 없이 닫는다.
확인 창을 연 화면의 생존 여부·콘텐츠 ID·변경 중 상태와 앱의 계정 세대를 검사한 뒤 기존 삭제 콜백을 실행한다.
삭제 API·Repository·ViewModel의 성공·실패·재조회 정책은 유지한다.

## 부분 검증 (2026-11-06, 첫 리뷰 전)

실제 케밥 → 삭제 UI 테스트를 먼저 추가했다. 기존 코드에서 DELETE `/contents/3`이 발생해
요청 0회 단언이 실패했고, 구현 뒤 같은 테스트가 통과했다.

- `frontend/`에서 `flutter test --no-pub test/content_mutation_test.dart test/archive_all_mutation_test.dart test/feed_pagination_test.dart test/search_alignment_test.dart test/bookmark_alignment_test.dart test/detail_alignment_test.dart`: 283개 통과.
- 각 진입점 성공 후 삭제 단언을 추가한 뒤 `flutter test --no-pub test/content_mutation_test.dart`: 98개 통과.
- `flutter analyze --no-pub`: `No issues found!`.
- 변경 Dart 파일 포맷 및 `git diff --check`: 통과.
- 각 검사 전에 `busy.sh --wait` 완료 확인 후 `busy.sh &&`로 재확인했다.

새 UI 테스트는 전체보기·카테고리·미분류·즐겨찾기·검색·홈 유입 상세·오늘 유입 상세의 링크와 스크린샷을 확인한다.
취소·바깥 탭·시스템 뒤로가기에서는 요청 수 불변을 확인하고, 확인 뒤 선택 ID의 DELETE 1회와 콘텐츠 제거를 확인한다.
보류된 실제 MockClient 요청과 삭제 중 모델 상태로 느린 응답 상태에 들어갔음을 증명하고 연타·성공·실패를 확인한다.
확인 대기 중 대상/화면/계정 전환을 확인하며, 기존 회귀 테스트가 늦은 응답과 계정 변경 뒤 결과 격리를 검사한다.
Pretendard를 실제 로드하여 320×568에서 배율 1.0·1.1·1.2·1.3을 독립 테스트했다.
기존 테스트 이름·기대값은 변경하지 않고 새 테스트와 import만 추가했다.

최초 새 목록 테스트는 카드 키를 숫자 ID로 찾는 fixture 오류로 실패했다. 실제 ContentItem ID에 맞춘 뒤 통과했다.
분석에서 발견한 중괄호 스타일 지적 3건은 수정했다. SVG의 기존 `unhandled element <filter/>` 로그는 남는다.
로컬 원본 로그는 `.utmp/ticket-238/partial-red.log`, `partial-green.log`, `partial-regression.log`,
`partial-content-final.log`, `partial-analyze-2.log`에 보존했다.

## 검수와 전체 검증 (2026-11-06)

검수 범위 `bdc95fc..14d3135`의 Standards·Spec은 각각 지적 0건이다.
문구 참고 의견에도 실행할 수정 요청은 없어 승인 문구를 유지했다.
감독이 `git fetch origin` 뒤 `HEAD..origin/main`이 비었음을 확인하여 추가 병합은 하지 않았다.
코드 근거 커밋은 `14d31350a1059c2497f45be7ce450fa7536946f3`이며, 깨끗한 작업 트리에서 전체 검증을 한 번 실행했다.

저장소 루트에서 `busy.sh --wait`를 비동기 실행하여 idle 종료를 확인한 뒤,
셸 제한 600초로 아래 명령을 실행했다.

```bash
bash "$HOME/.heoturu-agents/busy.sh" && python3 ~/.heoturu-agents/verify.py --log-dir .utmp/ticket-238/final
```

실제 결과 파일: `/Users/leehyeongyu/orca/workspaces/Clipback/delete-confirm/.utmp/ticket-238/final/20261106T004514-effb71d7db3d/verify-result.txt`.
결과 파일과 단계별 로그 및 `verify-progress.json`의 종료 코드 0을 대조했다.

```text
pytest skip: 45 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=11 failed=0 logs=/Users/leehyeongyu/orca/workspaces/Clipback/delete-confirm/.utmp/ticket-238/final/20261106T004514-effb71d7db3d
```

- 백엔드 ruff·compileall, 테스트/유지보수 DB 각각의 Alembic upgrade·check 통과.
- pytest 원문: `2048 passed, 46 skipped, 3 warnings in 171.74s (0:02:51)`.
- 앱 pub get·format·analyze·test 통과. format은 285개 파일 중 변경 0개, 앱 테스트는 2,931개 통과.
- skip 46개는 통과 수에 포함하지 않는다. deployment 45개는 opt-in Docker 실행과 식별된 API/operator 이미지·Docker/PG18 등의 조건 미충족, integration 1개는 `CLIPBACK_IMAGE_TEST_S3_ENDPOINT` 미설정이다. 개별 원문은 같은 디렉터리의 `backend-pytest.log`에 보존되어 있다.
- 이번 후속 변경은 이력 문서뿐이며 제품 코드·승인 문구는 변경하지 않았다. 문서 커밋 때문에 전체 검증을 반복하지 않는다.

## 미완료 범위

iOS Simulator·Android Emulator 변경 전/후 화면과 영상은 감독이 후속 확보한다.
변경 전 촬영은 승인된 병행 예외에 따라 시작 커밋에서 확보하며 제품 파일 복원과 구현을 동시에 하지 않는다.
기기 화면 확인·시각 승인·원격 CI·실기기·운영 검증을 자동 테스트 통과로 대신하지 않는다.
Docker/S3 skip 범위도 미검증으로 남는다. 이번 단계에서 촬영·GitHub 쓰기·push·PR은 수행하지 않았다.
