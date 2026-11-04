# 홈 흰 패널 하단 배경 연결 (#232)

2026-11-04, 시작 `8202d4f`에서 팀 피드백 시트 37·48의 같은 홈 하단 배경 문제를
한 이슈로 수정했다. 구현 `0434c31`, CHANGELOG `3a43897`이다.
사용자 결정은 "37·48은 이슈 만들어도 되고", 40분 중단 뒤 재개 결정은
"232 계속 진행하라고 해줘"다. 두 제보의 공통 원인을 수정했으며 시트 자체는 변경하지 않았다.
2026-11-04 사용자 "PR 승인"으로 화면 판정과 PR 초안 승인을 받았다.
승인 범위는 main 병합·전체 재검증·push·PR 생성이며, PR 병합·배포는 포함하지 않는다.

## 구현과 검수

- 홈 세로 스크롤을 `CustomScrollView`로 바꾸고 hero 다음 패널의 최소 높이를
  `max(0, viewportMainAxisExtent - precedingScrollExtent)`로 정했다.
  실제 hero 높이를 사용하며 긴 콘텐츠는 자연 높이대로 스크롤한다.
- 패널 밖 하단 16px를 제거했다. 패널 내부 하단 32px, 위쪽 반경 16px,
  상단 회색·노랑 영역, 카드·칩 및 하단 탭의 배치·안전 영역 처리는 유지했다.
- 측정 fixture, 홈 미리보기, 알림 복귀 테스트의 helper 3곳은 스크롤 타입 탐색을
  기존 `home-scroll` 키 탐색으로 적응했다. 기존 기대값·이름·docstring은 바꾸지 않았다.
- 단일 이슈이므로 `8202d4f..0434c31`의 티켓 검수가 최종 리뷰를 겸했다.
  Standards·Spec 모두 높음/중간/낮음 0건이다. 촬영 준비 파일도 검수 범위에 포함했다.
  상태 전환·화면 높이 변경을 확인한 검수자 probe 1건도 통과했다.
- 검수 전 `git fetch origin` 후 `git merge-tree --write-tree origin/main HEAD`가 exit0으로
  끝났다(tree `7d4a871fa9c25a36632004c425b643e520e7ea0d`). 당시 merge-base는 `8202d4f`였다.
  merge·rebase는 하지 않았다. 이는 22:06 KST의 충돌 확인 결과다.

## 자동 검증

부분 검사 명령은 `frontend/`에서 `busy.sh --wait` 대기 뒤 `busy.sh && 명령`으로 실행했다.
로그는 `.utmp/ticket-232/partial-*.log`이며 첫 줄에 명령을 남겼다.

| 검사 | 결과 | 로그 |
| --- | --- | --- |
| 신규 `home_panel_background_test.dart`, 수정 전 | saved/empty/short 3건 기대한 FAIL | `partial-background-red.log` |
| 같은 회귀, 마지막 내용 접근 단언 강화 후 | 67 PASS | `partial-background-strengthened.log` |
| `home_alignment_test.dart` | 111 PASS | `partial-home-alignment.log` |
| `home_base_alignment_test.dart`, helper 적응 후 | 18 PASS | `partial-home-base-alignment-adapted.log` |
| `navigation_figma_test.dart` | 20 PASS | `partial-navigation-figma.log` |
| `scaled_navigation_layout_test.dart` | 18 PASS | `partial-scaled-navigation-layout.log` |
| `notification_navigation_test.dart test/weekly_root_test.dart` | 17 PASS | `partial-home-scroll-consumers.log` |
| `flutter analyze --no-pub` | No issues found | `partial-flutter-analyze.log` |

신규 67건은 최초 재현 3건과 64개 조합이다. 저장 4개/0개/1개/칩 빈 결과(40자 카테고리),
weekly 0/2개, 화면 375×640/393×1200, 글자 배율 1.0/1.3, 하단 inset 0/34를 조합했다.
각 조합에서 처음과 끝의 패널 경계·흰 배경·윗모서리·마지막 실제 내용을 확인했다.
긴 화면 32개 조합은 `maxScrollExtent=0`도 확인했다. 실제 Pretendard를 사용했다.

