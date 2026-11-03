# 목록 전체 개수와 서버 정렬 최종 검증 (#224)

## 범위와 리뷰

- #225 개수 표시 구현 `c424347`, 검증 이력 `ff62c56`.
- #223 main 반영 `4c3044a`, #226 서버 정렬 구현 `3561ebb`, 검증 이력 `38f5d0d`.
- 시작 화면 기준은 main #222를 반영한 `ac43414`다.
- 각 티켓 리뷰와 최종 리뷰 모두 Standards·Spec의 높음/중간/낮음 지적이 0건이다.
  최종 리뷰는 `b70e392..38f5d0d`의 기능 전체와 촬영 준비 파일을 포함했다.
- 최종 리뷰 전 `git fetch origin` 후 `git merge-tree --write-tree origin/main HEAD`가 exit 0이었다.
  `HEAD..origin/main`은 비어 있었고 추가 main 병합은 필요하지 않았다.
- 티켓별 부분 검사·실패/수정·이전 전체 검사는 [개수 표시](2026-11-03-feed-total-count.md)와
  [서버 정렬](2026-11-03-feed-server-sort.md)에 보존한다. 실행 수를 합산하지 않는다.

## 전체 검사 (최종)

2026-11-03 22:40 KST busy 대기 완료 후 저장소 루트에서 실행했다.
검증 기준은 `38f5d0ddddb2d8a202d98a8ef00c3ed015993260`이며 제품 코드·테스트는 `3561ebb`와 같다.
최종 리뷰의 확정 지적이 없어 제품 변경 없이 실행했고, Python subprocess timeout은 600초였다.

```sh
~/.heoturu-agents/busy.sh && python3 ~/.heoturu-agents/verify.py --log-dir .utmp/ticket-226/final
```

- ruff·compileall, 일반/maintenance 테스트 DB의 migration·alembic check, 앱 pub-get·analyze 통과.
- 서버: `2047 passed, 46 skipped, 3 warnings in 171.65s (0:02:51)`.
- 앱: `01:59 +2187: All tests passed!`.
- 결과와 단계별 원본: `.utmp/ticket-226/final/verify-result.txt`, `backend-*.log`, `app-*.log`.
- 검사 자체의 exit 0과 결과 파일을 직접 대조했다. 아래 skip은 성공한 검사 수에 포함하지 않는다.

```text
pytest skip: 45 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=10 failed=0 logs=/Users/leehyeongyu/orca/workspaces/Clipback/feed-total-count/.utmp/ticket-226/final
```

Docker/operator-recovery와 S3 합성 CLI는 실행 조건이 없어 로컬 미검증이다. 원격 CI는 push하지 않아
미실행이다. 운영 API·설치된 옛 앱·실기기·실제 계정 규모 성능은 별도 사용자 확인 범위다.

## 촬영 준비 검사

최종 리뷰에서 보존 시작 서버 파일 111개와 ac43414의 바이트 일치, 변경 전 PNG/JSON 38쌍의 조건을
확인했다(주요 15상태×2플랫폼과 보조 화면 포함). after 첫 요청부터 total_count가 전달되도록
진입 파일을 설정했다. 변경 전 원본과 빌드 산출물은 보존했다.

빌드 전 `flutter test --no-pub --dart-define=PHASE=after ../.utmp/ticket-224/state_preview_check_test.dart`
1개 통과, exit 0. `.utmp/ticket-224/preview-check-after-final.log`.
실제 스크롤 동작은 Orca로 확인하고, 비교용 소수 offset은 촬영 전용 제어로 기존 기록에 맞춘다.
원본 이미지 픽셀을 보정하지 않는다. 자동 테스트와 아래 OS 실행 증거는 별도다.

## iOS·Android 최종 화면 검증

2026-11-03 22:46에 시작해 23:00에 촬영을 마쳤고, 23:01 busy idle을 확인했다.
15상태 × 3분 + 전체 검사 약 5분의 50분 예산 안에 완료했다. iOS 촬영을 끝낸 뒤 Android를 촬영했다.
주요 상태 15개씩과 보조 스크롤·상세 화면 4개씩, 총 38쌍을 변경 전과 대조했다.
`audit_capture.py`는 필요한 파일·기대 문구·조건·원본 영상·실제 옛 서버 요청을 검사해 PASS였다.

| 플랫폼 | 기기·OS | 논리 화면 | OS 안전 영역 위/아래 | 글자 배율 |
| --- | --- | --- | --- | --- |
| iOS | iPhone 16 / iOS 18.6 Simulator | 393 × 852 | 59 / 34 | 1.0 |
| Android | Medium_Phone / Android 16, API 36 | 411.428571 × 914.285714 | 24 / 24 | 1.0 |

설치본의 kernel/APK 해시를 빌드와 대조한 뒤 실행했다.
iOS after kernel 접두 `3461d8457c0e`(before `dba54b19d551`), Android after SHA256 접두
`4c7da3363558`(before `b99b840d4e57`)로 변경 전·후가 다르다. iOS·Android debug 빌드 모두 통과했고
Android Gradle daemon도 종료했다. Android JDK는 로컬 Android Studio의 jbr을 사용했다.

