# 작은 UI 묶음 최종 검증·화면 비교 (#237·#242·#241·#240)

후속: 사용자 화면 피드백에 따른 #242 새 간격과 최신 전체 검증은
[8색 간격 재배치 이력](2026-11-06-category-palette-spacing.md)에 있다. 아래는 최초 비교 당시 기록이다.

2026-11-06 기록. 구현 시작은 `6c9c668`, 최종 제품·테스트 기준은
`5a5725ebd014db73179be3a684c41f382cbd3427`이다. main의 #235·#239를 합친
`52f9eed` 뒤 최종 리뷰 반영과 전체 검증을 완료했다. 화면 비교까지 작성했으며
사용자 시각 판정·PR 본문 승인·push·PR 생성은 아직 하지 않았다.

## 구현·리뷰

| 이슈 | 제품 커밋 | 티켓 종료 기록 | 결과 |
| --- | --- | --- | --- |
| #237 | `6ef1a36` | `9d56952` | 빈 아카이브 안내·저장 성공 문구, 리뷰 두 축 0건 |
| #242 | `eea30c4` | `1a6b45b` | 무지개 전용 위젯·자산 제거, 리뷰 두 축 0건 |
| #241 | `1bde963`, `6b42319`, `4feac6d` | `12a2c8c` | 원본 통합·검색 배치 S1/S2 보완, r3 두 축 0건 |
| #240 | `dff377a` | `482d274` | 빈 별 x=14.25 통일·채운 별 위1.25px, 리뷰 두 축 0건 |

main 충돌 사용자 승인(2026-11-06, 원문): "응".
`assets.dart`는 #239 알림 설정 그림 제거와 #241 빈 그림 통합을,
`saved_content_confirmation_test.dart`는 #235와 #237 테스트를 모두 보존했다.
최종 검수는 Standards 0건·Spec 높음 1건(사진 callback의 submissionKey 누락)이었다.
`a282ff0`으로 세 callback을 수정했고, 첫 전체 검사에서 드러난 성공 버튼 finder
연결을 `5a5725e`로 수정했다. 감독이 diff·실제 로그를 대조했다.
최종 리뷰는 `.utmp/review-small-ui-batch-1-final.md`, 해결 판단은
`.utmp/final-review-resolution.md`에 있다.

## 사용자 결정과 승인 예외

- #237 본문은 `아래 + 버튼에서 링크나 스크린샷을 추가해 보세요.`, 성공 버튼은
  `저장 완료`다. 요청 대기의 비활성 `닫기`는 유지한다.
- #242 무지개를 숨기되 기존 8색의 왼쪽 정렬·8px 간격·크기·순서·한 줄 스크롤을
  유지한다. 팔레트 밖 기존 색도 이름만 수정할 때 보존한다.
- #240 빈 별은 E01 x=14.25를 공통 기준으로 쓴다. C01/J01의 차이는 승인 예외이며,
  채운 별은 16배 래스터의 50% 알파 경계 상자 중심을 비교해 위1.25px 보정했다.

#241 사용자 결정(2026-11-05, 원문): "오케이 가로 진행해줘".

승인된 추천(원문): "가: 캐릭터 높이, 위치, 아래 문구와의 간격을 지금과 똑같이 유지합니다. 폭만 좌우로 1px씩(총 약 2px) 넓어집니다. 그림 가장자리의 아주 흐린 외곽선이 칸 아래로 3px 정도 나가는데, 자르지 않고 그대로 보이게 하는 것을 추천합니다."

검색 본체 top2·높이119·수평중심40.5·문구 간격18을 유지하고 폭75→76.88477을
허용했다. 외부 슬롯81×123과 원본 비율·바이트를 유지하며 흐린 외곽은 자르지 않는다.
S2에서 짧은 viewport의 위0.040466px도 보이도록 상단 viewport와 content inset을
같이 보완했다. 승인 원본1018×1545의 SHA-256은
`1485e2db480560b2cdcbf2529896e8b9a42300e769c16963c152782b91eca542`다.

