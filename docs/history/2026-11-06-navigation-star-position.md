# 하단 탭 전환 시 즐겨찾기 별 위치 고정 (#240)

- 기록일: 2026-11-06 (KST).
- 이슈: [#240](https://github.com/clip-back/clipback/issues/240).
- 작업 디렉터리: `/Users/leehyeongyu/orca/workspaces/Clipback/small-ui-batch-1`.
- 구현·전체 검증 기준: `dff377a901754e40e2e0f630f0376d7bbea7d3cb`.
- 검수: Standards 0건 / Spec 0건. 추가 제품 수정 없이 전체 검증했다.

## 승인 기준과 구현 전 비교

빈 별은 E01 하단바 `111:4132`의 `I111:4132;325:6753` 원본으로 통일했다.
홈·마이의 빈 별은 오른쪽으로 1 logical px 이동하며 C01 `111:3680`·J01 `111:4764`의 기존 차이는 사용자 승인 예외다.
아카이브 전용 에셋·상수·선택 분기를 정리했다.

채운 별은 I01 하단바 `111:4093`의 `I111:4093;325:6874`와 비교했다.
구현 전 Flutter SvgIcon을 16배로 렌더하여 alpha>127 경계 상자를 측정했다.
슬롯 좌상단을 원점으로 환산한 실제 도형의 경계 중심은 다음과 같다.

| 원본 | 16배 래스터 경계 (좌상단 포함, 우하단 제외) | 중심 (logical px) |
| --- | --- | --- |
| 홈·마이 빈 별 | (45,49,379,383) | (13.25,13.5) |
| E01 빈 별 | (61,49,395,383) | (14.25,13.5) |
| I01 채운 별 | (77,86,379,386) | (14.25,14.75) |

공통 기준점은 E01의 실제 도형 경계 상자 중심 `(14.25,13.5)`로 정했다.
윤곽형·채움형은 면적과 경로가 달라 픽셀 전체나 면적 중심의 동일성을 요구하지 않고 외곽 배치 중심을 맞춘다.
채운 별은 SVG 그룹에 `translate(0 -1.25)`만 적용하여 위로 1.25px 보정했다.
원본 path·fill·stroke·viewBox, 28px 슬롯·라벨·다른 아이콘·안전 영역·저장 동작은 유지했다.

보관 Figma SVG와 현재 path를 대조했다. 빈 별은 `111-4132-6.svg`, 채운 별은 `111-4093-5.svg`와 일치한다.
원본 조회는 이슈 작성자의 2026-11-05 00:08–00:09 KST 기록을 인수했으며 이번 단계에서 Figma를 재조회하지 않았다.
근거는 `.utmp/issue-240/figma-nav`·metadata·manifest와 `.utmp/ticket-240/alignment-decision.md`,
`source-raster-probe.dart`, `before-outline.png`, `before-outline-archive.png`, `before-filled.png`다.
현재 기준은 [화면 맞춤 계획](../figma-ui-alignment-plan.md#figma-current-46)을 따른다.

## 자동 검증

수정 전 실제 홈→아카이브 탭 입력으로 active 상태가 바뀐 뒤 래스터 중심이 정확히 1px 이동하여 신규 8조건이 실패했다.
수정 후 같은 회귀 8개와 지정 기존 검사를 합한 113개 및 analyze가 통과했다.
실제 Pretendard, 폭320/375·배율1.0/1.3·iOS/Android 안전 영역을 별도 조건으로 검사했다.
네 슬롯 Rect와 실제 별의 8배 래스터 중심을 별도로 단언하며 네 탭 왕복·반복 입력·선택 표시·콜백 목적지를 확인한다.
기존 검사로 상세의 이동·저장 시트와 Placeholder의 Navigator pop도 확인했다.
이는 위젯·콜백 검사이며 기기에서 실제 화면이 전환되는 영상 증거가 아니다.

- RED: `.utmp/ticket-240/partial-red.log`.
- GREEN: `.utmp/ticket-240/partial-green.log`.
- 관련 검사·analyze: `.utmp/ticket-240/partial-related.log`.
- 구현 전 probe: `.utmp/ticket-240/partial-probe-r2.log` (1 PASS).
- 첫 probe는 PNG 변환 대기에서 멈춰 해당 테스트 프로세스만 종료한 뒤 runAsync로 수정했다. 첫 로그 `partial-probe.log`도 보존했다.

검수 뒤 clean인 위 기준 SHA에서 `busy.sh --wait`로 차례를 기다리고 전체 검증을 한 번 실행했다.
명령은 저장소 루트 기준이며 Python subprocess timeout으로 셸 시간 제한 600초를 적용했다.

```sh
bash "$HOME/.heoturu-agents/busy.sh" && python3 "$HOME/.heoturu-agents/verify.py" --log-dir .utmp/ticket-240
```

실제 `verify-result.txt` 원문:

```text
pytest skip: 45 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=11 failed=0 logs=/Users/leehyeongyu/orca/workspaces/Clipback/small-ui-batch-1/.utmp/ticket-240/20261106T002248-12a104445c51
```

실제 백엔드 pytest 요약 및 앱 전체 테스트 최종 줄:

```text
2047 passed, 46 skipped, 3 warnings in 173.86s (0:02:53)
02:27 +2926: All tests passed!
```

- 백엔드 ruff·compileall·검사 전용 DB 두 개의 alembic upgrade/check·pytest, 앱 pub get lockfile 검사·format·analyze·전체 테스트의 11단계가 통과했다.
- 콘솔: `.utmp/ticket-240/full-verify-console.log`.
- 결과: `.utmp/ticket-240/verify-result.txt`와 실행 폴더 `20261106T002248-12a104445c51/verify-result.txt`.
- 단계 로그 `backend-pytest.log`, `app-test.log`와 진행 증거 `verify-progress.json`은 같은 실행 폴더에 있다. 모든 진행 이벤트는 위 기준 SHA, dirty=false다.
- 46 skip은 통과가 아니다. Docker deployment 45건과 전용 S3 endpoint가 필요한 CLI 통합 1건은 미실행이다. 상세 사유는 backend-pytest.log의 SKIPPED 행에 보존했다.
- 후속 변경은 문서뿐이며 제품·테스트·CI가 위 PASS SHA와 같음을 확인하여 전체 검증은 반복하지 않는다.

## 화면 확인과 남은 일

**화면 확인 미완료.** 감독이 NS-01부터 NS-05를 iOS Simulator·Android Emulator에서 확인한다.
변경 전은 묶음 시작 커밋 `6c9c668` 기준이며, 변경 후와 동일 기종·OS·화면 크기·데이터·상태·배율·스크롤 조건으로 비교해야 한다.
양 플랫폼 스크린샷·네 탭 전환 영상과 변경 전/후/Figma 3열 비교는 아직 없다.
C01/E01/I01/J01 및 승인 통일 기준을 함께 명시하고 C01/J01 승인 예외와 OS 안전 영역 차이를 설명해야 한다.
이 자동 검증을 기기·CI·실기기·운영 검증으로 보고하지 않는다. 기기 실행·촬영·push·PR·GitHub 댓글/종료·배포는 하지 않았다.
