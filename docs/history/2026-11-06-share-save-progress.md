# 공유 저장 처리 중 표시 (#245)

## 범위와 기준

2026-11-06 기록. 첫 구현 커밋은 `bcf9bf2`, main의 콘텐츠 삭제 확인 창을 합친 전체 검증 기준은
`e847f27d6855a30692fef6599ecc3703891dcb43`이다. 이후 이력·CHANGELOG·README만 변경했으며 제품 코드는 이 검증 기준과 같다.

Figma `348:3390`(2026-11-06 조회)을 iOS Share Extension·Android ShareActivity의 저장 버튼 탭 이후에 적용했다.
처리 중에는 회색 버튼, `전송 중 ...`, 원본 20pt/dp 종이비행기와 10pt/dp 간격,
`저장하고 있어요... 잠시만 기다려주세요 !`를 표시한다. 준비 단계는 기존 버튼 잠금만 유지하고,
실패 알림·동일 키 재시도·닫기·완료 토스트 정책은 유지했다. 저장 완료는 자동 요약 완료를 뜻하지 않는다.
스피너·새 애니메이션·최소 표시 시간·실패 전용 화면은 추가하지 않았다.

## 진단과 리뷰 반영

iOS에서는 요청한 제목 프레임과 UIKit 배치 후 실제 프레임이 달라 제목과 아이콘이 5pt 겹쳤다.
사용자 승인에 따라 `layoutSubviews` 뒤 처리 중 제목·이미지를 직접 배치했고,
실제 프레임의 제목 끝 197pt·아이콘 시작 207pt·아이콘 20×20pt를 두 입력 경로에서 확인했다.
이는 관찰한 배치 차이이며 UIKit 내부 구현 원인까지 증명한 것은 아니다.
높이 제약만 옮기는 앞 실험은 실패하여 채택하지 않았다. 별도 행 구조로 바꾸는 대안은 필요하지 않았다.

기존 복귀 테스트는 시트 소멸 직후 송신 앱이 즉시 입력 가능하다고 가정했다.
500 오류 닫기에서 입력 불가가 약 0.366초 뒤 가능으로 바뀌는 것을 계측했다.
시트 소멸 대기 후 입력 복귀도 최대 5초 기다리도록 하고 기존 최종 단언을 유지했다.
각 대기가 최대 5초이며 helper 전체가 최대 5초라는 뜻은 아니다. 아이콘 matcher·golden·허용치는 변경하지 않았다.

티켓 리뷰는 Standards 중간 1건(S1), Spec 0건이었다. S1은 제품 코드가 아닌 로컬 촬영 도구의
before 경로·커밋 고정 및 기존 산출물 덮어쓰기 가능성이었다. 수정 전 외부 I/O mock으로 쓰기 시도와
원본 불변 단언 실패를 재현했고, phase/출력/빌드 근거/serial을 명시하며 이름·녹화 세션을 배타적으로 예약하도록 고쳤다.
수정 후 mock 9개가 정상 새 출력, 기존 출력 불변, 중복 shot/start/stop, 잘못된 phase/세션,
빌드 근거 변경·APK 불일치 거부를 통과했다. 로컬 `.utmp` 도구·안내는 커밋 대상이 아니며 실제 기기 기능 검증이 아니다.

낮은 확신 항목 판단:

- fixture의 truthiness 해석으로 문자열 `"false"`가 release를 실행하는 것은 mock으로 확인했다.
  현재 caller는 JSON bool을 보내는 내부 시험이고 손상 제어 입력은 계약 밖이므로 이번 제품 범위를 넓혀 수정하지 않았다.
- 전역 release는 순차 대역 시험용이며 병행 요청별 독립 release를 보장하지 않는다. 병행 사용 검증으로 확대하지 않았다.
- staging 부작용이 있는 `check-first-commit.py`는 이번 단계에서 실행하지 않았다.
- matcher 원본 본문과 golden 해시의 동일성은 별도 읽기 전용 비교로 확인했다.
  이전 source 해시와 다른 두 문서(화면 맞춤 계획·frontend README)는 main 반영으로 바뀐 것이며 제품 불일치가 아니다.

## 검증 결과

### 이번 전체 검증

저장소 루트에서 공용 점유 해소 후 실행했다. 셸 실행 제한은 600초였다.

```bash
~/.heoturu-agents/busy.sh --wait
~/.heoturu-agents/busy.sh && python3 ~/.heoturu-agents/verify.py --log-dir .utmp/ticket-245/final
```

```text
VERIFY result=PASS scope=all checks=11 failed=0
backend pytest: 2048 passed, 46 skipped, 3 warnings
Flutter: 2931 passed
pytest skip: 45 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
```

결과 파일과 실제 pytest/Flutter 로그를 대조했다. skip 46건은 통과에 포함하지 않았다.
로그 디렉터리: `.utmp/ticket-245/final/20261106T135720-7ab8685a1fc6`.
명령·셸 결과: `.utmp/ticket-245/review-fix/verify-console.log`.

### 앞 단계 네이티브 검증

아래는 main 합치기 전 구현 코드의 실행 근거이며 이번 전체 VERIFY가 네이티브 UI를 다시 실행한 것은 아니다.

| 환경·범위 | 결과 | `.utmp/ticket-245/` 로그 |
| --- | --- | --- |
| iPhone 16 / iOS 18.6, 신규 처리 중 UI | 3개 통과 | `partial-ios-layout-ready-progress.log` |
| 같은 Simulator, 기존 공유 UI | 15개 통과 | `partial-ios-layout-ready-regression.log` |
| 같은 Simulator, RunnerTests | 25개 통과 | `partial-ios-layout-final-runner.log` |
| Android Medium_Phone / API 36, 신규 처리 중 | 4개 통과 | `partial-android-green-progress.log` |
| 같은 Emulator, 네이티브 3개 클래스 | 69개 통과 | `partial-android-green-regression.log` |

모두 로컬 HTTP 대역 검증이다. 초기 red와 실패한 실험·회귀 로그도 보존했다.
진단은 `.utmp/ticket-245/diagnosis.md`, S1 수정 전·후 mock은 `.utmp/ticket-245/review-fix/`에 있다.

## 남은 확인

- 최종 변경 후 기기 촬영과 변경 전/후/Figma 3열 비교·전환 영상은 감독 후속이다.
- 정확한 iOS 수치 글자 배율 1.1/1.2/1.3과 실제 VoiceOver·TalkBack은 미완료다.
  OS content_size 단계의 과거 촬영을 수치 배율 완료로 간주하지 않는다.
- 기존 iOS before 전용 캡처 도구도 metadata/log 전체 충돌 보호가 없어 after에 재사용하지 않는다.
  새 xcresult 경로를 쓰는 UI 캡처와 별도 안전한 영상 경로를 사용해야 한다.
- Docker deployment/operator-recovery와 로컬 S3 시험은 skip 사유에 해당하며 CI·운영·실기기 성공을 의미하지 않는다.
- 준비 단계·실패 전용 디자인·애니메이션·최소 표시 시간 등 미확정 디자인은 그대로 남는다.
- GitHub 게시·push·PR·이슈 종료는 이번 단계에서 수행하지 않았다.
