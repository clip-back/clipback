# 빈 화면 그림 고해상도 원본과 검색 배치 보존 (#241)

- 기록일: 2026-11-06 (KST).
- 이슈: [#241](https://github.com/clip-back/clipback/issues/241).
- 작업 디렉터리: `/Users/leehyeongyu/orca/workspaces/Clipback/small-ui-batch-1`.
- 제품·전체 검증 기준: `4feac6d2ac165e5c602325c40ea6d2d166e2b2c9`.
- 제품 커밋: `1bde963`(원본 통합/교체), `6b42319`(S1 본체 배치), `4feac6d`(S2 viewport 외곽).
- 최종 재검수: `.utmp/review-241-r3.md`, Standards 0건 / Spec 0건. S1·S2 해결을 확인한 뒤 추가 제품 변경 없이 전체 검증했다.

## 변경과 승인 범위

동일한1254×1254 상자 PNG 두 개를 하나로 통합하여 미분류·즐겨찾기·알림에서 공유한다.
각 화면의 크롭·그림자·표시 크기·버튼은 유지한다. 홈은 같은 원본에서 만든284×328 파생 PNG로
기존67×78 논리 영역·71×82 페인트 여백·흰 캔버스·그림자를 유지하며 충분한 픽셀을 공급한다.
중복 원본과 홈 파생 자산을 구분한다. 다른 캐릭터 fallback·상태 판단·문구·API는 변경하지 않았다.

검색 확정 결과0은 전달받은 Figma1018×1545 투명 PNG 원본을 바이트 그대로 사용한다.
SHA-256은 `1485e2db480560b2cdcbf2529896e8b9a42300e769c16963c152782b91eca542`다.
그림 생성·AI 확대·재채색·배경 제거·비균일 확대는 하지 않았다.
현재 자산 경로·체크섬·홈 재생성 절차는 [빈 상태 그림 자산](../frontend/empty-state-assets.md)을 따른다.

사용자 결정(2026-11-05, 문구 그대로): "오케이 가로 진행해줘".

승인된 조율 추천 문구: "가: 캐릭터 높이, 위치, 아래 문구와의 간격을 지금과 똑같이 유지합니다. 폭만 좌우로 1px씩(총 약 2px) 넓어집니다. 그림 가장자리의 아주 흐린 외곽선이 칸 아래로 3px 정도 나가는데, 자르지 않고 그대로 보이게 하는 것을 추천합니다."

이 결정은 기존 검색 그림의 정확 폭/전체 외곽 경계 보존에 대한 승인 예외다.
외부81×123·원본 비율·PNG 바이트·주변 문구/버튼 배치는 유지하며,
본체alpha>128의 top2·높이119·수평중심40.5·문구 간격18을 맞춘다.
폭은75에서76.884774로 넓어지고 좌우각약0.942px 증가한다.
내부 Image는 균일 배율119/1458로83.087791×126.100823이며 offset은(.751715,-.285322)다.
슬롯 Stack은 Clip.none이고 alpha>0 외곽의 슬롯 기준 경계는
약(.751715,-.040466)-(79.187243,125.815501)다.

## 리뷰 반영

첫 리뷰 `.utmp/review-241.md`의 S1은 원본 투명 여백 차이로 본체가 왼쪽/위로 이동하고
높이와 문구 간격이 달라진 문제였다. 슬롯과 해시 검사만으로는 이를 검출하지 못했다.
원본 본체 비율 차이 때문에 폭/높이를 동시에 정확 보존할 수 없어 분석 단계에서 멈추고 질문했다.
위 사용자 결정으로 기준이 확정된 뒤 균일 배율·offset을 적용하여 S1을 해결했다.
그 중단은 현재 미해결 사항이 아니며 현재는 승인된 폭 예외로 구현됐다.

r2의 S2는 짧은 viewport 최초 위치에서 상위 스크롤 hardEdge가 위쪽0.040466px 외곽을 자르는 문제였다.
실제 viewport 상단을59/1458px 확장하고 동일 content top inset으로 상쇄했다.
논리 viewport 높이는 그대로 사용하여 본체/문구/CTA 위치와 scroll 범위를 유지하며,
하단 경계와 Clip.hardEdge도 유지한다. 전체 스크롤 Clip.none으로 바꾸지 않았다.

첫 리뷰·r2·r3, 최초 RED/중간 실패/최종 PASS 로그와 경계 분석 JSON은 `.utmp/`에 보존했다.
연결 PNG를 디코딩한 native alpha bbox를 실제 rect/fit/alignment로 사상하여 본체/문구를 검사하고,
render 조상의 describeApproximatePaintClip을 통해 private viewport의 실제 경계도 확인한다.
callback 완료0과 FeedPage 확정0, iOS/Android·짧은 높이·배율1.3·키보드512px 축소가 같은 경로를 쓴다.
새12개 회귀는 최초 offset0을 단언하고 실제 drag(-40px) 뒤 offset>0에 진입한 다음
jumpTo(maxScrollExtent)에서 제한된 상하 clip과 CTA 노출을 확인한다.
이는 끝까지 전부 드래그했거나 실제 OS 키보드를 검증했다는 뜻은 아니다.

## 완료된 자동 검증

수정 전 연결 자산 디코딩 검사에서 홈71×82·검색81×123의 해상도 부족을 재현했다.
S1 RED5개는 실제 본체 위치 차이를, S2 RED12개는 실제 render clip과 외곽의 차이를 검출했다.
S1 fixture 키 오류 및 S2 중복 import info의 중간 실패도 로그에 남기고 수정했다.
최종 부분 검사 search_alignment/home_alignment/empty_asset_integrity172 PASS와 analyze가 통과했다.
미분류·즐겨찾기·알림2종·archive_all·category_archive·card_review·feed_pagination의
별도8파일206 PASS도 있으며 이후 S1/S2의 제품 수정은 검색 경계에 국한됐다.
부분 로그는 `.utmp/ticket-241/partial-*.log`다. 재실행 횟수를 통과 수에 중복 합산하지 않는다.

r3 통과 뒤 위 제품SHA의 clean 작업 트리에서 공용 전체 검증을 한 번 실행했다.
기존 전체 결과가 없는 것을 먼저 확인했고 기존 partial/리뷰를 덮어쓰지 않았다.
busy.sh --wait를 exec session으로 기다린 뒤 다음 명령을600초 셸 제한으로 실행했다.

```sh
bash "$HOME/.heoturu-agents/busy.sh" && python3 "$HOME/.heoturu-agents/verify.py" --log-dir .utmp/ticket-241
```

실제 `verify-result.txt` 원문:

```text
pytest skip: 45 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=11 failed=0 logs=/Users/leehyeongyu/orca/workspaces/Clipback/small-ui-batch-1/.utmp/ticket-241/20261106T000052-cba98e26ad1e
```

실제 백엔드 pytest 요약과 앱 전체 테스트 최종 줄:

```text
2047 passed, 46 skipped, 3 warnings in 170.03s (0:02:50)
02:25 +2918: All tests passed!
```

- 백엔드 ruff·compileall·검사 전용DB 두 개의 alembic upgrade/check·pytest 및 앱 pub get lockfile 검사·format·analyze·전체 테스트, 총11단계 PASS.
- 실행 콘솔: `.utmp/ticket-241/full-verify-console.log`.
- 결과: `.utmp/ticket-241/verify-result.txt` 및 `.utmp/ticket-241/20261106T000052-cba98e26ad1e/verify-result.txt`.
- 단계 로그와 진행 증거: 같은 실행 폴더의 `backend-pytest.log`, `app-test.log`, `verify-progress.json` 등. 모든 진행 이벤트의 SHA는 위 기준과 같고 dirty=false였다.
- 46개 skip은 통과가 아니다.45개 deployment는 Docker/빌드 이미지가 필요한 CI 영역이고1개 integration은 전용 S3 endpoint 미확보다. 요약 원문은 위 결과이며 개별 SKIPPED 원문은 backend-pytest.log에 보존했다.
- 이후 변경은 문서뿐이다. 제품·테스트·CI가 위 PASS SHA와 같은지 확인하여 문서 커밋을 위한 전체 검증은 반복하지 않는다.

## 화면 확인과 남은 일

**화면 확인 미완료.** iOS Simulator·Android Emulator·DPR3 선명도·실제 OS 안전 영역·키보드·터치·스크롤과
변경 전/후/Figma3열 비교·영상은 감독 후속이다. 이번 결과는 로컬 대역/위젯 및 자동 검증이며
원격 CI·운영 서버·실제 OAuth·실기기 성공을 뜻하지 않는다.

감독은 이슈 EI-01부터 EI-09를 확인한다. 변경 전 화면은 묶음 시작 커밋6c9c668의 before-tree에서 확보하며,
플랫폼별 같은 기종·OS·크기·상태·데이터·글자배율·스크롤 위치·실제 DPR로 비교한다.
칩 전환·스크롤·버튼 이동은 영상으로 확인한다. 알림 빈 화면은 기존 하네스이며 운영 루트 연결 검증이 아니다.

Figma 파일svNWsTFh8Ws1Mpt8XQIcrN의 홈111:3711/111:3712·미분류142:5097·즐겨찾기111:4103·
알림125:4173·검색111:4043/340:3421을 기준으로 인수했다.
이슈에 기록된 조회 시점은 상자2026-11-05 00:08 KST, 검색00:29–00:31 KST이며 이번 단계의 새 조회가 아니다.
일반 목록·초기 카드 다시보기·비확정 fallback은 전용 Figma 미확보 사유를 유지하며 대체 화면을 만들지 않는다.
이슈 종료·GitHub 게시·push·PR·운영 배포는 하지 않았다.
