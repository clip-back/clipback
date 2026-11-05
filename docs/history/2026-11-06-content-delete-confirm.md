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

## 양 플랫폼 화면 검증 (2026-11-06)

실제 앱 루트와 메모리 HTTP 대역으로 변경 전 `bdc95fc`, 변경 후 `14d3135`를 실행했다.
변경 전 촬영은 승인된 병행 예외에 따라 시작 커밋의 제품 파일을 임시 복원해 빌드했고,
빌드 뒤 작업 파일을 복구했다. Android APK와 iOS 앱 kernel의 설치 해시 및 `/ready` phase를 대조했다.
기기 충돌로 중단한 뒤 조율 승인에 따라 기기 주인 잠금을 잡고 cold boot하여 재개했다.

| 플랫폼 | 환경 | 확인한 화면 크기·배율 |
| --- | --- | --- |
| iOS | iPhone 16 / iOS 18.6 Simulator | 세로 393×852, 가로 852×393; 1.0·1.3 |
| Android | Medium_Phone / Android 16 API 36 Emulator | 411.43×914.29, OS 해상도 override로 320×568; 1.0·1.3 |

- 전체보기·카테고리·미분류·즐겨찾기·검색 목록, 홈·목록·오늘의 콘텐츠 유입 상세에서 확인 창과 취소/확정을 확인했다. 링크의 모든 진입점을 촬영하고, 스크린샷 콘텐츠는 전체보기 대표 경로를 촬영했다. 모든 진입점×콘텐츠 종류 조합은 자동 테스트 근거와 구분한다.
- 확인 대기는 DELETE 0회/6개 유지, 취소·바깥 탭·뒤로가기 뒤에도 0회/6개이며 다시 열 수 있었다. 확정 성공은 선택 ID의 DELETE 1회/5개와 기존 상세 복귀를 확인했다.
- 실제 보류 응답에서 삭제 중 표시와 연타 차단을 확인했다. 실패는 콘텐츠를 유지하고 기존 오류를 표시했으며, 재시도 때 확인 창을 다시 거친 뒤 성공했다.
- 테스트 하네스로 상세의 대상 변경·화면 종료·계정 로그아웃 경계를 재현했다. 늦은 확인 뒤 DELETE 0회/6개가 유지됐다. 새 계정 로그인 추가 촬영은 계측 실패로 근거에서 제외했으며 새 계정 격리의 자동 테스트와 구분한다.
- Android 뒤로가기는 native 입력, iOS는 하드웨어 버튼이 없어 프레임워크 route back 하네스로 재현했다. 검색은 양쪽 native `clip` 입력과 제출을 사용했고 선입력으로 대체하지 않았다.
- 짧은 화면에서 제목·본문·버튼의 잘림 없이 취소할 수 있었다. iOS는 세로에서 확인 창을 연 뒤 가로 회전했다. 가로 1.3에서 기존 관리 시트를 새로 열면 삭제 행 일부가 잘리는 별도 경로는 관찰 사실로 남기며 이번 확인 창 검증과 구분한다.

F-M06 `120:4293`(375×812)은 00:54 KST, E12 `111:4484`는 01:18 KST 재조회했다.
F-M06은 문구 기준이며 카테고리 모달 모양·빨강 버튼·가로 배치·미리보기 없음은 승인된 예외다.
iOS 세로 OS 안전 영역은 위 59/아래 34, 가로 좌우 59/아래 21이며 Android는 위·아래 24다.
원본 화면의 영역을 보정하지 않았다. 기본/목록/상세/짧은 화면은 변경 전·후·Figma 비교를 제공한다.
대기·실패와 수명 전환은 대응 Figma 원본이 없어 실제 기기 결과만 제공하고 누락 이유를 기록했다.
변경 전에는 취소 단계가 없으므로 가짜 취소 화면은 만들지 않았다.
영상은 최신 사용자 속도 규칙에 따라 생략하고 상태별 PNG/계측으로 확인했다.

상세 촬영 목록·입력 방식·산출물 해시·한계는 로컬 `.utmp/ticket-238/capture-evidence.md`에 있다.
원본은 같은 디렉터리 `screens/`, 비교는 `compare-{ios,android}*.png`와 `-preview.png`다.
비교 도구는 실제 동작 직전의 화면/스크롤/데이터/입력과 출력 OS 크기·안전 영역·배율을 대조하고,
삭제로 달라진 출력 레이아웃은 별도로 표시한다. 원본 JSON은 바꾸지 않았다.
촬영 후속 검수에서 시작 계측의 타입·스크롤 extent 검증 누락 1건을 발견해 반영했다.
시작 record IDs/텍스트/계정/동작 상태의 스키마와 전체 scroll 조건을 검사하고,
출력의 scroll offset/extent 변화도 로그에 표시하도록 보강했다. 원본 JSON·PNG는 수정하지 않았다.
변형 거부·출력 차이 보고 테스트 5개가 통과했고 검수자의 재현 코드로 수정 효과를 대조했다.
기존 원본의 시작 상태 98쌍과 촬영 파일 134개를 재대조하여 통과했고 비교 이미지를 다시 생성했다.
로그는 `compare-guard-test.log`, `guard-repro-after.log`, `guard-all-start-pairs.log`, `capture-audit.log`다.
route ID는 직접 수집하지 않았으며 동일 화면 텍스트·스크롤·데이터는 진입 상태의 간접 근거다.

## 남은 확인과 범위

사용자 시각 승인과 PR 본문 승인을 기다린다. 원격 CI는 push/PR 전이라 실행하지 않았다.
Docker/S3 skip 범위는 미검증이며, 실제 OAuth·공유 자격증명·실기기·운영은 이번 작업 범위 밖이다.
기기 결과를 사용자 승인이나 운영 결과로 대신하지 않는다. GitHub 쓰기·push·PR은 수행하지 않았다.