| 상태 ID | iOS·Android에서 확인한 결과 |
| --- | --- |
| detail-home | `2 / 25` |
| detail-boundary | `20 / 25`에서 `21 / 25`로 이동, 분모 유지. 영상 확보 |
| detail-search | 검색어 `저장`, `1 / 25` |
| detail-category | 일상 `1 / 10` |
| detail-today | `1 / 5` |
| archive-all | 최신순 `총 25개`, 스크롤 뒤 유지 |
| category | 일상 `총 10개` |
| bookmark | `총 7개` |
| list-error | 실제 로컬 서버 종료 후 `총 -개`와 기존 실패 안내·다시 시도 |
| delete-after | 21번째 상세 삭제 후 목록으로 복귀, `총 24개`. 영상 확보 |
| old-server | 실제 시작 커밋 서버에서 `총 -개`, 상세 `2 / -` |
| archive-favorites-first | `총 25개`, 즐겨찾기 먼저·그 뒤 최신순. 스크롤 뒤 개수 유지 |
| category-favorites-first | 일상 `총 10개`, 즐겨찾기 먼저 |
| unclassified-detail | 툴바 없음, 미분류 `1 / 15` |
| old-server-sort | 실제 옛 서버는 sort를 무시해 01·02·03 최신순, `총 -개`, 앱 동작 유지 |

Orca AX로 문구·항목을 찾고 실제 탭·스크롤로 이동했다. 페이지 이동은 매번 위치 증가를 확인한 뒤
다음 입력을 보냈다. 한글 검색 입력은 촬영 진입 파일의 입력 경로를 사용했으며 네이티브 한글
키보드 입력 검증으로 주장하지 않는다. 검색 뒤 키보드를 닫고 같은 화면 조건으로 촬영했다.
개수 글자 크기·위치를 바꾸지 않았으며 새 안전 영역·정렬 버튼 겹침을 관찰하지 못했다.
네 자리/모름과 1.0·1.15·1.3배 경계는 티켓 자동 테스트 근거이며 기기 촬영 배율은 1.0이다.

### 자료와 비교 조건

- 원본: `.utmp/ticket-224/screens/{ios,android}-{before,after}-상태.{png,json}`.
- 모든 쌍에서 데이터 normal, textScale, viewPadding, logicalSize가 같고 scrollOffset 차이는 0.01 미만이다.
  ready=true, unexpected=[]를 확인했다. 결과는 `.utmp/ticket-224/capture-audit.json`.
- 비교 이미지: `.utmp/ticket-224/comparisons/{ios,android}-상태.png` 및 overview.png.
  공용 compare.py를 사용했다. 전체 링크 목록은 `.utmp/ticket-224/screen-report.md`.
- 비교 영상: 같은 폴더 `{ios,android}-{detail-boundary,delete-after}.mp4`.
  before/after 원본 8개 모두 ffprobe 통과, 합성 4개 모두 끝 프레임 검사 통과.
  1초 간격·전환·마지막 장면 미리보기를 감독이 직접 확인했다. 서로 다른 입력 시점의 영상이며 성능 비교가 아니다.
- Figma 파일 `svNWsTFh8Ws1Mpt8XQIcrN`, 조회 2026-11-03 21:13 KST.
  F02 111:3842, E01 111:4117, F01 111:3968, I01 111:4091, E06 111:4525.
  E01 원본 프레임 375×1102 / 받은 PNG 349×1024, F01 375×1396 / PNG 276×1024다.
  F02 PNG는 375×890, E06은 375×812다. OS 화면의 크기·안전 영역과 다르며 원본을 보정하지 않았다.
- 이슈가 지정한 E06은 미분류 목록 기준이고, 촬영 행 unclassified-detail은 그 목록에서 연 상세다.
  E06을 상세 화면 전체의 일대일 일치 근거로 쓰지 않는다. 상세 구조는 기존 F02 계열을 유지한다.
  old-server·list-error는 사용자 결정대로 Figma 원본이 없어 변경 전·후만 비교했다.
- 합성 콘텐츠와 Figma 예시 콘텐츠는 다르다. iOS Dynamic Island 표시 및 OS 시각 차이도 원본 그대로다.
  이번 비교는 요청한 개수·정렬 변화 확인이며 전체 화면의 픽셀 일치를 주장하지 않는다.

### 로컬 서버 증거와 한계

정상 상태는 합성 콘텐츠25개(일상10/미분류15, 즐겨찾기7)의 메모리 HTTP 대역이다.
old-server·old-server-sort는 시작 커밋 ac43414의 보존 서버와 로컬 PostgreSQL을 썼다.
앱 재시작마다 local=true 제어 응답을 저장하고, 서버 access log에서 실제 feed 및
`sort=favorites_first` 요청의 200 응답을 확인했다. 서버 응답은 items/next_cursor만 있고 total_count가 없다.
관련 파일은 `local-backend-after.log`, `local-backend-after-android.log`, `screens/*-control.json`이다.

인증은 합성 사용자로 대체하고 DB는 create_all로 준비했으므로 운영 인증·migration 증거가 아니다.
list-error는 서버를 종료했지만 촬영 어댑터가 연결 예외를503으로 바꾸므로 원시 전송 예외 검증은 아니다.
서버·기기 모두 종료했으며 실제 계정·운영 서버·실기기에 접근하지 않았다.

### 촬영 중 보완

- iOS 삭제 비교 영상의 시작 상태가 달라 변경 전처럼 메뉴를 연 상태부터 다시 촬영했다.
  최종 비교에서는 시작 상태와 끝 장면을 다시 확인했다.
- iOS 빌드 중 감독이 추가한 이력 목차 한 줄을 빌드 키트가 부작용으로 간주해 되돌렸다.
  side-effect.diff로 확인한 뒤 빌드 종료 후 복구했다. 제품 파일의 빌드 부작용은 없었다.
- 기기 동작·문구 검증은 완료했지만 **사용자 시각 판정은 대기**다. #225·#226은 닫지 않았다.