검수 반영 단계에서 제품 변경 없이 `0434c31`을 대상으로 아래 전체 검증을 **한 번** 실행했다.
저장소 루트, 셸 제한 600초, 22:10 시작·22:17 종료(exit0)다.

```sh
~/.heoturu-agents/busy.sh && python3 ~/.heoturu-agents/verify.py --log-dir .utmp/ticket-232
```

서버 ruff·compileall·일반/maintenance DB upgrade/check·pytest와 앱 pub-get·analyze·test,
10단계 모두 통과했다. 실제 로그 요약은 다음과 같다.

```text
pytest: 2047 passed, 46 skipped, 3 warnings in 198.91s (0:03:18)
pytest skip: 45 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
Flutter: 2254 tests passed
VERIFY result=PASS scope=all checks=10 failed=0
```

`verify-result.txt`, `verify-console.log`, `backend-pytest.log`, `app-test.log`를 감독이 직접 대조했다.
skip은 통과에 포함하지 않는다. Docker 복구와 로컬 S3 통합 46건은 이 실행에서 미검증이다.
이 검사 이후 main 병합 전까지는 문서만 변경해 전체 검사를 반복하지 않았다.
main 병합 후 재검증은 다음 절에 별도로 기록한다.

## 전체 검사(최종)

사용자 승인 뒤 `git fetch origin`으로 main의 #234(`#231`, `800aa81`)를 확인하고
아래 명령으로 병합했다. 병합 커밋은 `397aa5d4b79df83b7d09b6e95bffd15444bdae30`이며 충돌은 없었다.

```sh
git merge origin/main -m "merge: main의 #231 반영 (#232)"
```

`busy.sh --wait`로 다른 작업 종료를 기다린 뒤, 저장소 루트에서 셸 제한 600초로
아래 전체 검사를 다시 실행했다. 2026-11-04 22:46:42 시작·22:51:56 종료(KST), exit0이다.

```sh
~/.heoturu-agents/busy.sh && python3 ~/.heoturu-agents/verify.py --log-dir .utmp/ticket-232/final
```

```text
pytest: 2047 passed, 46 skipped, 3 warnings in 166.60s (0:02:46)
pytest skip: 45 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
Flutter: 2407 tests passed
VERIFY result=PASS scope=all checks=10 failed=0
```

감독이 `final/verify-result.txt`, `final/backend-pytest.log`, `final/app-test.log`를
직접 대조했다. Docker 복구·로컬 S3 통합 46건은 실행 조건 미충족으로 미검증이다.
추가로 `frontend/`에서 `dart format --output=none --set-exit-if-changed lib test`를 실행해
282개 파일, 변경 0개를 확인했다(`final/dart-format.log`). 이후 변경은 승인 상태·검증 이력 문서뿐이다.

## 변경 전·후 화면

변경 전 양 플랫폼 촬영은 제품 수정 전에 `8202d4f`로 완료했다.
변경 후 촬영은 제품 커밋 `0434c31` 기준이다. main 병합 후 다시 촬영하지 않았으며,
병합으로 들어온 #231의 weekly 문구·이름 색 변경은 이 촬영본에 반영되지 않았다.
병합 후 자동 검증과 병합 전 화면 검증을 구분한다.
조율 위임에 따라 감독이 완료 조건에서 대표 상태를 골라 `.utmp/ticket-232-summary.md`에
상태 ID·재현 방법·선정 기준을 먼저 기록했다. 상태별 처음/끝, 플랫폼당 10행을 촬영했다.
weekly가 패널 자연 높이를 늘리는 경우와 남은 높이를 채워야 하는 짧은 경우,
C01/C02 상단 차이, 칩 빈 결과, 배율 상한을 나누고 나머지 조합은 위 자동 회귀로 보완했다.

