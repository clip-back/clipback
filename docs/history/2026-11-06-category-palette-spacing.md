# 카테고리 8색 간격 재배치·최종 재검증 (#242)

2026-11-06 사용자 화면 피드백을 반영한 후속 기록이다.
이전 [작은 UI 묶음 이력](2026-11-06-small-ui-batch-1.md)의 왼쪽 정렬·고정8px 보존은
이번 결정으로 대체한다. 다른 세 이슈의 결정·화면 증거는 그 이력의 당시 기준을 유지한다.
간격 변경 당시 제품·테스트 기준은 `6a377dfc5088dfefa09da8515c06aaf4036dc4b2`다.
최신 main 병합 검증은 아래 최종 검증 절에 구분해 기록한다.

## 결정·구현

사용자 결정(원문): "카테고리 색 선택에서 지금 피그마 화면과 같이 간격이 맞았으면 좋겠어 지금은 왼쪽에 쏠려있는 느낌이라 무지개 팔레트가 채워지기 전까지 어색해 보일 것 같아"

8색이 가용 줄 폭의 양끝에 맞고 중간 간격은 같게 배치한다. 기존 색 순서·RGB·선택 표시,
문구·버튼·폴더 그림을 바꾸지 않는다. 생성·수정·팔레트 밖 색 수정이 같은 규칙을 쓴다.
제품 팔레트는 고정8개이며 개수가 다른 실제 상태는 발견하지 않았다.

공통 `FolderColorPicker`의 가용 폭과 최소 내용폭 중 큰 폭에 `spaceBetween`을 적용했다.
선택 링36px·미선택30px를 유지한다. 최소 내용폭은 단색 선택302px, 밖 색296px로,
320px 기기의 가용272px에서는 최소8px 간격과 기존 가로 스크롤을 유지한다.
Figma E09의304px 중앙 배치를 그대로 복제한 것은 아니다. 조율의 “줄 폭에 맞춰” 지시에
따라 가용327/345/363.43px에 분배한 감독 판단이며 사용자 시각 판정은 별도로 남긴다.

| 화면폭 | 가용폭 | 단색 선택 간격 | 밖 색 간격 |
| --- | --- | --- | --- |
| 320 | 272 | 8, 가로 스크롤 | 8, 가로 스크롤 |
| 375 | 327 | 약11.57 | 약12.43 |
| 393 | 345 | 약14.14 | 15 |
| 411.43 | 363.43 | 약16.78 | 약17.63 |

공유 테스트의 배율 전달·앱 폭 연결과 간격 판정만 함께 보완했다.
기본1.0배·다른 요소 기하 단언 및 촬영 실행 함수 `_run`/`_paletteDrag`는 유지했다.

## 검수·자동 검사

구현 전48개 새 좌표 검사는 모두 실패했고, 첫 GREEN의8건은393px 실측
29.99999999999997과30.0의 직접 비교 오류였다. 크기 단언을0.001px 허용 오차로
보완한 뒤 지정5파일254개와 analyze가 통과했다. 기존 색 저장·취소·잠금 단언은 유지했다.
로그는 `.utmp/ticket-242/spacing/partial-*.log`이며 실패 로그도 보존했다.

`20d7dee..6a377df` 변경분 검수는 Standards·Spec 각각 높음0/중간0/낮음0이다.
검수 결과 `.utmp/review-242-spacing.md`의 REVIEW-DONE과 실제 검사 로그를 감독이 대조했다.
리뷰어는 Flutter 검사를 반복 실행하지 않았다.

공용 busy 대기 뒤 셸 제한600초로 새 전체 검증을1회 실행했다.

```sh
~/.heoturu-agents/busy.sh && python3 ~/.heoturu-agents/verify.py --log-dir .utmp/ticket-242/spacing/verify
```

```text
pytest skip: 45 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=11 failed=0
```

pytest **2048 passed, 46 skipped, 3 warnings**, 앱 **3034 PASS**다.
원문은 `.utmp/ticket-242/spacing/verify/verify-result.txt`, 실행 로그는
`20261106T050502-a40ecebd6b3d/`에 있다. 모든 진행 이벤트24개가 같은 SHA·dirty=false였다.
skip은 통과가 아니며 Docker deployment와 별도 S3 endpoint 영역은 미실행이다.
이전5a5725e PASS를 새 결과로 사용하거나 합산하지 않았다.
촬영 하네스 사전 검사3건, iOS·Android debug 빌드·설치본 대조도 통과했다.
Android 빌드 뒤 Gradle daemon1개를 종료했다. 기존 SDK XML/Kotlin 경고는 비치명적이었다.

## 양 플랫폼 재촬영

| 플랫폼 | 기기·OS | 논리 화면·DPR | OS safe 위/아래 | 키보드 |
| --- | --- | --- | --- | --- |
| iOS | iPhone16, iOS18.6 Simulator | 393×852, 3 | 59/34 | 생성 전336; 선택·수정·밖 색0 |
| Android | Medium_Phone, Android16 API36 Emulator | 411.42857×914.28571, 2.625 | 24/24 | 네 상태336.38095238 |

palette-create/selected/edit/outside 각각 앱 글자 배율1.0/1.3으로 새로 촬영했다.
새 변경 후 PNG16장·probe16개와 플랫폼별4개 비교 이미지가 있다.
변경 전은 이미 확보한6c9c668의 같은 상태 원본16장·probe를 그대로 재사용했다.
기존 inventory SHA와 대조했고 이전 변경 후 파일이나 원본을 덮어쓰지 않았다.
새 폴더는 `.utmp/palette-spacing-capture/`, 원본 출처·해시는
`baseline-provenance.json`과 `capture-inventory.json`에 있다.