## 최종 전체 검증

작업 트리에서 공용 busy 대기 후 셸 제한600초로 실행했다.

```sh
~/.heoturu-agents/busy.sh && python3 ~/.heoturu-agents/verify.py --log-dir .utmp/small-ui-batch-1-final-verify/retry-1
```

```text
pytest skip: 45 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=11 failed=0
```

실제 결과는 pytest **2048 passed, 46 skipped, 3 warnings**, 앱 **2986 PASS**다.
ruff·compileall·마이그레이션·alembic check·pytest 및 앱 pub get·format·analyze·test가
공용 검증 범위다. skip은 통과에 포함하지 않았다.
결과 원문은 `.utmp/small-ui-batch-1-final-verify/retry-1/verify-result.txt`,
단계 로그는 같은 폴더의 `20261106T010309-4b663512be7b/`에 있다.
시작·종료 progress의 SHA는 모두 `5a5725e`, dirty=false다. 전체 실행은 약6분48초였다.
최초 실패 로그 `20261106T005236-979605ce28cb/`는 상위 폴더에 별도 보존했고 합산하지 않았다.
후속 변경은 문서뿐이므로 제품·테스트 동일성을 확인하고 전체 검사를 반복하지 않았다.

## 양 플랫폼 화면 확인

| 플랫폼 | 기기·OS | 논리 크기·DPR | 실제 OS 안전 영역 위/아래 |
| --- | --- | --- | --- |
| iOS | iPhone 16, iOS 18.6 Simulator | 393×852, 3 | 59/34 |
| Android | Medium_Phone, Android 16 API36 Emulator | 411.42857×914.28571, 2.625 | 24/24 |

`6c9c668` 임시 워크트리와 `5a5725e`에서 같은 촬영 하네스를 빌드했다.
사전 검사 전후 각3건을 통과했고, 앱 설치본의 kernel/APK를 대조했다.
하네스·manifest·build/run 로그·원본·해시는 `.utmp/batch-capture/`에 보존했다.
Android APK SHA는 전 `c7097e2b28811727b207e5dcae7a8af38eba646d88ce01116948a84428ecdc7d`,
후 `8fb9a657565948b17d92b00b5173eb66b164680c6329f0b8a40e39e9a0f1f745`다.
임시 워크트리는 원본 하네스·빌드 산출물 보존 후 제거했다.

변경 상태 중심의 아래18개를 양 플랫폼에서 전후 1.0/1.3배로 촬영했다.
배율은 앱 MediaQuery 글자 배율이며 OS 전체 글자 크기 변경이 아니다.

| 묶음 | 실제 촬영 상태 |
| --- | --- |
| 홈·탭 | home-empty, archive-empty, bookmark-empty, nav-my |
| 빈 그림 | notification-empty, home-filtered, home-long(40자), home-unclassified, unclassified-empty |
| 저장 성공 | save-link, save-photo, save-summary(summaryStatus=processing) |
| 색상 | palette-create, palette-selected, palette-edit, palette-outside |
| 검색 | search-empty, search-keyboard |

원본 PNG144장·대응 probe144개, 비교 이미지 플랫폼별18개,
일반 왕복·빠른 탭의 전후 영상 플랫폼별4개(비교 영상 총4개)를 확보했다.
`capture-inventory.json`은 각 원본의 SHA를 보존한다.
`compare.py`로 기종·데이터·배율·OS/app insets·스크롤·입력 문자열/selection/focus/출처를
검사했고 36개 비교 상태가 통과했다. 원본 화면이나 probe 값을 맞춰 보정하지 않았다.
입력 원본과 주요 비교 이미지에서 키보드·버튼·OS 메뉴 유무·그림 경계를 감독이 확인했다.
`compare_video.py`의 마지막 프레임 대조도 통과했고 실제 홈 복귀를 확인했다.
빠른 탭은 pointer 기록의 실제 간격이며 100ms 탭이나 모든 중간 프레임 관찰을 뜻하지 않는다.