| 데이터 ID | 재현 조건 | 배율 | 확인 |
| --- | --- | --- | --- |
| `normalweekly` | 저장 4개, weekly 2개, 전체 칩 | 1.0 | 상단 보존·패널 끝 |
| `emptyweekly` | 저장 0개, weekly 2개 | 1.0 | C02 상단·빈 상태·마지막 내용 |
| `short` | 저장 1개, weekly 0개 | 1.0 | 남은 높이 채움·스크롤 불필요 |
| `empty` | 저장 0개, weekly 0개 | 1.3 | 빈 상태 확대 글자·아래 빈 면적 |
| `chip` | 저장 4개에서 미분류 칩을 눌러 결과 0개, weekly 0개 | 1.3 | 칩 유지·빈 결과·패널 끝 |

각 ID에 `-top`/`-bottom`을 붙인다. 모든 기기 증거는 실제 루트 앱과 로컬 메모리 API의 결과다.
스크롤 불필요 상태는 처음/끝이 같은 화면이며 `maxScrollExtent=0`을 기록했다.

| 플랫폼 | 기기·OS | 논리 크기 | OS 안전 영역 위/아래 | 실제 스크롤 영상 배율 |
| --- | --- | --- | --- | --- |
| iOS | iPhone 16 / iOS 18.6 Simulator | 393×852 | 59/34 | 1.0 |
| Android | Medium_Phone / Android 16, API 36 | 411.4286×914.2857 | 24/24 | 1.3 |

Android는 긴 화면에서 배율 1.0의 대표 상태 모두 스크롤이 없어 실제 스크롤 영상만 1.3으로 찍었다.
변경 전·후 같은 조건이다. 첫 설치 직후 Android의 일시적인 안전 영역 레이아웃은 비교에서 제외하고,
양쪽 모두 `/scenario` 재진입 후 안정된 동일 조건의 원본과 JSON을 최종 증거로 사용했다.

| 데이터 | iOS 끝의 틈: 전 → 후 | Android 끝의 틈: 전 → 후 |
| --- | --- | --- |
| normalweekly | 16 → 0 | 38.2857 → 0 |
| emptyweekly | 16 → 0 | 66.2857 → 0 |
| short | 135 → 0 | 242.2857 → 0 |
| empty | 19.4 → 0 | 126.6857 → 0 |
| chip | 71.4 → 0 | 178.6857 → 0 |

단위는 논리 px이며 패널 바닥과 하단 탭 윗면 좌표 차이다. 처음 위치에서도 양수의 노출 틈이 없다.
iOS 짧은/빈/칩 상태 및 Android 정적 10행은 수정 후에도 스크롤이 불필요했다.

촬영 진입점은 빌드 전 5개 상태 경로 테스트를 통과했다. 변경 후에는 스크롤 탐색만
`home-scroll` 키로 적응하고 다시 5건 통과를 확인했다. 빌드/설치본 대조 근거:

- iOS kernel hash prefix: 전 `afd36d474d40`, 후 `eed2a1f7fcaf`.
- Android APK SHA-256 prefix: 전 `e9ab1a1910fc`, 후 `2dee4aee5093`.
- 양쪽 설치본이 각각의 빌드와 일치했다. Android 빌드마다 Gradle 데몬 종료를 확인했다.
- 시뮬레이터/에뮬레이터·빌드·검사는 순차 실행했고, 마지막에는 기기와 helper를 종료했다.

## Figma·동작·비교 증거

2026-11-04 21:46 KST, 파일 `svNWsTFh8Ws1Mpt8XQIcrN`의 C01 `111:3584` 전체 이미지,
패널 `111:3587`의 design context와 이미지, C02 `111:3681`의 context와 이미지를 직접 조회했다.
C01 전체 context는 시간 초과여서 패널 context와 전체 screenshot으로 확인했다.
C01은 375×936, C02는 375×956이고 패널은 흰색·위쪽 반경 16px로 프레임 바닥까지 이어진다.
기기의 크기·안전 영역 차이는 비교 이미지에 표시했으며 원본을 보정하지 않았다.
동적 데이터·weekly 문구·기존 폰트 차이는 이번 배경 수정 범위 밖이고 전체 Figma 일치를 주장하지 않는다.