조건 대조8건 모두 PASS다. 기기·OS/app insets·데이터·입력/selection/focus·출처·배율·
스크롤을 그대로 대조했고 검사 기준이나 원본 JSON을 맞춰 고치지 않았다.
iOS의 기존 무지개 포함 scrollMax3→0은 출력 배치 차이로 기록됐다.
감독이 각 플랫폼 네 상태의1.3배 원본과 모든 비교 preview를 직접 읽었다.
키보드·대상 버튼이 기대대로 보이고 OS 편집 메뉴는 없었다. Android 커서 손잡이와
일부 iOS Dynamic Island/커서 깜빡임은 OS 표시 차이로 남겼다.

8색의 분산 배치, 단색 선택 링·미리보기와 밖 색 무선택·산호색 폴더를 확인했다.
문구·버튼·폴더 위치에는 새 변경이 보이지 않았다.
양 플랫폼에서 native `batch241` 입력→파랑 선택→생성하기 후 목록 반영과
`unexpected=[]`를 확인했다. 로컬 memory API 결과이며 운영 저장 증거는 아니다.
320px 스크롤은 자동 검사 근거다. 간격은 정적 변경이므로 영상은 새로 만들지 않았다.
기존 다른14상태/탭 영상은5a5725e 당시 증거로 보존하며 새SHA에서 재촬영했다고 주장하지 않는다.

Figma 기준은 기존 직접 조회한 E09 `111:4287`(01:15:53.935551 KST),
E10 `111:4376`(03:05:07.105700), E11 `111:4427`(01:15:54.202578)이다.
조회일은 모두2026-11-06이고 manifest와 PNG를 보존했다. 375×812 디자인과 실제 기기,
한글/영문 키보드·입력값은 다르다. E11에는 과거 무지개가 있고 밖 색 전용 원본은 없다.

미디어 갤러리: `.utmp/palette-spacing-capture/comparison-index.md`.
비교 preview는 `compare-{ios,android}-palette-{create,selected,edit,outside}-preview.png`다.
`build-artifacts.json`의 iOS kernel SHA-1은
`417114c092036002641b6221e1c4c98dceea5463`, Android APK SHA-256은
`5fd58454aa351879bbfb6600ba923432407976fff88636b97be82faf6ad82d78`이다.

기기 잠금은 #245 종료 뒤05:18:26에 얻었고 iOS 종료·반납 후05:22:03에 Android 블록으로
재획득했다. Android 종료 응답 뒤 qemu가 남은 동안은 busy가 비워질 때까지 잠금을 유지했다.
양 플랫폼 종료와 잠금 반납 후 문서만 기록하며 제품·테스트가 PASS 기준과 같아
전체 검사를 반복하지 않는다. 실기기·운영·원격 CI는 이번 범위 밖이다.

## 당시 남은 확인

새 배치의 사용자 시각 판정과 PR 본문 승인을 기다린다. push·PR 생성·이슈 종료는 하지 않았다.
회고 필요: 예. 첫 화면 판정에서 배치 결정이 바뀌어 재작업·재촬영했다.

## main 추가 병합·전체 검사 (최종)

사용자 결정(2026-11-06, 원문): "응" — 조율의 "색 간격을 고친 화면과 PR 초안으로 push·PR을 만들어도 될까요?"에 대한 답이다.
이후 조율 지시로 main `bf65413`(콘텐츠 삭제 확인, PR #247)을 합쳤다.
`frontend/README.md`의 유일한 충돌은 삭제 확인 창 안내 다음에 빈 상태 그림 자산 절을
배치하여 양쪽 문단을 모두 보존했다. 병합 커밋은 `f88e6834cb8a1e56311f7600ccb043f3d941019e`다.

#247의 제품 diff는 삭제 선택 후 확인 창과 계정·소유 화면 guard 변경으로, 이 묶음의 촬영 상태(빈 화면·저장 결과·색 선택·하단 탭) 표시와 겹치지 않아 재촬영하지 않고 기존 증거를 유지했다.
공유 `clipback_app.dart`의 즐겨찾기 key는 계정 전환 시 화면을 새로 만드는 변경이며,
같은 계정의 촬영 상태 배치·자산·문구는 바꾸지 않는다. diff 판단 근거는
`.utmp/pr-publish/main-247-screen-impact.md`에 기록했다.

`busy.sh --wait`로 12:54:26부터 #245의 빌드·기기 차례를 기다려 13:49:34 idle을 확인했다.
그 뒤 guard를 다시 확인하고 병합된 clean 트리에서 전체 검사를 600초 제한으로 한 번 실행했다.

```sh
~/.heoturu-agents/busy.sh && python3 ~/.heoturu-agents/verify.py --log-dir .utmp/pr-publish/main-247-verify
```

```text
pytest skip: 45 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=11 failed=0
```

pytest **2048 passed, 46 skipped, 3 warnings**, 앱 **3058 PASS**다.
결과 파일 `.utmp/pr-publish/main-247-verify/verify-result.txt`와 실제 단계별 로그를 직접 대조했다.
실행 디렉터리는 `20261106T134940-2ba44f6f8fb6/`이며 이전 결과를 합산하지 않았다.
Docker deployment와 별도 S3 endpoint 검사는 skip이며, 실기기·운영 확인은 범위 밖이다.
최종 기록 커밋은 문서만 변경하며 제품·테스트는 이 PASS 기준과 같다.
사용자 승인에 따라 push·PR을 진행하고, PR 이미지 첨부와 병합은 사용자가 한다.