변경 후 양 플랫폼에서 저장3종의 `저장 완료` 탭 뒤 홈 복귀와 saveCalls=1 유지를
확인했다. 검색의 전체 리스트 보기·아카이브 홈으로 가기·중앙 + 이동도 native 경로로
확인했다. 입력은 native 타이핑이며 controller 선입력이 아니다.
생성/검색 원본의 키보드와 대상 버튼이 보이고 OS 편집 메뉴는 없었다.
Android 수정/선택의 키보드 유지와 iOS 키보드 숨김은 각 플랫폼 내 전후 일치시켰다.

## 비교 자료와 해석 범위

로컬 갤러리는 `.utmp/batch-capture/comparison-index.md`다.
대표 비교는 `compare-{ios,android}-{archive-empty,save-link,palette-create,search-keyboard,bookmark-empty}.png`,
영상은 `compare-{ios,android}-{nav,nav-rapid}.mp4`이며 원본은 `screens/`에 있다.
미디어는 저장소에 추가하지 않았으며 PR 첨부는 승인 뒤 진행한다.

Figma 파일 `svNWsTFh8Ws1Mpt8XQIcrN`의 조회시점·노드는 `figma/manifest.json`에 있다.
홈111:3681, 검색111:4043, 즐겨찾기111:4103, 미분류142:5097, 알림125:4173,
생성111:4287, 선택111:4376, 수정111:4427, 링크111:4902, 사진111:4865,
마이111:4707을 사용했다. 아카이브122:3566은 **문구 참고 와이어프레임**으로,
완성 디자인이 없는 자리를 새 디자인으로 채우지 않았다.

- Figma375px 프레임과 기기 크기·safe area·영문/한글 키보드·입력값·홈 데이터는 다르다.
  검색 키보드 전용 Figma는 없어 동일 빈 검색 원본을 기준으로 표시했다.
  팔레트 밖 색 수정도 전용 원본이 없어 기존 수정 화면을 참고로 썼다.
  승인 문구·무지개 숨김·검색 폭·별 위치 예외를 제외한 전체 화면 일치를 주장하지 않는다.
- 실제 ClipbackApp와 로컬 HomeBaseServer를 사용했다. 저장은 실제 AddContentSheet와
  메모리 callback, 사진 선택은 고정 PNG bytes 대역이다. OS 사진 선택기·운영 저장은 확인하지 않았다.
  알림은 실제 NotificationListScreen의 빈 목록 격리 fixture로, 운영 알림 경로 확인은 아니다.
- 사진 전후 입력 bytes는 같지만 main #235의 원본 사용·상단 정렬로 보이는 부분이 다르다.
  마이 메뉴 차이는 main #239다. 이 차이를 이번 네 이슈의 효과로 세지 않는다.
- 변경하지 않은 요청대기·fallback·오류 상태는 자동 회귀로 구분하고 추가 촬영하지 않았다.
  320px 좁은 viewport는 자동 테스트 근거이며 이번 기기 화면으로 대신하지 않는다.
- iOS Device Hub 입력 점유 복구와 Android IME 애니메이션 중 probe 불일치,
  마지막 홈 paint 전 영상 종료 때문에 일부를 재촬영했다. 실패 원본/로그는 각각
  `invalid-*`, `search-hub-first-attempt`, `nav-first-stop`에 보존하고 최종본과 구분했다.
- 감독-작은UI묶음 기기 잠금을 플랫폼별로 잡았고 촬영 종료 후 기기를 끄고 반납했다.
  사용자 시각 판정은 대기 중이다. 실기기·운영·원격 CI는 이번 검증 범위 밖이다.

## 후속

사용자에게 비교 화면과 PR 초안을 전달한 상태에서 멈춘다. push·PR 생성·이슈 종료는
진행하지 않았다. 회고 필요: 예. 검색 비율 결정/S2 보완, main 병합 계약 연결 누락,
기기 차례·입력 도구 복구·재촬영을 다음 작업 전에 정리할 필요가 있다.