- 양 플랫폼에서 실제 Orca 스크롤 입력 후 끝 도달, 카드 가로 이동, 아카이브 탭 진입/홈 복귀,
  추가 버튼으로 `콘텐츠 저장하기`·`링크 첨부`·`사진 첨부` 표시를 확인했다.
  칩 빈 결과는 앱 포인터 입력으로 실제 칩을 눌러 만들고 categoryId=99와 빈 위젯을 단언했다.
- Android 카드 가로 이동은 첫 카드 x범위 149..931 → 48..322, 다음 카드 952..1032 → 343..1032로
  실제 화면 이동을 확인했다. iOS는 가로 이동 후 다른 카드 제목과 화면 경계를 확인했다.
- 조건이 같은 3열 비교는 **iOS 8행, Android 10행**이다. iOS `normalweekly-bottom`은
  offset 85 → 69, `emptyweekly-bottom`은 57 → 41로 외부 16px 제거에 따라 끝 위치가 달라졌다.
  두 행은 동일 offset 3열 비교를 만들지 않았고 각 끝의 원본·JSON과 차이를 보존했다.
- 대표 화면 접촉 시트와 iOS 끝 원본을 감독이 직접 확인했다. 상단·카드·탭 배치를 유지하면서
  아래 회색 면적이 흰색으로 채워졌다. 2026-11-04 사용자 "PR 승인"으로 화면 판정을 승인받았다.
- 비교 영상은 `compare_video.py`로 생성했다. 마지막 프레임의 원본 대조도 통과했다.
  도구 칸별 차이(허용20)는 iOS 전13.3/후13.9, Android 전16.3/후18.6이다.
  1초별 장면과 마지막 프레임 미리보기를 직접 확인했다. 영상 길이를 반응시간 근거로 사용하지 않는다.

로컬 증거는 `.utmp/ticket-232/`에 보관한다. 저장소에는 이미지·APK·기기 데이터를 커밋하지 않는다.

| 증거 | 경로 |
| --- | --- |
| 원본 상태 이미지·JSON | `screens/{ios,android}-{before,after}-{데이터}-{top,bottom}.{png,json}` |
| 원본 스크롤 영상·시각 기록 | `screens/{ios,android}-{before,after}-scroll-video.{mp4,json}` |
| 3열 비교·미리보기·조건 대조 | `comparisons/{ios,android}-*.png`, `{ios,android}-audit.json` |
| 비교 영상·장면 미리보기 | `comparisons/compare-{ios,android}.mp4`, `comparisons/compare-{ios,android}-preview.png` |
| 실제 동작 확인 | `{ios,android}-after-native-smoke.json`, `*-after-ax.json` |
| Figma 원본/context | `figma/` |
| 검수 | `.utmp/review-232.md`, `.utmp/review-232-probes/transitions.log` |

## 한계와 현재 상태

- iOS 끝 2행의 동일 offset 3열 비교는 위 이유로 미확보다. 각 끝 상태의 촬영·마지막 내용 접근 검증은 했다.
- 사용자 화면 판정·PR 초안 승인을 받았다. #232는 PR 병합 시 닫도록 `Closes #232`를 사용한다.
- 원격 CI는 push·PR 생성 후 별도로 확인한다. 로컬 자동/메모리 API 실행을 원격 CI·실기기·운영 검증으로 대신하지 않는다. 실기기·운영 실행은 미검증이다.
- 승인에 따라 push·PR을 생성하며, PR의 이미지 자리는 사용자가 직접 첨부한다. PR 병합·배포는 승인 범위 밖이다.
